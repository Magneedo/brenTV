use super::*;
use rusqlite::OptionalExtension;
use serde_json::Value;
use std::sync::atomic::{AtomicUsize, Ordering};
use tokio::sync::oneshot;

type HeldResponse = (oneshot::Sender<()>, oneshot::Receiver<()>);

struct EpisodeServer {
    url: String,
    body: Arc<Mutex<String>>,
    hold: Arc<Mutex<Option<HeldResponse>>>,
    requests: Arc<AtomicUsize>,
    task: tokio::task::JoinHandle<()>,
}

impl Drop for EpisodeServer {
    fn drop(&mut self) {
        self.task.abort();
    }
}

fn listing() -> Value {
    json!({"seasons":[{"season_number":1},{"season_number":2}],"episodes":{
        "1":[{"id":"9001","title":"First episode","container_extension":"mp4","episode_num":1,"season":1}],
        "2":[{"id":9002,"title":"Second episode","container_extension":"mkv","episode_num":1,"season":2}]
    }})
}

impl EpisodeServer {
    async fn new() -> Self {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/player_api.php", listener.local_addr().unwrap());
        let body = Arc::new(Mutex::new(listing().to_string()));
        let hold = Arc::new(Mutex::new(None::<HeldResponse>));
        let requests = Arc::new(AtomicUsize::new(0));
        let (response, wait, count) = (body.clone(), hold.clone(), requests.clone());
        let task = tokio::spawn(async move {
            loop {
                let (mut socket, _) = listener.accept().await.unwrap();
                let (response, wait, count) = (response.clone(), wait.clone(), count.clone());
                tokio::spawn(async move {
                    let mut bytes = [0; 8192];
                    let n = socket.read(&mut bytes).await.unwrap();
                    assert!(String::from_utf8_lossy(&bytes[..n]).contains("get_series_info"));
                    count.fetch_add(1, Ordering::SeqCst);
                    let body = response.lock().unwrap().clone();
                    let held = wait.lock().unwrap().take();
                    if let Some((arrived, release)) = held {
                        let _ = arrived.send(());
                        let _ = release.await;
                    }
                    let reply = format!(
                        "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(reply.as_bytes()).await;
                });
            }
        });
        Self {
            url,
            body,
            hold,
            requests,
            task,
        }
    }

    fn hold_next(&self) -> (oneshot::Receiver<()>, oneshot::Sender<()>) {
        let (arrived, started) = oneshot::channel();
        let (release, wait) = oneshot::channel();
        *self.hold.lock().unwrap() = Some((arrived, wait));
        (started, release)
    }
}

fn seed(server: &EpisodeServer, name: &str) -> i64 {
    let src = source(name, server.url.clone(), 2);
    let id = src.id.unwrap();
    let conn = sql::get_conn().unwrap();
    conn.execute(
        "INSERT INTO groups(name,source_id,media_type) VALUES ('Shows',?,2)",
        [id],
    )
    .unwrap();
    let group = conn.last_insert_rowid();
    conn.execute("INSERT INTO channels(name,url,source_id,media_type,ext_key,group_id,favorite) VALUES ('Show','20',?,2,'2:20',?,0)", rusqlite::params![id,group]).unwrap();
    id
}

fn expire(id: i64) {
    sql::get_conn()
        .unwrap()
        .execute(
            "UPDATE channels SET episodes_loaded=0 WHERE source_id=? AND ext_key='2:20'",
            [id],
        )
        .unwrap();
}

async fn cached(server: &EpisodeServer, name: &str) -> i64 {
    let id = seed(server, name);
    xtream::get_episodes(20, id, None).await.unwrap();
    let conn = sql::get_conn().unwrap();
    conn.execute("UPDATE channels SET favorite=3,last_watched=123,hidden=1 WHERE source_id=? AND series_id=20 AND ext_key='episode:20:9001'", [id]).unwrap();
    conn.execute("INSERT INTO movie_positions(channel_id,position) SELECT id,42 FROM channels WHERE source_id=? AND series_id=20", [id]).unwrap();
    expire(id);
    id
}

/// Include identities, metadata, saved flags, seasons and resume positions.
fn state(id: i64) -> Vec<String> {
    let conn = sql::get_conn().unwrap();
    let mut result = Vec::new();
    for query in [
        "SELECT id,name,url,media_type,ext_key,series_id,season_id,episode_num,favorite,last_watched,hidden,episodes_loaded FROM channels WHERE source_id=? ORDER BY id",
        "SELECT id,name,image,series_id,season_number FROM seasons WHERE source_id=? ORDER BY id",
        "SELECT p.channel_id,p.position FROM movie_positions p JOIN channels c ON c.id=p.channel_id WHERE c.source_id=? ORDER BY p.channel_id",
    ] {
        let mut stmt = conn.prepare(query).unwrap();
        let width = stmt.column_count();
        result.push(query.into());
        result.extend(
            stmt.query_map([id], |row| {
                Ok((0..width)
                    .map(|column| format!("{:?}", row.get_ref(column).unwrap()))
                    .collect::<Vec<_>>()
                    .join("|"))
            })
            .unwrap()
            .collect::<Result<Vec<_>, _>>()
            .unwrap(),
        );
    }
    result
}

#[tokio::test]
async fn episode_invalid_payloads_preserve_all_cached_state() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    let id = cached(&server, "episode-invalid-payloads").await;
    let before = state(id);
    let mut unusable = listing();
    unusable["episodes"]["1"][0]["container_extension"] = json!("../mp4");
    unusable["episodes"]["2"][0]["id"] = json!(null);
    let cases = vec![
        json!({"seasons":[],"episodes":{}}),
        json!({"seasons":[],"episodes":{"1":[]}}),
        json!({"seasons":[],"episodes":[]}),
        unusable,
    ];
    for body in cases.into_iter().map(|v| v.to_string()).chain(["{".into()]) {
        *server.body.lock().unwrap() = body.clone();
        assert!(xtream::get_episodes(20, id, None).await.is_err(), "{body}");
        assert_eq!(state(id), before);
        assert!(!sql::series_has_episodes(20, id).unwrap());
    }
    // An error after the first upsert also rolls back metadata and season writes.
    let mut changed = listing();
    changed["episodes"]["1"][0]["title"] = json!("Changed before write failure");
    *server.body.lock().unwrap() = changed.to_string();
    sql::get_conn().unwrap().execute_batch(&format!("CREATE TRIGGER reject_later_episode BEFORE INSERT ON channels WHEN NEW.source_id={id} AND NEW.ext_key='episode:20:9002' BEGIN SELECT RAISE(ABORT,'fixture write failure'); END;")).unwrap();
    assert!(xtream::get_episodes(20, id, None).await.is_err());
    assert_eq!(state(id), before);
    sql::get_conn()
        .unwrap()
        .execute_batch("DROP TRIGGER reject_later_episode")
        .unwrap();
    sql::delete_source(id).unwrap();

