# IPTV Stream Launcher

A single-file web-based IPTV player. Builds a deduped, alphabetized stream list from multiple iptv-org feeds on page load, with logos overlaid from the iptv-org region playlists. Themes, favorites, recent list, group filter, category filters, A-Z jump strip, auto-skip dead streams, plenty of keyboard shortcuts. Includes an optional Cloudflare Worker proxy for streams that hit browser security restrictions.

**Live demo:** <https://tachaeon.github.io/IPTV/>

## Features

- **Combined-sources playlist auto-loads** — pulls from the iptv-org `us`, `uk`, `ca`, and `au` country files in parallel, deduplicates by URL, and alphabetizes
- **Logo enrichment, two passes** — region aggregates (`eur`, `amer`, `oce`) are fetched as metadata-only sources; logos overlay on matching stream URLs, then a name-based fallback fills any remaining gaps (e.g. duplicate "BBC News Pashto" entries share the same logo)
- **Category filter chips** — toggle Pluto / Shopping / Religious / Non-English on or off; state persists
- **A-Z jump strip** — vertical letter strip on the left of the streams list; click a letter to scroll to the first matching stream
- **Browse 200+ country/provider playlists** — pulled live from [iptv-org/iptv](https://github.com/iptv-org/iptv)
- **Load from file or URL** — open any local `.m3u` / `.m3u8` or paste a URL
- **Favorites** — right-click (or long-press) any stream to favorite
- **Recently played** — last 10 channels tracked automatically
- **Auto-resume** — picks up where you left off on page reload (scrolls to the playing row)
- **Auto-skip dead streams** — fails over to the next channel after 3 seconds
- **Failed-stream indicator** — red dot on streams that died, with a 24 h TTL so off-air channels get a fresh chance the next day
- **Group filter** — filter by `group-title` (Sports, News, Movies…)
- **Channel cycling** — ↑/↓ to surf without taking your hand off the keyboard
- **Random channel** — `R` to surprise yourself
- **Three themes** — Tokyo Night (dark), Light, Gruvbox
- **Resizable sidebar** — drag the right edge
- **Volume persistence** — remembers your level (and mute state) across sessions
- **Page fullscreen** — `F` key or button
- **Optional Cloudflare Worker proxy** — bypasses mixed-content / CORS so `http://` streams play on the live GH Pages site
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
| `cloudflare-worker/` | Serverless proxy for mixed-content / CORS bypass |
| `CLAUDE.md` | Architecture notes for contributors |
| `LICENSE` | MIT |
| `Archived/` | Legacy PowerShell apps and local dev server — see below |

## Local development

Open `index.html` directly in a browser. Works for all default sources because `iptv-org` and `raw.githubusercontent.com` both send CORS headers.

If you hit a CORS-blocked stream URL during testing, the archived `Archived/serve.ps1` provides a local dev server with a `/proxy` route. Copy it to the repo root and run:

```powershell
pwsh .\serve.ps1
# or
powershell .\serve.ps1
```

Serves on `http://localhost:8090` and opens the browser. The HLS.js loader inside `index.html` automatically routes requests through `/proxy` when running on `localhost`.

## Cloudflare Worker proxy (optional)

Many IPTV streams use `http://` URLs, which the browser refuses to load from the HTTPS GH Pages site (mixed-content blocking). The `cloudflare-worker/` folder contains a small serverless proxy that bypasses this — see [`cloudflare-worker/README.md`](cloudflare-worker/README.md) for first-time deployment steps.

Once deployed, set the `PROXY_URL` constant near the top of `index.html` to your worker URL. The app then routes `http://` streams through the worker automatically; HTTPS streams stay direct. The worker's free tier (100k req/day) supports several hours of daily streaming.

The proxy fixes mixed content + CORS + User-Agent rejections. It does NOT fix codec issues (H.265/AC3), DRM, RTMP/RTSP, or geo-blocking.

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
