//! A loopback relay for live streams Apple's player cannot open itself.
//!
//! `open` fetches the provider's MPEG-TS over TLS and reads its program map,
//! so the app knows the codecs before choosing a player path. If the stream
//! needs repackaging, a local FFmpeg (built without TLS) reads the same
//! connection from `http://127.0.0.1:<port>/<token>/input.ts` and writes HLS
//! into the session directory, which this server hands to the player.
use crate::generated_proto::{RelayInfo, RelayRequest};
use anyhow::{Result, anyhow, bail};
use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    sync::{
        Arc, LazyLock, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};
use tokio::{
    io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt},
    net::{TcpListener, TcpStream},
};

const PACKET: usize = 188;
/// Enough for the program map even behind a long burst of video.
const PROBE_BYTES: usize = 3 * 1024 * 1024;

struct Session {
    request: RelayRequest,
    directory: PathBuf,
    closed: AtomicBool,
    /// The open provider response and what was read from it while probing.
    /// The first `input.ts` reader takes both, so no second connection is made.
    input: Mutex<Option<(reqwest::Response, Vec<u8>)>>,
}

static SESSIONS: LazyLock<Mutex<HashMap<String, Arc<Session>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static PORT: tokio::sync::OnceCell<u16> = tokio::sync::OnceCell::const_new();

fn token() -> Result<String> {
    let mut bytes = [0u8; 16];
    getrandom::fill(&mut bytes).map_err(|_| anyhow!("No random source"))?;
    Ok(bytes.iter().map(|b| format!("{b:02x}")).collect())
}

fn client(request: &RelayRequest) -> Result<reqwest::Client> {
    Ok(reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(10))
        .read_timeout(Duration::from_secs(15))
        .danger_accept_invalid_certs(request.ignore_ssl)
        .build()?)
}

async fn connect(request: &RelayRequest, range: Option<&str>) -> Result<reqwest::Response> {
    let url = reqwest::Url::parse(&request.url).map_err(|_| anyhow!("Invalid URL"))?;
    if !matches!(url.scheme(), "http" | "https") {
        bail!("Only HTTP streams can be relayed");
    }
    let mut get = client(request)?.get(url);
    for (name, value) in [
        (reqwest::header::USER_AGENT, &request.user_agent),
        (reqwest::header::REFERER, &request.referrer),
        (reqwest::header::ORIGIN, &request.http_origin),
    ] {
        if let Some(value) = value.as_deref().filter(|v| !v.is_empty()) {
            get = get.header(name, value);
        }
    }
    if let Some(range) = range {
        get = get.header(reqwest::header::RANGE, range);
    }
    let response = tokio::time::timeout(Duration::from_secs(12), get.send())
        .await
        .map_err(|_| anyhow!("Timed out"))?
        .map_err(|e| anyhow!("{}", e.without_url()))?;
    if !response.status().is_success() {
        bail!("HTTP status {}", response.status().as_u16());
    }
    Ok(response)
}

/// Codec names FFmpeg uses, for the elementary stream types of a program.
#[derive(Debug, Default, PartialEq)]
pub struct Program {
    pub video: String,
    pub audio: String,
}

fn stream_codec(kind: u8, descriptors: &[u8]) -> Option<(bool, &'static str)> {
    Some(match kind {
        0x01 => (true, "mpeg1video"),
        0x02 => (true, "mpeg2video"),
        0x10 => (true, "mpeg4"),
        0x1b => (true, "h264"),
        0x24 => (true, "hevc"),
        0x33 => (true, "vvc"),
        0x03 | 0x04 => (false, "mp2"),
        0x0f => (false, "aac"),
        0x11 => (false, "aac_latm"),
        0x81 => (false, "ac3"),
        0x87 => (false, "eac3"),
        0x82 | 0x85 | 0x86 | 0x8a => (false, "dts"),
        // Private data: DVB signals the codec in a descriptor.
        0x06 => {
            let mut rest = descriptors;
            let mut found = None;
            while rest.len() >= 2 {
                let (tag, len) = (rest[0], rest[1] as usize);
                let body = rest.get(2..2 + len)?;
                found = match (tag, body) {
                    (0x6a, _) => Some((false, "ac3")),
                    (0x7a, _) => Some((false, "eac3")),
                    (0x7b, _) => Some((false, "dts")),
                    (0x05, b"AC-3") => Some((false, "ac3")),
                    (0x05, b"EAC3") => Some((false, "eac3")),
                    (0x05, b"HEVC") => Some((true, "hevc")),
                    _ => found,
                };
                rest = &rest[2 + len..];
            }
            found?
        }
        _ => return None,
    })
}

