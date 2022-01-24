#!/bin/sh

mkdir -p /var/lock/
chmod +x /ci/install.sh
/ci/install.sh install

cat /etc/banner

echo "-------------------------------------------"
opkg print-architecture
echo "-------------------------------------------"

echo "Architecture: $(uname -m)"
# Old arm devices need /lib/ld-musl-arm.so.1
[ -f "/lib/ld-musl-armhf.so.1" ] && ln -sf '/lib/ld-musl-armhf.so.1' '/lib/ld-musl-arm.so.1'
qbittorrent-nox -v

qbittorrent-nox --profile=/tmp 2>&1 &
sleep 10