    // An initially empty series stays retryable rather than caching emptiness.
    let id = seed(&server, "episode-initial-empty");
    *server.body.lock().unwrap() = json!({"seasons":[],"episodes":{}}).to_string();
    let before = state(id);
    assert!(xtream::get_episodes(20, id, None).await.is_err());
    assert_eq!(state(id), before);
    *server.body.lock().unwrap() = listing().to_string();
    xtream::get_episodes(20, id, None).await.unwrap();
    assert!(sql::series_has_episodes(20, id).unwrap());
    sql::delete_source(id).unwrap();
}

fn episode_row(id: i64, key: &str) -> Option<(i64, String, i64, Option<i64>)> {
    sql::get_conn()
        .unwrap()
        .query_row(
            "SELECT c.id,c.name,c.favorite,p.position FROM channels c LEFT JOIN movie_positions p ON p.channel_id=c.id WHERE c.source_id=? AND c.ext_key=?",
            rusqlite::params![id, key],
            |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)),
        )
        .optional()
        .unwrap()
}

fn orphans() -> i64 {
    sql::get_conn()
        .unwrap()
        .query_row(
            "SELECT (SELECT COUNT(*) FROM movie_positions WHERE channel_id NOT IN (SELECT id FROM channels))+(SELECT COUNT(*) FROM channel_http_headers WHERE channel_id NOT IN (SELECT id FROM channels))",
            [],
            |r| r.get(0),
        )
        .unwrap()
}

