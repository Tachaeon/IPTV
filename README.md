# IPTV Stream Launcher

A single-file web-based IPTV player. Open the link, hit play, watch streams. Themes, favorites, recent list, group filter, auto-skip dead streams, plenty of keyboard shortcuts.

**Live demo:** <https://tachaeon.github.io/IPTV/>

## Features

- **Default playlist auto-loads** — `All_Stations_FIXED.m3u8` from this repo
- **Browse 200+ country/provider playlists** — pulled live from [iptv-org/iptv](https://github.com/iptv-org/iptv)
- **Load from file or URL** — open any local `.m3u` / `.m3u8` or paste a URL
- **Favorites** — right-click (or long-press) any stream to favorite
- **Recently played** — last 10 channels tracked automatically
- **Auto-resume** — picks up where you left off on page reload (scrolls to the playing row)
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
- **Version label** in the footer; hover for last-modified timestamp

## Keyboard shortcuts

| Key | Action |
|---|---|
| `↑` / `↓` | Cycle channels in the active tab (while playing) |
| `R` | Random channel from the active tab |
| `F` | Toggle page fullscreen |
| `T` | Toggle sidebar |
| `Esc` | Close context menu |

Click any stream to play. Right-click (or long-press on touch / hold left-click on mouse) to manage favorites.

## Files

| File | Purpose |
|---|---|
| `index.html` | The entire web app (HTML + CSS + vanilla JS in one file) |
| `favicon.svg` | Site icon |
| `All_Stations_FIXED.m3u8` | Default playlist (auto-loads on page open) |
| `CLAUDE.md` | Architecture notes for contributors |
| `LICENSE` | MIT |
| `Archived/` | Legacy PowerShell apps and local dev server — see below |

## Local development

Open `index.html` directly in a browser. Works for most streams since `raw.githubusercontent.com` sends CORS headers, and so do most public stream hosts.

If you hit a CORS-blocked source, the archived `Archived/serve.ps1` provides a local dev server with a `/proxy` route. Copy it to the repo root and run:

```powershell
pwsh .\serve.ps1
# or
powershell .\serve.ps1
```

Serves on `http://localhost:8090` and opens the browser. The HLS.js loader inside `index.html` automatically routes requests through `/proxy` when running on `localhost`.

## Archived

The `Archived/` folder contains earlier iterations of this project that are no longer part of the live web app:

| File | What it was |
|---|---|
| `IP-TV.ps1` | WPF browser app that fetched iptv-org playlists and launched streams in [mpv](https://mpv.io/) |
| `Local-FileIPTV.ps1` | WinForms launcher for local M3U files (mpv path hardcoded) |
| `Test-Stream.ps1` | Same as Local-FileIPTV but expected `mpv` on PATH |
| `serve.ps1` | Local dev server with `/proxy` route for CORS bypass |

All three PowerShell apps required `mpv.exe`. They're kept for reference. See [CLAUDE.md](CLAUDE.md) for architecture details.

## License

MIT — see [LICENSE](LICENSE).
