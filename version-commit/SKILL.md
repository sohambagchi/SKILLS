---
name: version-commit
description: >
  Numbers every commit [X.Y.Z] in the subject line: Z per commit, Y per branch,
  X on convergence, 1.0.0 at MVP. Use when committing, starting a branch for a
  feature or larger issue, or deciding the next version number. Triggers:
  /version-commit, "commit this", "start a branch", "what version is this".
---

# version-commit

Every commit subject starts with its version: `[X.Y.Z] <summary>`. X, Y, Z are integers ≥ 0. No `v` prefix, no suffixes, no pre-release tags.

## Current version

```sh
git log -1 --format=%s                                    # this branch's latest
git log --all --format=%s | grep -oE '^\[[0-9]+\.[0-9]+\.[0-9]+\]' | sort -uV  # every version ever used
```

Use the second when choosing a new branch's Y, so an abandoned branch's Y is never reused.

## Choosing the number

| Situation | Version |
|---|---|
| First commit of a project | `0.0.0` |
| Another commit on the current branch | bump Z |
| A minor one-step fix — too small for a branch | bump Z on the current branch |
| First commit of a new branch | lowest unused Y for the current X, Z = 0 |
| MVP — central logic working end-to-end | `1.0.0` |
| A significant number of Y branches converged | bump X, Y = Z = 0 |

- A branch owns one value of Y for its whole life. Every commit on it shares that Y and differs only in Z.
- Y and Z reset to 0 only when X increments.
- X increments when several Y values have converged: issues fixed, features implemented and integrated, tested, and wired into scripts where required. Merging alone is not convergence.
- Never renumber an existing commit. If a number was wrong, carry on from the next one.

## Branching

A new feature or a larger issue gets its own branch. Create it and commit immediately, before any work — that commit fixes the branch's Y.

Not everything earns a branch. A minor fix done in one step — a typo, a one-line correction, a small doc edit — stays on the current branch and just bumps Z. Don't spend a Y on it.

```sh
git switch -c <branch>
git commit --allow-empty -m "[X.Y.0] Start <branch>: <what it will do>"
```

## Commit message

```
[X.Y.Z] <imperative summary, ≤ 72 chars>

<body: what changed, and why if the summary doesn't say it>
```

- One coherent change per commit. Don't bundle unrelated work to save a Z.
- If the project declares its own version (`package.json`, `pyproject.toml`, `Cargo.toml`, `VERSION`), set it to the same X.Y.Z in the same commit.
- Commit only when the user asks.
