#!/usr/bin/env bash
# Build a simple architecture-independent .deb for aibox
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="0.2.0"
PKG_NAME="aibox"
ARCH="all"
DIST="${ROOT}/dist"
BUILD="${ROOT}/packaging/build"

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD/DEBIAN" \
         "$BUILD/usr/bin" \
         "$BUILD/usr/share/aibox" \
         "$BUILD/etc/aibox" \
         "$BUILD/lib/systemd/system" \
         "$BUILD/usr/share/doc/aibox" \
         "$DIST"

# Control file
cat > "$BUILD/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: bubblewrap, python3, bash (>= 4)
Maintainer: Pr3ndy-ctrl <https://github.com/Pr3ndy-ctrl>
Homepage: https://github.com/Pr3ndy-ctrl/aibox
Description: Enterprise-ready AI agent sandbox for Linux
 aibox runs AI agents and untrusted code inside a lightweight
 bubblewrap sandbox with strong defaults: network denied,
 private HOME, read-only system paths, and optional host
 allow-list via a cooperative HTTP proxy. Includes JSON
 audit logging suitable for SIEM integration.
EOF

# Conffiles
echo "/etc/aibox/aibox.conf" > "$BUILD/DEBIAN/conffiles"

# Files
install -m 0755 "$ROOT/bin/aibox" "$BUILD/usr/bin/aibox"
install -m 0755 "$ROOT/lib/aibox-proxy.py" "$BUILD/usr/share/aibox/aibox-proxy.py"
install -m 0644 "$ROOT/etc/aibox.conf" "$BUILD/etc/aibox/aibox.conf"
install -m 0644 "$ROOT/systemd/aibox@.service" "$BUILD/lib/systemd/system/aibox@.service"
install -m 0644 "$ROOT/LICENSE" "$BUILD/usr/share/doc/aibox/copyright"
install -m 0644 "$ROOT/README.md" "$BUILD/usr/share/doc/aibox/README.md"
install -m 0644 "$ROOT/NOTICE" "$BUILD/usr/share/doc/aibox/NOTICE"

# postinst
cat > "$BUILD/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
mkdir -p /var/log/aibox /var/lib/aibox/workspaces
chmod 0755 /var/log/aibox /var/lib/aibox /var/lib/aibox/workspaces
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
fi
exit 0
EOF
chmod 0755 "$BUILD/DEBIAN/postinst"

# Build
dpkg-deb --build "$BUILD" "${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
echo "Built: ${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
ls -lh "${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
EOF
chmod +x /home/workdir/artifacts/aibox-repo/scripts/build-deb.sh
# Fix the heredoc end - the script above has a problem with nested EOF
# Rewrite cleanly
cat > /home/workdir/artifacts/aibox-repo/scripts/build-deb.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="0.2.0"
PKG_NAME="aibox"
ARCH="all"
DIST="${ROOT}/dist"
BUILD="${ROOT}/packaging/build"

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
Homepage: https://github.com/Pr3ndy-ctrl/aibox
Description: Enterprise-ready AI agent sandbox for Linux
 aibox runs AI agents and untrusted code inside a lightweight
 bubblewrap sandbox with strong defaults: network denied,
 private HOME, read-only system paths, and optional host
 allow-list via a cooperative HTTP proxy. Includes JSON
 audit logging suitable for SIEM integration.
EOF

echo "/etc/aibox/aibox.conf" > "$BUILD/DEBIAN/conffiles"

install -m 0755 "$ROOT/bin/aibox" "$BUILD/usr/bin/aibox"
install -m 0755 "$ROOT/lib/aibox-proxy.py" "$BUILD/usr/share/aibox/aibox-proxy.py"
install -m 0644 "$ROOT/etc/aibox.conf" "$BUILD/etc/aibox/aibox.conf"
install -m 0644 "$ROOT/systemd/aibox@.service" "$BUILD/lib/systemd/system/aibox@.service" 2>/dev/null || true
install -m 0644 "$ROOT/LICENSE" "$BUILD/usr/share/doc/aibox/copyright"
install -m 0644 "$ROOT/README.md" "$BUILD/usr/share/doc/aibox/README.md"
install -m 0644 "$ROOT/NOTICE" "$BUILD/usr/share/doc/aibox/NOTICE"

cat > "$BUILD/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
mkdir -p /var/log/aibox /var/lib/aibox/workspaces
chmod 0755 /var/log/aibox /var/lib/aibox /var/lib/aibox/workspaces || true
command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload || true
exit 0
POST
chmod 0755 "$BUILD/DEBIAN/postinst"

dpkg-deb --build "$BUILD" "${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
echo "Built: ${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
ls -lh "${DIST}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
SCRIPT
chmod +x /home/workdir/artifacts/aibox-repo/scripts/build-deb.sh
echo "build-deb.sh ready"
