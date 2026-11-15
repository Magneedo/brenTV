use serde::{Deserialize, Serialize};

#[derive(Clone, PartialEq, Debug, Deserialize, Serialize)]
pub struct Channel {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<i64>,
    pub name: String,
    pub url: Option<String>,
    pub group: Option<String>,
    pub image: Option<String>,
    pub media_type: u8,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source_id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub series_id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_id: Option<i64>,
    #[serde(default)]
    pub hidden: bool,
    pub archive_days: Option<u32>,
    pub epg_id: Option<String>,
    pub favorite: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stream_id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tv_archive: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub season_id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_num: Option<i64>,
    /// Parsed from the name: 0 unknown, 1 SD, 2 HD, 3 FHD, 4 UHD.
    #[serde(default)]
    pub quality: u8,
    /// Alternate-feed group key (live channels only).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub alt_key: Option<String>,
}

#[derive(Clone, PartialEq, Debug, Deserialize, Serialize, Default)]
pub struct Season {
    pub id: Option<i64>,
    pub name: String,
    pub season_number: i64,
    pub image: Option<String>,
    pub series_id: i64,
    pub source_id: i64,
}

#[derive(Clone, PartialEq, Debug, Deserialize, Serialize)]
pub struct Source {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<i64>,
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url_origin: Option<String>,
    pub epg_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub username: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub password: Option<String>,
    pub source_type: u8,
    pub enabled: bool,
    pub user_agent: Option<String>,
    pub stream_user_agent: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_updated: Option<i64>,
    pub import_live: bool,
    pub import_movies: bool,
    pub import_series: bool,
    #[serde(skip)]
    pub last_refresh_stats: Option<crate::generated_proto::RefreshStats>,
}

impl Source {
    /// Whether this source imports the given media type (LIVESTREAM, MOVIE or SERIE).
    pub fn imports(&self, media_type: u8) -> bool {
        match media_type {
            crate::media_type::LIVESTREAM => self.import_live,
            crate::media_type::MOVIE => self.import_movies,
            crate::media_type::SERIE => self.import_series,
            _ => true,
        }
    }
}

#[derive(Clone, PartialEq, Debug, Deserialize, Serialize, Default)]
pub struct Settings {
    pub use_stream_caching: Option<bool>,
    pub default_view: Option<u8>,
    pub refresh_on_start: Option<bool>,
    pub default_sort: Option<u8>,
    pub force_tv_mode: Option<bool>,
    pub show_livestreams: Option<bool>,
    pub show_movies: Option<bool>,
    pub show_series: Option<bool>,
    pub show_programmes: Option<bool>,
    pub number_key_switching: Option<bool>,
    pub linux_player: Option<u8>,
    pub mpv_path: Option<String>,
    pub hwdec: Option<String>,
    pub cache_secs: Option<u32>,
    pub demuxer_max_mb: Option<u32>,
    pub mpv_extra_args: Option<String>,
    pub mpv_reuse_window: Option<bool>,
    pub ios_native_player: Option<bool>,
    pub ios_prefer_hls: Option<bool>,
    pub background_audio: Option<bool>,
    pub auto_pip: Option<bool>,
    /// Start page category; 0 or unset means none.
    pub start_group_id: Option<i64>,
    pub start_group_name: Option<String>,
    pub enable_catchup: Option<bool>,
    pub enable_full_guide: Option<bool>,
    pub enable_xmltv: Option<bool>,
    pub keyboard_shortcuts: Option<bool>,
    pub guide_player_titles: Option<bool>,
    pub guide_tile_text: Option<bool>,
    pub auto_quality_discovery: Option<bool>,
    pub search_delay_ms: Option<u32>,
    pub ui_scale_percent: Option<u32>,
    pub square_corners: Option<bool>,
    pub bottom_bar: Option<String>,
    pub media_preferences: Option<String>,
    pub recording_jobs: Option<String>,
    pub download_jobs: Option<String>,
}

#[derive(Clone, PartialEq, Debug, Deserialize, Serialize)]
pub struct Filters {
    pub query: Option<String>,
    pub source_ids: Vec<i64>,
    pub media_types: Option<Vec<u8>>,
    pub view_type: u8,
    pub page: u32,
    pub series_id: Option<i64>,
    pub group_id: Option<i64>,
    pub use_keywords: bool,
    pub sort: u8,
    pub season: Option<i64>,
    /// List the favourite categories (groups) instead of channels.
    pub favorite_groups: bool,
    pub hidden_only: bool,
    pub include_hidden: bool,
}

#[derive(Clone, PartialEq, Debug, Deserialize, Serialize, Default)]
pub struct ChannelHttpHeaders {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub channel_id: Option<i64>,
    pub referrer: Option<String>,
    pub user_agent: Option<String>,
    pub http_origin: Option<String>,
    pub ignore_ssl: Option<bool>,
}
