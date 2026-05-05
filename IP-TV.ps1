<# 
IPTV WPF Browser + Persistent Favorites (JSON)

UI:
- Left: Playlists (Country / Provider) with search
- Right: Tabs for Channels + Favorites (each with search)
- Double-click playlist -> Load
- Double-click channel  -> Play
- Right-click channel   -> Add to Favorites
- Right-click favorite  -> Remove from Favorites
- Double-click favorite -> Play

Notes:
- WPF requires STA. This script will relaunch itself in STA when run as a .ps1 file.
- mpv.exe should be in the SAME folder as this script (or edit $mpvPath).

To do:
- change mpv title
- F2 to rename favorites
- favorites not deleting
- download install mvp if not found
- fav entire countries
 - - canada pluto
#>

# ----------------------------
# Ensure STA for WPF (relaunch if needed)
# ----------------------------
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    if ($PSCommandPath) {
        $ps = (Get-Process -Id $PID).Path
        $args = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        Start-Process -FilePath $ps -ArgumentList $args | Out-Null
        exit
    }
    else {
        Write-Warning "WPF works best in STA. Run this as a .ps1 file with: powershell.exe -STA -File .\iptv_wpf_favorites.ps1"
    }
}

# ----------------------------
# CONFIG
# ----------------------------
$base = 'https://raw.githubusercontent.com/iptv-org/iptv/refs/heads/master/streams/'

# Resolve script directory robustly (works even if launched from elsewhere)
$scriptDir =
if ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
elseif ($psISE -and $psISE.CurrentFile -and $psISE.CurrentFile.FullPath) {
    Split-Path -Parent $psISE.CurrentFile.FullPath
}
else {
    (Get-Location).Path
}

$mpvPath = Join-Path $scriptDir 'mpv.exe'

# Favorites storage (per-user)
$favDir = Join-Path $env:APPDATA 'IPTV-WPF'
$favPath = Join-Path $favDir 'favorites.json'

function Load-Favorites {
    if (-not (Test-Path $favPath)) { return @() }
    try {
        $raw = Get-Content -Path $favPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $data) { return @() }
        @($data)
    }
    catch {
        @()
    }
}

function Save-Favorites {
    param([Parameter(Mandatory)]$FavList)

    if (-not (Test-Path $favDir)) {
        New-Item -ItemType Directory -Path $favDir -Force | Out-Null
    }

    $FavList | ConvertTo-Json -Depth 8 |
    Set-Content -Path $favPath -Encoding UTF8
}

# Provider key -> Friendly name (keys MUST be quoted)
$ProviderMap = @{
    'pluto' = 'Pluto TV'; 'plutotv' = 'Pluto TV'; 'samsung' = 'Samsung TV Plus'; 'rakuten' = 'Rakuten TV'
    'bbc' = 'BBC'; 'xumo' = 'Xumo'; 'tubi' = 'Tubi'; 'plex' = 'Plex'; 'roku' = 'Roku'; 'stirr' = 'Stirr'
    'tcl' = 'TCL'; 'firetv' = 'Fire TV'; 'amagi' = 'Amagi'; 'local' = 'Local'; 'pbs' = 'PBS'
    'canelatv' = 'Canela TV'; 'cbsn' = 'CBSN'; 'abcnews' = 'ABC News'; 'onetv' = 'OneTV'; 'gem' = 'GEM'
    'yowi' = 'YoWi'; 'bonustv' = 'BonusTV'; 'catcast' = 'Catcast'; 'ntv' = 'NTV'; 'rt' = 'RT'
    'smotrim' = 'Smotrim'; 'televizor24' = 'Televizor24'; 'tvbricks' = 'TVBricks'; 'tvteleport' = 'TVTeleport'
    'zabava' = 'Zabava'; 'morescreens' = 'MoreScreens'; 'opencaster' = 'OpenCaster'; 'freevisiontv' = 'FreevisionTV'
    'multimedios' = 'Multimedios'; 'wfmz' = 'WFMZ'; 'ssh101' = 'SSH101'; 'v2hcdn' = 'V2HCDN'
    'cctv' = 'CCTV'; 'cgtn' = 'CGTN'; 'yeslivetv' = 'YesLiveTV'; 'lenz' = 'Lenz'; 'telewebion' = 'Telewebion'
    'wnslive' = 'WNSLive'; 'happywatch99' = 'HappyWatch99'; 'sportstribal' = 'SportsTribal'; 'distro' = 'Distro'
    'sofast' = 'Sofast'; 'frequency' = 'Frequency'; 'glewedtv' = 'GlewedTV'; 'klowdtv' = 'KlowdTV'
    'moveonjoy' = 'MoveOnJoy'; 'cineversetv' = 'CineverseTV'
    '30a' = '30A'; '3abn' = '3ABN'; '112114' = '112114'
}

