# Tach TV

A single-file web-based IPTV player. Builds a deduped, alphabetized stream list from ~50 iptv-org country/provider feeds on page load, with logos overlaid from the iptv-org region playlists. Settings menu with theme switcher and favorites import/export. Cinema mode, category filters, A-Z jump strip, auto-skip dead streams, plenty of keyboard shortcuts. Optimized for smart TVs. Optional Cloudflare Worker proxy for streams that hit browser security restrictions.

**Live demo:** <https://tachaeon.github.io/TachTV/>

## Features

- **Combined-sources playlist auto-loads** — 46 iptv-org feeds across US, UK, CA, AU, NZ (and provider variants: Pluto, Samsung TV Plus, BBC, Distro, Stingray, Roku, Xumo, Plex, Tubi, …) merged + deduped on page load
- **Logo enrichment, two passes** — region aggregates (`eur`, `amer`, `oce`) supply logos; URL-keyed overlay first, then normalized-name fallback so duplicate channels share artwork
- **Settings modal** — gear icon in the header opens a centered modal with Theme switcher, **Export / Import favorites** (JSON backup, URL-dedupe merge on import), Reset all data, and About info
- **Five category filter chips** — toggle Pluto / Shopping / Religious / Non-English / Geo-blocked; state persists
- **A-Z jump strip** — vertical letter strip on the left of the streams list; click to scroll to first matching channel
- **Cinema mode** — `C` (or icon, or X overlay) retracts header / footer / sidebar for a distraction-free view
- **Smart TV optimized** — auto-detects LG WebOS / Samsung Tizen / generic SmartTV; logos skipped, virtual scrolling on the streams list (~30 DOM rows vs 1500+), CSS effects killed, Browse tab lazy-built. Works on WebOS 5 (2020 LG OLED CX) and newer.
- **Browse 200+ country/provider playlists** — pulled live from [iptv-org/iptv](https://github.com/iptv-org/iptv)
- **Load from file or URL** — open any local `.m3u` / `.m3u8` or paste a URL
- **Favorites + share** — right-click (or long-press) a stream for a menu: favorite toggle, **Copy share link** (a deep link like `?play=...&name=...` that opens the app pre-tuned to that channel — uses Web Share API on mobile when available), or **Copy stream URL** (the raw `.m3u8`/`.m3u` for use in external players)
- **Recently played** — last 10 channels tracked automatically
- **Auto-resume** — picks up where you left off on page reload (scrolls to the playing row)
- **Auto-skip dead streams** — fails over to the next channel after 3 seconds
- **Failed-stream indicator** — red dot on streams that died; 24 h TTL so off-air channels get a fresh chance the next day
- **Group filter** — dropdown filter by `group-title` (Sports, News, Movies…)
- **Channel cycling** — ↑/↓ to surf without taking your hand off the keyboard
- **Random channel** — `R` to surprise yourself
- **Three themes** — Tokyo Night (dark), Light, Gruvbox (picker lives in Settings)
- **Resizable sidebar** — drag the right edge
- **Volume persistence** — remembers your level (and mute state) across sessions
- **Page fullscreen** — `F` key or button; native `<video>` controls + cursor auto-hide after 3s idle while in fullscreen
- **Optional Cloudflare Worker proxy** — bypasses mixed-content / CORS so `http://` streams play on the live GH Pages site
- **Version label** in the footer; hover for last-modified timestamp

## Keyboard shortcuts

| Key | Action |
|---|---|
| `↑` / `↓` | Cycle channels in the active tab (while playing) |
| `R` | Random channel from the active tab |
| `F` | Toggle page fullscreen |
| `C` | Toggle cinema mode (hide header/footer/sidebar) |
| `T` | Toggle sidebar |
| `Esc` | Close context menu + exit cinema mode |

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

## Smart TV support

The app auto-detects LG WebOS / Samsung Tizen / generic SmartTV user agents and adjusts:

- Skips rendering logo `<img>` tags (the biggest TV memory hog)
- Skips fetching the 3 region-metadata feeds entirely
- Drops irrelevant UI (Open URL, Open M3U buttons, A-Z strip)
- Virtual scrolling on the streams list — only ~30 rows in the DOM at once
- Lazy-builds the Browse tab
- All CSS transitions / animations / hover effects disabled
- Replaces the desktop hint bar with a TV-friendly one mentioning the OK button and long-press

Older WebOS browsers (Chromium 38–68, found on 2018–2020 model years) are also supported via:

- `Promise.allSettled` polyfill
- `Intl.DisplayNames` guard (falls back to bare country codes if the API is missing)
- ES2015-targeted JS (no async/await, object spread, optional `catch {}`, or `class extends`)
- An inline `window.onerror` handler that writes failures to the visible status bar — critical for diagnosis on devices without dev tools

## Local development

Open `index.html` directly in a browser. Works for all default sources because `iptv-org` and `raw.githubusercontent.com` both send CORS headers.

If you hit a CORS-blocked stream URL, the archived `Archived/serve.ps1` provides a local dev server with a `/proxy` route. Copy it to the repo root and run:

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