/// Reads the first program's map from transport-stream bytes. `None` until
/// both tables have been seen in full, or if this is not a transport stream.
pub fn program(data: &[u8]) -> Option<Program> {
    // Packets are 188 bytes apart, each starting with 0x47.
    let start = (0..PACKET.min(data.len()))
        .find(|&offset| (0..5).all(|n| data.get(offset + n * PACKET) == Some(&0x47)))?;
    let mut map_pid = None;
    let mut section: Vec<u8> = Vec::new();
    let mut collecting = false;
    for packet in data[start..].as_chunks::<PACKET>().0 {
        if packet[0] != 0x47 {
            continue;
        }
        let pid = ((packet[1] as u16 & 0x1f) << 8) | packet[2] as u16;
        let starts = packet[1] & 0x40 != 0;
        let mut payload = match (packet[3] >> 4) & 3 {
            1 => &packet[4..],
            3 => packet.get(5 + packet[4] as usize..)?,
            _ => continue,
        };
        if pid != 0 && Some(pid) != map_pid {
            continue;
        }
        if starts {
            let pointer = *payload.first()? as usize;
            payload = payload.get(1 + pointer..)?;
            section.clear();
            collecting = true;
        } else if !collecting {
            continue;
        }
        section.extend_from_slice(payload);
        if section.len() < 3 {
            continue;
        }
        let length = 3 + (((section[1] as usize & 0x0f) << 8) | section[2] as usize);
        if section.len() < length {
            continue;
        }
        collecting = false;
        let table = &section[..length];
        if pid == 0 && table[0] == 0x00 {
            // Program association: (program number, map PID) pairs after an
            // 8-byte header, before a 4-byte checksum. Program 0 is the NIT.
            for entry in table.get(8..length.checked_sub(4)?)?.as_chunks::<4>().0 {
                if entry[0] != 0 || entry[1] != 0 {
                    map_pid = Some(((entry[2] as u16 & 0x1f) << 8) | entry[3] as u16);
                    break;
                }
            }
        } else if Some(pid) == map_pid && table[0] == 0x02 {
            let info = ((*table.get(10)? as usize & 0x0f) << 8) | *table.get(11)? as usize;
            let mut entries = table.get(12 + info..length.checked_sub(4)?)?;
            let mut found = Program::default();
            while entries.len() >= 5 {
                let size = ((entries[3] as usize & 0x0f) << 8) | entries[4] as usize;
                let descriptors = entries.get(5..5 + size)?;
                if let Some((video, codec)) = stream_codec(entries[0], descriptors) {
                    let slot = if video {
                        &mut found.video
                    } else {
                        &mut found.audio
                    };
                    if slot.is_empty() {
                        *slot = codec.to_string();
                    }
                }
                entries = &entries[5 + size..];
            }
            return Some(found);
        }
    }
    None
}

async fn port() -> Result<u16> {
    PORT.get_or_try_init(|| async {
        let listener = TcpListener::bind(("127.0.0.1", 0)).await?;
        let port = listener.local_addr()?.port();
        tokio::spawn(async move {
            loop {
                if let Ok((socket, _)) = listener.accept().await {
                    tokio::spawn(async move {
                        let _ = serve(socket).await;
                    });
                }
            }
        });
        anyhow::Ok(port)
    })
    .await
    .copied()
}

