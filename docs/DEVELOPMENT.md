# changelog_cli — development

For install/usage as a regular user, see the main `README.md`. This file is for anyone working
on the tool itself: why it exists, how it's built, how to run it from source, and how to extend
it.

## Problem

Two things already existed before this tool:

1. `scripts/generate-ir-tags.sh` / `generate-rc-tags.sh` / `generate-qa-tags.sh` create release
   tags (`IR_<APP>_v<version>+<build>`, `RC_<APP>_v<version>+<build>`, with optional `_store_`
   / `_QA_` sub-types) and, at tag-creation time, auto-generate a PR-title release note from
   the previous tag to `HEAD`.
2. A hand-maintained changelog file where someone re-derives the same "PRs since the previous
   tag" view after the fact, across both `IR` and `RC` tags, in chronological order.

(2) is the error-prone part: it requires remembering tag order across two prefixes and
re-deriving PR titles per range by hand. This tool reproduces that view **on demand, read-only**
— it never creates or pushes tags, it only reads existing ones.

## Design

**Two layers, cleanly separated:**

- **Engine** (`lib/src/*.dart`) — pure logic: talks to `git`, parses tag names, computes the
  PR diff between tags, formats it as text/markdown. No UI concerns. Fully unit-testable via a
  fake `GitClient` (see `test/`), no real git calls in tests.
- **TUI** (`lib/src/tui/*.dart`) — an interactive terminal UI built with
  [`nocterm`](https://pub.dev/packages/nocterm) (a Flutter-widget-style framework for TUIs —
  `StatefulComponent`/`setState`/`Focusable`, pure Dart, no Flutter SDK required). It's a thin
  presentation layer over the engine; it does not duplicate any git or formatting logic.

`bin/changelog.dart` is the single entrypoint and dispatches between the two: no positional
arguments launches the TUI, any arguments switch to flag-driven, scriptable output.

**Everything else follows from those two decisions:**

- **Business-agnostic, by rule.** This tool must never contain any store/brand name or other
  business-identifying content — not in source, not in tests, not in this file's or the
  README's own examples. Apps are discovered by scanning `apps/*/version.yaml`; the tag-prefix
  form (e.g. `<country>_<app>` → `<COUNTRY>_<App>`) is derived with the same transform the bash
  scripts use, and is also the default display name.
  A `--display-name` flag lets you get a prettier one-off label for a specific run without
  baking any name into the code. When adding examples to docs or new code, use a placeholder
  like `<app>` / `some_app` rather than a real app name.
- **No hardcoded tag-type list.** `TagInfo.parse` matches
  `^(kind)_<appFormat>(?:_(subtype))?_v(version)(?:\+(build))?$`, so `RC_..._store_v...` →
  type `RC_store` and `IR_..._QA_v...` → type `IR_QA` automatically. New sub-types the release
  scripts grow in the future don't require a code change here.
- **No hardcoded app list.** Unlike the bash scripts' `APPS=(...)` array, apps are discovered
  from the filesystem, so a new app under `apps/` is picked up without editing this tool.
- **Read-only.** The tool never runs `git tag`, `git push`, or anything mutating — only
  `fetch --tags`, `for-each-ref`, and `log`.

## Architecture