# Full filename list (as you provided)
$files = @'
ad.m3u
ae.m3u
af.m3u
ag.m3u
al.m3u
am.m3u
ao.m3u
ar.m3u
at.m3u
at_plutotv.m3u
at_samsung.m3u
au.m3u
au_samsung.m3u
aw.m3u
az.m3u
ba.m3u
ba_morescreens.m3u
bb.m3u
bd.m3u
be.m3u
be_samsung.m3u
bf.m3u
bg.m3u
bh.m3u
bi.m3u
bj.m3u
bm.m3u
bn.m3u
bo.m3u
bq.m3u
br.m3u
br_pluto.m3u
br_samsung.m3u
bs.m3u
bw.m3u
by.m3u
bz.m3u
bz_nexgen.m3u
ca.m3u
ca_pluto.m3u
ca_samsung.m3u
ca_stingray.m3u
cd.m3u
cf.m3u
cg.m3u
ch.m3u
ch_pluto.m3u
ch_samsung.m3u
ci.m3u
cl.m3u
cm.m3u
cn.m3u
cn_112114.m3u
cn_cctv.m3u
cn_cgtn.m3u
cn_yeslivetv.m3u
co.m3u
cr.m3u
cu.m3u
cv.m3u
cw.m3u
cy.m3u
cz.m3u
de.m3u
de_pluto.m3u
de_rakuten.m3u
de_samsung.m3u
dj.m3u
dk.m3u
dk_samsung.m3u
dm.m3u
do.m3u
dz.m3u
ec.m3u
ee.m3u
eg.m3u
eh.m3u
er.m3u
es.m3u
es_pluto.m3u
es_rakuten.m3u
es_samsung.m3u
es_yowi.m3u
et.m3u
fi.m3u
fi_rakuten.m3u
fi_samsung.m3u
fj.m3u
fm.m3u
fo.m3u
fr.m3u
fr_bfm.m3u
fr_fashiontv.m3u
fr_groupecanalplus.m3u
fr_groupem6.m3u
fr_persiana.m3u
fr_pluto.m3u
fr_rakuten.m3u
fr_samsung.m3u
ga.m3u
ge.m3u
gf.m3u
gh.m3u
gl.m3u
gm.m3u
gn.m3u
gp.m3u
gq.m3u
gr.m3u
gt.m3u
gu.m3u
gy.m3u
hk.m3u
hn.m3u
hr.m3u
ht.m3u
hu.m3u
id.m3u
ie.m3u
ie_samsung.m3u
il.m3u
in.m3u
in_samsung.m3u
iq.m3u
ir.m3u
ir_lenz.m3u
ir_telewebion.m3u
ir_wnslive.m3u
is.m3u
it.m3u
it_pluto.m3u
it_rakuten.m3u
it_samsung.m3u
jm.m3u
jo.m3u
jp.m3u
ke.m3u
kg.m3u
kh.m3u
kh_happywatch99.m3u
km.m3u
kn.m3u
kp.m3u
kr.m3u
kw.m3u
kz.m3u
la.m3u
lb.m3u
lc.m3u
li.m3u
lk.m3u
lr.m3u
lt.m3u
lu.m3u
lu_samsung.m3u
lv.m3u
ly.m3u
ma.m3u
mc.m3u
md.m3u
me.m3u
mg.m3u
mk.m3u
ml.m3u
mm.m3u
mn.m3u
mo.m3u
mq.m3u
mr.m3u
mt.m3u
mt_smashplus.m3u
mu.m3u
mv.m3u
mw.m3u
mx.m3u
mx_amagi.m3u
mx_multimedios.m3u
mx_pluto.m3u
mx_samsung.m3u
my.m3u
mz.m3u
na.m3u
ne.m3u
ng.m3u
ni.m3u
nl.m3u
nl_samsung.m3u
no.m3u
no_samsung.m3u
np.m3u
nz.m3u
nz_samsung.m3u
om.m3u
pa.m3u
pe.m3u
pe_opencaster.m3u
pf.m3u
pg.m3u
ph.m3u
pk.m3u
pl.m3u
pl_mediateka.m3u
pl_rakuten.m3u
pr.m3u
ps.m3u
pt.m3u
pt_samsung.m3u
py.m3u
qa.m3u
ro.m3u
rs.m3u
ru.m3u
ru_bonustv.m3u
ru_catcast.m3u
ru_mylifeisgood.m3u
ru_ntv.m3u
ru_rt.m3u
ru_smotrim.m3u
ru_televizor24.m3u
ru_tvbricks.m3u
ru_tvteleport.m3u
ru_zabava.m3u
rw.m3u
sa.m3u
sd.m3u
se.m3u
se_samsung.m3u
sg.m3u
si.m3u
si_xploretv.m3u
sk.m3u
sl.m3u
sm.m3u
sn.m3u
so.m3u
so_premiumfree.m3u
sr.m3u
st.m3u
sv.m3u
sx.m3u
sy.m3u
td.m3u
tg.m3u
th.m3u
th_v2hcdn.m3u
tj.m3u
tl.m3u
tm.m3u
tn.m3u
tr.m3u
tr_gem.m3u
tr_onetv.m3u
tt.m3u
tw.m3u
tz.m3u
ua.m3u
ug.m3u
uk.m3u
uk_bbc.m3u
uk_pluto.m3u
uk_rakuten.m3u
uk_samsung.m3u
uk_sportstribal.m3u
us.m3u
us_30a.m3u
us_3abn.m3u
us_abcnews.m3u
us_amagi.m3u
us_canelatv.m3u
us_cbsn.m3u
us_cineversetv.m3u
us_distro.m3u
us_firetv.m3u
us_frequency.m3u
us_glewedtv.m3u
us_klowdtv.m3u
us_local.m3u
us_moveonjoy.m3u
us_pbs.m3u
us_plex.m3u
us_pluto.m3u
us_roku.m3u
us_samsung.m3u
us_sofast.m3u
us_ssh101.m3u
us_stirr.m3u
us_tcl.m3u
us_tubi.m3u
us_tvpass.m3u
us_vizio.m3u
us_wfmz.m3u
us_xumo.m3u
uy.m3u
uz.m3u
va.m3u
ve.m3u
vg.m3u
vi.m3u
vn.m3u
ws.m3u
xk.m3u
ye.m3u
yt.m3u
za.m3u
za_freevisiontv.m3u
zm.m3u
zw.m3u
'@ -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($_ -notmatch '^\s*#') }

