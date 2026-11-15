use std::path::PathBuf;
use std::str::FromStr;
use std::sync::OnceLock;
use std::vec;
use std::{collections::HashMap, sync::LazyLock};

use crate::sort_type;
use crate::types::Season;
use crate::{
    media_type,
    types::{Channel, ChannelHttpHeaders, Filters, Source},
    view_type,
};
use anyhow::{Context, Result, anyhow};
use r2d2::{Pool, PooledConnection};
use r2d2_sqlite::SqliteConnectionManager;
use rusqlite::{OptionalExtension, Row, Transaction, params, params_from_iter};
use rusqlite_migration::{M, Migrations};

const PAGE_SIZE: u8 = 36;
pub const DB_NAME: &str = "db_rust.sqlite";
pub const LAST_SEEN_VERSION_KEY: &str = "last_seen_version";
pub static DB_PATH_OVERRIDE: OnceLock<String> = OnceLock::new();
static CONN: LazyLock<Pool<SqliteConnectionManager>> = LazyLock::new(create_connection_pool);

pub fn get_conn() -> Result<PooledConnection<SqliteConnectionManager>> {
    CONN.get_timeout(std::time::Duration::from_secs(5))
        .context("SQLite connection pool is busy")
}

fn create_connection_pool() -> Pool<SqliteConnectionManager> {
    let manager = SqliteConnectionManager::file(get_and_create_sqlite_db_path()).with_init(|conn| {
        conn.execute_batch("PRAGMA busy_timeout=5000; PRAGMA journal_mode=WAL; PRAGMA journal_size_limit=16777216; PRAGMA synchronous=NORMAL; PRAGMA temp_store=MEMORY; PRAGMA cache_size=-8192;")
    });
    r2d2::Pool::builder()
        .max_size(8)
        .min_idle(Some(1))
        .build(manager)
        .unwrap()
}

fn get_and_create_sqlite_db_path() -> String {
    let mut path = PathBuf::from_str(DB_PATH_OVERRIDE.get().unwrap()).unwrap();
    if !path.exists() {
        std::fs::create_dir_all(&path).unwrap();
    }
    path.push(DB_NAME);
    path.to_string_lossy().to_string()
}

pub fn apply_migrations() -> Result<()> {
    let mut sql = get_conn()?;
    migrations().to_latest(&mut sql)?;
    Ok(())
}

