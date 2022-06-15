#!/bin/sh

mkdir -p /var/lock/
chmod +x /ci/install.sh
/ci/install.sh install

opkg update
opkg install curl jq

cat /etc/banner

echo "-------------------------------------------"
opkg print-architecture
echo "-------------------------------------------"
echo ""
echo "Architecture: $(uname -m)"
# Old arm devices need /lib/ld-musl-arm.so.1
[ -f "/lib/ld-musl-armhf.so.1" ] && ln -sf '/lib/ld-musl-armhf.so.1' '/lib/ld-musl-arm.so.1'
qbittorrent-nox -v

echo "-------------------------------------------"
qbittorrent-nox --profile=/tmp 2>&1 &
sleep 5

echo "-------------------------------------------"
sid=$(curl -is --header 'Referer: http://localhost:8080' --data 'username=admin&password=adminadmin' http://localhost:8080/api/v2/auth/login | grep 'SID' | sed 's/\S\+ SID=\([a-zA-Z0-9+/]\+\); .*/\1/g')
echo "qBittorrent:" $(curl -s http://localhost:8080/api/v2/app/version --cookie "SID=${sid}")
echo "WebAPI:" $(curl -s http://localhost:8080/api/v2/app/webapiVersion --cookie "SID=${sid}")
echo "-------------------------------------------"
curl -s http://localhost:8080/api/v2/app/buildInfo --cookie "SID=${sid}" | jq -r 'to_entries[] | "\(.key): \(.value)"'
curl -s http://localhost:8080/api/v2/app/shutdown --cookie "SID=${sid}"