# ----------------------------
# Helpers
# ----------------------------

function Resolve-CountryName {
    param([Parameter(Mandatory)][string]$Code)

    $cc = $Code.ToLower()

    # "uk" isn't an ISO region code in .NET; use GB.
    if ($cc -eq 'uk') { $cc = 'gb' }

    # Some codes may not exist in RegionInfo on certain systems.
    try {
        $ri = [System.Globalization.RegionInfo]::new($cc.ToUpper())
        if ($ri -and $ri.EnglishName) { return $ri.EnglishName }
    }
    catch {}

    return $Code.ToUpper()
}

function ConvertFrom-M3U {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$M3UText)

    $lines = ($M3UText -replace "`r`n", "`n" -replace "`r", "`n").Split("`n")

    function Get-ExtInfAttrs([string]$extinfLine) {
        $attrs = @{}
        foreach ($m in [regex]::Matches($extinfLine, '([\w-]+)="([^"]*)"')) {
            $attrs[$m.Groups[1].Value] = $m.Groups[2].Value
        }
        $attrs
    }

    $items = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if (-not $line) { continue }

        if ($line -like '#EXTINF:*') {
            $attrs = Get-ExtInfAttrs $line

            $name = $null
            $k = $line.LastIndexOf(',')
            if ($k -ge 0 -and $k -lt ($line.Length - 1)) { $name = $line.Substring($k + 1).Trim() }

            $url = $null
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                $next = $lines[$j].Trim()
                if (-not $next) { continue }
                if ($next -like '#*') { continue }
                $url = $next
                $i = $j
                break
            }

            $items.Add([pscustomobject]@{
                    Name      = $name
                    Group     = $attrs['group-title']
                    StreamUrl = $url
                })
        }
    }

    $items
}

