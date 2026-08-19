# last30days: environment setup notes

The `last30days` plugin is enabled for this repo in `.claude/settings.json`. This
file records what it needs to actually return data, based on a real run on
2026-08-19 (topic: "AI video tools") that returned zero items.

## Blocked hosts in Claude Code on the web

The engine's live sources are refused by the sandbox egress proxy. Every one of
these answered **403 to CONNECT** (an organization egress-policy denial, not a
plugin bug):

| Host | Source it powers |
|------|------------------|
| `www.reddit.com` | Reddit (keyless RSS + listing lanes) |
| `arctic-shift.photon-reddit.com` | Reddit (Arctic Shift listing search) |
| `hn.algolia.com` | Hacker News |
| `gamma-api.polymarket.com` | Polymarket |

`api.github.com` is a separate case: it resolves, and the proxy injects a token,
but the **search** endpoints (`/search/issues`, `/search/repositories`) still
return 403, so the GitHub source yields nothing either.

Net effect: all five keyless sources report `unreachable` / `auth-failed` /
`rate-limited`. That is not the same as "nothing was posted" - the run
establishes nothing about those platforms.

To fix, these hosts must be allowed in the environment's network policy. See
https://code.claude.com/docs/en/claude-code-on-the-web for how network policy is
configured per environment.

## Use Python 3.12, not 3.13

The engine requires Python 3.12+. This image has 3.11, 3.12, and 3.13, and
`python3` is 3.11, so the engine refuses to start under the default interpreter.

Do not reach for 3.13. Python 3.13 turns on strict X.509 verification by
default, which rejects the sandbox proxy CA and fails every HTTPS call with:

```
[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed:
CA cert does not include key usage extension
```

Python 3.12 verifies the same chain fine. Both link the same OpenSSL 3.0.13, so
the difference is the interpreter's default verify flags, not the CA bundle -
setting `SSL_CERT_FILE` or `REQUESTS_CA_BUNDLE` does not help.

```bash
python3.12 "$SKILL_DIR/scripts/last30days.py" "<topic>" --emit=compact
```

## Optional API keys

With no keys the engine self-reports "3/5 core sources" before it runs. All of
these are optional; each unlocks one lane:

| Variable | Unlocks |
|----------|---------|
| `SCRAPECREATORS_API_KEY` | TikTok, Instagram, deeper Reddit backfill |
| `XAI_API_KEY` / `AUTH_TOKEN` + `CT0` | X / Twitter |
| `BRAVE_API_KEY` / `PERPLEXITY_API_KEY` / `PARALLEL_API_KEY` | grounded web search |
| `yt-dlp` on `PATH` | YouTube transcripts |

## Health check

```bash
python3.12 "$SKILL_DIR/scripts/last30days.py" doctor
python3.12 "$SKILL_DIR/scripts/last30days.py" doctor --postmortem  # after a thin run
```

`doctor` predicts config health before a run; `--postmortem` reads the last run's
cache and reports what actually broke.

## Running locally instead

On a normal machine none of the above applies - there is no egress proxy, so the
four blocked hosts resolve and the keyless Reddit / HN / Polymarket lanes work
with no keys at all. `.claude/settings.json` registers the marketplace, but a
plugin from an external source still needs one install command per machine:

```bash
claude plugin install last30days@last30days-skill
```
