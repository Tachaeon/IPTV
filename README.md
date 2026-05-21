# IPTV Stream Launcher

A single-file web-based IPTV player. Builds a deduped, alphabetized stream list from multiple iptv-org feeds on page load, with logos overlaid from the iptv-org region playlists. Themes, favorites, recent list, group filter, category filters, auto-skip dead streams, plenty of keyboard shortcuts.

**Live demo:** <https://tachaeon.github.io/IPTV/>

## Features

- **Combined-sources playlist auto-loads** — pulls from the iptv-org `us`, `uk`, `ca`, and `au` country files in parallel, deduplicates by URL, and alphabetizes
- **Logo enrichment** — region aggregates (`eur`, `amer`, `oce`) are fetched as metadata-only sources; their station logos overlay matching stream URLs
- **Category filter chips** — toggle Pluto / Shopping / Religious / Non-English on or off; state persists
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
- **Volume persistence** — remembers your level (and mute state) across sessions
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
| `All_Stations_FIXED.m3u8` | Dormant — kept around but no longer referenced by the app |
| `CLAUDE.md` | Architecture notes for contributors |
| `LICENSE` | MIT |
| `Archived/` | Legacy PowerShell apps and local dev server — see below |

## Local development

Open `index.html` directly in a browser. Works for all default sources because `iptv-org` and `raw.githubusercontent.com` both send CORS headers.

If you hit a CORS-blocked stream URL, the archived `Archived/serve.ps1` provides a local dev server with a `/proxy` route. Copy it to the repo root and run:

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

The three PowerShell apps all required `mpv.exe`. Kept for reference. See [CLAUDE.md](CLAUDE.md) for architecture details.

## License

MIT — see [LICENSE](LICENSE).
