use std::io::Write;
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::LazyLock;
use std::{
    collections::HashMap,
    fs::File,
    io::{BufRead, BufReader},
};

use anyhow::{Context, Result, bail};
use regex::{Captures, Regex};
use types::{Channel, Source};

use crate::generated_proto::RefreshStats;
use crate::utils;
use crate::{
    media_type, source_type, sql,
    types::{self, ChannelHttpHeaders},
    utils::get_user_agent_from_source,
};

static NAME_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"tvg-name="(?P<name>[^"]*)""#).unwrap());
static NAME_REGEX_ALT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#",(?P<name>[^\n\r\t]*)"#).unwrap());
static ID_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"tvg-id="(?P<id>[^"]*)""#).unwrap());
static LOGO_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"tvg-logo="(?P<logo>[^"]*)""#).unwrap());
static GROUP_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"group-title="(?P<group>[^"]*)""#).unwrap());

static HTTP_ORIGIN_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"http-origin=(?P<origin>.+)"#).unwrap());
static HTTP_REFERRER_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"http-referrer=(?P<referrer>.+)"#).unwrap());
static HTTP_USER_AGENT_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"http-user-agent=(?P<user_agent>.+)"#).unwrap());

pub fn read_m3u8(mut source: Source, _wipe: bool) -> Result<RefreshStats> {
    source.id = Some(sql::do_tx(|tx| {
        sql::create_or_find_source_by_name(tx, &source)
    })?);
    let result = import_file(&source);
    match result {
        Ok(stats) => Ok(stats),
        Err(e) => Ok(sql::failed_stats(&source, &e)),
    }
}

fn import_file(source: &Source) -> Result<RefreshStats> {
    let source_id = source.id.context("no source id")?;
    let path = if source.source_type == source_type::M3U_LINK {
        get_tmp_path(source_id)?
    } else {
        source.url.clone().context("no file path found")?
    };
    let reader = BufReader::new(File::open(path).context("Failed to open m3u8 file")?);
    let rules = sql::CategoryRules::load(source_id)?;
    // Entries per media type bucket (live, movies, series episodes).
    let mut entries: [Vec<(Channel, Option<ChannelHttpHeaders>, usize)>; 3] = Default::default();
    let mut failures: [Option<String>; 3] = Default::default();
    let mut info = None;
    let mut headers = None;
    let mut position = 0;
    let mut playlist = false;
    // Some providers omit EXTM3U. Malformed entries preserve the affected
    // media type instead of silently deleting its previous channels.
    for line in reader.lines() {
        let line = line.context("Failed to read playlist")?;
        let line = line.trim();
        if line
            .get(..7)
            .is_some_and(|p| p.eq_ignore_ascii_case("#EXTM3U"))
        {
            playlist = true;
            if source.epg_url.is_none() {
                static EPG: LazyLock<Regex> =
                    LazyLock::new(|| Regex::new(r#"(?:x-tvg-url|url-tvg)="([^"]+)""#).unwrap());
                if let Some(url) = EPG.captures(line).and_then(|c| c.get(1)) {
                    sql::get_conn()?.execute(
                        "UPDATE sources SET epg_url=? WHERE id=? AND epg_url IS NULL",
                        rusqlite::params![url.as_str(), source_id],
                    )?;
                }
            }
        }
        if line
            .get(..7)
            .is_some_and(|p| p.eq_ignore_ascii_case("#EXTINF"))
        {
            playlist = true;
            if info.is_some() {
                bail!("Playlist entry has no URL");
            }
            info = Some(line.to_string());
            headers = None;
        } else if line
            .get(..10)
            .is_some_and(|p| p.eq_ignore_ascii_case("#EXTVLCOPT"))
        {
            set_http_headers(
                line,
                headers.get_or_insert_with(ChannelHttpHeaders::default),
            );
        } else if !line.is_empty()
            && !line.starts_with('#')
            && let Some(first) = info.take()
        {
            let mt = media_bucket(line);
            if source.imports(mt) {
                match get_channel_from_lines(first, line.to_string(), source_id) {
                    Ok(channel) => entries[mt as usize].push((channel, headers.take(), position)),
                    Err(e) => failures[mt as usize] = Some(crate::redact::error(&e, &[])),
                }
            }
            position += 1;
        }
    }
    if !playlist {
        bail!("Not an M3U playlist");
    }
    if info.is_some() {
        bail!("Playlist entry has no URL");
    }
    let mut conn = sql::get_conn()?;
    let tx = conn.transaction()?;
    sql::begin_refresh(&tx)?;
    let mut stats = RefreshStats {
        source_id,
        ..Default::default()
    };
    for (mt, entries) in entries.into_iter().enumerate() {
        let mt = mt as u8;
        let mut count = crate::generated_proto::MediaTypeStats {
            media_type: mt as u32,
            enabled: source.imports(mt),
            ..Default::default()
        };
        if source.imports(mt)
            && entries.is_empty()
            && failures[mt as usize].is_none()
            && sql::has_media_rows(&tx, source_id, mt)?
        {
            failures[mt as usize] = Some("Provider returned an empty list".into());
        }
        if let Some(error) = failures[mt as usize].take() {
            count.failed = true;
            count.error = Some(error);
        } else {
            let mut groups = HashMap::new();
            let mut categories: HashMap<String, u32> = HashMap::new();
            let mut seen = std::collections::HashSet::new();
            for (mut channel, headers, position) in entries {
                let key = format!(
                    "{}\t{}",
                    channel.url.as_deref().context("missing URL")?,
                    channel.name
                );
                if !seen.insert(key.clone()) {
                    continue;
                }
                count.fetched += 1;
                if let Some(group) = &channel.group {
                    *categories.entry(group.clone()).or_default() += 1;
                }
                if !rules.allows(mt, channel.group.as_deref()) {
                    count.excluded += 1;
                    continue;
                }
                sql::set_channel_group_id(&mut groups, &mut channel, &tx, &source_id)?;
                let id = sql::upsert_channel(&tx, &channel, &key, position)?;
                tx.prepare_cached("DELETE FROM channel_http_headers WHERE channel_id=?")?
                    .execute([id])?;
                if let Some(mut headers) = headers {
                    headers.channel_id = Some(id);
                    sql::insert_channel_headers(&tx, headers)?;
                }
                count.imported += 1;
            }
            count.categories = categories.len() as u32;
            count.categories_excluded = categories
                .keys()
                .filter(|name| !rules.allows(mt, Some(name)))
                .count() as u32;
            if count.enabled {
                sql::sync_categories(
                    &tx,
                    source_id,
                    mt,
                    &categories
                        .into_iter()
                        .map(|(name, count)| (name, None, Some(count)))
                        .collect::<Vec<_>>(),
                )?;
            }
            sql::finish_type(&tx, source_id, mt)?;
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

pub async fn get_m3u8_from_link(mut source: Source, wipe: bool) -> Result<RefreshStats> {
    source.id = Some(sql::do_tx(|tx| {
        sql::create_or_find_source_by_name(tx, &source)
    })?);
    let result: Result<()> = async {
        let client = reqwest::Client::builder()
            .user_agent(get_user_agent_from_source(&source)?)
            .connect_timeout(std::time::Duration::from_secs(10))
            .read_timeout(std::time::Duration::from_secs(30))
            .build()?;
        let mut response = client
            .get(source.url.as_deref().context("Invalid source")?)
            .send()
            .await
            .and_then(|r| r.error_for_status())
            .map_err(|e| e.without_url())?;
        let mut file = File::create(get_tmp_path(source.id.context("no source id")?)?)?;
        let mut size = 0;
        while let Some(chunk) = response.chunk().await.map_err(|e| e.without_url())? {
            size += chunk.len();
            if size > utils::MAX_CATALOG_BYTES {
                bail!("Playlist is too large");
            }
            file.write_all(&chunk)?;
        }
        Ok(())
    }
    .await;
    match result {
        Ok(()) => read_m3u8(source, wipe),
        Err(e) => Ok(sql::failed_stats(&source, &e)),
    }
}

fn get_tmp_path(source_id: i64) -> Result<String> {
    let mut path = PathBuf::from_str(utils::TEMP_PATH.get().context("no temp path")?)?;
    if !path.exists() {
        std::fs::create_dir_all(&path)?;
    }
    path.push(format!("get-{source_id}.m3u"));
    Ok(path.to_string_lossy().to_string())
}

fn extract_non_empty_capture(caps: Captures) -> Option<String> {
    caps.get(1)
        .map(|m| m.as_str().to_string())
        .filter(|s| !s.trim().is_empty())
}

fn set_http_headers(line: &str, headers: &mut ChannelHttpHeaders) -> bool {
    if let Some(origin) = HTTP_ORIGIN_REGEX
        .captures(line)
        .and_then(extract_non_empty_capture)
    {
        headers.http_origin = Some(origin);
        return true;
    } else if let Some(referrer) = HTTP_REFERRER_REGEX
        .captures(line)
        .and_then(extract_non_empty_capture)
    {
        headers.referrer = Some(referrer);
        return true;
    } else if let Some(user_agent) = HTTP_USER_AGENT_REGEX
        .captures(line)
        .and_then(extract_non_empty_capture)
    {
        headers.user_agent = Some(user_agent);
        return true;
    }
    false
}

fn get_channel_from_lines(first: String, mut second: String, source_id: i64) -> Result<Channel> {
    second = second.trim().to_string();
    if second.is_empty() {
        bail!("second line is empty");
    }
    let name = NAME_REGEX
        .captures(&first)
        .and_then(extract_non_empty_capture)
        .or_else(|| {
            let id = || {
                ID_REGEX
                    .captures(&first)
                    .and_then(extract_non_empty_capture)
            };
            let name_alt = || {
                NAME_REGEX_ALT
                    .captures(&first)
                    .and_then(extract_non_empty_capture)
            };
            name_alt().or(id())
        })
        .context("Couldn't find name from Name or ID")?;
    let group = GROUP_REGEX
        .captures(&first)
        .and_then(extract_non_empty_capture);
    let image = LOGO_REGEX
        .captures(&first)
        .and_then(extract_non_empty_capture);
    let channel = Channel {
        id: None,
        name: name.trim().to_string(),
        group: group.map(|x| x.trim().to_string()),
        image: image.map(|x| x.trim().to_string()),
        url: Some(second.clone()),
        media_type: media_bucket(&second),
        source_id: Some(source_id),
        series_id: None,
        group_id: None,
        hidden: false,
        archive_days: None,
        epg_id: ID_REGEX
            .captures(&first)
            .and_then(|c| c.name("id").map(|m| m.as_str().to_owned()))
            .filter(|s| !s.is_empty()),
        favorite: false,
        stream_id: None,
        tv_archive: None,
        season_id: None,
        episode_num: None,
        quality: 0,
        alt_key: None,
    };
    Ok(channel)
}

/// Which media type toggle an entry falls under: series (an Xtream-style
/// `/series/` path), movie (`/movie/` path or a video file) or live.
fn media_bucket(url: &str) -> u8 {
    let path = url.split(['?', '#']).next().unwrap_or(url);
    let segment = |name: &str| path.split('/').any(|part| part.eq_ignore_ascii_case(name));
    if segment("series") {
        media_type::SERIE
    } else if segment("movie")
        || [".mp4", ".mkv", ".avi", ".m4v", ".mov", ".webm"]
            .iter()
            .any(|ext| {
                path.get(path.len().saturating_sub(ext.len())..)
                    .is_some_and(|s| s.eq_ignore_ascii_case(ext))
            })
    {
        media_type::MOVIE
    } else {
        media_type::LIVESTREAM
    }
}

#[cfg(test)]
mod test_m3u {

    use crate::m3u::get_channel_from_lines;

    #[test]
    fn test_get_channel_from_lines() {
        get_channel_from_lines(r#"#EXTINF:-1 tvg-id="Amazing Channel" tvg-name="Amazing Channel" tvg-logo="http://myurl.local/logos/amazing/amazing-1.png" group-title="The Best Channels"#.to_string()
       , r#"http://myurl.local/1234/1234/1234"#.to_string(), 0).unwrap();
        get_channel_from_lines(r#"#EXTINF:-1 tvg-id="Amazing Channel" tvg-name="" tvg-logo="http://myurl.local/logos/amazing/amazing-1.png" group-title="The Best Channels"#.to_string()
       , r#"http://myurl.local/1234/1234/1234"#.to_string(), 0).unwrap();
        assert!(get_channel_from_lines(r#"#EXTINF:-1 tvg-id="" tvg-name="" tvg-logo="http://myurl.local/logos/amazing/amazing-1.png" group-title="The Best Channels"#.to_string()
       , r#"http://myurl.local/1234/1234/1234"#.to_string(), 0).is_err());
        assert!(get_channel_from_lines(r#"#EXTINF:-1 tvg-id=" " tvg-name="" tvg-logo="http://myurl.local/logos/amazing/amazing-1.png" group-title="The Best Channels"#.to_string()
       , r#"http://myurl.local/1234/1234/1234"#.to_string(), 0).is_err());
        assert!(get_channel_from_lines(r#"#EXTINF:-1 tvg-id="Id Of Channel" tvg-name="Name Of Channel" tvg-logo="http://myurl.local/amazing/stuff.png" group-title="|EU| FRANCE HEVC",Alt Name Of Channel"#.to_string(), "http://myurl.local/1111/1111.ts".to_string(), 0).unwrap().name == "Name Of Channel");
        assert!(get_channel_from_lines(r#"#EXTINF:-1 tvg-id="Id Of Channel" tvg-name="" tvg-logo="http://myurl.local/amazing/stuff.png" group-title="|EU| FRANCE HEVC",Alt Name Of Channel"#.to_string(), "http://myurl.local/1111/1111.ts".to_string(), 0).unwrap().name == "Alt Name Of Channel");
    }
}
