# A map goes stale by commit range

**Status:** accepted

**Context:** A map needs a mechanical staleness signal against the code it describes. Decided on console proposal `p-20261012-1910-staleness-signal`.
**Decision:** `git log <map.commit>..HEAD -- <anchors>`. A non-empty range flips the map to `stale` and records the commits that may have invalidated it.
**Alternatives:** A content digest — cheaper, but it cannot name the commits, and naming them is what makes the flag actionable.
**Consequences:** Every map carries `anchors[]` and `commit`; an occasional no-op flag (a commit that touched an anchor without changing the picture) is accepted as the cost.
