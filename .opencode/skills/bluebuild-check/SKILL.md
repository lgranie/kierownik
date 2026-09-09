---
name: bluebuild-check
description: Validate and lint BlueBuild repo using mise-managed tools (bluebuild validate, yamllint, shellcheck, shfmt, fish_indent, actionlint)
---

## What I do

Check/lint this BlueBuild + bootc repo without full image builds.
Install all check tools via `mise`, then run validation in order.

Shortcut (same steps as below):

```bash
mise run check         # check only, exit 1 on failure
mise run check --fix   # also apply shfmt -w + fish_indent -w
```

## When to use me

Use when user asks to check, lint, validate recipes, scripts, workflows,
or before committing changes to `recipes/`, `files/`, `.mise/tasks/`, `.github/`.

## Setup tools with mise

Repo-pinned tools (`bluebuild`, `gum`) come from `.mise/config.toml`.
Lint tools (`yamllint`, `yq`, `shellcheck`, `shfmt`, `actionlint`, fish)
are ephemeral via `mise x` — no repo config change needed.

```bash
# Trust + install repo tools once per checkout
mise trust
mise install

# Verify
mise x -- bluebuild --version
mise x -- gum --version
```

Tool map (auto-installs on first `mise x`):

| Check | mise invocation | Provides |
|---|---|---|
| recipe validate | `mise x -- bluebuild validate` (`cargo:blue-build` in config) | `bluebuild validate` |
| YAML lint | `mise x uv yamllint -- yamllint` (`uv` required by pipx backend) | `yamllint` |
| YAML query | `mise x yq -- yq` | `yq` |
| shell lint | `mise x shellcheck -- shellcheck` | `shellcheck` |
| shell format check | `mise x shfmt -- shfmt` | `shfmt` |
| fish format check | `mise x "aqua:fish-shell/fish-shell" -- fish_indent` | `fish_indent` |
| GHA lint | `mise x actionlint -- actionlint` | `actionlint` |

Never run `mise use -g` / `mise use` to pin lint tools unless user
explicitly asks. Prefer `mise x`.

## Workflow

Run from repo root. Stop and report on first hard failure unless user
asked for full report.

### 1. BlueBuild recipe validation (required)

```bash
mise x -- bluebuild validate recipes/krw-5290.yml
mise x -- bluebuild validate recipes/krw-8745.yml
mise x -- bluebuild validate recipes/krw-N100.yml
mise x -- bluebuild validate recipes/krw-wsl.yml
```

Or all top-level recipes:

```bash
for r in recipes/recipe-*.yml recipes/krw-*.yml; do
  [ -f "$r" ] || continue
  mise x -- bluebuild validate "$r"
done
```

### 2. YAML lint (recipes + workflows)

No `.yamllint.yml` in repo — use relaxed defaults so BlueBuild
`from-file` style passes:

```bash
mise x uv yamllint -- yamllint -d "{extends: default, rules: {line-length: {max: 160}, document-start: disable, truthy: disable}}" recipes/ .github/
```

If repo later adds `.yamllint.yml`, just run:

```bash
mise x uv yamllint -- yamllint recipes/ .github/
```

### 3. ShellCheck (bash scripts)

Targets: `.mise/tasks/**`, `files/scripts/**`, any `*.sh`.

```bash
# SC2154 excluded: mise USAGE spec injects $usage_* vars at runtime
mise x shellcheck -- shellcheck -S warning -e SC2154 -o all \
  .mise/tasks/build/* .mise/tasks/vm \
  $(find files/scripts -type f 2>/dev/null)
```

Per AGENTS.md: scripts must have `#!/usr/bin/env bash` + `set -oue pipefail`.
Flag missing shebang / missing `pipefail` as errors.
Ignore `files/scripts/finalize/` gum warnings — gum is NOT available at
build time there (runs before packages install).

### 4. shfmt format check (no writes by default)

```bash
# Repo uses 2-space indent (-i 2). -ci handles case-indent for `case` blocks.
mise x shfmt -- shfmt -d -i 2 -ci \
  .mise/tasks/build/* .mise/tasks/vm \
  $(find files -name "*.sh" 2>/dev/null)
```

Only run `shfmt -w` if user explicitly asks to fix.

### 5. Fish check (`*.fish`)

```bash
# syntax check
mise x "aqua:fish-shell/fish-shell" -- fish -n $(find files -name "*.fish" 2>/dev/null)

# format check (fails on diff, prints unified diff)
for f in $(find files -name "*.fish" 2>/dev/null); do
  mise x "aqua:fish-shell/fish-shell" -- fish_indent --check "$f"
done
```

Only run `fish_indent -w` on explicit fix request.

### 6. GitHub Actions lint

```bash
mise x actionlint -- actionlint .github/workflows/*.yml
```

### 7. Optional: recipe schema / structure sanity with yq

```bash
# list modules per top-level recipe
mise x yq -- yq '.modules[] | .type // .from-file' recipes/krw-5290.yml

# find files: modules referencing non-existent sources
mise x yq -- yq -r '.. | .source? // empty' recipes/
```

## Rules from AGENTS.md to enforce

- Shell: `set -oue pipefail`, sparing `|| true`, validate inputs.
- User interaction in `.mise/tasks/` and `files/**/tasks/*`: use `gum`,
  never `echo`/`read -p`. Mapping: `gum log -sl info|warn|error`,
  `gum style --border thick`, `gum input|choose|confirm|filter`.
  Keep plumbing `echo` (pipes, redirects, `> /sys/...`).
- No `gum` in `files/scripts/finalize/` (build-time).
- Recipes: schema `https://schema.blue-build.org/recipe-v1.json`,
  `install-weak-deps: false` for dnf modules.
- Never commit `cosign.key` / `cosign.*` secrets (`.gitignore`).
- No unit tests in repo — validation here replaces `mise test`.
  Full verification = `mise run build:oci <N100|8745|5290>` or VM,
  but don't run builds unless user asks (slow, privileged).

## Report format

1. Pass/fail per step (validate, yamllint, shellcheck, shfmt, fish, actionlint).
2. File:line + rule + one-line fix for each failure.
3. Do not auto-fix. Propose fix commands, wait for approval.
