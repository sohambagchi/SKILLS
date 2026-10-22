# Decisions live in git; the console projects them

**Status:** accepted

**Context:** Proposals, answers and briefings exist on a hosted artifact; the project's history must not depend on it. Decided on console proposal `p-20261012-1905-decision-home`.
**Decision:** git keeps the facts — ADRs, changelogs, code. The console shows them, plus what git cannot hold: waiting proposals, map staleness, per-claim confidence.
**Alternatives:** The console as the record — the history would then live on a page outside version control.
**Consequences:** Every accepted proposal gets an ADR ([docs tree](2026-10-20-1114-every-project-keeps-a-docs-tree.md)); snapshots on the console are computed, never retyped, and never read back as source.