fn migrations() -> Migrations<'static> {
    Migrations::new(vec![
        M::up(
            r#"
CREATE TABLE "sources" (
  "id"                INTEGER PRIMARY KEY,
  "name"              varchar(100),
  "source_type"       integer,
  "url"               varchar(500),
  "username"          varchar(100),
  "password"          varchar(100),
  "enabled"           integer DEFAULT 1,
  "user_agent"        varchar(500),
  "stream_user_agent" varchar(500),
  "last_updated"      integer
);

CREATE TABLE "groups" (
  "id"          INTEGER PRIMARY KEY,
  "name"        varchar(100),
  "image"       varchar(500),
  "source_id"   integer,
  "media_type"  integer,
  FOREIGN KEY (source_id) REFERENCES sources(id)
);

CREATE TABLE "channels" (
  "id"           INTEGER PRIMARY KEY,
  "name"         varchar(100),
  "image"        varchar(500),
  "url"          varchar(500),
  "media_type"   integer,
  "source_id"    integer,
  "favorite"     integer,
  "series_id"    integer,
  "group_id"     integer,
  "stream_id"    integer,
  "last_watched" integer,
  "tv_archive"   integer,
  "season_id"    integer,
  "episode_num"  integer,
  FOREIGN KEY (source_id) REFERENCES sources(id),
  FOREIGN KEY (group_id) REFERENCES groups(id)
);

CREATE TABLE "channel_http_headers" (
  "id"           INTEGER PRIMARY KEY,
  "channel_id"   integer,
  "referrer"     varchar(500),
  "user_agent"   varchar(500),
  "http_origin"  varchar(500),
  "ignore_ssl"   integer DEFAULT 0,
  FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
);

CREATE TABLE "movie_positions" (
  "id"         INTEGER PRIMARY KEY,
  "channel_id" integer,
  "position"   integer,
  FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
);

CREATE TABLE "seasons" (
  "id"            INTEGER PRIMARY KEY,
  "name"          VARCHAR(50),
  "season_number" integer,
  "series_id"     integer,
  "source_id"     integer,
  "image"         varchar(200),
  FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
);

CREATE TABLE "settings" (
  "key"   VARCHAR(50) PRIMARY KEY,
  "value" VARCHAR(100)
);

CREATE INDEX index_channel_name ON channels(name);
CREATE UNIQUE INDEX channels_unique ON channels(name, source_id, url, series_id, season_id);

CREATE UNIQUE INDEX index_source_name ON sources(name);
CREATE INDEX index_source_enabled ON sources(enabled);

CREATE UNIQUE INDEX index_group_unique ON groups(name, source_id);
CREATE INDEX index_group_name ON groups(name);

CREATE INDEX index_channel_source_id ON channels(source_id);
CREATE INDEX index_channel_favorite ON channels(favorite);
CREATE INDEX index_channel_series_id ON channels(series_id);
CREATE INDEX index_channel_group_id ON channels(group_id);
CREATE INDEX index_channel_media_type ON channels(media_type);
CREATE INDEX index_channels_stream_id ON channels(stream_id);
CREATE INDEX index_channels_last_watched ON channels(last_watched);
CREATE INDEX index_channels_tv_archive ON channels(tv_archive);
CREATE INDEX index_channels_season_id ON channels(season_id);
CREATE INDEX index_channels_episode_num ON channels(episode_num);

CREATE INDEX index_group_source_id ON groups(source_id);
CREATE INDEX index_groups_media_type ON groups(media_type);

CREATE UNIQUE INDEX index_channel_http_headers_channel_id ON channel_http_headers(channel_id);
CREATE UNIQUE INDEX index_movie_positions_channel_id ON movie_positions(channel_id);
CREATE UNIQUE INDEX unique_seasons ON seasons(season_number, series_id, source_id);

ANALYZE;
"#,
        ),
        M::up(MIGRATION_2),
        M::up("CREATE INDEX channels_source_type_position ON channels(source_id, media_type, position, id);
CREATE INDEX channels_source_type_name ON channels(source_id, media_type, name);
CREATE INDEX channels_favorites ON channels(source_id, media_type, name) WHERE favorite = 1;
CREATE INDEX channels_history ON channels(last_watched DESC) WHERE last_watched IS NOT NULL;"),
        M::up("ALTER TABLE channels ADD COLUMN episodes_loaded INTEGER NOT NULL DEFAULT 0;
CREATE INDEX channels_source_position ON channels(source_id, position, id) WHERE url IS NOT NULL;
CREATE INDEX channels_source_name ON channels(source_id, name, id) WHERE url IS NOT NULL;
DROP INDEX index_channel_source_id;
DROP INDEX index_channel_name;
DROP INDEX index_channels_stream_id;
DROP INDEX index_channels_tv_archive;
DROP INDEX index_channels_last_watched;
DROP INDEX channels_unique;
DROP INDEX index_channel_media_type;
DROP INDEX index_channel_favorite;
DROP INDEX index_channels_episode_num;"),
        M::up("ALTER TABLE groups ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0;"),
        M::up("ALTER TABLE channels ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0;
ALTER TABLE groups ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0;
ALTER TABLE channels ADD COLUMN archive_days INTEGER;
ALTER TABLE channels ADD COLUMN epg_id TEXT;
ALTER TABLE sources ADD COLUMN epg_url TEXT;"),
        // favorite holds the user's order (1, 2, …); 0 means not a favorite.
        M::up("DROP INDEX channels_favorites;
CREATE INDEX channels_favorites ON channels(favorite) WHERE favorite > 0;"),
    ])
}

/// brenTV schema: selective import, category filters, refresh statistics,
/// stable provider identity for incremental refresh, and alternate feeds.
const MIGRATION_2: &str = r#"
ALTER TABLE sources ADD COLUMN import_live INTEGER NOT NULL DEFAULT 1;
ALTER TABLE sources ADD COLUMN import_movies INTEGER NOT NULL DEFAULT 1;
ALTER TABLE sources ADD COLUMN import_series INTEGER NOT NULL DEFAULT 1;
ALTER TABLE sources ADD COLUMN category_mode_live INTEGER NOT NULL DEFAULT 0;
ALTER TABLE sources ADD COLUMN category_mode_movies INTEGER NOT NULL DEFAULT 0;
ALTER TABLE sources ADD COLUMN category_mode_series INTEGER NOT NULL DEFAULT 0;
ALTER TABLE sources ADD COLUMN last_refresh_stats BLOB;

CREATE TABLE source_categories (
  "id"           INTEGER PRIMARY KEY,
  "source_id"    integer NOT NULL,
  "media_type"   integer NOT NULL,
  "name"         varchar(200) NOT NULL,
  "ext_id"       varchar(50),
  "listed"       integer NOT NULL DEFAULT 0,
  "stream_count" integer,
  FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_source_categories_unique ON source_categories(source_id, media_type, name);

ALTER TABLE channels ADD COLUMN ext_key varchar(100);
ALTER TABLE channels ADD COLUMN position integer;
ALTER TABLE channels ADD COLUMN alt_key varchar(100);
ALTER TABLE channels ADD COLUMN quality integer NOT NULL DEFAULT 0;
CREATE UNIQUE INDEX index_channels_ext_key ON channels(source_id, ext_key) WHERE ext_key IS NOT NULL;
CREATE INDEX index_channels_alt_key ON channels(alt_key) WHERE alt_key IS NOT NULL;

-- Overrides name feeds by their provider identity (source_id, ext_key), so
-- they survive refreshes and same-named feeds stay distinct. kind: 0 unlink,
-- 1 link (to the target feed's group), 2 preferred. A feed has at most one
-- of unlink/link.
CREATE TABLE alt_overrides (
  "id"               INTEGER PRIMARY KEY,
  "source_id"        integer NOT NULL,
  "ext_key"          varchar(100) NOT NULL,
  "kind"             integer NOT NULL,
  "target_source_id" integer,
  "target_ext_key"   varchar(100),
  FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_alt_overrides_unique ON alt_overrides(source_id, ext_key, kind);

-- Adopt upstream rows: give them the ext_key a refresh computes, so the first
-- incremental refresh keeps their ids (favourites, history, positions).
-- Xtream live/movie "<media_type>:<stream_id>", Xtream series "2:<series_id>"
-- (upstream stores the series id in url), M3U "<url>\t<name>". Episodes keep
-- NULL (re-fetched on demand). Duplicates stay NULL (OR IGNORE) and are
-- replaced by the refresh.
UPDATE OR IGNORE channels SET ext_key = media_type || ':' || stream_id
WHERE ext_key IS NULL AND series_id IS NULL AND media_type IN (0, 1) AND stream_id IS NOT NULL
  AND source_id IN (SELECT id FROM sources WHERE source_type = 2);
UPDATE OR IGNORE channels SET ext_key = '2:' || url
WHERE ext_key IS NULL AND series_id IS NULL AND media_type = 2 AND url IS NOT NULL
  AND source_id IN (SELECT id FROM sources WHERE source_type = 2);
UPDATE OR IGNORE channels SET ext_key = url || char(9) || name
WHERE ext_key IS NULL AND series_id IS NULL AND url IS NOT NULL
  AND source_id IN (SELECT id FROM sources WHERE source_type IN (0, 1));
UPDATE channels SET position = id WHERE position IS NULL;
"#;

/// Creates a new source without importing and returns the stored row; see
/// `save_source` FFI. An existing name is an error (the unique index makes
/// this atomic), so cancelling a draft only ever deletes a source it created.
pub fn save_source(source: Source) -> Result<Source> {
    let id = do_tx(|tx| insert_source(tx, &source)).map_err(|e| {
        match e.downcast_ref::<rusqlite::Error>() {
            Some(rusqlite::Error::SqliteFailure(f, _))
                if f.code == rusqlite::ErrorCode::ConstraintViolation =>
            {
                anyhow!("A source named \"{}\" already exists", source.name)
            }
            _ => e,
        }
    })?;
    get_source_from_id(id)
}

fn insert_source(tx: &Transaction, source: &Source) -> Result<i64> {
    tx.execute(
        r#"
        INSERT INTO sources (name, source_type, url, username, password, enabled, user_agent,
            stream_user_agent, last_updated, import_live, import_movies, import_series, epg_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        "#,
        params![
            source.name,
            source.source_type,
            source.url,
            source.username,
            source.password,
            source.enabled,
            source.user_agent,
            source.stream_user_agent,
            chrono::Utc::now().timestamp(),
            source.import_live,
            source.import_movies,
            source.import_series,
            source.epg_url
        ],
    )?;
    Ok(tx.last_insert_rowid())
}

pub fn create_or_find_source_by_name(tx: &Transaction, source: &Source) -> Result<i64> {
    let id: Option<i64> = tx
        .query_row(
            "SELECT id FROM sources WHERE name = ?1",
            params![source.name],
            |r| r.get(0),
        )
        .optional()?;
    if let Some(id) = id {
        return Ok(id);
    }
    insert_source(tx, source)
}

pub fn insert_season(tx: &Transaction, season: Season) -> Result<i64> {
    tx.execute(
        r#"
        INSERT INTO seasons (name, image, series_id, season_number, source_id)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT (series_id, season_number, source_id)
        DO UPDATE SET
          image = excluded.image,
          name = excluded.name
        "#,
        params![
            season.name,
            season.image,
            season.series_id,
            season.season_number,
            season.source_id,
        ],
    )?;
    Ok(tx.query_row(
        r#"
        SELECT id
        FROM seasons
        WHERE series_id = ?
        AND season_number = ?
        AND source_id = ?
      "#,
        params![season.series_id, season.season_number, season.source_id],
        |r| r.get(0),
    )?)
}

pub fn insert_channel_headers(tx: &Transaction, headers: ChannelHttpHeaders) -> Result<()> {
    tx.execute(
        r#"
INSERT OR IGNORE INTO channel_http_headers (channel_id, referrer, user_agent, http_origin, ignore_ssl)
VALUES (?, ?, ?, ?, ?);
"#,
        params![
            headers.channel_id,
            headers.referrer,
            headers.user_agent,
            headers.http_origin,
            headers.ignore_ssl
        ],
    )?;
    Ok(())
}

fn get_or_insert_group(
    tx: &Transaction,
    group: &str,
    image: &Option<String>,
    source_id: &i64,
    media_type: u8,
) -> Result<i64> {
    Ok(tx.prepare_cached("INSERT INTO groups(name,image,source_id,media_type) VALUES (?,?,?,?) ON CONFLICT(name,source_id) DO UPDATE SET image=COALESCE(excluded.image,groups.image), media_type=CASE WHEN groups.media_type=excluded.media_type THEN groups.media_type ELSE NULL END RETURNING id")?.query_row(params![group,image,source_id,media_type], |r| r.get(0))?)
}

pub fn set_channel_group_id(
    groups: &mut HashMap<String, i64>,
    channel: &mut Channel,
    tx: &Transaction,
    source_id: &i64,
) -> Result<()> {
    if channel.group.is_none() {
        return Ok(());
    }
    if !groups.contains_key(channel.group.as_ref().unwrap()) {
        let id = get_or_insert_group(
            tx,
            channel.group.as_ref().unwrap(),
            &channel.image,
            source_id,
            channel.media_type,
        )?;
        groups.insert(channel.group.clone().unwrap(), id);
        channel.group_id = Some(id);
    } else {
        channel.group_id = groups
            .get(channel.group.as_ref().unwrap())
            .map(|x| x.to_owned());
    }
    Ok(())
}

pub fn get_channel_headers_by_id(id: i64) -> Result<Option<ChannelHttpHeaders>> {
    Ok(get_conn()?.query_row(
        "SELECT h.id,c.id AS channel_id,h.referrer,COALESCE(NULLIF(h.user_agent,''),NULLIF(s.stream_user_agent,''),NULLIF(s.user_agent,'')) AS user_agent,h.http_origin,COALESCE(h.ignore_ssl,0) AS ignore_ssl FROM channels c JOIN sources s ON s.id=c.source_id LEFT JOIN channel_http_headers h ON h.channel_id=c.id WHERE c.id=? AND (h.id IS NOT NULL OR NULLIF(s.stream_user_agent,'') IS NOT NULL OR NULLIF(s.user_agent,'') IS NOT NULL)",
        [id], row_to_channel_headers).optional()?)
}

fn row_to_channel_headers(row: &Row) -> Result<ChannelHttpHeaders, rusqlite::Error> {
    Ok(ChannelHttpHeaders {
        id: row.get("id")?,
        channel_id: row.get("channel_id")?,
        http_origin: row.get("http_origin")?,
        referrer: row.get("referrer")?,
        user_agent: row.get("user_agent")?,
        ignore_ssl: row.get("ignore_ssl")?,
    })
}

pub fn get_settings() -> Result<HashMap<String, String>> {
    let sql = get_conn()?;
    // A failed read must not look like an empty table: the next save would
    // write every default over the user's settings.
    let rows = sql
        .prepare("SELECT key, value FROM Settings")?
        .query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, Option<String>>(1)?))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    Ok(rows
        .into_iter()
        .filter_map(|(key, value)| Some((key, value?)))
        .collect())
}

pub fn update_settings(map: HashMap<String, Option<String>>) -> Result<()> {
    let mut sql: PooledConnection<SqliteConnectionManager> = get_conn()?;
    let tx = sql.transaction()?;
    for (key, value) in map {
        tx.execute(
            r#"
            INSERT INTO Settings (key, value)
            VALUES (?1, ?2)
            ON CONFLICT(key) DO UPDATE SET value = ?2
            "#,
            params![key, value],
        )?;
    }
    tx.commit()?;
    Ok(())
}

pub fn search(filters: Filters) -> Result<Vec<Channel>> {
    if (filters.favorite_groups || filters.view_type == view_type::CATEGORIES)
        && filters.group_id.is_none()
        && filters.series_id.is_none()
    {
        return search_group(filters);
    }
    if filters.series_id.is_some() && filters.season.is_none() {
        return search_series(filters);
    }
    let sql = get_conn()?;
    let offset = page_offset(filters.page);
    let mut media_types = match filters.series_id.is_some() {
        true => vec![1],
        false => filters.media_types.clone().unwrap_or_default(),
    };
    // Episodes are stored as movies but follow Series. Outside their series
    // only Favorites and History list them; elsewhere the series tile does.
    let episodes = filters.series_id.is_none()
        && media_types.contains(&media_type::SERIE)
        && (filters.view_type == view_type::FAVORITES || filters.view_type == view_type::HISTORY);
    let episodes_only = episodes && !media_types.contains(&media_type::MOVIE);
    if episodes_only {
        media_types.push(media_type::MOVIE);
    }
    let query = filters.query.clone().unwrap_or("".to_string());
    let keywords: Vec<String> = match filters.use_keywords {
        true => query
            .split(" ")
            .map(|f| format!("%{f}%").to_string())
            .collect(),
        false => vec![format!("%{query}%")],
    };
    let ordered_index = if filters.source_ids.len() == 1
        && media_types.len() > 1
        && filters.view_type != view_type::HISTORY
        && filters.view_type != view_type::FAVORITES
        && filters.group_id.is_none()
        && filters.series_id.is_none()
    {
        if filters.sort == sort_type::PROVIDER {
            " INDEXED BY channels_source_position"
        } else {
            " INDEXED BY channels_source_name"
        }
    } else {
        ""
    };
    let mut sql_query = format!(
        r#"
        SELECT * FROM CHANNELS{ordered_index}
        WHERE ({})
        AND media_type IN ({})
        AND source_id IN ({})
        AND url IS NOT NULL
        AND EXISTS (SELECT 1 FROM sources s WHERE s.id=channels.source_id AND s.enabled=1 AND CASE WHEN channels.series_id IS NOT NULL THEN s.import_series WHEN channels.media_type=0 THEN s.import_live WHEN channels.media_type=1 THEN s.import_movies WHEN channels.media_type=2 THEN s.import_series ELSE 1 END=1)"#,
        get_keywords_sql(keywords.len()),
        generate_placeholders(media_types.len()),
        generate_placeholders(filters.source_ids.len()),
    );
    if filters.series_id.is_none() {
        if !episodes {
            sql_query += " AND series_id IS NULL";
        } else if episodes_only {
            sql_query += " AND (media_type!=1 OR series_id IS NOT NULL)";
        }
    }
    sql_query += &visibility(&filters, false);
    let mut baked_params = 2;
    let favorites = filters.view_type == view_type::FAVORITES && filters.series_id.is_none();
    if favorites {
        sql_query += "\nAND favorite > 0";
    }

    if filters.series_id.is_some() {
        sql_query += "\nAND series_id = ?";
        baked_params += 1;
    } else if filters.group_id.is_some() {
        sql_query += "\nAND group_id = ?";
        baked_params += 1;
    }
    if filters.season.is_some() {
        sql_query += "\nAND season_id = ?";
        baked_params += 1;
    }
    let order = match filters.sort {
        sort_type::ALPHABETICAL_DESC => "DESC",
        _ => "ASC",
    };
    if filters.view_type == view_type::HISTORY {
        sql_query += "\nAND last_watched IS NOT NULL";
        sql_query += "\nORDER BY last_watched DESC";
    } else if filters.season.is_some() {
        sql_query += &format!("\nORDER BY episode_num {0}, name {0}", order)
    } else if filters.sort != sort_type::PROVIDER {
        sql_query += &format!("\nORDER BY name {}", order);
    } else if favorites {
        sql_query += "\nORDER BY favorite, position, id";
    } else {
        sql_query += "\nORDER BY position, id";
    }
    sql_query += "\nLIMIT ?, ?";
    let mut params: Vec<&dyn rusqlite::ToSql> = Vec::with_capacity(
        baked_params + media_types.len() + filters.source_ids.len() + keywords.len(),
    );
    params.extend(to_to_sql(&keywords));
    params.extend(to_to_sql(&media_types));
    params.extend(to_to_sql(&filters.source_ids));
    if let Some(ref series_id) = filters.series_id {
        params.push(series_id);
    } else if let Some(ref group) = filters.group_id {
        params.push(group);
    }
    if let Some(ref season) = filters.season {
        params.push(season);
    }
    params.push(&offset);
    params.push(&PAGE_SIZE);
    let channels: Vec<Channel> = sql
        .prepare_cached(&sql_query)?
        .query_map(params_from_iter(params), row_to_channel)?
        .filter_map(Result::ok)
        .collect();
    Ok(channels)
}

fn search_series(filters: Filters) -> Result<Vec<Channel>> {
    let sql = get_conn()?;
    let offset = page_offset(filters.page);
    let query = filters.query.clone().unwrap_or("".to_string());
    let keywords: Vec<String> = match filters.use_keywords {
        true => query
            .split(" ")
            .map(|f| format!("%{f}%").to_string())
            .collect(),
        false => vec![format!("%{query}%")],
    };
    let mut sql_query = format!(
        r#"
      SELECT *
      FROM seasons
      WHERE ({})
      AND source_id = ?
      AND series_id = ?
      "#,
        get_keywords_sql(keywords.len()),
    );
    sql_query += " AND EXISTS (SELECT 1 FROM sources s WHERE s.id=seasons.source_id AND s.enabled=1 AND s.import_series=1)";
    if !filters.include_hidden || filters.hidden_only {
        let hidden = "EXISTS (SELECT 1 FROM channels p WHERE p.source_id=seasons.source_id AND p.ext_key='2:'||seasons.series_id AND (p.hidden=1 OR EXISTS (SELECT 1 FROM groups g WHERE g.id=p.group_id AND g.hidden=1)))";
        sql_query += &format!(
            " AND {} ({hidden})",
            if filters.hidden_only { "" } else { "NOT" }
        );
    }
    let order = match filters.sort {
        sort_type::ALPHABETICAL_DESC => "DESC",
        _ => "ASC",
    };
    sql_query += &format!("\nORDER BY season_number {}", order);
    sql_query += "\nLIMIT ?, ?";
    let mut params: Vec<&dyn rusqlite::ToSql> =
        Vec::with_capacity(2 + filters.source_ids.len() + keywords.len());
    params.extend(to_to_sql(&keywords));
    params.push(filters.source_ids.first().context("no source ids")?);
    params.push(filters.series_id.as_ref().context("no series id")?);
    params.push(&offset);
    params.push(&PAGE_SIZE);
    let channels: Vec<Channel> = sql
        .prepare_cached(&sql_query)?
        .query_map(params_from_iter(params), season_row_to_channel)?
        .filter_map(Result::ok)
        .collect();
    Ok(channels)
}

fn season_row_to_channel(row: &Row) -> std::result::Result<Channel, rusqlite::Error> {
    Ok(Channel {
        id: row.get("id")?,
        image: row.get("image")?,
        hidden: false,
        archive_days: None,
        epg_id: None,
        favorite: false,
        group: None,
        group_id: None,
        media_type: media_type::SEASON,
        name: row.get("name")?,
        series_id: row.get("series_id")?,
        season_id: None,
        source_id: row.get("source_id")?,
        stream_id: None,
        tv_archive: None,
        url: None,
        episode_num: None,
        quality: 0,
        alt_key: None,
    })
}

/// Row offset of a 1-based page, in i64 so deep pages can't overflow.
fn page_offset(page: u32) -> i64 {
    (page.max(1) as i64 - 1) * PAGE_SIZE as i64
}

fn to_to_sql<T: rusqlite::ToSql>(values: &[T]) -> Vec<&dyn rusqlite::ToSql> {
    values.iter().map(|x| x as &dyn rusqlite::ToSql).collect()
}

fn get_keywords_sql(size: usize) -> String {
    std::iter::repeat_n("name LIKE ?", size)
        .collect::<Vec<_>>()
        .join(" AND ")
}

fn generate_placeholders(size: usize) -> String {
    std::iter::repeat_n("?", size).collect::<Vec<_>>().join(",")
}

#[cfg(test)]
pub fn series_has_episodes(series_id: i64, source_id: i64) -> Result<bool> {
    Ok(get_conn()?.query_row(
        "SELECT episodes_loaded FROM channels WHERE source_id=? AND media_type=2 AND ext_key=? AND series_id IS NULL LIMIT 1",
        params![source_id, format!("2:{series_id}")], |r| r.get::<_, bool>(0),
    ).optional()?.unwrap_or(false))
}

pub fn search_group(filters: Filters) -> Result<Vec<Channel>> {
    let sql = get_conn()?;
    let offset = page_offset(filters.page);
    let query = filters.query.clone().unwrap_or("".to_string());
    let media_types = filters.media_types.clone().unwrap_or_default();
    let keywords: Vec<String> = match filters.use_keywords {
        true => query
            .split(" ")
            .map(|f| format!("%{f}%").to_string())
            .collect(),
        false => vec![format!("%{query}%")],
    };
    let mut params: Vec<&dyn rusqlite::ToSql> = Vec::with_capacity(2 + filters.source_ids.len());
    let mut sql_query = format!(
        r#"
        SELECT *
        FROM groups
        WHERE ({})
        AND source_id in ({})
        AND (media_type IS NULL OR media_type in ({}))
    "#,
        get_keywords_sql(keywords.len()),
        generate_placeholders(filters.source_ids.len()),
        generate_placeholders(media_types.len())
    );
    sql_query += &visibility(&filters, true);
    sql_query += " AND EXISTS (SELECT 1 FROM sources s WHERE s.id=groups.source_id AND s.enabled=1 AND CASE groups.media_type WHEN 0 THEN s.import_live WHEN 1 THEN s.import_movies WHEN 2 THEN s.import_series ELSE (s.import_live OR s.import_movies OR s.import_series) END=1)";
    if filters.favorite_groups {
        sql_query += "\nAND favorite > 0";
    }
    // Favourite categories first, then the chosen order.
    sql_query += match filters.sort {
        sort_type::ALPHABETICAL_ASC => "\nORDER BY favorite = 0, name ASC",
        sort_type::ALPHABETICAL_DESC => "\nORDER BY favorite = 0, name DESC",
        _ => "\nORDER BY favorite = 0, favorite, id",
    };
    sql_query += "\nLIMIT ?, ?";
    params.extend(to_to_sql(&keywords));
    params.extend(to_to_sql(&filters.source_ids));
    params.extend(to_to_sql(&media_types));
    params.push(&offset);
    params.push(&PAGE_SIZE);
    let channels: Vec<Channel> = sql
        .prepare_cached(&sql_query)?
        .query_map(params_from_iter(params), row_to_group)?
        .filter_map(Result::ok)
        .collect();
    Ok(channels)
}

fn row_to_group(row: &Row) -> std::result::Result<Channel, rusqlite::Error> {
    let channel = Channel {
        id: row.get("id")?,
        name: row.get("name")?,
        group: None,
        image: row.get("image")?,
        media_type: media_type::GROUP,
        url: None,
        series_id: None,
        group_id: None,
        hidden: row.get("hidden")?,
        archive_days: None,
        epg_id: None,
        favorite: row.get("favorite")?,
        source_id: row.get("source_id")?,
        stream_id: None,
        tv_archive: None,
        season_id: None,
        episode_num: None,
        quality: 0,
        alt_key: None,
    };
    Ok(channel)
}

pub(crate) fn row_to_channel(row: &Row) -> std::result::Result<Channel, rusqlite::Error> {
    let channel = Channel {
        id: row.get("id")?,
        name: row.get("name")?,
        group_id: row.get("group_id")?,
        image: row.get("image")?,
        media_type: row.get("media_type")?,
        source_id: row.get("source_id")?,
        url: row.get("url")?,
        hidden: row.get("hidden")?,
        archive_days: row.get("archive_days")?,
        epg_id: row.get("epg_id")?,
        favorite: row.get("favorite")?,
        episode_num: row.get("episode_num")?,
        series_id: row.get("series_id")?,
        group: None,
        stream_id: row.get("stream_id")?,
        tv_archive: row.get("tv_archive")?,
        season_id: row.get("season_id")?,
        quality: row.get("quality")?,
        alt_key: row.get("alt_key")?,
    };
    Ok(channel)
}

pub fn delete_source(id: i64) -> Result<()> {
    do_tx(|tx| {
        for table in ["channel_http_headers", "movie_positions"] {
            tx.execute(&format!("DELETE FROM {table} WHERE channel_id IN (SELECT id FROM channels WHERE source_id = ?)"), [id])?;
        }
        for table in [
            "channels",
            "groups",
            "seasons",
            "source_categories",
            "alt_overrides",
        ] {
            tx.execute(&format!("DELETE FROM {table} WHERE source_id = ?"), [id])?;
        }
        if tx.execute("DELETE FROM sources WHERE id = ?", [id])? != 1 {
            return Err(anyhow!("No sources were deleted"));
        }
        Ok(())
    })
}

pub fn source_name_exists(name: &str) -> Result<bool> {
    let sql = get_conn()?;
    Ok(sql
        .query_row(
            r#"
    SELECT 1
    FROM sources
    WHERE name = ?1
    "#,
            [name],
            |row| row.get::<_, u8>(0),
        )
        .optional()?
        .is_some())
}

pub fn favorite_group(group_id: i64, favorite: bool) -> Result<()> {
    set_favorite("groups", group_id, favorite)
}

pub fn favorite_channel(channel_id: i64, favorite: bool) -> Result<()> {
    set_favorite("channels", channel_id, favorite)
}

/// A new favorite goes last; starring an existing one keeps its place.
fn set_favorite(table: &str, id: i64, favorite: bool) -> Result<()> {
    get_conn()?.execute(
        &format!(
            "UPDATE {table} SET favorite = CASE WHEN NOT ?1 THEN 0 WHEN favorite > 0 THEN favorite
            ELSE (SELECT COALESCE(MAX(favorite), 0) + 1 FROM {table}) END WHERE id = ?2"
        ),
        params![favorite, id],
    )?;
    Ok(())
}

/// Swaps two favorites' places. Renumbers all favorites 1..n in their shown
/// order first, so favorites saved before ordering existed (all 1) keep it.
pub fn swap_favorites(id: i64, other: i64, group: bool) -> Result<()> {
    let (table, order) = match group {
        true => ("groups", "favorite, id"),
        false => ("channels", "favorite, position, id"),
    };
    do_tx(|tx| {
        let mut ids: Vec<i64> = tx
            .prepare(&format!(
                "SELECT id FROM {table} WHERE favorite > 0 ORDER BY {order}"
            ))?
            .query_map([], |r| r.get(0))?
            .collect::<std::result::Result<_, _>>()?;
        let find = |x| ids.iter().position(|&y| y == x).context("not a favorite");
        let (a, b) = (find(id)?, find(other)?);
        ids.swap(a, b);
        let mut set = tx.prepare(&format!(
            "UPDATE {table} SET favorite = ?1 WHERE id = ?2 AND favorite != ?1"
        ))?;
        for (rank, id) in ids.iter().enumerate() {
            set.execute(params![rank as i64 + 1, id])?;
        }
        Ok(())
    })
}

pub fn get_sources() -> Result<Vec<Source>> {
    let sql = get_conn()?;
    let sources: Vec<Source> = sql
        .prepare("SELECT * FROM sources")?
        .query_map([], row_to_source)?
        .filter_map(Result::ok)
        .collect();
    Ok(sources)
}

pub fn get_enabled_sources_minimal() -> Result<Vec<i64>> {
    let sql = get_conn()?;
    Ok(sql
        .prepare("SELECT id FROM sources where enabled = 1")?
        .query_map([], |row| row.get(0))?
        .filter_map(Result::ok)
        .collect())
}

fn row_to_source(row: &Row) -> std::result::Result<Source, rusqlite::Error> {
    Ok(Source {
        id: row.get("id")?,
        name: row.get("name")?,
        username: row.get("username")?,
        password: row.get("password")?,
        url: row.get("url")?,
        source_type: row.get("source_type")?,
        url_origin: None,
        epg_url: row.get("epg_url")?,
        enabled: row.get("enabled")?,
        user_agent: row.get("user_agent")?,
        stream_user_agent: row.get("stream_user_agent")?,
        last_updated: row.get("last_updated")?,
        import_live: row.get("import_live")?,
        import_movies: row.get("import_movies")?,
        import_series: row.get("import_series")?,
        last_refresh_stats: row
            .get::<_, Option<Vec<u8>>>("last_refresh_stats")?
            .and_then(|b| prost::Message::decode(b.as_slice()).ok()),
    })
}

pub fn get_source_from_id(source_id: i64) -> Result<Source> {
    let sql = get_conn()?;
    Ok(sql.query_row(
        r#"
    SELECT * FROM sources where id = ?"#,
        [source_id],
        row_to_source,
    )?)
}

pub fn set_source_enabled(value: bool, source_id: i64) -> Result<()> {
    let sql = get_conn()?;
    sql.execute(
        r#"
        UPDATE sources
        SET enabled = ?
        WHERE id = ?
    "#,
        params![value, source_id],
    )?;
    Ok(())
}

pub fn do_tx<F, T>(f: F) -> Result<T>
where
    F: FnOnce(&Transaction) -> Result<T>,
{
    let mut sql = get_conn()?;
    let tx = sql.transaction()?;
    let result = f(&tx)?;
    tx.commit()?;
    Ok(result)
}

pub fn update_source(source: Source) -> Result<()> {
    let sql = get_conn()?;
    sql.execute(
        r#"
        UPDATE sources
        SET username = ?, password = ?, url = ?, user_agent = ?, stream_user_agent = ?,
            import_live = ?, import_movies = ?, import_series = ?, epg_url = ?
        WHERE id = ?"#,
        params![
            source.username,
            source.password,
            source.url,
            source.user_agent,
            source.stream_user_agent,
            source.import_live,
            source.import_movies,
            source.import_series,
            source.epg_url,
            source.id
        ],
    )?;
    Ok(())
}

pub fn add_last_watched(id: i64) -> Result<()> {
    let sql = get_conn()?;
    sql.execute(
        r#"
          UPDATE channels
          SET last_watched = strftime('%s', 'now')
          WHERE id = ?
        "#,
        params![id],
    )?;
    sql.execute(
        r#"
		  UPDATE channels
          SET last_watched = NULL
          WHERE last_watched IS NOT NULL
		  AND id NOT IN (
				SELECT id
				FROM channels
				WHERE last_watched IS NOT NULL
				ORDER BY last_watched DESC
				LIMIT 36
		  )
        "#,
        params![],
    )?;
    Ok(())
}

/// Removes one channel from History.
pub fn remove_last_watched(id: i64) -> Result<()> {
    let sql = get_conn()?;
    sql.execute(
        "UPDATE channels SET last_watched = NULL WHERE id = ?",
        params![id],
    )?;
    Ok(())
}

pub fn clear_history() -> Result<()> {
    let sql = get_conn()?;
    sql.execute(
        r#"
          UPDATE channels
          SET last_watched = NULL
          WHERE last_watched IS NOT NULL
        "#,
        params![],
    )?;
    Ok(())
}

pub fn update_source_last_updated(source_id: i64) -> Result<()> {
    let sql = get_conn()?;
    sql.execute(
        "UPDATE sources SET last_updated = ? WHERE id = ?",
        params![chrono::Utc::now().timestamp(), source_id],
    )?;
    Ok(())
}

pub fn set_movie_position(channel_id: i64, movie_position: i64) -> Result<()> {
    let sql = get_conn()?;
    sql.execute(
        r#"
        INSERT INTO movie_positions (channel_id, position)
        VALUES (?, ?)
        ON CONFLICT(channel_id) DO UPDATE SET position = excluded.position
        "#,
        params![channel_id, movie_position],
    )?;
    Ok(())
}

pub fn get_movie_position(channel_id: i64) -> Result<Option<i64>> {
    let sql = get_conn()?;
    let position: Option<i64> = sql
        .query_row(
            r#"
        SELECT position
        FROM movie_positions
        WHERE channel_id = ?
        LIMIT 1
    "#,
            params!(channel_id),
            |row| row.get(0),
        )
        .optional()?;
    Ok(position)
}

pub fn get_whats_new() -> Result<Option<String>> {
    let sql = get_conn()?;
    let version: Option<String> = sql
        .query_row(
            r#"
        SELECT value 
        FROM settings
        WHERE key = ?
        LIMIT 1
    "#,
            params![LAST_SEEN_VERSION_KEY],
            |row| row.get(0),
        )
        .optional()?;
    Ok(version)
}

pub fn has_sources() -> Result<bool> {
    let sql = get_conn()?;
    Ok(sql
        .query_row("SELECT 1 FROM sources LIMIT 1", [], |row| {
            row.get::<_, u8>(0)
        })
        .optional()?
        .is_some())
}

pub fn set_refresh_stats(stats: &crate::generated_proto::RefreshStats) -> Result<()> {
    let sql = get_conn()?;
    sql.execute(
        "UPDATE sources SET last_refresh_stats = ? WHERE id = ?",
        params![prost::Message::encode_to_vec(stats), stats.source_id],
    )?;
    Ok(())
}

fn category_mode_column(media_type: u8) -> Result<&'static str> {
    match media_type {
        media_type::LIVESTREAM => Ok("category_mode_live"),
        media_type::MOVIE => Ok("category_mode_movies"),
        media_type::SERIE => Ok("category_mode_series"),
        _ => Err(anyhow!("invalid media type for categories")),
    }
}

pub fn get_source_categories(source_id: i64) -> Result<crate::generated_proto::CategoryList> {
    let sql = get_conn()?;
    let (live_mode, movies_mode, series_mode) = sql.query_row(
        "SELECT category_mode_live, category_mode_movies, category_mode_series FROM sources WHERE id = ?",
        params![source_id],
        |r| Ok((r.get::<_, i32>(0)?, r.get::<_, i32>(1)?, r.get::<_, i32>(2)?)),
    )?;
    let categories = sql
        .prepare(
            "SELECT id, media_type, name, listed, stream_count FROM source_categories WHERE source_id = ? ORDER BY media_type, name",
        )?
        .query_map(params![source_id], |r| {
            Ok(crate::generated_proto::Category {
                id: r.get(0)?,
                media_type: r.get(1)?,
                name: r.get(2)?,
                listed: r.get(3)?,
                stream_count: r.get(4)?,
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;
    Ok(crate::generated_proto::CategoryList {
        categories,
        live_mode,
        movies_mode,
        series_mode,
    })
}

/// Replaces the list and mode of one media type. Names not yet known are
/// stored too, so a list can be prepared before the first import (after
/// `save_source`).
pub fn set_source_categories(msg: crate::generated_proto::SetCategories) -> Result<()> {
    let media_type = msg.media_type as u8;
    let column = category_mode_column(media_type)?;
    do_tx(|tx| {
        tx.execute(
            &format!("UPDATE sources SET {column} = ? WHERE id = ?"),
            params![msg.mode, msg.source_id],
        )?;
        tx.execute(
            "UPDATE source_categories SET listed = 0 WHERE source_id = ? AND media_type = ?",
            params![msg.source_id, media_type],
        )?;
        let mut stmt = tx.prepare_cached(
            r#"
            INSERT INTO source_categories (source_id, media_type, name, listed)
            VALUES (?, ?, ?, 1)
            ON CONFLICT (source_id, media_type, name) DO UPDATE SET listed = 1
            "#,
        )?;
        for name in &msg.listed {
            stmt.execute(params![msg.source_id, media_type, name.trim()])?;
        }
        Ok(())
    })
}

/// Tests: one migrated database (and temp dir) per test process.
#[cfg(test)]
static TEST_LOCK: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());
#[cfg(test)]
pub fn test_lock() -> tokio::sync::MutexGuard<'static, ()> {
    TEST_LOCK.blocking_lock()
}
#[cfg(test)]
pub async fn test_lock_async() -> tokio::sync::MutexGuard<'static, ()> {
    TEST_LOCK.lock().await
}

#[cfg(test)]
pub fn test_db() {
    static INIT: std::sync::Once = std::sync::Once::new();
    INIT.call_once(|| {
        let dir = std::env::temp_dir().join(format!("brentv-test-{}", std::process::id()));
        let _ = DB_PATH_OVERRIDE.set(dir.to_string_lossy().into_owned());
        let _ = crate::utils::TEMP_PATH.set(dir.to_string_lossy().into_owned());
        apply_migrations().unwrap();
    });
}

/// A source's category rules, loaded once per refresh for per-stream checks.
pub struct CategoryRules {
    include: [bool; 3],
    listed: [std::collections::HashSet<String>; 3],
}

impl CategoryRules {
    pub fn load(source_id: i64) -> Result<Self> {
        let list = get_source_categories(source_id)?;
        let mut listed: [std::collections::HashSet<String>; 3] = Default::default();
        for c in list.categories {
            if c.listed && c.media_type < 3 {
                listed[c.media_type as usize].insert(c.name);
            }
        }
        let include = [list.live_mode, list.movies_mode, list.series_mode].map(|m| m == 1);
        Ok(Self { include, listed })
    }

    /// Whether a stream of media type `mt` in category `name` is imported:
    /// include mode takes listed names only, exclude mode skips them.
    pub fn allows(&self, mt: u8, name: Option<&str>) -> bool {
        let listed = name.is_some_and(|n| self.listed[mt as usize].contains(n));
        listed == self.include[mt as usize]
    }
}

pub fn sync_categories(
    tx: &Transaction,
    source: i64,
    mt: u8,
    categories: &[(String, Option<String>, Option<u32>)],
) -> Result<()> {
    tx.execute("UPDATE source_categories SET ext_id = NULL, stream_count = NULL WHERE source_id = ? AND media_type = ?", params![source, mt])?;
    tx.execute_batch("CREATE TEMP TABLE IF NOT EXISTS seen_categories(name TEXT PRIMARY KEY); DELETE FROM seen_categories;")?;
    let mut upsert = tx.prepare_cached("INSERT INTO source_categories(source_id, media_type, name, ext_id, stream_count) VALUES (?, ?, ?, ?, ?) ON CONFLICT(source_id, media_type, name) DO UPDATE SET ext_id=excluded.ext_id, stream_count=excluded.stream_count")?;
    let mut seen = tx.prepare_cached("INSERT OR IGNORE INTO seen_categories VALUES (?)")?;
    for (name, id, count) in categories {
        upsert.execute(params![source, mt, name, id, count])?;
        seen.execute([name])?;
    }
    tx.execute("DELETE FROM source_categories WHERE source_id=? AND media_type=? AND listed=0 AND name NOT IN (SELECT name FROM seen_categories)", params![source,mt])?;
    Ok(())
}

pub fn begin_refresh(tx: &Transaction) -> Result<()> {
    tx.execute_batch("CREATE TEMP TABLE IF NOT EXISTS refresh_seen(id INTEGER PRIMARY KEY); DELETE FROM refresh_seen;")?;
    Ok(())
}

pub fn upsert_channel(
    tx: &Transaction,
    channel: &Channel,
    key: &str,
    position: usize,
) -> Result<i64> {
    let mut stmt = tx.prepare_cached("INSERT INTO channels(name,group_id,image,url,source_id,media_type,stream_id,tv_archive,favorite,ext_key,position,quality,alt_key,series_id,season_id,episode_num) VALUES (?,?,?,?,?,?,?,?,0,?,?,?,?,?,?,?) ON CONFLICT(source_id,ext_key) WHERE ext_key IS NOT NULL DO UPDATE SET name=excluded.name,group_id=excluded.group_id,image=excluded.image,url=excluded.url,media_type=excluded.media_type,stream_id=excluded.stream_id,tv_archive=excluded.tv_archive,position=excluded.position,quality=excluded.quality,alt_key=excluded.alt_key,series_id=excluded.series_id,season_id=excluded.season_id,episode_num=excluded.episode_num WHERE (channels.name,channels.group_id,channels.image,channels.url,channels.media_type,channels.stream_id,channels.tv_archive,channels.position,channels.quality,channels.alt_key,channels.series_id,channels.season_id,channels.episode_num) IS NOT (excluded.name,excluded.group_id,excluded.image,excluded.url,excluded.media_type,excluded.stream_id,excluded.tv_archive,excluded.position,excluded.quality,excluded.alt_key,excluded.series_id,excluded.season_id,excluded.episode_num) RETURNING id")?;
    let live = channel.media_type == media_type::LIVESTREAM;
    let id = stmt
        .query_row(
            params![
                channel.name,
                channel.group_id,
                channel.image,
                channel.url,
                channel.source_id,
                channel.media_type,
                channel.stream_id,
                channel.tv_archive,
                key,
                position as i64,
                if live {
                    crate::alt::quality(&channel.name)
                } else {
                    0
                },
                if live {
                    crate::alt::alt_key(&channel.name)
                } else {
                    None
                },
                channel.series_id,
                channel.season_id,
                channel.episode_num,
            ],
            |r| r.get::<_, i64>(0),
        )
        .optional()?;
    // A no-op conflict returns no row; retain the existing identity without
    // rewriting every secondary index on an unchanged catalogue refresh.
    let id = match id {
        Some(id) => id,
        None => tx
            .prepare_cached("SELECT id FROM channels WHERE source_id=? AND ext_key=?")?
            .query_row(params![channel.source_id, key], |r| r.get(0))?,
    };
    tx.prepare_cached("UPDATE channels SET archive_days=?, epg_id=? WHERE id=? AND (archive_days,epg_id) IS NOT (?,?)")?
        .execute(params![channel.archive_days,channel.epg_id,id,channel.archive_days,channel.epg_id])?;
    tx.prepare_cached("INSERT OR IGNORE INTO refresh_seen VALUES (?)")?
        .execute([id])?;
    Ok(id)
}

pub fn has_media_rows(tx: &Transaction, source: i64, mt: u8) -> Result<bool> {
    Ok(tx.query_row("SELECT EXISTS(SELECT 1 FROM channels WHERE source_id=? AND media_type=? AND series_id IS NULL)", params![source, mt], |r| r.get(0))?)
}

pub fn finish_type(tx: &Transaction, source: i64, mt: u8) -> Result<()> {
    // Only unadopted upstream duplicates use name matching, once.
    let legacy: bool = tx.query_row(
        "SELECT EXISTS(SELECT 1 FROM channels WHERE source_id=? AND media_type=? AND ext_key IS NULL AND series_id IS NULL)",
        params![source, mt],
        |row| row.get(0),
    )?;
    if legacy {
        tx.execute("UPDATE channels AS c SET favorite=MAX(favorite, COALESCE((SELECT MAX(favorite) FROM channels d WHERE d.source_id=c.source_id AND d.media_type=c.media_type AND d.name=c.name AND d.ext_key IS NULL AND d.series_id IS NULL),0)), last_watched=(SELECT MAX(v) FROM (SELECT c.last_watched AS v UNION ALL SELECT last_watched FROM channels d WHERE d.source_id=c.source_id AND d.media_type=c.media_type AND d.name=c.name AND d.ext_key IS NULL AND d.series_id IS NULL)) WHERE c.source_id=? AND c.media_type=? AND c.id IN (SELECT id FROM refresh_seen) AND EXISTS (SELECT 1 FROM channels d WHERE d.source_id=c.source_id AND d.media_type=c.media_type AND d.name=c.name AND d.ext_key IS NULL AND d.series_id IS NULL)", params![source,mt])?;
        tx.execute("INSERT OR IGNORE INTO movie_positions(channel_id,position) SELECT c.id, MAX(p.position) FROM channels c JOIN channels d ON d.source_id=c.source_id AND d.media_type=c.media_type AND d.name=c.name JOIN movie_positions p ON p.channel_id=d.id WHERE c.source_id=? AND c.media_type=? AND c.id IN (SELECT id FROM refresh_seen) AND d.ext_key IS NULL AND d.series_id IS NULL GROUP BY c.id", params![source,mt])?;
    }
    tx.execute("DELETE FROM channels WHERE source_id=? AND media_type=? AND series_id IS NULL AND id NOT IN (SELECT id FROM refresh_seen)", params![source,mt])?;
    if mt == media_type::SERIE {
        // Keep cached episodes and their saved state until this series is
        // opened again; metadata is then refreshed lazily by provider identity.
        tx.execute("UPDATE channels SET episodes_loaded=0 WHERE source_id=? AND media_type=2 AND series_id IS NULL", [source])?;
        tx.execute("DELETE FROM channels AS e WHERE source_id=? AND series_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM channels s WHERE s.source_id=e.source_id AND s.media_type=2 AND s.ext_key='2:'||e.series_id)", [source])?;
        tx.execute("DELETE FROM seasons AS e WHERE source_id=? AND NOT EXISTS (SELECT 1 FROM channels s WHERE s.source_id=e.source_id AND s.media_type=2 AND s.ext_key='2:'||e.series_id)", [source])?;
    }
    Ok(())
}

pub fn finish_refresh(tx: &Transaction, source: i64) -> Result<()> {
    // Favourite categories stay even while empty, so the star survives a
    // provider briefly dropping them.
    tx.execute("DELETE FROM groups WHERE source_id=? AND favorite=0 AND hidden=0 AND NOT EXISTS (SELECT 1 FROM channels WHERE group_id=groups.id)", [source])?;
    for table in ["movie_positions", "channel_http_headers"] {
        tx.execute(&format!("DELETE FROM {table} WHERE NOT EXISTS (SELECT 1 FROM channels WHERE id={table}.channel_id)"), [])?;
    }
    tx.execute_batch("ANALYZE channels; ANALYZE groups;")?;
    crate::alt::apply_overrides(tx, source)
}

pub fn failed_stats(
    source: &Source,
    error: &anyhow::Error,
) -> crate::generated_proto::RefreshStats {
    let secrets: Vec<&str> = [&source.username, &source.password]
        .into_iter()
        .filter_map(|s| s.as_deref())
        .collect();
    let error = crate::redact::error(error, &secrets);
    crate::generated_proto::RefreshStats {
        source_id: source.id.unwrap_or_default(),
        error: Some(error.clone()),
        types: (0..3)
            .map(|mt| crate::generated_proto::MediaTypeStats {
                media_type: mt as u32,
                enabled: source.imports(mt),
                failed: source.imports(mt),
                error: source.imports(mt).then(|| error.clone()),
                ..Default::default()
            })
            .collect(),
        ..Default::default()
    }
}

#[cfg(test)]
#[path = "../tests/refresh/mod.rs"]
mod refresh_tests;

fn visibility(filters: &Filters, group: bool) -> String {
    let hidden = if group {
        "hidden=1"
    } else {
        "(hidden=1 OR EXISTS (SELECT 1 FROM groups g WHERE g.id=channels.group_id AND g.hidden=1) OR EXISTS (SELECT 1 FROM channels parent WHERE parent.source_id=channels.source_id AND parent.ext_key='2:'||channels.series_id AND (parent.hidden=1 OR EXISTS (SELECT 1 FROM groups g WHERE g.id=parent.group_id AND g.hidden=1))))"
    };
    if filters.hidden_only {
        format!(" AND {hidden}")
    } else if filters.include_hidden {
        String::new()
    } else {
        format!(" AND NOT ({hidden})")
    }
}
pub fn set_hidden(id: i64, hidden: bool, group: bool) -> Result<()> {
    get_conn()?.execute(
        if group {
            "UPDATE groups SET hidden=? WHERE id=?"
        } else {
            "UPDATE channels SET hidden=? WHERE id=?"
        },
        params![hidden, id],
    )?;
    Ok(())
}
pub fn restore_all_hidden() -> Result<()> {
    do_tx(|tx| {
        tx.execute("UPDATE channels SET hidden=0 WHERE hidden=1", [])?;
        tx.execute("UPDATE groups SET hidden=0 WHERE hidden=1", [])?;
        Ok(())
    })
}
