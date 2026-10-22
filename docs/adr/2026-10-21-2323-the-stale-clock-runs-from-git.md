# The stale clock runs from git, not from a sync

**Status:** accepted

**Context:** [A stale map gets 30 days](2026-10-20-1115-stale-map-deadline.md) started the clock at the sync that first saw the map stale, stamping `stale_since` on the row. That makes the snapshot depend on when a sync ran: the same repository syncs to different content, and a repository whose maps nobody has synced in a month has no clock at all.
**Decision:** Staleness is derived, never stored. `arty sync` computes each live map's state into the snapshot, and the deadline counts from the oldest commit that touched the map's anchors since its refresh — `stale_since(row)`, a `git log --reverse` over the same range as [the commit-range signal](2026-10-20-1112-map-staleness-is-a-commit-range.md). The constant is `STALE_WARN_DAYS`.
**Alternatives:** Keeping the stamped field — it is one read instead of a git call, but it makes a sync's output clock-dependent. Counting from the map's last refresh — a map refreshed long before anything touched it would be overdue on arrival.
**Consequences:** Map rows lose `status: stale`, `stale_since` and `invalidated_by`; schema 4's sync writes nothing an agent or the page owns, and the console falls back to the old row fields only until a schema-4 snapshot covers a map. The deadline needs no sync to have run — it is a property of the history.
