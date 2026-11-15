//! Alternate feeds grouped by name, with refresh-stable provider overrides.

use std::collections::HashSet;
use std::sync::LazyLock;

use anyhow::{Result, anyhow, bail};
use regex::Regex;
use rusqlite::{OptionalExtension, Transaction, TransactionBehavior, params};

use crate::generated_proto::AltOverride;
use crate::types::Channel;

static SEPARATORS: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[|:\-_\.\[\](){}\s]+").unwrap());
static SUPERSCRIPTS: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[ᴬ-ᵿᶛ-ᶿ⁰-⁹ˢˣ]+").unwrap());
static CODEC: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?i)\bh\.26([45])\b").unwrap());

fn tokens(name: &str) -> Vec<String> {
    let name = SUPERSCRIPTS.replace_all(name, " ");
    let name = CODEC.replace_all(&name, "h26$1").to_lowercase();
    SEPARATORS
        .split(&name)
        .filter(|s| !s.is_empty())
        .map(str::to_owned)
        .collect()
}

fn rank(token: &str) -> u8 {
    match token {
        "uhd" | "4k" | "8k" | "2160p" => 4,
        "fhd" | "1080p" | "1080i" => 3,
        "hd" | "720p" => 2,
        "sd" | "576p" | "576i" | "480p" => 1,
        _ => 0,
    }
}

/// Preserve numbers, timeshifts, country prefixes and ordinary words such as
/// raw, plus, vip and multi. Superscript decorations (including RAW) are tags.
pub fn alt_key(name: &str) -> Option<String> {
    let words = tokens(name);
    let mut kept = Vec::new();
    let mut i = 0;
    while i < words.len() {
        let word = words[i].as_str();
        // Backup tags never lead a name: "ALT TV" keeps "alt".
        let backup = i > 0 && matches!(word, "backup" | "bkp" | "bk" | "alt" | "alternative");
        let fps = matches!(word, "25" | "30" | "50" | "60" | "24" | "120")
            && words.get(i + 1).is_some_and(|s| s == "fps");
        if backup || fps {
            i += 1;
            if fps
                || words
                    .get(i)
                    .is_some_and(|s| s.chars().all(|c| c.is_ascii_digit()))
            {
                i += 1;
            }
            continue;
        }
        let numbered_backup = i > 0
            && word
                .strip_prefix('b')
                .is_some_and(|s| !s.is_empty() && s.chars().all(|c| c.is_ascii_digit()));
        if rank(word) == 0
            && !numbered_backup
            && !matches!(
                word,
                "qhd"
                    | "1440p"
                    | "hq"
                    | "lq"
                    | "hevc"
                    | "h265"
                    | "x265"
                    | "h264"
                    | "x264"
                    | "avc"
                    | "24fps"
                    | "25fps"
                    | "30fps"
                    | "50fps"
                    | "60fps"
                    | "120fps"
            )
        {
            kept.push(word);
        }
        i += 1;
    }
    let key = kept.join(" ");
    (key.chars().filter(|c| c.is_alphanumeric()).count() >= 2).then_some(key)
}

pub fn quality(name: &str) -> u8 {
    let superscript_rank = if name.contains("ᵁᴴᴰ") {
        4
    } else if name.contains("ᶠᴴᴰ") {
        3
    } else if name.contains("ᴴᴰ") {
        2
    } else if name.contains("ˢᴰ") {
        1
    } else {
        0
    };
    tokens(name)
        .iter()
        .map(|s| rank(s))
        .chain([superscript_rank])
        .max()
        .unwrap_or(0)
}

