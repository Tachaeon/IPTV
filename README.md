# IPTV

A collection of PowerShell IPTV tools for browsing, searching, and playing live streams via mpv.exe. Includes a WPF playlist browser that pulls from the [iptv-org/iptv](https://github.com/iptv-org/iptv) repository, a local M3U file launcher, and a playlist cleanup rule set.

## Scripts

```
IP-TV.ps1                  # WPF browser — fetches iptv-org playlists by country/provider
Local-FileIPTV.ps1         # WinForms launcher for local M3U files (hardcoded mpv path)
Test-Stream.ps1            # WinForms launcher for local M3U files (mpv on PATH)
All_Stations.m3u           # Curated local playlist (used as default by Local-FileIPTV and Test-Stream)
IPTV_Playlist_Rules.txt    # Rules for cleaning and normalizing M3U playlists
Needs-MPV.txt              # Dependency reminder — mpv.exe required
Needs-ffprobe.txt          # Dependency reminder — ffprobe required for stream validation
```

## IP-TV.ps1 — WPF Playlist Browser

Fetches M3U playlists on demand from `raw.githubusercontent.com/iptv-org/iptv` and presents them in a two-panel WPF window.

**UI layout:**
- Left panel: full country/provider playlist list with search filter
- Right panel: tabbed Channels and Favorites views, each with search
- Single-click a playlist to auto-load it (300 ms debounce); double-click also works
- Right-click a channel → Add to Favorites
- Right-click a favorite → Remove from Favorites
- Double-click a channel or favorite → play in mpv

**Requirements:**
- PowerShell 5.1+ (script auto-relaunches itself in STA mode if needed for WPF)
- `mpv.exe` placed in the same folder as the script (or edit `$mpvPath`)
- Internet access to download playlists from iptv-org

**Favorites** are persisted per-user at `%APPDATA%\IPTV-WPF\favorites.json`.

## Local-FileIPTV.ps1 — Local M3U Launcher

WinForms stream launcher for locally stored M3U files. Auto-loads `All_Stations.m3u` on startup. Provides an Open button to browse for any `.m3u`/`.m3u8` file.

**Requirements:**
- PowerShell 5.1
- `mpv.exe` at `C:\Install\MPV\mpv.exe` (hardcoded; edit `$mpvPath` to change)

**Favorites** stored at `%APPDATA%\M3UStreamLauncher\favorites.json`.

## Test-Stream.ps1 — Simpler Local Launcher

Functionally identical to `Local-FileIPTV.ps1` but expects `mpv.exe` to be on the system PATH rather than a hardcoded location. Use this version on machines where mpv is installed globally.

## IPTV_Playlist_Rules.txt — Playlist Cleanup Rules

Ordered rules for cleaning and normalizing M3U playlists (intended to be applied manually or fed to an AI/script):

1. Remove geo-blocked streams
2. Remove streams below 720p
3. Prefer highest resolution — keep one 1080p/HLS version per channel
4. Remove exact duplicates (same tvg-id + URL)
5. Remove non-English channels
6. Remove religious channels
7. Remove Telemundo
8. Normalize all `tvg-id` values to empty (`tvg-id=""`)
9. Sort channels alphabetically by name
10. Optional: validate streams with ffprobe (10 s timeout), remove failures

## Dependencies

| Tool | Used By | Notes |
|------|---------|-------|
| `mpv.exe` | All launchers | Place next to `IP-TV.ps1`; `C:\Install\MPV\mpv.exe` for `Local-FileIPTV.ps1`; on PATH for `Test-Stream.ps1` |
| `ffprobe` | Playlist cleanup (optional) | Only needed for stream validation step in cleanup rules |
