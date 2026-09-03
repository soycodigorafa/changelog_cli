# changelog_cli

A small tool that turns this monorepo's git tags into a changelog, so nobody has to manually
reassemble "which PRs landed between tag X and tag Y" by hand anymore.

## Install

```bash
dart pub global activate --source git https://github.com/soycodigorafa/changelog_cli
```

Make sure `~/.pub-cache/bin` is on your `PATH` (pub warns if it isn't). After new changes are
pushed to this tool's repo, re-run the same command to pick them up — there's no live
auto-update.

## Launch

```bash
chlog
```

`chlog` operates on whichever monorepo checkout you run it from.

Pick an app → `Sync all apps` (first run) → browse a tag or `Search` to see PR changelogs.

Every screen shows a status line — "Fully synced — last full sync: 2026-09-02 14:32" or "Not
synced yet — run Sync from the app picker" — and the app picker's first row is always
`Sync all apps`: pick it to run a full sync with a live progress bar and a `Scanning... <app>
<tag>` line. While it's running, `p` pauses/resumes and `Esc` cancels — either way, anything
already cached before pausing/canceling is kept (nothing is redone). When it finishes (or is
canceled) it says `Done.`/`Canceled.` plus a per-app summary, and any key returns you to the
app picker.

Pick an app → pick a tag type (only types that actually exist for that app are listed) → pick a
tag → view its changelog. The tag list only shows the 5 most recent tags at first (listing tags
is cheap; diffing every tag's PRs against its predecessor is not, so that work is deferred).
Press `f` to reveal 5 more (repeatable back through full history). Selecting a tag (`Enter`) then
lazily computes and shows the PR titles merged since the *previous* tag — only for that one tag,
not the whole history. Keys on the tag list: `↑`/`↓` move, `Enter` view changelog, `f` fetch more,
`Esc` back a screen, `q` quit. Keys on the changelog detail: `↑`/`↓`/`PgUp`/`PgDn` scroll, `/`
starts a live filter by ticket number or `[tag]`, `s` starts a live free-text search across the
full PR title (`Enter`/`Esc` to stop editing either one), `Esc` back to the tag list, `q` quit.

The type picker also lists a `Search` entry (and `s` jumps there directly from that screen, no
need to scroll to it): pick it to ask "which tag (across every type — `IR`, `RC`, `RC_store`,
`IR_QA`, ...) shipped a PR matching this?" instead of browsing one tag at a time. Type a query,
use `←`/`→` to pick how far back to look (`day`/`week`/`month`/`year`/`max`, defaults to `max`),
`Enter` to search. Results are grouped by exact tag type; `Esc` from the results goes back to the
query (so you can widen the range and re-run without retyping).

Every PR-title lookup (browsing a tag, or `Search`) reads from the on-disk cache first and
writes anything newly computed back into it, so the second time you look at the same tag it's
instant.

---

Scripted/CI usage, flags, caching internals, and everything about working on the tool itself
(design rationale, architecture, running from source, tests, extending it)? See
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).