/// Connects to the stream, identifies its codecs and registers a session.
pub async fn open(request: RelayRequest) -> Result<RelayInfo> {
    let directory = PathBuf::from(&request.directory);
    if !directory.is_absolute() {
        bail!("Invalid folder");
    }
    // A file is fetched on demand, in whatever ranges its reader asks for.
    let mut input = None;
    let mut found = Program::default();
    if !request.seekable {
        let mut response = connect(&request, None).await?;
        let mut head = Vec::new();
        let mut map = None;
        let deadline = tokio::time::Instant::now() + Duration::from_secs(8);
        while map.is_none() && head.len() < PROBE_BYTES {
            match tokio::time::timeout_at(deadline, response.chunk()).await {
                Ok(Ok(Some(chunk))) => head.extend_from_slice(&chunk),
                _ => break,
            }
            map = program(&head);
        }
        found = map.unwrap_or_default();
        input = Some((response, head));
    }
    tokio::fs::create_dir_all(&directory).await?;
    let token = token()?;
    let port = port().await?;
    SESSIONS.lock().unwrap().insert(
        token.clone(),
        Arc::new(Session {
            request,
            directory,
            closed: AtomicBool::new(false),
            input: Mutex::new(input),
        }),
    );
    Ok(RelayInfo {
        token,
        port: port as u32,
        video: found.video,
        audio: found.audio,
    })
}

/// Ends a session: its provider connection closes and its files are refused.
pub fn close(token: &str) {
    if let Some(session) = SESSIONS.lock().unwrap().remove(token) {
        session.closed.store(true, Ordering::Relaxed);
        session.input.lock().unwrap().take();
    }
}

async fn head(socket: &mut TcpStream, status: &str, kind: &str, extra: &str) -> Result<()> {
    socket
        .write_all(
            format!(
                "HTTP/1.1 {status}\r\nContent-Type: {kind}\r\nCache-Control: no-store\r\nConnection: close\r\n{extra}\r\n"
            )
            .as_bytes(),
        )
        .await?;
    Ok(())
}

async fn refuse(socket: &mut TcpStream, status: &str) -> Result<()> {
    head(socket, status, "text/plain", "Content-Length: 0\r\n").await
}

async fn serve(mut socket: TcpStream) -> Result<()> {
    let mut request = Vec::new();
    let mut buffer = [0u8; 2048];
    while !request.windows(4).any(|w| w == b"\r\n\r\n") {
        let read =
            tokio::time::timeout(Duration::from_secs(10), socket.read(&mut buffer)).await??;
        if read == 0 || request.len() > 16 * 1024 {
            return Ok(());
        }
        request.extend_from_slice(&buffer[..read]);
    }
    let text = String::from_utf8_lossy(&request);
    let mut lines = text.split("\r\n");
    let mut first = lines.next().unwrap_or_default().split(' ');
    let (method, path) = (
        first.next().unwrap_or_default(),
        first.next().unwrap_or_default(),
    );
    if method != "GET" && method != "HEAD" {
        return refuse(&mut socket, "405 Method Not Allowed").await;
    }
    let path = path.split('?').next().unwrap_or_default();
    let mut parts = path.trim_start_matches('/').splitn(2, '/');
    let (token, name) = (
        parts.next().unwrap_or_default(),
        parts.next().unwrap_or_default(),
    );
    let session = SESSIONS.lock().unwrap().get(token).cloned();
    let Some(session) = session else {
        return refuse(&mut socket, "404 Not Found").await;
    };
    // One flat folder of generated files: no separators, no dot files.
    if name.is_empty()
        || name.starts_with('.')
        || !name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
    {
        return refuse(&mut socket, "404 Not Found").await;
    }
    let range = lines.find_map(|line| {
        let (key, value) = line.split_once(':')?;
        key.eq_ignore_ascii_case("range")
            .then(|| value.trim().to_string())
    });
    if session.request.seekable {
        if name.starts_with("input.") {
            return ranged(&mut socket, &session, range.as_deref(), method == "HEAD").await;
        }
    } else if name == "input.ts" {
        if method == "HEAD" {
            return head(&mut socket, "200 OK", "video/mp2t", "").await;
        }
        return input(&mut socket, &session).await;
    }
    let range = range.and_then(|value| {
        let (from, to) = value.strip_prefix("bytes=")?.split_once('-')?;
        Some((from.parse::<u64>().ok()?, to.parse::<u64>().ok()))
    });
    file(
        &mut socket,
        &session.directory.join(name),
        name,
        range,
        method == "HEAD",
    )
    .await
}

