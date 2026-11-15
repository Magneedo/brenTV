//! Resolve current catalog identities and bounded provider connection metadata.
use crate::{
    generated_proto::TransferInfo,
    sql,
    types::{Channel, Source},
};
use anyhow::{Result, anyhow, bail};
use std::{
    collections::hash_map::DefaultHasher,
    hash::{Hash, Hasher},
    time::Duration,
};

fn inputs(id: i64) -> Result<(Channel, Source, String)> {
    let conn = sql::get_conn()?;
    let mut channel = conn
        .query_row(
            "SELECT c.* FROM channels c JOIN sources s ON s.id=c.source_id
        WHERE c.id=? AND s.enabled=1 AND c.hidden=0
        AND NOT EXISTS(SELECT 1 FROM groups g WHERE g.id=c.group_id AND g.hidden=1)",
            [id],
            sql::row_to_channel,
        )
        .map_err(|_| anyhow!("This item is no longer available"))?;
    let source = sql::get_source_from_id(
        channel
            .source_id
            .ok_or_else(|| anyhow!("Source unavailable"))?,
    )?;
    channel.series_id = conn.query_row("SELECT series_id FROM channels WHERE id=?", [id], |r| {
        r.get(0)
    })?;
    if channel.series_id.is_some() && conn.query_row("SELECT EXISTS(SELECT 1 FROM channels p WHERE p.source_id=? AND p.ext_key='2:'||? AND (p.hidden=1 OR EXISTS(SELECT 1 FROM groups g WHERE g.id=p.group_id AND g.hidden=1)))", rusqlite::params![channel.source_id, channel.series_id], |r| r.get::<_, bool>(0))? { bail!("This series is hidden"); }
    if !source.imports(if channel.series_id.is_some() {
        crate::media_type::SERIE
    } else {
        channel.media_type
    }) || !matches!(channel.media_type, 0..=2)
    {
        bail!("This item is not available for recording or download");
    }
    let url = reqwest::Url::parse(channel.url.as_deref().unwrap_or_default())
        .map_err(|_| anyhow!("Stream unavailable"))?;
    if !matches!(url.scheme(), "http" | "https") {
        bail!("Only HTTP streams can be recorded or downloaded");
    }
    let key: Option<String> =
        conn.query_row("SELECT ext_key FROM channels WHERE id=?", [id], |r| {
            r.get(0)
        })?;
    let mut hash = DefaultHasher::new();
    (
        source.id,
        &source.url,
        &source.username,
        &source.password,
        &key,
        &channel.url,
    )
        .hash(&mut hash);
    Ok((channel, source, format!("{:016x}", hash.finish())))
}

fn limit(value: &serde_json::Value) -> u32 {
    value["user_info"]["max_connections"]
        .as_u64()
        .or_else(|| value["user_info"]["max_connections"].as_str()?.parse().ok())
        .map(|n| if n == 0 { 64 } else { n.min(64) as u32 })
        .unwrap_or(1)
}

static LIMITS: std::sync::LazyLock<
    std::sync::Mutex<std::collections::HashMap<u64, (std::time::Instant, u32)>>,
