#!/bin/sh

mkdir -p /var/lock
sh /ci/install.sh install qbittorrent

cat /etc/banner

echo "-------------------------------------------"
command -v opkg 2>&1 >>/dev/null && opkg print-architecture || apk --print-arch
echo "-------------------------------------------"
echo ""
echo "Architecture: $(uname -m)"
echo "-------------------------------------------"

mkdir -p /tmp/qbittorrent/qBittorrent/config

cat >> /tmp/qbittorrent/qBittorrent/config/qBittorrent.conf <<EOF
[LegalNotice]
Accepted=true

[Preferences]
WebUI\Password_PBKDF2="@ByteArray(${Password_PBKDF2})"
EOF
QT_FATAL_WARNINGS=1 qbittorrent-nox --profile=/tmp/qbittorrent
