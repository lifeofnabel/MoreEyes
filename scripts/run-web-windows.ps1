# Sprint-2-Fallback: Weboberflaeche direkt unter Windows starten (ohne Docker/Caddy),
# solange Docker Desktop nicht laeuft. Spaeter 1:1 ersetzbar durch: docker compose up -d
# Zeigt auf das lokal laufende go2rtc (scripts/run-go2rtc-windows.ps1).
# Achtung: ohne Caddy, daher reines HTTP direkt auf WEB_PORT (Standard 3000).

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
if (-not (Test-Path $envFile)) { throw ".env fehlt. Siehe .env.example." }

Get-Content $envFile | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
    $k, $v = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim(), 'Process')
}
[Environment]::SetEnvironmentVariable('GO2RTC_URL', 'http://127.0.0.1:1984', 'Process')
if (-not $env:WEB_PORT) { [Environment]::SetEnvironmentVariable('WEB_PORT', '3000', 'Process') }

Set-Location (Join-Path $root 'web')
Write-Host "Starte MoreEyes Web auf Port $($env:WEB_PORT) (Windows-Fallback, ohne Caddy) ..."
node server.js
