<#
.SYNOPSIS
    Serves the IPTV Stream Launcher on http://localhost:8090.

.DESCRIPTION
    Starts a minimal HTTP file server using .NET HttpListener — no external modules
    required. Serves all files in the script directory, defaulting to index.html,
    and opens the browser automatically on start.

    Special routes:
      GET /launch?url=<url>&title=<title>  — launches mpv.exe with the given stream
      GET /proxy?url=<url>                 — proxies the URL server-side (CORS bypass)

    All_Stations.m3u is injected into index.html at request time so it auto-loads.

    Press Ctrl+C to stop.

.EXAMPLE
    pwsh .\serve.ps1
    powershell .\serve.ps1
#>

#requires -version 5.1

$port    = 8090
$root    = $PSScriptRoot
$mpvPath = 'C:\Install\MPV\mpv.exe'   # edit if mpv is elsewhere

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.m3u'  = 'application/x-mpegurl'
    '.m3u8' = 'application/x-mpegurl'
    '.svg'  = 'image/svg+xml'
    '.png'  = 'image/png'
    '.ico'  = 'image/x-icon'
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "Stream Launcher  ->  http://localhost:$port  (Ctrl+C to stop)"
Start-Process "http://localhost:$port"

try {
    while ($listener.IsListening) {
        $ctx = $null
        try { $ctx = $listener.GetContext() } catch { break }

        $localPath = $ctx.Request.Url.LocalPath.TrimStart('/')
        $res       = $ctx.Response

        # /launch?url=...&title=... — fire mpv for streams the browser can't play
        if ($localPath -eq 'launch') {
            $url   = $ctx.Request.QueryString['url']
            $title = $ctx.Request.QueryString['title']
            if ($url -and (Test-Path $mpvPath -PathType Leaf)) {
                $safeTitle = if ($title) { $title -replace '"', '\"' } else { 'Stream' }
                $safeUrl   = $url -replace '"', '\"'
                Start-Process -FilePath $mpvPath -ArgumentList "--force-window=yes --title=`"$safeTitle`" `"$safeUrl`""
                $body = [System.Text.Encoding]::UTF8.GetBytes('ok')
            } else {
                $res.StatusCode = 503
                $body = [System.Text.Encoding]::UTF8.GetBytes("mpv not found at: $mpvPath")
            }
            $res.ContentType     = 'text/plain'
            $res.ContentLength64 = $body.Length
            $res.OutputStream.Write($body, 0, $body.Length)
            $res.Close()
            continue
        }

        # /proxy?url=... — fetch URL server-side so the browser avoids CORS restrictions
        if ($localPath -eq 'proxy') {
            $targetUrl = $ctx.Request.QueryString['url']
            if ($targetUrl) {
                try {
                    $wc = [System.Net.WebClient]::new()
                    $wc.Headers['User-Agent'] = 'Mozilla/5.0'
                    $data = $wc.DownloadData($targetUrl)
                    $ct   = $wc.ResponseHeaders['Content-Type']
                    $res.ContentType     = if ($ct) { $ct } else { 'application/octet-stream' }
                    $res.Headers.Add('Access-Control-Allow-Origin', '*')
                    $res.ContentLength64 = $data.LongLength
                    $res.OutputStream.Write($data, 0, $data.Length)
                } catch {
                    $res.StatusCode      = 502
                    $body                = [System.Text.Encoding]::UTF8.GetBytes($_.Exception.Message)
                    $res.ContentType     = 'text/plain'
                    $res.ContentLength64 = $body.Length
                    $res.OutputStream.Write($body, 0, $body.Length)
                }
            } else {
                $res.StatusCode      = 400
                $body                = [System.Text.Encoding]::UTF8.GetBytes('Missing url parameter')
                $res.ContentType     = 'text/plain'
                $res.ContentLength64 = $body.Length
                $res.OutputStream.Write($body, 0, $body.Length)
            }
            $res.Close()
            continue
        }

        # Static file serving
        if (-not $localPath) { $localPath = 'index.html' }
        $filePath = Join-Path $root $localPath

        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }

            if ($localPath -eq 'index.html') {
                $html    = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
                $m3uPath = Join-Path $root 'All_Stations.m3u'
                if (Test-Path $m3uPath -PathType Leaf) {
                    $m3uJson = [System.IO.File]::ReadAllText($m3uPath, [System.Text.Encoding]::UTF8) | ConvertTo-Json
                    $html    = $html -replace '(?i)</head>', "<script>window.__PLAYLIST_RAW__=$m3uJson;</script></head>"
                }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
            } else {
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
            }

            $res.ContentLength64 = $bytes.LongLength
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $res.StatusCode      = 404
            $body                = [System.Text.Encoding]::UTF8.GetBytes('Not found')
            $res.ContentLength64 = $body.Length
            $res.OutputStream.Write($body, 0, $body.Length)
        }

        $res.Close()
    }
} finally {
    $listener.Stop()
    Write-Host 'Server stopped.'
}
