---
name: arty
description: >
  Maintains a project console: one claude.ai artifact per project that works as
  a remote dashboard. It shows where things stand and what comes next (a
  briefing read from docky's newest changelog plus the TODO list), every docky
  document, a navigable git graph of features and merges with "as of" time
  travel, the decision inbox, and the live maps and dated reports about the
  code. Refreshes are routine; judgement is needed only for the deviations a
  sync reports. Use when refreshing the console
  after work, when a decision needs figures, diffs or numbers rather than a
  chat question, when publishing a visual artifact about the code, when
  checking whether a map has gone stale, or when picking up an answer left on
  the console. Triggers: /arty, "update the console", "put it on the console",
  "this needs a decision", "is that diagram still right", "publish this as an
  artifact", "what's waiting for me", "what's stale".
---

# arty

**git keeps facts, the console keeps state.** Decisions, changes and code live in
the repository. The console shows them, alongside what git can't hold:
proposals awaiting judgement, map staleness and per-claim confidence.

The console is the user's **remote view of the project**: opened from a phone or
another machine to see what is going on, what comes next, and what is waiting on
them. Everything about the repository on it is a **snapshot** computed by `arty`
from git and `docs/`, never retyped by an agent — the briefing included, which is
read from docky's changelogs. An agent writes only what needs judgement: proposals
and exhibits.

**Routine by default, agentic by exception.** A refresh is mechanical: dump, `arty
sync`, write the batches it prints. Judgement comes in only for the **deviations**
sync lists — an answered proposal to act on, a stale map, a changelog that fell
behind, a TODO list docky's rules say is untidy. No deviations, nothing to decide.

## 1. Layout

```
.arty                 tracked pointer: console = <url>, project, schema
<console artifact>    one per project: Now, Docs, History, Decisions, Maps & reports
<exhibit artifacts>   the heavy visuals, registered as rows in the console
```

Read `.arty` first. No pointer means no console — offer section 2, don't invent one.
The pointer is the only thing arty adds to the repository: live state is never
mirrored into git, and the console is never the home of an ADR.

What the page shows, and where each part comes from:

| Tab | Shows | Source |
|---|---|---|
| Now | HEAD's version, briefing (newest changelog, its ADRs, what left the TODO list, blockers), recently landed features, recent ADRs, waiting proposals, top TODOs, unmerged branches, attention items and deviations | snapshot + `proposals` + `maps` |
| Docs | every file under `docs/` plus `README.md`, rendered, with cross-links and per-file history; "as of" any commit on HEAD's line | snapshot |
| History | features grouped by `[X.Y]` (version-commit) with merged/open status, lane graph of the last 300 commits on every branch, commit inspector | snapshot |
| Decisions | proposals: answer from any device | `proposals` |
| Maps & reports | exhibits and inline figures | `maps`, `reports` |

## 2. Setup

```sh
arty page --project "<Project>" > "$SCRATCH/console.html"
```

Publish it with `capabilities: {db: {}, user: {}}`, title `<Project> Console`,
icon `dashboard`. Then:

```sh
arty init --url <console-url>        # writes .arty and the meta/project seed
```

`write_db` the seed to `meta/project`, run a refresh (section 6), commit `.arty`,
and offer to pin the console. One console per repository, forever — a second one
splits the inbox.

**Upgrading the page.** When `arty page` changes (a new `console.html` here),
republish it to the console's URL: read the artifact first, then publish the new
output over it. Rows survive a republish.

## 3. Schema

The schema is the contract. The page is generic: every project-specific fact is a
value in the database, never a branch in the page. `arty check` enforces this
section.

```
meta/project                   project, schema (3), remote, created, head

snapshot/h-<id>                id, parts, bytes, generated_at, head, branch
snapshot/p-<id>-NNN            id, n, data      a slice of the snapshot's JSON
                               written once by `arty sync`, never updated, never by hand
                               the JSON carries `briefs` (section 4) and `deviations`

proposals/p-YYYYMMDD-HHMM-slug
  title          one line, the call to be made
  question       what exactly is being asked
  urgency        blocking | soon | whenever
  status         open | answered | accepted | withdrawn | superseded
  assumption     what the session proceeded with meanwhile  (required)
  options[]      {key, label, summary, tradeoffs, recommended}   two or more
  evidence       {markdown, mermaid, diffs[{path, patch}], exhibits[url]}
  anchors[]      paths the decision concerns
  asked_at, asked_by
  answer         {choice, notes, answered_at}      written by the page
  outcome        {adr, changelog, acked_at}        written by the agent

maps/m-slug
  title, purpose
  url            the exhibit -- or, for an inline map, none:
  markdown       inline body, shown in the console
  figures[]      {src, title?, caption, group?}  images shown in the console;
                 src is figures/<map-slug>/<file> published with the console,
                 or an https url
  figure_rendering   auto | smooth | pixelated | crisp-edges   (optional)
  anchors[]      pathspecs the map describes       (required)
  commit         HEAD when it was last refreshed
  refreshed_at
  status         current | stale | retired
  claims         {verified, unverified, partial, planned}   rollup, derived
  invalidated_by[{commit, subject}], invalidated_count, checked_at   by sync

reports/r-YYYYMMDD-slug
  title, question, answer, date, anchors[]
  status         current | settled | stale
  url            the exhibit, or `markdown` and/or `figures[]` (as maps) for a
                 report that needs no page of its own
  path           docs/analysis-artifacts/<file> when docky holds the written report
```

The snapshot's id is a digest of its content, so a sync of an unchanged repository
writes nothing. A changed one gets new rows under the new id, and the previous
snapshot's rows are deleted after the new head lands. Rows that are only ever
created need no version pin, and rows deleted at version 1 have a pin known in
advance, so refreshing the snapshot never depends on versions from a read. Its bounds — 300 commits, 60k characters per doc, 40 versions of
`TODO.md` and `INDEX.md` — are constants at the top of `arty`.

Schema 1 had a `records` collection projected from the ADRs and changelogs, and
schema 2 a `briefings` collection an agent wrote. The snapshot replaces both: the
first sync at schema 3 deletes those rows.

Rows are never deleted or moved to archive them: `status` flips, and the queries
below are what keep retired rows out of context.

## 4. The briefing

The briefing is **read, not written**. docky already records each piece of work as
a changelog and keeps `docs/TODO.md` current, so `arty sync` extracts it:

| Briefing | Comes from |
|---|---|
| headline, Changed | the newest changelog's title and bullets (`Rationale` bullets drop when the ADR shows) |
| Decided | ADRs committed with that changelog, or carrying its timestamp |
| Closed | TODO items present at the previous changelog and gone now — docky removes finished tasks |
| Blocked | TODO items marked `— blocked: <on what>` (docky's convention), plus open blocking proposals |
| Next then | when stepping back: the top of `TODO.md` as committed with that changelog |

The page steps back through the last 30 changelogs, each with the TODO list as it
stood then. A repository with no changelogs gets one briefing per version-commit
feature on HEAD's line, from its commit subjects. `arty brief [-n N]` prints the
same thing in a terminal.

So **a good briefing is a good changelog**: outcomes, not activity ("the North
Corridor slice is playable end to end", not "worked on the slice"), written when a
change set lands. If 15 commits pass on HEAD's line with no new changelog, sync
lists it as a deviation and the page says so on the briefing.

## 5. Proposals

**Filing one never blocks.** File the row, say in the reply that it is waiting,
state the same assumption the row carries, and carry on with everything that does
not depend on the answer. Prefer filing a proposal *before* building the part it
governs.

- Two to four options, each with its real tradeoff, and mark the recommended one.
  A proposal with one option is a notification, not a decision.
- Put the expensive part in `evidence`: a mermaid graph, a unified diff, the
  numbers. If it needs an interactive page, publish an exhibit and reference it.
- `urgency: blocking` only when work is genuinely stopped, never to hurry a reply.
- Chat first for anything a sentence settles. The console is for calls that need
  looking at.

**Picking up an answer.** At the start of console work:

```
read_db  db_op=query  collection=proposals  query={"where":[["status","eq","answered"]]}
```

For each: implement the choice, honour `answer.notes`, write the ADR with **docky**
(and a changelog entry if the code changed), then flip the row to `accepted` with
`outcome.adr`, `outcome.changelog` and `outcome.acked_at`. An answered row that
stays answered is a dropped decision.

If the answer contradicts what the session assumed, say so plainly and undo the
assumption's work before building on the choice.

Withdraw (`status: withdrawn`, with a one-line reason in `answer.notes`) when the
question stopped mattering. Never silently delete a proposal the user answered.

## 6. Refresh: routine sync, then deviations

Refresh the console **at the end of any session that committed or changed
`docs/`**, and whenever arty is used. The Stop hook (section 7) holds a session
that forgets. The routine part needs no judgement — run it as written:

```
read_db  db_op=list  collection=<proposals|maps|reports>  out_dir=$DUMP
read_db  db_op=get   collection=meta      doc_id=project  out_dir=$DUMP
read_db  db_op=list  collection=snapshot                  out_dir=$DUMP
read_db  db_op=list  collection=<records|briefings>       out_dir=$DUMP   # schema-1/2 consoles only
```
```sh
arty sync  --db "$DUMP" --plan "$PLAN"    # prints the plan, the deviations, then the batches
arty check --db "$DUMP"
```
```
write_db db_op=batch writes=<batch 1>      # then batch 2, ... in order
```

Batches respect write_db's limits (50 entries, 1 MiB) and their order matters:
parts, then the head, then the old snapshot's deletes. An entry reading
`"if_version": "<version from the read>"` takes the version the read reported for
that row; the dumped files don't carry it.

Sync builds the snapshot from git and the working tree's `docs/` (briefings
included), splits it into parts, recomputes each map's staleness as `git log
<commit>..HEAD -- <anchors>` (so the page can name the commits that may have
invalidated it), and records in `.git/arty-synced` what it saw, which is what
`arty due` compares against. It merges, never replaces: authored fields survive.
The page reads the newest head whose parts have all arrived, so it never assembles
half a snapshot.

**Deviations** close sync's output. `deviations: none` means the refresh is done
once the batches are written. Otherwise each line names what is off and the fix:

| Deviation | Fix |
|---|---|
| `pickup` an answered proposal | implement it, ADR it with docky, flip it to `accepted` (section 5) |
| `stale` a map whose anchors moved | refresh the exhibit and re-anchor it, or retire it (section 8) |
| `docs` 15+ commits since the last changelog | write the changelog with docky — it is the briefing |
| `docs` ticked items in `TODO.md` | remove them (docky); the changelog records completion |
| `docs` a TODO or INDEX link to a missing file | repoint it or drop the line (docky) |

`arty check` errors are deviations too. The page shows the `docs` ones under
Attention, so they are visible remotely until fixed.

Dump only to sync. For everything else, query — `{"where":[["status","eq","open"]]}`
for the inbox, `[["status","ne","retired"]]` for the live maps. Never read an
exhibit's body unless the task is about that exhibit.

**Audit** when the console and reality may have drifted: `Artifact action: list`
against the `maps` and `reports` rows. A published artifact with no row is
invisible to the next session — register or delete it. A row whose artifact is gone
is retired.

## 7. The Stop hook

`arty due --hook` makes the refresh hard to forget. It is silent in a repository
without `.arty`, and silent when HEAD and `docs/` match the last sync. Otherwise it
blocks the session's stop once, never twice in a row, with a reason that asks for
the routine refresh and names any `docs` deviations it can already see.
Installed once, in the user's Claude Code settings:

```json
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "~/.claude/skills/arty/arty due --hook"}]}]}}
```

Without the hook, `arty due` prints the same reason and exits 1, for any agent.

## 8. Exhibits — maps and reports

**Map:** a live picture of how something in the code is — architecture, data flow,
performance, state of a migration. One per concern, **updated in place at its own
URL forever**. Staleness is a bug.

**Report:** a dated question and its answer. Immutable. Never refreshed; archived
when the question is settled.

**Inline map:** pictures that need no interactive page of their own -- a gallery
of rendered assets, a set of screenshots -- live in the console itself. Publish the
images as console files under `figures/<map-slug>/` (republish the `arty page`
output with `files`; files left out are kept), and give the row `figures[]` instead
of `url`. The row expands in place; a figure opens full size. Staleness works as for
any map: refresh = regenerate the images, republish those files, update `commit`
and `refreshed_at`. Anything with controls or claims is an exhibit, not an inline
map.

Choosing wrong is what produces redundancy: a new report where a map should have
been refreshed. Before publishing anything, query `maps` and `reports` for the
question already being answered and update that artifact instead.

A map's claims are its payload, so a map **declares `{db: {}, user: {}}` of its
own** and keeps one row per claim in its own `claims` collection:

```
claims/<claim-id>   label, status: verified|unverified|partial|planned,
                    evidence (test, run, file:line), anchors[], updated_at
