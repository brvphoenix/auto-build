#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

qt_ver=$1
libt_ver=$2
link_type=$3

mkdir -p ../mirror ../mirror/package/self
cp -r ../qt_repo/qbittorrent/{luci-app-qbittorrent,qbittorrent,qtbase,qttools} ../mirror/package/self

# Use custom libtorrent-rasterbar
# cp -r ../libt_repo/qbittorrent/libtorrent-rasterbar ../mirror/package/self
mv ../auto-build/rsync/common/package/self/libtorrent-rasterbar_${libt_ver} ../auto-build/rsync/common/package/self/libtorrent-rasterbar
rm -rf ../auto-build/rsync/common/package/self/libtorrent-rasterbar_*
rm -rf feeds/packages/libs/libtorrent-rasterbar

[ -d "../auto-build/rsync/common" ] && rsync -a ../auto-build/rsync/common/* ../mirror
[ -d "../auto-build/rsync/${link_type}" ] && rsync -a ../auto-build/rsync/${link_type}/* ../mirror

# Add no-deprecated when built with openssl 3.0.x, libtorrent RC_2_0 and static linkage.
[ -d ../mirror/package/self/openssl ] && [ "${libt_ver}" = "2_0" ] && [ "${link_type}" = "static" ] && sed -i 's/\(OPENSSL_OPTIONS:=.*\)$/\1 no-deprecated/' ../mirror/package/self/openssl/Makefile

# Update the release number according the tag number
sed -i 's/^\(PKG_RELEASE\)=\S\+/\1='${USE_RELEASE_NUMBER:-1}'/g' ../mirror/package/self/qbittorrent/Makefile

if [ "${qt_ver}" = "5" ]; then
	# Make qmake compile in parallel (should be deleted when update to Qt6)
	mv ../auto-build/test.mk ../mirror/package/self/qtbase
	sed -i '/define Build\/Compile/i include ./test.mk' ../mirror/package/self/qtbase/Makefile

	# Only needed when use openssl 3.0.x
	[ -d ../mirror/package/self/openssl ] && sed -i 's/\(EXTRA_INCLUDE_LIBS =\)/\1 \\\n\tOPENSSL_LIBS="-lssl -lcrypto -latomic"/' ../mirror/package/self/qtbase/Makefile
fi

# Pathes has not been contained in the upstream.
curl -kLOZ --compressed ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY_OWNER}/qBittorrent/commit/daaf8a6f5.patch
mkdir -p ../mirror/package/self/qbittorrent/patches
mv daaf8a6f5.patch ../mirror/package/self/qbittorrent/patches/0001-daaf8a6f5.patch
