# Kierownik &nbsp; [![bluebuild build badge](https://github.com/lgranie/kierownik/actions/workflows/build.yml/badge.svg)](https://github.com/lgranie/kierownik/actions/workflows/build.yml)

Kierownik is a personal operating system built with [BlueBuild](https://blue-build.org) for my machines:

* [krw-5290](https://github.com/lgranie/kierownik/blob/main/recipes/krw-5290.yml) — **Dell Latitude 5290 2-in-1** — Hyprland
* [krw-8745](https://github.com/lgranie/kierownik/blob/main/recipes/krw-8745.yml) — **Chuwi AuBox 8745** — Hyprland
* [krw-N100](https://github.com/lgranie/kierownik/blob/main/recipes/krw-N100.yml) — headless server (Intel N100)
* [krw-wsl](https://github.com/lgranie/kierownik/blob/main/recipes/krw-wsl.yml) — WSL

Kierownik ships with:

* a headless version ( kierownik-base ) with :
  * fish as default interactive shell
  * a collection of terminal tools ( lsd, zoxide, bat, tv, ... )
  * mise for dev and system tasks
* graphical flavors ( kierownik-hypr ) : Hyprland with scrolling layout as default
  * noctalia-shell
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

If building on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/how-to/generate-iso/#_top). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

#### From a recipe

if you got sudo command
```bash
bluebuild generate-iso --iso-name krw-5290.iso recipe recipes/krw-5290.yml
```

#### From an image

if you have sudo command
```bash
bluebuild generate-iso --iso-name krw-5290.iso image ghcr.io/lgranie/krw-5290:latest
```

or use mise taks ( use run0 )
```bash
mise run build:iso 5290
```

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
