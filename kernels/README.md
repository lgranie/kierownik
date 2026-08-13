# Custom kernels

Each machine gets its own lean, hand-trimmed kernel config:

| Image      | Machine                 | CPU / iGPU                        | Config            |
| ---------- | ----------------------- | --------------------------------- | ----------------- |
| `krw-5290` | Dell Latitude 5290 2-in-1 | Intel Kaby Lake, UHD 620        | `kernels/5290.config` |
| `krw-8745` | Chuwi AuBox 8745        | AMD Ryzen 7 8745HS, Radeon 780M  | `kernels/8745.config` |

## How it works

Each recipe defines a `kernel-builder` stage (top-level `stages:` block). It:

1. Configures the Fedora source repo and fetches the kernel SRPM matching the
   base image's `kernel-core` version (no manual version bumps).
2. Extracts it with `rpmbuild -bp`, applying the Fedora patches.
3. Copies the machine config into `.config` and runs `make olddefconfig`
   (every option not listed in the config gets its Kconfig default).
4. Builds with `make bzImage modules`.
5. Stages `vmlinuz`, `System.map`, `config` and modules into
   `/usr/lib/modules/<version>-kierownik/` - the location ostree/bootc uses to
   deploy a kernel.
6. Packages everything into a `kernel-kierownik-<version>.rpm` via
   `rpmbuild -bb`.

The shared build logic lives in `files/scripts/kernel/build-kernel-rpm.sh` and
`files/scripts/kernel/kernel-kierownik.spec.in`. The RPM is copied into the
final image by `recipes/kernel/install.yml`, which installs it and removes the
stock Fedora kernels so the image ships a single kernel. The build toolchain
stays in the builder stage and never pollutes the final image.

## Editing the configs

Only the options that matter are listed; `make olddefconfig` fills in the rest
with upstream defaults. To regenerate a full `.config` for tweaking:

```bash
# inside the extracted kernel source
cp kernels/5290.config .config
make olddefconfig
make menuconfig   # make your changes
# copy the full .config back if you want to commit it
```

## Version tracking

The configs are written for the stable line that Fedora 44 ships (kernel
7.x). The build always fetches the SRPM matching the base image's
`kernel-core`, so no manual bump is needed.

## Caveats

- **Secure Boot**: the built kernel is unsigned. Disable Secure Boot or enroll
  MOK keys before rebasing.
- **kargs**: existing `kargs` (e.g. `preempt=full`, `i915.*`, `amd_pstate`)
  are honored - the configs enable `CONFIG_PREEMPT_DYNAMIC`, the matching GPU
  driver and pstate driver.
- **Modules**: this repo has no akmods/dkms packages, so the removed stock
  kernels break nothing.