#[tokio::test]
async fn episode_listing_skips_bad_entries_and_keeps_their_saved_state() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    // (field, value, expected 9002 name, or None when the row must be deleted)
    let cases: Vec<(&str, Value, Option<&str>)> = vec![
        ("id", json!(null), Some("Second episode")),
        ("id", json!(""), Some("Second episode")),
        ("id", json!(-1), Some("Second episode")),
        ("id", json!("not-an-id"), Some("Second episode")),
        ("title", json!("  "), Some("Episode 1")),
        ("title", json!(null), Some("Episode 1")),
        ("container_extension", json!(""), Some("Second episode")),
        (
            "container_extension",
            json!("../mp4"),
            Some("Second episode"),
        ),
        ("container_extension", json!(null), Some("Second episode")),
        ("id", json!(9001), None),
    ];
    for (i, (field, value, expected)) in cases.into_iter().enumerate() {
        *server.body.lock().unwrap() = listing().to_string();
        let id = cached(&server, &format!("episode-lenient-{i}")).await;
        let first = episode_row(id, "episode:20:9001").unwrap();
        let second = episode_row(id, "episode:20:9002").unwrap();
        let mut body = listing();
        body["episodes"]["2"][0][field] = value.clone();
        *server.body.lock().unwrap() = body.to_string();
        xtream::get_episodes(20, id, None).await.unwrap();
        assert!(sql::series_has_episodes(20, id).unwrap(), "{field}={value}");
        assert_eq!(episode_row(id, "episode:20:9001"), Some(first));
        match expected {
            Some(name) => {
                let row = episode_row(id, "episode:20:9002").unwrap();
                assert_eq!((row.0, row.1.as_str(), row.3), (second.0, name, Some(42)));
            }
            None => assert_eq!(episode_row(id, "episode:20:9002"), None),
        }
        assert_eq!(orphans(), 0, "{field}={value}");
        sql::delete_source(id).unwrap();
    }
}

#[tokio::test]
async fn tied_duplicate_episodes_pick_the_same_copy_every_load() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    *server.body.lock().unwrap() = listing().to_string();
    let id = seed(&server, "episode-tied-duplicates");
    // Same identity, season and number in two buckets; only the title differs.
    let mut body = listing();
    body["episodes"]["1"]
        .as_array_mut()
        .unwrap()
        .push(json!({"id":"9002","title":"From bucket 1","container_extension":"mp4","episode_num":1,"season":2}));
    body["episodes"]["2"][0]["title"] = json!("From bucket 2");
    *server.body.lock().unwrap() = body.to_string();
    for _ in 0..20 {
        expire(id);
        xtream::get_episodes(20, id, None).await.unwrap();
        assert_eq!(
            episode_row(id, "episode:20:9002").map(|row| row.1),
            Some("From bucket 1".to_string())
        );
    }
    sql::delete_source(id).unwrap();
}

#[tokio::test]
async fn replaced_episode_leaves_no_state_for_a_reused_id() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    let id = cached(&server, "episode-replaced").await;
    let conn = sql::get_conn().unwrap();
    // The bundled SQLite enables foreign keys, so deletes cascade to saved
    // positions and headers.
    let enforced: bool = conn
        .query_row("PRAGMA foreign_keys", [], |r| r.get(0))
        .unwrap();
    assert!(enforced);
    let old: i64 = conn
        .query_row(
            "SELECT id FROM channels WHERE source_id=? AND ext_key='episode:20:9002'",
            [id],
            |r| r.get(0),
        )
        .unwrap();
    conn.execute(
        "INSERT INTO channel_http_headers(channel_id,user_agent) VALUES (?,'old')",
        [old],
    )
    .unwrap();
    let mut body = listing();
    body["episodes"]["2"][0]["id"] = json!(9003);
    *server.body.lock().unwrap() = body.to_string();
    xtream::get_episodes(20, id, None).await.unwrap();
    assert_eq!(orphans(), 0);
    // SQLite can give a later insert the highest deleted ID back, so nothing
    // may still point at the dropped episode.
    let state: (i64, i64) = conn
        .query_row(
            "SELECT (SELECT COUNT(*) FROM movie_positions WHERE channel_id=?1),(SELECT COUNT(*) FROM channel_http_headers WHERE channel_id=?1)",
            [old],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .unwrap();
    assert_eq!(state, (0, 0));
    sql::delete_source(id).unwrap();
}

