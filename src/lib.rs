use std::collections::HashMap;

use crate::c::FfiCallback;
use crate::generated_proto::ToggleFavorite;
use anyhow::Ok;

mod alt;
mod c;
mod download;
mod epg;
#[allow(clippy::enum_variant_names)]
mod generated_proto;
mod hls;
mod log;
mod m3u;
mod media_type;
mod redact;
mod relay;
mod settings;
mod sort_type;
mod source_type;
mod sql;
mod transfers;
mod types;
mod utils;
mod view_type;
mod xmltv;
mod xtream;

impl From<crate::types::Settings> for crate::generated_proto::Settings {
    fn from(s: crate::types::Settings) -> Self {
        crate::generated_proto::Settings {
            use_stream_caching: s.use_stream_caching,
            default_view: s.default_view.map(|v| v as u32),
            refresh_on_start: s.refresh_on_start,
            default_sort: s.default_sort.map(|s| s as u32),
            force_tv_mode: s.force_tv_mode,
            show_livestreams: s.show_livestreams,
            show_series: s.show_series,
            show_programmes: s.show_programmes,
            number_key_switching: s.number_key_switching,
            show_movies: s.show_movies,
            linux_player: s.linux_player.map(|v| v as u32),
            mpv_path: s.mpv_path,
            hwdec: s.hwdec,
            cache_secs: s.cache_secs,
            demuxer_max_mb: s.demuxer_max_mb,
            mpv_extra_args: s.mpv_extra_args,
            mpv_reuse_window: s.mpv_reuse_window,
            ios_native_player: s.ios_native_player,
            ios_prefer_hls: s.ios_prefer_hls,
            background_audio: s.background_audio,
            auto_pip: s.auto_pip,
            start_group_id: s.start_group_id,
            start_group_name: s.start_group_name,
            enable_catchup: s.enable_catchup,
            enable_full_guide: s.enable_full_guide,
            enable_xmltv: s.enable_xmltv,
            keyboard_shortcuts: s.keyboard_shortcuts,
            guide_player_titles: s.guide_player_titles,
            guide_tile_text: s.guide_tile_text,
            auto_quality_discovery: s.auto_quality_discovery,
            search_delay_ms: s.search_delay_ms,
            ui_scale_percent: s.ui_scale_percent,
            square_corners: s.square_corners,
            bottom_bar: s.bottom_bar,
            media_preferences: s.media_preferences,
            recording_jobs: s.recording_jobs,
            download_jobs: s.download_jobs,
        }
    }
}

impl From<crate::generated_proto::Settings> for crate::types::Settings {
    fn from(s: crate::generated_proto::Settings) -> Self {
        crate::types::Settings {
            use_stream_caching: s.use_stream_caching,
            default_view: s.default_view.map(|v| v as u8),
            refresh_on_start: s.refresh_on_start,
            default_sort: s.default_sort.map(|s| s as u8),
            force_tv_mode: s.force_tv_mode,
            show_livestreams: s.show_livestreams,
            show_movies: s.show_movies,
            show_series: s.show_series,
            show_programmes: s.show_programmes,
            number_key_switching: s.number_key_switching,
            linux_player: s.linux_player.map(|v| v as u8),
            mpv_path: s.mpv_path,
            hwdec: s.hwdec,
            cache_secs: s.cache_secs,
            demuxer_max_mb: s.demuxer_max_mb,
            mpv_extra_args: s.mpv_extra_args,
            mpv_reuse_window: s.mpv_reuse_window,
            ios_native_player: s.ios_native_player,
            ios_prefer_hls: s.ios_prefer_hls,
            background_audio: s.background_audio,
            auto_pip: s.auto_pip,
            start_group_id: s.start_group_id,
            start_group_name: s.start_group_name,
            enable_catchup: s.enable_catchup,
            enable_full_guide: s.enable_full_guide,
            enable_xmltv: s.enable_xmltv,
            keyboard_shortcuts: s.keyboard_shortcuts,
            guide_player_titles: s.guide_player_titles,
            guide_tile_text: s.guide_tile_text,
            auto_quality_discovery: s.auto_quality_discovery,
            search_delay_ms: s.search_delay_ms,
            ui_scale_percent: s.ui_scale_percent,
            square_corners: s.square_corners,
            bottom_bar: s.bottom_bar,
            media_preferences: s.media_preferences,
            recording_jobs: s.recording_jobs,
            download_jobs: s.download_jobs,
        }
    }
}

