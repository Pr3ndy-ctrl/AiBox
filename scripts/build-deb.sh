#!/usr/bin/env bash
# Build an architecture-independent Debian package for aibox.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="0.2.0"
PKG_NAME="aibox"
ARCH="all"
DIST="${ROOT}/dist"
BUILD="${ROOT}/packaging/build"

command -v dpkg-deb >/dev/null 2>&1 || {
  echo "Error: dpkg-deb is required to build the package." >&2
  exit 1
}

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD/DEBIAN" \
         "$BUILD/usr/bin" \
         "$BUILD/usr/share/aibox" \
         "$BUILD/etc/aibox" \
         "$BUILD/lib/systemd/system" \
         "$BUILD/usr/share/doc/aibox" \
         "$DIST"

cat > "$BUILD/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: bubblewrap, python3, bash (>= 4)
Maintainer: Pr3ndy-ctrl <https://github.com/Pr3ndy-ctrl>
Homepage: https://github.com/Pr3ndy-ctrl/AiBox
Description: Enterprise-ready AI agent sandbox for Linux
 aibox runs AI agents and untrusted code inside a lightweight
 bubblewrap sandbox with strong defaults: network denied,
 private HOME, read-only system paths, and an optional
 cooperative HTTP proxy allow-list. Includes JSON audit
 logging suitable for SIEM integration.
EOF

printf '%s\n' "/etc/aibox/aibox.conf" > "$BUILD/DEBIAN/conffiles"

install -m 0755 "$ROOT/bin/aibox" "$BUILD/usr/bin/aibox"
install -m 0755 "$ROOT/lib/aibox-proxy.py" "$BUILD/usr/share/aibox/aibox-proxy.py"
install -m 0644 "$ROOT/etc/aibox.conf" "$BUILD/etc/aibox/aibox.conf"
install -m 0644 "$ROOT/systemd/aibox@.service" "$BUILD/lib/systemd/system/aibox@.service"
install -m 0644 "$ROOT/LICENSE" "$BUILD/usr/share/doc/aibox/copyright"
install -m 0644 "$ROOT/README.md" "$BUILD/usr/share/doc/aibox/README.md"
install -m 0644 "$ROOT/NOTICE" "$BUILD/usr/share/doc/aibox/NOTICE"

cat > "$BUILD/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
mkdir -p /var/log/aibox /var/lib/aibox/workspaces
chmod 0755 /var/log/aibox /var/lib/aibox /var/lib/aibox/workspaces || true
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
fi
exit 0
POSTINST
chmod 0755 "$BUILD/DEBIAN/postinst"

dpkg-deb --build "$BUILD" "${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
echo "Built: ${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
ls -lh "${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
