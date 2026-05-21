#requires -version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------- CONFIG ----------------
$mpvPath = "C:\Install\MPV\mpv.exe"   # set full path if needed
$favoritesFile = Join-Path $env:APPDATA "M3UStreamLauncher\favorites.json"

# Default M3U (works when run as .ps1 or copy/pasted; falls back to current directory)
$baseDir =
if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

#$defaultM3U = Join-Path $baseDir "All_Stations.m3u"
$defaultM3U = "C:\Projects\Scripts\IPTV\All_Stations.m3u"
# ----------------------------------------

function Ensure-FavoritesFolder {
    $dir = Split-Path -Parent $favoritesFile
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Parse-M3U {
    param([Parameter(Mandatory)][string]$Path)

    $lines = Get-Content -LiteralPath $Path -ErrorAction Stop
    $items = New-Object System.Collections.Generic.List[object]
    $pendingName = $null

    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line.StartsWith("#")) {
            if ($line -match '^#EXTINF:.*?,\s*(.*)\s*$') {
                $pendingName = $Matches[1]
            }
            continue
        }

        $items.Add([pscustomobject]@{
                Name = if ($pendingName) { $pendingName } else { $line }
                Url  = $line
            })
        $pendingName = $null
    }

    return $items
}

function Start-Mpv {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Title
    )

    # Quote title so spaces are preserved (PS 5.1 / CreateProcess parsing)
    $safeTitle = $Title -replace '"', '\"'
    $safeUrl = $Url -replace '"', '\"'
    $argString = "--force-window=yes --title=`"$safeTitle`" `"$safeUrl`""

    try {
        Start-Process -FilePath $mpvPath -ArgumentList $argString -ErrorAction Stop | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to start mpv.`n`n$($_.Exception.Message)`n`nmpv path: $mpvPath",
            "mpv Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Load-Favorites {
    Ensure-FavoritesFolder
    if (-not (Test-Path -LiteralPath $favoritesFile)) { return @() }

    try {
        $json = Get-Content -LiteralPath $favoritesFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) { return @() }

        $data = $json | ConvertFrom-Json
        if ($data -is [System.Array]) { return @($data) }
        return @($data)
    }
    catch {
        return @()
    }
}

function Save-Favorites {
    param([object]$Favs)

    Ensure-FavoritesFolder

    # Normalize to array (or empty array)
    $arr = @()
    if ($Favs -ne $null) { $arr = @($Favs) }

    $arr | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $favoritesFile -Encoding UTF8
}

function Find-FavoriteIndex {
    param(
        [object[]]$Favs = @(),
        [Parameter(Mandatory)][string]$Url
    )

    if (-not $Favs -or $Favs.Count -eq 0) { return -1 }

    for ($i = 0; $i -lt $Favs.Count; $i++) {
        if ($Favs[$i].Url -eq $Url) { return $i }
    }
    return -1
}

# State
$script:allStreams = @()

# Ensure favorites is ALWAYS an array (even if JSON returns single object)
$script:favorites = @()
$script:favorites += @(Load-Favorites)

function Fit-ListColumn {
    param([System.Windows.Forms.ListView]$lv)
    if ($lv -and $lv.Columns.Count -gt 0) {
        $lv.Columns[0].Width = $lv.ClientSize.Width - 4
    }
}

function Populate-StreamsList {
    param([string]$FilterText)

    $needle = ""
    if ($FilterText) { $needle = $FilterText.Trim().ToLowerInvariant() }

    $lvStreams.BeginUpdate()
    $lvStreams.Items.Clear()

    $filtered = if ($needle) {
        $script:allStreams | Where-Object { $_.Name.ToLowerInvariant().Contains($needle) }
    }
    else {
        $script:allStreams
    }

    $i = 0
    foreach ($s in $filtered) {
        $item = New-Object System.Windows.Forms.ListViewItem($s.Name)
        $item.Tag = $s.Url
        $item.BackColor = if ($i % 2) { [System.Drawing.Color]::FromArgb(248, 249, 251) } else { [System.Drawing.Color]::White }
        $null = $lvStreams.Items.Add($item)
        $i++
    }

    $lvStreams.EndUpdate()
    Fit-ListColumn $lvStreams

    if ($needle) {
        $statusLabel.Text = "Showing $($filtered.Count) of $($script:allStreams.Count)"
    }
    else {
        $statusLabel.Text = "Loaded $($script:allStreams.Count) streams"
    }
}

