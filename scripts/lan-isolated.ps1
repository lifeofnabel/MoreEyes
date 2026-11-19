# Setzt am LAN-Port feste Adressen OHNE Gateway (Kamera bekommt so kein Internet).
# Aufruf:  .\scripts\lan-isolated.ps1          (Setup)
#          .\scripts\lan-isolated.ps1 -Undo    (zurueck auf automatisch)
param([switch]$Undo, [string]$Alias = 'Ethernet')

$isAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Alias $Alias" + $(if ($Undo) { ' -Undo' } else { '' })
    Start-Process powershell -Verb RunAs -ArgumentList $arg   # UAC-Abfrage
    exit
}

$log = Join-Path $env:TEMP 'moreeyes-lan.log'
Start-Transcript -Path $log -Force | Out-Null
try {
    if ($Undo) {
        Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false
        Set-NetIPInterface -InterfaceAlias $Alias -Dhcp Enabled
        'UNDO OK'
    } else {
        foreach ($a in @(@('192.168.137.1', 24), @('169.254.200.200', 16))) {
            if (-not (Get-NetIPAddress -InterfaceAlias $Alias -IPAddress $a[0] -ErrorAction SilentlyContinue)) {
                New-NetIPAddress -InterfaceAlias $Alias -IPAddress $a[0] -PrefixLength $a[1] | Out-Null
            }
        }
        'SETUP OK (kein Gateway gesetzt)'
    }
    Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 | Select-Object IPAddress, PrefixLength, PrefixOrigin | Format-Table -AutoSize
} catch { "FEHLER: $_" }
Stop-Transcript | Out-Null
Start-Sleep 4
