param(
    [Parameter(Mandatory = $true)][string]$PeerIP,
    [ValidateRange(1, 50)][int]$Count = 10
)
$ErrorActionPreference = "Continue"
Write-Host "Tailscale client path check"
Write-Host "Time: $(Get-Date -Format o)"
Write-Host "Target peer: $PeerIP"

if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    Write-Error "tailscale command not found. Check installation/PATH."
    exit 1
}

Write-Host "`n========== 1. Tailscale version =========="
& tailscale version

Write-Host "`n========== 2. Tailscale ping =========="
& tailscale ping "--c=$Count" $PeerIP
$pingExit = $LASTEXITCODE

Write-Host "`n========== 3. Tailscale status =========="
$status = & tailscale status 2>&1
$status | ForEach-Object { Write-Host $_ }

Write-Host "`n========== 4. Interpretation =========="
$peerLine = $status | Where-Object { "$_" -match [regex]::Escape($PeerIP) } | Select-Object -First 1
if ($peerLine) {
    Write-Host "Peer status line: $peerLine"
    if ("$peerLine" -match "peer-relay") {
        Write-Host "RESULT: peer-relay marker found."
    } elseif ("$peerLine" -match "relay") {
        Write-Host "RESULT: relay marker found; inspect whether DERP or peer-relay."
    } elseif ("$peerLine" -match "direct") {
        Write-Host "RESULT: direct connection shown; Peer Relay is not being used."
    } else {
        Write-Host "RESULT: no conclusive marker in status line."
    }
} else {
    Write-Host "No status line matching $PeerIP found."
}
if ($pingExit -ne 0) { Write-Host "tailscale ping exit code: $pingExit" }

Write-Host "`nInterpret the ping output:"
Write-Host "- peer-relay: your own Peer Relay is being used."
Write-Host "- DERP(...): Tailscale public DERP is being used."
Write-Host "- public IP:port / direct: direct path."
Write-Host "Read-only: no Tailscale or firewall settings changed."
