//! Bounded HLS master probes. Variant URLs are informational; playback keeps
//! the master so separate audio and subtitle renditions remain attached.

use std::{
    collections::{HashMap, HashSet},
    sync::OnceLock,
    time::Duration,
};

use anyhow::{Result, anyhow, bail};
use reqwest::{
    Url,
    header::{HeaderMap, HeaderValue, ORIGIN, REFERER, USER_AGENT},
};

use crate::generated_proto::{StreamVariant, StreamVariantList, StreamVariantsRequest};

const MAX_PLAYLIST: usize = 512 * 1024;
const MAX_PREFIX: usize = 4096;

fn http_error(e: reqwest::Error) -> anyhow::Error {
    anyhow!(crate::redact::redact(&e.without_url().to_string(), &[]))
}

fn headers(channel_id: i64) -> Result<HeaderMap> {
    let conn = crate::sql::get_conn()?;
    let (ua, referrer, origin): (Option<String>, Option<String>, Option<String>) = conn.query_row(
        "SELECT COALESCE(NULLIF(h.user_agent,''),NULLIF(s.stream_user_agent,''),NULLIF(s.user_agent,''),'brenTV'), h.referrer,h.http_origin
         FROM channels c JOIN sources s ON s.id=c.source_id LEFT JOIN channel_http_headers h ON h.channel_id=c.id WHERE c.id=?",
        [channel_id], |r| Ok((r.get(0)?,r.get(1)?,r.get(2)?)))?;
    let mut headers = HeaderMap::new();
    for (name, value) in [(USER_AGENT, ua), (REFERER, referrer), (ORIGIN, origin)] {
        if let Some(value) = value.filter(|s| !s.is_empty()) {
            headers.insert(
                name,
                HeaderValue::from_str(&value).map_err(|_| anyhow!("Invalid stream HTTP header"))?,
            );
        }
    }
    Ok(headers)
}

pub async fn get_variants(req: StreamVariantsRequest) -> Result<StreamVariantList> {
    let result = probe(&req.url, headers(req.channel_id)?).await;
    result.map_err(|e| anyhow!(crate::redact::error(&e, &[])))
}

async fn probe(url: &str, headers: HeaderMap) -> Result<StreamVariantList> {
    static CLIENT: OnceLock<reqwest::Client> = OnceLock::new();
    let client = if let Some(client) = CLIENT.get() {
        client.clone()
    } else {
        let client = reqwest::Client::builder()
            .referer(false)
            .timeout(Duration::from_secs(8))
            .build()
            .map_err(http_error)?;
        CLIENT.get_or_init(|| client).clone()
    };
    let mut response = client
        .get(url)
        .headers(headers)
        .send()
        .await
        .map_err(http_error)?
        .error_for_status()
        .map_err(http_error)?;
    let master = response.url().clone();
    let mut body = Vec::new();
    let mut hls = false;
    while let Some(chunk) = response.chunk().await.map_err(http_error)? {
        // Before recognising the signature, inspect at most a few KiB even
        // when the server sends an enormous first chunk or only whitespace.
        let limit = if hls { MAX_PLAYLIST } else { MAX_PREFIX };
        let take = chunk.len().min(limit - body.len());
        body.extend_from_slice(&chunk[..take]);
        if !hls {
            let prefix = body.iter().position(|b| !b.is_ascii_whitespace());
            if let Some(start) = prefix {
                let bytes = &body[start..];
                let n = bytes.len().min(7);
                if bytes[..n] != b"#EXTM3U"[..n] {
                    return Ok(StreamVariantList {
                        master_url: master.to_string(),
                        variants: vec![],
                    });
                }
                hls = bytes.len() >= 7;
            }
            if !hls && body.len() == MAX_PREFIX {
                return Ok(StreamVariantList {
                    master_url: master.to_string(),
                    variants: vec![],
                });
            }
            if hls {
                let rest = &chunk[take..];
                if body.len() + rest.len() > MAX_PLAYLIST {
                    bail!("HLS playlist exceeds 512 KiB limit");
                }
                body.extend_from_slice(rest);
            }
        }
        if body.len() == MAX_PLAYLIST {
            bail!("HLS playlist exceeds 512 KiB limit");
        }
    }
    Ok(StreamVariantList {
        variants: if hls {
            parse(&String::from_utf8_lossy(&body), &master)
        } else {
            vec![]
        },
        master_url: master.to_string(),
    })
}

