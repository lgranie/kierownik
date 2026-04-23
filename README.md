# Kierownik &nbsp; [![bluebuild build badge](https://github.com/lgranie/kierownik/actions/workflows/build.yml/badge.svg)](https://github.com/lgranie/kierownik/actions/workflows/build.yml)

Kierownik is an operating system built with bluebuild. It is immutable and container‑native, designed for reproducibility, developer productivity, and a responsive desktop experience. Kierownik ships with:

* a headless version ( kierownik-base ) with :
  * fish as default interactive shell
  * a collection of terminal tools ( lsd, zoxide, bat, tv, ... )
  * mise for dev
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

* First rebase to the unsigned image, to get the proper signing keys and policies installed:

  ```bash
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/lgranie/kierownik-hypr:latest
  ```

* Reboot to complete the rebase:

  ```bash
  systemctl reboot
  ```

* Then rebase to the signed image, like so:

  ```bash
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/lgranie/kierownik-hypr:latest
  ```

* Reboot again to complete the installation

  ```bash
  systemctl reboot
  ```

### ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/how-to/generate-iso/#_top). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

#### From a recipe

```bash
bluebuild generate-iso --iso-name kier-hypr.iso receipe recipes/recipe-hypr.yml
```

#### From a image

```bash
bluebuild generate-iso --iso-name kier-hypr.iso image ghcr.io/lgranie/kierownik-hypr:latest
```

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/lgranie/kierownik
```

## BlueBuild Template &nbsp; [![bluebuild build badge](https://github.com/blue-build/template/actions/workflows/build.yml/badge.svg)](https://github.com/blue-build/template/actions/workflows/build.yml)

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.
