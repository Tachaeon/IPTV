# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the scripts

```powershell
# WPF browser (main app) — requires PowerShell 5.1, STA is handled automatically
powershell.exe -File .\IP-TV.ps1

# Local M3U launcher (mpv hardcoded to C:\Install\MPV\mpv.exe)
powershell.exe -File .\Local-FileIPTV.ps1

# Local M3U launcher (mpv must be on PATH)
powershell.exe -File .\Test-Stream.ps1
```

`mpv.exe` must be in the same folder as `IP-TV.ps1` (or edit `$mpvPath` near the top of the script). No modules or installs required beyond PowerShell 5.1.

## Architecture — IP-TV.ps1

Single-file WPF app. The entire UI is an inline XAML string loaded via `[Windows.Markup.XamlReader]::Load()`. Controls are retrieved by name with `$win.FindName('ControlName')`.

**Data flow:**
1. `$files` (here-string list of M3U filenames) + `$ProviderMap` → `Get-PlaylistMeta` builds display objects → bound to `$playlistView` (CollectionViewSource)
2. Selecting a playlist → `Load-SelectedPlaylist` → `Invoke-WebRequest` to `raw.githubusercontent.com/iptv-org/iptv/refs/heads/master/streams/<file>` → `ConvertFrom-M3U` → `$channelsView`
3. Double-clicking a channel → `Start-MpvInJob` → `Start-Job` launches mpv.exe non-blocking; a `DispatcherTimer` (500ms) polls the job and surfaces errors

**Key patterns:**
- `$script:` scope is required for variables shared across event handler ScriptBlocks (timers, jobs, pending selection)
- Live filtering uses `$view.Filter = { param($o) ... }` + `$view.Refresh()` on CollectionViewSource
- Favorites use `ObservableCollection[object]` so the WPF list updates live without rebinding
- Playlist selection uses a 300ms debounce DispatcherTimer (`$script:PlaylistSelectTimer`) to avoid loading on every keystroke during arrow-key navigation
- `ConvertFrom-M3U` walks lines looking for `#EXTINF:` entries, extracts attributes via regex, then grabs the next non-comment line as the URL

**Persistence:**
- Favorites: `%APPDATA%\IPTV-WPF\favorites.json` (Load-Favorites / Save-Favorites helpers)
- Local-FileIPTV favorites: `%APPDATA%\M3UStreamLauncher\favorites.json`

## Known TODOs (from script header)

- `favorites not deleting` — bug; `Remove-SelectedFavorite` matches by `StreamUrl` but may not find the item under certain conditions
- F2 to rename favorites
- Change mpv window title to channel name
- Auto-download mpv if not found at `$mpvPath`
- Favorite entire country/provider playlists (e.g. "Canada - Pluto TV")

## Adding new providers

Add an entry to `$ProviderMap` at the top of `IP-TV.ps1`:
```powershell
$ProviderMap = @{
    ...
    'newprovider' = 'Friendly Provider Name'
    ...
}
```
The key must match the suffix in the M3U filename (e.g. `us_newprovider.m3u` → key `'newprovider'`). New country files go in the `$files` here-string list.