async fn file(
    socket: &mut TcpStream,
    path: &Path,
    name: &str,
    range: Option<(u64, Option<u64>)>,
    head_only: bool,
) -> Result<()> {
    let Ok(mut source) = tokio::fs::File::open(path).await else {
        return refuse(socket, "404 Not Found").await;
    };
    let size = source.metadata().await?.len();
    let kind = match name.rsplit('.').next() {
        Some("m3u8") => "application/vnd.apple.mpegurl",
        Some("mp4" | "m4s") => "video/mp4",
        Some("ts") => "video/mp2t",
        _ => "application/octet-stream",
    };
    let (from, to, status) = match range {
        Some((from, to)) if from < size => (
            from,
            to.unwrap_or(size - 1).min(size - 1),
            "206 Partial Content",
        ),
        Some(_) => {
            return head(
                socket,
                "416 Range Not Satisfiable",
                kind,
                &format!("Content-Range: bytes */{size}\r\nContent-Length: 0\r\n"),
            )
            .await;
        }
        None => (0, size.saturating_sub(1), "200 OK"),
    };
    let length = if size == 0 { 0 } else { to + 1 - from };
    let mut extra = format!("Accept-Ranges: bytes\r\nContent-Length: {length}\r\n");
    if range.is_some() {
        extra += &format!("Content-Range: bytes {from}-{to}/{size}\r\n");
    }
    head(socket, status, kind, &extra).await?;
    if head_only || length == 0 {
        return Ok(());
    }
    source.seek(std::io::SeekFrom::Start(from)).await?;
    tokio::io::copy(&mut source.take(length), socket).await?;
    Ok(())
}

/// Passes one request for a file through to the provider, range and all, so
/// a reader without TLS can seek in it.
async fn ranged(
    socket: &mut TcpStream,
    session: &Session,
    range: Option<&str>,
    head_only: bool,
) -> Result<()> {
    let Ok(mut response) = connect(&session.request, range).await else {
        return refuse(socket, "502 Bad Gateway").await;
    };
    let status = if response.status() == reqwest::StatusCode::PARTIAL_CONTENT {
        "206 Partial Content"
    } else {
        "200 OK"
    };
    let mut extra = String::from("Accept-Ranges: bytes\r\n");
    for name in [
        reqwest::header::CONTENT_LENGTH,
        reqwest::header::CONTENT_RANGE,
    ] {
        if let Some(value) = response.headers().get(&name).and_then(|v| v.to_str().ok()) {
            extra += &format!("{name}: {value}\r\n");
        }
    }
    head(socket, status, "application/octet-stream", &extra).await?;
    if head_only {
        return Ok(());
    }
    while !session.closed.load(Ordering::Relaxed) {
        match response.chunk().await {
            Ok(Some(chunk)) => socket.write_all(&chunk).await?,
            _ => break,
        }
    }
    Ok(())
}