```
bin/changelog.dart          entrypoint: dispatch to TUI (no args) or flag-driven print (args)

lib/src/
  git_client.dart            GitClient interface + ProcessGitClient (shells out to `git`)
  app_registry.dart          discoverApps(): scans apps/*/version.yaml, derives tagFormat
  tag_info.dart               TagInfo: parses one tag into kind/subtype/version/build
  changelog.dart              loadTags / buildChangelog / filterByTicketPrefix
  formatter.dart              renders ChangelogEntry list as text or markdown
  time_range.dart             parseTimeRange(): "day"/"2 weeks"/"365 days"/"1 year"/"max" -> Duration?
  search.dart                 searchAcrossTags(): which tag (any type) shipped a matching PR
  cache.dart                  ChangelogCache: on-disk PR-titles-per-tag cache, pure file I/O;
                               plus last_full_sync.json / sync_stats.json helpers
  sync.dart                   buildChangelogEntryAtCached / syncApp / syncAll: cache-first
                               reads, bounded-concurrency (8) tag diffing, and the bulk
                               backfill behind the `sync` command; SyncController for
                               pause/resume/cancel
  version.dart                appVersion: a manually-maintained constant (bump alongside
                               pubspec.yaml's version: field) — baked into the compiled code,
                               so it's correct under `dart run` and once installed as `chlog`

  tui/
    app.dart                  ChangelogTuiRoot: holds the screen stack, no Navigator needed; also
                               owns the one shared "last full sync" timestamp every screen shows
    app_picker.dart           Screen 1 — `Sync all apps` (always first) or pick an app
    type_picker.dart          Screen 2 — pick a tag type (derived from that app's real tags),
                               or the `Search` entry to jump to search_view.dart instead
    changelog_view.dart       Screen 3 — tag list (recent 5, `f` fetches more) then, per selected
                               tag, a lazily-computed scrollable changelog; `/` filters by ticket
                               number or `[tag]`, `s` free-text searches the full PR title
    search_view.dart          Alt screen 3 — type a query, pick a time range, see every tag
                               (any type) whose PR diff matched
    sync_view.dart             Reachable from `Sync all apps` — progress bar + "Scanning..."
                               line while syncAll runs; any key returns once done
    sync_status_line.dart     buildSyncStatusLine(): the "Fully synced — last full sync: ..." /
                               "Not synced yet" line shown on every screen
    pr_title_line.dart        shared PR-title rendering (tags header + stripped title), used by
                               both changelog_view.dart and search_view.dart

test/
  fake_git_client.dart        in-memory GitClient for tests, no real git calls
  tag_info_test.dart          tag parsing (plain, no-build, QA sub-type, store sub-type)
  app_registry_test.dart      tagFormatFor() matches the bash APP_FORMAT transform
  changelog_test.dart         ordering across types, range filtering, PR diffing, rendering
  time_range_test.dart        parseTimeRange() unit/count/"max" parsing
  search_test.dart            grouping by exact type, "within" cutoff, typeFilter, no-match,
                               cache-first reads
  cache_test.dart             load/save round-trip, missing/corrupt file, no-op save,
                               last-full-sync timestamp round-trip
  sync_test.dart               syncApp backfills once then no-ops, syncAll covers every app,
                               onProgress reports a monotonic count and a stable grand total,
                               SyncController pause/resume/cancel

.cache/                       generated by sync / normal use, git-ignored — one <folderName>.json
                               per app, `{"<rawTag>": ["PR title", ...], ...}`, plus a shared
                               last_full_sync.json (`{"at": "<iso8601>"}`) and sync_stats.json
                               (`{"cachedTags": N, "totalTags": M}`)
```

## Run from source (dev loop)

```bash
cd local_tools/changelog_cli
dart pub get                  # once, or whenever pubspec.yaml changes
dart run bin/changelog.dart   # launches the interactive TUI
```

