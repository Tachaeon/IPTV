# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A single-file IPTV web player hosted on GitHub Pages: <https://tachaeon.github.io/IPTV/>.

Production-relevant files (repo root):

- `index.html` — the entire web app (HTML + CSS + vanilla JS in one file)
- `favicon.svg`
- `README.md` / `CLAUDE.md` / `LICENSE`
- `cloudflare-worker/` — serverless proxy for mixed-content / CORS bypass; see [Cloudflare Worker proxy](#cloudflare-worker-proxy)
- `Archived/` — legacy PowerShell mpv apps and the older local dev server; not part of the web flow

## Running locally

Open `index.html` in a browser. The app fetches its default playlist from `iptv-org` over HTTPS, which sends CORS headers, so this works directly from `file://`.

If you need to test a stream URL whose host blocks browser fetches, copy `Archived/serve.ps1` to the repo root and run it. It serves on `http://localhost:8090` with a `/proxy?url=...` route that fetches server-side and adds `Access-Control-Allow-Origin: *`. The HLS.js loader inside `index.html` auto-routes through `/proxy` when running on `localhost`.

## Web app architecture (`index.html`)

No framework, no build step. Single `<script>` block. HLS.js loaded from CDN.

### Source loading

Two parallel arrays drive the default load:

- `STREAM_SOURCES` — raw iptv-org country playlists (`us`, `uk`, `ca`, `au`). Channels come **only** from these.
- `LOGO_SOURCES` — iptv-org region aggregates (`eur`, `amer`, `oce`). Used **only** as metadata. Their entries are parsed into a `metaMap` keyed by URL; any `tvg-logo`, `group-title`, and `tvg-language` they carry is overlaid onto matching stream entries.

`loadFromSources()` fetches all seven feeds via `Promise.allSettled` (one failure doesn't abort the rest), merges into a `streamMap` keyed by URL (dedupes across the country files), applies the URL-based metadata overlay, then runs a name-based logo fallback (normalized-name → logo map built from anything with a logo; backfills streams still missing one), then alphabetizes. No filtering happens here — the filter chip UI handles that at render time.

`normalizeChannelName(name)` strips quality markers (`(720p)`, `(1080p)`, `(4K)`, trailing `HD`/`SD`/`UHD`/`FHD`), bracket annotations (`[Geo-blocked]`, `[Not 24/7]`), and punctuation. So `BBC One (720p)` and `BBC One HD` both collapse to `bbc one` for matching.

### State & storage

State `let`s at the top of the script (`allStreams`, `favorites`, `recents`, `failed`, etc.). All localStorage keys are prefixed `stream-launcher-`:

| Key | Purpose |
|---|---|
| `stream-launcher-favs` | Favorites array |
| `stream-launcher-last` | Last-played channel (for auto-resume) |
| `stream-launcher-recents` | Last 10 channels (Recent tab) |
| `stream-launcher-vol` | Saved volume (0..1) |
| `stream-launcher-muted` | Saved mute state |
| `stream-launcher-failed` | Map of URL → timestamp of last failure (24h TTL) |
| `stream-launcher-sidebar-width` | Custom sidebar width |
| `stream-launcher-filters` | Filter chip state (pluto/shop/rel/noneng) |
| `theme` | Active theme name |
| `sidebar-collapsed` | Sidebar collapsed flag |

The **Reset** button in the header wipes all of these and reloads.

### Central functions

- `parseM3U(text)` — walks EXTINF/URL pairs, extracts `name`, `url`, `logo`, `group`, `language` (from `tvg-logo` / `group-title` / `tvg-language` attributes).
- `loadFromSources({switchTab})` — multi-source loader used by the page-load default load and the Browse tab's `__DEFAULT__` row. Returns a promise.
- `loadFromUrl(url, label, {switchTab})` — single-URL loader used by file input, URL prompt, and per-country Browse rows.
- `renderList(items, containerId, store)` — uniform renderer for Streams, Favorites, Recent. Adds `playing` class to the current row and `failed` class + red dot for streams marked failed *within the last 24 h* (uses `isFailed(url)` which lazy-prunes expired marks).
- `play(url, name)` — saves last-played, adds to Recents, cancels auto-skip, sets up HLS.js or native playback, updates `<title>`.
- `showError(msg)` — central error handler: shows the overlay, marks the URL as failed, schedules auto-skip in 3s.
- `wireList(containerId, store)` — attaches click, contextmenu, mouse long-press, and touch long-press handlers.
- `cycleChannel(dir)` — used by arrow keys + auto-skip. Cycles through whichever tab is currently active (Streams / Favs / Recent).
- `toggleFilter(key)` — flips one of the four filter chips and re-renders. `FILTER_PREDICATES` defines the four detectors (`pluto`, `shop`, `rel`, `noneng`).
- `updateAzJump()` / `jumpToLetter(letter)` — rebuilds the A-Z strip's first-occurrence index after every `filterStreams()`, and handles letter clicks by scrolling the matching row into view.
- `maybeProxy(url)` — decides whether to route a URL through `serve.ps1`'s `/proxy` (localhost), the Cloudflare Worker (production + http://), or pass through unchanged.

### Failed-mark TTL

`failed` is a `Map<url, timestamp>` (was a `Set`). Entries older than `FAILED_TTL_MS` (24 hours) are treated as not-failed and lazy-pruned on each `isFailed(url)` check. This handles channels that go off-air during off-hours: the red dot drops the next day. Legacy `Set`-format storage (a plain JSON array of URLs) is auto-migrated on load by stamping each URL with the current time.

### Filter chips

Four chip-style toggle buttons sit under the group dropdown: `Pluto`, `Shopping`, `Religious`, `Non-Eng`. Each, when active (`.chip.active`, accent-filled), removes streams matching its predicate from the rendered list. Predicates check both `group-title` and channel name; the `noneng` predicate only fires when `tvg-language` is present and not English, so untagged streams are kept.

`filterStreams()` applies them after the text search and group dropdown. Chips work on every load path — combined sources, file, URL, Browse — not just the default load.

### A-Z jump strip

A 14px-wide vertical strip on the *left* side of the streams list with 26 letter buttons (A-Z), each `flex: 1` so they distribute evenly down the list height. Letters with no matching first-character in `shownStreams` are dimmed and disabled. Clicking a letter calls `scrollIntoView({ block: 'start' })` on the first matching `.stream-item`. Index rebuilds on every `filterStreams()`, so it adapts to search, group filter, and category chips.

### Themes

CSS variables in `:root` define the default (Tokyo Night). Alternate themes are `[data-theme="light"]` and `[data-theme="gruvbox"]` blocks. An early-paint script in `<head>` reads `localStorage.theme` and sets the `data-theme` attribute *before* the body renders to avoid a flash of wrong theme.

A `--on-accent` variable is used wherever text sits on top of the accent color (e.g. `.btn-primary`, active chips) so it stays readable across themes.

### Keyboard shortcuts (gated on focus not being in an input)

| Key | Action |
|---|---|
| `↑ / ↓` | Cycle channels in the active tab (only while playing) |
| `R` | Random channel from the active tab |
| `F` | Toggle page fullscreen |
| `T` | Toggle sidebar |
| `Esc` | Close context menu |

### Long-press

`wireList()` supports long-press (500ms hold, < 4px movement) for both mouse and touch — opens the same context menu as right-click. The follow-up `click` after a long-press calls `e.stopPropagation()` to keep the document-level `hideCtx` handler from immediately closing the just-opened menu.

### Browse tab

`PLAYLIST_FILES` (a hardcoded list of country/provider `.m3u` filenames) is mapped to `browseItems` with friendly labels via `PROVIDER_MAP` + `Intl.DisplayNames`. The first entry is a special `{ filename: '__DEFAULT__' }` row that re-runs `loadFromSources()` — gives users a way back to the combined-sources playlist after picking a country.

### Version label

A `<span class="version">` in the footer. Bump manually on meaningful releases. Hover shows `document.lastModified` (the HTTP `Last-Modified` timestamp) — handy for confirming the browser served the new build vs. cached HTML.

## Cloudflare Worker proxy

`cloudflare-worker/worker.js` is a ~60-line serverless proxy that bypasses two browser limitations the GH-Pages-hosted app hits:

1. **Mixed-content blocking** — HTTPS page can't fetch `http://` resources.
2. **CORS rejections** — many stream servers don't send `Access-Control-Allow-Origin`.

The Worker fetches the target server-side (where neither restriction applies), forwards `Range` headers (for video seeking), spoofs a desktop Chrome `User-Agent` (some servers reject browser-default UAs), and streams the response back with permissive CORS headers.

### How it's wired

`index.html` has a `PROXY_URL` constant. When set, `maybeProxy(url)` routes `http://` stream URLs through the worker on production. HTTPS streams go direct so they don't burn the worker's free-tier quota (100k req/day).

The `ProxyLoader` for HLS.js wraps every fetch and re-writes the URL via `maybeProxy()`. **It also overrides `response.url` to the original (pre-proxy) URL inside `onSuccess`** — otherwise HLS.js would use the proxy URL as the base for resolving relative segment URLs in manifests, producing broken paths like `worker.dev/segment1.ts` instead of `origin.com/segment1.ts`. This URL preservation is the key bit; the Worker itself stays simple.

The non-HLS path (Safari native HLS, direct MP4 streams) also runs `vid.src = maybeProxy(url)`.

### Deployment

See `cloudflare-worker/README.md` for first-time deployment steps. Summary: create a Worker on cloudflare.com, paste `worker.js`, copy the URL, set `PROXY_URL` in `index.html`, push.

### Caveats

The proxy fixes mixed content + CORS + UA. It does NOT fix codec issues (browser can't decode H.265/AC3), DRM, non-HLS protocols (RTMP/RTSP), or geo-blocking.

## Archived

`Archived/` contains earlier iterations not part of the live web app:

- `IP-TV.ps1` — WPF browser app that fetched iptv-org playlists and launched streams in [mpv](https://mpv.io/). Single-file: UI is an inline XAML string loaded via `[Windows.Markup.XamlReader]::Load()`. `$script:` scope is required for variables shared across event handler ScriptBlocks. Live filtering uses `$view.Filter = { ... } + $view.Refresh()` on `CollectionViewSource`. Favorites are `ObservableCollection[object]` so the list updates without rebinding. Playlist selection is debounced 300ms.
- `Local-FileIPTV.ps1` — WinForms launcher for local M3U files. mpv path hardcoded to `C:\Install\MPV\mpv.exe`. Favorites at `%APPDATA%\M3UStreamLauncher\favorites.json`.
- `Test-Stream.ps1` — same as Local-FileIPTV but expects `mpv` on PATH.
- `serve.ps1` — local dev server with `/proxy` route. Copy back to root to use.

The three PowerShell apps all require `mpv.exe`. Favorites for `IP-TV.ps1` persist to `%APPDATA%\IPTV-WPF\favorites.json`. To add a new provider in `IP-TV.ps1`, edit `$ProviderMap` at the top (key must match the suffix in the M3U filename, e.g. `us_newprovider.m3u` → key `'newprovider'`); add country filenames to the `$files` here-string list.