> = std::sync::LazyLock::new(|| std::sync::Mutex::new(std::collections::HashMap::new()));
async fn cached_limit(source: &Source) -> u32 {
    let mut hash = DefaultHasher::new();
    (
        &source.url,
        &source.username,
        &source.password,
        &source.user_agent,
    )
        .hash(&mut hash);
    let key = hash.finish();
    if let Some((at, limit)) = LIMITS.lock().unwrap().get(&key).copied()
        && at.elapsed() < Duration::from_secs(300)
    {
        return limit;
    }
    let value = provider_limit(source).await.unwrap_or(1);
    let mut cache = LIMITS.lock().unwrap();
    cache.retain(|_, (at, _)| at.elapsed() < Duration::from_secs(300));
    if cache.len() >= 32 {
        cache.clear();
    }
    cache.insert(key, (std::time::Instant::now(), value));
    value
}
async fn provider_limit(source: &Source) -> Option<u32> {
    if source.source_type != crate::source_type::XTREAM {
        return Some(1);
    }
    let mut url = reqwest::Url::parse(source.url.as_ref()?).ok()?;
    url.query_pairs_mut()
        .append_pair("username", source.username.as_deref()?)
        .append_pair("password", source.password.as_deref()?);
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(5))
        .redirect(reqwest::redirect::Policy::limited(3))
        .build()
        .ok()?;
    let request = client.get(url).header(
        reqwest::header::USER_AGENT,
        source.user_agent.as_deref().unwrap_or("brenTV"),
    );
    let mut response = request.send().await.ok()?.error_for_status().ok()?;
    let mut bytes = Vec::new();
    while let Some(chunk) = response.chunk().await.ok()? {
        if bytes.len() + chunk.len() > 256 * 1024 {
            return None;
        }
        bytes.extend_from_slice(&chunk);
    }
    Some(limit(&serde_json::from_slice(&bytes).ok()?))
}

pub async fn resolve(id: i64) -> Result<TransferInfo> {
    let (channel, source, identity) = inputs(id)?;
    let max_connections = cached_limit(&source).await;
    let (current, current_source, current_identity) = inputs(id)?;
    if identity != current_identity || source != current_source || channel != current {
        bail!("This item changed; try again");
    }
    let conn = sql::get_conn()?;
    let show_name = channel
        .series_id
        .and_then(|sid| {
            conn.query_row(
                "SELECT name FROM channels WHERE source_id=? AND ext_key='2:'||?",
                rusqlite::params![channel.source_id, sid],
                |r| r.get::<_, String>(0),
            )
            .ok()
        })
        .unwrap_or_default();
    let season = channel
        .season_id
        .and_then(|sid| {
            conn.query_row("SELECT season_number FROM seasons WHERE id=?", [sid], |r| {
                r.get::<_, u32>(0)
            })
            .ok()
        })
        .unwrap_or(0);
    let episode = channel
        .episode_num
        .and_then(|n| n.try_into().ok())
        .unwrap_or(0);
    let mut channel: crate::generated_proto::Channel = channel.into();
    channel.playback_headers = sql::get_channel_headers_by_id(id)?.map(Into::into);
    if channel.playback_headers.as_ref().is_some_and(|h| {
        [&h.referrer, &h.user_agent, &h.http_origin]
            .iter()
            .any(|v| v.as_ref().is_some_and(|v| v.contains(['\r', '\n'])))
    }) {
        bail!("Invalid playback headers");
    }
    Ok(TransferInfo {
        channel: Some(channel),
        max_connections,
        identity,
        show_name,
        season,
        episode,
    })
}

/// Available bytes for the filesystem containing an existing directory.
pub fn disk_space(path: &str) -> Result<i64> {
    let path = std::ffi::CString::new(path).map_err(|_| anyhow!("Invalid folder"))?;
    let mut stat = std::mem::MaybeUninit::<libc::statvfs>::uninit();
    // SAFETY: the NUL-terminated path and writable stat buffer live across the call.
    if unsafe { libc::statvfs(path.as_ptr(), stat.as_mut_ptr()) } != 0 {
        bail!("Could not check free disk space. Check the destination folder");
    }
    // SAFETY: a successful statvfs call initialized the complete structure.
    let stat = unsafe { stat.assume_init() };
    Ok(((stat.f_bavail as u128) * (stat.f_frsize as u128)).min(i64::MAX as u128) as i64)
}

#[cfg(test)]
mod tests {
    #[test]
    fn connection_limits() {
        use serde_json::json;
        assert_eq!(super::limit(&json!({})), 1);
        assert_eq!(
            super::limit(&json!({"user_info":{"max_connections":"3"}})),
            3
        );
        assert_eq!(
            super::limit(&json!({"user_info":{"max_connections":0}})),
            64
        );
        assert_eq!(
            super::limit(&json!({"user_info":{"max_connections":"bad"}})),
            1
        );
    }
}
