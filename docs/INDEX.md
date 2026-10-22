# Index

- [Console](https://claude.ai/artifact/3w8HNz6wdanyNr3NAmiUMt) — this project's dashboard

## Decisions

- [2026-10-20-1111-decisions-live-in-git](adr/2026-10-20-1111-decisions-live-in-git.md) — git keeps the facts, the console projects them
- [2026-10-20-1114-every-project-keeps-a-docs-tree](adr/2026-10-20-1114-every-project-keeps-a-docs-tree.md) — `docs/` is allowed here, and required wherever there is a console
- [2026-10-20-1112-map-staleness-is-a-commit-range](adr/2026-10-20-1112-map-staleness-is-a-commit-range.md) — a map goes stale by commit range, which names the commits
- [2026-10-21-2323-the-stale-clock-runs-from-git](adr/2026-10-21-2323-the-stale-clock-runs-from-git.md) — staleness is derived, and the 30-day clock counts from the history

## Changes

- [2026-10-20-1116-docs-tree-and-stale-deadline](changelog/2026-10-20-1116-docs-tree-and-stale-deadline.md) — the repository keeps its own decisions; stale maps get 30 days
