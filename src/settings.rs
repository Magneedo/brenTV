use std::collections::HashMap;
use std::str::FromStr;

use anyhow::Result;

use crate::{sql, types::Settings};

pub const USE_STREAM_CACHING: &str = "useStreamingCaching";
pub const DEFAULT_VIEW: &str = "defaultView";
pub const REFRESH_ON_START: &str = "refreshOnStart";
pub const DEFAULT_SORT: &str = "defaultSort";
pub const FORCE_TV_MODE: &str = "forceTvMode";
pub const SHOW_LIVESTREAMS: &str = "showLivestreams";
pub const SHOW_MOVIES: &str = "showMovies";
pub const SHOW_SERIES: &str = "showSeries";
pub const SHOW_PROGRAMMES: &str = "showProgrammes";
pub const LINUX_PLAYER: &str = "linuxPlayer";
pub const MPV_PATH: &str = "mpvPath";
pub const HWDEC: &str = "hwdec";
pub const CACHE_SECS: &str = "cacheSecs";
pub const DEMUXER_MAX_MB: &str = "demuxerMaxMb";
pub const MPV_EXTRA_ARGS: &str = "mpvExtraArgs";
pub const MPV_REUSE_WINDOW: &str = "mpvReuseWindow";
pub const IOS_NATIVE_PLAYER: &str = "iosNativePlayer";
pub const IOS_PREFER_HLS: &str = "iosPreferHls";
pub const BACKGROUND_AUDIO: &str = "backgroundAudio";
pub const AUTO_PIP: &str = "autoPip";
pub const START_GROUP_ID: &str = "startGroupId";
pub const START_GROUP_NAME: &str = "startGroupName";

pub fn get_settings() -> Result<Settings> {
    let map = sql::get_settings()?;
    fn get<T: FromStr>(map: &HashMap<String, String>, key: &str) -> Option<T> {
        map.get(key).and_then(|s| s.parse().ok())
    }
    Ok(Settings {
        use_stream_caching: get(&map, USE_STREAM_CACHING),
        default_view: get(&map, DEFAULT_VIEW),
        refresh_on_start: get(&map, REFRESH_ON_START),
        default_sort: get(&map, DEFAULT_SORT),
        force_tv_mode: get(&map, FORCE_TV_MODE),
        show_livestreams: get(&map, SHOW_LIVESTREAMS),
        show_movies: get(&map, SHOW_MOVIES),
        show_series: get(&map, SHOW_SERIES),
        show_programmes: get(&map, SHOW_PROGRAMMES),
        number_key_switching: get(&map, "numberKeySwitching"),
        linux_player: get(&map, LINUX_PLAYER),
        mpv_path: get(&map, MPV_PATH),
        hwdec: get(&map, HWDEC),
        cache_secs: get(&map, CACHE_SECS),
        demuxer_max_mb: get(&map, DEMUXER_MAX_MB),
        mpv_extra_args: get(&map, MPV_EXTRA_ARGS),
        mpv_reuse_window: get(&map, MPV_REUSE_WINDOW),
        ios_native_player: get(&map, IOS_NATIVE_PLAYER),
        ios_prefer_hls: get(&map, IOS_PREFER_HLS),
        background_audio: get(&map, BACKGROUND_AUDIO),
        auto_pip: get(&map, AUTO_PIP),
        start_group_id: get(&map, START_GROUP_ID),
        start_group_name: get(&map, START_GROUP_NAME),
        enable_catchup: get(&map, "enableCatchup"),
        enable_full_guide: get(&map, "enableFullGuide"),
        enable_xmltv: get(&map, "enableXmltv"),
        keyboard_shortcuts: get(&map, "keyboardShortcuts"),
        guide_player_titles: get(&map, "guidePlayerTitles"),
        guide_tile_text: get(&map, "guideTileText"),
        auto_quality_discovery: get(&map, "autoQualityDiscovery"),
        search_delay_ms: get(&map, "searchDelayMs"),
        ui_scale_percent: get(&map, "uiScalePercent"),
        square_corners: get(&map, "squareCorners"),
        media_preferences: get(&map, "mediaPreferences"),
        recording_jobs: get(&map, "recordingJobs"),
        download_jobs: get(&map, "downloadJobs"),
        bottom_bar: Some(normalize_bottom_bar(
            map.get("bottomBar").map(String::as_str),
        )),
    })
}