function Populate-FavoritesList {
    param([string]$FilterText)

    $needle = ""
    if ($FilterText) { $needle = $FilterText.Trim().ToLowerInvariant() }

    $lvFavs.BeginUpdate()
    $lvFavs.Items.Clear()

    $filtered = if ($needle) {
        $script:favorites | Where-Object { $_.Name.ToLowerInvariant().Contains($needle) }
    }
    else {
        $script:favorites
    }

    $i = 0
    foreach ($f in $filtered) {
        $item = New-Object System.Windows.Forms.ListViewItem($f.Name)
        $item.Tag = $f.Url
        $item.BackColor = if ($i % 2) { [System.Drawing.Color]::FromArgb(248, 249, 251) } else { [System.Drawing.Color]::White }
        $null = $lvFavs.Items.Add($item)
        $i++
    }

    $lvFavs.EndUpdate()
    Fit-ListColumn $lvFavs

    if ($needle) {
        $statusLabel.Text = "Favorites: showing $($filtered.Count) of $($script:favorites.Count)"
    }
    else {
        $statusLabel.Text = "Favorites: $($script:favorites.Count)"
    }
}

function Add-ToFavorites {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url
    )

    $idx = Find-FavoriteIndex -Favs $script:favorites -Url $Url
    if ($idx -ge 0) {
        $statusLabel.Text = "Already in favorites: $Name"
        return
    }

    # Array-safe append
    $script:favorites = @($script:favorites) + @([pscustomobject]@{ Name = $Name; Url = $Url })

    Save-Favorites -Favs $script:favorites
    Populate-FavoritesList -FilterText $txtSearch.Text
    $statusLabel.Text = "Added to favorites: $Name"
}

function Remove-FromFavorites {
    param([Parameter(Mandatory)][string]$Url)

    $idx = Find-FavoriteIndex -Favs $script:favorites -Url $Url
    if ($idx -lt 0) { return }

    $name = $script:favorites[$idx].Name
    $script:favorites = @($script:favorites | Where-Object { $_.Url -ne $Url })

    Save-Favorites -Favs $script:favorites
    Populate-FavoritesList -FilterText $txtSearch.Text
    $statusLabel.Text = "Removed from favorites: $name"
}