const CHANGES: &[&str] = &[
    "UPDATE sources SET enabled=0 WHERE id=?",
    "UPDATE sources SET import_series=0 WHERE id=?",
    "UPDATE sources SET source_type=0 WHERE id=?",
    "UPDATE sources SET url=url||'/changed' WHERE id=?",
    "UPDATE sources SET username='changed' WHERE id=?",
    "UPDATE sources SET password='changed' WHERE id=?",
    "UPDATE sources SET user_agent='changed' WHERE id=?",
    "UPDATE sources SET last_updated=COALESCE(last_updated,0)+1 WHERE id=?",
    "UPDATE channels SET name='Changed' WHERE source_id=? AND ext_key='2:20'",
    "UPDATE channels SET url='21' WHERE source_id=? AND ext_key='2:20'",
    "UPDATE channels SET hidden=1 WHERE source_id=? AND ext_key='2:20'",
    "UPDATE groups SET hidden=1 WHERE source_id=?",
    "UPDATE channels SET id=id+1000 WHERE source_id=? AND ext_key='2:20'",
    "DELETE FROM channels WHERE source_id=? AND ext_key='2:20'",
    "DELETE FROM sources WHERE id=?",
];

fn apply_change(id: i64, change: &str) {
    if change == "DELETE FROM sources WHERE id=?" {
        sql::delete_source(id).unwrap();
    } else {
        sql::get_conn().unwrap().execute(change, [id]).unwrap();
    }
}

fn cleanup(id: i64) {
    if sql::get_source_from_id(id).is_ok() {
        sql::delete_source(id).unwrap();
    }
}

#[tokio::test]
async fn episode_discovery_rejects_inflight_source_and_parent_changes() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    for (index, change) in CHANGES.iter().enumerate() {
        let id = cached(&server, &format!("episode-inflight-{index}")).await;
        let (started, release) = server.hold_next();
        let task = tokio::spawn(async move { xtream::get_episodes(20, id, None).await });
        tokio::time::timeout(std::time::Duration::from_secs(2), started)
            .await
            .unwrap()
            .unwrap();
        apply_change(id, change);
        let before = state(id);
        release.send(()).unwrap();
        assert!(task.await.unwrap().is_err(), "{change}");
        assert_eq!(state(id), before, "{change}");
        cleanup(id);
    }
}

#[tokio::test]
async fn episode_discovery_rejects_unsupported_or_disabled_parents_without_http() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    for (index, change) in [
        CHANGES[0],
        CHANGES[1],
        CHANGES[2],
        CHANGES[9],
        CHANGES[10],
        CHANGES[11],
        CHANGES[13],
        CHANGES[14],
    ]
    .into_iter()
    .enumerate()
    {
        let id = cached(&server, &format!("episode-no-http-{index}")).await;
        // Even a previously loaded cache cannot bypass source eligibility.
        sql::get_conn()
            .unwrap()
            .execute(
                "UPDATE channels SET episodes_loaded=1 WHERE source_id=? AND ext_key='2:20'",
                [id],
            )
            .unwrap();
        apply_change(id, change);
        let before = state(id);
        let requests = server.requests.load(Ordering::SeqCst);
        assert!(
            xtream::get_episodes(20, id, None).await.is_err(),
            "{change}"
        );
        assert_eq!(server.requests.load(Ordering::SeqCst), requests);
        assert_eq!(state(id), before);
        cleanup(id);
    }
}

