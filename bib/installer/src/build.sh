#!/usr/bin/bash
set -exo pipefail

dnf install -qy \
    anaconda \
    anaconda-install-img-deps \
    anaconda-dracut \
    dracut-config-generic \
    dracut-network \
    net-tools \
    grub2-efi-x64-cdboot \
    jq

# these are necessary build tools for image-builder bootc-generic-iso
dnf install -qy \
    xorrisofs \
    squashfs-tools

dnf clean all

mkdir -p /boot/efi \
    && cp -ra /usr/lib/efi/*/*/EFI /boot/efi

# this is normally done by lorax; distilled down to the bare essentials to
# make anaconda the default boot target of the live image
echo "install:x:0:0:root:/root:/usr/libexec/anaconda/run-anaconda" >> /etc/passwd
echo "install::14438:0:99999:7:::" >> /etc/shadow
passwd -d root

mv /usr/share/anaconda/list-harddrives-stub /usr/bin/list-harddrives
mv /etc/yum.repos.d /etc/anaconda.repos.d
ln -s /lib/systemd/system/anaconda.target /etc/systemd/system/default.target
rm -v /usr/lib/systemd/system-generators/systemd-gpt-auto-generator

rm /usr/lib/systemd/system/autovt@.service
ln -s /usr/lib/systemd/system/anaconda-shell@.service /usr/lib/systemd/system/autovt@.service

mkdir -p /usr/lib/systemd/logind.conf.d
printf '[Login]\nReserveVT=2\n' > /usr/lib/systemd/logind.conf.d/anaconda-shell.conf

# regenerate the initramfs including the anaconda module
mkdir -p "$(realpath /root)"
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version' | head -n1)
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
  --add "anaconda" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# set the defaults for anaconda, including the container to install
cp /src/interactive-defaults.ks /usr/share/anaconda/interactive-defaults.ks

# set the defaults for image-builder
mkdir -p /usr/lib/bootc-image-builder
cp /src/iso.yaml /usr/lib/bootc-image-builder/iso.yaml
