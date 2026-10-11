$ErrorActionPreference = 'Stop'
$servers = @(@('stun.l.google.com',19302),@('stun.cloudflare.com',3478),@('stun.miwifi.com',3478))
$udp = New-Object System.Net.Sockets.UdpClient(0)
$udp.Client.ReceiveTimeout = 2000
foreach ($server in $servers) {
    $hostname = [string]$server[0]
    $port = [int]$server[1]
    $packet = New-Object byte[] 20
    $packet[1] = 1
    $packet[4] = 0x21; $packet[5] = 0x12; $packet[6] = 0xa4; $packet[7] = 0x42
    $transaction = New-Object byte[] 12
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($transaction)
    [Array]::Copy($transaction,0,$packet,8,12)
    try {
        $address = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object {$_.AddressFamily -eq 'InterNetwork'} | Select-Object -First 1
        $endpoint = New-Object System.Net.IPEndPoint($address,$port)
        [void]$udp.Send($packet,$packet.Length,$endpoint)
        $responseEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)
        $response = $udp.Receive([ref]$responseEndpoint)
        [pscustomobject]@{Server="$($hostname):$port";ResponseBytes=$response.Length;ResponseFrom=$responseEndpoint.ToString()} | ConvertTo-Json -Compress
    } catch {
        [pscustomobject]@{Server="$($hostname):$port";Error=$_.Exception.GetBaseException().Message} | ConvertTo-Json -Compress
    }
}
$udp.Close()
