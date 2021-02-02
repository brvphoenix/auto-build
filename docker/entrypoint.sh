#!/bin/sh

mkdir -p /var/lock/

opkg update
opkg print-architecture | awk -F ' ' '{print "--add-arch " $2 ":" $3}' | xargs opkg --add-arch $1:100 install $(find /ci -type f -iname '*.ipk')

cat /etc/banner
echo "-------------------------------------------"
opkg print-architecture
echo "-------------------------------------------"
qbittorrent-nox -v

