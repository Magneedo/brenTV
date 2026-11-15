//! Keeps provider credentials out of logs, error messages and stored stats.
//! Xtream puts the username and password in query strings
//! (`?username=…&password=…`) and in stream paths (`/live/<user>/<pass>/1.ts`).

use std::sync::LazyLock;

use regex::Regex;

static QUERY: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)\b(username|password|user|pass|passwd|token|auth|key)=[^&\s'\x22)]*").unwrap()
});
static XTREAM_PATH: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)/(live|movie|series|timeshift)/[^/\s'\x22]+/[^/\s'\x22]+/").unwrap()
});
static USERINFO: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"://[^/@\s'\x22]+@").unwrap());

/// Masks credentials in `text`, plus any `secrets` given (a source's own
/// username and password, wherever they appear).
pub fn redact(text: &str, secrets: &[&str]) -> String {
    let mut out = QUERY.replace_all(text, "$1=***").into_owned();
    out = XTREAM_PATH.replace_all(&out, "/$1/***/***/").into_owned();
    out = USERINFO.replace_all(&out, "://***@").into_owned();
    for secret in secrets.iter().filter(|s| s.len() >= 3) {
        out = out.replace(secret, "***");
    }
    out
}

/// `redact` for an error and its causes, as one line.
pub fn error(e: &anyhow::Error, secrets: &[&str]) -> String {
    redact(&format!("{e:#}"), secrets)
}

#[cfg(test)]
mod tests {
    use super::redact;

    #[test]
    fn masks_query_path_userinfo_and_secrets() {
        let s = "error sending request for url (http://h:8080/player_api.php?username=bob1&password=s3cret&action=get_live_streams)";
        let r = redact(s, &[]);
        assert!(!r.contains("bob1") && !r.contains("s3cret"), "{r}");
        let r = redact("http://h/live/bob1/s3cret/123.ts failed", &[]);
        assert_eq!(r, "http://h/live/***/***/123.ts failed");
        let r = redact("http://bob1:s3cret@h/get.php", &[]);
        assert!(!r.contains("s3cret"), "{r}");
        let r = redact("http://h/bob1/s3cret/123", &["bob1", "s3cret"]);
        assert_eq!(r, "http://h/***/***/123");
    }
}
