use crate::{generated_proto::SetCategories, m3u, sql, types::Source, xtream};
use serde_json::json;
use std::sync::{Arc, Mutex};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

mod episodes;

fn source(name: &str, url: String, kind: u8) -> Source {
    sql::test_db();
    sql::save_source(Source {
        id: None,
        name: name.into(),
        url: Some(url),
        url_origin: None,
        epg_url: None,
        username: Some("synthetic-user".into()),
        password: Some("synthetic-password".into()),
        source_type: kind,
        enabled: true,
        user_agent: None,
        stream_user_agent: None,
        last_updated: None,
        import_live: true,
        import_movies: true,
        import_series: true,
        last_refresh_stats: None,
    })
    .unwrap()
}

struct Server {
    url: String,
    requests: Arc<Mutex<Vec<String>>>,
    fail: Arc<Mutex<Vec<String>>>,
    corrupt: Arc<Mutex<u8>>,
    task: tokio::task::JoinHandle<()>,
}
impl Drop for Server {
    fn drop(&mut self) {
        self.task.abort();
    }
}
impl Server {
    async fn new() -> Self {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/player_api.php", listener.local_addr().unwrap());
        let requests = Arc::new(Mutex::new(Vec::new()));
        let fail = Arc::new(Mutex::new(Vec::new()));
        let corrupt = Arc::new(Mutex::new(0));
        let (log, errors, corrupt_data) = (requests.clone(), fail.clone(), corrupt.clone());
        let task = tokio::spawn(async move {
            loop {
                let (mut socket, _) = listener.accept().await.unwrap();
                let (log, errors, corrupt_data) =
                    (log.clone(), errors.clone(), corrupt_data.clone());
                tokio::spawn(async move {
                    let mut bytes = vec![0; 8192];
                    let n = socket.read(&mut bytes).await.unwrap();
                    let request = String::from_utf8_lossy(&bytes[..n]);
                    let path = request.split_whitespace().nth(1).unwrap().to_string();
                    log.lock().unwrap().push(path.clone());
                    let parsed = reqwest::Url::parse(&format!("http://local{path}")).unwrap();
                    let action = parsed
                        .query_pairs()
                        .find(|(k, _)| k == "action")
                        .unwrap()
                        .1
                        .to_string();
                    let failed = errors.lock().unwrap().contains(&action);
                    let corruption = *corrupt_data.lock().unwrap();
                    let body=if action == "get_series_info" {
                        json!({"seasons":[{"season_number":1}],"episodes":{"1":[{"id":"9001","title":"Episode 1","container_extension":"mp4","episode_num":1,"season":1},{"id":"9002","title":"Episode 2","container_extension":"mp4","episode_num":2,"season":1}]}})
                    } else if corruption == 3 || (corruption == 4 && action == "get_live_streams") {
                        json!([])
                    } else if action.ends_with("categories") {
                        json!((0..6).map(|id|json!({"category_id":id.to_string(),"category_name":format!("Category {id}")})).collect::<Vec<_>>())
                    } else {
                        // Deliberately ignore category_id, exercising the client-side filter.
                        json!((0..6).map(|id| {
                            let mut value=json!({"stream_id":id+10,"series_id":id+20,"name":format!("Channel {id}"),"category_id":id.to_string(),"tv_archive": if id==1 {0}else{1},"tv_archive_duration":if id==0 {2}else if id==1 {7}else{0}});
                            if id==0 { match *corrupt_data.lock().unwrap() { 1 => value["name"]=json!(null), 2 => value["stream_id"]=json!(null), _ => () } }
                            value
                        }).collect::<Vec<_>>())
                    }.to_string();
                    let status = if failed { "500 Failed" } else { "200 OK" };
                    let response = format!(
                        "HTTP/1.1 {status}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    socket.write_all(response.as_bytes()).await.unwrap();
                });
            }
        });
        Self {
            url,
            requests,
            fail,
            corrupt,
            task,
        }
    }
}
fn rows(id: i64, mt: u8) -> Vec<i64> {
    sql::get_conn()
        .unwrap()
        .prepare("SELECT id FROM channels WHERE source_id=? AND media_type=? ORDER BY id")
        .unwrap()
        .query_map(rusqlite::params![id, mt], |r| r.get(0))
        .unwrap()
        .collect::<Result<_, _>>()
        .unwrap()
}
fn rules(id: i64, mt: u32, mode: i32, listed: &[&str]) {
    sql::set_source_categories(SetCategories {
        source_id: id,
        media_type: mt,
        mode,
        listed: listed.iter().map(|s| s.to_string()).collect(),
    })
    .unwrap();
}

#[tokio::test]
async fn selective_categories_failures_and_identity() {
    let _db_guard = crate::sql::test_lock_async().await;
    let server = Server::new().await;
    let mut src = source("xtream-refresh-test", server.url.clone(), 2);
    src.import_series = false;
    sql::update_source(src.clone()).unwrap();
    let id = src.id.unwrap();
    rules(id, 0, 1, &["Category 1"]);
    let stats = xtream::get_xtream(src.clone(), false).await.unwrap();
    assert!(stats.success);
    assert_eq!(stats.types[0].imported, 1);
    assert_eq!(stats.types[0].excluded, 5);
    assert_eq!(stats.types[0].categories_excluded, 5);
    assert_eq!(rows(id, 1).len(), 6);
    let categories = sql::get_source_categories(id).unwrap();
    assert!(
        categories
            .categories
            .iter()
            .filter(|c| c.media_type == 0 && c.name != "Category 1")
            .all(|c| c.stream_count.is_none())
    );
    let requests = server.requests.lock().unwrap().clone();
    assert!(!requests.iter().any(|r| r.contains("series")));
    assert!(requests.iter().any(|r| r.contains("category_id=1")));
    let channel = rows(id, 0)[0];
    sql::favorite_channel(channel, true).unwrap();
    sql::add_last_watched(channel).unwrap();
    sql::set_movie_position(channel, 123).unwrap();
    let stats = xtream::get_xtream(src.clone(), true).await.unwrap();
    assert!(stats.success);
    assert_eq!(rows(id, 0), vec![channel]);
    assert_eq!(sql::get_movie_position(channel).unwrap(), Some(123));
    let state: (bool, Option<i64>) = sql::get_conn()
        .unwrap()
        .query_row(
            "SELECT favorite,last_watched FROM channels WHERE id=?",
            [channel],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .unwrap();
    assert!(state.0 && state.1.is_some());
    *server.corrupt.lock().unwrap() = 4;
    let empty = xtream::get_xtream(src.clone(), true).await.unwrap();
    assert!(empty.success && empty.types[0].failed && !empty.types[1].failed);
    assert_eq!(rows(id, 0), vec![channel]);
    assert_eq!(sql::get_movie_position(channel).unwrap(), Some(123));
    *server.corrupt.lock().unwrap() = 0;
    server.fail.lock().unwrap().push("get_live_streams".into());
    let stats = xtream::get_xtream(src.clone(), true).await.unwrap();
    assert!(stats.success && stats.types[0].failed && !stats.types[1].failed);
    assert_eq!(rows(id, 0), vec![channel]);
    server.fail.lock().unwrap().push("get_vod_streams".into());
    let movies = rows(id, 1);
    let stats = xtream::get_xtream(src.clone(), true).await.unwrap();
    assert!(stats.error.is_some() && stats.types[0].failed && stats.types[1].failed);
    assert_eq!(rows(id, 1), movies);
    server.fail.lock().unwrap().clear();
    rules(id, 0, 0, &["Category 1"]);
    let stats = xtream::get_xtream(src.clone(), true).await.unwrap();
    assert_eq!(stats.types[0].imported, 5); // Newly seen categories are imported.
    src.import_movies = false;
    xtream::get_xtream(src.clone(), true).await.unwrap();
    assert!(rows(id, 1).is_empty());
    server.requests.lock().unwrap().clear();
    xtream::fetch_categories(id).await.unwrap();
    assert!(
        server
            .requests
            .lock()
            .unwrap()
            .iter()
            .all(|r| r.contains("categories"))
    );
    sql::delete_source(id).unwrap();
    assert_eq!(sql::get_movie_position(channel).unwrap(), None);
}

#[test]
fn m3u_types_categories_stats_and_cleanup() {
    let _db_guard = crate::sql::test_lock();
    sql::test_db();
    let path = std::env::temp_dir().join(format!("brentv-fixture-{}.m3u", std::process::id()));
    std::fs::write(&path,"#EXTM3U\n#EXTINF:-1 group-title=\"News\",Live\nhttp://local/live/1.ts\n#EXTINF:-1 group-title=\"Films\",Movie\nhttp://local/video.MKV?x=1\n#EXTINF:-1 group-title=\"Shows\",Series\nhttp://local/series/1.mp4\n").unwrap();
    let mut src = source("m3u-classify-test", path.to_string_lossy().into(), 0);
    let id = src.id.unwrap();
    src.import_movies = false;
    rules(id, 0, 0, &["News"]);
    let stats = m3u::read_m3u8(src.clone(), false).unwrap();
    assert_eq!((stats.types[0].fetched, stats.types[0].excluded), (1, 1));
    assert_eq!(stats.types[1].fetched, 0);
    assert_eq!(rows(id, 2).len(), 1);
    rules(id, 0, 1, &["News", "Missing"]);
    m3u::read_m3u8(src.clone(), true).unwrap();
    assert_eq!(rows(id, 0).len(), 1);
    std::fs::write(&path, "#EXTM3U\n").unwrap();
    let stats = m3u::read_m3u8(src, true).unwrap();
    assert!(stats.types[0].failed && stats.types[2].failed);
    let cats = sql::get_source_categories(id).unwrap();
    assert!(
        cats.categories
            .iter()
            .any(|c| c.name == "Missing" && c.listed)
    );
    assert!(cats.categories.iter().any(|c| c.name == "Shows"));
    assert_eq!(rows(id, 0).len(), 1);
    sql::delete_source(id).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[tokio::test]
async fn failed_sources_continue_and_redact_paths() {
    let _db_guard = crate::sql::test_lock_async().await;
    sql::test_db();
    let bad=source("refresh-all-bad","http://127.0.0.1:1/live/synthetic-user/synthetic-password/1.ts?username=synthetic-user&password=synthetic-password".into(),1);
    let path = std::env::temp_dir().join(format!("brentv-empty-{}.m3u", std::process::id()));
    std::fs::write(&path, "#EXTM3U\n").unwrap();
    let good = source("refresh-all-good", path.to_string_lossy().into(), 0);
    let stats = crate::utils::refresh_all().await.unwrap();
    let failed = stats
        .iter()
        .find(|s| s.source_id == bad.id.unwrap())
        .unwrap();
    assert!(!failed.success && failed.types.iter().all(|t| t.failed));
    let text = format!("{failed:?}");
    assert!(!text.contains("synthetic-user") && !text.contains("synthetic-password"));
    assert!(
        stats
            .iter()
            .find(|s| s.source_id == good.id.unwrap())
            .unwrap()
            .success
    );
    sql::delete_source(bad.id.unwrap()).unwrap();
    sql::delete_source(good.id.unwrap()).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[test]
fn upstream_migration_adopts_ids_and_transfers_duplicates() {
    let _db_guard = crate::sql::test_lock();
    sql::test_db();
    let mut conn = rusqlite::Connection::open_in_memory().unwrap();
    super::migrations().to_version(&mut conn, 1).unwrap();
    conn.execute_batch("INSERT INTO sources(id,name,source_type) VALUES(1,'upstream',2);
INSERT INTO channels(id,name,url,source_id,media_type,stream_id,favorite,last_watched) VALUES(100,'Film','http://local/movie/10.mp4',1,1,10,0,NULL),(101,'Film','http://local/movie/10.mp4',1,1,10,1,987),(104,'Film','http://local/movie/10.mp4',1,1,10,0,1000);
INSERT INTO movie_positions(channel_id,position) VALUES(101,543),(104,600);").unwrap();
    super::migrations().to_latest(&mut conn).unwrap();
    let adopted: i64 = conn
        .query_row("SELECT id FROM channels WHERE ext_key='1:10'", [], |r| {
            r.get(0)
        })
        .unwrap();
    assert_eq!(adopted, 100);
    let tx = conn.transaction().unwrap();
    sql::begin_refresh(&tx).unwrap();
    // Read the actual migrated upstream row, as the importer would.
    let channel = tx
        .query_row(
            "SELECT * FROM channels WHERE id=100",
            [],
            super::row_to_channel,
        )
        .unwrap();
    assert_eq!(sql::upsert_channel(&tx, &channel, "1:10", 0).unwrap(), 100);
    sql::finish_type(&tx, 1, 1).unwrap();
    sql::finish_refresh(&tx, 1).unwrap();
    let state:(bool,i64,i64)=tx.query_row("SELECT favorite,last_watched,(SELECT position FROM movie_positions WHERE channel_id=100) FROM channels WHERE id=100",[],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?))).unwrap();
    assert_eq!(state, (true, 1000, 600));
    assert_eq!(
        tx.query_row("SELECT count(*) FROM channels", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        1
    );
    tx.commit().unwrap();
}

#[test]
fn m3u_parse_failure_keeps_type_and_unknown_categories_follow_mode() {
    let _db_guard = crate::sql::test_lock();
    sql::test_db();
    let path = std::env::temp_dir().join(format!("brentv-partial-{}.m3u", std::process::id()));
    std::fs::write(
        &path,
        "#EXTM3U\n#EXTINF:-1,News\nhttp://local/1.ts\n#EXTINF:-1,Film\nhttp://local/film.mov\n",
    )
    .unwrap();
    let mut src = source("m3u-partial", path.to_string_lossy().into(), 0);
    src.import_series = false;
    let id = src.id.unwrap();
    m3u::read_m3u8(src.clone(), false).unwrap();
    let live = rows(id, 0);
    let movie = rows(id, 1)[0];
    sql::favorite_channel(movie, true).unwrap();
    sql::add_last_watched(movie).unwrap();
    sql::set_movie_position(movie, 42).unwrap();
    m3u::read_m3u8(src.clone(), true).unwrap();
    assert_eq!(rows(id, 1), vec![movie]);
    assert_eq!(sql::get_movie_position(movie).unwrap(), Some(42));
    std::fs::write(
        &path,
        "#EXTM3U\n#EXTINF:-1\nhttp://local/2.ts\n#EXTINF:-1,Film\nhttp://local/film.mov\n",
    )
    .unwrap();
    let stats = m3u::read_m3u8(src.clone(), true).unwrap();
    assert!(stats.success && stats.types[0].failed && !stats.types[1].failed);
    assert_eq!(rows(id, 0), live);
    rules(id, 1, 1, &["Only listed"]);
    let stats = m3u::read_m3u8(src.clone(), true).unwrap();
    assert_eq!(
        (
            stats.types[1].fetched,
            stats.types[1].imported,
            stats.types[1].excluded
        ),
        (1, 0, 1)
    );
    assert_eq!(sql::get_movie_position(movie).unwrap(), None);
    std::fs::write(
        &path,
        "#EXTM3U\n#EXTINF:-1\nhttp://local/2.ts\n#EXTINF:-1\nhttp://local/film.mov\n",
    )
    .unwrap();
    let stats = m3u::read_m3u8(src, true).unwrap();
    assert!(stats.error.is_some());
    assert_eq!(rows(id, 0), live);
    std::fs::write(&path, "<html>Provider maintenance</html>").unwrap();
    let stats = m3u::read_m3u8(sql::get_source_from_id(id).unwrap(), true).unwrap();
    assert!(!stats.success && stats.error.is_some());
    assert_eq!(rows(id, 0), live);
    sql::delete_source(id).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[test]
fn media_classification_and_deep_provider_pages() {
    let _db_guard = crate::sql::test_lock();
    sql::test_db();
    let path = std::env::temp_dir().join(format!("brentv-deep-{}.m3u", std::process::id()));
    let mut playlist = String::from("#EXTM3U\n");
    for n in 0..10_900 {
        playlist.push_str(&format!(
            "#EXTINF:-1,Channel {}\nhttp://local/{n}.ts\n",
            10_900 - n
        ));
    }
    for ext in ["mp4", "mkv", "avi", "m4v", "mov", "webm"] {
        playlist.push_str(&format!(
            "#EXTINF:-1,Film {ext}\nhttp://local/video.{ext}?download=1\n"
        ));
    }
    std::fs::write(&path, playlist).unwrap();
    let src = source("deep-provider", path.to_string_lossy().into(), 0);
    let id = src.id.unwrap();
    let stats = m3u::read_m3u8(src, false).unwrap();
    assert_eq!(stats.types[1].imported, 6);
    let channels = sql::search(crate::types::Filters {
        query: None,
        source_ids: vec![id],
        media_types: Some(vec![0]),
        view_type: 0,
        page: 300,
        series_id: None,
        group_id: None,
        use_keywords: false,
        sort: 2,
        season: None,
        favorite_groups: false,
        hidden_only: false,
        include_hidden: false,
    })
    .unwrap();
    assert_eq!(channels[0].name, "Channel 136");
    sql::delete_source(id).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[tokio::test]
async fn episode_refresh_preserves_ids_state_and_failed_fetches() {
    let _db_guard = crate::sql::test_lock_async().await;
    let server = Server::new().await;
    let mut src = source("series-state", server.url.clone(), 2);
    src.import_live = false;
    src.import_movies = false;
    sql::update_source(src.clone()).unwrap();
    let id = src.id.unwrap();
    xtream::get_xtream(src.clone(), false).await.unwrap();
    xtream::get_episodes(20, id, None).await.unwrap();
    let episodes = rows(id, 1);
    assert_eq!(episodes.len(), 2);
    let episode = episodes[0];
    sql::favorite_channel(episode, true).unwrap();
    sql::add_last_watched(episode).unwrap();
    sql::set_movie_position(episode, 123).unwrap();
    assert!(sql::series_has_episodes(20, id).unwrap());
    xtream::get_xtream(src.clone(), true).await.unwrap();
    assert_eq!(rows(id, 1), episodes);
    assert!(!sql::series_has_episodes(20, id).unwrap());
    server.fail.lock().unwrap().push("get_series_info".into());
    assert!(xtream::get_episodes(20, id, None).await.is_err());
    assert_eq!(rows(id, 1), episodes);
    server.fail.lock().unwrap().clear();
    sql::get_conn().unwrap().execute_batch("CREATE TRIGGER reject_episode BEFORE INSERT ON channels WHEN NEW.series_id IS NOT NULL BEGIN SELECT RAISE(ABORT,'injected episode write failure'); END;").unwrap();
    assert!(xtream::get_episodes(20, id, None).await.is_err());
    assert_eq!(rows(id, 1), episodes);
    assert_eq!(sql::get_movie_position(episode).unwrap(), Some(123));
    sql::get_conn()
        .unwrap()
        .execute_batch("DROP TRIGGER reject_episode")
        .unwrap();
    xtream::get_episodes(20, id, None).await.unwrap();
    assert_eq!(rows(id, 1), episodes);
    assert_eq!(sql::get_movie_position(episode).unwrap(), Some(123));
    let state: (bool, Option<i64>) = sql::get_conn()
        .unwrap()
        .query_row(
            "SELECT favorite,last_watched FROM channels WHERE id=?",
            [episode],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .unwrap();
    assert!(state.0 && state.1.is_some());
    src.import_series = false;
    xtream::get_xtream(src, true).await.unwrap();
    assert!(rows(id, 1).is_empty());
    sql::delete_source(id).unwrap();
}

#[tokio::test]
async fn malformed_xtream_entry_preserves_the_entire_selected_type() {
    let _db_guard = crate::sql::test_lock_async().await;
    let server = Server::new().await;
    let mut src = source("malformed-xtream", server.url.clone(), 2);
    src.import_movies = false;
    src.import_series = false;
    sql::update_source(src.clone()).unwrap();
    let id = src.id.unwrap();
    xtream::get_xtream(src.clone(), false).await.unwrap();
    let before = rows(id, 0);
    assert_eq!(before.len(), 6);
    sql::favorite_channel(before[0], true).unwrap();
    sql::add_last_watched(before[0]).unwrap();
    sql::set_movie_position(before[0], 42).unwrap();
    for malformed in [1, 2, 3] {
        *server.corrupt.lock().unwrap() = malformed;
        let stats = xtream::get_xtream(src.clone(), true).await.unwrap();
        assert!(!stats.success && stats.types[0].failed);
        assert_eq!(rows(id, 0), before);
        let state: (bool, Option<i64>) = sql::get_conn()
            .unwrap()
            .query_row(
                "SELECT favorite,last_watched FROM channels WHERE id=?",
                [before[0]],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .unwrap();
        assert!(state.0 && state.1.is_some());
        assert_eq!(sql::get_movie_position(before[0]).unwrap(), Some(42));
    }
    sql::delete_source(id).unwrap();
}

#[test]
fn unfinished_m3u_entry_preserves_saved_state() {
    let _db_guard = crate::sql::test_lock();
    let path = std::env::temp_dir().join(format!("brentv-unfinished-{}.m3u", std::process::id()));
    std::fs::write(
        &path,
        "#EXTM3U\n#EXTINF:-1,A\nhttp://local/a.ts\n#EXTINF:-1,B\nhttp://local/b.ts\n",
    )
    .unwrap();
    let src = source("unfinished-m3u", path.to_string_lossy().into(), 0);
    let id = src.id.unwrap();
    m3u::read_m3u8(src.clone(), false).unwrap();
    let before = rows(id, 0);
    sql::favorite_channel(before[0], true).unwrap();
    sql::add_last_watched(before[0]).unwrap();
    sql::set_movie_position(before[0], 42).unwrap();
    std::fs::write(
        &path,
        "#EXTM3U\n#EXTINF:-1,A\n#EXTINF:-1,B\nhttp://local/b.ts\n",
    )
    .unwrap();
    let stats = m3u::read_m3u8(src, true).unwrap();
    assert!(!stats.success);
    assert_eq!(rows(id, 0), before);
    let state: (bool, Option<i64>) = sql::get_conn()
        .unwrap()
        .query_row(
            "SELECT favorite,last_watched FROM channels WHERE id=?",
            [before[0]],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .unwrap();
    assert!(state.0 && state.1.is_some());
    assert_eq!(sql::get_movie_position(before[0]).unwrap(), Some(42));
    sql::delete_source(id).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[test]
fn adoption_excludes_other_sources_types_and_cached_episodes() {
    let _db_guard = crate::sql::test_lock();
    let mut conn = rusqlite::Connection::open_in_memory().unwrap();
    super::migrations().to_latest(&mut conn).unwrap();
    conn.execute_batch(
        "INSERT INTO sources(id,name,source_type) VALUES(1,'one',2),(2,'two',2);
INSERT INTO channels(id,name,source_id,media_type,ext_key,favorite,last_watched,series_id) VALUES
(100,'Film',1,1,'1:10',0,12,NULL),
(101,'Film',2,1,NULL,1,999,NULL),
(102,'Film',1,0,NULL,1,999,NULL),
(103,'Film',1,1,NULL,1,999,42);
INSERT INTO movie_positions(channel_id,position) VALUES(100,24),(101,999),(102,999),(103,999);",
    )
    .unwrap();
    for legacy in [false, true] {
        let tx = conn.transaction().unwrap();
        sql::begin_refresh(&tx).unwrap();
        tx.execute("INSERT INTO refresh_seen(id) VALUES(100)", [])
            .unwrap();
        if legacy {
            // An unrelated legacy row triggers adoption without a name match.
            tx.execute(
                "INSERT INTO channels(name,source_id,media_type) VALUES('Other',1,1)",
                [],
            )
            .unwrap();
        }
        sql::finish_type(&tx, 1, 1).unwrap();
        sql::finish_refresh(&tx, 1).unwrap();
        let state: (i64,i64,i64) = tx.query_row("SELECT favorite,last_watched,(SELECT position FROM movie_positions WHERE channel_id=100) FROM channels WHERE id=100", [], |r| Ok((r.get(0)?,r.get(1)?,r.get(2)?))).unwrap();
        assert_eq!(state, (0, 12, 24));
        assert_eq!(
            tx.query_row(
                "SELECT count(*) FROM channels WHERE id IN (101,102,103)",
                [],
                |r| r.get::<_, i64>(0)
            )
            .unwrap(),
            3
        );
        tx.commit().unwrap();
    }
}

#[test]
fn empty_m3u_refresh_retains_state_but_initial_empty_import_succeeds() {
    let _guard = crate::sql::test_lock();
    let path = std::env::temp_dir().join(format!("brentv-empty-state-{}.m3u", std::process::id()));
    std::fs::write(&path, "#EXTM3U\n").unwrap();
    let mut src = source("empty-state", path.to_string_lossy().into(), 0);
    src.import_movies = false;
    src.import_series = false;
    let id = src.id.unwrap();
    assert!(m3u::read_m3u8(src.clone(), false).unwrap().success);
    std::fs::write(&path, "#EXTM3U\n#EXTINF:-1,A\nhttp://local/a.ts\n").unwrap();
    assert!(m3u::read_m3u8(src.clone(), true).unwrap().success);
    let before = rows(id, 0);
    sql::favorite_channel(before[0], true).unwrap();
    sql::add_last_watched(before[0]).unwrap();
    sql::set_movie_position(before[0], 42).unwrap();
    std::fs::write(&path, "#EXTM3U\n").unwrap();
    let stats = m3u::read_m3u8(src, true).unwrap();
    assert!(!stats.success && stats.types[0].failed);
    assert_eq!(rows(id, 0), before);
    let state: (bool, Option<i64>) = sql::get_conn()
        .unwrap()
        .query_row(
            "SELECT favorite,last_watched FROM channels WHERE id=?",
            [before[0]],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .unwrap();
    assert!(state.0 && state.1.is_some());
    assert_eq!(sql::get_movie_position(before[0]).unwrap(), Some(42));
    sql::delete_source(id).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[test]
fn migration_four_drops_redundant_indexes_and_indexes_series_identity() {
    let _guard = crate::sql::test_lock();
    sql::test_db();
    assert_eq!(
        sql::get_conn()
            .unwrap()
            .query_row("PRAGMA journal_size_limit", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        16_777_216
    );
    let mut conn = rusqlite::Connection::open_in_memory().unwrap();
    super::migrations().to_version(&mut conn, 3).unwrap();
    super::migrations().to_latest(&mut conn).unwrap();
    for index in [
        "channels_unique",
        "index_channel_media_type",
        "index_channel_favorite",
        "index_channels_episode_num",
    ] {
        assert!(
            !conn
                .query_row(
                    "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name=?)",
                    [index],
                    |r| r.get::<_, bool>(0)
                )
                .unwrap()
        );
    }
    let plan: String = conn.query_row("EXPLAIN QUERY PLAN SELECT episodes_loaded FROM channels WHERE source_id=1 AND media_type=2 AND ext_key='2:20' AND series_id IS NULL", [], |r| r.get(3)).unwrap();
    assert!(plan.contains("index_channels_ext_key"), "{plan}");
}

#[tokio::test]
async fn xtream_initial_empty_and_intentional_exclusions_succeed() {
    let _guard = crate::sql::test_lock_async().await;
    let server = Server::new().await;
    let mut src = source("empty-xtream", server.url.clone(), 2);
    src.import_movies = false;
    src.import_series = false;
    let id = src.id.unwrap();
    *server.corrupt.lock().unwrap() = 3;
    assert!(
        xtream::get_xtream(src.clone(), false)
            .await
            .unwrap()
            .success
    );
    *server.corrupt.lock().unwrap() = 0;
    assert!(xtream::get_xtream(src.clone(), true).await.unwrap().success);
    rules(id, 0, 1, &["Missing"]);
    let stats = xtream::get_xtream(src, true).await.unwrap();
    assert!(stats.success && !stats.types[0].failed);
    assert!(rows(id, 0).is_empty());
    sql::delete_source(id).unwrap();
}

#[test]
fn favorite_categories_first_filtered_and_kept_while_empty() {
    let _db_guard = crate::sql::test_lock();
    sql::test_db();
    let path = std::env::temp_dir().join(format!("brentv-favgroups-{}.m3u", std::process::id()));
    std::fs::write(
        &path,
        "#EXTM3U\n#EXTINF:-1 group-title=\"Alpha\",One\nhttp://local/live/1.ts\n#EXTINF:-1 group-title=\"Beta\",Two\nhttp://local/live/2.ts\n",
    )
    .unwrap();
    let src = source("favorite-groups", path.to_string_lossy().into(), 0);
    let id = src.id.unwrap();
    m3u::read_m3u8(src.clone(), false).unwrap();
    let groups = |favorite_groups| {
        sql::search(crate::types::Filters {
            query: None,
            source_ids: vec![id],
            media_types: Some(vec![0]),
            view_type: crate::view_type::CATEGORIES,
            page: 1,
            series_id: None,
            group_id: None,
            use_keywords: false,
            sort: crate::sort_type::PROVIDER,
            season: None,
            favorite_groups,
            hidden_only: false,
            include_hidden: false,
        })
        .unwrap()
    };
    let beta = groups(false)
        .into_iter()
        .find(|g| g.name == "Beta")
        .unwrap();
    sql::favorite_group(beta.id.unwrap(), true).unwrap();
    let all = groups(false);
    assert_eq!((all[0].name.as_str(), all[0].favorite), ("Beta", true));
    let favorites = groups(true);
    assert_eq!(favorites.len(), 1);
    assert_eq!(favorites[0].id, beta.id);
    // The provider drops Beta's channels: the favourite category stays.
    std::fs::write(
        &path,
        "#EXTM3U\n#EXTINF:-1 group-title=\"Alpha\",One\nhttp://local/live/1.ts\n",
    )
    .unwrap();
    m3u::read_m3u8(src, true).unwrap();
    assert_eq!(groups(true)[0].id, beta.id);
    sql::delete_source(id).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[test]
fn remove_one_channel_from_history() {
    let _db_guard = crate::sql::test_lock();
    sql::test_db();
    let path = std::env::temp_dir().join(format!("brentv-history-{}.m3u", std::process::id()));
    std::fs::write(
        &path,
        "#EXTM3U\n#EXTINF:-1,One\nhttp://local/live/h1.ts\n#EXTINF:-1,Two\nhttp://local/live/h2.ts\n",
    )
    .unwrap();
    let src = source("history-remove", path.to_string_lossy().into(), 0);
    let id = src.id.unwrap();
    m3u::read_m3u8(src, false).unwrap();
    let ids = rows(id, 0);
    for channel in &ids {
        sql::add_last_watched(*channel).unwrap();
    }
    sql::remove_last_watched(ids[0]).unwrap();
    let watched: Vec<i64> = sql::get_conn()
        .unwrap()
        .prepare("SELECT id FROM channels WHERE source_id=? AND last_watched IS NOT NULL")
        .unwrap()
        .query_map([id], |r| r.get(0))
        .unwrap()
        .collect::<Result<_, _>>()
        .unwrap();
    assert_eq!(watched, vec![ids[1]]);
    sql::delete_source(id).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[test]
fn favorites_keep_their_order_and_swap() {
    let _db_guard = crate::sql::test_lock();
    let path = std::env::temp_dir().join(format!("brentv-fav-order-{}.m3u", std::process::id()));
    let mut m3u = String::from("#EXTM3U\n");
    for n in 1..=4 {
        m3u += &format!("#EXTINF:-1 group-title=\"G{n}\",C{n}\nhttp://local/live/f{n}.ts\n");
    }
    std::fs::write(&path, m3u).unwrap();
    let src = source("favorite-order", path.to_string_lossy().into(), 0);
    let id = src.id.unwrap();
    m3u::read_m3u8(src, false).unwrap();
    let ids = rows(id, 0);
    let favorites = |favorite_groups| {
        sql::search(crate::types::Filters {
            query: None,
            source_ids: vec![id],
            media_types: Some(vec![0]),
            view_type: crate::view_type::FAVORITES,
            page: 1,
            series_id: None,
            group_id: None,
            use_keywords: false,
            sort: crate::sort_type::PROVIDER,
            season: None,
            favorite_groups,
            hidden_only: false,
            include_hidden: false,
        })
        .unwrap()
        .iter()
        .map(|c| c.id.unwrap())
        .collect::<Vec<_>>()
    };
    // Stars saved before ordering existed are all 1 and keep provider order.
    sql::get_conn()
        .unwrap()
        .execute(
            "UPDATE channels SET favorite=1 WHERE id IN (?,?)",
            [ids[1], ids[2]],
        )
        .unwrap();
    sql::favorite_channel(ids[0], true).unwrap();
    assert_eq!(favorites(false), vec![ids[1], ids[2], ids[0]]);
    sql::swap_favorites(ids[0], ids[2], false).unwrap();
    assert_eq!(favorites(false), vec![ids[1], ids[0], ids[2]]);
    sql::favorite_channel(ids[0], true).unwrap();
    sql::favorite_channel(ids[3], true).unwrap();
    assert_eq!(favorites(false), vec![ids[1], ids[0], ids[2], ids[3]]);
    sql::favorite_channel(ids[1], false).unwrap();
    assert_eq!(favorites(false), vec![ids[0], ids[2], ids[3]]);
    assert!(sql::swap_favorites(ids[0], ids[1], false).is_err());

    let groups = favorites(true);
    assert!(groups.is_empty());
    let group_ids: Vec<i64> = sql::get_conn()
        .unwrap()
        .prepare("SELECT id FROM groups WHERE source_id=? ORDER BY id")
        .unwrap()
        .query_map([id], |r| r.get(0))
        .unwrap()
        .collect::<Result<_, _>>()
        .unwrap();
    for g in &group_ids[..3] {
        sql::favorite_group(*g, true).unwrap();
    }
    sql::swap_favorites(group_ids[2], group_ids[0], true).unwrap();
    assert_eq!(
        favorites(true),
        vec![group_ids[2], group_ids[1], group_ids[0]]
    );
    sql::delete_source(id).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[tokio::test]
async fn hidden_refresh_preserves_user_state_and_exact_epg_id() {
    let _guard = sql::test_lock_async().await;
    let path = std::env::temp_dir().join(format!("brentv-hidden-{}.m3u", std::process::id()));
    std::fs::write(&path,"#EXTM3U x-tvg-url=\"http://unused.invalid/epg.xml\"\n#EXTINF:-1 tvg-id=\"Exact.ID\" group-title=\"Hidden Group\",One\nhttp://local/live/hidden1.ts\n#EXTINF:-1 group-title=\"Other\",Two\nhttp://local/live/hidden2.ts\n").unwrap();
    let src = source("hidden-state", path.to_string_lossy().into(), 0);
    let sid = src.id.unwrap();
    m3u::read_m3u8(src.clone(), false).unwrap();
    assert_eq!(
        sql::get_source_from_id(sid).unwrap().epg_url.as_deref(),
        Some("http://unused.invalid/epg.xml")
    );
    let filters = |hidden_only, include_hidden| crate::types::Filters {
        query: None,
        source_ids: vec![sid],
        media_types: Some(vec![0]),
        view_type: 0,
        page: 1,
        series_id: None,
        group_id: None,
        use_keywords: false,
        sort: 2,
        season: None,
        favorite_groups: false,
        hidden_only,
        include_hidden,
    };
    let all = sql::search(filters(false, false)).unwrap();
    assert_eq!(all.len(), 2);
    let first = all.iter().find(|c| c.name == "One").unwrap();
    let cid = first.id.unwrap();
    let gid = first.group_id.unwrap();
    assert_eq!(first.epg_id.as_deref(), Some("Exact.ID"));
    assert!(!first.hidden);
    sql::favorite_channel(cid, true).unwrap();
    sql::add_last_watched(cid).unwrap();
    sql::set_movie_position(cid, 123).unwrap();
    sql::set_hidden(gid, true, true).unwrap();
    assert_eq!(sql::search(filters(false, false)).unwrap().len(), 1);
    let hidden = sql::search(filters(true, false)).unwrap();
    assert_eq!(hidden.len(), 1);
    assert_eq!(hidden[0].id, Some(cid));
    sql::set_hidden(cid, true, false).unwrap();
    m3u::read_m3u8(src, true).unwrap();
    let hidden = sql::search(filters(true, false)).unwrap();
    assert!(hidden[0].hidden && hidden[0].favorite);
    assert_eq!(hidden[0].id, Some(cid));
    assert_eq!(sql::get_movie_position(cid).unwrap(), Some(123));
    let watched: bool = sql::get_conn()
        .unwrap()
        .query_row(
            "SELECT last_watched IS NOT NULL FROM channels WHERE id=?",
            [cid],
            |r| r.get(0),
        )
        .unwrap();
    assert!(watched);
    assert_eq!(sql::search(filters(false, true)).unwrap().len(), 2);
    sql::restore_all_hidden().unwrap();
    assert_eq!(sql::search(filters(false, false)).unwrap().len(), 2);
    sql::set_source_enabled(false, sid).unwrap();
    assert!(sql::search(filters(false, true)).unwrap().is_empty());
    sql::delete_source(sid).unwrap();
    std::fs::remove_file(path).unwrap();
}

#[tokio::test]
async fn backend_feature_gates_make_no_http_requests() {
    let _guard = sql::test_lock_async().await;
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/player_api.php", listener.local_addr().unwrap());
    let src = source("guide-feature-gates", url.clone(), 2);
    let sid = src.id.unwrap();
    sql::get_conn().unwrap().execute("INSERT INTO channels(name,url,source_id,media_type,stream_id,tv_archive,archive_days,epg_id) VALUES ('Guide','http://unused',?,0,42,1,2,'Exact.ID')",[sid]).unwrap();
    let cid: i64 = sql::get_conn()
        .unwrap()
        .query_row("SELECT id FROM channels WHERE source_id=?", [sid], |r| {
            r.get(0)
        })
        .unwrap();
    let at = chrono::Utc::now().timestamp();
    crate::settings::update_settings(crate::types::Settings {
        show_programmes: Some(false),
        ..Default::default()
    })
    .unwrap();
    assert!(!crate::epg::get_now_next(cid).await.unwrap().supported);
    assert!(
        !crate::epg::get_schedule(cid, at, at + 3600)
            .await
            .unwrap()
            .supported
    );
    crate::settings::update_settings(crate::types::Settings {
        show_programmes: Some(true),
        enable_full_guide: Some(false),
        enable_catchup: Some(false),
        ..Default::default()
    })
    .unwrap();
    assert!(
        !crate::epg::get_schedule(cid, at, at + 3600)
            .await
            .unwrap()
            .supported
    );
    assert!(
        crate::epg::get_catchup(cid, at - 120, at - 60)
            .await
            .is_err()
    );
    crate::settings::update_settings(crate::types::Settings {
        enable_full_guide: Some(true),
        enable_catchup: Some(true),
        ..Default::default()
    })
    .unwrap();
    let local = chrono::DateTime::from_timestamp(at - 120 - 5 * 3600, 0)
        .unwrap()
        .format("%Y-%m-%d %H:%M:%S")
        .to_string();
    let body=json!({"epg_listings":[{"title":"Archived show","start_timestamp":at-120,"stop_timestamp":at-60,"start":local,"has_archive":"1"}]}).to_string();
    let serve = async {
        let (mut socket, _) = listener.accept().await.unwrap();
        let mut bytes = [0; 4096];
        let n = socket.read(&mut bytes).await.unwrap();
        assert!(String::from_utf8_lossy(&bytes[..n]).contains("get_simple_data_table"));
        socket
            .write_all(
                format!(
                    "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                    body.len(),
                    body
                )
                .as_bytes(),
            )
            .await
            .unwrap();
    };
    let (catchup, ()) = tokio::join!(crate::epg::get_catchup(cid, at - 120, at - 60), serve);
    let catchup = catchup.unwrap();
    let date = chrono::NaiveDateTime::parse_from_str(&local, "%Y-%m-%d %H:%M:%S")
        .unwrap()
        .format("%Y-%m-%d:%H-%M")
        .to_string();
    assert!(catchup.url.as_ref().unwrap().contains(&date));
    assert_eq!(catchup.id, None);
    assert_eq!(catchup.source_id, Some(sid));
    assert_eq!(catchup.media_type, 1);
    sql::set_source_enabled(false, sid).unwrap();
    assert!(
        !crate::epg::get_schedule(cid, at, at + 3600)
            .await
            .unwrap()
            .supported
    );
    assert!(
        crate::epg::get_catchup(cid, at - 120, at - 60)
            .await
            .is_err()
    );
    // M3U XMLTV remains off by default even with a valid saved endpoint.
    let mut m3u = sql::get_source_from_id(sid).unwrap();
    m3u.source_type = 0;
    sql::get_conn()
        .unwrap()
        .execute(
            "UPDATE sources SET source_type=0,enabled=1,epg_url=? WHERE id=?",
            rusqlite::params![url, sid],
        )
        .unwrap();
    assert!(!crate::epg::get_now_next(cid).await.unwrap().supported);
    assert!(
        !crate::epg::get_schedule(cid, at, at + 3600)
            .await
            .unwrap()
            .supported
    );
    assert!(
        crate::epg::get_catchup(cid, at - 120, at - 60)
            .await
            .is_err()
    );
    assert!(
        tokio::time::timeout(std::time::Duration::from_millis(20), listener.accept())
            .await
            .is_err()
    );
    sql::delete_source(sid).unwrap();
}

#[test]
fn migration_six_defaults_preserve_existing_state() {
    let mut conn = rusqlite::Connection::open_in_memory().unwrap();
    super::migrations().to_version(&mut conn, 5).unwrap();
    conn.execute_batch("INSERT INTO sources(id,name,source_type,enabled) VALUES(1,'old',2,1); INSERT INTO groups(id,name,source_id,favorite) VALUES(1,'old',1,1); INSERT INTO channels(id,name,source_id,favorite,last_watched) VALUES(1,'old',1,1,123); INSERT INTO movie_positions(channel_id,position) VALUES(1,456);").unwrap();
    super::migrations().to_latest(&mut conn).unwrap();
    assert_eq!(
        conn.query_row(
            "SELECT hidden,favorite,last_watched FROM channels WHERE id=1",
            [],
            |r| Ok((
                r.get::<_, bool>(0)?,
                r.get::<_, bool>(1)?,
                r.get::<_, i64>(2)?
            ))
        )
        .unwrap(),
        (false, true, 123)
    );
    assert_eq!(
        conn.query_row("SELECT hidden,favorite FROM groups WHERE id=1", [], |r| Ok(
            (r.get::<_, bool>(0)?, r.get::<_, bool>(1)?)
        ))
        .unwrap(),
        (false, true)
    );
    assert_eq!(
        conn.query_row(
            "SELECT position FROM movie_positions WHERE channel_id=1",
            [],
            |r| r.get::<_, i64>(0)
        )
        .unwrap(),
        456
    );
}

#[tokio::test]
async fn xmltv_exact_ids_schedule_and_cache_invalidation() {
    let _guard = sql::test_lock_async().await;
    let at = chrono::Utc::now().timestamp();
    let date = |t| {
        chrono::DateTime::from_timestamp(t, 0)
            .unwrap()
            .format("%Y%m%d%H%M%S +0000")
            .to_string()
    };
    let path = std::env::temp_dir().join(format!("brentv-xmltv-{}.xml", std::process::id()));
    let other = path.with_extension("other.xml");
    let body = |title| {
        format!(
            "<tv><programme channel=\"Exact.ID\" start=\"{}\" stop=\"{}\"><title>{title}</title></programme><programme channel=\"bad\" start=\"broken\" stop=\"broken\"><title>bad</title></programme></tv>",
            date(at - 60),
            date(at + 3600)
        )
    };
    std::fs::write(&path, body("First")).unwrap();
    std::fs::write(&other, body("Second")).unwrap();
    let mut src = source("xmltv-cache", "unused.m3u".into(), 0);
    let sid = src.id.unwrap();
    src.epg_url = Some(path.to_string_lossy().into_owned());
    sql::update_source(src.clone()).unwrap();
    sql::get_conn().unwrap().execute("INSERT INTO channels(name,url,source_id,media_type,epg_id) VALUES ('Same name','http://unused',?,0,'Exact.ID')",[sid]).unwrap();
    let cid: i64 = sql::get_conn()
        .unwrap()
        .query_row("SELECT id FROM channels WHERE source_id=?", [sid], |r| {
            r.get(0)
        })
        .unwrap();
    crate::settings::update_settings(crate::types::Settings {
        enable_xmltv: Some(true),
        ..Default::default()
    })
    .unwrap();
    let schedule = crate::epg::get_schedule(cid, at - 100, at + 7200)
        .await
        .unwrap();
    assert_eq!(schedule.programmes[0].title, "First");
    assert!(!schedule.catchup_supported);
    assert_eq!(
        crate::epg::get_now_next(cid)
            .await
            .unwrap()
            .now
            .unwrap()
            .title,
        "First"
    );
    sql::get_conn()
        .unwrap()
        .execute("UPDATE channels SET epg_id='exact.id' WHERE id=?", [cid])
        .unwrap();
    assert!(
        crate::epg::get_schedule(cid, at - 100, at + 7200)
            .await
            .unwrap()
            .programmes
            .is_empty()
    );
    sql::get_conn()
        .unwrap()
        .execute("UPDATE channels SET epg_id='Exact.ID' WHERE id=?", [cid])
        .unwrap();
    src.epg_url = Some(other.to_string_lossy().into_owned());
    sql::update_source(src.clone()).unwrap();
    assert_eq!(
        crate::epg::get_now_next(cid)
            .await
            .unwrap()
            .now
            .unwrap()
            .title,
        "Second"
    );
    std::fs::write(&path, "<tv><programme").unwrap();
    src.epg_url = Some(path.to_string_lossy().into_owned());
    sql::update_source(src.clone()).unwrap();
    assert!(crate::epg::get_now_next(cid).await.is_err());
    src.epg_url = Some(other.to_string_lossy().into_owned());
    sql::update_source(src).unwrap();
    assert_eq!(
        crate::epg::get_now_next(cid)
            .await
            .unwrap()
            .now
            .unwrap()
            .title,
        "Second"
    );
    crate::settings::update_settings(crate::types::Settings {
        enable_xmltv: Some(false),
        ..Default::default()
    })
    .unwrap();
    assert!(!crate::epg::get_now_next(cid).await.unwrap().supported);
    sql::delete_source(sid).unwrap();
    std::fs::remove_file(path).unwrap();
    std::fs::remove_file(other).unwrap();
}

#[tokio::test]
async fn provider_archive_days_require_explicit_support_and_positive_days() {
    let _guard = sql::test_lock_async().await;
    let server = Server::new().await;
    let mut src = source("archive-metadata", server.url.clone(), 2);
    src.import_movies = false;
    src.import_series = false;
    sql::update_source(src.clone()).unwrap();
    let sid = src.id.unwrap();
    assert!(xtream::get_xtream(src, true).await.unwrap().success);
    let values = sql::get_conn()
        .unwrap()
        .prepare("SELECT stream_id,archive_days FROM channels WHERE source_id=? ORDER BY stream_id")
        .unwrap()
        .query_map([sid], |r| {
            Ok((r.get::<_, i64>(0)?, r.get::<_, Option<u32>>(1)?))
        })
        .unwrap()
        .collect::<Result<Vec<_>, _>>()
        .unwrap();
    assert_eq!(values[0], (10, Some(2)));
    assert!(values.iter().skip(1).all(|(_, days)| days.is_none()));
    sql::delete_source(sid).unwrap();
}
