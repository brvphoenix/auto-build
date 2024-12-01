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

codename=$(curl -ksfL http://ftp.debian.org/debian/dists/testing/InRelease | grep 'Codename:' | cut -d' ' -f2)
qus_ver=$(curl -ksfL https://sources.debian.org/api/src/qemu | jq -r --arg codename "$codename" '.versions | map(select(.suites[] | contains($codename))) | .[0].version | split(":") | .[-1]')

curl -fkLOZ --compressed --connect-timeout 10 --retry 5 http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user_${qus_ver}_amd64.deb
dpkg -x "qemu-user_${qus_ver}_amd64.deb" "$(pwd)/qus"

# Register qemu by official binfmt.
exportdir=$(pwd)/tmp
binfmt_ver=$(echo ${qus_ver} | sed -n 's,\([0-9]\+\.[0-9]\+\).*,\1,gp')
curl -fkLOZ --compressed --connect-timeout 10 --retry 5 https://raw.githubusercontent.com/qemu/qemu/stable-${binfmt_ver}/scripts/qemu-binfmt-conf.sh
chmod +x qemu-binfmt-conf.sh

# Modify the package name to avoid potential conflits. For example, it need the modify the package name
# to 'qemu-user-static' if use package 'qemu-user-static'.
sed -i 's/^package qemu-\$cpu$/package qemu-test-static/g' qemu-binfmt-conf.sh
./qemu-binfmt-conf.sh --qemu-path "$(pwd)/qus/usr/bin" --debian --exportdir "${exportdir}" --persistent yes
sudo update-binfmts --importdir ${exportdir} --import
