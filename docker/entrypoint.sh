#!/bin/sh

mkdir -p /var/lock/

opkg update
opkg install $(find /ci -type f -iname '*.ipk')

cat /etc/banner
echo "-------------------------------------------"
opkg print-architecture
echo "-------------------------------------------"
qbittorrent-nox -v

