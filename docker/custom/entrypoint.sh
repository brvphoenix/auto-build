#!/bin/sh

mkdir -p /var/lock
sh /ci/install.sh install qbittorrent

cat /etc/banner

echo "-------------------------------------------"
opkg print-architecture
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