function Get-PlaylistMeta {
    param([Parameter(Mandatory)][string]$File)

    $name = $File.Replace('.m3u', '')
    $parts = $name -split '_'
    $countryCode = $parts[0].ToLower()

    # Prefer map if you later decide to add a small override table; fallback to RegionInfo.
    $countryName = Resolve-CountryName -Code $countryCode

    $providerKey = $null
    if ($parts.Count -gt 1) {
        $providerKey = ($parts[1..($parts.Count - 1)] -join '_').ToLower()
    }

    $providerName = $null
    if ($providerKey) {
        $providerName = $ProviderMap[$providerKey]
        if (-not $providerName) { $providerName = $ProviderMap[($providerKey -split '_')[0]] }
        if (-not $providerName) { $providerName = $providerKey }
    }

    [pscustomobject]@{
        Display  = if ($providerName) { "$countryName ($providerName)" } else { $countryName }
        Country  = $countryName
        Provider = $providerName
        File     = $File
        RawUrl   = "$base$File"
    }
}

# mpv in a job (non-blocking UI)
$script:mpvJob = $null

function Start-MpvInJob {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url
    )

    if (-not (Test-Path $mpvPath)) {
        [System.Windows.MessageBox]::Show(
            "mpv.exe not found at:`n$mpvPath`n`nPut mpv.exe in the SAME folder as this script.",
            "mpv missing", "OK", "Error"
        ) | Out-Null
        return
    }

    # Cleanup previous job object (does not kill mpv)
    if ($script:mpvJob -and ($script:mpvJob.State -in 'Running', 'NotStarted', 'Completed', 'Failed', 'Stopped')) {
        try { Stop-Job $script:mpvJob -Force -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job $script:mpvJob -Force -ErrorAction SilentlyContinue } catch {}
        $script:mpvJob = $null
    }

    Set-Status "Starting mpv (background): $Name"

    $script:mpvJob = Start-Job -Name 'mpv-player' -ArgumentList $mpvPath, $Url -ScriptBlock {
        param($path, $url)
        try {
            $p = Start-Process -FilePath $path -ArgumentList @($url) -PassThru -WindowStyle Normal
            $p.WaitForExit()
            [pscustomobject]@{ Started = $true; ExitCode = $p.ExitCode; Error = $null }
        }
        catch {
            [pscustomobject]@{ Started = $false; ExitCode = $null; Error = $_.Exception.Message }
        }
    }

    # Watch for completion and notify (timer on UI thread)
    if (-not $script:mpvWatchTimer) {
        $script:mpvWatchTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:mpvWatchTimer.Interval = [TimeSpan]::FromMilliseconds(500)
        $script:mpvWatchTimer.Add_Tick({
                if ($script:mpvJob -and $script:mpvJob.State -eq 'Completed') {
                    $result = Receive-Job $script:mpvJob -ErrorAction SilentlyContinue
                    Remove-Job $script:mpvJob -Force -ErrorAction SilentlyContinue
                    $script:mpvJob = $null

                    if ($result -and -not $result.Started) {
                        [System.Windows.MessageBox]::Show(
                            "Failed to start mpv.`n`nError:`n$($result.Error)",
                            "mpv error", "OK", "Error"
                        ) | Out-Null
                    }
                    elseif ($result -and $result.ExitCode -ne 0) {
                        [System.Windows.MessageBox]::Show(
                            "mpv exited with code $($result.ExitCode).",
                            "mpv exited", "OK", "Warning"
                        ) | Out-Null
                    }

                    Set-Status "Ready."
                    $script:mpvWatchTimer.Stop()
                }
            })
    }

    $script:mpvWatchTimer.Start()
    Set-Status "mpv launched: $Name"
}