function Load-Playlist {
    param([Parameter(Mandatory)][string]$Path)

    try {
        $script:allStreams = Parse-M3U -Path $Path
        Populate-StreamsList -FilterText $txtSearch.Text
    }
    catch {
        $statusLabel.Text = "Failed to load playlist."
        [System.Windows.Forms.MessageBox]::Show(
            "Could not read/parse:`n$Path`n`n$($_.Exception.Message)",
            "Parse Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

# ---------------- UI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Stream Launcher"
$form.Size = New-Object System.Drawing.Size(620, 540)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(620, 420)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.BackColor = [System.Drawing.Color]::White

# ---- Fill area FIRST ----
$card = New-Object System.Windows.Forms.Panel
$card.Dock = "Fill"
$card.Padding = 0
$card.BackColor = [System.Drawing.Color]::White

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = "Fill"
$tabs.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$card.Controls.Add($tabs)

$tabStreams = New-Object System.Windows.Forms.TabPage
$tabStreams.Text = "Streams"
$tabStreams.BackColor = [System.Drawing.Color]::White
$tabStreams.Padding = New-Object System.Windows.Forms.Padding(8)

$tabFavs = New-Object System.Windows.Forms.TabPage
$tabFavs.Text = "Favorites"
$tabFavs.BackColor = [System.Drawing.Color]::White
$tabFavs.Padding = New-Object System.Windows.Forms.Padding(8)

$tabs.TabPages.Add($tabStreams) | Out-Null
$tabs.TabPages.Add($tabFavs)   | Out-Null

# Streams list
$lvStreams = New-Object System.Windows.Forms.ListView
$lvStreams.Dock = "Fill"
$lvStreams.View = "Details"
$lvStreams.FullRowSelect = $true
$lvStreams.MultiSelect = $false
$lvStreams.GridLines = $false
$lvStreams.BorderStyle = "FixedSingle"
$lvStreams.HideSelection = $false
$lvStreams.HeaderStyle = "None"
$null = $lvStreams.Columns.Add("Stream", 600)
$tabStreams.Controls.Add($lvStreams)

# Favorites list
$lvFavs = New-Object System.Windows.Forms.ListView
$lvFavs.Dock = "Fill"
$lvFavs.View = "Details"
$lvFavs.FullRowSelect = $true
$lvFavs.MultiSelect = $false
$lvFavs.GridLines = $false
$lvFavs.BorderStyle = "FixedSingle"
$lvFavs.HideSelection = $false
$lvFavs.HeaderStyle = "None"
$null = $lvFavs.Columns.Add("Favorite", 600)
$tabFavs.Controls.Add($lvFavs)

# ---- Controls bar (Top) ----
$controls = New-Object System.Windows.Forms.Panel
$controls.Dock = "Top"
$controls.Height = 56
$controls.Padding = New-Object System.Windows.Forms.Padding(16, 12, 16, 8)
$controls.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = "Open"
$btnOpen.Width = 90
$btnOpen.Height = 30
$btnOpen.FlatStyle = "Flat"
$btnOpen.Location = New-Object System.Drawing.Point(16, 12)
$controls.Controls.Add($btnOpen)

# Search label (left of textbox)
$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = "Search"
$lblSearch.AutoSize = $true
$lblSearch.Location = New-Object System.Drawing.Point(116, 18)
$controls.Controls.Add($lblSearch)

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Width = 420
$txtSearch.Location = New-Object System.Drawing.Point(170, 14)
$controls.Controls.Add($txtSearch)

# ---- Header ----
$header = New-Object System.Windows.Forms.Panel
$header.Dock = "Top"
$header.Height = 42
$header.BackColor = [System.Drawing.Color]::FromArgb(32, 33, 36)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "M3U Stream Launcher"
$script:BannerBase = "M3U Stream Launcher"
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14)
$lblTitle.Location = New-Object System.Drawing.Point(16, 9)
$lblTitle.AutoSize = $true
$header.Controls.Add($lblTitle)

# ---- Status bar (with hint on right) ----
$status = New-Object System.Windows.Forms.StatusStrip

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Spring = $true
$statusLabel.TextAlign = 'MiddleLeft'
$statusLabel.Text = "Open an M3U file to begin"

$hintStatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$hintStatusLabel.Text = "Right-click: favorites • Double-click/Enter: play"
$hintStatusLabel.TextAlign = 'MiddleRight'
$hintStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)

$null = $status.Items.Add($statusLabel)
$null = $status.Items.Add($hintStatusLabel)

$form.Controls.Add($card)
$form.Controls.Add($controls)
$form.Controls.Add($header)
$form.Controls.Add($status)

# ---- Dialog ----
$openDialog = New-Object System.Windows.Forms.OpenFileDialog
$openDialog.Filter = "M3U Playlists (*.m3u;*.m3u8)|*.m3u;*.m3u8"

# ---- Context menus ----
$ctxStreams = New-Object System.Windows.Forms.ContextMenuStrip
$miAddFav = New-Object System.Windows.Forms.ToolStripMenuItem
$miAddFav.Text = "Add to Favorites"
$null = $ctxStreams.Items.Add($miAddFav)
$lvStreams.ContextMenuStrip = $ctxStreams

$ctxFavs = New-Object System.Windows.Forms.ContextMenuStrip
$miRemoveFav = New-Object System.Windows.Forms.ToolStripMenuItem
$miRemoveFav.Text = "Remove from Favorites"
$null = $ctxFavs.Items.Add($miRemoveFav)
$lvFavs.ContextMenuStrip = $ctxFavs

# Ensure right-click selects the item under cursor (Streams)
$lvStreams.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            $hit = $lvStreams.HitTest($e.Location)
            if ($hit.Item -ne $null) {
                $lvStreams.SelectedItems.Clear()
                $hit.Item.Selected = $true
            }
        }
    })

