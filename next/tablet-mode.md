# Tablet mode (Dell Latitude 5290 2-in-1)

Design notes for the 2-in-1 support. Implemented: **P1 (rotation only)**.
`next/*.md` is ignored by CI.

## Hardware, probed on the 5290 (Hyprland 0.57.1)

| Thing | Finding |
|---|---|
| Panel | `eDP-1`, 1920x1280 3:2, scale 1.3333334, external `DP-1` at `1920x0` transform 2 |
| Accelerometer | `iio:device4` `accel_3d` (Intel HID sensor hub), `in_accel_{x,y,z}_raw`, scale 0.000009806 |
| Other iio | `gyro_3d`, `incli_3d`, `magn_3d`, `geomagnetic_orientation`, `als`, `dev_rotation` |
| Tablet switch | `Intel Virtual Switches` (`SW=2` → `SW_TABLET_MODE`), plus `Lid Switch` |
| Keyboard base | `platform-i8042-serio-0-event-kbd` + `Alps_Touchpad` on USB |
| Digitizers | `wacom-hid-484e-finger` (touch), `wacom-hid-484e-pen` (pen) |
| `hyprctl eval` | works on 0.57.1 (`hyprctl keyword` is refused: Lua config) |

Notes:

- `SW_TABLET_MODE` exists, so P2 can bind `switch:on:Intel Virtual Switches` /
  `switch:off:...` instead of only polling.
- The keyboard base's keyboard arrives as the i8042 AT keyboard, so
  `/dev/input/by-path/*-kbd` disappearing is the detach signal. Verify by
  detaching the base and watching `udevadm monitor --subsystem-match=input`.
- iio-sensor-proxy is **not** in the image yet; the `accel_3d` device was read
  straight from sysfs during the probe. If the daemon reports no orientation
  after installing it, check for the iio-sensor-proxy 3.7 regression (accel
  buffer claimed by udev; fixed in 3.8) and `monitor-sensor --accel`.

## P1 — rotation only (implemented)

- `recipes/wm/common/tablet.yml` (pulled in by `recipes/wm/5290.yml`):
  `iio-sensor-proxy`, `files/wm/common/tablet`, `chmod +x /usr/bin/krw-tablet`,
  system `iio-sensor-proxy.service`, user `krw-tablet.service`.
- `files/wm/common/tablet/usr/bin/krw-tablet`:
  - `daemon` polls `net.hadess.SensorProxy.AccelerometerOrientation` (~1 s,
    two identical readings before turning), the live `eDP-1` transform, and
    whether an internal keyboard is attached.
  - `rotate normal|right|inverted|left|next|prev|auto`, `lock on|off|toggle`,
    `status`, `probe`.
  - Mapping (`right-up` → transform 3 is the standard one, confirmed by hand
    on the device): `normal 0`, `right 3`, `inverted 2`, `left 1`.
  - Applied with `hyprctl eval` of `hl.monitor` + `hl.config input.touchdevice
    / input.tablet` + `hl.device` per touch/pen device. Binding a digitizer to
    an output does not rotate its axes, so the device transform is required.
  - Persistence: the same Lua is written to
    `$HOME/.local/state/kierownik/tablet/rotation.lua` (removed when upright)
    and loaded at the end of `5290.lua`, so `hyprctl reload` keeps the panel
    turned. `$HOME` rather than `$XDG_STATE_HOME` so the Lua side can find it.
  - A manual rotation takes the lock; `rotate auto` releases it. The lock file
    holds `$HYPRLAND_INSTANCE_SIGNATURE`, so it never survives a logout.
- `krw wm tablet` — task wrapper with `gum choose`.

Auto-rotation runs only while no `/dev/input/by-path/*-kbd` exists
(`KRW_TABLET_FORCE=1` overrides). That is P1's only mode detection.

## Still to verify on the tablet

1. `krw-tablet probe` with iio-sensor-proxy installed → `HasAccelerometer`,
   `AccelerometerOrientation` changing on tilt.
2. Detach the keyboard base, tilt in four directions: panel follows, taps and
   pen land where the finger is. If a direction is wrong, fix the mapping in
   `sensor_orientation` (or the mount matrix via
   `/etc/udev/hwdb.d/61-sensor-local.hwdb` if the sensor itself is rotated).
3. `hyprctl reload` while turned → stays turned.
4. `krw-tablet rotate lock`, tilt → no rotation; `rotate auto` → follows again.
5. With the external `DP-1` attached, check `position = "auto"` does not put
   the turned panel under the external display.

## P2 (next): tablet mode

- `hl.bind("switch:on:Intel Virtual Switches", …)` / `switch:off`, plus the
  keyboard-presence poll and a manual `krw-tablet mode on|off|toggle`.
- Enter: rotate, start `wvkbd.service` (`SIGRTMIN` if already running).
  Exit: upright, stop wvkbd.
- Noctalia: intentionally untouched in P1. Later: `dock-show/hide` on
  enter/exit, and only after testing that an auto-hidden bar is reachable by
  touch (reveal is pointer-driven; touch is not `wl_pointer`).
