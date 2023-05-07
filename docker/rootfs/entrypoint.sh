#!/bin/sh

mkdir -p /var/lock
sh /ci/install.sh install

cat /etc/banner

echo "-------------------------------------------"
opkg print-architecture
echo "-------------------------------------------"
echo ""
echo "Architecture: $(uname -m)"
echo "-------------------------------------------"

mkdir -p /tmp/qbittorrent
qbittorrent-nox --profile=/tmp/qbittorrent