# ----------------------------
# WPF UI
# ----------------------------
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="IPTV Browser"
        Width="1100" Height="740"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResizeWithGrip">

  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Status -->
    <DockPanel Grid.Row="0" Margin="0,0,0,8">
      <TextBlock Name="StatusText"
                 Text="Ready."
                 FontSize="14"
                 FontWeight="SemiBold"/>
    </DockPanel>

    <!-- Main -->
    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="1.2*"/>
      </Grid.ColumnDefinitions>

      <!-- LEFT: Playlists -->
      <GroupBox Header="Playlists (Country / Provider)"
                Grid.Column="0"
                Margin="0,0,6,0">
        <Grid Margin="8">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <TextBox Name="PlaylistSearch"
                   Height="28"
                   Margin="0,0,0,8"
                   ToolTip="Type to filter playlists"/>

          <ListView Name="PlaylistList"
                    Grid.Row="1"
                    SelectionMode="Single">
            <ListView.View>
              <GridView>
                <GridViewColumn Header="Name"
                                DisplayMemberBinding="{Binding Display}"
                                Width="320"/>
                <GridViewColumn Header="File"
                                DisplayMemberBinding="{Binding File}"
                                Width="180"/>
              </GridView>
            </ListView.View>
          </ListView>
        </Grid>
      </GroupBox>

      <!-- RIGHT: Channels + Favorites (aligned) -->
      <GroupBox Header="Channels / Favorites"
                Grid.Column="1"
                Margin="6,0,0,0">
        <Grid Margin="8">
          <TabControl Name="RightTabs">

            <!-- Channels tab -->
            <TabItem Header="Channels">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <TextBox Name="ChannelSearch"
                         Height="28"
                         Margin="0,0,0,8"
                         ToolTip="Type to filter channels"/>

                <ListView Name="ChannelList"
                          Grid.Row="1"
                          SelectionMode="Single">
                  <ListView.View>
                    <GridView>
                      <GridViewColumn Header="Name"
                                      DisplayMemberBinding="{Binding Name}"
                                      Width="430"/>
                      <GridViewColumn Header="Group"
                                      DisplayMemberBinding="{Binding Group}"
                                      Width="220"/>
                    </GridView>
                  </ListView.View>
                </ListView>
              </Grid>
            </TabItem>

            <!-- Favorites tab -->
            <TabItem Header="Favorites">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <TextBox Name="FavSearch"
                         Height="28"
                         Margin="0,0,0,8"
                         ToolTip="Type to filter favorites"/>

                <ListView Name="FavList"
                          Grid.Row="1"
                          SelectionMode="Single">
                  <ListView.View>
                    <GridView>
                      <GridViewColumn Header="Name"
                                      DisplayMemberBinding="{Binding Name}"
                                      Width="430"/>
                      <GridViewColumn Header="Playlist"
                                      DisplayMemberBinding="{Binding PlaylistDisplay}"
                                      Width="240"/>
                    </GridView>
                  </ListView.View>
                </ListView>
              </Grid>
            </TabItem>

          </TabControl>
        </Grid>
      </GroupBox>
    </Grid>

    <!-- Buttons -->
    <StackPanel Grid.Row="2"
                Orientation="Horizontal"
                HorizontalAlignment="Right"
                Margin="0,8,0,0">
      <Button Name="LoadBtn"
              Content="Load"
              Width="90"
              Height="32"
              Margin="0,0,8,0"/>
      <Button Name="PlayBtn"
              Content="Play"
              Width="90"
              Height="32"
              Margin="0,0,8,0"/>
      <Button Name="CloseBtn"
              Content="Close"
              Width="90"
              Height="32"/>
    </StackPanel>

  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$StatusText = $win.FindName('StatusText')
$PlaylistSearch = $win.FindName('PlaylistSearch')
$PlaylistList = $win.FindName('PlaylistList')
$ChannelSearch = $win.FindName('ChannelSearch')
$ChannelList = $win.FindName('ChannelList')
$FavSearch = $win.FindName('FavSearch')
$FavList = $win.FindName('FavList')
$LoadBtn = $win.FindName('LoadBtn')
$PlayBtn = $win.FindName('PlayBtn')
$CloseBtn = $win.FindName('CloseBtn')

