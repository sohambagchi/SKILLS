---
name: use-nix
description: >
  Uses a flake.nix for project dependencies, dev shells, and builds whenever
  possible. Use when setting up a project, adding tooling or dependencies, or
  running builds. Triggers: /use-nix, "nix", "flake", "dev shell".
---

# use-nix

1. Check for nix: `command -v nix`.
2. If nix is missing, tell the user nix isn't available on this machine and offer to install it with:
   ```sh
   curl -fsSL https://install.determinate.systems/nix | sh -s -- install
   ```
   Run it only if the user agrees.
3. If nix is available, use `flake.nix` whenever possible: declare dependencies and tooling there, and run commands through `nix develop`, `nix build`, or `nix run` instead of installing packages globally.
4. For one-off runs that need specific tools or packages, use `nix-shell -p <pkgs> --run '<cmd>'` instead.
