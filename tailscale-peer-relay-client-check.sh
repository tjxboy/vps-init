#!/usr/bin/env bash
# Read-only Tailscale client path check for Linux/macOS.
set -u
PEER_IP="${1:-}"
COUNT="${2:-10}"
if [[ -z "$PEER_IP" ]] || ! [[ "$COUNT" =~ ^[0-9]+$ ]] || (( COUNT < 1 || COUNT > 50 )); then
  echo "Usage: $0 PEER_TAILSCALE_IP [COUNT]"
  echo "Example: $0 100.112.215.35 10"; exit 2
fi
if ! command -v tailscale >/dev/null 2>&1; then echo "tailscale command not found"; exit 1; fi

echo "Tailscale client path check | $(date -Is 2>/dev/null || date)"
echo "Target peer: $PEER_IP"
echo
echo "========== 1. tailscale ping =========="
tailscale ping "--c=$COUNT" "$PEER_IP"
PING_RC=$?
echo
echo "========== 2. tailscale status =========="
STATUS="$(tailscale status 2>&1)"
printf '%s\n' "$STATUS"
echo
echo "========== 3. interpretation =========="
LINE="$(printf '%s\n' "$STATUS" | grep -F "$PEER_IP" | head -n 1 || true)"
if printf '%s\n' "$LINE" | grep -qi 'peer-relay'; then
  echo "RESULT: peer-relay marker found for this peer."
elif printf '%s\n' "$LINE" | grep -qi 'relay'; then
  echo "RESULT: relay marker found; inspect whether it is DERP or peer-relay."
elif printf '%s\n' "$LINE" | grep -qi 'direct'; then
  echo "RESULT: direct connection shown; Peer Relay is not being used for this peer."
else
  echo "RESULT: no conclusive marker. Inspect the full ping/status output above."
fi
if (( PING_RC != 0 )); then echo "tailscale ping exit code: $PING_RC"; fi
echo "Read-only: no configuration or firewall settings changed."