#[tokio::test]
async fn episode_success_preserves_ids_and_lazy_cache_until_expired() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    let id = cached(&server, "episode-valid-refresh").await;
    let before = state(id);
    let mut whitespace_id = listing();
    whitespace_id["episodes"]["2"][0]["id"] = json!(" 9002 ");
    *server.body.lock().unwrap() = whitespace_id.to_string();
    xtream::get_episodes(20, id, None).await.unwrap();
    assert!(sql::series_has_episodes(20, id).unwrap());
    let after = state(id);
    // The loaded marker is the only change for identical provider data.
    expire(id);
    assert_eq!(state(id), before);
    xtream::get_episodes(20, id, None).await.unwrap();
    assert_eq!(state(id), after);
    let requests = server.requests.load(Ordering::SeqCst);
    xtream::get_episodes(20, id, None).await.unwrap();
    assert_eq!(server.requests.load(Ordering::SeqCst), requests);

    let conn = sql::get_conn().unwrap();
    let saved: (i64,i64,i64,i64,i64) = conn.query_row("SELECT c.id,c.favorite,c.last_watched,c.season_id,p.position FROM channels c JOIN movie_positions p ON p.channel_id=c.id WHERE c.source_id=? AND c.ext_key='episode:20:9001'",[id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?))).unwrap();
    let removed: i64 = conn
        .query_row(
            "SELECT id FROM channels WHERE source_id=? AND ext_key='episode:20:9002'",
            [id],
            |r| r.get(0),
        )
        .unwrap();
    let mut shorter = listing();
    shorter["episodes"].as_object_mut().unwrap().remove("2");
    shorter["episodes"]["1"][0]["title"] = json!("Renamed episode");
    *server.body.lock().unwrap() = shorter.to_string();
    expire(id);
    xtream::get_episodes(20, id, None).await.unwrap();
    let updated: (i64,i64,i64,i64,i64) = conn.query_row("SELECT c.id,c.favorite,c.last_watched,c.season_id,p.position FROM channels c JOIN movie_positions p ON p.channel_id=c.id WHERE c.source_id=? AND c.ext_key='episode:20:9001'",[id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?))).unwrap();
    assert_eq!(updated, saved);
    assert_eq!(
        conn.query_row("SELECT name FROM channels WHERE id=?", [saved.0], |r| {
            r.get::<_, String>(0)
        })
        .unwrap(),
        "Renamed episode"
    );
    assert_eq!(
        conn.query_row(
            "SELECT COUNT(*) FROM channels WHERE source_id=? AND series_id=20",
            [id],
            |r| r.get::<_, i64>(0)
        )
        .unwrap(),
        1
    );
    assert_eq!(
        conn.query_row(
            "SELECT COUNT(*) FROM seasons WHERE source_id=?",
            [id],
            |r| r.get::<_, i64>(0)
        )
        .unwrap(),
        1
    );
    assert_eq!(
        conn.query_row(
            "SELECT COUNT(*) FROM movie_positions WHERE channel_id=?",
            [removed],
            |r| r.get::<_, i64>(0)
        )
        .unwrap(),
        0
    );
    sql::delete_source(id).unwrap();
}

fn filters(id: i64, media_types: &[u8], view_type: u8) -> crate::types::Filters {
    crate::types::Filters {
        query: None,
        source_ids: vec![id],
        media_types: Some(media_types.to_vec()),
        view_type,
        page: 1,
        series_id: None,
        group_id: None,
        use_keywords: false,
        sort: crate::sort_type::ALPHABETICAL_ASC,
        season: None,
        favorite_groups: false,
        hidden_only: false,
        include_hidden: false,
    }
}

fn names(selection: crate::types::Filters) -> Vec<String> {
    let mut names = sql::search(selection)
        .unwrap()
        .into_iter()
        .map(|channel| channel.name)
        .collect::<Vec<_>>();
    names.sort();
    names
}

