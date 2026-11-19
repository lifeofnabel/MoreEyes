# Schaltet den Windows-Zeitdienst als NTP-SERVER fuer das Kamera-Subnetz ein (nur 192.168.137.0/24).
# Aufruf: .\scripts\ntp-local.ps1          (an)
#         .\scripts\ntp-local.ps1 -Off     (aus, Regel weg)
param([switch]$Off)

$isAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" + $(if ($Off) { ' -Off' } else { '' }))
    exit
}
$log = Join-Path $env:TEMP 'moreeyes-ntp.log'
Start-Transcript -Path $log -Force | Out-Null
try {
    $key = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time'
    $rule = 'MoreEyes-NTP-Kamera'
    if ($Off) {
        Set-ItemProperty "$key\TimeProviders\NtpServer" -Name Enabled -Value 0
        Remove-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
        'NTP-Server AUS'
    } else {
        Set-ItemProperty "$key\TimeProviders\NtpServer" -Name Enabled -Value 1
        Set-ItemProperty "$key\Config" -Name AnnounceFlags -Value 5     # PC darf sich als Zeitquelle melden, auch ohne Referenz
        if (-not (Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $rule -Direction Inbound -Protocol UDP -LocalPort 123 -RemoteAddress 192.168.137.0/24 -Action Allow | Out-Null
        }
        'NTP-Server AN (nur fuer 192.168.137.0/24)'
    }
    Restart-Service w32time
    Get-Service w32time | Select-Object Status, Name
} catch { "FEHLER: $_" }
Stop-Transcript | Out-Null
Start-Sleep 4
