---
name: code-comments
description: >
  Decides what code needs a comment, what doesn't, how long the comment should
  be, and when an explanation is too big for a comment and belongs in a document
  instead. Use when writing or reviewing comments and docstrings, when a piece of
  code is hard to explain, or when comments have gone stale. Triggers:
  /code-comments, "comment this", "add docstrings", "is this comment needed",
  "document this function", "explain this code".
---

# code-comments

The default is no comment. Code states what happens; a comment exists only to supply what the code cannot state. Every comment is a second thing to keep true, so it must earn that cost.

Before writing one, try to make it unnecessary: rename the variable, extract the expression into a named function, split the branch. A comment is the fallback when the knowledge lives outside the code.

## Comment these

Write a comment when a competent reader of this codebase would otherwise stop and ask:

- **Why this and not the obvious thing.** A deliberate deviation from the straightforward implementation — a workaround, a performance trade-off, an ordering that matters.
- **External constraints.** Hardware behavior, a spec or RFC clause, a protocol quirk, a bug in a dependency. Cite it: version, section, issue URL.
- **Non-local coupling.** This code must stay in sync with something the reader cannot see from here. Name the other file or symbol.
- **Non-obvious invariants and preconditions.** What must hold on entry, what holds on exit, what the caller owns, what is not thread-safe, what may block.
- **Units, ranges, encodings, ownership.** Whenever the type doesn't carry them and the name can't.
- **Derivations.** A magic constant, a formula, a bound: where the number came from.
- **Deliberate empties.** An empty catch, an intentional fallthrough, a no-op branch — say it's intended and why.
- **Public API surface.** A docstring on anything callers outside the module use: purpose, parameters that aren't self-evident, return, errors raised. Follow the language's convention and whatever the file already does.

## Don't comment these

- Restatements of the code (`// increment i`, `# loop over users`).
- Names that are already the comment (`// the user ID` above `user_id`).
- Section banners and decorative separators inside a function; that's a sign to split the function.
- History: what changed, when, by whom, or what the code used to be. That's git, and — if it matters — a changelog.
- Commented-out code. Delete it.
- Bare `TODO`/`FIXME` with no follow-through. Either fix it, or record the task with `docky` and make the comment a pointer to it.
- Anything only true right now (a value that will change, a "temporary" note).

## No redundancy

Say each thing once, in one place. A comment carries only what isn't already stated by the code, its name, its type, or a comment above it.

- Don't repeat the function name, signature, parameter types, or default values in its docstring. Describe only what they don't say.
- Don't restate an enclosing comment, file header, or docstring inside the body it covers. The inner comment adds the local detail or is deleted.
- Don't say the same thing at two rungs of the ladder below; the higher rung owns it and the lower one stays silent.
- Don't copy a document's reasoning inline. The pointer plus one sentence is the whole inline share.
- Don't explain the same constraint at each of its call sites. Put it where the constraint lives and point at that symbol.
- Two comments that would say the same thing mean the region needs one comment higher up, not two.

## How long

Pick the smallest rung that carries the reason.

| Rung | Use for | Length |
|---|---|---|
| Trailing comment | A unit, a bound, a single surprising token | ≤ 1 short clause |
| One line above the statement | One local why | 1 line |
| Short block above a function or branch | A precondition set, an invariant, a workaround with its cause | 2–5 lines |
| Docstring | Public API contract | Convention of the language, no prose padding |
| File or module header | What this file owns and how it relates to its siblings | ≤ 10 lines |
| Document (`docky`) | Anything larger — see below | Not in the source |

Rules that apply at every rung: full sentences, present tense, describe current behavior, no hedging or apology, wrap to the file's existing width.

## When it becomes a document

Escalate out of the source as soon as any of these is true. Write the document with `docky`, then leave a one-line comment pointing at it.

- The explanation would exceed roughly 10 lines, or needs headings, a list of alternatives, a diagram, or a table.
- It spans more than one file, and no single file is its natural home.
- It records a **decision** — alternatives considered and rejected. That is an ADR, never a comment.
- It explains a subsystem, protocol, data format, or workflow rather than a piece of code.
- It is an investigation or measurement (a benchmark, a bug hunt) rather than a property of the code.
- It ages on a different clock than the code around it.

Then in the source:

```
// Ring buffer indices are packed; see docs/adr/2026-09-22-1130-packed-indices.md
```

- One pointer at the entry point of the region, not on every function in it.
- Relative path from the repo root, so it survives moves.
- The comment keeps the one-sentence summary; the document keeps the argument. Don't duplicate the document's reasoning inline.
- If the code moves or the document is superseded, fix the pointer in the same change.

## Maintenance

- Changing code means re-reading the comments it sits under. A comment that no longer describes the code is worse than no comment — correct it or delete it in the same commit.
- Deleting code deletes its comments and any pointer that now dangles.
- When reviewing, flag a comment that restates code as removable, and a surprising line with no comment as a missing one.
