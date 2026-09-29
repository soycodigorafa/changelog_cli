# changelog_cli

Turns this monorepo's git tags into a changelog — no more manually figuring out "which PRs
landed between tag X and tag Y."

## Install

```bash
dart pub global activate --source git https://github.com/soycodigorafa/changelog_cli
```

Make sure `~/.pub-cache/bin` is on your `PATH` (pub warns if it isn't). There's no auto-update —
re-run the command above whenever the tool itself changes.

## Quick Start

```bash
chlog
```

Run it from inside your monorepo checkout, then:

1. Pick an app.
2. First time? Pick **Sync all apps** to fetch everything (shows a live progress bar).
3. Pick a tag type, then a tag — or jump straight to **Search** / **Upcoming**.
4. Read the PR changelog.

## Screens

### App picker

First row is always **Sync all apps** — runs a full sync with a live `Scanning... <app> <tag>`
progress bar. Anything already synced is cached, so pausing or canceling never loses work.

| Key | Action |
|---|---|
| `p` | pause / resume sync |
| `Esc` | cancel sync |

### Tag type picker

Only shows types that actually exist for the chosen app (e.g. `IR`, `RC`, `RC_store`...), plus
shortcuts to **Search** and **Upcoming**.

| Key | Action |
|---|---|
| `Enter` | open selected type |
| `s` | jump to Search |
| `u` | jump to Upcoming |
| `Esc` | back |

### Tag list

Shows the 5 most recent tags — listing is cheap, but diffing every tag's PRs isn't, so older
tags are loaded on demand.

| Key | Action |
|---|---|
| `↑` / `↓` | move |
| `Enter` | view changelog for the selected tag |
| `f` | load 5 more tags |
| `Esc` | back |
| `q` | quit |

### Changelog detail

Shows the PR titles merged since the *previous* tag.

| Key | Action |
|---|---|
| `↑` / `↓` / `PgUp` / `PgDn` | scroll |
| `/` | filter by ticket number or `[tag]` |
| `s` | free-text search across PR titles |
| `Esc` | back to tag list |
| `q` | quit |

### Search

Ask "which tag — across every type — shipped a PR matching this?" instead of browsing tag by
tag.

1. Type a query.
2. Use `←` / `→` to pick how far back to look (`day` / `week` / `month` / `year` / `max`,
   defaults to `max`).
3. `Enter` to search — results are grouped by tag type.
4. `Esc` from results goes back to the query box, so you can widen the range and search again.

### Upcoming

Shows every PR merged since each tag type's latest tag — i.e. what would ship if you cut a
release right now. Always reads live from git, so it's never stale.

- One section per tag type: a `<TYPE> — N pending changes` header and the tag it's counting
  from.
- PRs listed newest-first, each with its merge date and relative age (e.g. `4 days ago`).

| Key | Action |
|---|---|
| `↑` / `↓` / `PgUp` / `PgDn` | scroll |
| `/` | filter by ticket number or `[tag]` (per section) |
| `c` | copy every listed PR title — handy for a release-note draft |
| `Esc` | back |
| `q` | quit |

## Good to know

- **Caching**: every PR lookup is saved to disk, so viewing the same tag again is instant.
- **Copy to clipboard**: on the changelog, search, and Upcoming screens, click-and-drag over PR
  titles to copy the selection (via your terminal's OSC 52 support — iTerm2, Terminal.app,
  WezTerm, Alacritty, and tmux all work).

---

Looking for flags, CI usage, caching internals, or how to work on the tool itself? See
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).
