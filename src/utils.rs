use crate::generated_proto::RefreshStats;
use crate::{m3u, source_type, sql, types::Source, xtream};
use anyhow::{Result, anyhow};
use std::sync::OnceLock;
use std::time::Instant;

const DEFAULT_USER_AGENT: &str = "brenTV";
pub static TEMP_PATH: OnceLock<String> = OnceLock::new();
// Largest playlist or provider reply a refresh will download.
pub const MAX_CATALOG_BYTES: usize = 512 << 20;

/// Imports (`wipe` false: new source) or refreshes a source. The importers
/// return stats (with `error` set and the previous data kept when the import
/// as a whole failed); unexpected errors become such stats here. Stats of an
/// existing source are stored. Credentials never reach the error text.
async fn import(source: Source, wipe: bool) -> Result<RefreshStats> {
    let started = Instant::now();
    let (id, name) = (source.id, source.name.clone());
    let secrets: Vec<String> = [&source.username, &source.password]
        .into_iter()
        .flatten()
        .cloned()
        .collect();
    let result = match source.source_type {
        source_type::M3U => m3u::read_m3u8(source, wipe),
        source_type::M3U_LINK => m3u::get_m3u8_from_link(source, wipe).await,
        source_type::XTREAM => xtream::get_xtream(source, wipe).await,
        _ => return Err(anyhow!("invalid source_type")),
    };
    let secrets: Vec<&str> = secrets.iter().map(String::as_str).collect();
    let mut stats = match result {
        Ok(stats) => stats,
        // A new source that failed has no row to store stats in.
        Err(e) if !wipe => return Err(anyhow!(crate::redact::error(&e, &secrets))),
        Err(e) => RefreshStats {
            source_id: id.unwrap_or_default(),
            error: Some(crate::redact::error(&e, &secrets)),
            ..Default::default()
        },
    };
    stats.error = stats.error.map(|e| crate::redact::redact(&e, &secrets));
    for mt in &mut stats.types {
        mt.error = mt.error.take().map(|e| crate::redact::redact(&e, &secrets));
    }
    stats.source_name = name.clone();
    stats.duration_ms = started.elapsed().as_millis() as u64;
    stats.finished_at = chrono::Utc::now().timestamp();
    stats.success = stats.error.is_none();
    if let Some(e) = &stats.error {
        tracing::error!("Failed to import {name}: {e}");
    } else {
        sql::update_source_last_updated(stats.source_id)?;
    }
    if stats.source_id != 0 {
        sql::set_refresh_stats(&stats)?;
    }
    Ok(stats)
}

/// Refreshes a source. A failed refresh is reported (and stored) as stats
/// with `success` false; the previous channels stay.
pub async fn refresh_source(source: Source) -> Result<RefreshStats> {
    import(source, true).await
}

/// Refreshes every enabled source; one failing source doesn't stop the rest.
pub async fn refresh_all() -> Result<Vec<RefreshStats>> {
    let mut all = Vec::new();
    for source in sql::get_sources()?.into_iter().filter(|s| s.enabled) {
        let (id, name) = (source.id.unwrap_or_default(), source.name.clone());
        all.push(
            refresh_source(source)
                .await
                .unwrap_or_else(|e| RefreshStats {
                    source_id: id,
                    source_name: name,
                    finished_at: chrono::Utc::now().timestamp(),
                    error: Some(crate::redact::error(&e, &[])),
                    ..Default::default()
                }),
        );
    }
    Ok(all)
}

/// Imports a new source; failures are errors (there is no source to keep).
pub async fn process_source(source: Source) -> Result<RefreshStats> {
    let stats = import(source, false).await?;
    if let Some(error) = &stats.error {
        return Err(anyhow!(error.clone()));
    }
    Ok(stats)
}

pub fn get_user_agent_from_source(source: &Source) -> Result<String> {
    let user_agent: &str = source
        .user_agent
        .as_deref()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(DEFAULT_USER_AGENT);
    Ok(user_agent.to_string())
}

pub fn should_show_whats_new(version: Option<String>) -> Result<bool> {
    Ok(sql::get_whats_new()? != version)
}

#[cfg(test)]
mod tests {
    use crate::{source_type, sql, types::Source};

    /// A failed refresh is returned and stored as stats, without credentials.
    #[tokio::test]
    async fn failed_refresh_reports_redacted_stats() {
        let _db_guard = crate::sql::test_lock_async().await;
        sql::test_db();
        let source = sql::save_source(Source {
            id: None,
            name: "redact-test".into(),
            url: Some("http://127.0.0.1:1/get.php?username=bob1&password=s3cret".into()),
            url_origin: None,
            epg_url: None,
            username: None,
            password: None,
            source_type: source_type::M3U_LINK,
            enabled: true,
            user_agent: None,
            stream_user_agent: None,
            last_updated: None,
            import_live: true,
            import_movies: true,
            import_series: true,
            last_refresh_stats: None,
        })
        .unwrap();
        let stats = super::refresh_source(source.clone()).await.unwrap();
        assert!(!stats.success);
        let error = stats.error.unwrap();
        assert!(
            !error.contains("s3cret") && !error.contains("bob1"),
            "{error}"
        );
        let stored = sql::get_source_from_id(source.id.unwrap()).unwrap();
        assert!(!stored.last_refresh_stats.unwrap().success);
    }

    /// save_source stores every field, returns the stored row and refuses an
    /// existing name.
    #[tokio::test]
    async fn save_source_round_trip_and_collision() {
        let _db_guard = crate::sql::test_lock_async().await;
        sql::test_db();
        let draft = Source {
            id: None,
            name: "save-test".into(),
            url: Some("http://example.invalid/get.php".into()),
            url_origin: None,
            epg_url: Some("http://epg.invalid/exact.xml".into()),
            username: Some("u".into()),
            password: Some("p".into()),
            source_type: source_type::XTREAM,
            enabled: false,
            user_agent: Some("ua".into()),
            stream_user_agent: Some("stream-ua".into()),
            last_updated: None,
            import_live: true,
            import_movies: false,
            import_series: true,
            last_refresh_stats: None,
        };
        let saved = sql::save_source(draft.clone()).unwrap();
        assert!(!saved.enabled && !saved.import_movies);
        assert_eq!(saved.epg_url, draft.epg_url);
        assert_eq!(saved.stream_user_agent.as_deref(), Some("stream-ua"));
        assert_eq!(saved, sql::get_source_from_id(saved.id.unwrap()).unwrap());
        let err = sql::save_source(draft).unwrap_err().to_string();
        assert!(err.contains("already exists"), "{err}");
    }
}
