# Night Light Sync

Applies a dedicated color palette and a wallpaper from a night directory while
Noctalia's night light is active, then restores the user's day palette and
wallpapers when it turns off. Theme dark mode is intentionally not used, because
it tracks the user's theme preference rather than the sun.

## Plugin

| Field | Value |
| --- | --- |
| ID | `kierownik/nightlight` |
| Entries | Service: `sync` |

## Requirements

Install `noctalia` on `PATH` (the plugin calls `noctalia msg color-scheme-get`,
`color-scheme-set`, and `wallpaper-get`).

Noctalia 5.5+ is required for the built-in night light watch hook.

## Usage

The service runs in the background. Enable it from the Noctalia plugin store; it
starts automatically and reconciles its state on startup.

While night light is active it:

- saves the current palette and per-output wallpapers,
- applies the configured night palette,
- picks a wallpaper from the configured night directory.

When night light turns off it restores the saved day palette and wallpapers.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `night_palette_source` | select (`builtin`, `custom`, `community`) | `custom` | Where the night palette comes from, matching `color-scheme-set` sources. |
| `night_palette` | string | `Ristretto` | Palette name without `.json` (for `custom`) used while night light is active. |
| `night_wallpapers_dir` | folder | `~/Pictures/Wallpapers-Night` | Directory night wallpapers are picked from. |

## IPC

```sh
noctalia msg plugin kierownik/nightlight:sync all update
```

Triggers a re-evaluation of the current night-light state.

## Notes

- State is persisted in the plugin data directory as `night-sync.json`.
- If the night directory is empty or missing, a message is logged once and no wallpaper is changed.
- On disable/uninstall while night is active, the saved day palette is restored.
- Network: none. Filesystem: reads/writes plugin state and the configured night wallpaper directory.