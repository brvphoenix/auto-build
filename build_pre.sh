#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

qt_ver=$1
libt_ver=$2
link_type=$3

mkdir -p ./mirror ./mirror/package/self
cp -r ./qt_repo/qbittorrent/{luci-app-qbittorrent,qbittorrent,qtbase,qttools} ./mirror/package/self

if [ "${USE_LIBT_LOCAL}" = "true" ]; then
	# Use custom libtorrent-rasterbar
	mv ./auto-build/rsync/common/package/self/libtorrent-rasterbar_${libt_ver} ./auto-build/rsync/common/package/self/libtorrent-rasterbar
else
	cp -r ./libt_repo/qbittorrent/libtorrent-rasterbar ./mirror/package/self
fi

rm -rf ./auto-build/rsync/common/package/self/libtorrent-rasterbar_*

[ -d "./auto-build/rsync/common" ] && rsync -a ./auto-build/rsync/common/* ./mirror
[ -d "./auto-build/rsync/${link_type}" ] && rsync -a ./auto-build/rsync/${link_type}/* ./mirror

# Add no-deprecated when built with openssl 3.0.x, libtorrent RC_2_0 and static linkage.
[ -d ./mirror/package/self/openssl ] && [ "${libt_ver}" = "2_0" ] && [ "${link_type}" = "static" ] && sed -i 's/\(OPENSSL_OPTIONS:=.*\)$/\1 no-deprecated/' ./mirror/package/self/openssl/Makefile

# Update the release number according the tag number
sed -i 's/^\(PKG_RELEASE\)=\S\+/\1='${USE_RELEASE_NUMBER:-1}'/g' ./mirror/package/self/qbittorrent/Makefile

if [ "${qt_ver}" = "5" ]; then
	# Make qmake compile in parallel (should be deleted when update to Qt6)
	mv ./auto-build/test.mk ./mirror/package/self/qtbase
	sed -i '/define Build\/Compile/i include ./test.mk' ./mirror/package/self/qtbase/Makefile

	# Only needed when use openssl 3.0.x
	[ -d ./mirror/package/self/openssl ] && sed -i 's/\(EXTRA_INCLUDE_LIBS =\)/\1 \\\n\tOPENSSL_LIBS="-lssl -lcrypto -latomic"/' ./mirror/package/self/qtbase/Makefile
fi

# Pathes has not been contained in the upstream.
mkdir -p ./mirror/package/self/qbittorrent/patches

# Hotfixes for official v4_5_x
curl -kLZ --compressed -o 0001.patch https://github.com/qbittorrent/qBittorrent/compare/release-4.5.0...v4_5_x.patch
mv 0001.patch ./mirror/package/self/qbittorrent/patches/0001.patch

curl -kLZ --compressed -o 0002.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18271.patch
mv 0002.patch ./mirror/package/self/qbittorrent/patches/0002.patch

rm -rf ./mirror/package/self/qbittorrent/patches/0001-Unify-the-way-to-generate-the-language-list-in-WebUI.patch

# Log view
curl -kLZ --compressed -o 0003.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18290.patch
mv 0003.patch ./mirror/package/self/qbittorrent/patches/0003.patch
