#!/bin/sh
# Installs a `claudia` alias: Claude Code with its own config directory, so a
# second account can stay logged in next to the one `claude` uses.
#
#   sh claudia.sh               install (safe to re-run)
#   sh claudia.sh --uninstall   remove the alias; the config directory is kept
#
# CLAUDIA_DIR picks the config directory (default ~/.claudia).
set -eu

dir="${CLAUDIA_DIR:-$HOME/.claudia}"
begin='# >>> claudia >>>'
end='# <<< claudia <<<'
fish_file="$HOME/.config/fish/conf.d/claudia.fish"

mode=install
case "${1:-}" in
  '') ;;
  --uninstall) mode=uninstall ;;
  *) echo "usage: sh claudia.sh [--uninstall]" >&2; exit 2 ;;
esac

# Drops the marked block from an rc file, keeping everything else.
strip_block() {
  tmp="$1.claudia.$$"
  awk -v b="$begin" -v e="$end" '$0==b{s=1;next} $0==e{s=0;next} !s' "$1" >"$tmp"
  cat "$tmp" >"$1"
  rm -f "$tmp"
}

# Bash and zsh files: ones that exist, plus the login shell's own.
rc_files() {
  bash_rc="$HOME/.bashrc"
  [ "$(uname -s)" = Darwin ] && bash_rc="$HOME/.bash_profile"
  for f in "$bash_rc" "$HOME/.zshrc"; do
    [ -e "$f" ] && echo "$f"
  done
  case "$(basename "${SHELL:-}")" in
    bash) [ -e "$bash_rc" ] || echo "$bash_rc" ;;
    zsh) [ -e "$HOME/.zshrc" ] || echo "$HOME/.zshrc" ;;
  esac
}

# A read-only rc (e.g. a home-manager symlink into /nix/store) is reported, not edited.
skipped=
for rc in $(rc_files); do
  if [ -e "$rc" ] && [ ! -w "$rc" ]; then
    skipped="$skipped $rc"
    continue
  fi
  [ -e "$rc" ] && strip_block "$rc"
  if [ "$mode" = install ]; then
    printf '%s\nalias claudia='\''CLAUDE_CONFIG_DIR="%s" command claude'\''\n%s\n' \
      "$begin" "$dir" "$end" >>"$rc"
    echo "claudia: alias added to $rc"
  else
    echo "claudia: alias removed from $rc"
  fi
done

if [ "$(basename "${SHELL:-}")" = fish ] || command -v fish >/dev/null 2>&1; then
  if [ "$mode" = install ]; then
    mkdir -p "$(dirname "$fish_file")"
    # shellcheck disable=SC2016  # $argv is fish's, not ours
    printf 'function claudia --wraps claude\n    env CLAUDE_CONFIG_DIR="%s" claude $argv\nend\n' "$dir" >"$fish_file"
    echo "claudia: function written to $fish_file"
  elif [ -e "$fish_file" ]; then
    rm -f "$fish_file"
    echo "claudia: removed $fish_file"
  fi
fi

for rc in $skipped; do
  if [ "$mode" = install ]; then
    echo "claudia: $rc is read-only (managed elsewhere); add this there instead:" >&2
    echo "  alias claudia='CLAUDE_CONFIG_DIR=\"$dir\" command claude'" >&2
  else
    echo "claudia: $rc is read-only (managed elsewhere); remove the alias there" >&2
  fi
done

[ "$mode" = uninstall ] && { echo "claudia: kept $dir"; exit 0; }

mkdir -p "$dir/skills"
# Links each personal skill `claude` has, so both logins load the same set.
# synced/ holds the account's own claude.ai skills, so each login keeps its own.
linked=0
for s in "$HOME"/.claude/skills/*; do
  name=$(basename "$s")
  [ "$name" = synced ] && continue
  [ -e "$s" ] || continue
  if [ ! -e "$dir/skills/$name" ] && [ ! -L "$dir/skills/$name" ]; then
    ln -s "$s" "$dir/skills/$name"
    linked=$((linked + 1))
  fi
done
echo "claudia: linked $linked skill(s) from ~/.claude/skills into $dir/skills"
command -v claude >/dev/null 2>&1 ||
  echo "claudia: \`claude\` is not on PATH yet; install Claude Code before running claudia" >&2
echo "claudia: open a new shell, run \`claudia\`, then /login with the second account"
