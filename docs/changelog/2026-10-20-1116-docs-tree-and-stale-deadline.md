# The repository keeps its own decisions, and stale maps have a deadline

- `docs/` exists here: the six decisions the console had accepted now have ADRs, so none of them lives only on a hosted page.
- `README.md` allows docky's `docs/` tree; docky and arty both say every project keeps one.
- `arty check` names a map stale for more than 30 days in a warning as well as the summary line. The clock runs from the oldest commit that touched the map's anchors, so it needs no sync to have run.
- docky and arty are installed for both Claude Code logins (`claude` and `claudia`), each with arty's Stop hook.
- Rationale: see ADRs [every project keeps a docs tree](../adr/2026-10-20-1114-every-project-keeps-a-docs-tree.md) and [a stale map gets 30 days](../adr/2026-10-20-1115-stale-map-deadline.md)
