//! On-demand, bounded Xtream now/next. Provider details never enter errors.
use std::{sync::OnceLock, time::Duration};

use anyhow::{Result, anyhow, bail};
use base64::{Engine, engine::general_purpose::STANDARD};
use chrono::{DateTime, NaiveDateTime, Timelike, Utc};
use reqwest::{Client, Url};
use rusqlite::{Connection, OptionalExtension};
use serde_json::Value;
use tokio::sync::Semaphore;

use crate::generated_proto::{NowNext, Programme};

const MAX_BODY: usize = 256 * 1024;
pub(crate) static REQUESTS: Semaphore = Semaphore::const_new(2);

// Compare saved request inputs and channel identity again after the await.
#[derive(PartialEq)]
struct Identity {
    source_id: i64,
    stream_id: i64,
    channel_url: String,
    channel_name: String,
    source_name: String,
    updated: Option<i64>,
    url: Option<String>,
    username: Option<String>,
    password: Option<String>,
    user_agent: Option<String>,
}

fn resolve(conn: &Connection, id: i64) -> Result<Option<Identity>> {
    Ok(conn.query_row(
        "SELECT s.id,c.stream_id,c.url,c.name,s.name,s.last_updated,s.url,s.username,s.password,s.user_agent
         FROM channels c JOIN sources s ON s.id=c.source_id
         WHERE c.id=? AND c.media_type=0 AND c.stream_id>0 AND length(trim(c.url))>0
         AND s.source_type=2 AND s.enabled=1 AND s.import_live=1 AND c.hidden=0 AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id=c.group_id AND g.hidden=1)",
        [id], |r| Ok(Identity {
            source_id: r.get(0)?, stream_id: r.get(1)?, channel_url: r.get(2)?,
            channel_name: r.get(3)?, source_name: r.get(4)?, updated: r.get(5)?,
            url: r.get(6)?, username: r.get(7)?, password: r.get(8)?, user_agent: r.get(9)?,
        })).optional()?)
}

pub async fn get_now_next(id: i64) -> Result<NowNext> {
    if crate::settings::get_settings()
        .map_err(|_| anyhow!("EPG database unavailable"))?
        .show_programmes
        == Some(false)
    {
        return Ok(NowNext::default());
    }
    if crate::xmltv::eligible(id)? {
        return crate::xmltv::now_next(id).await;
    }
    let result = fetch(|| {
        let conn = crate::sql::get_conn()?;
        resolve(&conn, id)
    })
    .await?;
    if !guide_enabled(false)? {
        return Ok(NowNext::default());
    }
    Ok(result)
}

async fn fetch(resolve: impl Fn() -> Result<Option<Identity>>) -> Result<NowNext> {
    let identity = resolve().map_err(|_| anyhow!("EPG database unavailable"))?;
    let Some(identity) = identity else {
        return Ok(NowNext::default());
    };
    let _permit = REQUESTS
        .try_acquire()
        .map_err(|_| anyhow!("EPG requests busy"))?;
    let result = request(&identity).await;
    if resolve()
        .map_err(|_| anyhow!("EPG database unavailable"))?
        .as_ref()
        != Some(&identity)
    {
        bail!("EPG source or channel changed");
    }
    parse(&result?, Utc::now().timestamp())
}

async fn request(identity: &Identity) -> Result<Vec<u8>> {
    request_action(identity, false).await
}

