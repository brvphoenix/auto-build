#!/bin/sh

mkdir -p /var/lock/

opkg update
opkg install $(find /ci -type f -iname '*.ipk')

cat /etc/banner
echo "-------------------------------------------"
opkg print-architecture
echo "-------------------------------------------"
python3 -c "import libtorrent as lt;print(lt.__version__);print(dir(lt));"
