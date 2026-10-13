---
name: arty
description: >
  Maintains a project console: one claude.ai artifact per project holding the
  decision inbox, the live maps of the code with per-claim confidence, dated
  reports, and a timeline projected from the project's ADRs and changelogs. Use
  when a decision needs figures, diffs or numbers rather than a chat question,
  when publishing or refreshing a visual artifact about the code, when checking
  whether a map has gone stale, or when picking up an answer left on the
  console. Triggers: /arty, "put it on the console", "this needs a decision",
  "is that diagram still right", "publish this as an artifact", "what's waiting
  for me", "what's stale".
---

# arty

**git keeps facts, the console keeps state.** Decisions, changes and code live in
the repository. Proposals awaiting judgement, map staleness, per-claim confidence
and the archive live in the console database. Neither one holds the other's
content.

The console exists for the **proposal**: a judgement call too big for a chat
question, because it needs a diagram, a diff or measured numbers. It is filed as
a row, answered on the page from any device at any time, and picked up by
whatever session runs next. Simple decisions stay in the chat.

## 1. Layout

```
.arty                 tracked pointer: console = <url>, project, schema, docs paths
<console artifact>    one per project: inbox, maps, reports, timeline
<exhibit artifacts>   the heavy visuals, registered as rows in the console
```

Read `.arty` first. No pointer means no console — offer section 2, don't invent one.
The pointer is the only thing arty adds to the repository: live state is never
mirrored into git, and the console is never the home of an ADR.

Sync reads records from docky's `docs/adr/`, `docs/changelog/` and `docs/stale/`.
A repository laid out otherwise names its own in `.arty`, one optional line each:

```
adr_dir = docs/ADR
changelog_dir = docs/changelog
stale_dir = docs/archive
```

A named directory that does not exist stops sync; it never reads as zero records.
An ADR's status is the first word of its `**Status:**` line, bare or as a list item
(`superseded` and `reversed` both show as superseded; `Accepted; amended by …` stays
accepted). Its summary is the `**Decision:**` line, else the first paragraph or item
under `## Decision`.

## 2. Setup

```sh
arty page --project "<Project>" > "$SCRATCH/console.html"
```

Publish it with `capabilities: {db: {}, user: {}}`, title `<Project> Console`,
favicon 🛎️ (every console carries the same one). Then:

```sh
arty init --url <console-url>        # writes .arty and the meta/project seed
```

`write_db` the seed to `meta/project`, run a sync (section 6), commit `.arty`, and
offer to pin the console. One console per repository, forever — a second one
splits the inbox.

## 3. Schema

The schema is the contract. The page is generic: every project-specific fact is a
value in the database, never a branch in the page. `arty check` enforces this
section.

```
meta/project                   project, schema, remote, created, head

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
  title, purpose, url
  anchors[]      pathspecs the map describes       (required)
  commit         HEAD when it was last refreshed
  refreshed_at
  status         current | stale | retired
  claims         {verified, unverified, partial, planned}   rollup, derived
  invalidated_by[{commit, subject}], invalidated_count, checked_at   by sync

reports/r-YYYYMMDD-slug
  title, question, answer, date, anchors[]
  status         current | settled | stale
  url            the exhibit, or `markdown` for a report that needs no page
  path           docs/analysis-artifacts/<file> when docky holds the written report

records/adr-<stamp>-slug, records/chg-<stamp>-slug
  kind, title, date, time, status, summary, path    projected from git by sync
  proposal, exhibits[]                              authored, sync never touches
```

Rows are never deleted or moved to archive them: `status` flips, and the queries
below are what keep retired rows out of context.

## 4. Proposals

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

## 5. Exhibits — maps and reports

**Map:** a live picture of how something in the code is — architecture, data flow,
performance, state of a migration. One per concern, **updated in place at its own
URL forever**. Staleness is a bug.

**Report:** a dated question and its answer. Immutable. Never refreshed; archived
when the question is settled.

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

## 6. Sync and audit

Run a sync whenever arty is used:

```
read_db  db_op=list  collection=<proposals|maps|reports|records>  out_dir=$DUMP
read_db  db_op=get   collection=meta  doc_id=project               out_dir=$DUMP
```
```sh
arty sync  --db "$DUMP" --plan "$PLAN"    # prints a batch of {op, collection, doc_id, file_path}
arty check --db "$DUMP"
```
```
write_db db_op=batch writes=<the entries sync printed>
```

Sync projects the ADR and changelog directories (section 1) into `records`, and
prints how many files it read from each and which it skipped. It recomputes each
map's staleness as `git log <commit>..HEAD -- <anchors>` — so the page can name the
commits that may have invalidated it. It merges, never replaces: authored fields
survive.

Dump only to sync. For everything else, query — `{"where":[["status","eq","open"]]}`
for the inbox, `[["status","ne","retired"]]` for the live maps. Never read an
exhibit's body unless the task is about that exhibit.

**Audit** when the console and reality may have drifted: `Artifact action: list`
against the `maps` and `reports` rows. A published artifact with no row is
invisible to the next session — register or delete it. A row whose artifact is gone
is retired.

## 7. Archive and ceilings

- Archive by flipping `status` (`retired`, `settled`, `superseded`), never by
  deleting a row. Unpin the artifact. Delete an artifact only when the user says so.
- Ceilings, enforced as warnings by `arty check`: **6** open proposals, **12** live
  maps. Over the line, merge overlapping maps or archive the ones nobody opens —
  don't raise the ceiling.
- A stale map is refreshed or demoted to a dated report. It is never left stale
  with a fresh-looking page.

## 8. Boundaries

- **docky** owns the repository's `docs/` tree and the format of every ADR and
  changelog. arty projects those files into the console and writes nothing under
  `docs/`. The console URL goes in one line at the top of `docs/INDEX.md`.
- A decision reached in chat is docky's alone; arty only gets involved when the
  question needs a page.
- A project whose own rules forbid a `docs/` tree has no durable home for a decision.
  Say so when accepting a proposal there — don't invent a file the project disallows.

## 9. Commands

`arty` (this directory, Python 3, standard library only, no dependencies):

```sh
arty init  --url URL [--name NAME] [--seed PATH]   # .arty pointer + meta/project seed
arty page  [--project NAME]                        # console HTML on stdout
arty sync  --db DUMP --plan DIR                    # records projection + staleness plan
arty check --db DUMP                               # schema, ceilings, dangling anchors
```