fn attributes(line: &str) -> HashMap<&str, &str> {
    let mut quoted = false;
    line.split(|c| {
        if c == '"' {
            quoted = !quoted;
        }
        c == ',' && !quoted
    })
    .filter_map(|part| part.split_once('='))
    .map(|(key, value)| (key.trim(), value.trim().trim_matches('"')))
    .collect()
}

fn parse(body: &str, base: &Url) -> Vec<StreamVariant> {
    let mut pending = None;
    let mut seen = HashSet::new();
    let mut variants = Vec::new();
    for line in body.lines().map(str::trim).filter(|s| !s.is_empty()) {
        if let Some(attrs) = line.strip_prefix("#EXT-X-STREAM-INF:") {
            pending = Some(attributes(attrs));
        } else if !line.starts_with('#') {
            let Some(attrs) = pending.take() else {
                continue;
            };
            let Ok(url) = base.join(line) else { continue };
            if !matches!(url.scheme(), "http" | "https") || !seen.insert(url.to_string()) {
                continue;
            }
            let resolution = attrs
                .get("RESOLUTION")
                .and_then(|s| s.split_once('x'))
                .and_then(|(w, h)| Some((w.parse::<u32>().ok()?, h.parse::<u32>().ok()?)));
            variants.push(StreamVariant {
                url: url.to_string(),
                bandwidth: attrs
                    .get("BANDWIDTH")
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(0),
                average_bandwidth: attrs.get("AVERAGE-BANDWIDTH").and_then(|s| s.parse().ok()),
                width: resolution.map(|r| r.0),
                height: resolution.map(|r| r.1),
                frame_rate: attrs
                    .get("FRAME-RATE")
                    .and_then(|s| s.parse::<f64>().ok())
                    .filter(|v| v.is_finite() && *v > 0.0),
                codecs: attrs.get("CODECS").map(|s| s.to_string()),
                name: attrs.get("NAME").map(|s| s.to_string()),
            });
        }
    }
    variants
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::{
        io::{AsyncReadExt, AsyncWriteExt},
        net::TcpListener,
    };

    #[test]
    fn master_attributes_and_audio_renditions() {
        let _db_guard = crate::sql::test_lock();
        let base = Url::parse("http://localhost/redirected/master.m3u8").unwrap();
        let body = "#EXTM3U\r\n\
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"English\",URI=\"audio/en.m3u8\"\r\n\
#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=100,URI=\"iframe.m3u8\"\r\n\
#EXT-X-STREAM-INF:BANDWIDTH=1280000,AVERAGE-BANDWIDTH=1000000,RESOLUTION=1280x720,FRAME-RATE=59.940,CODECS=\"avc1.4d401f,mp4a.40.2\",AUDIO=\"audio\"\r\n\
../720.m3u8\r\n\
#EXT-X-STREAM-INF:BANDWIDTH=2560000,AUDIO=\"audio\"\r\n\
http://localhost/full.m3u8\r\n\
#EXT-X-STREAM-INF:BANDWIDTH=2560000\r\n\
http://localhost/full.m3u8\r\n\
#EXT-X-STREAM-INF:NAME=\"Unknown, quality\"\r\n\
//localhost/missing.m3u8\r\n";
        let variants = parse(body, &base);
        assert_eq!(variants.len(), 3);
        assert_eq!(variants[0].url, "http://localhost/720.m3u8");
        assert_eq!(variants[0].bandwidth, 1280000);
        assert_eq!(variants[0].average_bandwidth, Some(1000000));
        assert_eq!(
            (variants[0].width, variants[0].height),
            (Some(1280), Some(720))
        );
        assert_eq!(variants[0].frame_rate, Some(59.94));
        assert_eq!(variants[0].codecs.as_deref(), Some("avc1.4d401f,mp4a.40.2"));
        assert_eq!(variants[1].bandwidth, 2560000);
        assert_eq!(variants[2].bandwidth, 0);
        assert_eq!(variants[2].width, None);
        assert_eq!(variants[2].name.as_deref(), Some("Unknown, quality"));
        assert!(parse("#EXTM3U\n#EXTINF:10\nsegment.ts\n", &base).is_empty());
        assert!(
            parse(
                "#EXTM3U\n#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=100,URI=\"i.m3u8\"",
                &base
            )
            .is_empty()
        );
    }

    async fn request(socket: &mut tokio::net::TcpStream) -> String {
        let mut bytes = Vec::new();
        loop {
            let mut buf = [0; 1024];
            let n = socket.read(&mut buf).await.unwrap();
            if n == 0 {
                break;
            }
            bytes.extend_from_slice(&buf[..n]);
            if bytes.windows(4).any(|s| s == b"\r\n\r\n") {
                break;
            }
        }
        String::from_utf8(bytes).unwrap()
    }

    #[tokio::test]
    async fn persistent_probes_isolate_headers() {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let server = tokio::spawn(async move {
            let mut tasks = Vec::new();
            // Sequential probes must share the first connection. Concurrent
            // probes can open a second while the first is busy.
            for count in [3, 1] {
                let (mut socket, _) = listener.accept().await.unwrap();
                tasks.push(tokio::spawn(async move {
                    for _ in 0..count {
                        let req = request(&mut socket).await.to_lowercase();
                        let path = req.split_whitespace().nth(1).unwrap();
                        for header in ["user-agent", "referer", "origin"] {
                            if path == "/absent" {
                                assert!(!req.contains(&format!("{header}:")), "{req}");
                            } else {
                                let value = path.trim_start_matches('/');
                                assert!(req.contains(&format!("{header}: {value}\r\n")), "{req}");
                            }
                        }
                        socket
                            .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 8\r\n\r\n#EXTM3U\n")
                            .await
                            .unwrap();
                    }
                }));
            }
            for task in tasks {
                task.await.unwrap();
            }
        });
        let run = |value: &'static str| async move {
            let mut headers = HeaderMap::new();
            if value != "absent" {
                for name in [USER_AGENT, REFERER, ORIGIN] {
                    headers.insert(name, HeaderValue::from_static(value));
                }
            }
            probe(&format!("http://{addr}/{value}"), headers)
                .await
                .unwrap();
        };
        tokio::time::timeout(Duration::from_secs(5), async {
            run("first").await;
            run("absent").await;
            tokio::join!(run("second"), run("absent"));
            server.await.unwrap();
        })
        .await
        .unwrap();
    }

    #[tokio::test]
    async fn redirects_and_channel_headers() {
        let _db_guard = crate::sql::test_lock_async().await;
        crate::sql::test_db();
        let id = crate::sql::do_tx(|tx| {
            tx.execute("INSERT INTO sources(name,user_agent,stream_user_agent) VALUES ('hls-headers','source-agent','stream-agent')",[])?;
            let source = tx.last_insert_rowid();
            tx.execute("INSERT INTO channels(source_id,name,media_type) VALUES (?,'Probe',0)",[source])?;
            let id = tx.last_insert_rowid();
            tx.execute("INSERT INTO channel_http_headers(channel_id,user_agent,referrer,http_origin) VALUES (?,'channel-agent','http://localhost/ref','http://localhost')",[id])?;
            Ok(id)
        }).unwrap();
        assert_eq!(headers(id).unwrap()[USER_AGENT], "channel-agent");
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let server = tokio::spawn(async move {
            for index in 0..2 {
                let (mut socket, _) = listener.accept().await.unwrap();
                let request = request(&mut socket).await.to_lowercase();
                assert!(request.contains("user-agent: channel-agent"));
                assert!(request.contains("referer: http://localhost/ref"));
                assert!(request.contains("origin: http://localhost"));
                if index == 0 {
                    socket.write_all(b"HTTP/1.1 302 Found\r\nLocation: /nested/master.m3u8\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").await.unwrap();
                } else {
                    assert!(request.starts_with("get /nested/master.m3u8 "));
                    let body = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=4000\nlow.m3u8\n";
                    socket.write_all(format!("HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).as_bytes()).await.unwrap();
                }
            }
        });
        let result = get_variants(StreamVariantsRequest {
            channel_id: id,
            url: format!("http://{addr}/start"),
        })
        .await
        .unwrap();
        assert_eq!(
            result.master_url,
            format!("http://{addr}/nested/master.m3u8")
        );
        assert_eq!(
            result.variants[0].url,
            format!("http://{addr}/nested/low.m3u8")
        );
        server.await.unwrap();
        crate::sql::do_tx(|tx| {
            tx.execute(
                "UPDATE channel_http_headers SET user_agent=NULL WHERE channel_id=?",
                [id],
            )?;
            Ok(())
        })
        .unwrap();
        assert_eq!(headers(id).unwrap()[USER_AGENT], "stream-agent");
        crate::sql::do_tx(|tx| {
            tx.execute(
                "UPDATE sources SET stream_user_agent=NULL WHERE name='hls-headers'",
                [],
            )?;
            Ok(())
        })
        .unwrap();
        assert_eq!(headers(id).unwrap()[USER_AGENT], "source-agent");
        crate::sql::do_tx(|tx| {
            tx.execute(
                "UPDATE sources SET user_agent=NULL WHERE name='hls-headers'",
                [],
            )?;
            Ok(())
        })
        .unwrap();
        assert_eq!(headers(id).unwrap()[USER_AGENT], "brenTV");
    }

    #[tokio::test]
    async fn bounded_probe_and_non_hls_early_abort() {
        let _db_guard = crate::sql::test_lock_async().await;
        for prefix in [
            b"transport stream".as_slice(),
            b"   transport stream",
            &[b' '; MAX_PREFIX],
        ] {
            let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
            let addr = listener.local_addr().unwrap();
            let prefix = prefix.to_vec();
            let server = tokio::spawn(async move {
                let (mut socket, _) = listener.accept().await.unwrap();
                request(&mut socket).await;
                socket
                    .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 100000000\r\n\r\n")
                    .await
                    .unwrap();
                socket.write_all(&prefix).await.unwrap();
                // Remain open until the client closes, rather than completing
                // the body: reading to EOF would hit the test timeout.
                let mut byte = [0; 1];
                assert_eq!(socket.read(&mut byte).await.unwrap(), 0);
            });
            let result = tokio::time::timeout(
                Duration::from_secs(2),
                probe(&format!("http://{addr}/live.ts"), HeaderMap::new()),
            )
            .await
            .unwrap()
            .unwrap();
            assert!(result.variants.is_empty());
            tokio::time::timeout(Duration::from_secs(2), server)
                .await
                .unwrap()
                .unwrap();
        }
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let server = tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            request(&mut socket).await;
            socket
                .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 100000000\r\n\r\n#EXTM3U\n")
                .await
                .unwrap();
            let chunk = vec![b' '; 4096];
            loop {
                if socket.write_all(&chunk).await.is_err() {
                    break;
                }
            }
        });
        let error = tokio::time::timeout(
            Duration::from_secs(2),
            probe(&format!("http://{addr}/master"), HeaderMap::new()),
        )
        .await
        .unwrap()
        .unwrap_err();
        assert!(error.to_string().contains("512 KiB"));
        tokio::time::timeout(Duration::from_secs(2), server)
            .await
            .unwrap()
            .unwrap();
    }

    #[tokio::test]
    async fn credential_errors_are_redacted() {
        let _db_guard = crate::sql::test_lock_async().await;
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let server = tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            request(&mut socket).await;
            socket
                .write_all(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
                .await
                .unwrap();
        });
        // Synthetic fixture credentials only.
        let error = probe(&format!("http://fixtureuser:fixturepass@{addr}/live/fixtureuser/fixturepass/1.ts?token=fixturetoken"),HeaderMap::new()).await.unwrap_err();
        let error = format!("{error:#}");
        for secret in ["fixtureuser", "fixturepass", "fixturetoken"] {
            assert!(!error.contains(secret), "{error}");
        }
        server.await.unwrap();
        let error = probe(
            "http://[bad/username=fixtureuser&password=fixturepass",
            HeaderMap::new(),
        )
        .await
        .unwrap_err();
        assert!(!format!("{error:#}").contains("fixturepass"));
    }
}
