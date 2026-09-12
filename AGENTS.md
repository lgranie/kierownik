# Kierownik - Agent Guidelines

BlueBuild/Fedora bootc OS config. Immutable container-native OS; changes require rebuild.

## Build

```bash
mise run check [--fix]                # validate/lint, no build
mise run build:oci N100|8745|5290     # N100=headless, 8745=Hyprland AMD, 5290=Hyprland Intel
mise run build:iso|build:qcow2 5290
mise run run:vm|run:iso 5290
mise run build:wsl
mise run wp:build [--event push]      # local Woodpecker run
bluebuild build recipes/krw-5290.yml
```

CI: `.github/workflows/build.yml` + `.woodpecker/build.yml`. GHA uses `blue-build/github-action@v1.12`, matrix `krw-5290.yml` + `krw-8745.yml`, schedule Sat 07:00 UTC, push (ignore `**.md`), PR, dispatch.

## Shell

- `#!/usr/bin/env bash`, `set -oue pipefail`, validate inputs, sparse `|| true`.
- User interaction in `.mise/tasks/`, `files/**/tasks/*` via `gum`, never `echo`/`read -p`: `gum log -sl info|warn|error`, `gum style --border thick`, `gum input|choose|confirm|filter`, verbatim `gum style "${var}"`. Plumbing `echo` stays (pipes, redirects, `> /sys/...`, `echo $?`).
- `gum` from `.mise/config.toml` + `recipes/base/tools.yml`. No `gum` in `files/scripts/finalize/` (pre-install build time).

## Recipes

- Line 1 schema required: `# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json`
- dnf: `install-weak-deps: false`. files: relative `source:`, `destination: /`.
- Top-level `recipes/krw-*.yml`; modules in `recipes/{base,cpu,wm,wsl,llm,finalize}/`. Overlays in `files/{base,cpu,wm,wsl,llm,scripts}/` (`files/base/` system, `files/wm/<name>/` WM-specific).

## Notes

- No unit tests; `mise run check` = validation. Full test = build or VM.
- Never commit `cosign.*` secrets; images signed, verify via `cosign verify`.
- New package/feature: recipe module + overlays + `from-file:` include; new top-level recipe -> add to GHA matrix.
