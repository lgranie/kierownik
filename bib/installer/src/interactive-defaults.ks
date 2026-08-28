# interactive-defaults.ks for the bootc-generic-iso live installer.
#
# This is installed at /usr/share/anaconda/interactive-defaults.ks inside the
# installer-environment container. When the live ISO boots into the Anaconda
# installer, these values are pre-loaded as defaults.
#
# __IMGREF__ is substituted by the build/iso task with the per-target image ref.
#
# The `bootc` command handles filesystem population and bootloader setup. It
# does not yet support arbitrary mount points including /boot/efi, so EFI is
# created via `reqpart --add-boot` rather than an explicit `part /boot/efi`.
#
# A dedicated non-zram swap partition (swap >= RAM) is created because zram
# cannot be used for hibernation; the hibernation-configure service picks up its
# UUID at first boot for the kernel `resume=UUID=...` parameter.

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

# Network
network --bootproto=dhcp --device=link --activate --onboot=on

# Install the container image via bootc
bootc --source-imgref=registry:__IMGREF__ --target-imgref=__IMGREF__
