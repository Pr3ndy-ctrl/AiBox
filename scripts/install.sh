#!/usr/bin/env bash
# aibox installer — enterprise friendly
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="${PREFIX}/bin"
ETC_DIR="/etc/aibox"
LOG_DIR="/var/log/aibox"
STATE_BASE="/var/lib/aibox"

echo "Installing aibox to ${PREFIX} ..."

# Binary
install -d "$BIN_DIR"
install -m 0755 bin/aibox "$BIN_DIR/aibox"

# Config
install -d "$ETC_DIR"
if [[ ! -f "$ETC_DIR/aibox.conf" ]]; then
  install -m 0644 etc/aibox.conf "$ETC_DIR/aibox.conf"
  echo "  Created $ETC_DIR/aibox.conf"
else
  echo "  Keeping existing $ETC_DIR/aibox.conf"
fi

# Log and state directories
install -d -m 0755 "$LOG_DIR"
install -d -m 0755 "$STATE_BASE"
install -d -m 0755 "$STATE_BASE/workspaces"

# Optional systemd unit (example)
if [[ -d /etc/systemd/system ]]; then
  install -d /etc/systemd/system
  if [[ -f systemd/aibox@.service ]]; then
    install -m 0644 systemd/aibox@.service /etc/systemd/system/aibox@.service
    echo "  Installed systemd template aibox@.service"
  fi
fi

echo
echo "Installation complete."
echo
echo "Quick test:"
echo "  aibox version"
echo "  aibox info"
echo "  aibox run --dry-run echo hello"
echo
echo "Documentation: see docs/ or 'aibox help'"
echo
echo "Note: bubblewrap (bwrap) must be installed on the system."
echo "  Debian/Ubuntu : apt install bubblewrap"
echo "  Fedora/RHEL   : dnf install bubblewrap"
echo "  Arch          : pacman -S bubblewrap"
