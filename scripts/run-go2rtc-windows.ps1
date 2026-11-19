# Sprint-1-Fallback: go2rtc direkt unter Windows starten (solange Docker Desktop
# nicht laeuft). Spaeter 1:1 ersetzbar durch: docker compose up -d
# Liest Kamera-URL aus .env, startet bin\go2rtc.exe mit go2rtc\go2rtc.yaml.

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
if (-not (Test-Path $envFile)) { throw ".env fehlt. Siehe .env.example." }

Get-Content $envFile | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
    $k, $v = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim(), 'Process')
}

$exe = Join-Path $root 'bin\go2rtc.exe'
$cfg = Join-Path $root 'go2rtc\go2rtc.yaml'
Write-Host "Starte go2rtc (Web-UI: http://127.0.0.1:1984 ) ..."
& $exe -config $cfg
