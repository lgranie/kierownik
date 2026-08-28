# bootc-native kickstart for the explicit `bootc` install method.
#
# This kickstart is injected into a GENERIC Fedora 44+ installer ISO with
# `mkksiso` (see the build/iso-bootc task). At install time Anaconda pulls the
# container image from the registry over the network using the `bootc` command,
# which handles filesystem population and bootloader configuration.
#
# __IMGREF__ is substituted by the build task with the per-target image ref.
#
# Known limitation: the `bootc` command does not yet support arbitrary mount
# points including /boot/efi, so EFI is handled via `reqpart --add-boot`
# instead of an explicit `part /boot/efi`. See:
#   https://discussion.fedoraproject.org/t/install-bootc-system-centos-from-kickstart/179368
#
# A dedicated non-zram swap partition (swap >= RAM) is created because zram
# cannot be used for hibernation; the hibernation-configure service picks up its
# UUID at first boot for the kernel `resume=UUID=...` parameter.

# Fully unattended installation
text

# Locale / keyboard / timezone (matches firstboot defaults)
lang en_US.UTF-8
keyboard us
timezone Europe/Paris --utc

# Wipe the first disk and partition it (GPT)
zerombr
clearpart --all --initlabel --disklabel=gpt

# Create /boot (and EFI/BIOS boot parts) automatically
reqpart --add-boot

# Swap partition >= RAM for hibernation (zram cannot hibernate)
part swap --size=16384 --fstype=swap

# Root filesystem, grows to fill the disk (bootc mounts at /sysroot)
part / --grow --fstype=btrfs

# Network (needed to pull the container from the registry)
network --bootproto=dhcp --device=link --activate --onboot=on

# Install the container image via bootc
bootc --source-imgref=registry:__IMGREF__ --target-imgref=__IMGREF__

# Reboot into the installed system when done
reboot --eject
