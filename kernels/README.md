# Custom kernels

Each machine gets its own lean, hand-trimmed kernel fragment on top of shared
layers — `kernels/common.config` (hardware platform, drivers, disk formats),
`kernels/common/bootc.config` (bootc image model + container stack), for Intel
images `kernels/common/intel.config` (pstate, idle, i915, ...), and, for
human-facing images only, `kernels/common/workstation.config` (wireless,
audio, bluetooth):

| Image      | Machine                 | CPU / iGPU                        | Config                                                                                          |
| ---------- | ----------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------- |
| `krw-5290` | Dell Latitude 5290 2-in-1 | Intel Kaby Lake, UHD 620        | `common.config` + `common/bootc.config` + `common/intel.config` + `common/workstation.config` + `5290.config` |
| `krw-8745` | Chuwi AuBox 8745        | AMD Ryzen 7 8745HS, Radeon 780M  | `common.config` + `common/bootc.config` + `common/workstation.config` + `8745.config` |
| `krw-x4cxl`| Topton X4C-XL           | Intel N100 (Alder Lake-N) | `common.config` + `common/bootc.config` + `common/intel.config` + `x4cxl.config` |

## How it works

Each recipe defines a `kernel-builder` stage (top-level `stages:` block). It:

1. Configures the Fedora source repo and fetches the kernel SRPM matching the
   base image's `kernel-core` version (no manual version bumps).
2. Extracts it with `rpmbuild -bp`, applying the Fedora patches.
3. Merges `kernels/common.config` + `kernels/common/bootc.config`
   [+ `common/intel.config` for Intel images]
   [+ the workstation fragment for human-facing images]
   + the machine fragment via `scripts/kconfig/merge_config.sh -m`
   (later files win on conflict), then runs `make olddefconfig`
   (every option listed in no file gets its Kconfig default).
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
with upstream defaults. Options identical on every machine live in
`kernels/common.config` (platform/drivers) or `kernels/common/bootc.config`
(bootc + containers), Intel-shared bits in `kernels/common/intel.config`,
or, for human-facing images, `kernels/common/workstation.config`
(wireless/audio/bluetooth); only hardware deltas (CPU tuning, `NR_CPUS`, GPU,
NIC, sensors) live in `kernels/<machine>.config`. To regenerate a full
`.config` for tweaking:

```bash
# inside the extracted kernel source
cp /path/to/kernels/common.config .config
./scripts/kconfig/merge_config.sh -m -O . .config \
  /path/to/kernels/common/bootc.config \
  /path/to/kernels/common/intel.config `# Intel images only` \
  /path/to/kernels/common/workstation.config `# human-facing images only` \
  /path/to/kernels/5290.config
make olddefconfig
make menuconfig   # make your changes
# split the result back: platform bits to common.config, bootc bits to
# common/bootc.config, deltas to <machine>.config
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
