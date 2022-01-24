#!/bin/sh

mkdir -p /var/lock/
chmod +x /ci/install.sh
/ci/install.sh install

cat /etc/banner

echo "-------------------------------------------"
opkg print-architecture
echo "-------------------------------------------"

echo "Architecture: $(uname -m)"
qbittorrent-nox -v

qbittorrent-nox --profile=/tmp 2>&1 &
sleep 10
