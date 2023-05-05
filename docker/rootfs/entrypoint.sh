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

# Old arm devices need /lib/ld-musl-arm.so.1
[ -f "/lib/ld-musl-armhf.so.1" ] && ln -sf '/lib/ld-musl-armhf.so.1' '/lib/ld-musl-arm.so.1'

mkdir -p /tmp/qbittorrent
qbittorrent-nox --profile=/tmp/qbittorrent