async fn request_action(identity: &Identity, full: bool) -> Result<Vec<u8>> {
    static CLIENT: OnceLock<Client> = OnceLock::new();
    let client = if let Some(client) = CLIENT.get() {
        client
    } else {
        let client = Client::builder()
            .referer(false)
            .connect_timeout(Duration::from_secs(2))
            .timeout(Duration::from_secs(8))
            .redirect(reqwest::redirect::Policy::limited(3))
            .build()
            .map_err(|_| anyhow!("EPG client unavailable"))?;
        CLIENT.get_or_init(|| client)
    };
    let mut url = Url::parse(
        identity
            .url
            .as_deref()
            .ok_or_else(|| anyhow!("EPG configuration invalid"))?,
    )
    .map_err(|_| anyhow!("EPG configuration invalid"))?;
    // Keep the saved endpoint, but replace API arguments instead of duplicating them.
    let pairs: Vec<(String, String)> = url
        .query_pairs()
        .filter(|(k, _)| {
            !matches!(
                k.as_ref(),
                "username" | "password" | "action" | "stream_id" | "limit"
            )
        })
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    url.set_query(None);
    url.query_pairs_mut()
        .extend_pairs(pairs)
        .append_pair(
            "username",
            identity
                .username
                .as_deref()
                .ok_or_else(|| anyhow!("EPG configuration invalid"))?,
        )
        .append_pair(
            "password",
            identity
                .password
                .as_deref()
                .ok_or_else(|| anyhow!("EPG configuration invalid"))?,
        )
        .append_pair(
            "action",
            if full {
                "get_simple_data_table"
            } else {
                "get_short_epg"
            },
        )
        .append_pair("stream_id", &identity.stream_id.to_string())
        .append_pair("limit", "4");
    let mut response = client
        .get(url)
        .timeout(Duration::from_secs(if full { 8 } else { 5 }))
        .header(
            reqwest::header::USER_AGENT,
            identity
                .user_agent
                .as_deref()
                .filter(|s| !s.is_empty())
                .unwrap_or("brenTV"),
        )
        .send()
        .await
        .map_err(|_| anyhow!("EPG request failed"))?
        .error_for_status()
        .map_err(|_| anyhow!("EPG request failed"))?;
    if response
        .content_length()
        .is_some_and(|n| n > (if full { 2 * 1024 * 1024 } else { MAX_BODY }) as u64)
    {
        bail!("EPG response too large");
    }
    let mut body = Vec::new();
    while let Some(chunk) = response
        .chunk()
        .await
        .map_err(|_| anyhow!("EPG response failed"))?
    {
        if chunk.len() > (if full { 2 * 1024 * 1024 } else { MAX_BODY }) - body.len() {
            bail!("EPG response too large");
        }
        body.extend_from_slice(&chunk);
    }
    Ok(body)
}

fn timestamp(value: &Value) -> Result<i64> {
    let n = match value {
        Value::Number(n) => n.as_i64(),
        Value::String(s) if !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()) => {
            s.parse().ok()
        }
        _ => None,
    }
    .filter(|n| *n >= 0 && DateTime::from_timestamp(*n, 0).is_some());
    n.ok_or_else(|| anyhow!("EPG timestamp invalid"))
}

pub(crate) fn normalize(title: &str) -> String {
    title
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .chars()
        .take(256)
        .collect()
}

fn title(raw: &str) -> String {
    if let Some(decoded) = STANDARD
        .decode(raw)
        .ok()
        .and_then(|b| String::from_utf8(b).ok())
    {
        let normalized = normalize(&decoded);
        if !normalized.is_empty()
            && !decoded
                .chars()
                .any(|c| c.is_control() && !c.is_whitespace())
        {
            return normalized;
        }
    }
    normalize(raw)
}

fn parse_list(body: &[u8], limit: usize) -> Result<Vec<Programme>> {
    let value: Value = serde_json::from_slice(body).map_err(|_| anyhow!("EPG response invalid"))?;
    if value.get("error").is_some()
        || value.get("user_info").and_then(|u| u.get("auth")) == Some(&Value::from(0))
    {
        bail!("EPG provider error");
    }
    let listings = value
        .get("epg_listings")
        .and_then(Value::as_array)
        .ok_or_else(|| anyhow!("EPG listings invalid"))?;
    if listings.len() > limit {
        bail!("EPG too many listings");
    }
    let mut programmes = Vec::new();
    for entry in listings {
        let start = timestamp(&entry["start_timestamp"])?;
        let stop = timestamp(&entry["stop_timestamp"])?;
        if stop <= start {
            bail!("EPG interval invalid");
        }
        let title = title(
            entry["title"]
                .as_str()
                .ok_or_else(|| anyhow!("EPG title invalid"))?,
        );
        if title.is_empty() {
            bail!("EPG title invalid");
        }
        programmes.push(Programme {
            title,
            start,
            stop,
            catchup_available: archive_date(entry, start).is_some(),
        });
    }
    programmes.sort_by(|a, b| (a.start, a.stop, &a.title).cmp(&(b.start, b.stop, &b.title)));
    programmes.dedup();
    Ok(programmes)
}

