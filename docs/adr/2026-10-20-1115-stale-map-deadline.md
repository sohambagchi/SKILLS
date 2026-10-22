# A stale map gets 30 days

**Status:** superseded by [2026-10-21-2323-the-stale-clock-runs-from-git](2026-10-21-2323-the-stale-clock-runs-from-git.md)

**Context:** A stale map should be refreshed or demoted, but nothing said when. Decided on console proposal `p-20261012-1925-stale-deadline`.
**Decision:** `arty check` escalates a map stale for more than 30 days from a line in its report to a warning naming it. `stale_since` is stamped by the sync that first sees it stale, so the clock starts then.
**Alternatives:** Automatic demotion to a dated report at 90 days — a map you were about to refresh can be retired under you. No deadline — exactly how maps went stale before the skill existed.
**Consequences:** Pressure without surprise: nothing is rewritten, retired or archived without a person. The deadline is one constant, `STALE_DEADLINE_DAYS` in `arty/arty`.
