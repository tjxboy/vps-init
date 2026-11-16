
#!/usr/bin/env bash
# Tailscale Peer Relay Setup
# Target: Debian 13
# Created: 2026-11-16

set -Eeuo pipefail

NODE_NAME="${TAILSCALE_HOSTNAME:-us-vps-relay}"
RELAY_PORT="${TAILSCALE_RELAY_PORT:-40000}"
AUTH_WAIT_SECONDS=600

log() {
    echo
    echo "[Tailscale Setup] $*"
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

# Must run as root
if [[ "$EUID" -ne 0 ]]; then
    die "Run this script with sudo."
fi

# Check OS
if [[ ! -r /etc/os-release ]]; then
    die "Cannot identify operating system."
fi

source /etc/os-release

if [[ "${ID:-}" != "debian" || "${VERSION_ID:-}" != "13" ]]; then
    die "This script only supports Debian 13."
fi

# Install dependencies
log "Installing dependencies..."

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl ca-certificates

# Install official Tailscale package
log "Installing Tailscale..."

curl -fsSL https://tailscale.com/install.sh | sh

# Start service
systemctl enable --now tailscaled

command -v tailscale >/dev/null || die "Tailscale installation failed."

# Check minimum version
VERSION="$(tailscale version | awk 'NR==1 {print $1}')"

if ! dpkg --compare-versions "$VERSION" ge "1.86.0"; then
    die "Tailscale version $VERSION is too old. Peer Relay requires 1.86 or later."
fi

log "Tailscale version: $VERSION"

# Join existing Tailnet
if tailscale ip -4 >/dev/null 2>&1; then

    log "Already connected to Tailnet."

else

    log "Starting Tailnet authentication..."

    set +e
    tailscale up \
        --hostname="$NODE_NAME" \
        --accept-dns=false
    UP_RC=$?
    set -e

    if (( UP_RC != 0 )); then
        log "Authentication command returned $UP_RC. Checking login status..."
    fi

    log "If an authentication URL appeared above, open it and authorize this VPS."

    AUTHENTICATED=0

    for ((i=0; i<AUTH_WAIT_SECONDS; i+=2)); do
        if tailscale ip -4 >/dev/null 2>&1; then
            AUTHENTICATED=1
            break
        fi
        sleep 2
    done

    if (( AUTHENTICATED == 0 )); then
        die "Authentication not completed. Authorize the VPS and run this script again."
    fi

fi

# Configure Peer Relay
log "Configuring Peer Relay..."

tailscale set \
    --accept-dns=false \
    --relay-server-port="$RELAY_PORT"

# Display results
log "Setup completed."

echo
echo "========================================"
echo " Tailscale Peer Relay"
echo "========================================"
echo "Hostname:       $NODE_NAME"
echo "Version:        $VERSION"
echo "Tailscale IPv4: $(tailscale ip -4 | head -n1)"
echo "Relay UDP port: $RELAY_PORT"
echo "========================================"

echo
echo "Current Tailscale status:"
tailscale status

echo
echo "NEXT STEPS:"
echo "1. Allow inbound UDP $RELAY_PORT in VPS firewall/security group."
echo "2. Allow UDP $RELAY_PORT in the OS firewall if active."
echo "3. Add the peer-relay grant to the Tailnet access policy."
echo
echo "No firewall or ACL changes were made by this script."
