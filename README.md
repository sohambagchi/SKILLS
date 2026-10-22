# SKILLS

Personal agent skills. One skill per directory, each loadable alone, all composable.

## Index

| Skill | Description |
|---|---|
| [amail](amail/SKILL.md) | Messages other independent agent instances with AgentMail, a folder of markdown mail files. Uses `/proj` on CloudLab, and `~/amail` elsewhere when the user asks. Includes `amail-tui`, a read-only browser for humans. |
| [arty](arty/SKILL.md) | Maintains a project console: one claude.ai artifact per project that works as a remote dashboard: a briefing read from docky's newest changelog, the TODO list, every docky document, a navigable git graph of features and merges, the decision inbox, and live maps and reports. Includes `arty`, which snapshots git and `docs/`, owns the schema and the page, and has a Stop hook that flags a stale console. Refreshes are routine; an agent's judgement is needed only for the deviations `arty sync` reports. |
| [asm-analysis](asm-analysis/SKILL.md) | Standardizes a cross-variant workspace that puts N programs side by side in two aligned rows — authored source on top, generated code below — with a portable bundle format, a git-tracked annotation store, and workflows for extracting the mapping, chunking the corpus for annotation, and keeping both current. Includes `asmviz`, a validator and reference viewer. |
| [code-comments](code-comments/SKILL.md) | Decides what code needs a comment, what doesn't, how long the comment should be, and when an explanation is too big for a comment and belongs in a document instead. |
| [docky](docky/SKILL.md) | Maintains a project's `docs/` tree: timestamped ADRs, changelogs and analysis reports, plus TODO, index and a stale archive, kept brief and non-overlapping. |
| [experiment-infrastructure](experiment-infrastructure/SKILL.md) | Builds experiment infrastructure tailored to a project: self-contained timestamped results with provenance, raw-first parsing, validity, resumable runs, safe reuse, and plotting conventions. No framework; each project gets its own. |
| [use-nix](use-nix/SKILL.md) | Uses `flake.nix` whenever possible; if nix is missing, says so and offers the Determinate Systems installer. |
| [version-commit](version-commit/SKILL.md) | Numbers every commit `[X.Y.Z]` in the subject: Z per commit, Y per branch, X on convergence, 1.0.0 at MVP. |
| [caveman](caveman/skills/caveman/SKILL.md) | Upstream submodule ([JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)). Terse output mode; cuts tokens, keeps technical substance. |

## Rules

- **Layout:** `<skill-name>/SKILL.md` plus optional helper scripts (and their `requirements.txt`). Nothing else in a skill directory.
- **No extra docs:** Outside skill directories, the only markdown is this README and the `docs/` tree **docky** owns — every project keeps one so decisions have a durable home in git ([ADR](docs/adr/2026-10-20-1114-every-project-keeps-a-docs-tree.md)). No `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, loose notes, or per-skill READMEs.
- **Concise:** A `SKILL.md` has frontmatter (`name`, `description`) and the minimum instructions needed. No background, rationale, or examples unless the skill fails without them.
- **Description shape:** The `description` says in the third person what the skill does, then `Use when <situations>.`, then `Triggers: <phrases a user would say>.` The index entry above reuses the first part.
- **No overlap:** Each skill owns one concern. If two skills would say the same thing, put it in one and reference that skill by name.
- **Composable:** Skills don't assume or contradict each other, so any set can be active together.
- **Index:** Adding, renaming, or removing a skill means updating the table above with a one-line description. Rows are alphabetical, with submodules last. Nothing else changes.
- **Submodules:** Upstream skills (such as `caveman`) are git submodules. Don't edit them here.

## Install

Clone with submodules:

```sh
git clone --recurse-submodules git@github.com:sohambagchi/SKILLS.git ~/dev/SKILLS
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

### Second Claude Code login

`claudia.sh` adds a `claudia` alias (bash, zsh, fish) that runs `claude` with its own config directory, `~/.claudia`, so a second account stays logged in alongside the first. Rerunning it is safe, and `--uninstall` removes the alias.

```sh
sh ~/dev/SKILLS/claudia.sh
# or, without a clone:
curl -fsSL https://raw.githubusercontent.com/sohambagchi/SKILLS/main/claudia.sh | sh
```

Then open a new shell, run `claudia`, and `/login`. Set `CLAUDIA_DIR` to use a different directory. The script also links every skill in `~/.claude/skills/` into `~/.claudia/skills/`, so both logins load the same skills; rerun it after adding a skill. Each account's own claude.ai skills (`synced/`) stay separate.