```

Then confirming something is one `write_db` to the map's URL, not a rewrite of its
HTML — which is the whole reason maps stay current. Never state a claim as fact in
the markup; render it from its row, with the legend visible.

After touching a map, update its console row: `commit` to current HEAD,
`refreshed_at`, and the `claims` rollup counts.

Follow **artifact-design** for the page and **dataviz** for anything plotted.

### Motion and visualization

An exhibit is a review instrument, so prefer a visualization to a description, and a
control to a picture. Reach for motion when it carries what a static frame cannot --
time, sequence, state change, cause -- and leave it alone when it doesn't.

- **Show the mechanism, not the shape.** A lock-free algorithm wants an interleaving
  you can step through; a pipeline wants one packet you can follow; a regression wants
  both traces on one scale. Boxes and arrows are the fallback, not the goal.
- **Scrub, step, toggle -- don't loop.** Understanding needs a control: a step button,
  a timeline slider, a variant switch, a hover that reveals what connects. Animation
  that plays by itself is a video, and nobody can ask a video a question. One ambient
  motion per page, to mark something live, is the exception.
- **Drive it from the rows.** The visualization reads the same `claims` rows the legend
  does, so an unverified path still looks unverified while it moves. Never hard-code a
  state the database owns, and never animate a claim into looking settled.
- **Open at rest, and at a frame worth seeing.** The first paint is the whole story at
  t = 0 -- nothing parked at `opacity: 0` waiting on a scroll, and the control already
  at a position that shows what the exhibit is for.
- **Measured numbers carry their provenance.** A chart's figures name the run they came
  from; a number with no source doesn't go on the page.
- Canvas or WebGL for thousands of marks, generative work, or anything per-frame; SVG
  for structure you want to label, hit-test and theme. Both honour
  `prefers-reduced-motion`: at zero duration every state must still be reachable.

## 9. Archive and ceilings

- Archive by flipping `status` (`retired`, `settled`, `superseded`), never by
  deleting a row. Unpin the artifact. Delete an artifact only when the user says so.
- Ceilings, enforced as warnings by `arty check`: **6** open proposals, **12** live
  maps. Over the line, merge overlapping maps or archive the ones nobody opens —
  don't raise the ceiling.
- A stale map is refreshed or demoted to a dated report. It is never left stale
  with a fresh-looking page.

## 10. Boundaries

- **docky** owns the repository's `docs/` tree and the format of every ADR and
  changelog. arty shows those files on the console and writes nothing under
  `docs/`. The console URL goes in one line at the top of `docs/INDEX.md`.
- **version-commit** numbering is what History groups into features. A repository
  without `[X.Y.Z]` subjects still gets the graph; its feature band is empty and
  Now falls back to the newest changelogs.
- A decision reached in chat is docky's alone; arty only gets involved when the
  question needs a page.
- A project whose own rules forbid a `docs/` tree has no durable home for a decision.
  Say so when accepting a proposal there — don't invent a file the project disallows.

## 11. Commands

`arty` (this directory, Python 3, standard library only, no dependencies). The page
source is `console.html` beside it.

```sh
arty init      --url URL [--name NAME] [--seed PATH]   # .arty pointer + meta/project seed
arty page      [--project NAME]                        # console HTML on stdout
arty sync      --db DUMP --plan DIR [--force]          # snapshot + staleness -> batch plan
arty check     --db DUMP                               # schema, ceilings, dangling anchors
arty brief     [-n N]                                  # the briefing(s) the console shows, in a terminal
arty snapshot  --out FILE                              # the snapshot as one JSON file
arty due       [--hook]                                # is the console behind? (Stop hook)
```

For a local look at the page without claude.ai, put `arty page` output and
`arty snapshot --out snapshot.json` in one directory and serve it: the page reads
`snapshot.json` when no database answers.
