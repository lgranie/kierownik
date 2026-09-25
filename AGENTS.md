# Kierownik - Agent Guidelines

BlueBuild/Fedora bootc OS config. Immutable container-native OS; changes require rebuild.

## Build

```bash
mise run check:lint [--fix]           # validate/lint, no build
mise run check:trivy                  # trivy fs + config scan (HIGH/CRITICAL)
mise run build:oci N100|8745|5290     # N100=headless, 8745=Hyprland AMD, 5290=Hyprland Intel
mise run build:iso|build:qcow2 5290
mise run run:vm|run:iso 5290
mise run build:wsl                    # no target arg, always krw-wsl.yml
mise run wp:build [--event push]      # local Woodpecker run
```

CI: `.github/workflows/build.yml` + `.woodpecker/build.yml`. Matrix `krw-5290.yml` + `krw-8745.yml` (N100/WSL excluded), schedule Sat 07:00 UTC, push (ignore `**.md`, `next/*`), PR, dispatch.

## Shell

- `#!/usr/bin/env bash`, `set -oue pipefail`, validate inputs, sparse `|| true`.
- Interaction in `.mise/tasks/`, `files/**/tasks/*` via `gum`, never `echo`/`read -p`. Plumbing `echo` stays (pipes, redirects, `> /sys/...`).
- No `gum` in `files/scripts/finalize/` (pre-install build time).

## Recipes

- Line 1 schema required: `# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json`
- dnf: `install-weak-deps: false`. files: relative `source:`, `destination: /`.
- Top-level `recipes/krw-*.yml`; modules in `recipes/{base,cpu,wm,wsl,llm,finalize}/`. Overlays in `files/{base,cpu,wm,wsl,llm,scripts}/`.

## Notes

- No unit tests; `mise run check:lint` = validation. Full test = build or VM.
- Never commit `cosign.*` secrets; images signed, verify via `cosign verify`.
- New package/feature: recipe module + overlays + `from-file:` include; new top-level recipe -> add to GHA matrix (N100/WSL deliberately excluded).
- On-image tasks: `files/*/usr/lib/kierownik/tasks/<group>/<name>`, run via `krw`; `recipes/finalize/all.yml` chmods +x.
- Disk images: `.mise/tasks_assets/image-builder/config/qcow2-blueprint.json` feeds `build:qcow2` (image-builder). `next/*.md` = design notes, ignored by CI.