function Set-Status([string]$msg) { $StatusText.Text = $msg }

# Data: playlists
$playlistObjs = @($files | ForEach-Object { Get-PlaylistMeta -File $_ } | Sort-Object Display, File)
$playlistView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($playlistObjs)
$PlaylistList.ItemsSource = $playlistView

# Data: channels (loaded per playlist)
$channelsObjs = @()
$channelsView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($channelsObjs)
$ChannelList.ItemsSource = $channelsView

# Data: favorites (persistent)
$favorites = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
foreach ($f in (Load-Favorites)) { $favorites.Add($f) }
$favView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($favorites)
$FavList.ItemsSource = $favView

# Filters
function Apply-PlaylistFilter {
    $q = ($PlaylistSearch.Text ?? '').Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($q)) {
        $playlistView.Filter = $null
    }
    else {
        $playlistView.Filter = {
            param($o)
            (($o.Display + ' ' + $o.File + ' ' + $o.RawUrl).ToLower().Contains($q))
        }
    }
    $playlistView.Refresh()
}

function Apply-ChannelFilter {
    $q = ($ChannelSearch.Text ?? '').Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($q)) {
        $channelsView.Filter = $null
    }
    else {
        $channelsView.Filter = {
            param($o)
            (($o.Name + ' ' + ($o.Group ?? '') + ' ' + ($o.StreamUrl ?? '')).ToLower().Contains($q))
        }
    }
    $channelsView.Refresh()
}

function Apply-FavFilter {
    $q = ($FavSearch.Text ?? '').Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($q)) {
        $favView.Filter = $null
    }
    else {
        $favView.Filter = {
            param($o)
            (($o.Name + ' ' + ($o.PlaylistDisplay ?? '') + ' ' + ($o.StreamUrl ?? '')).ToLower().Contains($q))
        }
    }
    $favView.Refresh()
}

# Actions
function Load-SelectedPlaylist {
    $pl = $PlaylistList.SelectedItem
    if (-not $pl) { return }

    Set-Status("Downloading: $($pl.Display)")
    $win.Dispatcher.Invoke([action] {}, "Background")

    try {
        $text = (Invoke-WebRequest -Uri $pl.RawUrl -UseBasicParsing -TimeoutSec 30).Content
    }
    catch {
        Set-Status("Download failed.")
        [System.Windows.MessageBox]::Show(
            "Failed to download:`n$($pl.RawUrl)`n`n$($_.Exception.Message)",
            "Download error", "OK", "Error"
        ) | Out-Null
        return
    }

    $parsed = ConvertFrom-M3U -M3UText $text
    if (-not $parsed -or $parsed.Count -eq 0) {
        Set-Status("No channels parsed.")
        return
    }

    $channelsObjs = @($parsed | Sort-Object Name, StreamUrl -Unique)
    $channelsView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($channelsObjs)
    $ChannelList.ItemsSource = $channelsView
    Apply-ChannelFilter

    Set-Status("Loaded: $($pl.Display) — $($channelsObjs.Count) channels")
}

# Debounce timer for single-click/selection changes
$script:PlaylistSelectTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:PlaylistSelectTimer.Interval = [TimeSpan]::FromMilliseconds(300)

$script:PendingPlaylist = $null

$script:PlaylistSelectTimer.Add_Tick({
        $script:PlaylistSelectTimer.Stop()

        # Only load if selection is still the same item we last saw
        if ($script:PendingPlaylist -and $PlaylistList.SelectedItem -eq $script:PendingPlaylist) {
            Load-SelectedPlaylist
        }
    })

function Play-SelectedChannel {
    $ch = $ChannelList.SelectedItem
    if (-not $ch) { return }
    if ([string]::IsNullOrWhiteSpace($ch.StreamUrl)) { return }

    Start-MpvInJob -Name $ch.Name -Url $ch.StreamUrl
}

function Play-SelectedFavorite {
    $fav = $FavList.SelectedItem
    if (-not $fav) { return }
    if ([string]::IsNullOrWhiteSpace($fav.StreamUrl)) { return }

    Start-MpvInJob -Name $fav.Name -Url $fav.StreamUrl
}

