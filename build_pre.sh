#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

qt_ver=$1
libt_ver=$2
link_type=$3

# add modified pkgs to CUSTOM_DIR
QT_REPO_DIR=./qt_repo
LIBT_REPO_DIR=./libt_repo
CUSTOM_DIR=${QT_REPO_DIR}/custom
RSYNC_DIR=./auto-build/rsync

if [ "${USE_LIBT_LOCAL}" = "true" ]; then
	# Use custom libtorrent-rasterbar
	mv ${RSYNC_DIR}/common/libtorrent-rasterbar_${libt_ver} ${RSYNC_DIR}/common/libtorrent-rasterbar
else
	mv ${LIBT_REPO_DIR}/packages/libs/libtorrent-rasterbar ${RSYNC_DIR}/common/libtorrent-rasterbar
fi

rm -r ${RSYNC_DIR}/common/libtorrent-rasterbar_*

[ ! -d "${RSYNC_DIR}/common" ] || rsync -aK ${RSYNC_DIR}/common/* ${CUSTOM_DIR}
[ ! -d "${RSYNC_DIR}/${link_type}" ] || rsync -aK ${RSYNC_DIR}/${link_type}/* ${CUSTOM_DIR}

if [ "${link_type}" = "static" ]; then
	[ ! -f "${CUSTOM_DIR}/pcre2/Makefile" ] || \
		sed --follow-symlinks -i \
		-e '/CMAKE_OPTIONS += \\/{:a;n;s/\(-DBUILD_SHARED_LIBS=\)ON/\1OFF/;s/\(-DBUILD_STATIC_LIBS=\)OFF/\1ON/;s/$(CONFIG_PACKAGE_libpcre2-16)/y/g;/^$/!ba}' \
		-e '/^define Package\/libpcre2\/default$/{:b;N;/endef/!bb;/BUILDONLY:=1/!{s/\(endef\)/  BUILDONLY:=1\n\1/g}}' ${CUSTOM_DIR}/pcre2/Makefile
	[ ! -f "${CUSTOM_DIR}/libtorrent-rasterbar/Makefile" ] || \
		sed --follow-symlinks -i \
		-e 's/\(-DBUILD_SHARED_LIBS=\)ON/\1OFF/' \
		-e '/^define Package\/libtorrent-rasterbar$/{:a;N;/endef/!ba;/BUILDONLY:=1/!{s/\(endef\)/  BUILDONLY:=1\n\1/g}}' ${CUSTOM_DIR}/libtorrent-rasterbar/Makefile
fi

# Use modified libtorrent-rasterbar
rm -r ${QT_REPO_DIR}/packages/libs/libtorrent-rasterbar

# Update the release number according the tag number
if [ "${GITHUB_REF}" = "refs/tags/${GITHUB_REF_NAME}" ]; then
	release_count=$(git ls-remote -t ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY} "${GITHUB_REF%%-*}*" | wc -l)
	grep -oF "PKG_RELEASE=${release_count:-1}" ${QT_REPO_DIR}/packages/net/qbittorrent/Makefile || \
		sed --follow-symlinks -i 's/^\(PKG_RELEASE\)=\S\+/\1='${release_count:-1}'/g' ${QT_REPO_DIR}/packages/net/qbittorrent/Makefile
fi

if [ "${qt_ver}" = "5" ]; then
	# Make qmake compile in parallel (should be deleted when update to Qt6)
	mv ${RSYNC_DIR}/test.mk ${QT_REPO_DIR}/packages/qt${qt_ver}/qtbase
	sed --follow-symlinks -i '/define Build\/Compile/i include ./test.mk' ${QT_REPO_DIR}/packages/qt${qt_ver}/qtbase/Makefile

	# Only needed when use openssl 3.0.x
	if [ "${link_type}" = "static" ]; then
		sed --follow-symlinks -i 's/\(EXTRA_INCLUDE_LIBS =\)/\1 \\\n\tOPENSSL_LIBS="-lssl -lcrypto -latomic"/' ${QT_REPO_DIR}/packages/qt${qt_ver}/qtbase/Makefile
	fi
fi

# Pathes has not been contained in the upstream.
PATCH_DIR=${QT_REPO_DIR}/packages/net/qbittorrent/patches
mkdir -p ${PATCH_DIR}

# Hotfixes and backport for official v4_5_x
curl -kLZ --compressed -o ${PATCH_DIR}/0001.patch https://github.com/brvphoenix/qBittorrent/compare/release-4.5.5...stable_backup.patch

# # Backport
# curl -kLZ --compressed -o ${PATCH_DIR}/0002.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18727.patch

# # Log view
# curl -kLZ --compressed -o ${PATCH_DIR}/0003.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18290.patch

# # Log setting
# curl -kLZ --compressed -o ${PATCH_DIR}/0004-1.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18506.patch

# # Log compressing
# curl -kLZ --compressed -o ${PATCH_DIR}/0004-2.patch https://github.com/brvphoenix/qBittorrent/compare/compress-backup~1...compress.patch
rm -rf ${PATCH_DIR}/0806-filelogger.patch

## CleanUp
#curl -kLZ --compressed -o ${PATCH_DIR}/0005.patch https://github.com/brvphoenix/qBittorrent/compare/cleanup~2...cleanup.patch
