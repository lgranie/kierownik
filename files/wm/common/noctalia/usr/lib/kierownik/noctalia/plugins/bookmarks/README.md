# Linkding Bookmarks

A Noctalia launcher provider that searches your Linkding bookmarks and opens them
in your browser.

## Plugin

| Field | Value |
| --- | --- |
| ID | `kierownik/bookmarks` |
| Entries | Launcher provider: `bookmarks` (prefix `/bookmarks`) |

## Usage

Type `/bookmarks` in the Noctalia launcher, then search. Selecting a bookmark
opens it in the configured browser. Categories can be selected to narrow results.

Update bookmarks from the Linkding server with the plugin's update action.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `browser` | string | `brave-browser` | Browser executable used to open bookmarks. |
| `token` | string | `` | Linkding session token. |
| `serverUrl` | string | `` | Linkding server URL. |

## Notes

- Bookmarks are cached locally in the plugin data directory (`database.json`,
  `usage.json`).
- Network: fetches bookmarks from the configured Linkding server. Filesystem:
  reads/writes plugin data files. Spawns the configured browser.