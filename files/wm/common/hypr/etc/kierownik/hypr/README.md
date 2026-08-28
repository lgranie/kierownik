# Hyprland Hibernation Guide

This guide explains how to use hibernation (suspend to disk) with Hyprland on Kierownik.

## Keybindings

The following keybindings are available for power management:

| Keybinding | Action |
|------------|--------|
| `SUPER + CTRL + ALT + S` | Suspend (sleep) |
| `SUPER + CTRL + ALT + H` | Hibernate (suspend to disk) |
| `SUPER + CTRL + ALT + P` | Hybrid Sleep (hibernate then suspend) |

## Requirements

1. **Swap Partition**: You must have a swap partition that is at least as large as your RAM.
2. **UUID Configuration**: The swap partition must be configured for resume.

## Checking Support

To verify your system supports hibernation:

```bash
sudo /usr/lib/kierownik/tasks/hibernation/test
```

This will show:
- Swap configuration
- Memory and swap sizes
- Resume parameter
- Systemd hibernate service
- Initramfs configuration

## Manual Hibernation

You can hibernate from the command line:

```bash
systemctl hibernate
```

## Troubleshooting

### Hibernation fails to resume

1. Check kernel messages:
   ```bash
   journalctl -b -0 | grep -i hibernate
   ```

2. Verify resume parameter:
   ```bash
   cat /proc/cmdline | grep resume
   ```

3. Check swap configuration:
   ```bash
   swapon --show
   blkid | grep swap
   ```

### Battery drain during hibernation

If your battery drains during hibernation:

1. Check if suspend is working:
   ```bash
   systemctl suspend
   ```

2. Configure better power management:
   ```bash
   sudo powerprofilesctl set active balanced
   ```

## References

- [Systemd Hibernation](https://www.freedesktop.org/software/systemd/man/systemd-suspend-service.html)
- [Kernel Hibernation](https://www.kernel.org/doc/html/latest/power/userland-interfaces.html)
