# Kierownik - Agent Guidelines

This is a BlueBuild/Fedora bootc OS configuration repository. Agents working here are configuring an immutable, container-native operating system.

## Build Commands

### Using mise (recommended)
```bash
# Build OCI image
mise run build_oci base    # Build base image
mise run build_oci wm      # Build WM (Hyprland) image

# Build ISO
mise run build_iso wm

# Build QCOW2 for VM
mise run build_qcow2 wm

# Run in VM
mise run vm wm
```

### Using bluebuild directly
```bash
bluebuild build recipes/recipe-wm.yml
bluebuild generate-iso --iso-name kier-wm.iso recipe recipes/recipe-wm.yml
```

### CI/CD
- GitHub Actions: `.github/workflows/build.yml`
- Builds run on schedule (Saturday 07:00 UTC) and on push
- Uses blue-build/github-action@v1.11
- Currently builds `recipe-wm.yml` (add to matrix in build.yml to build more)

## Code Style

### Shell Scripts
- Shebang: `#!/usr/bin/env bash` or `#!/usr/bin/env fish`
- Always use error handling: `set -oue pipefail`
- Example:
```bash
#!/usr/bin/env bash
set -oue pipefail
# Your code here
```

### YAML Recipes
- Use BlueBuild recipe schema: `https://schema.blue-build.org/recipe-v1.json`
- Recipe structure:
```yaml
---
modules:
  - type: dnf
    install:
      packages:
        - package-name
  - type: files
    files:
      - source: relative/path
        destination: /
  - type: script
    snippets:
      - "shell command"
```

### Configuration Files
- Follow existing patterns in `files/` directory
- Use descriptive names: `config.fish`, `hyprland.conf`, etc.
- Keep system configs in `files/base/`
- Keep WM-specific configs in `files/wm/<wm-name>/`

### File Organization
```
recipes/
  base/          # Base system modules
  wm/            # Window manager modules
  common/        # Shared modules
  recipe-*.yml   # Top-level recipes

files/
  base/          # System-level file overlays
  wm/            # WM-specific overlays
  scripts/       # Shell scripts
```

## Error Handling
- Shell scripts: Always use `set -oue pipefail`
- Use `|| true` sparingly when errors are acceptable
- Validate inputs in scripts

## Important Notes
- No unit tests exist (configuration-only repo)
- Test changes by building images or running in VM
- Signing keys (cosign.*) are in .gitignore - never commit
- This is a NixOS-like immutable OS - changes require rebuild
- Images are signed with cosign - verify with `cosign verify`

## Adding New Packages
1. Create or modify a recipe in `recipes/base/` or `recipes/wm/`
2. Add dnf module with package list
3. Optionally add file overlays or scripts

## Adding New WM/Features
1. Create module in `recipes/wm/common/` or `recipes/base/`
2. Add file overlays in `files/wm/` or `files/base/`
3. Include in relevant recipe
4. Add to build matrix in `.github/workflows/build.yml` if new recipe
