#!/usr/bin/env bash
# Build a lean, machine-tuned kernel from the Fedora kernel SRPM and package
# it into a kernel-kierownik RPM.
#
# Runs inside the `kernel-builder` stage of the image build (see the `stages:`
# block in the top-level recipes). The machine config is copied in as
# /tmp/kernelsrc/kernel.config by that stage. The RPM is written to
# /tmp/kernels, from where the main image installs it.
set -oue pipefail

SRC_DIR=/tmp/kernelsrc
RPM_DIR=/tmp/kernels
STAGE=${RPM_DIR}/stage

mkdir -p "${SRC_DIR}" "${RPM_DIR}"
cd "${SRC_DIR}"

# Source repo for fetching the kernel SRPM. It tracks the same release as the
# base image (fedora-bootc), so the SRPM version always matches.
printf '[fedora-source]\nname=Fedora $releasever - Source\nbaseurl=https://dl.fedoraproject.org/pub/fedora/linux/releases/$releasever/Everything/source/tree/\nenabled=1\ngpgcheck=1\nmetadata_expire=6h\n' > /etc/yum.repos.d/fedora-source.repo

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

# Machine-tuned config on top of the Fedora defaults; every option missing
# from the config gets its Kconfig default.
cp "${SRC_DIR}/kernel.config" "${SRCTREE}/.config"
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
  /tmp/files/scripts/kernel/kernel-kierownik.spec.in > "${SRC_DIR}/kernel-kierownik.spec"
rpmbuild -bb "${SRC_DIR}/kernel-kierownik.spec" \
  --define "_sourcedir ${RPM_DIR}"

ls -la "${RPM_DIR}"/x86_64/*.rpm
