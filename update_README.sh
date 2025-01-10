#!/bin/sh

set -eET -o pipefail
. ./scripts/build_default.sh

VERSION=${1:-0.0.0}
BRANCH="$(echo $VERSION | cut -d '.' -f 1,2 | tr '.' '_')_x"
GITHUB_SERVER_URL=https://github.com

for ver in RC_1_2 RC_2_0; do
	eval "hash_full=$(git ls-remote ${GITHUB_SERVER_URL}/arvidn/libtorrent refs/heads/$ver | cut -f1)"
	hash_9="$(echo -n $hash_full | head -c 9)"
	sed -i 's;\['$ver'@\w\{9\}\]\(('$GITHUB_SERVER_URL'/arvidn/libtorrent/commits/'$ver'?before\)=\w\{40\}\(+35&branch='$ver')\);['$ver'@'$hash_9']\1='$hash_full'\2;g' ./README.md
done

for link in static dynamic; do
	for pkg in boost openssl zlib; do
		_ver=$(find rsync -iwholename "rsync/${link}/*${pkg}/Makefile" -exec sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp' {} \;)
		eval "${pkg}_${link}_ver=${_ver}"
	done
done

[ -n "${boost_static_ver}" ] || boost_static_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/packages/refs/heads/master/libs/boost/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')
[ -n "${openssl_static_ver}" ] || openssl_static_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/openwrt/refs/heads/main/package/libs/openssl/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')
[ -n "${zlib_static_ver}" ] || zlib_static_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/openwrt/refs/heads/main/package/libs/zlib/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')

[ -n "${boost_dynamic_ver}" ] || boost_dynamic_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/packages/refs/heads/openwrt-23.05/libs/boost/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')
[ -n "${openssl_dynamic_ver}" ] || openssl_dynamic_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/openwrt/refs/heads/openwrt-23.05/package/libs/openssl/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')
[ -n "${zlib_dynamic_ver}" ] || zlib_dynamic_ver=$(curl -fskLZ https://raw.githubusercontent.com/openwrt/openwrt/refs/heads/openwrt-23.05/package/libs/zlib/Makefile | sed -n 's/PKG_VERSION:=\(\S\+\)/\1/gp')

sed -i -e "s/\(# Last updated time:\) .*\$/\1 $(date -u "+%F %T %z")/g" \
	-e '/\[ChangeLog\]/ s/\/blob\/v\+[0-9]\+_[0-9]\+_x\//\/blob\/v'$BRANCH'\//g' \
	-e 's/\* Boost.*/* Boost '$boost_dynamic_ver' \/ '$boost_static_ver'/g' \
	-e 's/\* openssl.*/* openssl '$openssl_dynamic_ver' \/ '$openssl_static_ver'/g' \
	-e 's/\* zlib.*/* zlib '$zlib_dynamic_ver' \/ '$zlib_static_ver'/g' \
	./README.md
