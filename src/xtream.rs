use crate::generated_proto::{CategoryList, RefreshStats};
use crate::media_type;
use crate::sql;
use crate::sql::insert_season;
use crate::types::Channel;
use crate::types::Season;
use crate::types::Source;
use crate::utils::get_user_agent_from_source;
use anyhow::anyhow;
use anyhow::{Context, Result};
use futures::{StreamExt, TryStreamExt, stream};
use reqwest::Client;
use reqwest::Url;
use rusqlite::{Connection, OptionalExtension, Transaction, params};
use serde::Deserialize;
use serde::Serialize;
use std::collections::HashMap;
use std::sync::LazyLock;
use std::time::Duration;

const GET_LIVE_STREAMS: &str = "get_live_streams";
const GET_VODS: &str = "get_vod_streams";
const GET_SERIES: &str = "get_series";
const GET_SERIES_INFO: &str = "get_series_info";
const GET_SERIES_CATEGORIES: &str = "get_series_categories";
const GET_LIVE_STREAM_CATEGORIES: &str = "get_live_categories";
const GET_VOD_CATEGORIES: &str = "get_vod_categories";
const LIVE_STREAM_EXTENSION: &str = "ts";
const NO_SEASON_NUMBER: i64 = -9999;
// Reuse HTTP connections across requests and bound stalled provider refreshes.
static CLIENT: LazyLock<Client> = LazyLock::new(|| {
    Client::builder()
        .connect_timeout(Duration::from_secs(10))
        .read_timeout(Duration::from_secs(30))
        .build()
        .expect("HTTP client")
});

