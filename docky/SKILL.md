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

One file per coherent change set (feature, fix, refactor, session of work). Say what changed, not why. If an ADR covers the reasoning, the entry is just a pointer.

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
```

- Remove finished tasks. The changelog records completion, so don't keep checked items.
- Only create a `docs/todo/<timestamp>-<slug>.md` file if the task can't be captured in a few lines (multi-step plan, specs, repro steps). Default to no detail file.
- Delete a detail file when its task is done. Move any decision it contains into an ADR first.

## Analysis artifacts — `docs/analysis-artifacts/`

Markdown reports for complex analyses **the user asked for**: an investigation of some specific behavior, or a study of a region of the code.

Not a dumping ground. Don't file incidental findings here — a debugging note on why `nix` won't build, a summary of work just done, a self-directed audit. Those belong in the reply, or in a changelog/ADR if they changed the project.

- Timestamped filename, same format as ADRs and changelogs.
- Lead with the question asked and the answer. Findings before evidence.
- Decisions that come out of a report go in an ADR; the report is a pointer's worth of context, not the decision record.
- For an analysis published as an artifact on claude.ai, keep a markdown copy here with the artifact URL on the first line.
- Reports worth returning to get a line in `INDEX.md` under `## Analysis`.
- Prunable and stale-able like any other doc: whenever docky runs, drop reports whose question is settled and no longer referenced, and move ones the code has outgrown to `docs/stale/`.

## Index — `docs/INDEX.md`

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
