# Tablet mode (Dell Latitude 5290 2-in-1)

Design notes for the 2-in-1 support. Implemented: **P1 (rotation)**,
**P2 (tablet mode)**, **P3 (Noctalia)** and **P4 (on-device fixes)**.
`next/*.md` is ignored by CI.

## Hardware, probed on the 5290 (Hyprland 0.57.1)

| Thing | Finding |
|---|---|
| Panel | `eDP-1`, 1920x1280 3:2, scale 1.3333334, external `DP-1` at `1920x0` transform 2 |
| Accelerometer | `iio:device4` `accel_3d` (Intel HID sensor hub), `in_accel_{x,y,z}_raw`, scale 0.000009806 |
| Other iio | `gyro_3d`, `incli_3d`, `magn_3d`, `geomagnetic_orientation`, `als`, `dev_rotation` |
| Tablet switch | `Intel Virtual Switches` (`SW=2` → `SW_TABLET_MODE`), plus `Lid Switch` |
| Keyboard base | the EC keyboard `platform-i8042-serio-0-event-kbd` **stays in the slate**, plus `1-2 044e:1218 Alps Touchpad` on USB, which leaves with the base |
| Digitizers | `wacom-hid-484e-finger` (touch), `wacom-hid-484e-pen` (pen) |
| `hyprctl eval` | works on 0.57.1 (`hyprctl keyword` is refused: Lua config) |

Notes:

- `SW_TABLET_MODE` exists and the binds are deployed, but **the switch never
  moves when the base is detached** (captured with
  `udevadm monitor --udev --property` over a detach/attach cycle: no switch
  event, `switch` state file stayed `off`). It is still worth binding; on this
  machine it just never fires.
- The base's keyboard arrives as the i8042 AT keyboard, which is in the slate
  and survives the detach, so `*-kbd` disappearing is **not** a usable detach
  signal. See P4.
- iio-sensor-proxy (3.9 in the image) only computes
  `AccelerometerOrientation` while a client holds a claim, so one-shot D-Bus
  reads say `s "undefined"`. See P4.

## P1 — rotation only (implemented)

- `recipes/wm/common/tablet.yml` (pulled in by `recipes/wm/5290.yml`):
  `iio-sensor-proxy`, `files/wm/common/tablet`, `chmod +x /usr/bin/krw-tablet`,
  system `iio-sensor-proxy.service`, user `krw-tablet.service`.
- `files/wm/common/tablet/usr/bin/krw-tablet`:
  - `daemon` followed `net.hadess.SensorProxy.AccelerometerOrientation` by
    polling (~1 s, two identical readings before turning). P4 replaced the
    polling with the claim/event stream; the mode and lock state are still
    re-read every second.
  - `rotate normal|right|inverted|left|next|prev|auto`, `lock on|off|toggle`,
    `status`, `probe`.
  - Mapping (`right-up` → transform 3 is the standard one for iio + Hyprland,
    still to be confirmed by tilting the real machine): `normal 0`, `right 3`,
    `inverted 2`, `left 1`.
  - Applied with `hyprctl eval` of `hl.monitor` + `hl.config input.touchdevice
    / input.tablet` + `hl.device` per touch/pen device. Binding a digitizer to
    an output does not rotate its axes, so the device transform is required.
  - Persistence: the same Lua is written to
    `$HOME/.local/state/kierownik/tablet/rotation.lua` (removed when upright)
    and loaded by `additionals/tablet.lua`, after `5290.lua`, so `hyprctl
    reload` keeps the panel turned. `$HOME` rather than `$XDG_STATE_HOME` so
    the Lua side can find it.
  - A manual rotation takes the lock; `rotate auto` releases it. The lock file
    holds `$HYPRLAND_INSTANCE_SIGNATURE`, so it never survives a logout.
- `krw wm tablet` — task wrapper with `gum choose`.

Auto-rotation runs only in tablet mode, which P1 keyed off the internal keyboard
alone (`KRW_TABLET_FORCE=1` overrides); P2 replaced that with the full trigger
chain below, and P4 replaced the keyboard test itself.

## P2 — tablet mode (implemented)

- Mode is on when any of these says so, in order: `krw-tablet mode on` (manual,
  tagged with the session signature), `SW_TABLET_MODE` from the Hyprland binds
  in `additionals/tablet.lua`, or the base being absent (P4 defines "absent").
  An "on" claim always wins, so an undetected keyboard node or a lying switch
  cannot leave a keyless tablet in laptop mode; `mode off` is the only way to
  hold it there.
- Enter: start `wvkbd.service`, rotate to the sensor (unless locked).
- Exit: stop `wvkbd.service`, clear the rotation lock, straighten the panel.
- `wvkbd.service` is no longer enabled at session start and `start-wvkbd`
  no longer checks for a keyboard itself: the daemon decides, so the keyboard
  can start and stop on detach/attach instead of only at login.
- `krw wm tablet` gained `mode-on`, `mode-off`, `mode-auto`.

## P3 — Noctalia (implemented)

The problem is small but real: a Noctalia bar with `auto_hide` slides back in
when the **pointer** reaches the screen edge, and a tablet has no pointer. An
auto-hidden bar is therefore unreachable while the base is detached, and so is
a bar hidden with `bar-hide` (which blocks edge reveal too).

- Enter: if any bar auto-hides (`auto_hide` or `smart_auto_hide` in the merged
  config), `bar-auto-hide-set off`; then `bar-show` for the bar itself. Both are
  runtime only — Noctalia documents them as resetting on config reload or shell
  restart — so the image config is never written to and the user's
  `~/.config/noctalia` is left alone.
