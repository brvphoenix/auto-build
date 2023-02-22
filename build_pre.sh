#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

qt_ver=$1
libt_ver=$2
link_type=$3

MIRROR_DIR=./mirror
MIRROR_SELF_DIR=${MIRROR_DIR}/package/self

mkdir -p ${MIRROR_DIR} ${MIRROR_SELF_DIR}
cp -r ./qt_repo/qbittorrent/{luci-app-qbittorrent,qbittorrent,qtbase,qttools} ${MIRROR_SELF_DIR}

if [ "${USE_LIBT_LOCAL}" = "true" ]; then
	# Use custom libtorrent-rasterbar
	mv ./auto-build/rsync/common/package/self/libtorrent-rasterbar_${libt_ver} ./auto-build/rsync/common/package/self/libtorrent-rasterbar
else
	cp -r ./libt_repo/qbittorrent/libtorrent-rasterbar ${MIRROR_SELF_DIR}
fi

rm -rf ./auto-build/rsync/common/package/self/libtorrent-rasterbar_*

[ -d "./auto-build/rsync/common" ] && rsync -a ./auto-build/rsync/common/* ${MIRROR_DIR}
[ -d "./auto-build/rsync/${link_type}" ] && rsync -a ./auto-build/rsync/${link_type}/* ${MIRROR_DIR}

# Add no-deprecated when built with openssl 3.0.x, libtorrent RC_2_0 and static linkage.
#[ -d ${MIRROR_SELF_DIR}/openssl ] && [ "${libt_ver}" = "2_0" ] && [ "${link_type}" = "static" ] && sed -i 's/\(OPENSSL_OPTIONS:=.*\)$/\1 no-deprecated/' ${MIRROR_SELF_DIR}/openssl/Makefile

# Update the release number according the tag number
sed -i 's/^\(PKG_RELEASE\)=\S\+/\1='${USE_RELEASE_NUMBER:-1}'/g' ${MIRROR_SELF_DIR}/qbittorrent/Makefile

if [ "${qt_ver}" = "5" ]; then
	# Make qmake compile in parallel (should be deleted when update to Qt6)
	mv ./auto-build/test.mk ${MIRROR_SELF_DIR}/qtbase
	sed -i '/define Build\/Compile/i include ./test.mk' ${MIRROR_SELF_DIR}/qtbase/Makefile

	# Only needed when use openssl 3.0.x
	if [ "${link_type}" = "static" ]; then
		sed -i 's/\(EXTRA_INCLUDE_LIBS =\)/\1 \\\n\tOPENSSL_LIBS="-lssl -lcrypto -latomic"/' ${MIRROR_SELF_DIR}/qtbase/Makefile
	fi
fi

# Pathes has not been contained in the upstream.
mkdir -p ${MIRROR_SELF_DIR}/qbittorrent/patches

PATCH_DIR=${MIRROR_SELF_DIR}/qbittorrent/patches
# Hotfixes for official v4_5_x
curl -kLZ --compressed -o ${PATCH_DIR}/0001.patch https://github.com/qbittorrent/qBittorrent/compare/release-4.5.1...v4_5_x.patch

# Backport
# curl -kLZ --compressed -o ${PATCH_DIR}/0002.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18452.patch

# Log view
curl -kLZ --compressed -o ${PATCH_DIR}/0003.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18290.patch

# Log setting and compressing
#curl -kLZ --compressed -o ${PATCH_DIR}/0004.patch https://github.com/brvphoenix/qBittorrent/compare/filelogger-compressed~5...filelogger-compressed.patch
#rm -rf ${PATCH_DIR}/0806-filelogger.patch

## CleanUp
#curl -kLZ --compressed -o ${PATCH_DIR}/0005.patch https://github.com/brvphoenix/qBittorrent/compare/cleanup~2...cleanup.patch
