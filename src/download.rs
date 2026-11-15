//! Ranged, resumable file transfers. Dart owns the queue and its saved state;
//! this module moves the bytes, which dart:io does several times slower.
use crate::generated_proto::{DownloadRequest, DownloadStatus};
use anyhow::{Result, anyhow, bail};
use reqwest::{StatusCode, header};
use std::{
    collections::HashMap,
    path::Path,
    sync::{
        Arc, LazyLock, Mutex,
        atomic::{AtomicBool, AtomicI64, Ordering},
    },
    time::Duration,
};
use tokio::io::AsyncWriteExt;

#[derive(Default)]
struct Progress {
    bytes: AtomicI64,
    total: AtomicI64,
    stop: AtomicBool,
    validators: Mutex<(Option<String>, Option<String>)>,
}

static ACTIVE: LazyLock<Mutex<HashMap<String, Arc<Progress>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// A problem the user must see; retrying the same request cannot fix it.
#[derive(Debug)]
struct Failure(&'static str);

fn fail<T>(message: &'static str) -> Result<T, Outcome> {
    Err(Outcome::Failure(Failure(message)))
}

enum Outcome {
    Failure(Failure),
    Retry(anyhow::Error),
}

impl<E: Into<anyhow::Error>> From<E> for Outcome {
    fn from(e: E) -> Self {
        Outcome::Retry(e.into())
    }
}

impl Progress {
    fn status(&self) -> DownloadStatus {
        let (etag, last_modified) = self.validators.lock().unwrap().clone();
        DownloadStatus {
            bytes: self.bytes.load(Ordering::Relaxed),
            total: self.total.load(Ordering::Relaxed),
            etag,
            last_modified,
            ..Default::default()
        }
    }
}

pub fn progress(id: &str) -> DownloadStatus {
    match ACTIVE.lock().unwrap().get(id) {
        Some(p) => DownloadStatus {
            active: true,
            ..p.status()
        },
        None => DownloadStatus::default(),
    }
}

pub fn stop(id: &str) {
    if let Some(p) = ACTIVE.lock().unwrap().get(id) {
        p.stop.store(true, Ordering::Relaxed);
    }
}

pub async fn download(request: DownloadRequest) -> Result<DownloadStatus> {
    let progress = Arc::new(Progress::default());
    progress.total.store(request.total, Ordering::Relaxed);
    *progress.validators.lock().unwrap() = (request.etag.clone(), request.last_modified.clone());
    {
        let mut active = ACTIVE.lock().unwrap();
        match active.entry(request.id.clone()) {
            std::collections::hash_map::Entry::Vacant(entry) => {
                entry.insert(progress.clone());
            }
            std::collections::hash_map::Entry::Occupied(_) => {
                bail!("This download is already running");
            }
        }
    }
    let result = transfer(&request, &progress).await;
    ACTIVE.lock().unwrap().remove(&request.id);
    let mut status = progress.status();
    match result {
        Ok(()) => {
            status.stopped = progress.stop.load(Ordering::Relaxed) && status.bytes != status.total;
            status.finished = !status.stopped;
            Ok(status)
        }
        Err(Outcome::Failure(Failure(message))) => {
            status.failure = Some(message.to_string());
            Ok(status)
        }
        Err(Outcome::Retry(e)) => Err(e),
    }
}

async fn truncate(part: &Path, progress: &Progress) -> Result<()> {
    tokio::fs::write(part, []).await?;
    progress.bytes.store(0, Ordering::Relaxed);
    progress.total.store(0, Ordering::Relaxed);
    *progress.validators.lock().unwrap() = (None, None);
    Ok(())
}

fn text(headers: &header::HeaderMap, name: header::HeaderName) -> Option<String> {
    headers.get(name)?.to_str().ok().map(str::to_string)
}

/// `bytes START-END/TOTAL`
fn content_range(value: &str) -> Option<(i64, i64, i64)> {
    let (range, total) = value.strip_prefix("bytes ")?.split_once('/')?;
    let (start, end) = range.split_once('-')?;
    Some((start.parse().ok()?, end.parse().ok()?, total.parse().ok()?))
}

async fn transfer(request: &DownloadRequest, progress: &Progress) -> Result<(), Outcome> {
    let url = reqwest::Url::parse(&request.url).map_err(|_| anyhow!("Invalid URL"))?;
    if !matches!(url.scheme(), "http" | "https") {
        return fail("Only HTTP videos can be downloaded.");
    }
    let part = Path::new(&request.part_path);
    let folder = part.parent().ok_or_else(|| anyhow!("Invalid folder"))?;
    tokio::fs::create_dir_all(folder).await?;
    let mut offset = match tokio::fs::metadata(part).await {
        Ok(m) => m.len() as i64,
        Err(_) => 0,
    };
    let (mut etag, mut modified) = (request.etag.clone(), request.last_modified.clone());
    let mut total = request.total;
    // Many providers send neither ETag nor Last-Modified. Their partial files
    // are then validated by the total size the server reports on resume.
    if offset > 0 && etag.is_none() && modified.is_none() && total <= 0 {
        truncate(part, progress).await?;
        offset = 0;
    }
    let client = reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(15))
        .read_timeout(Duration::from_secs(30))
        .danger_accept_invalid_certs(request.ignore_ssl)
        .build()?;
    for _ in 0..2 {
        if progress.stop.load(Ordering::Relaxed) {
            return Ok(());
        }
        let mut get = client
            .get(url.clone())
            .header(header::ACCEPT_ENCODING, "identity");
        if let Some(v) = &request.user_agent {
            get = get.header(header::USER_AGENT, v);
        }
        if let Some(v) = &request.referrer {
            get = get.header(header::REFERER, v);
        }
        if let Some(v) = &request.http_origin {
            get = get.header(header::ORIGIN, v);
        }
        if offset > 0 {
            get = get.header(header::RANGE, format!("bytes={offset}-"));
            if let Some(v) = etag.as_ref().or(modified.as_ref()) {
                get = get.header(header::IF_RANGE, v);
            }
        }
        let mut response = tokio::time::timeout(Duration::from_secs(30), get.send())
            .await
            .map_err(|_| anyhow!("Timed out"))?
            .map_err(|e| anyhow!("{}", e.without_url()))?;
        let headers = response.headers().clone();
        let strong = text(&headers, header::ETAG).filter(|e| !e.starts_with("W/"));
        let new_modified = text(&headers, header::LAST_MODIFIED);
        let range = text(&headers, header::CONTENT_RANGE).unwrap_or_default();
        let status = response.status();
        if status == StatusCode::RANGE_NOT_SATISFIABLE {
            let size: Option<i64> = range.strip_prefix("bytes */").and_then(|s| s.parse().ok());
            let valid = match &etag {
                Some(saved) => strong.as_ref() == Some(saved),
                None => new_modified.is_some() && new_modified == modified,
            };
            if offset > 0 && size == Some(offset) && size == Some(total) && valid {
                progress.bytes.store(offset, Ordering::Relaxed);
                return Ok(());
            }
            truncate(part, progress).await?;
            (offset, total, etag, modified) = (0, 0, None, None);
            continue;
        }
        if status != StatusCode::OK && status != StatusCode::PARTIAL_CONTENT {
            return Err(anyhow!("HTTP status {}", status.as_u16()).into());
        }
        if text(&headers, header::CONTENT_ENCODING).is_some_and(|e| e != "identity") {
            return fail(
                "The server compressed this file; a safe resumable download is unavailable.",
            );
        }
        let kind = text(&headers, header::CONTENT_TYPE)
            .unwrap_or_default()
            .to_lowercase();
        if ["mpegurl", "text/html", "application/json"]
            .iter()
            .any(|t| kind.contains(t))
        {
            return fail(
                "This URL is a playlist or webpage. Downloads require a direct video file.",
            );
        }
        let length = text(&headers, header::CONTENT_LENGTH).and_then(|v| v.parse::<i64>().ok());
        if status == StatusCode::PARTIAL_CONTENT {
            let Some((start, end, size)) = content_range(&range).filter(|r| r.0 == offset) else {
                return fail("The server returned an invalid resume range.");
            };
            if end < start || end >= size || length.is_some_and(|l| l != end - start + 1) {
                return fail("The server returned an invalid file size.");
            }
            let changed = offset > 0
                && (match &etag {
                    Some(saved) => Some(saved) != strong.as_ref(),
                    None => modified != new_modified,
                } || (total > 0 && total != size));
            if changed {
                truncate(part, progress).await?;
                (offset, total, etag, modified) = (0, 0, None, None);
                continue;
            }
            total = size;
        } else {
            offset = 0;
            total = length.unwrap_or(0);
        }
        if total <= 0 {
            return fail(
                "The server did not provide a file size. A complete download cannot be verified.",
            );
        }
        (etag, modified) = (strong, new_modified);
        progress.bytes.store(offset, Ordering::Relaxed);
        progress.total.store(total, Ordering::Relaxed);
        *progress.validators.lock().unwrap() = (etag.clone(), modified.clone());
        let available = crate::transfers::disk_space(&folder.to_string_lossy())?;
        if available < total - offset + request.reserved_bytes + 64 * 1024 * 1024 {
            return fail(
                "Not enough free disk space for this video. Free space or choose another folder in Settings > Downloads.",
            );
        }
        if progress.stop.load(Ordering::Relaxed) {
            return Ok(());
        }
        let file = tokio::fs::OpenOptions::new()
            .create(true)
            .write(true)
            .append(offset > 0)
            .truncate(offset == 0)
            .open(part)
            .await?;
        let mut output = tokio::io::BufWriter::with_capacity(1 << 20, file);
        let mut written = offset;
        let mut outcome = Ok(());
        while !progress.stop.load(Ordering::Relaxed) {
            match response.chunk().await {
                Ok(Some(chunk)) => {
                    if written + chunk.len() as i64 > total {
                        outcome = fail("The server sent more data than the declared file size.");
                        break;
                    }
                    if let Err(e) = output.write_all(&chunk).await {
                        outcome = Err(e.into());
                        break;
                    }
                    written += chunk.len() as i64;
                    progress.bytes.store(written, Ordering::Relaxed);
                }
                Ok(None) => break,
                Err(e) => {
                    outcome = Err(anyhow!("{}", e.without_url()).into());
                    break;
                }
            }
        }
        // What reached the buffer must reach the file, so a resume starts at
        // the byte the saved progress says it does.
        output.flush().await?;
        output.get_ref().sync_data().await?;
        let on_disk = tokio::fs::metadata(part).await?.len() as i64;
        progress.bytes.store(on_disk, Ordering::Relaxed);
        outcome?;
        if !progress.stop.load(Ordering::Relaxed) && on_disk != total {
            return Err(anyhow!("Incomplete file").into());
        }
        return Ok(());
    }
    fail("The server changed the file while resuming. Retry to start again.")
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    type Respond = Arc<dyn Fn(Option<i64>, Option<String>) -> (String, Vec<u8>) + Send + Sync>;

    /// Serves every connection with `respond(range start, If-Range)`, which
    /// returns the status line plus extra headers, and the body.
    async fn serve(respond: Respond) -> (String, Arc<Mutex<Vec<Option<i64>>>>) {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/video.mkv", listener.local_addr().unwrap());
        let seen = Arc::new(Mutex::new(Vec::new()));
        let log = seen.clone();
        tokio::spawn(async move {
            loop {
                let Ok((mut socket, _)) = listener.accept().await else {
                    return;
                };
                let (respond, log) = (respond.clone(), log.clone());
                tokio::spawn(async move {
                    let mut request = Vec::new();
                    let mut buffer = [0u8; 1024];
                    while !request.windows(4).any(|w| w == b"\r\n\r\n") {
                        match socket.read(&mut buffer).await {
                            Ok(n) if n > 0 => request.extend_from_slice(&buffer[..n]),
                            _ => return,
                        }
                    }
                    let request = String::from_utf8_lossy(&request).to_lowercase();
                    let find = |name: &str| {
                        request
                            .lines()
                            .find_map(|l| l.strip_prefix(name))
                            .map(|v| v.trim().to_string())
                    };
                    let start = find("range: bytes=")
                        .and_then(|v| v.trim_end_matches('-').parse::<i64>().ok());
                    log.lock().unwrap().push(start);
                    let (head, body) = respond(start, find("if-range:"));
                    let head = format!("HTTP/1.1 {head}connection: close\r\n\r\n");
                    let _ = socket.write_all(head.as_bytes()).await;
                    for piece in body.chunks(4096) {
                        if socket.write_all(piece).await.is_err() {
                            return;
                        }
                        tokio::time::sleep(Duration::from_micros(200)).await;
                    }
                });
            }
        });
        (url, seen)
    }

    fn data() -> Vec<u8> {
        (0..256 * 1024).map(|i| (i % 251) as u8).collect()
    }

    /// A server that honours Range and reports `total` as the file size.
    fn ranged(total: i64, etag: &'static str) -> Respond {
        Arc::new(move |start, _| {
            let body = data();
            let tag = if etag.is_empty() {
                String::new()
            } else {
                format!("etag: {etag}\r\n")
            };
            match start {
                Some(s) => (
                    format!(
                        "206 Partial Content\r\ncontent-type: video/x-matroska\r\n{tag}content-range: bytes {s}-{}/{total}\r\ncontent-length: {}\r\n",
                        body.len() - 1,
                        body.len() as i64 - s
                    ),
                    body[s as usize..].to_vec(),
                ),
                None => (
                    format!(
                        "200 OK\r\ncontent-type: video/x-matroska\r\n{tag}content-length: {}\r\n",
                        body.len()
                    ),
                    body,
                ),
            }
        })
    }

    fn request(id: &str, url: &str, part: &Path) -> DownloadRequest {
        DownloadRequest {
            id: id.to_string(),
            url: url.to_string(),
            part_path: part.to_string_lossy().into_owned(),
            ..Default::default()
        }
    }

    #[tokio::test]
    async fn downloads_then_resumes_by_size_without_validators() {
        let folder = tempfile::tempdir().unwrap();
        let part = folder.path().join("sub/Movie.mkv.part");
        let (url, seen) = serve(ranged(data().len() as i64, "")).await;
        let status = download(request("fresh", &url, &part)).await.unwrap();
        assert!(status.finished && status.failure.is_none());
        assert_eq!(status.total, data().len() as i64);
        assert_eq!(std::fs::read(&part).unwrap(), data());

        std::fs::write(&part, &data()[..10000]).unwrap();
        let mut resume = request("resume", &url, &part);
        resume.total = data().len() as i64;
        let status = download(resume).await.unwrap();
        assert!(status.finished);
        assert_eq!(*seen.lock().unwrap(), [None, Some(10000)]);
        assert_eq!(std::fs::read(&part).unwrap(), data());
    }

    #[tokio::test]
    async fn a_changed_file_is_never_appended_to() {
        let folder = tempfile::tempdir().unwrap();
        let part = folder.path().join("Movie.mkv.part");
        // Saved size differs from what the server now reports.
        let (url, seen) = serve(ranged(data().len() as i64, "")).await;
        std::fs::write(&part, vec![7u8; 10000]).unwrap();
        let mut changed = request("size", &url, &part);
        changed.total = data().len() as i64 - 1;
        assert!(download(changed).await.unwrap().finished);
        assert_eq!(*seen.lock().unwrap(), [Some(10000), None]);
        assert_eq!(std::fs::read(&part).unwrap(), data());

        // Saved ETag differs: the server ignores the range and sends it all.
        let ignoring: Respond = Arc::new(|_, if_range| {
            assert_eq!(if_range.as_deref(), Some("\"old\""));
            (
                format!(
                    "200 OK\r\netag: \"new\"\r\ncontent-length: {}\r\n",
                    data().len()
                ),
                data(),
            )
        });
        let (url, _) = serve(ignoring).await;
        std::fs::write(&part, vec![7u8; 10000]).unwrap();
        let mut stale = request("etag", &url, &part);
        stale.total = data().len() as i64;
        stale.etag = Some("\"old\"".to_string());
        let status = download(stale).await.unwrap();
        assert!(status.finished);
        assert_eq!(status.etag.as_deref(), Some("\"new\""));
        assert_eq!(std::fs::read(&part).unwrap(), data());
    }

    #[tokio::test]
    async fn failures_and_retries_are_told_apart() {
        let folder = tempfile::tempdir().unwrap();
        let part = folder.path().join("Movie.mkv.part");
        let playlist: Respond = Arc::new(|_, _| {
            (
                "200 OK\r\ncontent-type: application/vnd.apple.mpegurl\r\ncontent-length: 7\r\n"
                    .to_string(),
                b"#EXTM3U".to_vec(),
            )
        });
        let (url, _) = serve(playlist).await;
        let status = download(request("playlist", &url, &part)).await.unwrap();
        assert!(status.failure.unwrap().contains("playlist"));
        assert!(!status.finished);

        let unsized_: Respond = Arc::new(|_, _| ("200 OK\r\n".to_string(), data()));
        let (url, _) = serve(unsized_).await;
        let status = download(request("unsized", &url, &part)).await.unwrap();
        assert!(status.failure.unwrap().contains("file size"));

        let busy: Respond =
            Arc::new(|_, _| ("503 Busy\r\ncontent-length: 0\r\n".to_string(), Vec::new()));
        let (url, _) = serve(busy).await;
        assert!(download(request("busy", &url, &part)).await.is_err());

        // The connection drops halfway: retry later, keeping what arrived.
        let short: Respond = Arc::new(|_, _| {
            (
                format!("200 OK\r\ncontent-length: {}\r\n", data().len()),
                data()[..50000].to_vec(),
            )
        });
        let (url, _) = serve(short).await;
        assert!(download(request("short", &url, &part)).await.is_err());
        assert_eq!(std::fs::read(&part).unwrap(), &data()[..50000]);
    }

    #[tokio::test]
    async fn duplicate_id_preserves_the_running_transfer() {
        let folder = tempfile::tempdir().unwrap();
        let part = folder.path().join("Movie.mkv.part");
        let (url, _) = serve(ranged(data().len() as i64, "\"v1\"")).await;
        let running = tokio::spawn(download(request("duplicate", &url, &part)));
        tokio::time::timeout(Duration::from_secs(5), async {
            while progress("duplicate").bytes == 0 {
                tokio::time::sleep(Duration::from_millis(1)).await;
            }
        })
        .await
        .unwrap();
        let incumbent = ACTIVE.lock().unwrap()["duplicate"].clone();
        assert!(download(request("duplicate", &url, &part)).await.is_err());
        assert!(Arc::ptr_eq(
            &incumbent,
            &ACTIVE.lock().unwrap()["duplicate"]
        ));
        stop("duplicate");
        let status = running.await.unwrap().unwrap();
        assert!(status.stopped);
        assert_eq!(std::fs::metadata(part).unwrap().len() as i64, status.bytes);
        assert!(!progress("duplicate").active);
    }

    #[tokio::test]
    async fn stop_keeps_a_consistent_partial_file() {
        let folder = tempfile::tempdir().unwrap();
        let part = folder.path().join("Movie.mkv.part");
        let (url, _) = serve(ranged(data().len() as i64, "\"v1\"")).await;
        let running = tokio::spawn(download(request("stoppable", &url, &part)));
        loop {
            let now = progress("stoppable");
            if now.active && now.bytes > 0 {
                assert_eq!(now.total, data().len() as i64);
                assert_eq!(now.etag.as_deref(), Some("\"v1\""));
                break;
            }
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
        stop("stoppable");
        let status = running.await.unwrap().unwrap();
        assert!(status.stopped && !status.finished);
        let saved = std::fs::read(&part).unwrap();
        assert_eq!(saved.len() as i64, status.bytes);
        assert_eq!(saved, &data()[..saved.len()]);
        assert!(!progress("stoppable").active);
    }
}
