---
name: docky
description: >
  Maintains a project's docs/ tree: timestamped ADRs and changelogs, TODO.md,
  INDEX.md, analysis reports, and a stale/ archive, kept brief and
  non-overlapping. Use when recording a decision or change, updating open tasks,
  filing a requested analysis report, setting up project docs, or cleaning up
  sprawling markdown. Triggers: /docky, "document this", "write an ADR", "update
  the changelog", "add a todo", "write up this analysis".
---

# docky

## Layout

```
docs/
  INDEX.md            pointers to significant ADRs/changelogs
  TODO.md             open tasks
  adr/                decision records
  changelog/          change records
  todo/               detail files for large tasks (rare)
  analysis-artifacts/ reports for user-requested analyses
  stale/              outdated docs kept for history
```

Create any missing piece on first use. Don't add other files or directories under `docs/`.

Every project keeps this tree. A repository whose own rules forbid markdown outside
some directory relaxes them for `docs/` rather than going without: a decision with
no `docs/adr/` entry has no durable home, and a hosted console is a projection, not
a record.

Timestamped filenames: `YYYY-MM-DD-HHMM-<kebab-slug>.md`, time from `date +%Y-%m-%d-%H%M`. Never rename a timestamped file.

## Rules

1. **Brevity.** Bullets over prose. No filler, no restating code, no headings for one line of content.
2. **One home per fact.** Before writing, check whether it already exists. Link instead of repeating.
3. **Link by filename.** Relative markdown links, e.g. `[2026-09-17-1402-cache-layer](../adr/2026-09-17-1402-cache-layer.md)`.

## ADRs — `docs/adr/`

Write one when a choice was made between alternatives, or a constraint was adopted, that a future reader would otherwise question. Not for routine changes.

```markdown
# <Decision title>

**Status:** accepted | superseded by [<file>](...)

**Context:** <why a decision was needed, 1–3 lines>
**Decision:** <what was chosen>
**Alternatives:** <option — why rejected> (omit if none)
**Consequences:** <what this commits us to>
```

ADRs are immutable apart from `Status`. To change a decision, write a new ADR and mark the old one superseded.

## Changelogs — `docs/changelog/`

One file per coherent change set (feature, fix, refactor, session of work). Say what changed, not why. If an ADR covers the reasoning, the entry is just a pointer. Lead with outcomes ("the slice is playable end to end", not "worked on the slice"): where an arty console exists, the newest changelog is its briefing.

```markdown
# <Change title>

- <what changed, user- or developer-visible>
- <...>
- Rationale: see ADR [<file>](../adr/<file>)
```

## TODO — `docs/TODO.md`

```markdown
# TODO

- [ ] <task, one line>
- [ ] <task> — details: [<file>](todo/<file>)
- [ ] <task> — blocked: <what or who it waits on>
```

- Remove finished tasks. The changelog records completion, so don't keep checked items.
- Mark a task that can't move with `— blocked: <on what>` at the end of its line, and drop the marker when it unblocks.
- Only create a `docs/todo/<timestamp>-<slug>.md` file if the task can't be captured in a few lines (multi-step plan, specs, repro steps). Default to no detail file.
- Delete a detail file when its task is done. Move any decision it contains into an ADR first.

### Board

A `TODO.md` whose `##` headings are all column names is a kanban board, and the
arty console draws it as one. Convert a flat list only when the user asks.

```markdown
# TODO

## Doing
- [ ] Fix: <task> #<area> — stages: edit, [test]

## Review
- [ ] <task> +<epic> — details: [<file>](todo/<file>)
  - [x] <subtask>
  - [ ] <subtask>

## Next
- [ ] Benchmark: <task> #<area> +<epic> — stages: dev, rebuild, measure — blocked: <other card's text>

## Backlog
- [ ] Investigate: <task>
```

| Column | A card goes here when |
|---|---|
| Doing | work on it has started. At most 3 cards. |
| Review | it is built and waits on the user's check: a playthrough, a measurement, a read. |
| Next | it is committed work. Top of the column = next to start. |
| Backlog | it is an idea, a someday, or a gap nobody has committed to. |

- Write the columns in that order. An empty column's heading may stay or go; any other `##` heading turns the board back into a list.
- Move a card by moving its line — keep its text, so the console can tell how long it has sat in a column.
- Starting work moves the card to Doing. Finishing it removes the card, closed as its category says (below); finishing work the user must check moves it to Review instead. Review cards leave when the user confirms.
- A new task goes to Backlog unless the user committed to it, then Next.
- Over 3 cards in Doing, or a card stuck 14+ days in Doing (in its current stage, when it has stages), is untidy: move it back to Next, split it, or mark what blocks it.

**A card's line**, everything but the task optional:

```
- [ ] [Category: ]<task> [#area ...] [+epic] [— stages: ...] [— details: <link>] [— blocked: <on what>]
```