- Exit: re-send the configured auto-hide mode, and `bar-hide` only if the bar
  was hidden when the mode was entered. The pair is recorded in
  `$STATE_DIR/noctalia` with the session signature: an exit with no record (a
  plain `mode off` at login, or Noctalia was down) touches nothing at all.
- The daemon retries the enter side up to 30 times, one per loop, while mode is
  on and no record exists — a tablet booted with the base already off starts
  before Noctalia can answer. After it succeeds the file says so and the retry
  stops, so nothing is polled forever.
- `mode on|off` now **force** the transition even when the mode already matches.
  That is the repair command for what a Noctalia (or wvkbd, or Hyprland)
  restart undid: the shell restart clears its runtime overrides and there is no
  pointer to fix the bar by hand.
- `status` gained one `shell:` line and `probe` a `== shell (Noctalia) ==`
  section (bar visibility, configured auto-hide, dock state).

Not done, on purpose:

- The dock. It is `enabled = false` in the image, and `dock-show`/`dock-hide`
  save an override rather than being a pure runtime flag, so showing it would
  be a real change of the user's session. With the dock enabled *and*
  auto-hiding it has the same touch problem as the bar; the fix belongs in the
  config (`[dock.monitor."eDP-1"] auto_hide = false`), not in a mode switch.
- Any `config-set`/`config-reload`: both would persist or reset unrelated user
  choices. The bar scale is also left alone — bigger touch targets are a
  config decision, not something a detach should silently change.

## P4 — it has to work on the real machine (implemented)

The P1–P3 build booted (`br-tablet-45`) with the daemon alive and the binds
deployed, and still did nothing when the base was unclipped and the slate
tilted. Two independent causes, both found on the machine:

**The accelerometer was never claimed.** iio-sensor-proxy computes
`AccelerometerOrientation` only while a client holds a claim, and a claim lives
exactly as long as its D-Bus connection. The daemon read the property with
`busctl --system get-property`, which connects, asks and disconnects — so with
nothing else claiming the sensor it always got `s "undefined"`, logged
`no accelerometer orientation`, and never rotated:

```
$ busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy \
    net.hadess.SensorProxy AccelerometerOrientation
s "undefined"
$ timeout 3 monitor-sensor --accel      # claims it, and then reports changes
    Accelerometer orientation changed: normal
```

- The daemon now runs `monitor-sensor --accel` as a **coproc**: that process is
  the claim *and* the event stream, so rotation is event-driven and the property
  stays live for `status`/`probe`.
- The read timeout on the coproc doubles as the ~1 s tick for mode, lock and the
  Noctalia retry, so a detach or a switch bind is still noticed without a tilt.
- A rotation waits 200 ms and re-reads the property before turning, so a machine
  resting on an edge does not flap.
- CLI paths without a daemon (`mode on`, `rotate auto`) take a short
  `monitor-sensor` claim of their own; after a claim/release the property keeps
  the last value, so `status` may show a stale orientation and `probe` says so.
- `probe` gained the `monitor-sensor` path, whether `krw-tablet` is active, and
  the mode it would pick.

**Detach was invisible.** `platform-i8042-serio-0-event-kbd` is the EC keyboard
inside the slate: it stays after the base is unclipped, so "no `*-kbd` node"
never became true. `SW_TABLET_MODE` does not fire either. What does leave is the
base's USB device `1-2 044e:1218 Alps Touchpad` (interfaces `ID_USB_INTERFACES=
:030102:`, mouse + touchpad), whose input nodes are gone from
`/dev/input/by-path` a second later — captured at 07:20:29 (detach) and
07:21:22 (attach), with `usb-0:2:*` nodes vanishing and reappearing.

- `keyboard_attached` became `base_attached`: attached iff a keyboard **or** a
  touchpad node on the USB bus exists (`*-kbd` / `*event-mouse` whose by-path
  name names a USB path). A bare i8042 keyboard never counts.
- The touchscreen also appears as a mouse, so the touchpad half is confirmed
  with `udevadm info --query=property`: `ID_INPUT_TOUCHPAD=1` for the base,
  `ID_INPUT_TABLET=1` for the slate's digitizer. One ~30 ms `udevadm` call per
  tick on a single node, so the gate stays cheap.
- `mode_reason` says `base` / `no base`; `status` prints `base: attached|absent
  (tablet)`; `probe` has a `== base ==` section listing the keyboard nodes and
  both USB verdicts, which is how the next hardware round gets diagnosed.

## Still to verify on the tablet

1. `krw-tablet probe` → `AccelerometerOrientation` live (not `undefined`), and
   `== base ==` agreeing with whether the base is on.
2. Detach the keyboard base: `journalctl --user -u krw-tablet` should show
   `tablet mode on (no base)` within a second, wvkbd appears on text focus,
   tilt in four directions: panel follows, taps and pen land where the finger
   is. If a direction is wrong, fix the mapping in `orientation_name` (or the
   mount matrix via `/etc/udev/hwdb.d/61-sensor-local.hwdb` if the sensor is
   rotated).
3. Re-attach the base: mode off, panel upright, wvkbd gone, lock cleared.
4. `hyprctl reload` while turned → stays turned.
5. `krw-tablet rotate lock`, tilt → no rotation; `rotate auto` → follows again.
6. With the external `DP-1` attached, check `position = "auto"` does not put
   the turned panel under the external display.
7. Noctalia: with `auto_hide = true` set by hand, detach the base and check the
   bar stays put in all four rotations and that its widgets are tappable;
   reattach and check the bar goes back to auto-hiding. Then
   `systemctl --user restart noctalia` while in tablet mode and
   `krw wm tablet` → `mode-on` to confirm the repair path.
