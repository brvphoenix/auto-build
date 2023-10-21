#!/bin/bash
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

[ -n "$(command -v update-binfmts)" ] || {
	sudo apt-get update
	sudo apt-get -y install binfmt-support
}

## Update binfmts using ubuntu's binfmt files.
#sudo update-binfmts --import

mkdir -p qemu qemu/qus qemu/tmp
cd qemu

curl -ksLOZ http://ftp.debian.org/debian/dists/bookworm/main/binary-amd64/Packages.xz
xz -d Packages.xz
qus_ver=$(sed -n '/Package: qemu-user-static/{:a;n;/Version: \S\+/!ba;s/Version: 1:\(\S\+\)/\1/p}' Packages)

curl -fkLOZ --compressed --connect-timeout 10 --retry 5 http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${qus_ver}_amd64.deb
dpkg -x "qemu-user-static_${qus_ver}_amd64.deb" "$(pwd)/qus"

# Register qemu by official binfmt.
exportdir=$(pwd)/tmp
binfmt_ver=$(echo ${qus_ver} | sed -n 's,\(\([0-9]\+\.\)\+[0-9]\+\).*,\1,gp')
curl -fkLOZ --compressed --connect-timeout 10 --retry 5 https://raw.githubusercontent.com/qemu/qemu/stable-${binfmt_ver}/scripts/qemu-binfmt-conf.sh
chmod +x qemu-binfmt-conf.sh

# Modify the package name to avoid potential conflits. For example, it need the modify the package name
# to 'qemu-user-static' if use package 'qemu-user-static'.
sed -i 's/^package qemu-\$cpu$/package qemu-test-static/g' qemu-binfmt-conf.sh
./qemu-binfmt-conf.sh --qemu-suffix "-static" --qemu-path "$(pwd)/qus/usr/bin" --debian --exportdir "${exportdir}" --persistent yes
sudo update-binfmts --importdir ${exportdir} --import
