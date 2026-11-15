#[allow(dead_code, clippy::enum_variant_names)]
#[path = "../src/generated_proto.rs"]
mod proto;
use prost::Message;
use std::{
    sync::{Mutex, mpsc},
    time::Instant,
};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

type Ffi = extern "C" fn(u64, extern "C" fn(u64, *mut u8, usize), *const u8, usize);
static ANSWER: Mutex<Option<mpsc::Sender<Vec<u8>>>> = Mutex::new(None);
extern "C" fn callback(_: u64, ptr: *mut u8, len: usize) {
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec();
    brentv_core::free_message(ptr, len);
    ANSWER
        .lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .send(bytes)
        .unwrap();
}
fn call(f: Ffi, message: &impl Message) -> proto::FfiResult {
    let (tx, rx) = mpsc::channel();
    *ANSWER.lock().unwrap() = Some(tx);
    let bytes = message.encode_to_vec();
    f(1, callback, bytes.as_ptr(), bytes.len());
    let result = proto::FfiResult::decode(rx.recv().unwrap().as_slice()).unwrap();
    assert!(result.success, "{:?}", result.error_message);
    result
}
fn latency(label: &str, filters: proto::Filters) {
    let mut times = Vec::new();
    for _ in 0..31 {
        let now = Instant::now();
        call(brentv_core::get_channels, &filters);
        times.push(now.elapsed().as_secs_f64() * 1000.0);
    }
    times.sort_by(f64::total_cmp);
    println!("{label}: median={:.3}ms p95={:.3}ms", times[15], times[29]);
}
fn main() {
    let kind = std::env::args().nth(1).unwrap_or_else(|| "m3u".into());
    let dir = std::env::temp_dir().join(format!(
        "brentv-bench-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    std::fs::create_dir_all(&dir).unwrap();
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let listener = runtime
        .block_on(tokio::net::TcpListener::bind("127.0.0.1:0"))
        .unwrap();
    let address = listener.local_addr().unwrap();
    let mut lists = Vec::new();
    let mut m3u = String::from("#EXTM3U\n");
    for (mt, total) in [(0, 100_000), (1, 50_000), (2, 10_000)] {
        let mut list = Vec::with_capacity(total);
        for i in 0..total {
            let name = format!(
                "{} {} {:06}",
                ["Live", "Movie", "Series"][mt],
                if i % 10 == 0 {
                    "News"
                } else if i % 7 == 0 {
                    "Sport HD"
                } else {
                    "Entertainment"
                },
                i
            );
            let url = format!(
                "http://127.0.0.1/{}/{i}{}",
                ["live", "movie", "series"][mt],
                if mt == 1 { ".mp4" } else { ".ts" }
            );
            m3u.push_str(&format!(
                "#EXTINF:-1 group-title=\"Category {}\",{name}\n{url}\n",
                i % 100
            ));
            list.push(serde_json::json!({"stream_id":i+1,"series_id":i+1,"name":name,"category_id":(i%100).to_string(),"container_extension":"mp4"}));
        }
        lists.push(serde_json::to_vec(&list).unwrap());
    }
    let cats=serde_json::to_vec(&(0..100).map(|i|serde_json::json!({"category_id":i.to_string(),"category_name":format!("Category {i}")})).collect::<Vec<_>>()).unwrap();
    let lists = std::sync::Arc::new(lists);
    let cats = std::sync::Arc::new(cats);
    runtime.spawn(async move {
        loop {
            let (mut socket, _) = listener.accept().await.unwrap();
            let (lists, cats) = (lists.clone(), cats.clone());
            tokio::spawn(async move {
                let mut buf = [0; 8192];
                let n = socket.read(&mut buf).await.unwrap();
                let text = String::from_utf8_lossy(&buf[..n]);
                let index = if text.contains("get_vod") {
                    1
                } else if text.contains("get_series") {
                    2
                } else {
                    0
                };
                let body = if text.contains("categories") {
                    cats.as_slice()
                } else {
                    lists[index].as_slice()
                };
                socket
                    .write_all(
                        format!(
                            "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                            body.len()
                        )
                        .as_bytes(),
                    )
                    .await
                    .unwrap();
                socket.write_all(body).await.unwrap();
            });
        }
    });
    let fixture = dir.join("fixture.m3u");
    std::fs::write(&fixture, m3u).unwrap();
    call(
        brentv_core::initialize,
        &proto::InitMessage {
            db_path: dir.to_string_lossy().into(),
            temp_path: dir.to_string_lossy().into(),
        },
    );
    let mut src = proto::Source {
        name: "bench".into(),
        url: Some(if kind == "xtream" {
            format!("http://{address}/player_api.php")
        } else {
            fixture.to_string_lossy().into()
        }),
        username: Some("fixture".into()),
        password: Some("fixture".into()),
        source_type: if kind == "xtream" { 2 } else { 0 },
        enabled: true,
        ..Default::default()
    };
    let now = Instant::now();
    call(brentv_core::process_source, &src);
    println!("{kind} import: {:.3}s", now.elapsed().as_secs_f64());
    src.id = Some(1);
    let filters = proto::Filters {
        source_ids: vec![1],
        media_types: vec![0, 1, 2],
        page: 1,
        ..Default::default()
    };
    let result = call(brentv_core::get_channels, &filters);
    if let Some(proto::ffi_result::Data::ChannelList(channels)) = result.data {
        for channel in channels.channels.iter().take(20) {
            let id = channel.id.unwrap();
            call(
                brentv_core::favorite,
                &proto::ToggleFavorite {
                    channel_id: id,
                    favorite: true,
                },
            );
            call(
                brentv_core::add_last_watched,
                &proto::IdMessage { value: id },
            );
        }
    }
    let now = Instant::now();
    call(brentv_core::refresh_source, &src);
    println!("refresh: {:.3}s", now.elapsed().as_secs_f64());
    latency(
        "provider page 1",
        proto::Filters {
            sort: 2,
            ..filters.clone()
        },
    );
    latency(
        "provider page 200",
        proto::Filters {
            sort: 2,
            page: 200,
            ..filters.clone()
        },
    );
    latency("all page 1", filters.clone());
    latency(
        "search news",
        proto::Filters {
            query: Some("news".into()),
            ..filters.clone()
        },
    );
    latency(
        "keywords sport hd",
        proto::Filters {
            query: Some("sport hd".into()),
            use_keywords: true,
            ..filters.clone()
        },
    );
    latency(
        "page 200",
        proto::Filters {
            page: 200,
            ..filters.clone()
        },
    );
    latency(
        "categories",
        proto::Filters {
            view_type: 1,
            ..filters.clone()
        },
    );
    latency(
        "favorites",
        proto::Filters {
            view_type: 2,
            ..filters.clone()
        },
    );
    latency(
        "history",
        proto::Filters {
            view_type: 3,
            ..filters
        },
    );
    println!(
        "{}",
        std::fs::read_to_string("/proc/self/status")
            .unwrap()
            .lines()
            .find(|l| l.starts_with("VmHWM"))
            .unwrap()
    );
    let size: u64 = std::fs::read_dir(&dir)
        .unwrap()
        .map(|p| p.unwrap())
        .filter(|p| {
            p.file_name()
                .to_string_lossy()
                .starts_with("db_rust.sqlite")
        })
        .map(|p| p.metadata().unwrap().len())
        .sum();
    println!("DB including WAL: {size} bytes");
    let db = rusqlite::Connection::open(dir.join("db_rust.sqlite")).unwrap();
    let state: (i64, i64, i64) = db
        .query_row(
            "SELECT count(*),sum(favorite>0),count(last_watched) FROM channels",
            [],
            |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
        )
        .unwrap();
    assert_eq!(state, (160_000, 20, 20));
    println!(
        "State: channels={} favorites={} history={}",
        state.0, state.1, state.2
    );
    drop(db);
    std::fs::remove_dir_all(&dir).unwrap();
}
