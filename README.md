# Kierownik &nbsp; [![bluebuild build badge](https://github.com/lgranie/kierownik/actions/workflows/build.yml/badge.svg)](https://github.com/lgranie/kierownik/actions/workflows/build.yml)

Kierownik is a personal operating system built with [BlueBuild](https://blue-build.org) for my machines:

* [krw-5290](https://github.com/lgranie/kierownik/blob/main/recipes/krw-5290.yml) — **Dell Latitude 5290 2-in-1** — Hyprland
* [krw-8745](https://github.com/lgranie/kierownik/blob/main/recipes/krw-8745.yml) — **Chuwi AuBox 8745** — Hyprland
* [krw-X4CXL](https://github.com/lgranie/kierownik/blob/main/recipes/krw-X4CXL.yml) — **Topton X4C-XL** Headless Server
* [krw-wsl](https://github.com/lgranie/kierownik/blob/main/recipes/krw-wsl.yml) — wsl

Kierownik ships with:

* a headless version with :
  * fish as default interactive shell
  * a collection of terminal tools ( lsd, zoxide, bat, tv, ... )
  * mise for dev and system tasks
* graphical flavors : Hyprland with scrolling layout as default
  * noctalia / noctalia-greeter
  * flatpak / flathub / bazaar
  * foot terminal
  * some nerd fonts

## Inspirations

* <https://github.com/blue-build/template>
* <https://github.com/secureblue/secureblue>
* <https://github.com/wayblueorg/wayblue>
* <https://github.com/zirconium-dev/zirconium>
* <https://github.com/Zena-Linux/Zena>
* <https://github.com/basecamp/omarchy>

## Installation

### Rebase an existing atomic Fedora installation

To rebase an existing atomic Fedora installation to the latest build:

* Switch to the image :

```bash
run0 bash -c 'bootc switch ghcr.io/lgranie/krw-5290:latest --apply'
```

### ISO

Two installer ISO methods are provided. Both wipe the **first disk** they find,
so only boot them on the target machine. Both create a dedicated swap partition
(>= RAM) required for hibernation (zram cannot be used to hibernate).

#### bootc-generic-iso (image-builder, recommended)

A live installer ISO built from a small installer-environment container via the
`bootc-generic-iso` image type in `image-builder` (the successor to the
deprecated `anaconda-iso` -- `bootc-image-builder`). The payload image is
embedded (`--bootc-installer-payload-ref`), so install works offline; leftover
`inst.stage2` / kernel args boot a text Anaconda that applies
`bib/installer/src/interactive-defaults.ks`.

```bash
mise run build:iso 5290        # -> /tmp/output/iso/install.iso
```

Installer container: `bib/installer/` (Containerfile + src).

#### bootc-native (generic Fedora installer + registry pull)

Downloads a generic Fedora 44+ installer ISO, injects a kickstart using the
explicit `bootc` kickstart command, and pulls the image from the registry over
the network at install time.

```bash
mise run build:iso-bootc 5290  # -> /tmp/output/iso-bootc
```

Kickstart: `bib/ks/bootc.ks`. Install time requires access to
`ghcr.io/lgranie`. Note: the `bootc` command does not yet support `/boot/efi`
as an explicit mount point (handled via `reqpart --add-boot`), and does not
support installing from authenticated registries.

### WSL

```bash
podman pull ghcr.io/lgranie/kierownik-wsl:latest
podman create --name kierownik-temp ghcr.io/lgranie/kierownik-wsl:latest
podman export kierownik-temp -o kierownik.wsl
podman rm kierownik-temp
wsl --import Kierownik .local/share/kierownik kierownik.wsl
wsl -d Kierownik
```

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/lgranie/krw-5290
```