Fetches `args`, `path`, and `nocterm` (and nocterm's own transitive deps) into the shared pub
cache. Re-run `dart pub get` whenever `pubspec.yaml` changes. Every `chlog ...` command below
works the same way as `dart run bin/changelog.dart ...` here — swap the prefix and the
arguments are identical.

## Scripted usage

```bash
chlog some_app
chlog some_app list
chlog all --format text --type rc
chlog some_app \
  --from RC_SOME_APP_v1.2.3+45 --to RC_SOME_APP_v1.2.4+46

# search: which tag(s), across every type, shipped a PR matching this query?
chlog some_app search "TASK-1234" --since "1 year"
chlog some_app search "FE" --since "2 days"
chlog some_app search "hotfix" --since max
chlog all search "TASK-1234" --since "365 days" --type rc

# sync: bulk-warm the cache for every app (see Caching internals below)
chlog sync
```

Example `search` output:

```
Sample:
  RC v1.2.4+46 (RC_SOME_APP_v1.2.4+46)
    FE
    - TASK-1234 Example PR merged title (#123)
  IR v1.2.3+45 (IR_SOME_APP_v1.2.3+45)
    FE
    - TASK-1234 Example PR merged title (#123)
```

or, if nothing matched within the window: `Sample: no match for "TASK-1234" within 1 year.`

| Flag              | Meaning                                                              |
|-------------------|-----------------------------------------------------------------------|
| `--type`          | `ir`, `rc`, `rc_store`, `ir_qa`, ... or `all` (default)               |
| `--from` / `--to` | Explicit tag range (inclusive), defaults to full history             |
| `--limit`         | Only the last N tags                                                  |
| `--ticket-prefix` | Only include PR lines matching this ticket prefix, e.g. `WR`         |
| `--since`         | `search` only: how far back to look — `day`, `"2 days"`, `"365 days"`, `"1 year"`, or `max` (default) |
| `--format`        | `markdown` (default) or `text`                                       |
| `--display-name`  | Override the header name for a single app                            |
| `--no-fetch`      | Skip `git fetch --tags` before reading                               |
| `--no-cache`      | Skip the on-disk PR-title cache for this run (see Caching internals below) |
| `--version` / `-v` | Print the tool's version and exit                                    |

A `make changelog ARGS="..."` target in the root `Makefile` forwards to this, alongside the
existing `ir-tag`/`rc-tag`/`qa-tag` targets.

## Caching internals

Diffing PRs between two tags means shelling out to git — the slow part of this tool. Once a tag
exists, that diff never changes (a released tag's history is immutable), so it's wasted work to
redo it every run. Two things keep this fast:

- **One git call per tag.** `GitClient.prTitlesBetween` gets hash+subject+body for every matching
  commit in a single `git log` call (a custom format string with `\x1f`/`\x1e` delimiters, parsed
  in Dart), instead of one `git log` to find commits plus up to two more `git log -1` calls *per
  matched commit*. With hundreds of tags, that's the difference between thousands of subprocess
  spawns and a few hundred.
- **Bounded concurrency.** Tag diffs don't depend on each other, and git reads don't need
  locking, so `syncApp`/`syncAll` run up to 8 of them at a time (fixed, no flag) instead of one
  at a time.

`lib/src/cache.dart` persists PR titles per tag to `local_tools/changelog_cli/.cache/<app>.json`
(git-ignored). Every command that needs PR titles — `changelog`, `search`, and the TUI's
changelog/search screens — reads that cache first and writes back anything it had to compute
live, so the cache self-heals just from normal use. `list` never touches it (it doesn't diff
PRs). Pass `--no-cache` to bypass it for one run (e.g. to double-check against a fresh git read).
Each newly-computed tag is saved as soon as it's computed (not batched until the end), so killing
the process mid-sync only ever loses whatever was concurrently in flight at that instant.

`sync` is the deliberate, bulk version of the same thing: it walks every discovered app and
every tag type, computing and caching anything not already cached, and prints a one-line
summary per app:

```
some_app: +3 new tags cached (17 total)
other_app: up to date (9 tags cached)
```

The same thing is reachable from the TUI via the app picker's `Sync all apps` entry
(`lib/src/tui/sync_view.dart`): it shows how many tags are already cached *before* the bar starts
moving (e.g. `487 of 600 tags already cached — syncing the remaining 113...`), then a live
progress bar and a `Scanning... <app> <tag>` line.

Both the CLI and TUI sync paths record one shared timestamp
(`local_tools/changelog_cli/.cache/last_full_sync.json`) when a full (uncanceled) sync finishes,
and a synced-tag tally (`sync_stats.json`) after *every* sync attempt, whether it completed or
was paused/canceled partway. Every TUI screen reads both to show e.g. "87% synced (522/600 tags)
· Fully synced — last full sync: <date>" or "· Not synced yet" — the percentage reflects the last
sync run's actual progress, not a live per-screen recheck of current git state.

## Testing

```bash
dart analyze
dart test
```

The engine is tested against `FakeGitClient` (`test/fake_git_client.dart`) so tests never touch
real git state or the network.

## Extending this later

- **New tag sub-type** (e.g. a future `_hotfix_` suffix): no code change needed — `TagInfo.parse`
  already derives `kind`/`subtype` generically from the regex.
- **New app**: no code change needed — it's picked up as soon as `apps/<name>/version.yaml`
  exists.
- **New output format** (e.g. JSON for piping into other tooling): add a case to
  `OutputFormat`/`formatChangelog` in `formatter.dart`; the TUI is unaffected since it renders
  `ChangelogEntry` directly.
- **Live tag watching**: deliberately out of scope for now (see project history) — this tool is
  on-demand only, no polling process. If that's ever needed, it would be a new `watch` command
  that periodically calls `GitClient.fetchTags()` and diffs the tag list, without touching the
  existing `list`/`changelog` commands.
- **Manually add a merged task the git-log scan missed** (e.g. a PR that didn't match the
  `(#123)`/`Merge pull request` grep, or something merged outside the normal PR flow). Flow:
  1. Show the current changelog first, same as today, so the user has full context before
     adding anything.
  2. Prompt for the task itself (free-text line, e.g. `TASK-1234 [FE] short description`).
  3. Ask which tag type(s) this task should be attributed to, as a **multi-select** (one task
     can belong to more than one release line, e.g. both `IR` and `RC` if it shipped to both) —
     built the same way as nocterm's todo-app example (`Focusable` + `space` to toggle a
     checkbox per item, `Enter` to confirm the selection).
  Needs a small persistence layer since these entries don't come from git: a per-app sidecar
  (e.g. `local_tools/changelog_cli/manual_entries/<app>.yaml`, keyed by tag type) that
  `buildChangelog` merges in alongside the git-derived PR titles when rendering, so manual
  entries show up in both the TUI and the flag-driven output without changing how either
  consumes `ChangelogEntry`.
- **Import / backup the CLI's own data.** Once manual entries (above) exist as local sidecar
  files, they're the one piece of state this tool owns that isn't reproducible from git — worth
  being able to back up and restore. A `changelog backup <path>` command would archive
  `manual_entries/` (and any other local-only state added later) into a single file; a matching
  `changelog import <path>` would restore it, merging or overwriting per-app as needed. Useful
  for moving to a new machine, sharing manually-curated entries with a teammate, or recovering
  from an accidental delete — without needing those entries to live in git history at all.