/// Stores every setting that is set; unset ones keep their stored value.
pub fn update_settings(settings: Settings) -> Result<()> {
    let clear_xmltv =
        settings.enable_xmltv == Some(false) || settings.show_programmes == Some(false);
    let mut map: HashMap<String, Option<String>> = HashMap::new();
    let mut put = |key: &str, value: Option<String>| {
        if let Some(value) = value {
            map.insert(key.to_string(), Some(value));
        }
    };
    put(
        USE_STREAM_CACHING,
        settings.use_stream_caching.map(|v| v.to_string()),
    );
    put(DEFAULT_VIEW, settings.default_view.map(|v| v.to_string()));
    put(
        REFRESH_ON_START,
        settings.refresh_on_start.map(|v| v.to_string()),
    );
    put(DEFAULT_SORT, settings.default_sort.map(|v| v.to_string()));
    put(FORCE_TV_MODE, settings.force_tv_mode.map(|v| v.to_string()));
    put(
        SHOW_LIVESTREAMS,
        settings.show_livestreams.map(|v| v.to_string()),
    );
    put(SHOW_MOVIES, settings.show_movies.map(|v| v.to_string()));
    put(SHOW_SERIES, settings.show_series.map(|v| v.to_string()));
    put(
        "numberKeySwitching",
        settings.number_key_switching.map(|v| v.to_string()),
    );
    put(
        SHOW_PROGRAMMES,
        settings.show_programmes.map(|v| v.to_string()),
    );
    put(LINUX_PLAYER, settings.linux_player.map(|v| v.to_string()));
    put(MPV_PATH, settings.mpv_path);
    put(HWDEC, settings.hwdec);
    put(CACHE_SECS, settings.cache_secs.map(|v| v.to_string()));
    put(
        DEMUXER_MAX_MB,
        settings.demuxer_max_mb.map(|v| v.to_string()),
    );
    put(MPV_EXTRA_ARGS, settings.mpv_extra_args);
    put(
        MPV_REUSE_WINDOW,
        settings.mpv_reuse_window.map(|v| v.to_string()),
    );
    put(
        IOS_NATIVE_PLAYER,
        settings.ios_native_player.map(|v| v.to_string()),
    );
    put(
        IOS_PREFER_HLS,
        settings.ios_prefer_hls.map(|v| v.to_string()),
    );
    put(
        BACKGROUND_AUDIO,
        settings.background_audio.map(|v| v.to_string()),
    );
    put(AUTO_PIP, settings.auto_pip.map(|v| v.to_string()));
    put(
        START_GROUP_ID,
        settings.start_group_id.map(|v| v.to_string()),
    );
    put(START_GROUP_NAME, settings.start_group_name);
    put(
        "enableCatchup",
        settings.enable_catchup.map(|v| v.to_string()),
    );
    put(
        "enableFullGuide",
        settings.enable_full_guide.map(|v| v.to_string()),
    );
    put("enableXmltv", settings.enable_xmltv.map(|v| v.to_string()));
    put(
        "keyboardShortcuts",
        settings.keyboard_shortcuts.map(|v| v.to_string()),
    );
    put(
        "guidePlayerTitles",
        settings.guide_player_titles.map(|v| v.to_string()),
    );
    put(
        "guideTileText",
        settings.guide_tile_text.map(|v| v.to_string()),
    );
    put(
        "autoQualityDiscovery",
        settings.auto_quality_discovery.map(|v| v.to_string()),
    );
    put(
        "searchDelayMs",
        settings.search_delay_ms.map(|v| v.to_string()),
    );
    put(
        "uiScalePercent",
        settings.ui_scale_percent.map(|v| v.to_string()),
    );
    put(
        "squareCorners",
        settings.square_corners.map(|v| v.to_string()),
    );
    put(
        "bottomBar",
        settings.bottom_bar.map(|s| normalize_bottom_bar(Some(&s))),
    );
    put("mediaPreferences", settings.media_preferences);
    put("recordingJobs", settings.recording_jobs);
    put("downloadJobs", settings.download_jobs);
    sql::update_settings(map)?;
    if clear_xmltv {
        crate::xmltv::clear_cache();
    }
    Ok(())
}

