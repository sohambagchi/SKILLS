# SKILLS

Personal agent skills. One skill per directory, each loadable alone, all composable.

## Index

| Skill | Description |
|---|---|
| [amail](amail/SKILL.md) | Messages other independent agent instances with AgentMail, a folder of markdown mail files. Uses `/proj` on CloudLab, and `~/amail` elsewhere when the user asks. Includes `amail-tui`, a read-only browser for humans. |
| [docky](docky/SKILL.md) | Maintains a project's `docs/` tree: timestamped ADRs, changelogs and analysis reports, plus TODO, index and a stale archive, kept brief and non-overlapping. |
| [experiment-infrastructure](experiment-infrastructure/SKILL.md) | Builds experiment infrastructure tailored to a project: self-contained timestamped results with provenance, raw-first parsing, validity, resumable runs, safe reuse, and plotting conventions. No framework; each project gets its own. |
| [use-nix](use-nix/SKILL.md) | Uses `flake.nix` whenever possible; if nix is missing, says so and offers the Determinate Systems installer. |
| [version-commit](version-commit/SKILL.md) | Numbers every commit `[X.Y.Z]` in the subject: Z per commit, Y per branch, X on convergence, 1.0.0 at MVP. |
| [caveman](caveman/skills/caveman/SKILL.md) | Upstream submodule ([JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)). Terse output mode; cuts tokens, keeps technical substance. |

## Rules

- **Layout:** `<skill-name>/SKILL.md` plus optional helper scripts (and their `requirements.txt`). Nothing else in a skill directory.
- **No extra docs:** The only markdown outside skill directories is this README. No `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `docs/`, changelogs, notes, or per-skill READMEs.
- **Concise:** A `SKILL.md` has frontmatter (`name`, `description`) and the minimum instructions needed. No background, rationale, or examples unless the skill fails without them.
- **Description shape:** The `description` says in the third person what the skill does, then `Use when <situations>.`, then `Triggers: <phrases a user would say>.` The index entry above reuses the first part.
- **No overlap:** Each skill owns one concern. If two skills would say the same thing, put it in one and reference that skill by name.
- **Composable:** Skills don't assume or contradict each other, so any set can be active together.
- **Index:** Adding, renaming, or removing a skill means updating the table above with a one-line description. Rows are alphabetical, with submodules last. Nothing else changes.
- **Submodules:** Upstream skills (such as `caveman`) are git submodules. Don't edit them here.

## Install

Clone with submodules:

```sh
git clone --recurse-submodules git@github.com:<you>/SKILLS.git ~/dev/SKILLS
```

Symlink the skill directories into each agent's user skill directory:

| Agent | Skill directory |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Pi | `~/.pi/agent/skills/` |
| Codex | `~/.agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` (also reads `~/.claude/skills/`) |

```sh
dest=~/.claude/skills   # pick a directory from the table
mkdir -p "$dest"
for d in ~/dev/SKILLS/*/ ~/dev/SKILLS/caveman/skills/caveman/; do
  [ -f "$d/SKILL.md" ] && ln -sfn "${d%/}" "$dest/$(basename "$d")"
done
```

For a single project, use the project-level directory instead (`.claude/skills/`, `.pi/skills/`, `.agents/skills/`, `.opencode/skills/`).
