# Minimaler DHCP-Server fuer die Kamera am LAN-Port. Vergibt feste IP, KEIN Gateway (kein Internet),
# DNS + NTP zeigen auf den PC (dns-sinkhole.ps1 / Windows-Zeitdienst).
param([int]$Seconds = 0, [string]$ServerIp = '192.168.137.1', [string]$CamIp = '192.168.137.56', [string]$Log = "$env:TEMP\moreeyes-dhcp.log")

$srv = [Net.IPAddress]::Parse($ServerIp).GetAddressBytes()
$yi = [Net.IPAddress]::Parse($CamIp).GetAddressBytes()
$c = New-Object Net.Sockets.UdpClient(67)
$c.EnableBroadcast = $true
$c.Client.ReceiveTimeout = 1000
# Subnetz-Broadcast statt 255.255.255.255: so nimmt Windows sicher den LAN-Port (PC hat viele Adapter/VPNs)
$bc = New-Object Net.IPEndPoint([Net.IPAddress]::Parse(($ServerIp -replace '\.\d+$', '.255')), 68)
$end = if ($Seconds -gt 0) { (Get-Date).AddSeconds($Seconds) } else { [datetime]::MaxValue }
"$(Get-Date -f s) DHCP gestartet, vergibt $CamIp (ohne Gateway)" | Out-File $Log -Append
while ((Get-Date) -lt $end) {
    try { $r = New-Object Net.IPEndPoint([Net.IPAddress]::Any, 0); $d = $c.Receive([ref]$r) } catch { continue }
    if ($d.Length -lt 241 -or $d[0] -ne 1) { continue }
    $type = 0; $i = 240
    while ($i -lt $d.Length - 1 -and $d[$i] -ne 255) { if ($d[$i] -eq 53) { $type = $d[$i + 2] }; $i += 2 + $d[$i + 1] }
    if ($type -ne 1 -and $type -ne 3) { continue }
    $reply = if ($type -eq 1) { 2 } else { 5 }
    $p = New-Object byte[] 300
    $p[0] = 2; $p[1] = 1; $p[2] = 6
    [Array]::Copy($d, 4, $p, 4, 4)          # xid
    [Array]::Copy($d, 10, $p, 10, 2)        # flags
    [Array]::Copy($yi, 0, $p, 16, 4)        # yiaddr
    [Array]::Copy($srv, 0, $p, 20, 4)       # siaddr
    [Array]::Copy($d, 28, $p, 28, 16)       # chaddr
    $p[236] = 99; $p[237] = 130; $p[238] = 83; $p[239] = 99
    $o = [byte[]](53, 1, $reply) + [byte[]](54, 4) + $srv + [byte[]](51, 4, 0, 1, 0x51, 0x80) +
         [byte[]](1, 4, 255, 255, 255, 0) + [byte[]](6, 4) + $srv + [byte[]](42, 4) + $srv + [byte[]](255)
    [Array]::Copy($o, 0, $p, 240, $o.Length)
    [void]$c.Send($p, 240 + $o.Length, $bc)
    "$(Get-Date -f s) $(if ($type -eq 1) {'DISCOVER->OFFER'} else {'REQUEST->ACK'}) $CamIp" | Out-File $Log -Append
}
$c.Close()