#[derive(Serialize, Deserialize, Clone, Debug)]
struct XtreamStream {
    #[serde(default)]
    stream_id: serde_json::Value,
    name: Option<String>,
    #[serde(default)]
    category_id: serde_json::Value,
    stream_icon: Option<String>,
    #[serde(default)]
    series_id: serde_json::Value,
    cover: Option<String>,
    container_extension: Option<String>,
    #[serde(default)]
    tv_archive: serde_json::Value,
    #[serde(default)]
    tv_archive_duration: serde_json::Value,
}
#[derive(Serialize, Deserialize, Clone, Debug)]
struct XtreamSeries {
    seasons: Vec<XtreamSeason>,
    episodes: HashMap<String, Vec<XtreamEpisode>>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct XtreamSeason {
    #[serde(default)]
    season_number: serde_json::Value,
    #[serde(default)]
    overview: Option<String>,
    #[serde(default)]
    cover: Option<String>,
    #[serde(default)]
    cover_tmdb: Option<String>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct XtreamEpisode {
    #[serde(default)]
    id: serde_json::Value,
    #[serde(default)]
    title: serde_json::Value,
    #[serde(default)]
    container_extension: serde_json::Value,
    #[serde(default)]
    episode_num: serde_json::Value,
    #[serde(default)]
    season: serde_json::Value,
    #[serde(default)]
    info: serde_json::Value,
}
#[derive(Serialize, Deserialize, Clone, Debug)]
struct XtreamEpisodeInfo {
    movie_image: Option<String>,
}
#[derive(Serialize, Deserialize, Clone, Debug)]
struct XtreamCategory {
    #[serde(default)]
    category_id: serde_json::Value,
    category_name: String,
}

fn build_xtream_url(source: &mut Source) -> Result<Url> {
    let mut url = Url::parse(source.url.as_ref().context("Missing URL")?)?;
    source.url_origin = Some(url.origin().ascii_serialization());
    url.query_pairs_mut()
        .append_pair(
            "username",
            source.username.as_ref().context("Missing username")?,
        )
        .append_pair(
            "password",
            source.password.as_ref().context("Missing password")?,
        );
    Ok(url)
}

pub async fn get_xtream(mut source: Source, _wipe: bool) -> Result<RefreshStats> {
    source.id = Some(sql::do_tx(|tx| {
        sql::create_or_find_source_by_name(tx, &source)
    })?);
    let url = match build_xtream_url(&mut source) {
        Ok(url) => url,
        Err(e) => return Ok(sql::failed_stats(&source, &e)),
    };
    let user_agent = get_user_agent_from_source(&source)?;
    let source_id = source.id.context("no source id")?;
    let rules = sql::CategoryRules::load(source_id)?;
    // Fetch one large media list at a time to bound JSON buffer peaks;
    // disabled types issue no requests. Category requests remain bounded.
    let mut results = Vec::with_capacity(3);
    for mt in 0..3 {
        results.push(if source.imports(mt) {
            Some(fetch_type(url.clone(), &user_agent, mt, &rules).await)
        } else {
            None
        });
    }
    let mut stats = RefreshStats {
        source_id,
        ..Default::default()
    };
    let secrets: Vec<&str> = [&source.username, &source.password]
        .into_iter()
        .filter_map(|s| s.as_deref())
        .collect();
    let mut conn = sql::get_conn()?;
    let tx = conn.transaction()?;
    sql::begin_refresh(&tx)?;
    for (mt, result) in results.into_iter().enumerate() {
        let mt = mt as u8;
        let mut count = crate::generated_proto::MediaTypeStats {
            media_type: mt as u32,
            enabled: source.imports(mt),
            ..Default::default()
        };
        match result {
            None => {
                sql::finish_type(&tx, source_id, mt)?;
            }
            Some(Err(e)) => {
                count.failed = true;
                count.error = Some(crate::redact::error(&e, &secrets));
            }
            Some(Ok((cats, streams))) => {
                count.categories = cats.len() as u32;
                count.categories_excluded = cats
                    .iter()
                    .filter(|c| !rules.allows(mt, Some(c.category_name.trim())))
                    .count() as u32;
                let names: HashMap<String, String> = cats
                    .iter()
                    .filter_map(|c| {
                        get_serde_json_string(&c.category_id)
                            .map(|id| (id, c.category_name.trim().to_string()))
                    })
                    .collect();
                let mut category_counts: HashMap<String, u32> = HashMap::new();
                let stream_count = streams.len();
                let mut channels = Vec::with_capacity(stream_count);
                let mut seen = std::collections::HashSet::new();
                for (position, stream) in streams.into_iter().enumerate() {
                    let id = match mt {
                        media_type::SERIE => get_serde_json_string(&stream.series_id),
                        _ => get_serde_json_string(&stream.stream_id),
                    };
                    let Some(key) = id.map(|id| format!("{mt}:{id}")) else {
                        count.failed = true;
                        count.error = Some("Provider stream is missing its identity".into());
                        break;
                    };
                    if !seen.insert(key.clone()) {
                        continue;
                    }
                    count.fetched += 1;
                    let category = get_serde_json_string(&stream.category_id)
                        .and_then(|id| names.get(&id).cloned());
                    if let Some(name) = &category {
                        *category_counts.entry(name.clone()).or_default() += 1;
                    }
                    if !rules.allows(mt, category.as_deref()) {
                        count.excluded += 1;
                        continue;
                    }
                    match convert_xtream_live_to_channel(stream, &source, mt, category) {
                        Ok(channel) => channels.push((channel, key, position)),
                        Err(e) => {
                            count.failed = true;
                            count.error = Some(crate::redact::error(&e, &secrets));
                            break;
                        }
                    }
                }
                let intentionally_empty = !cats.is_empty()
                    && cats
                        .iter()
                        .all(|c| !rules.allows(mt, Some(c.category_name.trim())));
                if stream_count == 0
                    && !intentionally_empty
                    && sql::has_media_rows(&tx, source_id, mt)?
                {
                    count.failed = true;
                    count.error = Some("Provider returned an empty list".into());
                }
                if count.failed || (stream_count > 0 && channels.is_empty() && count.excluded == 0)
                {
                    count.failed = true;
                    if count.error.is_none() {
                        count.error = Some("Provider returned no valid stream entries".into());
                    }
                } else {
                    let categories = cats
                        .into_iter()
                        .map(|c| {
                            let name = c.category_name.trim().to_string();
                            let count = rules
                                .allows(mt, Some(&name))
                                .then(|| category_counts.get(&name).copied().unwrap_or(0));
                            (name, get_serde_json_string(&c.category_id), count)
                        })
                        .collect::<Vec<_>>();
                    sql::sync_categories(&tx, source_id, mt, &categories)?;
                    let mut groups = HashMap::new();
                    for (mut channel, key, position) in channels {
                        sql::set_channel_group_id(&mut groups, &mut channel, &tx, &source_id)?;
                        sql::upsert_channel(&tx, &channel, &key, position)?;
                        count.imported += 1;
                    }
                    sql::finish_type(&tx, source_id, mt)?;
                }
            }
        }
        stats.types.push(count);
    }
    if stats.types.iter().any(|t| t.enabled)
        && stats.types.iter().filter(|t| t.enabled).all(|t| t.failed)
    {
        tx.rollback()?;
        stats.error = Some("All enabled media types failed".into());
    } else {
        sql::finish_refresh(&tx, source_id)?;
        tx.commit()?;
        stats.success = true;
    }
    Ok(stats)
}

fn actions(mt: u8) -> (&'static str, &'static str) {
    match mt {
        0 => (GET_LIVE_STREAM_CATEGORIES, GET_LIVE_STREAMS),
        1 => (GET_VOD_CATEGORIES, GET_VODS),
        _ => (GET_SERIES_CATEGORIES, GET_SERIES),
    }
}

async fn fetch_type(
    url: Url,
    agent: &String,
    mt: u8,
    rules: &sql::CategoryRules,
) -> Result<(Vec<XtreamCategory>, Vec<XtreamStream>)> {
    let (categories_action, streams_action) = actions(mt);
    let cats: Vec<XtreamCategory> =
        get_xtream_http_data(url.clone(), categories_action, agent).await?;
    let selected: Vec<&XtreamCategory> = cats
        .iter()
        .filter(|c| rules.allows(mt, Some(c.category_name.trim())))
        .collect();
    let streams = if selected.len() <= 20 && selected.len() * 2 < cats.len() {
        let urls: Result<Vec<Url>> = selected
            .iter()
            .map(|c| {
                let mut url = url.clone();
                url.query_pairs_mut().append_pair(
                    "category_id",
                    &get_serde_json_string(&c.category_id).context("missing category id")?,
                );
                Ok(url)
            })
            .collect();
        stream::iter(urls?.into_iter().map(|url| async move {
            get_xtream_http_data::<Vec<XtreamStream>>(url, streams_action, agent).await
        }))
        .buffered(4)
        .try_collect::<Vec<_>>()
        .await?
        .into_iter()
        .flatten()
        .collect()
    } else {
        get_xtream_http_data(url, streams_action, agent).await?
    };
    Ok((cats, streams))
}

/// Categories only: this never requests stream lists.
pub async fn fetch_categories(source_id: i64) -> Result<CategoryList> {
    let mut source = sql::get_source_from_id(source_id)?;
    if source.source_type != crate::source_type::XTREAM {
        return sql::get_source_categories(source_id);
    }
    let result: Result<()> = async {
        let url = build_xtream_url(&mut source)?;
        let agent = get_user_agent_from_source(&source)?;
        let mut fetched = Vec::new();
        for mt in 0..3 {
            if source.imports(mt) {
                let cats: Vec<XtreamCategory> =
                    get_xtream_http_data(url.clone(), actions(mt).0, &agent).await?;
                fetched.push((mt, cats));
            }
        }
        sql::do_tx(|tx| {
            for (mt, cats) in fetched {
                // A category listing has no stream counts. Preserve counts already measured.
                let stored = sql::get_source_categories(source_id)?;
                let cats = cats
                    .into_iter()
                    .map(|c| {
                        let name = c.category_name.trim().to_string();
                        let count = stored
                            .categories
                            .iter()
                            .find(|v| v.media_type == mt as u32 && v.name == name)
                            .and_then(|v| v.stream_count);
                        (name, get_serde_json_string(&c.category_id), count)
                    })
                    .collect::<Vec<_>>();
                sql::sync_categories(tx, source_id, mt, &cats)?;
            }
            Ok(())
        })
    }
    .await;
    result.map_err(|e| {
        anyhow!(crate::redact::error(
            &e,
            &[
                source.username.as_deref().unwrap_or(""),
                source.password.as_deref().unwrap_or("")
            ]
        ))
    })?;
    sql::get_source_categories(source_id)
}

async fn get_xtream_http_data<T>(mut url: Url, action: &str, user_agent: &String) -> Result<T>
where
    T: serde::de::DeserializeOwned,
{
    url.query_pairs_mut().append_pair("action", action);
    // without_url: the request URL carries the credentials.
    let mut response = CLIENT
        .get(url)
        .header(reqwest::header::USER_AGENT, user_agent)
        .send()
        .await
        .and_then(|r| r.error_for_status())
        .map_err(|e| e.without_url())?;
    let mut body = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(|e| e.without_url())? {
        anyhow::ensure!(
            body.len() + chunk.len() <= crate::utils::MAX_CATALOG_BYTES,
            "Provider response is too large"
        );
        body.extend_from_slice(&chunk);
    }
    Ok(serde_json::from_slice(&body)?)
}

fn convert_xtream_live_to_channel(
    stream: XtreamStream,
    source: &Source,
    stream_type: u8,
    category_name: Option<String>,
) -> Result<Channel> {
    let stream_id = get_serde_json_i64(&stream.stream_id);
    Ok(Channel {
        id: None,
        group: category_name.map(|x| x.trim().to_string()),
        image: stream
            .stream_icon
            .or(stream.cover)
            .map(|x| x.trim().to_string()),
        media_type: stream_type,
        name: stream
            .name
            .filter(|n| !n.trim().is_empty())
            .context("No name")?
            .trim()
            .to_string(),
        source_id: source.id,
        url: if stream_type == media_type::SERIE {
            get_serde_json_string(&stream.series_id)
        } else {
            Some(get_url(
                stream_id.context("missing stream id")?.to_string(),
                source,
                stream_type,
                stream.container_extension,
            )?)
        },
        stream_id,
        hidden: false,
        archive_days: if get_serde_json_i64(&stream.tv_archive) == Some(1) {
            get_serde_json_i64(&stream.tv_archive_duration)
                .and_then(|n| u32::try_from(n).ok())
                .filter(|n| *n > 0)
        } else {
            None
        },
        epg_id: None,
        favorite: false,
        group_id: None,
        series_id: None,
        tv_archive: get_serde_json_i64(&stream.tv_archive).map(|x| x == 1),
        season_id: None,
        episode_num: None,
        quality: 0,
        alt_key: None,
    })
}

fn get_url(
    stream_id: String,
    source: &Source,
    stream_type: u8,
    extension: Option<String>,
) -> Result<String> {
    Ok(format!(
        "{}/{}/{}/{}/{}.{}",
        source
            .url_origin
            .as_deref()
            .ok_or_else(|| anyhow::anyhow!("missing url_origin"))?,
        get_media_type_string(stream_type)?,
        source
            .username
            .as_deref()
            .ok_or_else(|| anyhow::anyhow!("missing username"))?,
        source
            .password
            .as_deref()
            .ok_or_else(|| anyhow::anyhow!("missing password"))?,
        stream_id,
        extension.unwrap_or_else(|| LIVE_STREAM_EXTENSION.to_string())
    ))
}

fn get_media_type_string(stream_type: u8) -> Result<String> {
    match stream_type {
        media_type::LIVESTREAM => Ok("live".to_string()),
        media_type::MOVIE => Ok("movie".to_string()),
        media_type::SERIE => Ok("series".to_string()),
        _ => Err(anyhow!("Invalid stream_type")),
    }
}

pub async fn get_episodes(
    series_id: i64,
    source_id: i64,
    fallback_image: Option<String>,
) -> Result<()> {
    let mut source = sql::get_source_from_id(source_id)?;
    let (parent, loaded) = {
        let conn = sql::get_conn()?;
        resolve_series(&conn, &source, series_id)?.context("Series is unavailable or disabled")?
    };
    if loaded {
        return Ok(());
    }
    let mut url = build_xtream_url(&mut source)?;
    let user_agent = get_user_agent_from_source(&source)?;
    url.query_pairs_mut()
        .append_pair("series_id", &series_id.to_string());
    let mut series = get_xtream_http_data::<XtreamSeries>(url, GET_SERIES_INFO, &user_agent)
        .await
        .map_err(|_| anyhow!("Series request failed"))?;
    series
        .seasons
        .sort_by_key(|f| get_serde_json_i64(&f.season_number));
    let seasons: HashMap<i64, XtreamSeason> = series
        .seasons
        .iter()
        .filter_map(|x| get_serde_json_i64(&x.season_number).map(|y| (y, x.clone())))
        .collect();
    // Buckets in key order and a stable sort: the first copy of a duplicated
    // identity always wins, whatever the map's iteration order.
    let mut buckets: Vec<_> = series.episodes.into_iter().collect();
    buckets.sort_by_cached_key(|(key, _)| (key.trim().parse::<i64>().ok(), key.clone()));
    let mut listed: Vec<XtreamEpisode> = buckets.into_iter().flat_map(|(_, list)| list).collect();
    listed.sort_by_cached_key(|e| {
        (
            get_serde_json_i64(&e.season),
            get_serde_json_i64(&e.episode_num),
            get_serde_json_string(&e.id),
        )
    });
    // Skip episodes that can't be keyed or played instead of failing the
    // series. A refreshed listing deletes only the episodes the provider no
    // longer lists, so skipped ones keep their cached rows, and an entry with
    // no identity (it could be any cached episode) turns deletion off.
    let mut valid = std::collections::HashSet::new();
    let mut skipped = std::collections::BTreeSet::new();
    let mut prune = true;
    let mut episodes = Vec::new();
    for mut episode in listed {
        let Some(id) = get_serde_json_string(&episode.id)
            .filter(|id| !id.is_empty() && id.bytes().all(|c| c.is_ascii_digit()))
            .and_then(|id| id.parse::<i64>().ok())
            .filter(|id| *id > 0)
        else {
            prune = false;
            continue;
        };
        let extension = get_serde_json_string(&episode.container_extension).unwrap_or_default();
        if extension.is_empty()
            || extension.len() > 10
            || !extension.bytes().all(|c| c.is_ascii_alphanumeric())
        {
            skipped.insert(id);
            continue;
        }
        if valid.insert(id) {
            episode.id = id.into();
            episode.container_extension = extension.into();
            episodes.push(episode);
        }
    }
    // An empty listing must never become destructive cache cleanup.
    if episodes.is_empty() {
        return Err(anyhow!(
            "The provider listed no playable episodes for this series"
        ));
    }
    let kept: Vec<String> = skipped
        .iter()
        .filter(|id| !valid.contains(*id))
        .map(|id| format!("episode:{series_id}:{id}"))
        .collect();
    insert_episodes(
        &source,
        &parent,
        seasons,
        episodes,
        prune.then_some(kept.as_slice()),
        series_id,
        parent.image.clone().or(fallback_image),
    )?;
    Ok(())
}

#[derive(PartialEq)]
struct SeriesParent {
    id: i64,
    name: String,
    url: String,
    image: Option<String>,
}

/// Resolve the saved parent and the exact source inputs used for this request.
/// The same query runs inside the write transaction after the HTTP await.
fn resolve_series(
    conn: &Connection,
    source: &Source,
    series_id: i64,
) -> Result<Option<(SeriesParent, bool)>> {
    Ok(conn.query_row(
        "SELECT c.id,c.name,c.url,c.image,c.episodes_loaded FROM channels c JOIN sources s ON s.id=c.source_id
         WHERE s.id=? AND s.source_type=2 AND s.enabled=1 AND s.import_series=1
         AND s.name=? AND s.url IS ? AND s.username IS ? AND s.password IS ? AND s.user_agent IS ? AND s.last_updated IS ?
         AND c.media_type=2 AND c.series_id IS NULL AND c.ext_key=? AND c.url=? AND c.hidden=0
         AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id=c.group_id AND g.hidden=1)",
        params![source.id, source.name, source.url, source.username, source.password, source.user_agent, source.last_updated, format!("2:{series_id}"), series_id.to_string()],
        |row| Ok((SeriesParent { id: row.get(0)?, name: row.get(1)?, url: row.get(2)?, image: row.get(3)? }, row.get(4)?)),
    ).optional()?)
}

fn insert_episodes(
    source: &Source,
    parent: &SeriesParent,
    seasons: HashMap<i64, XtreamSeason>,
    episodes: Vec<XtreamEpisode>,
    prune: Option<&[String]>,
    series_id: i64,
    default_season_image: Option<String>,
) -> Result<()> {
    let mut seasons_db: HashMap<i64, i64> = HashMap::new();
    sql::do_tx(|tx| {
        let changed = || anyhow!("The source changed while this series loaded. Try again.");
        let (current, loaded) = resolve_series(tx, source, series_id)?.ok_or_else(changed)?;
        if current != *parent {
            return Err(changed());
        }
        if loaded {
            return Ok(());
        }
        sql::begin_refresh(tx)?;
        for episode in episodes {
            insert_episode(
                episode,
                source,
                tx,
                &mut seasons_db,
                &seasons,
                series_id,
                default_season_image.clone(),
            )
            .context("Failed to insert episode")?;
        }
        // `prune` lists the episodes to keep although they were skipped.
        if let Some(kept) = prune {
            for key in kept {
                tx.execute("INSERT OR IGNORE INTO refresh_seen SELECT id FROM channels WHERE source_id=? AND ext_key=?", rusqlite::params![source.id, key])?;
            }
            tx.execute("DELETE FROM channels WHERE source_id=? AND series_id=? AND id NOT IN (SELECT id FROM refresh_seen)", rusqlite::params![source.id, series_id])?;
        }
        tx.execute("DELETE FROM seasons WHERE source_id=? AND series_id=? AND id NOT IN (SELECT season_id FROM channels WHERE source_id=? AND series_id=?)", rusqlite::params![source.id, series_id, source.id, series_id])?;
        tx.execute("UPDATE channels SET episodes_loaded=1 WHERE source_id=? AND media_type=2 AND ext_key=? AND series_id IS NULL", rusqlite::params![source.id, format!("2:{series_id}")])?;
        Ok(())
    })
}

fn insert_episode(
    episode: XtreamEpisode,
    source: &Source,
    tx: &Transaction,
    seasons_db: &mut HashMap<i64, i64>,
    seasons: &HashMap<i64, XtreamSeason>,
    series_id: i64,
    default_season_image: Option<String>,
) -> Result<()> {
    let season_number = get_serde_json_i64(&episode.season).unwrap_or(NO_SEASON_NUMBER);
    let season_id = seasons_db.get(&season_number);
    let season_id: i64 = match season_id {
        Some(s) => *s,
        None => {
            let season = seasons
                .get(&season_number)
                .and_then(|f| {
                    xtream_season_to_season(f.clone(), source.id.unwrap(), series_id)
                        .with_context(|| "Failed to convert XtreamSeason to Season")
                        .inspect_err(|e| tracing::error!("{}", crate::redact::error(e, &[])))
                        .ok()
                })
                .unwrap_or_else(|| {
                    create_makeshift_season(
                        season_number,
                        series_id,
                        source.id.unwrap(),
                        default_season_image,
                    )
                });
            let id = insert_season(tx, season)?;
            seasons_db.insert(season_number, id);
            id
        }
    };
    let key = format!(
        "episode:{series_id}:{}",
        get_serde_json_string(&episode.id).context("No episode ID")?
    );
    let episode = episode_to_channel(episode, source, series_id, season_id)?;
    // Legacy rows have no provider key; adopt their identity before upsert.
    tx.execute("UPDATE OR IGNORE channels SET ext_key=? WHERE source_id=? AND series_id=? AND url=? AND ext_key IS NULL", rusqlite::params![key, source.id, series_id, episode.url])?;
    sql::upsert_channel(
        tx,
        &episode,
        &key,
        episode.episode_num.unwrap_or(0).max(0) as usize,
    )?;
    Ok(())
}

fn create_makeshift_season(
    number: i64,
    series_id: i64,
    source_id: i64,
    image: Option<String>,
) -> Season {
    Season {
        name: match number == NO_SEASON_NUMBER {
            true => "Uncategorized".to_string(),
            false => format!("Season {number}"),
        },
        series_id,
        season_number: number,
        source_id,
        image,
        ..Default::default()
    }
}

fn get_serde_json_string(value: &serde_json::Value) -> Option<String> {
    value
        .as_str()
        .map(|cid| cid.to_string())
        .or_else(|| value.as_i64().map(|cid| cid.to_string()))
        .map(|cid| cid.trim().to_string())
}

fn get_serde_json_i64(value: &serde_json::Value) -> Option<i64> {
    value
        .as_str()
        .and_then(|val| val.trim().parse::<i64>().ok())
        .or_else(|| value.as_i64())
}

fn xtream_season_to_season(season: XtreamSeason, source_id: i64, series_id: i64) -> Result<Season> {
    let season_number = get_serde_json_i64(&season.season_number).context("no season number")?;
    Ok(Season {
        season_number,
        series_id,
        source_id,
        image: season.cover_tmdb.or(season.cover).or(season.overview),
        name: format!("Season {season_number}"),
        ..Default::default()
    })
}

fn episode_to_channel(
    episode: XtreamEpisode,
    source: &Source,
    series_id: i64,
    season_id: i64,
) -> Result<Channel> {
    Ok(Channel {
        id: None,
        group: None,
        image: serde_json::from_value::<XtreamEpisodeInfo>(episode.info)
            .map(|e| e.movie_image)
            .unwrap_or_default(),
        media_type: media_type::MOVIE,
        name: get_serde_json_string(&episode.title)
            .filter(|title| !title.is_empty())
            .unwrap_or_else(|| match get_serde_json_i64(&episode.episode_num) {
                Some(number) => format!("Episode {number}"),
                None => "Episode".to_string(),
            }),
        source_id: source.id,
        url: Some(get_url(
            get_serde_json_string(&episode.id).context("no id")?,
            source,
            media_type::SERIE,
            get_serde_json_string(&episode.container_extension),
        )?),
        series_id: Some(series_id),
        episode_num: get_serde_json_i64(&episode.episode_num),
        quality: 0,
        alt_key: None,
        season_id: Some(season_id),
        stream_id: None,
        group_id: None,
        hidden: false,
        archive_days: None,
        epg_id: None,
        favorite: false,
        tv_archive: None,
    })
}