pub fn get_alternates(channel_id: i64) -> Result<Vec<Channel>> {
    let conn = crate::sql::get_conn()?;
    let mut stmt = conn.prepare(
        "SELECT c.*, g.name AS group_name FROM channels c
         JOIN sources s ON s.id=c.source_id LEFT JOIN groups g ON g.id=c.group_id
         WHERE c.alt_key=(SELECT alt_key FROM channels WHERE id=?1)
           AND c.hidden=0 AND COALESCE(g.hidden,0)=0 AND s.import_live=1 AND c.id<>?1 AND c.media_type=0 AND s.enabled=1 AND c.url IS NOT NULL AND c.url<>''
           AND (SELECT media_type FROM channels WHERE id=?1)=0
         ORDER BY EXISTS(SELECT 1 FROM alt_overrides o WHERE o.source_id=c.source_id
                    AND o.ext_key=c.ext_key AND o.kind=2) DESC,
           c.quality DESC, c.source_id=(SELECT source_id FROM channels WHERE id=?1) DESC, c.name, c.id")?;
    let rows = stmt.query_map([channel_id], |r| {
        Ok(Channel {
            id: r.get("id")?,
            name: r.get("name")?,
            url: r.get("url")?,
            group: r.get("group_name")?,
            image: r.get("image")?,
            media_type: r.get("media_type")?,
            source_id: r.get("source_id")?,
            series_id: r.get("series_id")?,
            group_id: r.get("group_id")?,
            hidden: r.get("hidden")?,
            archive_days: r.get("archive_days")?,
            epg_id: r.get("epg_id")?,
            favorite: r.get::<_, Option<bool>>("favorite")?.unwrap_or(false),
            stream_id: r.get("stream_id")?,
            tv_archive: r.get("tv_archive")?,
            season_id: r.get("season_id")?,
            episode_num: r.get("episode_num")?,
            quality: r.get("quality")?,
            alt_key: r.get("alt_key")?,
        })
    })?;
    Ok(rows.collect::<rusqlite::Result<_>>()?)
}

pub fn preferred_channel(channel_id: i64) -> Result<Option<i64>> {
    Ok(crate::sql::get_conn()?.query_row(
        "SELECT c.id FROM channels c JOIN sources s ON s.id=c.source_id JOIN alt_overrides o ON o.source_id=c.source_id AND o.ext_key=c.ext_key AND o.kind=2 WHERE c.alt_key=(SELECT alt_key FROM channels WHERE id=?) AND c.media_type=0 AND c.hidden=0 AND NOT EXISTS (SELECT 1 FROM groups g WHERE g.id=c.group_id AND g.hidden=1) AND s.enabled=1 AND s.import_live=1 AND c.url IS NOT NULL ORDER BY o.id DESC LIMIT 1",
        [channel_id], |r| r.get(0)).optional()?)
}

fn identity(tx: &Transaction, id: i64) -> Result<(i64, String)> {
    let (source, ext, media): (i64, Option<String>, u8) = tx.query_row(
        "SELECT source_id, ext_key, media_type FROM channels WHERE id=?",
        [id],
        |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
    )?;
    if media != 0 {
        bail!("Only live feeds can have alternate overrides");
    }
    Ok((
        source,
        ext.ok_or_else(|| anyhow!("Refresh the source first before overriding this feed"))?,
    ))
}

// Reserve the writer before reading identities; deferred read-to-write
// upgrades can fail immediately when a refresh is writing concurrently.
fn write_override(f: impl FnOnce(&Transaction) -> Result<()>) -> Result<()> {
    let mut conn = crate::sql::get_conn()?;
    let tx = conn.transaction_with_behavior(TransactionBehavior::Immediate)?;
    f(&tx)?;
    tx.commit()?;
    Ok(())
}

pub fn set_override(msg: AltOverride) -> Result<()> {
    write_override(|tx| {
        let (source, ext) = identity(tx, msg.channel_id)?;
        if !(0..=2).contains(&msg.kind) {
            bail!("Unknown alternate override kind");
        }
        let target = if msg.kind == 1 {
            let target = identity(
                tx,
                msg.target_channel_id
                    .ok_or_else(|| anyhow!("A link needs a target feed"))?,
            )?;
            if target == (source, ext.clone()) {
                bail!("A feed cannot link to itself");
            }
            Some(target)
        } else {
            None
        };
        if msg.kind != 2 {
            tx.execute(
                "DELETE FROM alt_overrides WHERE source_id=? AND ext_key=? AND kind IN (0,1)",
                params![source, ext],
            )?;
            reset_key(tx, source, &ext)?;
        } else {
            tx.execute("DELETE FROM alt_overrides WHERE kind=2 AND EXISTS (
                SELECT 1 FROM channels c WHERE c.source_id=alt_overrides.source_id AND c.ext_key=alt_overrides.ext_key
                AND c.alt_key=(SELECT alt_key FROM channels WHERE id=?))", [msg.channel_id])?;
        }
        tx.execute("INSERT OR REPLACE INTO alt_overrides(source_id,ext_key,kind,target_source_id,target_ext_key) VALUES (?,?,?,?,?)",
            params![source, ext, msg.kind, target.as_ref().map(|t| t.0), target.as_ref().map(|t| &t.1)])?;
        apply_overrides(tx, source)
    })
}

fn reset_key(tx: &Transaction, source: i64, ext: &str) -> Result<()> {
    let name: Option<String> = tx
        .query_row(
            "SELECT name FROM channels WHERE source_id=? AND ext_key=?",
            params![source, ext],
            |r| r.get(0),
        )
        .optional()?;
    if let Some(name) = name {
        tx.execute(
            "UPDATE channels SET alt_key=? WHERE source_id=? AND ext_key=?",
            params![alt_key(&name), source, ext],
        )?;
    }
    Ok(())
}

pub fn clear_overrides(channel_id: i64) -> Result<()> {
    write_override(|tx| {
        let (source, ext) = identity(tx, channel_id)?;
        tx.execute(
            "DELETE FROM alt_overrides WHERE source_id=? AND ext_key=?",
            params![source, ext],
        )?;
        reset_key(tx, source, &ext)?;
        apply_overrides(tx, source)
    })
}

fn resolve_link(
    tx: &Transaction,
    source: i64,
    ext: &str,
    visiting: &mut HashSet<(i64, String)>,
) -> Result<Option<String>> {
    let exists: bool = tx.query_row(
        "SELECT EXISTS(SELECT 1 FROM channels WHERE source_id=? AND ext_key=?)",
        params![source, ext],
        |r| r.get(0),
    )?;
    if !exists {
        return Ok(None);
    }
    if !visiting.insert((source, ext.to_owned())) {
        bail!("Alternate links contain a cycle");
    }
    let target: Option<(i64,String)> = tx.query_row("SELECT target_source_id,target_ext_key FROM alt_overrides WHERE source_id=? AND ext_key=? AND kind=1",
        params![source,ext], |r| Ok((r.get(0)?,r.get(1)?))).optional()?;
    let key = if let Some((ts, te)) = target {
        let exists: bool = tx.query_row(
            "SELECT EXISTS(SELECT 1 FROM channels WHERE source_id=? AND ext_key=?)",
            params![ts, te],
            |r| r.get(0),
        )?;
        if exists {
            let key =
                resolve_link(tx, ts, &te, visiting)?.unwrap_or_else(|| format!("link:{ts}:{te}"));
            tx.execute("UPDATE channels SET alt_key=? WHERE (source_id=? AND ext_key=?) OR (source_id=? AND ext_key=?)", params![key,source,ext,ts,te])?;
            Some(key)
        } else {
            reset_key(tx, source, ext)?;
            tx.query_row(
                "SELECT alt_key FROM channels WHERE source_id=? AND ext_key=?",
                params![source, ext],
                |r| r.get(0),
            )?
        }
    } else {
        tx.query_row(
            "SELECT alt_key FROM channels WHERE source_id=? AND ext_key=?",
            params![source, ext],
            |r| r.get(0),
        )
        .optional()?
        .flatten()
    };
    visiting.remove(&(source, ext.to_owned()));
    Ok(key)
}

/// Resolve the stored graph, including incoming links from other sources.
/// Missing feeds retain their overrides until a later refresh restores them.
pub fn apply_overrides(tx: &Transaction, source_id: i64) -> Result<()> {
    tx.execute("UPDATE channels SET alt_key=NULL WHERE source_id=? AND EXISTS(SELECT 1 FROM alt_overrides o WHERE o.source_id=channels.source_id AND o.ext_key=channels.ext_key AND o.kind=0)", [source_id])?;
    let mut stmt = tx.prepare(
        "WITH RECURSIVE affected(source_id,ext_key) AS (
        SELECT source_id,ext_key FROM alt_overrides WHERE source_id=?1 OR target_source_id=?1
        UNION
        SELECT o.source_id,o.ext_key FROM alt_overrides o JOIN affected a
        ON o.target_source_id=a.source_id AND o.target_ext_key=a.ext_key WHERE o.kind=1)
        SELECT a.source_id,a.ext_key FROM affected a JOIN alt_overrides o
        ON o.source_id=a.source_id AND o.ext_key=a.ext_key WHERE o.kind=1 ORDER BY o.id",
    )?;
    let links = stmt
        .query_map([source_id], |r| {
            Ok((r.get::<_, i64>(0)?, r.get::<_, String>(1)?))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    for (source, ext) in links {
        resolve_link(tx, source, &ext, &mut HashSet::new())?;
    }
    tx.execute("DELETE FROM alt_overrides WHERE kind=2 AND id IN (
        SELECT older.id FROM alt_overrides older JOIN channels a ON a.source_id=older.source_id AND a.ext_key=older.ext_key
        JOIN channels b ON b.alt_key=a.alt_key JOIN alt_overrides newer ON newer.source_id=b.source_id AND newer.ext_key=b.ext_key
        WHERE older.kind=2 AND newer.kind=2 AND newer.id>older.id)", [])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalisation() {
        let _db_guard = crate::sql::test_lock();
        for name in [
            "ESPN FHD",
            "ESPN HD",
            "ESPN ᴴᴰ",
            "ESPN ᶠᴴᴰ",
            "ESPN ᵁᴴᴰ",
            "ESPN ˢᴰ",
            "ESPN ᴿᴬᵂ",
            "ESPN (Backup)",
            "ESPN 1080p 50fps",
            "ESPN [backup 2]",
            "ESPN alt 1",
            "ESPN b2",
            "ESPN H.265 50 fps",
            " ESPN__HEVC...HQ ",
        ] {
            assert_eq!(alt_key(name).as_deref(), Some("espn"), "{name}");
        }
        assert_eq!(alt_key("US| ESPN HEVC").as_deref(), Some("us espn"));
        assert_eq!(alt_key("UK:Sky-News_HD").as_deref(), Some("uk sky news"));
        for (a, b) in [
            ("ESPN", "ESPN 2"),
            ("BBC One", "BBC One Scotland"),
            ("Sky Sports Main Event", "Sky Sports Main Event +1"),
            ("CNN", "CNN International"),
            ("UK: Sky News", "US: Sky News"),
            ("Channel", "HDTV Channel"),
            ("TV", "SHDTV"),
            ("Canal", "Canal plus"),
            ("Feed", "Feed raw"),
            ("Feed", "Feed vip"),
            ("Feed", "Feed multi"),
            ("Sky +1", "Sky +2"),
            ("TV", "ALT TV"),
            ("Bk", "BK Sports"),
            ("Radio", "Radio 576"),
        ] {
            assert_ne!(alt_key(a), alt_key(b), "{a} / {b}");
        }
        for name in ["", "HD FHD backup 2", "ᴴᴰ", "a", "[4K] 50 fps", "-"] {
            assert_eq!(alt_key(name), None, "{name}");
        }
    }

    #[test]
    fn qualities() {
        let _db_guard = crate::sql::test_lock();
        for (name, expected) in [
            ("ESPN", 0),
            ("HDTV Channel", 0),
            ("SHDTV", 0),
            ("ESPN sd", 1),
            ("ESPN 576i", 1),
            ("ESPN 480p", 1),
            ("ESPN ˢᴰ", 1),
            ("ESPN hd", 2),
            ("ESPN 720p", 2),
            ("ESPN ᴴᴰ", 2),
            ("ESPN ᶠᴴᴰ", 3),
            ("ESPN 1080i", 3),
            ("ESPN FHD", 3),
            ("ESPN UHD HD", 4),
            ("ESPN ᵁᴴᴰ", 4),
            ("ESPN 2160p", 4),
            ("ESPN 4k", 4),
            ("ESPN 8k", 4),
        ] {
            assert_eq!(quality(name), expected, "{name}");
        }
    }

    fn source(tx: &Transaction, name: &str, enabled: bool) -> i64 {
        tx.execute(
            "INSERT INTO sources(name,enabled) VALUES (?,?)",
            params![name, enabled],
        )
        .unwrap();
        tx.last_insert_rowid()
    }

    fn feed(tx: &Transaction, source: i64, ext: &str, name: &str) -> i64 {
        tx.execute("INSERT INTO channels(source_id,ext_key,name,url,media_type,favorite,quality,alt_key) VALUES (?,?,?,'http://localhost/feed',0,0,?,?)",params![source,ext,name,quality(name),alt_key(name)]).unwrap();
        tx.last_insert_rowid()
    }

    fn key(id: i64) -> Option<String> {
        crate::sql::get_conn()
            .unwrap()
            .query_row("SELECT alt_key FROM channels WHERE id=?", [id], |r| {
                r.get(0)
            })
            .unwrap()
    }

    fn override_feed(id: i64, kind: i32, target: Option<i64>) {
        set_override(AltOverride {
            channel_id: id,
            kind,
            target_channel_id: target,
        })
        .unwrap();
    }

    #[test]
    fn alternates_order_and_filter() {
        let _db_guard = crate::sql::test_lock();
        crate::sql::test_db();
        let (base, same, other, uhd, preferred) = crate::sql::do_tx(|tx| {
            let s = source(tx, "alt-order-a", true);
            let t = source(tx, "alt-order-b", true);
            let disabled = source(tx, "alt-order-disabled", false);
            let base = feed(tx, s, "base", "OrderTest HD");
            let same = feed(tx, s, "same", "OrderTest FHD");
            let other = feed(tx, t, "other", "OrderTest FHD");
            let uhd = feed(tx, t, "uhd", "OrderTest UHD");
            let preferred = feed(tx, t, "pref", "OrderTest SD");
            feed(tx, disabled, "disabled", "OrderTest UHD");
            let no_url = feed(tx, s, "no-url", "OrderTest UHD");
            tx.execute("UPDATE channels SET url=NULL WHERE id=?", [no_url])?;
            let movie = feed(tx, s, "movie", "OrderTest UHD");
            tx.execute("UPDATE channels SET media_type=1 WHERE id=?", [movie])?;
            Ok((base, same, other, uhd, preferred))
        })
        .unwrap();
        override_feed(preferred, 2, None);
        let rows = get_alternates(base).unwrap();
        assert_eq!(
            rows.iter().map(|r| r.id.unwrap()).collect::<Vec<_>>(),
            [preferred, uhd, same, other]
        );
        assert_eq!(rows[1].quality, 4);
        assert_eq!(rows[1].alt_key.as_deref(), Some("ordertest"));
        override_feed(same, 2, None);
        assert_eq!(get_alternates(base).unwrap()[0].id, Some(same));
        let count: i64 = crate::sql::get_conn().unwrap().query_row(
            "SELECT COUNT(*) FROM alt_overrides o JOIN channels c ON c.source_id=o.source_id AND c.ext_key=o.ext_key WHERE o.kind=2 AND c.id=?",
            [preferred], |r| r.get(0)).unwrap();
        assert_eq!(count, 0);
    }

    #[test]
    fn overrides_survive_refresh_and_clear() {
        let _db_guard = crate::sql::test_lock();
        crate::sql::test_db();
        let (s, t, a, b, _short) = crate::sql::do_tx(|tx| {
            let s = source(tx, "alt-refresh-a", true);
            let t = source(tx, "alt-refresh-b", true);
            Ok((
                s,
                t,
                feed(tx, s, "a", "RefreshTest HD"),
                feed(tx, t, "b", "OtherTest FHD"),
                feed(tx, t, "short", "X"),
            ))
        })
        .unwrap();
        override_feed(a, 0, None);
        assert_eq!(key(a), None);
        override_feed(a, 1, Some(b));
        assert_eq!(key(a), key(b));
        override_feed(a, 2, None);
        let (a, b, short) = crate::sql::do_tx(|tx| {
            tx.execute(
                "DELETE FROM channels WHERE source_id IN (?,?)",
                params![s, t],
            )?;
            let a = feed(tx, s, "a", "RefreshTest UHD");
            let b = feed(tx, t, "b", "OtherTest HD");
            let short = feed(tx, t, "short", "X");
            apply_overrides(tx, s)?;
            Ok((a, b, short))
        })
        .unwrap();
        assert_eq!(key(a), key(b));
        assert_eq!(get_alternates(b).unwrap()[0].id, Some(a));
        assert_eq!(preferred_channel(b).unwrap(), Some(a));
        clear_overrides(a).unwrap();
        assert_eq!(key(a).as_deref(), Some("refreshtest"));
        override_feed(a, 1, Some(short));
        assert_eq!(key(a), key(short));
        assert!(key(a).unwrap().starts_with("link:"));
        override_feed(a, 0, None);
        assert_eq!(key(a), None);
        clear_overrides(a).unwrap();
        crate::sql::do_tx(|tx| {
            tx.execute("UPDATE channels SET ext_key=NULL WHERE id=?", [a])?;
            Ok(())
        })
        .unwrap();
        assert!(
            set_override(AltOverride {
                channel_id: a,
                kind: 0,
                target_channel_id: None
            })
            .unwrap_err()
            .to_string()
            .contains("Refresh")
        );
        assert!(
            clear_overrides(a)
                .unwrap_err()
                .to_string()
                .contains("Refresh")
        );
    }

    #[test]
    fn incoming_links_chains_missing_feeds_and_cycles() {
        let _db_guard = crate::sql::test_lock();
        crate::sql::test_db();
        let (s, t, a, b, c) = crate::sql::do_tx(|tx| {
            let s = source(tx, "alt-chain-a", true);
            let t = source(tx, "alt-chain-b", true);
            Ok((
                s,
                t,
                feed(tx, s, "a", "ChainA"),
                feed(tx, t, "b", "ChainB"),
                feed(tx, t, "c", "ChainC"),
            ))
        })
        .unwrap();
        override_feed(a, 1, Some(b));
        override_feed(b, 1, Some(c));
        assert_eq!(key(a), key(c));
        assert!(
            set_override(AltOverride {
                channel_id: c,
                kind: 1,
                target_channel_id: Some(a)
            })
            .is_err()
        );
        crate::sql::do_tx(|tx| {
            tx.execute(
                "UPDATE channels SET name='ChainNew',alt_key='chainnew' WHERE id=?",
                [c],
            )?;
            apply_overrides(tx, t)
        })
        .unwrap();
        assert_eq!(key(a).as_deref(), Some("chainnew"));
        crate::sql::do_tx(|tx| {
            tx.execute("DELETE FROM channels WHERE id=?", [c])?;
            apply_overrides(tx, t)
        })
        .unwrap();
        assert_eq!(key(a).as_deref(), Some("chainb"));
        crate::sql::do_tx(|tx| {
            feed(tx, t, "c", "ChainReturned");
            apply_overrides(tx, t)
        })
        .unwrap();
        assert_eq!(key(a).as_deref(), Some("chainreturned"));
        assert!(get_alternates(a).unwrap().len() >= 2);
        assert_ne!(s, t);
    }

    #[test]
    fn unlink_and_missing_feed_overrides_survive_refresh() {
        let _db_guard = crate::sql::test_lock();
        crate::sql::test_db();
        let (source, a, b) = crate::sql::do_tx(|tx| {
            let source = source(tx, "alt-absent", true);
            Ok((
                source,
                feed(tx, source, "a", "AbsentTest HD"),
                feed(tx, source, "b", "AbsentTest SD"),
            ))
        })
        .unwrap();
        override_feed(a, 0, None);
        let a = crate::sql::do_tx(|tx| {
            tx.execute("DELETE FROM channels WHERE id=?", [a])?;
            apply_overrides(tx, source)?;
            let a = feed(tx, source, "a", "AbsentTest FHD");
            apply_overrides(tx, source)?;
            Ok(a)
        })
        .unwrap();
        assert_eq!(key(a), None);
        override_feed(a, 1, Some(b));
        assert_eq!(key(a), key(b));
        let a = crate::sql::do_tx(|tx| {
            tx.execute("DELETE FROM channels WHERE id=?", [a])?;
            apply_overrides(tx, source)?;
            let count: i64 = tx.query_row(
                "SELECT COUNT(*) FROM alt_overrides WHERE source_id=? AND ext_key='a'",
                [source],
                |r| r.get(0),
            )?;
            assert_eq!(count, 1);
            let a = feed(tx, source, "a", "AbsentTest UHD");
            apply_overrides(tx, source)?;
            Ok(a)
        })
        .unwrap();
        assert_eq!(key(a), key(b));
        clear_overrides(a).unwrap();
        assert_eq!(key(a).as_deref(), Some("absenttest"));
    }
}
