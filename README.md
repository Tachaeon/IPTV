# IPTV Stream Launcher

A single-file web-based IPTV player. Open the link, hit play, watch streams. Themes, favorites, recent list, group filter, auto-skip dead streams, plenty of keyboard shortcuts.

**Live demo:** <https://tachaeon.github.io/IPTV/>

## Features

- **Default playlist auto-loads** — `All_Stations_FIXED.m3u8` from this repo
- **Browse 200+ country/provider playlists** — pulled live from [iptv-org/iptv](https://github.com/iptv-org/iptv)
- **Load from file or URL** — open any local `.m3u` / `.m3u8` or paste a URL
- **Favorites** — right-click (or long-press) any stream to favorite
- **Recently played** — last 10 channels tracked automatically
- **Auto-resume** — picks up where you left off on page reload
- **Auto-skip dead streams** — fails over to the next channel after 3 seconds
- **Group filter** — filter by `group-title` (Sports, News, Movies…)
- **Channel cycling** — ↑/↓ to surf without taking your hand off the keyboard
- **Random channel** — `R` to surprise yourself
- **Failed-stream indicator** — red dot on streams that died, persists across sessions
- **Three themes** — Tokyo Night (dark), Light, Gruvbox
- **Resizable sidebar** — drag the right edge
- **Volume persistence** — remembers your level across sessions
- **Page fullscreen** — `F` key or button
- **Reset button** — clear all saved data in one click

## Keyboard shortcuts

| Key | Action |
|---|---|
| `↑` / `↓` | Cycle channels in the active tab (while playing) |
| `R` | Random channel from the active tab |
| `F` | Toggle page fullscreen |
| `T` | Toggle sidebar |
| `Esc` | Close context menu |

Click any stream to play. Right-click (or long-press on touch / hold left-click on mouse) to manage favorites.

## Local development

Open `index.html` directly in a browser — works for most streams, since `raw.githubusercontent.com` sends CORS headers.

If you need the CORS proxy for testing a stream URL whose host blocks browser fetches, run the included PowerShell dev server:

```powershell
pwsh .\serve.ps1
# or
powershell .\serve.ps1
```

Serves on `http://localhost:8090` and opens the browser. Provides a `/proxy?url=...` route that fetches server-side and adds `Access-Control-Allow-Origin: *`. The HLS.js loader inside `index.html` routes all HLS fetches through this when running on `localhost`.

## Files

| File | Purpose |
|---|---|
| `index.html` | The entire web app (HTML + CSS + vanilla JS in one file) |
| `favicon.svg` | Site icon |
| `All_Stations_FIXED.m3u8` | Default playlist (auto-loads on page open; Pluto streams removed) |
| `All_Stations.m3u` | Older raw playlist, kept for reference |
| `serve.ps1` | Optional local dev server with CORS proxy |
| `IPTV_Playlist_Rules.txt` | Rules for cleaning and normalizing M3U playlists |
| `CLAUDE.md` | Architecture notes for contributors |

## Playlist cleanup rules

`IPTV_Playlist_Rules.txt` documents the ordered rules used to clean and normalize M3U playlists:

1. Remove geo-blocked streams
2. Remove streams below 720p
3. Keep one 1080p/HLS version per channel
4. Remove exact duplicates (same `tvg-id` + URL)
5. Remove non-English channels
6. Remove religious channels
7. Remove Telemundo
8. Normalize all `tvg-id` values to empty (`tvg-id=""`)
9. Sort alphabetically by name
10. Optional: validate with `ffprobe` (10 s timeout), remove failures

## Legacy PowerShell apps

The repo also includes three older PowerShell apps that launch streams in [mpv](https://mpv.io/) on Windows desktop. These are independent of the web app — kept because they still work.

| Script | What it does |
|---|---|
| `IP-TV.ps1` | WPF browser; fetches iptv-org playlists by country/provider |
| `Local-FileIPTV.ps1` | WinForms launcher for local M3U files (mpv path hardcoded to `C:\Install\MPV\mpv.exe`) |
| `Test-Stream.ps1` | Same as `Local-FileIPTV` but expects `mpv` on PATH |

All three require `mpv.exe`. Favorites persist to `%APPDATA%\IPTV-WPF\favorites.json` (WPF app) or `%APPDATA%\M3UStreamLauncher\favorites.json` (the WinForms launchers). See [CLAUDE.md](CLAUDE.md) for architecture details.

## License

MIT — see [LICENSE](LICENSE).
