# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A single-file IPTV web player hosted on GitHub Pages: <https://tachaeon.github.io/TachTV/>.

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

No framework, no build step. Single `<script>` block. HLS.js (light variant) loaded from CDN with `crossorigin="anonymous"` so its errors come through with details.

### Source loading

Two parallel arrays drive the default load:

- `STREAM_SOURCES` — 46 raw iptv-org country/provider playlists across `us` (32 variants), `uk` (5), `ca` (4), `au` (2), and `nz` (2). Channels come **only** from these.
- `LOGO_SOURCES` — iptv-org region aggregates (`eur`, `amer`, `oce`). Used **only** as metadata for logo/group/language enrichment. **Skipped on TV** since logos aren't rendered there.

`loadFromSources()` fetches all sources via `Promise.allSettled` (one failure doesn't abort the rest), merges into a `streamMap` keyed by URL (dedupes across overlapping country files like `us.m3u` + `us_pluto.m3u`), applies the URL-based metadata overlay, runs a name-based logo fallback (normalized-name → logo map built from anything with a logo; backfills streams still missing one), then alphabetizes. After parsing each source's response text, the raw string is dropped (`r.value = null`) so GC can reclaim it before the rest of processing runs.

`normalizeChannelName(name)` strips quality markers (`(720p)`, `(1080p)`, `(4K)`, trailing `HD`/`SD`/`UHD`/`FHD`), bracket annotations (`[Geo-blocked]`, `[Not 24/7]`), and punctuation. So `BBC One (720p)` and `BBC One HD` both collapse to `bbc one` for matching.

`parseM3U` only sets `group`, `language`, `logo` fields on the returned object when actually populated, keeping object shapes compact when EXTINF lines lack those attributes.

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
| `stream-launcher-filters` | Filter chip state (pluto/shop/rel/noneng/geo) |
| `theme` | Active theme name |
| `sidebar-collapsed` | Sidebar collapsed flag |

The **Reset** button in the header wipes all of these and reloads.

### Central functions

- `parseM3U(text)` — walks EXTINF/URL pairs, extracts `name`, `url`, plus `logo`/`group`/`language` only when present.
- `loadFromSources({switchTab})` — multi-source loader; used by page-load default and Browse tab's `__DEFAULT__` row. Returns a promise.
- `loadFromUrl(url, label, {switchTab})` — single-URL loader used by file input, URL prompt, and per-country Browse rows.
- `renderList(items, containerId, store)` — uniform renderer. On TV + `lst-streams`, delegates to `renderVirtual` for windowed rendering; otherwise renders the full list. Adds `playing` and `failed` classes.
- `renderVirtual(el, items)` — virtual scrolling: phantom container with full virtual height, absolutely-positioned window containing only visible rows + 8-row buffer. `requestAnimationFrame`-throttled scroll handler swaps rows.
- `scrollListToIndex(listId, idx, block)` — helper for `cycleChannel` / `jumpToLetter` / auto-resume. On the virtualized list uses `scrollTop = idx * TV_ROW_HEIGHT` (with center/nearest variants); elsewhere falls back to `items[idx].scrollIntoView`.
- `play(url, name)` — saves last-played, adds to Recents, cancels auto-skip, sets up HLS.js or native playback via `maybeProxy()`, updates `<title>`.
- `showError(msg)` — central error handler: shows the overlay, marks the URL as failed, schedules auto-skip in 3s.
- `wireList(containerId, store)` — attaches click, contextmenu, mouse long-press, touch long-press handlers.
- `cycleChannel(dir)` — used by arrow keys + auto-skip. Cycles through whichever tab is currently active.
- `toggleFilter(key)` — flips one of the five filter chips and re-renders. `FILTER_PREDICATES` defines the detectors (`pluto`, `shop`, `rel`, `noneng`, `geo`).
- `openSettings()` / `closeSettings(e)` — show/hide the centered settings modal. Closes via X button, backdrop click, or `Esc`.
- `exportFavorites()` — serializes `favorites` to JSON, triggers download as `tach-tv-favorites-YYYY-MM-DD.json`.
- Favorites import handler (on `#fav-import` change) — reads + parses JSON, validates each entry has `name`+`url`, merges by URL into existing favorites (won't clobber duplicates).
- `toggleCinema()` — toggles `body.cinema-mode` (retracts header/footer/sidebar). `C` hotkey or visible X button or `Esc`.
- `toggleFullscreen()` / `updateFsIcon()` — page fullscreen via `document.documentElement.requestFullscreen()`. Activity-tracked auto-hide for native `<video>` controls + cursor while in fullscreen (`fsActivity`/`fsShow`/`fsHide`, 3-second idle, capture-phase listeners on `mousemove`/`mousedown`/`click`/`keydown`/`touchstart`/`touchmove`/`wheel`).
- `updateAzJump()` / `jumpToLetter(letter)` — rebuilds the A-Z strip's first-occurrence index after every `filterStreams()`. Short-circuits on TV (strip is hidden).
- `maybeProxy(url)` — routes a URL through `serve.ps1`'s `/proxy` on localhost, through the Cloudflare Worker for `http://` URLs on production, or passes through unchanged.

### TV mode (`IS_TV`)

User-Agent regex detects LG WebOS / Samsung Tizen / generic SmartTV/HbbTV/Viera/Hisense. When matched, `IS_TV = true` and `body.is-tv` class is set. Mode triggers many separate optimizations to fit constrained TV RAM/CPU:

| Optimization | What it does |
|---|---|
| **Skip `<img>` tags in stream rows** | `renderList` omits the `<img class="stream-logo">` entirely — biggest single win at ~1500 rows |
| **Skip the 3 `LOGO_SOURCES` fetches** | No region-metadata HTTP requests, no `metaMap` allocation, no name-based logo fallback pass |
| **Skip `tvg-logo=` regex** in `parseM3U` | Less work per EXTINF line |
| **Omit `logo` field from stream objects** | Smaller per-entry object across thousands of entries |
| **`body.is-tv` CSS overrides** | All `transition`/`animation`/`:hover` effects killed via `!important`; `stream-list::-webkit-scrollbar` width 0 |
| **`.tv-hidden` class** | Hides desktop-only UI on TV (currently: Open URL + Open M3U buttons) |
| **`.tv-only` class** | Shows TV-only UI (the simpler footer hint: "Select: play · ↑/↓: cycle channels · Favorite: long press") |
| **Hide A-Z jump strip** | `body.is-tv .az-jump { display: none }`; `updateAzJump` short-circuits to skip rebuild work |
| **Virtual scrolling on `lst-streams`** | Only ~30 rows in DOM at a time (visible + 8-row buffer); fixed `28px` row height via `body.is-tv .stream-item { height:28px }` |
| **Lazy-built Browse tab** | `browseItems` is `null` until first `switchTab('browse')`; `ensureBrowseBuilt()` runs the 290-entry `PLAYLIST_FILES.map` then |

The Reset / theme / cinema-toggle / fullscreen buttons all stay accessible on TV.

### Older-browser compatibility (WebOS 4/5, etc.)

LG WebOS pre-2021 ships Chromium 38–68; Samsung Tizen similar vintage. Several down-levels are in place to avoid parse/runtime aborts on these:

- `Promise.allSettled` (Chromium 76+) — polyfilled in head from `Promise.all` + per-promise reflection
- `Intl.DisplayNames` (Chromium 81+) — wrapped in try/catch; on failure, Browse-tab labels fall back to bare country codes (`US`/`GB`/`CA`)
- `async/await` (Chromium 55+) — `loadFromSources` is a plain function returning `.then()` chains
- Object spread `{...a, ...b}` (Chromium 60+) — replaced with `Object.assign({}, a, b)`
- Optional `catch {}` (Chromium 66+) — all `catch` clauses bind `(e)`
- `class extends` (Chromium 49+) — `ProxyLoader` uses prototype-based ES5 (`Object.create` + `Function.prototype.call`)
- Default parameters (Chromium 49+) — `loadFromUrl` does `opts = opts || {}` inside the body

An early `<script>` in `<head>` installs `window.onerror` and `unhandledrejection` listeners that write the failure into the `#status` element — gives a visible diagnostic on TV browsers without dev tools. The end of the main script writes `"[boot OK] loading…"` into the badge so we can tell the script reached EOF.

### Failed-mark TTL

`failed` is a `Map<url, timestamp>` (was a `Set`). Entries older than `FAILED_TTL_MS` (24 hours) are treated as not-failed and lazy-pruned on each `isFailed(url)` check. This handles channels that go off-air during off-hours: the red dot drops the next day. Legacy `Set`-format storage (a plain JSON array of URLs) is auto-migrated on load by stamping each URL with the current time.

### Filter chips

Five chip-style toggle buttons under the group dropdown: `Pluto`, `Shopping`, `Religious`, `Non-Eng`, `Geo-blocked`. Each, when active (`.chip.active`, accent-filled), removes streams matching its predicate from the rendered list. Predicates check both `group-title` and channel name; the `noneng` predicate only fires when `tvg-language` is present and not English, so untagged streams are kept; `geo` matches `geo-blocked`/`geoblocked`/`geo blocked` in the name (catches iptv-org's `[Geo-blocked]` annotation).

`filterStreams()` applies them after the text search and group dropdown. Chips work on every load path — combined sources, file, URL, Browse — not just the default load.

### A-Z jump strip (desktop only)

A 14px-wide vertical strip on the *left* side of the streams list with 26 letter buttons. Each `flex: 1` so they distribute evenly down the list height. Letters with no matching first-character in `shownStreams` are dimmed and disabled. Clicking calls `scrollListToIndex('lst-streams', idx, 'start')`. Index rebuilds on every `filterStreams()`. Hidden on TV.

### Themes

CSS variables in `:root` define the default (Tokyo Night). Alternate themes are `[data-theme="light"]` and `[data-theme="gruvbox"]` blocks. An early-paint script in `<head>` reads `localStorage.theme` and sets the `data-theme` attribute *before* the body renders to avoid a flash of wrong theme. A `--on-accent` variable handles text on accent-color buttons across themes.

### Settings modal

A centered overlay (`.modal-backdrop` + `.modal`) triggered by the gear icon in the header. Four sections:

- **Appearance** — theme `<select>` (was previously in the header)
- **Favorites** — Export to dated JSON, Import from JSON (URL-dedupe merge)
- **Data** — Reset all saved data (was previously in the header, now danger-styled)
- **About** — version + `document.lastModified`

Closes on X click, click outside the inner modal (handled in `closeSettings(e)` by checking `e.target === backdrop`), or `Esc`. Moving theme + reset into the modal de-cluttered the header significantly.

### Cinema mode

`toggleCinema()` flips a `body.cinema-mode` class. CSS hides `.header`, `.footer`, and `.sidebar` so only the video remains. A fixed-position `.cinema-exit` X button (top-right, transparent with drop-shadow + 50% opacity, full opacity on hover) gives a click-out path that works regardless of input device — important on TVs without a `C` key. `Esc` also exits cinema mode. Triggered by the rectangle icon in the header, the `C` hotkey, or the X overlay.

### Fullscreen auto-hide

While in fullscreen, controls + cursor stay visible until 3 seconds of no input. Capture-phase listeners on `mousemove`/`mousedown`/`click`/`keydown`/`touchstart`/`touchmove`/`wheel` call `fsActivity()` which calls `fsShow()` (re-adds `controls` attribute, removes `body.fs-idle` class) and schedules `fsHide()` 3s later. `fsHide()` removes the `controls` attribute and adds `body.fs-idle` (sets `cursor: none` everywhere). Exiting fullscreen cancels the timer and restores controls.

### Keyboard shortcuts (gated on focus not being in an input)

| Key | Action |
|---|---|
| `↑ / ↓` | Cycle channels in the active tab (only while playing) |
| `R` | Random channel from the active tab |
| `F` | Toggle page fullscreen |
| `C` | Toggle cinema mode |
| `T` | Toggle sidebar |
| `Esc` | Close context menu + exit cinema mode |

### Long-press

`wireList()` supports long-press (500ms hold, < 4px movement) for both mouse and touch — opens the same context menu as right-click. The follow-up `click` after a long-press calls `e.stopPropagation()` to keep the document-level `hideCtx` handler from immediately closing the just-opened menu.

### Browse tab

`PLAYLIST_FILES` (a hardcoded list of country/provider `.m3u` filenames) is mapped to `browseItems` with friendly labels via `PROVIDER_MAP` + `Intl.DisplayNames` (guarded). On TV (and to save startup CPU on all devices), `browseItems` is `null` until the first `switchTab('browse')` triggers `ensureBrowseBuilt()`. The first entry is a special `{ filename: '__DEFAULT__' }` row that re-runs `loadFromSources()` — gives users a way back to the combined-sources playlist after picking a country.

### Version label

A `<span class="version">` in the footer. Bump manually on meaningful releases. Hover shows `document.lastModified` (the HTTP `Last-Modified` timestamp) — handy for confirming the browser served the new build vs. cached HTML.

## Cloudflare Worker proxy

`cloudflare-worker/worker.js` is a ~60-line serverless proxy that bypasses two browser limitations the GH-Pages-hosted app hits:

1. **Mixed-content blocking** — HTTPS page can't fetch `http://` resources.
2. **CORS rejections** — many stream servers don't send `Access-Control-Allow-Origin`.

The Worker fetches the target server-side (where neither restriction applies), forwards `Range` headers (for video seeking), spoofs a desktop Chrome `User-Agent` (some servers reject browser-default UAs), and streams the response back with permissive CORS headers.

### How it's wired

`index.html` has a `PROXY_URL` constant. When set, `maybeProxy(url)` routes `http://` stream URLs through the worker on production. HTTPS streams go direct so they don't burn the worker's free-tier quota (100k req/day).

The `ProxyLoader` for HLS.js wraps every fetch and re-writes the URL via `maybeProxy()`. **It also overrides `response.url` to the original (pre-proxy) URL inside `onSuccess`** — otherwise HLS.js would use the proxy URL as the base for resolving relative segment URLs in manifests, producing broken paths like `worker.dev/segment1.ts` instead of `origin.com/segment1.ts`. This URL preservation is the key bit; the Worker itself stays simple. `ProxyLoader` is a prototype-based constructor (not a `class extends`) for older-browser compatibility.

The non-HLS path (Safari native HLS, direct MP4 streams) also runs `vid.src = maybeProxy(url)`.

### Deployment

See `cloudflare-worker/README.md` for first-time deployment steps. Summary: create a Worker on cloudflare.com (use "Start with Hello World!"), paste `worker.js`, copy the URL, set `PROXY_URL` in `index.html`, push.

### Caveats

The proxy fixes mixed content + CORS + UA. It does NOT fix codec issues (browser can't decode H.265/AC3), DRM, non-HLS protocols (RTMP/RTSP), or geo-blocking.

## Archived

`Archived/` contains earlier iterations not part of the live web app:

- `IP-TV.ps1` — WPF browser app that fetched iptv-org playlists and launched streams in [mpv](https://mpv.io/). Single-file: UI is an inline XAML string loaded via `[Windows.Markup.XamlReader]::Load()`. `$script:` scope is required for variables shared across event handler ScriptBlocks. Live filtering uses `$view.Filter = { ... } + $view.Refresh()` on `CollectionViewSource`. Favorites are `ObservableCollection[object]` so the list updates without rebinding. Playlist selection is debounced 300ms.
- `Local-FileIPTV.ps1` — WinForms launcher for local M3U files. mpv path hardcoded to `C:\Install\MPV\mpv.exe`. Favorites at `%APPDATA%\M3UStreamLauncher\favorites.json`.
- `Test-Stream.ps1` — same as Local-FileIPTV but expects `mpv` on PATH.
- `serve.ps1` — local dev server with `/proxy` route. Copy back to root to use.

The three PowerShell apps all require `mpv.exe`. Favorites for `IP-TV.ps1` persist to `%APPDATA%\IPTV-WPF\favorites.json`. To add a new provider in `IP-TV.ps1`, edit `$ProviderMap` at the top (key must match the suffix in the M3U filename, e.g. `us_newprovider.m3u` → key `'newprovider'`); add country filenames to the `$files` here-string list.