#[tokio::test]
async fn episode_visibility_follows_series_in_root_favorites_and_history() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    let id = seed(&server, "episode-semantic-visibility");
    xtream::get_episodes(20, id, None).await.unwrap();
    let conn = sql::get_conn().unwrap();
    conn.execute(
        "UPDATE channels SET favorite=1,last_watched=123 WHERE source_id=? AND series_id=20",
        [id],
    )
    .unwrap();
    for (name, media_type, url) in [
        ("Movie", 1, "http://fixture/movie.mp4"),
        ("Live", 0, "http://fixture/live.ts"),
        ("Direct series", 2, "http://fixture/series/direct.mp4"),
    ] {
        conn.execute("INSERT INTO channels(name,url,source_id,media_type,favorite,last_watched) VALUES (?,?,?,?,1,123)",rusqlite::params![name,url,id,media_type]).unwrap();
    }
    for view in [0, crate::view_type::FAVORITES, crate::view_type::HISTORY] {
        // Outside Favorites and History the series tile stands for its episodes.
        let mut series = if view == 0 {
            vec!["Direct series", "Show"]
        } else {
            vec!["Direct series", "First episode", "Second episode"]
        };
        series.sort();
        assert_eq!(
            names(filters(id, &[2], view)),
            series,
            "series-only view {view}"
        );
        assert_eq!(
            names(filters(id, &[1], view)),
            ["Movie"],
            "movies-only view {view}"
        );
        assert_eq!(
            names(filters(id, &[0], view)),
            ["Live"],
            "live-only view {view}"
        );
        let mut combined = series.clone();
        combined.push("Movie");
        combined.sort();
        assert_eq!(names(filters(id, &[1, 2], view)), combined);
        assert!(names(filters(id, &[], view)).is_empty());
    }
    // Import switches independently gate the corresponding semantic type.
    conn.execute("UPDATE sources SET import_movies=0 WHERE id=?", [id])
        .unwrap();
    assert_eq!(
        names(filters(id, &[1, 2], crate::view_type::FAVORITES)),
        ["Direct series", "First episode", "Second episode"]
    );
    assert!(names(filters(id, &[1], crate::view_type::HISTORY)).is_empty());
    conn.execute(
        "UPDATE sources SET import_movies=1,import_series=0 WHERE id=?",
        [id],
    )
    .unwrap();
    assert_eq!(
        names(filters(id, &[1, 2], crate::view_type::FAVORITES)),
        ["Movie"]
    );
    assert!(names(filters(id, &[2], crate::view_type::HISTORY)).is_empty());
    conn.execute("UPDATE sources SET import_movies=0 WHERE id=?", [id])
        .unwrap();
    assert!(names(filters(id, &[1, 2], 0)).is_empty());
    conn.execute(
        "UPDATE sources SET import_movies=1,import_series=1,enabled=0 WHERE id=?",
        [id],
    )
    .unwrap();
    assert!(names(filters(id, &[0, 1, 2], crate::view_type::FAVORITES)).is_empty());
    sql::delete_source(id).unwrap();
}

#[tokio::test]
async fn episode_drilldown_uses_series_import_gate_without_movie_imports() {
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    let id = seed(&server, "episode-drilldown-visibility");
    xtream::get_episodes(20, id, None).await.unwrap();
    let conn = sql::get_conn().unwrap();
    conn.execute("UPDATE sources SET import_movies=0 WHERE id=?", [id])
        .unwrap();
    let mut selection = filters(id, &[2], 0);
    selection.series_id = Some(20);
    let seasons = sql::search(selection.clone()).unwrap();
    assert_eq!(
        seasons.iter().map(|s| s.name.as_str()).collect::<Vec<_>>(),
        ["Season 1", "Season 2"]
    );
    selection.season = seasons[0].id;
    assert_eq!(names(selection.clone()), ["First episode"]);
    selection.season = seasons[1].id;
    assert_eq!(names(selection.clone()), ["Second episode"]);
    // A root Movies query must never gain cached episodes from the drilldown.
    assert!(names(filters(id, &[1], 0)).is_empty());
    conn.execute(
        "UPDATE sources SET import_movies=1,import_series=0 WHERE id=?",
        [id],
    )
    .unwrap();
    assert!(names(selection.clone()).is_empty());
    selection.season = None;
    assert!(names(selection.clone()).is_empty());
    conn.execute(
        "UPDATE sources SET import_series=1,enabled=0 WHERE id=?",
        [id],
    )
    .unwrap();
    assert!(names(selection.clone()).is_empty());
    selection.season = seasons[0].id;
    assert!(names(selection).is_empty());
    sql::delete_source(id).unwrap();
}