# Ensure right-click selects the item under cursor (Favorites)
$lvFavs.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            $hit = $lvFavs.HitTest($e.Location)
            if ($hit.Item -ne $null) {
                $lvFavs.SelectedItems.Clear()
                $hit.Item.Selected = $true
            }
        }
    })

$miAddFav.Add_Click({
        if ($lvStreams.SelectedItems.Count -eq 0) { return }
        $item = $lvStreams.SelectedItems[0]
        Add-ToFavorites -Name $item.Text -Url ([string]$item.Tag)
    })

$miRemoveFav.Add_Click({
        if ($lvFavs.SelectedItems.Count -eq 0) { return }
        $item = $lvFavs.SelectedItems[0]
        Remove-FromFavorites -Url ([string]$item.Tag)
    })

# ---- Play helpers for both tabs ----
function Play-SelectedInListView {
    param([System.Windows.Forms.ListView]$lv)

    $form.cursor = [System.Windows.Forms.Cursors]::WaitCursor
    if ($lv.SelectedItems.Count -eq 0) { return }
    $item = $lv.SelectedItems[0]

    # Update the banner text to reflect the last launched stream
    if ($lblTitle -ne $null) {
        $base = if ($script:BannerBase) { $script:BannerBase } else { "M3U Stream Launcher" }
        $lblTitle.Text = "$base - MPV Launched $($item.Text)"
    }

    Start-Mpv -Url ([string]$item.Tag) -Title $item.Text
    $form.cursor = [System.Windows.Forms.Cursors]::Default
}

$lvStreams.Add_DoubleClick({ Play-SelectedInListView -lv $lvStreams })
$lvFavs.Add_DoubleClick({ Play-SelectedInListView -lv $lvFavs })

$lvStreams.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq 'Enter') { $e.SuppressKeyPress = $true; Play-SelectedInListView -lv $lvStreams }
    })
$lvFavs.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq 'Enter') { $e.SuppressKeyPress = $true; Play-SelectedInListView -lv $lvFavs }
    })

# ---- Events ----
$btnOpen.Add_Click({
        if ($openDialog.ShowDialog() -eq 'OK') {
            Load-Playlist -Path $openDialog.FileName
        }
    })

$txtSearch.Add_TextChanged({
        if ($tabs.SelectedTab -eq $tabFavs) {
            Populate-FavoritesList -FilterText $txtSearch.Text
        }
        else {
            Populate-StreamsList -FilterText $txtSearch.Text
        }
    })

$tabs.Add_SelectedIndexChanged({
        if ($tabs.SelectedTab -eq $tabFavs) {
            Populate-FavoritesList -FilterText $txtSearch.Text
        }
        else {
            Populate-StreamsList -FilterText $txtSearch.Text
        }
    })

$form.Add_Shown({
        # Load favorites tab contents
        Populate-FavoritesList -FilterText $txtSearch.Text

        # Auto-load default playlist if present (BeginInvoke avoids UI timing issues)
        if (Test-Path -LiteralPath $defaultM3U) {
            $form.BeginInvoke([Action] {
                    Load-Playlist -Path $defaultM3U
                    $statusLabel.Text = "Loaded default playlist: $defaultM3U"
                }) | Out-Null
        }
        else {
            $statusLabel.Text = "Default playlist not found: $defaultM3U"
        }

        Fit-ListColumn $lvStreams
        Fit-ListColumn $lvFavs
    })

$form.Add_Resize({
        Fit-ListColumn $lvStreams
        Fit-ListColumn $lvFavs
    })

#Make PowerShell Disappear
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

#Force garbage collection just to start slightly lower RAM usage.
[void][System.GC]::Collect()

[void]$form.ShowDialog()