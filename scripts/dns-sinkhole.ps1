# Minimaler lokaler DNS-Responder fuer den Kamera-Port (192.168.137.1:53).
# Beantwortet JEDE Anfrage mit NXDOMAIN -> Kamera loest egardia.com nie auf (Cloud-Block),
# blockiert aber nicht mehr beim Warten auf DNS. Loggt alle Anfragen.
param([int]$Seconds = 0, [string]$Bind = '192.168.137.1', [string]$NtpIp = '', [string]$Log = "$env:TEMP\moreeyes-dns.log")

$c = New-Object Net.Sockets.UdpClient(New-Object Net.IPEndPoint([Net.IPAddress]::Parse($Bind), 53))
$c.Client.ReceiveTimeout = 1000
$end = if ($Seconds -gt 0) { (Get-Date).AddSeconds($Seconds) } else { [datetime]::MaxValue }
"$(Get-Date -f s) DNS-Sinkhole gestartet auf ${Bind}:53" | Out-File $Log -Append
while ((Get-Date) -lt $end) {
    try {
        $r = New-Object Net.IPEndPoint([Net.IPAddress]::Any, 0)
        $d = $c.Receive([ref]$r)
    } catch { continue }
    if ($d.Length -lt 12) { continue }
    $i = 12; $n = @()
    while ($i -lt $d.Length -and $d[$i] -ne 0) { $l = $d[$i]; $n += [Text.Encoding]::ASCII.GetString($d, $i + 1, $l); $i += $l + 1 }
    $qend = $i + 5                                   # Nullbyte + QTYPE + QCLASS
    $qtype = $d[$i + 2]
    $name = $n -join '.'
    if ($NtpIp -and $name -match 'ntp\.org$' -and $qtype -eq 1) {
        # A-Record: NTP-Namen -> lokaler NTP-Server (PC)
        $ans = [byte[]](0xC0, 0x0C, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4) + [Net.IPAddress]::Parse($NtpIp).GetAddressBytes()
        $resp = New-Object byte[] ($qend + $ans.Length)
        [Array]::Copy($d, $resp, $qend)
        [Array]::Copy($ans, 0, $resp, $qend, $ans.Length)
        $resp[2] = 0x81; $resp[3] = 0x80; $resp[6] = 0; $resp[7] = 1; $resp[8] = 0; $resp[9] = 0; $resp[10] = 0; $resp[11] = 0
        $verdict = "A $NtpIp"
    } else {
        $resp = New-Object byte[] $qend
        [Array]::Copy($d, $resp, [Math]::Min($qend, $d.Length))
        $resp[2] = 0x81; $resp[3] = 0x83             # Response, RD+RA, RCODE=3 (NXDOMAIN)
        $resp[6] = 0; $resp[7] = 0; $resp[8] = 0; $resp[9] = 0; $resp[10] = 0; $resp[11] = 0
        $verdict = 'NXDOMAIN'
    }
    [void]$c.Send($resp, $resp.Length, $r)
    "$(Get-Date -f s) $($r.Address) -> $name $verdict" | Out-File $Log -Append
}
$c.Close()
