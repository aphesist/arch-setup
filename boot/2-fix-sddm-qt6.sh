#!/usr/bin/env bash
# Fix: SDDM launched the Qt5 greeter (not installed) for the Panacea theme,
# because its metadata.desktop lacks QtVersion=6. Greeter died -> the last
# Plymouth frame stayed on screen.
# Run as:  sudo bash boot/2-fix-sddm-qt6.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }

# Idempotent patcher. Panacea's install.sh re-copies the theme on every
# update, so this runs before each SDDM start instead of once.
cat > /usr/local/bin/sddm-panacea-qt6 <<'EOF'
#!/bin/sh
m=/usr/share/sddm/themes/panacea/metadata.desktop
[ -f "$m" ] || exit 0
grep -q '^QtVersion=6' "$m" && exit 0
sed -i '/^\[SddmGreeterTheme\]/a QtVersion=6' "$m"
EOF
chmod 755 /usr/local/bin/sddm-panacea-qt6

mkdir -p /etc/systemd/system/sddm.service.d
cat > /etc/systemd/system/sddm.service.d/10-panacea-qt6.conf <<'EOF'
[Service]
# '-' = never block SDDM if this fails
ExecStartPre=-/usr/local/bin/sddm-panacea-qt6
EOF
systemctl daemon-reload

/usr/local/bin/sddm-panacea-qt6
echo "--- metadata.desktop now:"
cat /usr/share/sddm/themes/panacea/metadata.desktop
grep -q '^QtVersion=6' /usr/share/sddm/themes/panacea/metadata.desktop \
  && echo "OK: theme now uses sddm-greeter-qt6" || echo "FAIL: QtVersion not set"