- **Category** — at most one, as the first word: `Feature`, `Fix`, `Investigate`, `Evaluate`, `Benchmark`, `Refactor`, `Deprecate`. Any other leading word is just text. Set it when the kind of work is clear. It decides how the card closes:

  | Category | Closes with |
  |---|---|
  | Feature, Fix, Refactor | a changelog bullet |
  | Investigate | the answer: an analysis report when it needs one (the card on the board counts as the user's ask), else a changelog bullet |
  | Evaluate | an ADR recording the choice |
  | Benchmark | the numbers: a report or arty map, linked from a changelog bullet |
  | Deprecate | a changelog bullet for the removal; superseded docs move to `stale/` |

- **Stages** — how big the card is, as the steps it must go through, in order: `— stages: dev, rebuild, test, measure`. Use the project's own words for steps that take a long time, so a long rebuild or measurement run can be seen before it starts: `edit` (a small change), `dev`, `rebuild`, `test`, `measure`, or whatever the project needs. Size a card by its stages, never in hours or days. While the card is in Doing, put the current stage in brackets, `dev, [rebuild], test`, and move the brackets as each stage finishes. A card with no brackets hasn't started. Steps that take a long time are named in `.arty` (`long_stages = rebuild, measure`) and drawn as such on the console.
- **Area tags** — `#area`, lowercase, any number. They group by part of the project and replace topical sections.
- **Epic** — `+epic`, one per card, for cards that each move through the columns on their own but belong to one larger piece of work. The console shows each epic's progress across the columns.
- **Subtasks** — checkboxes indented under a card, for steps that never need their own column. They move with the card. Tick them as they finish (the one exception to "remove finished items"), and they leave with the card.
- **Blocked on another card** — write the start of that card's text (`— blocked: Act-mood post-process`) and the console links the two.
- Use a subtask when the step can't move by itself, and an epic when it can. Don't nest cards deeper than that.
- Converting a flat list: committed items go to Next in their existing order, the rest to Backlog, and anything awaiting the user to Review. Sections become area tags, and a leading verb that is a category becomes one.

## Analysis artifacts — `docs/analysis-artifacts/`

Markdown reports for complex analyses **the user asked for**: an investigation of some specific behavior, or a study of a region of the code.

Not a dumping ground. Don't file incidental findings here — a debugging note on why `nix` won't build, a summary of work just done, a self-directed audit. Those belong in the reply, or in a changelog/ADR if they changed the project.

- Timestamped filename, same format as ADRs and changelogs.
- Lead with the question asked and the answer. Findings before evidence.
- Decisions that come out of a report go in an ADR; the report is a pointer's worth of context, not the decision record.
- For an analysis published as a page on claude.ai, keep the question, the answer and the
  artifact URL here, and nothing else — the page is registered as an exhibit by **arty**.
  Don't mirror the page's content into this directory.
- Reports worth returning to get a line in `INDEX.md` under `## Analysis`.
- Prunable and stale-able like any other doc: whenever docky runs, drop reports whose question is settled and no longer referenced, and move ones the code has outgrown to `docs/stale/`.

## Index — `docs/INDEX.md`

If the project has a console (a tracked `.arty` pointer), its link is the first line of the file.

One line per entry: link plus a short phrase. Most files never appear here — only the ones that shaped the project (architecture, major features, breaking changes) or that a reader would go looking for. Prune links that are no longer significant.

Analysis artifacts come first, before the decision and change history:

```markdown
# Index

## Analysis

- [<file>](analysis-artifacts/<file>) — <question the report answers>

## Decisions

- [<file>](adr/<file>) — <what was decided>

## Changes

- [<file>](changelog/<file>) — <what changed>
```

Omit a section while it has no entries.

## Stale — `docs/stale/`

- Never create a new file here. Only move existing docs (`git mv` if tracked) whose content is no longer accurate but still has historical value.
- A moved file may be rewritten or condensed. Add a first line: `> Stale since YYYY-MM-DD. Current: <link or "none">.`
- Update every link that pointed at the old path, and drop it from `INDEX.md` unless it is still historically significant.
- Superseded ADRs stay in `adr/`. Don't move them here.

## Markdown sprawl check

Run this whenever docky is used. Count the project's markdown files, excluding:
- everything this skill manages (`docs/INDEX.md`, `docs/TODO.md`, `docs/adr/`, `docs/changelog/`, `docs/todo/`, `docs/analysis-artifacts/`, `docs/stale/`)
- the root `README.md` and agent instruction files (`CLAUDE.md`, `AGENTS.md`, `SKILL.md`, ...)
- vendored, generated, or dependency directories and git submodules

```sh
git ls-files '*.md' | grep -vE '^docs/(INDEX|TODO)\.md$|^docs/(adr|changelog|todo|analysis-artifacts|stale)/|(^|/)(CLAUDE|AGENTS|SKILL)\.md$|^README\.md$'
```

If more than 10 remain:
- Merge overlapping ones into the doc that should own each fact.
- Turn decision content into ADRs and history into changelogs.
- Move outdated ones to `docs/stale/`.
- Propose the plan to the user before moving or merging anything.
