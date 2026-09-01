# Building Kierownik

Build commands for this BlueBuild / Fedora bootc repo. Requires podman +
[run0](https://man7.org/linux/man-pages/man1/run0.1.html) (systemd's sudo
alternative; or sudo), [mise](https://mise.jdx.dev), and `gh` for publishing.
Install tooling from `.mise/config.toml`:

```bash
mise install
```

Targets: `5290` (Dell Latitude), `8745` (Chuwi AuBox), `N100` (headless server),
`wsl`.

## Build an OCI image

```bash
mise run build:oci 8745          # or 5290 / N100
```

Runs `bluebuild build recipes/krw-<target>.yml`. Result:
`ghcr.io/lgranie/krw-<target>:latest`.

## Generate an ISO

Two installer ISO options (network needed at install time):

```bash
mise run build:iso 5290          # unattended bootc installer ISO (bootc-generic-iso)
mise run build:iso-bootc 5290    # bootc-native, kickstart injected via mkksiso
```

- `build:iso` → output `/tmp/output/iso/install.iso` (stages `bib/installer/`,
  uses image-builder / `IMAGE_BUILDER` env).
- `build:iso-bootc` → output `/tmp/output/iso-bootc/krw-<target>.iso` (uses
  `bib/ks/bootc.ks` + `bib/mkksiso/`).

## Build a QCOW2 for a VM

```bash
mise run build:qcow2 5290
```

Uses bootc-image-builder (`BIB_IMAGE` env), config/rootfs from `bib/`. Output in
`/tmp/output/qcow2/`.

## Run the image in a VM

```bash
mise run vm:qcow2 5290          # virt-install the built qcow2
mise run vm:iso-bootc 5290      # boot and test the build:iso-bootc installer ISO
```

UEFI VM, 8GB RAM / 8 vCPUs, SPICE + virtio GPU accel.

## Build the WSL image

```bash
mise run build:wsl
```

Builds `recipes/krw-wsl.yml`, exports the container, compresses to
`/tmp/output/wsl/kierownik.wsl`.

## Verify a signed image

```bash
cosign verify --key cosign.pub ghcr.io/lgranie/krw-5290
```
