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

mkdir -p /tmp/qbittorrent
QT_FATAL_WARNINGS=1 qbittorrent-nox --profile=/tmp/qbittorrent
