//! Optional exact-ID XMLTV. Bounded expiring source caches, no disk writes.
use crate::generated_proto::{NowNext, Programme, ProgrammeList};
use anyhow::{Result, anyhow, bail};
use chrono::{DateTime, NaiveDateTime, Utc};
use quick_xml::{Reader, XmlVersion, events::Event};
use rusqlite::OptionalExtension;
use std::{
    collections::HashMap,
    sync::Mutex,
    time::{Duration, Instant},
};
const MAX_BYTES: usize = 16 * 1024 * 1024;
const MAX_ENTRIES: usize = 50_000;
const MAX_CACHED_SOURCES: usize = 4;
#[derive(Clone, PartialEq)]
struct Identity {
    source: i64,
    url: String,
    epg_id: String,
    source_url: Option<String>,
    updated: Option<i64>,
    agent: Option<String>,
}
struct Cache {
    identity: Identity,
    fetched: Instant,
    data: HashMap<String, Vec<Programme>>,
}
static CACHE: Mutex<Vec<Cache>> = Mutex::new(Vec::new());
// Coalesce document misses, including requests for different channels in one source.
static LOAD: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());
pub fn clear_cache() {
    if let Ok(mut cache) = CACHE.lock() {
        cache.clear();
    }
}
fn resolve(id: i64) -> Result<Option<Identity>> {
    let s = crate::settings::get_settings()?;
    if s.enable_xmltv != Some(true) || s.show_programmes == Some(false) {
        return Ok(None);
    }
    let conn = crate::sql::get_conn()?;
    Ok(conn.query_row("SELECT s.id,s.epg_url,c.epg_id,s.url,s.last_updated,s.user_agent FROM channels c JOIN sources s ON s.id=c.source_id WHERE c.id=? AND c.media_type=0 AND s.source_type IN (0,1) AND s.enabled=1 AND s.import_live=1 AND c.hidden=0 AND length(c.epg_id)>0 AND length(s.epg_url)>0 AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id=c.group_id AND g.hidden=1)",[id],|r|Ok(Identity{source:r.get(0)?,url:r.get(1)?,epg_id:r.get(2)?,source_url:r.get(3)?,updated:r.get(4)?,agent:r.get(5)?})).optional()?)
}
pub fn eligible(id: i64) -> Result<bool> {
    Ok(resolve(id)?.is_some())
}
pub async fn now_next(id: i64) -> Result<NowNext> {
    let at = Utc::now().timestamp();
    let data = load(id, false).await?;
    let Some(mut p) = data else {
        return Ok(Default::default());
    };
    p.sort_by_key(|p| p.start);
    Ok(NowNext {
        supported: true,
        now: p
            .iter()
            .filter(|p| p.start <= at && at < p.stop)
            .max_by_key(|p| p.start)
            .cloned(),
        next: p.into_iter().find(|p| p.start > at),
    })
}
pub async fn schedule(id: i64, from: i64, to: i64) -> Result<ProgrammeList> {
    crate::epg::validate_window(from, to)?;
    let data = load(id, true).await?;
    Ok(match data {
        None => Default::default(),
        Some(p) => ProgrammeList {
            supported: true,
            programmes: p
                .into_iter()
                .filter(|p| p.start < to && p.stop > from)
                .take(2048)
                .collect(),
            catchup_supported: false,
            archive_days: 0,
        },
    })
}
fn full_enabled(full: bool) -> Result<bool> {
    Ok(!full || crate::settings::get_settings()?.enable_full_guide != Some(false))
}
fn cached(identity: &Identity) -> Result<Option<Vec<Programme>>> {
    let mut cache = CACHE
        .lock()
        .map_err(|_| anyhow!("XMLTV cache unavailable"))?;
    cache.retain(|c| c.fetched.elapsed() < Duration::from_secs(900));
    let hit = cache.iter().position(|c| {
        c.identity.source == identity.source
            && c.identity.url == identity.url
            && c.identity.source_url == identity.source_url
            && c.identity.updated == identity.updated
            && c.identity.agent == identity.agent
    });
    Ok(hit.map(|index| {
        let entry = cache.remove(index);
        let programmes = entry
            .data
            .get(&identity.epg_id)
            .cloned()
            .unwrap_or_default();
        cache.push(entry);
        programmes
    }))
}
async fn load(id: i64, full: bool) -> Result<Option<Vec<Programme>>> {
    if !full_enabled(full)? {
        return Ok(None);
    }
    let Some(identity) = resolve(id)? else {
        return Ok(None);
    };
    if let Some(programmes) = cached(&identity)? {
        return Ok(Some(programmes));
    }
    let _load = tokio::time::timeout(Duration::from_secs(8), LOAD.lock())
        .await
        .map_err(|_| anyhow!("XMLTV load busy"))?;
    if !full_enabled(full)? || resolve(id)?.as_ref() != Some(&identity) {
        bail!("XMLTV source or settings changed");
    }
    if let Some(programmes) = cached(&identity)? {
        return Ok(Some(programmes));
    }
    let _permit = crate::epg::REQUESTS
        .try_acquire()
        .map_err(|_| anyhow!("EPG requests busy"))?;
    let body = tokio::time::timeout(Duration::from_secs(8), read(&identity))
        .await
        .map_err(|_| anyhow!("XMLTV request timed out"))??;
    let data = tokio::task::spawn_blocking(move || parse_compressed(&body, Utc::now().timestamp()))
        .await
        .map_err(|_| anyhow!("XMLTV parser unavailable"))??;
    if !full_enabled(full)? || resolve(id)?.as_ref() != Some(&identity) {
        bail!("XMLTV source or settings changed");
    }
    let result = data.get(&identity.epg_id).cloned().unwrap_or_default();
    let mut cache = CACHE
        .lock()
        .map_err(|_| anyhow!("XMLTV cache unavailable"))?;
    cache.retain(|c| c.identity.source != identity.source);
    if cache.len() >= MAX_CACHED_SOURCES {
        cache.remove(0);
    }
    cache.push(Cache {
        identity,
        fetched: Instant::now(),
        data,
    });
    Ok(Some(result))
}
async fn read(identity: &Identity) -> Result<Vec<u8>> {
    if let Ok(url) = reqwest::Url::parse(&identity.url) {
        if url.scheme() == "file" {
            let path = url
                .to_file_path()
                .map_err(|_| anyhow!("XMLTV file invalid"))?;
            return read_file(path).await;
        }
        if !matches!(url.scheme(), "http" | "https") {
            bail!("XMLTV URL invalid");
        }
        let client = reqwest::Client::builder()
            .referer(false)
            .connect_timeout(Duration::from_secs(2))
            .timeout(Duration::from_secs(8))
            .redirect(reqwest::redirect::Policy::limited(3))
            .build()
            .map_err(|_| anyhow!("XMLTV client unavailable"))?;
        // Wire and decompressed payloads have separate caps.
        let mut response = client
            .get(url)
            .header("Accept-Encoding", "identity")
            .header("User-Agent", identity.agent.as_deref().unwrap_or("brenTV"))
            .send()
            .await
            .map_err(|_| anyhow!("XMLTV request failed"))?
            .error_for_status()
            .map_err(|_| anyhow!("XMLTV request failed"))?;
        if response
            .headers()
            .get("content-encoding")
            .is_some_and(|v| v != "identity" && v != "gzip")
            || response
                .content_length()
                .is_some_and(|n| n > MAX_BYTES as u64)
        {
            bail!("XMLTV response unsupported or too large");
        }
        let mut body = Vec::new();
        while let Some(chunk) = response
            .chunk()
            .await
            .map_err(|_| anyhow!("XMLTV response failed"))?
        {
            if chunk.len() > MAX_BYTES - body.len() {
                bail!("XMLTV response too large");
            }
            body.extend_from_slice(&chunk);
        }
        Ok(body)
    } else {
        read_file(identity.url.clone().into()).await
    }
}
async fn read_file(path: std::path::PathBuf) -> Result<Vec<u8>> {
    use tokio::io::AsyncReadExt;
    let metadata = tokio::fs::metadata(&path)
        .await
        .map_err(|_| anyhow!("XMLTV file unavailable"))?;
    if !metadata.is_file() || metadata.len() > MAX_BYTES as u64 {
        bail!("XMLTV file unsupported or too large");
    }
    let file = tokio::fs::File::open(path)
        .await
        .map_err(|_| anyhow!("XMLTV file unavailable"))?;
    let mut body = Vec::new();
    file.take((MAX_BYTES + 1) as u64)
        .read_to_end(&mut body)
        .await
        .map_err(|_| anyhow!("XMLTV file failed"))?;
    if body.len() > MAX_BYTES {
        bail!("XMLTV file too large");
    }
    Ok(body)
}
fn timestamp(s: &str) -> Option<i64> {
    DateTime::parse_from_str(s, "%Y%m%d%H%M%S %z")
        .map(|d| d.timestamp())
        .or_else(|_| {
            NaiveDateTime::parse_from_str(s, "%Y%m%d%H%M%S").map(|d| d.and_utc().timestamp())
        })
        .ok()
        .filter(|t| *t >= 0)
}
fn parse_compressed(body: &[u8], now: i64) -> Result<HashMap<String, Vec<Programme>>> {
    if body.len() > MAX_BYTES {
        bail!("XMLTV response too large");
    }
    if body.starts_with(&[0x1f, 0x8b]) {
        use std::io::Read;
        let mut decoded = Vec::new();
        flate2::read::MultiGzDecoder::new(body)
            .take((MAX_BYTES + 1) as u64)
            .read_to_end(&mut decoded)
            .map_err(|_| anyhow!("XMLTV compressed document invalid"))?;
        if decoded.len() > MAX_BYTES {
            bail!("XMLTV decoded document too large");
        }
        parse(&decoded, now)
    } else {
        parse(body, now)
    }
}
fn parse(body: &[u8], now: i64) -> Result<HashMap<String, Vec<Programme>>> {
    if body.len() > MAX_BYTES {
        bail!("XMLTV response too large");
    }
    let mut reader = Reader::from_reader(body);
    let mut data: HashMap<String, Vec<Programme>> = HashMap::new();
    let mut current: Option<(String, i64, i64, String)> = None;
    let mut in_title = false;
    let mut title_seen = false;
    let mut count = 0;
    let mut depth = 0usize;
    let mut root = false;
    loop {
        match reader
            .read_event()
            .map_err(|_| anyhow!("XMLTV document invalid"))?
        {
            Event::Empty(e) if depth == 0 && e.name().as_ref() == b"tv" => {
                if root {
                    bail!("XMLTV root invalid");
                }
                root = true;
            }
            // quick-xml never fetches the external DTD. Internal subsets stay
            // unsupported, and unknown entity references still fail below.
            Event::DocType(e) if e.as_ref().contains(&b'[') => {
                bail!("XMLTV internal DTD unsupported")
            }
            Event::Start(e) => {
                depth += 1;
                if depth > 32 {
                    bail!("XMLTV nesting excessive");
                }
                if depth == 1 {
                    if e.name().as_ref() != b"tv" {
                        bail!("XMLTV root invalid");
                    }
                    if root {
                        bail!("XMLTV root invalid");
                    }
                    root = true;
                }
                if e.name().as_ref() == b"programme" {
                    title_seen = false;
                    count += 1;
                    if count > MAX_ENTRIES {
                        bail!("XMLTV too many entries");
                    }
                    let mut id = None;
                    let mut start = None;
                    let mut stop = None;
                    for a in e.attributes() {
                        let a = a.map_err(|_| anyhow!("XMLTV attribute invalid"))?;
                        let v = a
                            .normalized_value(XmlVersion::Implicit1_0)
                            .map_err(|_| anyhow!("XMLTV attribute invalid"))?;
                        match a.key.as_ref() {
                            b"channel" => id = Some(v.into_owned()),
                            b"start" => start = timestamp(&v),
                            b"stop" => stop = timestamp(&v),
                            _ => (),
                        }
                    }
                    current = match (id, start, stop) {
                        (Some(id), Some(a), Some(b))
                            if !id.is_empty()
                                && id.len() <= 512
                                && b > a
                                && b - a <= 86400
                                && b > now - 7 * 86400
                                && a < now + 7 * 86400 =>
                        {
                            Some((id, a, b, String::new()))
                        }
                        _ => None,
                    };
                }
                if e.name().as_ref() == b"title" {
                    in_title = !title_seen;
                    title_seen = true;
                }
            }
            Event::Empty(e) if e.name().as_ref() == b"title" => title_seen = true,
            Event::Text(e) if in_title => {
                if let Some((_, _, _, title)) = &mut current
                    && title.len() < 4096
                {
                    title.push_str(
                        &e.xml11_content()
                            .map_err(|_| anyhow!("XMLTV text invalid"))?,
                    );
                }
            }
            Event::CData(e) if in_title => {
                if let Some((_, _, _, title)) = &mut current
                    && title.len() < 4096
                {
                    title.push_str(&e.decode().map_err(|_| anyhow!("XMLTV text invalid"))?);
                }
            }
            Event::GeneralRef(e) if in_title => {
                if let Some((_, _, _, title)) = &mut current {
                    let name = e.decode().map_err(|_| anyhow!("XMLTV text invalid"))?;
                    let value = quick_xml::escape::unescape(&format!("&{name};"))
                        .map_err(|_| anyhow!("XMLTV entity unsupported"))?
                        .into_owned();
                    if title.len() < 4096 {
                        title.push_str(&value);
                    }
                }
            }
            Event::End(e) => {
                depth = depth.saturating_sub(1);
                if e.name().as_ref() == b"title" {
                    in_title = false;
                }
                if e.name().as_ref() == b"programme"
                    && let Some((id, start, stop, title)) = current.take()
                {
                    let title = crate::epg::normalize(&title);
                    if !title.is_empty() {
                        data.entry(id).or_default().push(Programme {
                            title,
                            start,
                            stop,
                            catchup_available: false,
                        });
                    }
                }
            }
            Event::Eof => break,
            _ => (),
        }
    }
    if !root || depth != 0 {
        bail!("XMLTV document incomplete");
    }
    for list in data.values_mut() {
        list.sort_by_key(|p| (p.start, p.stop));
        list.dedup();
    }
    Ok(data)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn local_file_limits() {
        let dir = std::env::temp_dir().join(format!("brentv-xmltv-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        assert!(read_file(dir.clone()).await.is_err());
        let path = dir.join("guide.xml");
        std::fs::write(&path, b"<tv/>").unwrap();
        assert_eq!(read_file(path.clone()).await.unwrap(), b"<tv/>");
        std::fs::OpenOptions::new()
            .write(true)
            .open(&path)
            .unwrap()
            .set_len((MAX_BYTES + 1) as u64)
            .unwrap();
        assert!(read_file(path).await.is_err());
        std::fs::remove_dir_all(dir).unwrap();
    }
    #[test]
    fn offsets_exact_ids_and_malformed() {
        assert_eq!(
            timestamp("20260101010000 +0100"),
            timestamp("20260101000000 +0000")
        );
        assert_eq!(
            timestamp("20260101000000"),
            timestamp("20260101000000 +0000")
        );
        let at = timestamp("20260101000000 +0000").unwrap();
        let body=br#"<tv><programme channel="Exact.ID" start="20260101000000 +0000" stop="20260101010000 +0000"><title>A &amp; B</title></programme><programme channel="bad" start="bad" stop="bad"><title>bad</title></programme></tv>"#;
        let data = parse(body, at).unwrap();
        assert_eq!(data.len(), 1);
        assert_eq!(data["Exact.ID"][0].title, "A & B");
        assert!(!data.contains_key("exact.id"));
        let standard = br#"<!DOCTYPE tv SYSTEM "xmltv.dtd"><tv><programme channel="exact" start="20260101000000" stop="20260101010000"><title lang="en">News</title><title lang="de">Nachrichten</title></programme></tv>"#;
        assert_eq!(parse(standard, at).unwrap()["exact"][0].title, "News");
        let unknown = br#"<!DOCTYPE tv SYSTEM "file:///missing.dtd"><tv><programme channel="exact" start="20260101000000" stop="20260101010000"><title>&external;</title></programme></tv>"#;
        assert!(parse(unknown, at).is_err());
        assert!(
            parse(
                b"<!DOCTYPE tv [<!ENTITY x SYSTEM 'file:///secret'>]><tv/>",
                at
            )
            .is_err()
        );
        assert!(parse(b"<tv><programme>", at).is_err());
    }
    #[test]
    fn gzip_decoding_is_bounded() {
        use std::io::Write;
        let mut gzip = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
        gzip.write_all(b"<tv/>").unwrap();
        assert!(
            parse_compressed(&gzip.finish().unwrap(), 0)
                .unwrap()
                .is_empty()
        );
        let mut gzip = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
        gzip.write_all(&vec![b' '; MAX_BYTES + 1]).unwrap();
        assert_eq!(
            parse_compressed(&gzip.finish().unwrap(), 0)
                .unwrap_err()
                .to_string(),
            "XMLTV decoded document too large"
        );
    }
}