impl From<crate::generated_proto::Source> for crate::types::Source {
    fn from(source: crate::generated_proto::Source) -> Self {
        crate::types::Source {
            id: source.id,
            name: source.name,
            source_type: source.source_type as u8,
            last_updated: source.last_updated,
            username: source.username,
            password: source.password,
            url: source.url,
            url_origin: source.url_origin,
            epg_url: source.epg_url,
            stream_user_agent: source.stream_user_agent,
            user_agent: source.user_agent,
            enabled: source.enabled,
            import_live: source.import_live.unwrap_or(true),
            import_movies: source.import_movies.unwrap_or(true),
            import_series: source.import_series.unwrap_or(true),
            last_refresh_stats: None,
        }
    }
}

impl From<crate::types::Source> for crate::generated_proto::Source {
    fn from(source: crate::types::Source) -> Self {
        crate::generated_proto::Source {
            id: source.id,
            name: source.name,
            url: source.url,
            url_origin: source.url_origin,
            epg_url: source.epg_url,
            username: source.username,
            password: source.password,
            source_type: source.source_type as u32,
            enabled: source.enabled,
            user_agent: source.user_agent,
            stream_user_agent: source.stream_user_agent,
            last_updated: source.last_updated,
            import_live: Some(source.import_live),
            import_movies: Some(source.import_movies),
            import_series: Some(source.import_series),
            last_refresh_stats: source.last_refresh_stats,
        }
    }
}

