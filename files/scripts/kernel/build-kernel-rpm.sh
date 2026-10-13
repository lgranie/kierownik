#!/usr/bin/env bash
# Build a lean, machine-tuned kernel from the Fedora kernel SRPM and package
# it into a kernel-kierownik RPM.
#
# Runs inside the `kernel-builder` stage of the image build (see the `stages:`
# block in the top-level recipes). The shared base is copied in as
# /tmp/kernelsrc/common.config, the bootc/container base as
# /tmp/kernelsrc/bootc.config, the optional workstation fragment as
# /tmp/kernelsrc/extra.config (human-facing images only) and the machine
# fragment as /tmp/kernelsrc/machine.config by that stage. The RPM is written to
# /tmp/kernels, from where the main image installs it.
set -oue pipefail

SRC_DIR=/tmp/kernelsrc
RPM_DIR=/tmp/kernels
STAGE=${RPM_DIR}/stage

mkdir -p "${SRC_DIR}" "${RPM_DIR}"
cd "${SRC_DIR}"

# Source repo for fetching the kernel SRPM. It tracks the same release as the
# base image (fedora-bootc), so the SRPM version always matches.
printf '[fedora-source]\nname=Fedora $releasever - Source\nbaseurl=https://dl.fedoraproject.org/pub/fedora/linux/releases/$releasever/Everything/source/tree/\nenabled=1\ngpgcheck=1\nmetadata_expire=6h\n' >/etc/yum.repos.d/fedora-source.repo

# Build toolchain - only ever present in this builder stage.
dnf -y install \
  bc binutils bison diffutils flex gcc git kmod make openssl-devel \
  elfutils-libelf-devel patch perl python3 rpm-build tar xz \
  >/dev/null

# Fetch the exact SRPM the base image ships and unpack it with the Fedora
# patches applied (rpmbuild -bp runs the spec's %prep).
dnf download --source kernel-core
rpm -ivh kernel-*.src.rpm
rpmbuild -bp /root/rpmbuild/SPECS/kernel.spec

SRCTREE="$(ls -d /root/rpmbuild/BUILD/kernel-*)"

# Merge the shared base (common.config) with the bootc/container base
# (bootc.config), the optional workstation fragment (extra.config, only
# copied in by human-facing images) and the machine fragment
# (machine.config); later files win on conflict. Every option missing from
# all files gets its Kconfig default via olddefconfig.
[[ -f "${SRC_DIR}/common.config" && -f "${SRC_DIR}/bootc.config" && -f "${SRC_DIR}/machine.config" ]] ||
  {
    echo "missing ${SRC_DIR}/common.config, bootc.config or machine.config" >&2
    exit 1
  }
cp "${SRC_DIR}/common.config" "${SRCTREE}/.config"
fragments=("${SRC_DIR}/bootc.config")
[[ -f "${SRC_DIR}/extra.config" ]] && fragments+=("${SRC_DIR}/extra.config")
fragments+=("${SRC_DIR}/machine.config")
"${SRCTREE}/scripts/kconfig/merge_config.sh" -m -O "${SRCTREE}" \
  "${SRCTREE}/.config" "${fragments[@]}"
make -C "${SRCTREE}" olddefconfig

# Compile the kernel and modules.
make -C "${SRCTREE}" -j"$(nproc)" bzImage modules

# Stage the install tree exactly as it should appear under /usr.
KREL="$(make -C "${SRCTREE}" kernelrelease)"
KVER="${KREL%-*}"
make -C "${SRCTREE}" INSTALL_MOD_PATH="${STAGE}/usr" INSTALL_MOD_STRIP=1 modules_install
depmod -b "${STAGE}/usr" "${KREL}"
install -Dm644 "${SRCTREE}/arch/x86/boot/bzImage" "${STAGE}/usr/lib/modules/${KREL}/vmlinuz"
install -Dm644 "${SRCTREE}/System.map" "${STAGE}/usr/lib/modules/${KREL}/System.map"
install -Dm644 "${SRCTREE}/.config" "${STAGE}/usr/lib/modules/${KREL}/config"

# Package the staged tree into a versioned RPM.
sed -e "s|@KVER@|${KVER}|g" -e "s|@KREL@|${KREL}|g" \
  /tmp/files/scripts/kernel/kernel-kierownik.spec.in >"${SRC_DIR}/kernel-kierownik.spec"
rpmbuild -bb "${SRC_DIR}/kernel-kierownik.spec" \
  --define "_sourcedir ${RPM_DIR}"

ls -la "${RPM_DIR}"/x86_64/*.rpm
