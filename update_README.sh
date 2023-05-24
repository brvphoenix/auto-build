#!/bin/sh

set -eET -o pipefail
. ./build_default.sh

VERSION=${1:-0.0.0}
BRANCH="$(echo $VERSION | cut -d '.' -f 1,2 | tr '.' '_')_x"
GITHUB_SERVER_URL=https://github.com

for ver in RC_1_2 RC_2_0; do
	eval "hash_full=$(git ls-remote ${GITHUB_SERVER_URL}/arvidn/libtorrent refs/heads/$ver | cut -f1)"
	hash_9="$(echo -n $hash_full | head -c 9)"
	sed -i 's;\['$ver'@\w\{9\}\]\(('$GITHUB_SERVER_URL'/arvidn/libtorrent/commits/'$ver'?before\)=\w\{40\}\(+35&branch='$ver')\);['$ver'@'$hash_9']\1='$hash_full'\2;g' ./README.md
done

boost_static_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/packages/master/libs/boost/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')
openssl_static_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/openwrt/main/package/libs/openssl/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')
zlib_static_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/openwrt/main/package/libs/zlib/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')

boost_dynamic_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/packages/openwrt-22.03/libs/boost/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')
openssl_dynamic_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/openwrt/openwrt-22.03/package/libs/openssl/Makefile | sed -n -e 's/PKG_BASE:=\(\S\+\).*/\1/gp' -e 's/PKG_BUGFIX:=\(\S\+\).*/\1/gp' | xargs echo | sed 's/\s\+//g')
zlib_dynamic_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/openwrt/openwrt-22.03/package/libs/zlib/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')


sed -i -e 's/\(# Version\) \S\+$/\1 '$VERSION'/g' \
	-e '/\[ChangeLog\]/ s/\/blob\/v[0-9]\+_[0-9]\+_x\//\/blob\/v'$BRANCH'\//g' \
	-e 's/\* Boost.*/* Boost '$boost_dynamic_ver' \/ '$boost_static_ver'/g' \
	-e 's/\* openssl.*/* openssl '$openssl_dynamic_ver' \/ '$openssl_static_ver'/g' \
	-e 's/\* zlib.*/* zlib '$zlib_dynamic_ver' \/ '$zlib_static_ver'/g' \
	./README.md