fn parse(body: &[u8], at: i64) -> Result<NowNext> {
    let programmes = parse_list(body, 64)?;
    Ok(NowNext {
        supported: true,
        now: programmes
            .iter()
            .filter(|p| p.start <= at && at < p.stop)
            .max_by_key(|p| p.start)
            .cloned(),
        next: programmes.into_iter().find(|p| p.start > at),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::sync::{Arc, Mutex};
    use tokio::{
        io::{AsyncReadExt, AsyncWriteExt},
        net::TcpListener,
    };

    fn listing(title: &str, start: Value, stop: Value) -> Value {
        json!({"title":title,"start_timestamp":start,"stop_timestamp":stop,"now_playing":1,
            "start":"wrong timezone date"})
    }

    #[test]
    fn parsing_and_bounds() {
        let entry = listing("UHJvZ3JhbW1lIDE=", json!(100), json!(200));
        let body = json!({"epg_listings":[listing("Later",json!(300),json!(400)),
            entry.clone(),entry,listing("Next",json!("200"),json!("300"))]});
        let result = parse(body.to_string().as_bytes(), 150).unwrap();
        assert!(result.supported);
        assert_eq!(result.now.unwrap().title, "Programme 1");
        assert_eq!(result.next.unwrap().start, 200);
        let boundary = parse(body.to_string().as_bytes(), 200).unwrap();
        assert_eq!(boundary.now.unwrap().title, "Next");
        assert_eq!(boundary.next.unwrap().start, 300);
        assert!(
            parse(body.to_string().as_bytes(), 99)
                .unwrap()
                .now
                .is_none()
        );
        assert!(
            parse(body.to_string().as_bytes(), 400)
                .unwrap()
                .next
                .is_none()
        );
        assert_eq!(title(" Plain\n\t title\0 "), "Plain title");
        assert_eq!(title("////"), "////"); // invalid UTF-8 base64 falls back
        assert_eq!(title("AA=="), "AA=="); // unusable decoded control
        assert_eq!(title(&"é".repeat(300)).chars().count(), 256);
        for bad in [
            json!(-1),
            json!(1.0),
            json!("1.0"),
            json!("+1"),
            json!(" 1"),
            json!("9223372036854775808"),
            json!(253402300800000i64),
            Value::Null,
        ] {
            assert!(timestamp(&bad).is_err(), "{bad}");
        }
        assert_eq!(timestamp(&json!(0)).unwrap(), 0);
        assert_eq!(timestamp(&json!("123")).unwrap(), 123);
        for value in [
            json!({}),
            json!({"epg_listings":null}),
            json!({"epg_listings":[{}]}),
            json!({"epg_listings":[],"error":"secret"}),
            json!({"epg_listings":[],"user_info":{"auth":0}}),
            json!({"epg_listings":[listing("x",json!(2),json!(1))]}),
            json!({"epg_listings":[listing("x",json!(1),json!(1))]}),
            json!({"epg_listings":vec![listing("x",json!(1),json!(2));65]}),
        ] {
            assert!(parse(value.to_string().as_bytes(), 1).is_err());
        }
        assert!(parse(b"not JSON secret", 1).is_err());
        let empty = parse(br#"{"epg_listings":[]}"#, 1).unwrap();
        assert!(empty.supported && empty.now.is_none() && empty.next.is_none());
        assert!(
            parse(
                json!({"epg_listings":vec![listing("x",json!(1),json!(2));64]})
                    .to_string()
                    .as_bytes(),
                1
            )
            .is_ok()
        );
    }

    fn database(url: &str) -> Arc<Mutex<Connection>> {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch("CREATE TABLE sources(id INTEGER,name TEXT,last_updated INTEGER,url TEXT,
            username TEXT,password TEXT,user_agent TEXT,source_type INTEGER,enabled INTEGER,import_live INTEGER);
            CREATE TABLE groups(id INTEGER,hidden INTEGER); CREATE TABLE channels(id INTEGER,source_id INTEGER,stream_id INTEGER,url TEXT,name TEXT,media_type INTEGER,hidden INTEGER DEFAULT 0,group_id INTEGER);
            INSERT INTO channels(id,source_id,stream_id,url,name,media_type) VALUES(1,1,42,'http://playable','Channel',0);").unwrap();
        conn.execute("INSERT INTO sources VALUES(1,'Source',1,?,'fake-user','fake-secret','test-agent',2,1,1)",[url]).unwrap();
        Arc::new(Mutex::new(conn))
    }

    async fn server(
        response: Vec<u8>,
        delay: bool,
    ) -> (
        String,
        tokio::task::JoinHandle<String>,
        tokio::sync::oneshot::Receiver<()>,
        tokio::sync::oneshot::Sender<()>,
    ) {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!(
            "http://{}/player_api.php?username=old&action=old",
            listener.local_addr().unwrap()
        );
        let (seen_tx, seen_rx) = tokio::sync::oneshot::channel();
        let (release_tx, release_rx) = tokio::sync::oneshot::channel();
        let task = tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut request = Vec::new();
            loop {
                let mut buf = [0; 1024];
                let n = socket.read(&mut buf).await.unwrap();
                if n == 0 {
                    break;
                }
                request.extend_from_slice(&buf[..n]);
                if request.windows(4).any(|w| w == b"\r\n\r\n") {
                    break;
                }
            }
            let _ = seen_tx.send(());
            if delay {
                let _ = release_rx.await;
            }
            let _ = socket.write_all(&response).await;
            String::from_utf8(request).unwrap()
        });
        (url, task, seen_rx, release_tx)
    }

    fn response(body: &[u8], chunked: bool) -> Vec<u8> {
        if chunked {
            let mut bytes =
                b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n"
                    .to_vec();
            for chunk in body.chunks(8192) {
                bytes.extend_from_slice(format!("{:x}\r\n", chunk.len()).as_bytes());
                bytes.extend_from_slice(chunk);
                bytes.extend_from_slice(b"\r\n");
            }
            bytes.extend_from_slice(b"0\r\n\r\n");
            bytes
        } else {
            let mut bytes = format!(
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            )
            .into_bytes();
            bytes.extend_from_slice(body);
            bytes
        }
    }

    #[tokio::test]
    async fn local_http_eligibility_bounds_redaction_and_races() {
        let _guard = crate::sql::test_lock_async().await;
        let empty = br#"{"epg_listings":[]}"#;
        // The full guide uses the non-video endpoint and a separate 2 MiB cap.
        for chunked in [false, true] {
            let (url, task, _, _) = server(response(empty, chunked), false).await;
            let db = database(&url);
            let identity = resolve(&db.lock().unwrap(), 1).unwrap().unwrap();
            assert_eq!(request_action(&identity, true).await.unwrap(), empty);
            let request = task.await.unwrap();
            assert!(request.contains("action=get_simple_data_table"));
            assert!(!request.contains("get_simple_data_table_video"));
            let (url, task, _, _) =
                server(response(&vec![b'x'; 2 * 1024 * 1024 + 1], chunked), false).await;
            let db = database(&url);
            let identity = resolve(&db.lock().unwrap(), 1).unwrap().unwrap();
            assert_eq!(
                request_action(&identity, true)
                    .await
                    .unwrap_err()
                    .to_string(),
                "EPG response too large"
            );
            task.await.unwrap();
        }

        for chunked in [false, true] {
            let (url, task, _, _) = server(response(empty, chunked), false).await;
            let db = database(&url);
            let result = fetch(|| resolve(&db.lock().unwrap(), 1)).await.unwrap();
            assert!(result.supported && result.now.is_none());
            let request = task.await.unwrap();
            assert!(
                request.contains("action=get_short_epg")
                    && request.contains("stream_id=42")
                    && request.contains("limit=4")
            );
            assert!(request.contains("username=fake-user") && !request.contains("username=old"));
            assert!(request.contains("user-agent: test-agent"));
            assert!(!request.to_lowercase().contains("referer:"));
        }
        let at = Utc::now().timestamp();
        let body = json!({"epg_listings":[
            listing("Current programme",json!(at-60),json!(at+600)),
            listing("Future programme",json!(at+600),json!(at+1200))
        ]})
        .to_string();
        let (url, task, _, _) = server(response(body.as_bytes(), true), false).await;
        let db = database(&url);
        let result = fetch(|| resolve(&db.lock().unwrap(), 1)).await.unwrap();
        assert_eq!(result.now.unwrap().title, "Current programme");
        assert_eq!(result.next.unwrap().title, "Future programme");
        task.await.unwrap();
        for bytes in [
            response(&vec![b'x'; MAX_BODY + 1], false),
            response(&vec![b'x'; MAX_BODY + 1], true),
            response(b"fake-secret invalid json", false),
            b"HTTP/1.1 500 fake-secret\r\nContent-Length: 11\r\n\r\nfake-secret".to_vec(),
        ] {
            let (url, task, _, _) = server(bytes, false).await;
            let db = database(&url);
            let error = fetch(|| resolve(&db.lock().unwrap(), 1))
                .await
                .unwrap_err()
                .to_string();
            assert!(
                !error.contains("fake-secret")
                    && !error.contains("127.0.0.1")
                    && !error.contains("fake-user")
            );
            task.await.unwrap();
        }
        // A listener remains untouched for every unsupported case.
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let db = database(&format!("http://{}", listener.local_addr().unwrap()));
        for change in [
            "UPDATE sources SET source_type=0",
            "UPDATE sources SET source_type=1",
            "UPDATE sources SET enabled=0",
            "UPDATE sources SET import_live=0",
            "UPDATE channels SET media_type=1",
            "UPDATE channels SET stream_id=0",
            "UPDATE channels SET url=NULL",
            "DELETE FROM channels",
            "DELETE FROM sources",
        ] {
            {
                let conn = db.lock().unwrap();
                conn.execute_batch("SAVEPOINT unsupported").unwrap();
                conn.execute_batch(change).unwrap();
            }
            assert!(
                !fetch(|| resolve(&db.lock().unwrap(), 1))
                    .await
                    .unwrap()
                    .supported
            );
            db.lock()
                .unwrap()
                .execute_batch("ROLLBACK TO unsupported; RELEASE unsupported")
                .unwrap();
        }
        assert!(
            !fetch(|| resolve(&db.lock().unwrap(), 999))
                .await
                .unwrap()
                .supported
        );
        assert!(
            tokio::time::timeout(Duration::from_millis(20), listener.accept())
                .await
                .is_err()
        );
        // Acquire both slots: a third eligible request fails immediately, without HTTP.
        let permits = REQUESTS.acquire_many(2).await.unwrap();
        let error = fetch(|| resolve(&db.lock().unwrap(), 1)).await.unwrap_err();
        assert_eq!(error.to_string(), "EPG requests busy");
        drop(permits);
        for change in [
            "UPDATE sources SET enabled=0",
            "UPDATE sources SET import_live=0",
            "UPDATE sources SET password='changed'",
            "UPDATE sources SET url='http://changed'",
            "UPDATE sources SET user_agent='changed'",
            "DELETE FROM sources",
            "DELETE FROM channels",
            "UPDATE channels SET stream_id=43",
            "UPDATE channels SET url='http://changed'",
            "UPDATE channels SET media_type=1",
        ] {
            let (url, task, seen, release) = server(response(empty, false), true).await;
            let db = database(&url);
            let future = fetch(|| resolve(&db.lock().unwrap(), 1));
            let edit = async {
                seen.await.unwrap();
                db.lock().unwrap().execute_batch(change).unwrap();
                release.send(()).unwrap();
            };
            let (result, ()) = tokio::join!(future, edit);
            assert_eq!(
                result.unwrap_err().to_string(),
                "EPG source or channel changed",
                "{change}"
            );
            task.await.unwrap();
        }
    }
    #[tokio::test]
    async fn schedule_rechecks_source_and_master_after_await() {
        let _guard = crate::sql::test_lock_async().await;
        crate::sql::test_db();
        for master in [false, true] {
            let (url, task, seen, release) =
                server(response(br#"{"epg_listings":[]}"#, false), true).await;
            let source = crate::sql::save_source(
                crate::generated_proto::Source {
                    name: "schedule-race".into(),
                    url: Some(url),
                    source_type: 2,
                    username: Some("synthetic".into()),
                    password: Some("synthetic".into()),
                    enabled: true,
                    ..Default::default()
                }
                .into(),
            )
            .unwrap();
            let sid = source.id.unwrap();
            crate::sql::get_conn().unwrap().execute("INSERT INTO channels(name,url,media_type,source_id,stream_id) VALUES ('Race','http://unused',0,?,42)",[sid]).unwrap();
            let cid = crate::sql::get_conn()
                .unwrap()
                .query_row("SELECT id FROM channels WHERE source_id=?", [sid], |r| {
                    r.get(0)
                })
                .unwrap();
            let edit = async {
                seen.await.unwrap();
                if master {
                    crate::settings::update_settings(crate::types::Settings {
                        show_programmes: Some(false),
                        ..Default::default()
                    })
                    .unwrap();
                } else {
                    crate::sql::set_source_enabled(false, sid).unwrap();
                }
                release.send(()).unwrap();
            };
            let (result, ()) = tokio::join!(get_schedule(cid, 1, 100), edit);
            if master {
                assert!(!result.unwrap().supported);
            } else {
                assert_eq!(
                    result.unwrap_err().to_string(),
                    "EPG source or channel changed"
                );
            }
            task.await.unwrap();
            crate::sql::delete_source(sid).unwrap();
            crate::settings::update_settings(crate::types::Settings {
                show_programmes: Some(true),
                ..Default::default()
            })
            .unwrap();
        }
    }
}

fn guide_enabled(full: bool) -> Result<bool> {
    let s = crate::settings::get_settings().map_err(|_| anyhow!("EPG database unavailable"))?;
    Ok(s.show_programmes != Some(false) && (!full || s.enable_full_guide != Some(false)))
}
pub async fn get_schedule(
    id: i64,
    from: i64,
    to: i64,
) -> Result<crate::generated_proto::ProgrammeList> {
    validate_window(from, to)?;
    if !guide_enabled(true)? {
        return Ok(Default::default());
    }
    if crate::xmltv::eligible(id)? {
        return crate::xmltv::schedule(id, from, to).await;
    }
    let identity = {
        let conn = crate::sql::get_conn()?;
        resolve(&conn, id)?
    };
    let Some(identity) = identity else {
        return Ok(Default::default());
    };
    let _permit = REQUESTS
        .try_acquire()
        .map_err(|_| anyhow!("EPG requests busy"))?;
    let body = request_action(&identity, true).await?;
    if !guide_enabled(true)? {
        return Ok(Default::default());
    }
    let current = {
        let conn = crate::sql::get_conn()?;
        resolve(&conn, id)?
    };
    if current.as_ref() != Some(&identity) {
        bail!("EPG source or channel changed");
    }
    let programmes = parse_list(&body, 2048)?
        .into_iter()
        .filter(|p| p.start < to && p.stop > from)
        .collect();
    let (archive, days) = archive(id)?;
    Ok(crate::generated_proto::ProgrammeList {
        supported: true,
        programmes,
        catchup_supported: archive
            && crate::settings::get_settings()?.enable_catchup != Some(false),
        archive_days: days,
    })
}
pub(crate) fn validate_window(from: i64, to: i64) -> Result<()> {
    if from < 0 || to <= from || to - from > 7 * 86400 || DateTime::from_timestamp(to, 0).is_none()
    {
        bail!("EPG window invalid");
    }
    Ok(())
}
fn archive(id: i64) -> Result<(bool, u32)> {
    let conn = crate::sql::get_conn()?;
    Ok(conn
        .query_row(
            "SELECT COALESCE(tv_archive,0),COALESCE(archive_days,0) FROM channels WHERE id=?",
            [id],
            |r| Ok((r.get::<_, bool>(0)?, r.get::<_, u32>(1)?)),
        )
        .optional()?
        .map(|(a, d)| (a && d > 0, d))
        .unwrap_or_default())
}
pub async fn get_catchup(id: i64, start: i64, stop: i64) -> Result<crate::types::Channel> {
    if !guide_enabled(true)? || crate::settings::get_settings()?.enable_catchup == Some(false) {
        bail!("Catch-up disabled");
    }
    let identity = {
        let conn = crate::sql::get_conn()?;
        resolve(&conn, id)?.ok_or_else(|| anyhow!("Catch-up unavailable"))?
    };
    let (supported, days) = archive(id)?;
    validate_catchup(start, stop, Utc::now().timestamp(), supported, days)?;
    let _permit = REQUESTS
        .try_acquire()
        .map_err(|_| anyhow!("EPG requests busy"))?;
    let body = request_action(&identity, true).await?;
    // Use the provider's paired wall-clock date, rather than guessing its
    // timezone from the device or formatting the UTC timestamp as local time.
    let values: Value =
        serde_json::from_slice(&body).map_err(|_| anyhow!("EPG response invalid"))?;
    parse_list(&body, 2048)?;
    let local = values["epg_listings"]
        .as_array()
        .and_then(|rows| {
            rows.iter().find(|p| {
                timestamp(&p["start_timestamp"]).ok() == Some(start)
                    && timestamp(&p["stop_timestamp"]).ok() == Some(stop)
            })
        })
        .and_then(|p| archive_date(p, start))
        .ok_or_else(|| anyhow!("Catch-up program unavailable"))?;
    let current = {
        let conn = crate::sql::get_conn()?;
        resolve(&conn, id)?
    };
    if !guide_enabled(true)?
        || crate::settings::get_settings()?.enable_catchup == Some(false)
        || current.as_ref() != Some(&identity)
        || archive(id)? != (supported, days)
    {
        bail!("Catch-up source or channel changed");
    }
    let url = catchup_url(
        &identity,
        start,
        stop,
        Utc::now().timestamp(),
        supported,
        days,
        local,
    )?;
    // A transient movie never writes a live channel's history or position.
    Ok(crate::types::Channel {
        id: None,
        name: identity.channel_name,
        url: Some(url),
        group: None,
        image: None,
        media_type: crate::media_type::MOVIE,
        source_id: Some(identity.source_id),
        series_id: None,
        group_id: None,
        favorite: false,
        stream_id: None,
        tv_archive: None,
        season_id: None,
        episode_num: None,
        quality: 0,
        alt_key: None,
        hidden: false,
        archive_days: None,
        epg_id: None,
    })
}

fn archive_date(entry: &Value, start: i64) -> Option<NaiveDateTime> {
    let archived = match entry.get("has_archive") {
        None => true,
        Some(Value::Bool(v)) => *v,
        Some(Value::Number(v)) => v.as_u64() == Some(1),
        Some(Value::String(v)) => v == "1",
        _ => false,
    };
    if !archived {
        return None;
    }
    let date = NaiveDateTime::parse_from_str(entry["start"].as_str()?, "%Y-%m-%d %H:%M:%S").ok()?;
    ((date.and_utc().timestamp() - start).abs() <= 18 * 3600).then_some(date)
}

fn validate_catchup(start: i64, stop: i64, now: i64, supported: bool, days: u32) -> Result<()> {
    if !supported
        || days == 0
        || start < 0
        || stop <= start
        || stop > now
        || start < now - i64::from(days) * 86400
        || stop - start > 86400
    {
        bail!("Catch-up interval unavailable");
    }
    Ok(())
}
fn catchup_url(
    identity: &Identity,
    start: i64,
    stop: i64,
    now: i64,
    supported: bool,
    days: u32,
    local: NaiveDateTime,
) -> Result<String> {
    validate_catchup(start, stop, now, supported, days)?;
    let date = local.format("%Y-%m-%d:%H-%M").to_string();
    let mut url = Url::parse(
        identity
            .url
            .as_deref()
            .ok_or_else(|| anyhow!("Catch-up configuration invalid"))?,
    )
    .map_err(|_| anyhow!("Catch-up configuration invalid"))?;
    if !matches!(url.scheme(), "http" | "https") {
        bail!("Catch-up configuration invalid");
    }
    url.set_query(None);
    url.set_fragment(None);
    {
        let mut path = url
            .path_segments_mut()
            .map_err(|_| anyhow!("Catch-up configuration invalid"))?;
        path.pop()
            .push("timeshift")
            .push(
                identity
                    .username
                    .as_deref()
                    .ok_or_else(|| anyhow!("Catch-up configuration invalid"))?,
            )
            .push(
                identity
                    .password
                    .as_deref()
                    .ok_or_else(|| anyhow!("Catch-up configuration invalid"))?,
            )
            // Xtream dates have minute precision; include the truncated seconds.
            .push(&((stop - start + i64::from(local.second()) + 59) / 60).to_string())
            .push(&date)
            .push(&format!("{}.ts", identity.stream_id));
    }
    Ok(url.into())
}

#[cfg(test)]
mod expansion_tests {
    use super::*;
    #[test]
    fn catchup_dates_retention_and_encoding() {
        let identity = Identity {
            source_id: 1,
            stream_id: 42,
            channel_url: "http://live".into(),
            channel_name: "News".into(),
            source_name: "Source".into(),
            updated: None,
            url: Some("https://example.invalid/prefix/player_api.php?secret=discard".into()),
            username: Some("u/name".into()),
            password: Some("p?#word".into()),
            user_agent: None,
        };
        let at = DateTime::parse_from_rfc3339("2026-11-13T12:00:00Z")
            .unwrap()
            .timestamp();
        let url = catchup_url(
            &identity,
            at - 3600,
            at - 3539,
            at,
            true,
            2,
            DateTime::from_timestamp(at - 3600, 0).unwrap().naive_utc(),
        )
        .unwrap();
        assert_eq!(
            url,
            "https://example.invalid/prefix/timeshift/u%2Fname/p%3F%23word/2/2026-11-13:11-00/42.ts"
        );
        let url = catchup_url(
            &identity,
            at - 3600 + 59,
            at - 3600 + 119,
            at,
            true,
            2,
            DateTime::from_timestamp(at - 3600 + 59, 0)
                .unwrap()
                .naive_utc(),
        )
        .unwrap();
        assert!(url.contains("/2/2026-11-13:11-00/"));
        for (a, b, s, d) in [
            (at - 100, at + 1, true, 2),
            (at - 3 * 86400, at - 3 * 86400 + 60, true, 2),
            (at - 60, at, false, 2),
            (at - 60, at, true, 0),
            (at, at, true, 2),
            (at - 86401, at, true, 2),
        ] {
            assert!(
                catchup_url(
                    &identity,
                    a,
                    b,
                    at,
                    s,
                    d,
                    DateTime::from_timestamp(at, 0).unwrap().naive_utc()
                )
                .is_err()
            );
        }
        assert!(
            catchup_url(
                &identity,
                at - 2 * 86400,
                at - 2 * 86400 + 60,
                at,
                true,
                2,
                DateTime::from_timestamp(at - 2 * 86400, 0)
                    .unwrap()
                    .naive_utc()
            )
            .is_ok()
        );
    }
    #[test]
    fn schedule_window_entries_and_filter_inputs() {
        assert!(validate_window(0, 7 * 86400).is_ok());
        assert!(validate_window(0, 7 * 86400 + 1).is_err());
        assert!(validate_window(-1, 1).is_err());
        assert!(validate_window(5, 5).is_err());
        let entry =
            serde_json::json!({"start_timestamp":"100","stop_timestamp":200,"title":"VGVzdA=="});
        let body = serde_json::json!({"epg_listings":vec![entry.clone();2048]}).to_string();
        assert_eq!(parse_list(body.as_bytes(), 2048).unwrap().len(), 1);
        let body = serde_json::json!({"epg_listings":vec![entry;2049]}).to_string();
        assert!(parse_list(body.as_bytes(), 2048).is_err());
    }
}