function Add-FavoriteFromChannel {
    $ch = $ChannelList.SelectedItem
    if (-not $ch) { return }
    if ([string]::IsNullOrWhiteSpace($ch.StreamUrl)) { return }

    $pl = $PlaylistList.SelectedItem

    # Country label (fallbacks)
    $countryLabel =
    if ($pl -and $pl.Country) { $pl.Country }
    elseif ($pl -and $pl.Display) { ($pl.Display -split '\s*\(')[0].Trim() }  # "Australia (ABC News)" -> "Australia"
    else { 'Unknown' }

    $favName = "$countryLabel - $($ch.Name)"

    # Deduplicate by StreamUrl (best unique key)
    foreach ($x in $favorites) {
        if ($x.StreamUrl -eq $ch.StreamUrl) {
            Set-Status("Already in favorites: $favName")
            return
        }
    }

    $favObj = [pscustomobject]@{
        Name            = $favName
        ChannelName     = $ch.Name          # keep original too
        Group           = $ch.Group
        StreamUrl       = $ch.StreamUrl
        Country         = $countryLabel
        PlaylistDisplay = $pl?.Display
        PlaylistUrl     = $pl?.RawUrl
        AddedUtc        = [DateTime]::UtcNow.ToString("o")
    }

    $favorites.Add($favObj)
    Save-Favorites -FavList $favorites
    Apply-FavFilter
    Set-Status("Added to favorites: $favName")
}

function Remove-SelectedFavorite {
    $sel = $FavList.SelectedItem
    if (-not $sel) { return }

    $toRemove = $null
    foreach ($x in $favorites) {
        if ($x.StreamUrl -eq $sel.StreamUrl) { $toRemove = $x; break }
    }

    if ($toRemove) {
        $favorites.Remove($toRemove)
        Save-Favorites -FavList $favorites
        Apply-FavFilter
        Set-Status("Removed favorite: $($sel.Name)")
    }
}

# Context menus
$cmCh = New-Object System.Windows.Controls.ContextMenu
$miAdd = New-Object System.Windows.Controls.MenuItem
$miAdd.Header = 'Add to Favorites'
$miAdd.Add_Click({ Add-FavoriteFromChannel })
$cmCh.Items.Add($miAdd) | Out-Null
$ChannelList.ContextMenu = $cmCh

$cmFav = New-Object System.Windows.Controls.ContextMenu
$miRemove = New-Object System.Windows.Controls.MenuItem
$miRemove.Header = 'Remove from Favorites'
$miRemove.Add_Click({ Remove-SelectedFavorite })
$cmFav.Items.Add($miRemove) | Out-Null
$FavList.ContextMenu = $cmFav

# Events
$PlaylistSearch.Add_TextChanged({ Apply-PlaylistFilter })
$ChannelSearch.Add_TextChanged({ Apply-ChannelFilter })
$FavSearch.Add_TextChanged({ Apply-FavFilter })

$LoadBtn.Add_Click({ Load-SelectedPlaylist })
$PlayBtn.Add_Click({
        # Play depending on which tab has focus
        # If Favorites tab selected, play favorite; otherwise play selected channel.
        try {
            if ($FavList.IsVisible -and $FavList.IsKeyboardFocusWithin) { Play-SelectedFavorite }
            else { Play-SelectedChannel }
        }
        catch {
            Play-SelectedChannel
        }
    })
$CloseBtn.Add_Click({ $win.Close() })

$PlaylistList.Add_SelectionChanged({
        # Each time selection changes, reset debounce timer
        $script:PendingPlaylist = $PlaylistList.SelectedItem
        $script:PlaylistSelectTimer.Stop()
        $script:PlaylistSelectTimer.Start()
    })

$ChannelList.Add_MouseDoubleClick({ Play-SelectedChannel })
$FavList.Add_MouseDoubleClick({ Play-SelectedFavorite })

# Initial status + apply fav filter
Set-Status("Double-click a playlist to load. Right-click a channel to add favorites. Favorites persist to: $favPath")
Apply-FavFilter

# Show window
$null = $win.ShowDialog()