/// Normalization is also the migration for settings saved before this feature.
pub fn normalize_bottom_bar(value: Option<&str>) -> String {
    use serde_json::{Value, json};
    let defaults = [
        "all",
        "categories",
        "favorites",
        "history",
        "downloads",
        "recordings",
    ];
    let input = value
        .and_then(|s| serde_json::from_str::<Vec<Value>>(s).ok())
        .unwrap_or_default();
    let mut pages: Vec<Value> = Vec::new();
    for entry in input {
        if let (Some(page), Some(visible)) = (entry["page"].as_str(), entry["visible"].as_bool()) {
            let page = if page == "localMedia" {
                "downloads"
            } else {
                page
            };
            if !defaults.contains(&page) {
                continue;
            }
            if let Some(existing) = pages.iter_mut().find(|p| p["page"] == page) {
                if page == "downloads" && visible {
                    existing["visible"] = json!(true);
                }
            } else {
                pages.push(json!({"page": page, "visible": visible}));
            }
        }
    }
    for page in defaults {
        if !pages.iter().any(|p| p["page"] == page) {
            pages.push(json!({"page": page, "visible": page != "recordings"}));
        }
    }
    if !pages.iter().any(|p| p["visible"] == true) {
        pages.iter_mut().find(|p| p["page"] == "all").unwrap()["visible"] = json!(true);
    }
    pages.push(json!({"page": "settings", "visible": true}));
    serde_json::to_string(&pages).unwrap()
}

#[cfg(test)]
mod tests {
    use super::normalize_bottom_bar;
    use serde_json::{Value, json};
    #[test]
    fn old_settings_and_corrupt_values_migrate() {
        let migrated: Vec<Value> = serde_json::from_str(&normalize_bottom_bar(None)).unwrap();
        assert_eq!(
            migrated
                .iter()
                .map(|p| p["page"].as_str().unwrap())
                .collect::<Vec<_>>(),
            [
                "all",
                "categories",
                "favorites",
                "history",
                "downloads",
                "recordings",
                "settings"
            ]
        );
        assert!(!migrated[5]["visible"].as_bool().unwrap());
        assert!(migrated[4]["visible"].as_bool().unwrap());
        assert_eq!(
            normalize_bottom_bar(Some("bad")),
            normalize_bottom_bar(None)
        );
    }
    #[test]
    fn preserve_order_deduplicate_pin_settings_and_recover_empty() {
        let input = json!([
            {"page":"settings","visible":false}, {"page":"history","visible":true},
            {"page":"all","visible":false}, {"page":"history","visible":false},
            {"page":"unknown","visible":true}
        ])
        .to_string();
        let normalized = normalize_bottom_bar(Some(&input));
        let pages: Vec<Value> = serde_json::from_str(&normalized).unwrap();
        assert_eq!(pages[0]["page"], "history");
        assert_eq!(
            pages.last().unwrap(),
            &json!({"page":"settings","visible":true})
        );
        assert_eq!(normalize_bottom_bar(Some(&normalized)), normalized);
        let hidden = json!([
            "all",
            "categories",
            "favorites",
            "history",
            "localMedia",
            "recordings",
            "downloads"
        ])
        .as_array()
        .unwrap()
        .iter()
        .map(|p| json!({"page":p,"visible":false}))
        .collect::<Vec<_>>();
        let recovered: Vec<Value> = serde_json::from_str(&normalize_bottom_bar(Some(
            &serde_json::to_string(&hidden).unwrap(),
        )))
        .unwrap();
        assert!(
            recovered
                .iter()
                .any(|p| p == &json!({"page":"all","visible":true}))
        );
    }
}