/// Streams the provider's bytes until the reader leaves or the session ends.
/// A dropped provider connection is replaced, so a live stream keeps going.
async fn input(socket: &mut TcpStream, session: &Session) -> Result<()> {
    head(socket, "200 OK", "video/mp2t", "").await?;
    let taken = session.input.lock().unwrap().take();
    let (mut response, buffered) = match taken {
        Some((response, buffered)) => (Some(response), buffered),
        None => (None, Vec::new()),
    };
    socket.write_all(&buffered).await?;
    let mut failures = 0;
    while !session.closed.load(Ordering::Relaxed) {
        let Some(current) = response.as_mut() else {
            if failures >= 5 {
                break;
            }
            if failures > 0 {
                tokio::time::sleep(Duration::from_secs(1)).await;
            }
            match connect(&session.request, None).await {
                Ok(next) => response = Some(next),
                Err(_) => failures += 1,
            }
            continue;
        };
        match current.chunk().await {
            Ok(Some(chunk)) => {
                failures = 0;
                socket.write_all(&chunk).await?;
            }
            // The provider ended or dropped the stream: connect again.
            Ok(None) | Err(_) => {
                response = None;
                failures += 1;
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The relay's listener lives on the runtime that first used it, so the
    /// tests that reach it share one, as the app does.
    static RUNTIME: LazyLock<tokio::runtime::Runtime> =
        LazyLock::new(|| tokio::runtime::Runtime::new().unwrap());

    /// One transport packet carrying a complete table section.
    fn packet(pid: u16, section: &[u8]) -> Vec<u8> {
        let mut out = vec![0x47, 0x40 | (pid >> 8) as u8, pid as u8, 0x10, 0x00];
        out.extend_from_slice(section);
        out.resize(PACKET, 0xff);
        out
    }

    fn association(map_pid: u16) -> Vec<u8> {
        let mut body = vec![0x00, 0xb0, 13, 0, 1, 0xc1, 0, 0];
        body.extend_from_slice(&[0, 1, 0xe0 | (map_pid >> 8) as u8, map_pid as u8]);
        body.extend_from_slice(&[0; 4]);
        packet(0, &body)
    }

    fn map(pid: u16, streams: &[(u8, &[u8])]) -> Vec<u8> {
        let mut entries = Vec::new();
        for (index, (kind, descriptors)) in streams.iter().enumerate() {
            entries.extend_from_slice(&[*kind, 0xe1, index as u8, 0xf0, descriptors.len() as u8]);
            entries.extend_from_slice(descriptors);
        }
        let length = 9 + entries.len() + 4;
        let mut body = vec![0x02, 0xb0 | (length >> 8) as u8, length as u8];
        body.extend_from_slice(&[0, 1, 0xc1, 0, 0, 0xe1, 0x00, 0xf0, 0x00]);
        body.extend_from_slice(&entries);
        body.extend_from_slice(&[0; 4]);
        packet(pid, &body)
    }

    fn stream(streams: &[(u8, &[u8])]) -> Vec<u8> {
        let filler = packet(0x100, &[0; 20]);
        // Junk before the first packet, as when joining a stream midway.
        let mut out = vec![0x12, 0x47, 0x00];
        for _ in 0..6 {
            out.extend_from_slice(&filler);
        }
        out.extend_from_slice(&association(0x1000));
        out.extend_from_slice(&filler);
        out.extend_from_slice(&map(0x1000, streams));
        for _ in 0..6 {
            out.extend_from_slice(&filler);
        }
        out
    }

    #[test]
    fn program_map_names_the_codecs() {
        let codecs = |streams: &[(u8, &[u8])]| {
            let found = program(&stream(streams)).unwrap();
            (found.video, found.audio)
        };
        assert_eq!(
            codecs(&[(0x1b, &[]), (0x0f, &[])]),
            ("h264".into(), "aac".into())
        );
        assert_eq!(
            codecs(&[(0x24, &[]), (0x0f, &[])]),
            ("hevc".into(), "aac".into())
        );
        assert_eq!(
            codecs(&[(0x02, &[]), (0x03, &[])]),
            ("mpeg2video".into(), "mp2".into())
        );
        // DVB carries AC-3 as private data named by a descriptor; the first
        // audio stream wins and unknown streams are ignored.
        assert_eq!(
            codecs(&[
                (0x1b, &[]),
                (0x05, &[]),
                (0x06, &[0x0a, 1, 0, 0x6a, 1, 0]),
                (0x0f, &[])
            ]),
            ("h264".into(), "ac3".into())
        );
        assert_eq!(codecs(&[(0x0f, &[])]), (String::new(), "aac".into()));
        // Not a transport stream, and a stream cut before its map.
        assert_eq!(program(b"#EXTM3U\n#EXT-X-VERSION:3\n"), None);
        let whole = stream(&[(0x24, &[])]);
        assert_eq!(program(&whole[..3 + PACKET * 8]), None);
    }

    async fn get(port: u32, path: &str, range: Option<&str>) -> (String, Vec<u8>) {
        let mut socket = TcpStream::connect(("127.0.0.1", port as u16))
            .await
            .unwrap();
        let range = range.map(|r| format!("Range: {r}\r\n")).unwrap_or_default();
        socket
            .write_all(format!("GET {path} HTTP/1.1\r\nHost: x\r\n{range}\r\n").as_bytes())
            .await
            .unwrap();
        let mut all = Vec::new();
        let _ = tokio::time::timeout(Duration::from_secs(5), socket.read_to_end(&mut all)).await;
        let split = all.windows(4).position(|w| w == b"\r\n\r\n").unwrap();
        (
            String::from_utf8_lossy(&all[..split]).into_owned(),
            all[split + 4..].to_vec(),
        )
    }

    #[test]
    fn relays_one_connection_then_reconnects_and_serves_only_its_folder() {
        RUNTIME.block_on(relays_one_connection_then_reconnects_and_serves_only_its_folder_body());
    }

    async fn relays_one_connection_then_reconnects_and_serves_only_its_folder_body() {
        // A provider that sends the stream once per connection, then hangs up.
        let data = stream(&[(0x24, &[]), (0x0f, &[])]);
        let provider = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/live/u/p/1.ts", provider.local_addr().unwrap());
        let connections = Arc::new(Mutex::new(Vec::new()));
        let (log, body) = (connections.clone(), data.clone());
        tokio::spawn(async move {
            loop {
                let (mut socket, _) = provider.accept().await.unwrap();
                let (log, body) = (log.clone(), body.clone());
                tokio::spawn(async move {
                    let mut request = vec![0u8; 4096];
                    let read = socket.read(&mut request).await.unwrap_or(0);
                    let text = String::from_utf8_lossy(&request[..read]).to_lowercase();
                    let count = {
                        let mut log = log.lock().unwrap();
                        log.push(text.contains("user-agent: brentv-test"));
                        log.len()
                    };
                    let _ = socket
                        .write_all(b"HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n")
                        .await;
                    let _ = socket.write_all(&body).await;
                    if count >= 2 {
                        // Stay open so the relay has no reason to dial again.
                        tokio::time::sleep(Duration::from_secs(30)).await;
                    }
                });
            }
        });
        let folder = tempfile::tempdir().unwrap();
        let info = open(RelayRequest {
            url,
            user_agent: Some("brentv-test".into()),
            directory: folder.path().join("live").to_string_lossy().into_owned(),
            ..Default::default()
        })
        .await
        .unwrap();
        assert_eq!((info.video.as_str(), info.audio.as_str()), ("hevc", "aac"));
        assert_eq!(info.token.len(), 32);

        // The probed bytes are replayed, then the second connection follows.
        let (head, body) = get(info.port, &format!("/{}/input.ts", info.token), None).await;
        assert!(head.starts_with("HTTP/1.1 200"));
        assert_eq!(body, [data.clone(), data.clone()].concat());
        assert_eq!(*connections.lock().unwrap(), [true, true]);

        let live = folder.path().join("live");
        std::fs::write(live.join("live.m3u8"), "#EXTM3U\n").unwrap();
        std::fs::write(live.join("seg1.m4s"), b"0123456789").unwrap();
        std::fs::write(folder.path().join("secret.txt"), "no").unwrap();
        let (head, body) = get(info.port, &format!("/{}/live.m3u8", info.token), None).await;
        assert!(head.contains("application/vnd.apple.mpegurl") && body == b"#EXTM3U\n");
        let (head, body) = get(
            info.port,
            &format!("/{}/seg1.m4s", info.token),
            Some("bytes=2-5"),
        )
        .await;
        assert!(head.starts_with("HTTP/1.1 206") && head.contains("bytes 2-5/10"));
        assert_eq!(body, b"2345");
        for path in [
            format!("/{}/../secret.txt", info.token),
            format!("/{}/..%2Fsecret.txt", info.token),
            format!("/{}/missing.m4s", info.token),
            "/00000000000000000000000000000000/live.m3u8".to_string(),
        ] {
            assert!(
                get(info.port, &path, None)
                    .await
                    .0
                    .starts_with("HTTP/1.1 404"),
                "{path}"
            );
        }
        close(&info.token);
        let (head, _) = get(info.port, &format!("/{}/live.m3u8", info.token), None).await;
        assert!(head.starts_with("HTTP/1.1 404"));
    }

    #[test]
    fn a_dead_channel_is_an_error_and_a_playlist_has_no_codecs() {
        RUNTIME.block_on(a_dead_channel_is_an_error_and_a_playlist_has_no_codecs_body());
    }

    async fn a_dead_channel_is_an_error_and_a_playlist_has_no_codecs_body() {
        let provider = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = provider.local_addr().unwrap();
        tokio::spawn(async move {
            loop {
                let (mut socket, _) = provider.accept().await.unwrap();
                tokio::spawn(async move {
                    let mut request = vec![0u8; 4096];
                    let read = socket.read(&mut request).await.unwrap_or(0);
                    let dead = String::from_utf8_lossy(&request[..read]).contains("/dead.ts");
                    let reply: &[u8] = if dead {
                        b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    } else {
                        b"HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n#EXTM3U\n#EXTINF:2,\nseg.ts\n"
                    };
                    let _ = socket.write_all(reply).await;
                });
            }
        });
        let folder = tempfile::tempdir().unwrap();
        let request = |name: &str| RelayRequest {
            url: format!("http://{address}/{name}"),
            directory: folder.path().to_string_lossy().into_owned(),
            ..Default::default()
        };
        assert!(open(request("dead.ts")).await.is_err());
        let info = open(request("list.m3u8")).await.unwrap();
        assert_eq!((info.video.as_str(), info.audio.as_str()), ("", ""));
        close(&info.token);
    }

    #[test]
    fn a_file_is_fetched_on_demand_with_the_readers_ranges() {
        RUNTIME.block_on(a_file_is_fetched_on_demand_with_the_readers_ranges_body());
    }

    async fn a_file_is_fetched_on_demand_with_the_readers_ranges_body() {
        let provider = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = provider.local_addr().unwrap();
        tokio::spawn(async move {
            loop {
                let (mut socket, _) = provider.accept().await.unwrap();
                tokio::spawn(async move {
                    let mut request = vec![0u8; 4096];
                    let read = socket.read(&mut request).await.unwrap_or(0);
                    let text = String::from_utf8_lossy(&request[..read]).to_lowercase();
                    let reply = if text.contains("range: bytes=4-") {
                        "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes 4-9/10\r\nContent-Length: 6\r\nConnection: close\r\n\r\n456789"
                    } else {
                        "HTTP/1.1 200 OK\r\nContent-Length: 10\r\nConnection: close\r\n\r\n0123456789"
                    };
                    let _ = socket.write_all(reply.as_bytes()).await;
                });
            }
        });
        let folder = tempfile::tempdir().unwrap();
        let info = open(RelayRequest {
            url: format!("http://{address}/movie/u/p/1.mkv"),
            directory: folder.path().to_string_lossy().into_owned(),
            seekable: true,
            ..Default::default()
        })
        .await
        .unwrap();
        let path = format!("/{}/input.mkv", info.token);
        let (head, body) = get(info.port, &path, None).await;
        assert!(
            head.starts_with("HTTP/1.1 200") && head.to_lowercase().contains("content-length: 10")
        );
        assert_eq!(body, b"0123456789");
        let (head, body) = get(info.port, &path, Some("bytes=4-")).await;
        assert!(head.starts_with("HTTP/1.1 206") && head.to_lowercase().contains("bytes 4-9/10"));
        assert_eq!(body, b"456789");
        close(&info.token);
    }
}
