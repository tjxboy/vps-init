#!/usr/bin/env bash
# Read-only Tailscale Peer Relay VPS diagnostic. No settings are changed.
set -u
PORT="${1:-40000}"
if ! [[ "$PORT" =~ ^[0-9]{1,5}$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Usage: $0 [UDP_PORT]"; exit 2
fi
section(){ printf '\n========== %s ==========\n' "$1"; }
have(){ command -v "$1" >/dev/null 2>&1; }

echo "Tailscale Peer Relay VPS diagnostic | $(date -Is 2>/dev/null || date)"
echo "Target UDP port: $PORT | READ-ONLY"

section "1. OS"
if [[ -r /etc/os-release ]]; then . /etc/os-release; echo "${PRETTY_NAME:-unknown}"; else echo "/etc/os-release unavailable"; fi
uname -srmo 2>/dev/null || true

section "2. Tailscale version"
if have tailscale; then tailscale version 2>&1 | head -n 3; else echo "tailscale command not found"; fi

section "3. tailscaled service"
if have systemctl; then
  echo -n "enabled: "; systemctl is-enabled tailscaled 2>&1 || true
  echo -n "active: "; systemctl is-active tailscaled 2>&1 || true
else
  echo "systemctl unavailable"
fi

section "4. UDP listener"
if have ss; then
  OUT="$(ss -H -lunp 2>/dev/null | awk -v suffix=":$PORT" '$5 ~ (suffix "$")')"
  if [[ -n "$OUT" ]]; then
    echo "$OUT"
    echo "RESULT: local UDP listener exists on port $PORT."
  else
    echo "RESULT: no local UDP listener found on UDP $PORT."
    echo "Check relay configuration: tailscale set --relay-server-port=$PORT"
  fi
else
  echo "ss command not found"
fi

section "5. Configured relay port (if exposed by this Tailscale version)"
if have tailscale; then
  LINE="$(tailscale debug prefs 2>/dev/null | grep -i 'RelayServerPort' | head -n 1 || true)"
  if [[ -n "$LINE" ]]; then echo "$LINE"; else echo "RelayServerPort not exposed by tailscale debug prefs; use listener check above."; fi
fi

section "6. Host firewall inspection"
if have ufw; then echo "--- UFW ---"; ufw status verbose 2>&1 || true; else echo "UFW: not installed"; fi
if have nft; then echo "--- nftables ---"; nft list ruleset 2>&1 || true; else echo "nft command: not installed"; fi
if have iptables; then echo "--- iptables ---"; iptables -S 2>&1 || true; else echo "iptables: not installed"; fi
if have ip6tables; then echo "--- ip6tables ---"; ip6tables -S 2>&1 || true; else echo "ip6tables: not installed"; fi
if have firewall-cmd; then echo "--- firewalld ---"; firewall-cmd --state 2>&1 || true; firewall-cmd --list-all 2>&1 || true; else echo "firewalld command: not installed"; fi
if have systemctl; then
  for svc in nftables firewalld ufw; do echo -n "$svc: "; systemctl is-active "$svc" 2>&1 || true; done
fi

section "7. Network addresses and routes"
if have ip; then ip -brief address 2>&1 || true; echo "--- IPv4 routes ---"; ip -4 route 2>&1 || true; else echo "ip command not found"; fi

section "8. Tailscale status"
if have tailscale; then
  tailscale status 2>&1 || true
  echo "--- Tailscale IPv4 ---"
  tailscale ip -4 2>&1 || true
else
  echo "tailscale command not found"
fi

section "9. What this check does not prove"
cat <<EOF
- A local UDP listener does NOT prove VMISS's edge firewall/security group allows inbound UDP $PORT.
- Missing firewall commands do NOT prove that no host/provider firewall exists.
- This VPS-only check cannot validate Tailnet ACL/Grants or prove clients are using this relay.
- Check VMISS Firewall/Security Group manually.
- End-to-end proof: from a client, tailscale ping the OTHER client and inspect tailscale status.
  Look for peer-relay. DERP/relay means public DERP is still being used.
- No settings were changed.
EOF
section "Completed"
