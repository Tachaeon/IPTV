# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A single-file IPTV web player hosted on GitHub Pages: <https://tachaeon.github.io/IPTV/>.

The only production-relevant files are:

- `index.html` — the entire web app (HTML + CSS + vanilla JS in one file)
- `favicon.svg`
- `All_Stations_FIXED.m3u8` — default playlist that auto-loads on page open
- `All_Stations.m3u` — older raw playlist (kept for reference)
- `serve.ps1` — optional local dev server with a `/proxy` route for CORS bypass

The PowerShell scripts `IP-TV.ps1`, `Local-FileIPTV.ps1`, `Test-Stream.ps1` are legacy mpv-based desktop apps. They're not part of the web flow — see [Legacy PowerShell apps](#legacy-powershell-apps) at the end.

## Running locally

Just open `index.html` in a browser — everything except the iptv-org Browse tab works over `file://` because `raw.githubusercontent.com` serves CORS headers.

If you need the CORS proxy (e.g. for testing a stream URL whose host blocks browser fetches):

```powershell
pwsh .\serve.ps1
# or
powershell .\serve.ps1
```

Serves on `http://localhost:8090`, auto-opens the browser. `/proxy?url=...` fetches server-side and adds `Access-Control-Allow-Origin: *`. The HLS.js proxy loader inside `index.html` routes all HLS fetches through this when running on `localhost`.

## Web app architecture (`index.html`)

No framework, no build step. Single `<script>` block. HLS.js loaded from CDN.

### State & storage

All `let`s at the top of the script (`allStreams`, `favorites`, `recents`, `failed`, etc.). All localStorage keys are prefixed `stream-launcher-`:

| Key | Purpose |
|---|---|
| `stream-launcher-favs` | Favorites array |
| `stream-launcher-last` | Last-played channel (for auto-resume) |
| `stream-launcher-recents` | Last 10 channels (Recent tab) |
| `stream-launcher-vol` | Saved volume (0..1) |
| `stream-launcher-muted` | Saved mute state |
| `stream-launcher-failed` | Set of URLs that failed to load |
| `stream-launcher-sidebar-width` | Custom sidebar width |
| `theme` | Active theme name |
| `sidebar-collapsed` | Sidebar collapsed flag |

The **Reset** button in the header wipes all of the above and reloads.

### Central functions

- `parseM3U(text)` — walks EXTINF/URL pairs, extracts `name`, `url`, `logo`, `group` (from `tvg-logo` / `group-title` attributes)
- `loadFromUrl(url, label, {switchTab})` — central playlist loader. Used by: file input, URL input prompt, default-playlist auto-load, Browse-tab clicks. Returns a promise.
- `renderList(items, containerId, store)` — used uniformly by Streams, Favorites, and Recent tabs. Adds the `playing` class to the currently-playing row and the `failed` class + red dot for previously-failed streams.
- `play(url, name)` — saves last-played, adds to Recents, cancels auto-skip, sets up HLS.js or native playback, updates `<title>`.
- `showError(msg)` — central error handler: shows the overlay, marks the URL as failed, schedules auto-skip 3s later.
- `wireList(containerId, store)` — attaches click, contextmenu, mouse long-press, and touch long-press handlers to a list container.
- `cycleChannel(dir)` — used by arrow keys + auto-skip. Cycles through whichever tab is currently active (Streams / Favs / Recent).

### Themes

CSS variables in `:root` define the default (Tokyo Night). Alternate themes are `[data-theme="light"]` and `[data-theme="gruvbox"]` blocks. An early-paint script in `<head>` reads `localStorage.theme` and sets the `data-theme` attribute *before* the body renders to avoid a flash of wrong theme.

A `--on-accent` variable is used wherever text sits on top of the accent color (e.g. `.btn-primary`) so it stays readable across themes.

### Keyboard shortcuts (all gated on focus not being in an input)

| Key | Action |
|---|---|
| `↑ / ↓` | Cycle channels in the active tab (only while playing) |
| `R` | Random channel from the active tab |
| `F` | Toggle page fullscreen |
| `T` | Toggle sidebar |
| `Esc` | Close context menu |

### Long-press

`wireList()` supports long-press (500ms hold, < 4px movement) for both mouse and touch — opens the same context menu as right-click. The follow-up click after a long-press calls `e.stopPropagation()` to keep the document-level `hideCtx` from immediately closing the just-opened menu.

### Browse tab

`PLAYLIST_FILES` (a hardcoded list of country/provider .m3u filenames) is mapped to `browseItems` with friendly labels via `PROVIDER_MAP` + `Intl.DisplayNames`. The first entry is a special `{ filename: '__DEFAULT__' }` row that re-loads `DEFAULT_M3U_URL` — gives users a way back to the original playlist after picking a country.

### Version label

A `<span class="version">v0.2.0</span>` in the footer. Bump manually on meaningful releases. Hover shows `document.lastModified` (the actual file's HTTP `Last-Modified` timestamp) — handy for confirming the browser served the new build vs. cached HTML.

## Editing `All_Stations_FIXED.m3u8`

Standard M3U format: `#EXTINF:...,Channel Name` then the URL on the next line. The file has had all Pluto streams stripped (search for "pluto" should return zero matches). Process EXTINF/URL pairs together when filtering — never operate on individual lines.

## Legacy PowerShell apps

These are independent mpv-launching desktop apps. Not connected to the web app or to `serve.ps1`.

```powershell
# WPF browser app — requires PowerShell 5.1, STA handled automatically
powershell.exe -File .\IP-TV.ps1

# Local M3U launcher (mpv hardcoded to C:\Install\MPV\mpv.exe)
powershell.exe -File .\Local-FileIPTV.ps1

# Local M3U launcher (mpv must be on PATH)
powershell.exe -File .\Test-Stream.ps1
```

`mpv.exe` must be at `$mpvPath` (top of each script). Favorites persist to `%APPDATA%\IPTV-WPF\favorites.json` (IP-TV.ps1) or `%APPDATA%\M3UStreamLauncher\favorites.json` (Local-FileIPTV.ps1).

`IP-TV.ps1` is a single-file WPF app — UI is an inline XAML string loaded via `[Windows.Markup.XamlReader]::Load()`. `$script:` scope is required for variables shared across event handler ScriptBlocks. Live filtering uses `$view.Filter = { ... } + $view.Refresh()` on a `CollectionViewSource`. Favorites are `ObservableCollection[object]` so the list updates without rebinding. Playlist selection is debounced 300ms to avoid loading on every arrow-key press.

To add a new provider, edit `$ProviderMap` at the top of `IP-TV.ps1` (the key must match the suffix in the M3U filename, e.g. `us_newprovider.m3u` → key `'newprovider'`). Add country filenames to the `$files` here-string list.
