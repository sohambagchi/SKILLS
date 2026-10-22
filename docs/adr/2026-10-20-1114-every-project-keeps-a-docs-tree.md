# Every project keeps a docs tree

**Status:** accepted

**Context:** This repository's rules allowed no markdown outside skill directories, so docky could not exist here and four accepted decisions had no ADR. Decided on console proposal `p-20261012-1920-no-docs-repos`.
**Decision:** Relax the rule for docky's `docs/` tree rather than go without. A repository with a console keeps it, whatever else its rules say about markdown.
**Alternatives:** The console as the home of a decision in such a repository — it contradicts [decisions live in git](2026-10-20-1111-decisions-live-in-git.md). A decisions section in `README.md` — keeps the rule, but grows a changelog the README was not meant to carry.
**Consequences:** `README.md` names `docs/` as allowed; docky and arty both state the requirement; `arty check`'s "accepted without an ADR" warning stands everywhere, with no exemption for repositories that forbid a docs tree.
