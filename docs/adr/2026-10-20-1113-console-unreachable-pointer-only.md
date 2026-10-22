# An unreachable console degrades to the pointer

**Status:** accepted

**Context:** A session may not reach the console artifact. Decided on console proposal `p-20261012-1915-degraded-mode`.
**Decision:** Say so and carry on from `.arty` alone. Live state is never mirrored into the repository as a fallback cache.
**Alternatives:** Mirroring rows into git — two homes for one fact, and the mirror goes stale silently.
**Consequences:** Work proceeds without the inbox; the refresh happens on the next session that can reach the page.