#[tokio::test]
async fn episode_visibility_paginates_without_duplicates_or_movie_leaks() {
    use std::collections::BTreeSet;
    let _guard = sql::test_lock_async().await;
    let server = EpisodeServer::new().await;
    let id = seed(&server, "episode-paginated-visibility");
    let other = seed(&server, "episode-paginated-other-source");
    let conn = sql::get_conn().unwrap();
    let root: i64 = conn
        .query_row(
            "SELECT id FROM channels WHERE source_id=? AND ext_key='2:20'",
            [id],
            |r| r.get(0),
        )
        .unwrap();
    let mut episode_ids = BTreeSet::new();
    let mut movie_ids = BTreeSet::new();
    for (count, series) in [(73, true), (80, false)] {
        for number in 0..count {
            conn.execute("INSERT INTO channels(name,url,source_id,media_type,series_id,position,favorite,last_watched) VALUES (?,?,?,1,?,?,1,123)",rusqlite::params![format!("{} {number:03}",if series {"Episode"}else{"Movie"}),format!("http://fixture/{series}/{number}.mp4"),id,series.then_some(20),number]).unwrap();
            if series {
                episode_ids.insert(conn.last_insert_rowid());
            } else {
                movie_ids.insert(conn.last_insert_rowid());
            }
        }
    }
    conn.execute("INSERT INTO channels(name,url,source_id,media_type,series_id,favorite,last_watched) VALUES ('Other episode','http://fixture/other.mp4',?,1,20,1,123)",[other]).unwrap();
    for view in [0, crate::view_type::FAVORITES, crate::view_type::HISTORY] {
        for sort in [
            crate::sort_type::PROVIDER,
            crate::sort_type::ALPHABETICAL_ASC,
            crate::sort_type::ALPHABETICAL_DESC,
        ] {
            for kinds in [&[2][..], &[1][..], &[1, 2][..]] {
                let mut expected = BTreeSet::new();
                if kinds.contains(&2) {
                    if view == 0 {
                        expected.insert(root);
                    } else {
                        expected.extend(&episode_ids);
                    }
                }
                if kinds.contains(&1) {
                    expected.extend(&movie_ids);
                }
                let mut selection = filters(id, kinds, view);
                selection.sort = sort;
                let mut seen = BTreeSet::new();
                for page in 1..=6 {
                    selection.page = page;
                    let batch = sql::search(selection.clone()).unwrap();
                    assert!(batch.len() <= 36);
                    if batch.is_empty() {
                        break;
                    }
                    for channel in batch {
                        assert_eq!(channel.source_id, Some(id));
                        // Rows don't carry series_id; episodes are known by ID.
                        let kind = if episode_ids.contains(&channel.id.unwrap()) {
                            2
                        } else {
                            channel.media_type
                        };
                        assert!(
                            kinds.contains(&kind),
                            "{} kind {kind} view {view} kinds {kinds:?}",
                            channel.name
                        );
                        assert!(seen.insert(channel.id.unwrap()), "duplicate on page {page}");
                    }
                }
                assert_eq!(seen, expected, "view {view}, sort {sort}, kinds {kinds:?}");
            }
        }
    }
    let mut selection = filters(id, &[2], crate::view_type::FAVORITES);
    selection.query = Some("Episode 07".into());
    assert_eq!(
        names(selection),
        ["Episode 070", "Episode 071", "Episode 072"]
    );
    let mut category = filters(id, &[2], crate::view_type::CATEGORIES);
    category.group_id = conn
        .query_row("SELECT group_id FROM channels WHERE id=?", [root], |r| {
            r.get(0)
        })
        .unwrap();
    assert_eq!(names(category), ["Show"]);
    assert_eq!(server.requests.load(Ordering::SeqCst), 0);

    sql::delete_source(id).unwrap();
    sql::delete_source(other).unwrap();
}