impl From<Vec<crate::types::Source>> for crate::generated_proto::SourceList {
    fn from(sources: Vec<crate::types::Source>) -> Self {
        crate::generated_proto::SourceList {
            sources: sources.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<crate::generated_proto::Filters> for crate::types::Filters {
    fn from(filters: crate::generated_proto::Filters) -> Self {
        crate::types::Filters {
            query: filters.query,
            source_ids: filters.source_ids,
            media_types: (!filters.media_types.is_empty())
                .then(|| filters.media_types.into_iter().map(|m| m as u8).collect()),
            view_type: filters.view_type as u8,
            page: filters.page.max(1),
            series_id: filters.series_id,
            group_id: filters.group_id,
            favorite_groups: filters.favorite_groups,
            hidden_only: filters.hidden_only,
            include_hidden: filters.include_hidden,
            use_keywords: filters.use_keywords,
            sort: filters.sort as u8,
            season: filters.season,
        }
    }
}

impl From<crate::types::Channel> for crate::generated_proto::Channel {
    fn from(channel: crate::types::Channel) -> Self {
        crate::generated_proto::Channel {
            id: channel.id,
            name: channel.name,
            url: channel.url,
            group: channel.group,
            image: channel.image,
            media_type: channel.media_type as u32,
            source_id: channel.source_id,
            series_id: channel.series_id.map(|s| s as u64),
            group_id: channel.group_id,
            favorite: channel.favorite,
            playback_headers: None,
            hidden: channel.hidden,
            archive_days: channel.archive_days,
            epg_id: channel.epg_id,
            stream_id: channel.stream_id.map(|s| s as u64),
            tv_archive: channel.tv_archive,
            season_id: channel.season_id,
            episode_num: channel.episode_num,
            quality: channel.quality as u32,
            alt_key: channel.alt_key,
        }
    }
}
impl From<Vec<crate::types::Channel>> for crate::generated_proto::ChannelList {
    fn from(channels: Vec<crate::types::Channel>) -> Self {
        crate::generated_proto::ChannelList {
            channels: channels.into_iter().map(Into::into).collect(),
            preferred_channel_id: None,
        }
    }
}

impl From<crate::types::ChannelHttpHeaders> for crate::generated_proto::ChannelHttpHeaders {
    fn from(headers: crate::types::ChannelHttpHeaders) -> Self {
        crate::generated_proto::ChannelHttpHeaders {
            id: headers.id,
            channel_id: headers.channel_id,
            referrer: headers.referrer,
            user_agent: headers.user_agent,
            http_origin: headers.http_origin,
            ignore_ssl: headers.ignore_ssl,
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn initialize(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |init_msg: generated_proto::InitMessage| {
            sql::DB_PATH_OVERRIDE
                .set(init_msg.db_path)
                .map_err(|e| anyhow::anyhow!(e))?;
            utils::TEMP_PATH
                .set(init_msg.temp_path)
                .map_err(|e| anyhow::anyhow!(e))?;
            log::init_logger();
            sql::apply_migrations()
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn process_source(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |source: crate::generated_proto::Source| async move {
            utils::process_source(crate::types::Source::from(source))
                .await
                .map(generated_proto::ffi_result::Data::RefreshStats)
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn refresh_source(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |source: crate::generated_proto::Source| async move {
            utils::refresh_source(crate::types::Source::from(source))
                .await
                .map(generated_proto::ffi_result::Data::RefreshStats)
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn delete_source(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(task_id, callback, ptr, len, |source_id| {
        sql::delete_source(source_id)
    });
}

#[unsafe(no_mangle)]
pub extern "C" fn get_channels(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |filters: crate::generated_proto::Filters| {
            Ok(generated_proto::ffi_result::Data::ChannelList(
                crate::generated_proto::ChannelList::from(sql::search(
                    crate::types::Filters::from(filters),
                )?),
            ))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn favorite(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |favorite_msg: ToggleFavorite| {
            sql::favorite_channel(favorite_msg.channel_id, favorite_msg.favorite)
        },
    )
}

/// Marks a category (group) as favourite or not; `channel_id` is the group id.
#[unsafe(no_mangle)]
pub extern "C" fn favorite_group(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(task_id, callback, ptr, len, |msg: ToggleFavorite| {
        sql::favorite_group(msg.channel_id, msg.favorite)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn swap_favorites(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |m: crate::generated_proto::SwapFavorites| sql::swap_favorites(m.id, m.other, m.group),
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn get_settings(task_id: u64, callback: FfiCallback) {
    c::queue_blocking(task_id, callback, || {
        settings::get_settings().map(|settings| {
            generated_proto::ffi_result::Data::Settings(generated_proto::Settings::from(settings))
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn update_settings(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |settings: generated_proto::Settings| {
            settings::update_settings(crate::types::Settings::from(settings))
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn add_last_watched(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: crate::generated_proto::IdMessage| sql::add_last_watched(id.value),
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn set_movie_position(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |position: generated_proto::MoviePosition| {
            sql::set_movie_position(position.channel_id, position.position)
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn get_movie_position(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id_message: generated_proto::IdMessage| {
            Ok(generated_proto::ffi_result::Data::MoviePosition(
                generated_proto::GetMoviePosition {
                    position: sql::get_movie_position(id_message.value)?,
                },
            ))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn remove_last_watched(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: crate::generated_proto::IdMessage| sql::remove_last_watched(id.value),
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn clear_history(task_id: u64, callback: FfiCallback) {
    c::queue_blocking(task_id, callback, sql::clear_history);
}

#[unsafe(no_mangle)]
pub extern "C" fn source_name_exists(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |str_message: generated_proto::StrMessage| {
            Ok(crate::generated_proto::ffi_result::Data::BoolMessage(
                crate::generated_proto::BoolMessage {
                    value: sql::source_name_exists(&str_message.value)?,
                },
            ))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn get_episodes(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        async move |get_episodes_msg: crate::generated_proto::GetEpisodes| {
            xtream::get_episodes(
                get_episodes_msg.series_id,
                get_episodes_msg.source_id,
                get_episodes_msg.fallback_image,
            )
            .await
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn should_show_whats_new(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |opt_str_message: generated_proto::OptStrMessage| {
            Ok(generated_proto::ffi_result::Data::BoolMessage(
                crate::generated_proto::BoolMessage {
                    value: utils::should_show_whats_new(opt_str_message.value)?,
                },
            ))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn update_last_seen_version(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |str_msg: crate::generated_proto::StrMessage| {
            let mut map: HashMap<String, Option<String>> = HashMap::new();
            map.insert(sql::LAST_SEEN_VERSION_KEY.to_string(), Some(str_msg.value));
            sql::update_settings(map)
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn refresh_all(task_id: u64, callback: FfiCallback) {
    c::queue_async(task_id, callback, async move {
        utils::refresh_all().await.map(|stats| {
            generated_proto::ffi_result::Data::RefreshStatsList(generated_proto::RefreshStatsList {
                stats,
            })
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn get_channel_headers(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: crate::generated_proto::IdMessage| {
            let headers = sql::get_channel_headers_by_id(id.value)?;
            Ok(headers.map(|f| {
                generated_proto::ffi_result::Data::Headers(
                    generated_proto::ChannelHttpHeaders::from(f),
                )
            }))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn update_source(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |source_msg: crate::generated_proto::Source| {
            sql::update_source(crate::types::Source::from(source_msg))
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn get_enabled_sources_minimal(task_id: u64, callback: FfiCallback) {
    c::queue_blocking(task_id, callback, || {
        Ok(
            crate::generated_proto::ffi_result::Data::EnabledSourcesMinimal(
                crate::generated_proto::GetEnabledSourcesMinimal {
                    list_id: sql::get_enabled_sources_minimal()?,
                },
            ),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn has_sources(task_id: u64, callback: FfiCallback) {
    c::queue_blocking(task_id, callback, || {
        Ok(crate::generated_proto::ffi_result::Data::BoolMessage(
            crate::generated_proto::BoolMessage {
                value: sql::has_sources()?,
            },
        ))
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn get_sources(task_id: u64, callback: FfiCallback) {
    c::queue_blocking(task_id, callback, || {
        Ok(crate::generated_proto::ffi_result::Data::SourceList(
            crate::generated_proto::SourceList::from(sql::get_sources()?),
        ))
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn set_source_enabled(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |set_source_enabled_msg: crate::generated_proto::SetSourceEnabled| {
            sql::set_source_enabled(
                set_source_enabled_msg.enabled,
                set_source_enabled_msg.source_id,
            )
        },
    )
}

/// Creates the source row without importing anything and returns it with its
/// id, so categories can be chosen before the first import (`process_source`
/// then imports into this row, matched by name).
#[unsafe(no_mangle)]
pub extern "C" fn save_source(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |source: generated_proto::Source| {
            let source = sql::save_source(crate::types::Source::from(source))?;
            Ok(generated_proto::ffi_result::Data::Source(source.into()))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn get_source_categories(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: generated_proto::IdMessage| {
            Ok(generated_proto::ffi_result::Data::CategoryList(
                sql::get_source_categories(id.value)?,
            ))
        },
    )
}

/// Asks the provider for its current categories (Xtream) without importing
/// streams, stores them, and returns the full list.
#[unsafe(no_mangle)]
pub extern "C" fn fetch_source_categories(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: generated_proto::IdMessage| async move {
            Ok(generated_proto::ffi_result::Data::CategoryList(
                xtream::fetch_categories(id.value).await?,
            ))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn set_source_categories(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |msg: generated_proto::SetCategories| sql::set_source_categories(msg),
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn get_alternates(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: generated_proto::IdMessage| {
            let mut list = generated_proto::ChannelList::from(alt::get_alternates(id.value)?);
            list.preferred_channel_id = alt::preferred_channel(id.value)?;
            Ok(generated_proto::ffi_result::Data::ChannelList(list))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn set_alt_override(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |msg: generated_proto::AltOverride| alt::set_override(msg),
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn clear_alt_overrides(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: generated_proto::IdMessage| alt::clear_overrides(id.value),
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn get_stream_variants(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |req: generated_proto::StreamVariantsRequest| async move {
            Ok(generated_proto::ffi_result::Data::StreamVariants(
                hls::get_variants(req).await?,
            ))
        },
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn free_message(ptr: *mut u8, len: usize) {
    unsafe {
        if !ptr.is_null() && len > 0 {
            let fat_ptr = std::ptr::slice_from_raw_parts_mut(ptr, len);
            let _ = Box::from_raw(fat_ptr);
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn get_now_next(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: generated_proto::IdMessage| async move {
            epg::get_now_next(id.value)
                .await
                .map(generated_proto::ffi_result::Data::NowNext)
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn get_schedule(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |r: generated_proto::GuideRequest| async move {
            epg::get_schedule(r.channel_id, r.from, r.to)
                .await
                .map(generated_proto::ffi_result::Data::ProgrammeList)
        },
    );
}
#[unsafe(no_mangle)]
pub extern "C" fn get_catchup(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |r: generated_proto::GuideRequest| async move {
            epg::get_catchup(r.channel_id, r.from, r.to)
                .await
                .and_then(|c| {
                    let mut channel = generated_proto::Channel::from(c);
                    channel.playback_headers =
                        sql::get_channel_headers_by_id(r.channel_id)?.map(Into::into);
                    Ok(generated_proto::ffi_result::Data::ChannelList(
                        generated_proto::ChannelList {
                            channels: vec![channel],
                            preferred_channel_id: None,
                        },
                    ))
                })
        },
    );
}
#[unsafe(no_mangle)]
pub extern "C" fn set_hidden(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |r: generated_proto::SetHidden| sql::set_hidden(r.id, r.hidden, r.group),
    );
}
#[unsafe(no_mangle)]
pub extern "C" fn restore_all_hidden(task_id: u64, callback: FfiCallback) {
    c::queue_blocking(task_id, callback, sql::restore_all_hidden);
}

#[unsafe(no_mangle)]
pub extern "C" fn get_transfer_info(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: generated_proto::IdMessage| async move {
            transfers::resolve(id.value)
                .await
                .map(generated_proto::ffi_result::Data::TransferInfo)
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn get_disk_space(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |path: generated_proto::StrMessage| {
            transfers::disk_space(&path.value).map(|value| {
                generated_proto::ffi_result::Data::DiskSpace(generated_proto::IdMessage { value })
            })
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn download_file(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |request: generated_proto::DownloadRequest| async move {
            download::download(request)
                .await
                .map(generated_proto::ffi_result::Data::DownloadStatus)
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn download_progress(
    task_id: u64,
    callback: FfiCallback,
    ptr: *const u8,
    len: usize,
) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: generated_proto::StrMessage| {
            anyhow::Ok(generated_proto::ffi_result::Data::DownloadStatus(
                download::progress(&id.value),
            ))
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn stop_download(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |id: generated_proto::StrMessage| {
            download::stop(&id.value);
            anyhow::Ok(())
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn relay_open(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_async_with_message(
        task_id,
        callback,
        ptr,
        len,
        |request: generated_proto::RelayRequest| async move {
            relay::open(request)
                .await
                .map(generated_proto::ffi_result::Data::RelayInfo)
        },
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn relay_close(task_id: u64, callback: FfiCallback, ptr: *const u8, len: usize) {
    c::queue_blocking_with_message(
        task_id,
        callback,
        ptr,
        len,
        |token: generated_proto::StrMessage| {
            relay::close(&token.value);
            anyhow::Ok(())
        },
    );
}
