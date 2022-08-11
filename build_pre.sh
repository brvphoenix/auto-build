#!/bin/bash

set -eET -o pipefail

failure() {
  echo "Failed at line $1: $2"
}

trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

. "$GITHUB_ENV"

qt_ver=$1
libt_ver=$2
link_type=$3

# Restore the modified feeds sources
for d in $([ ! -d feeds ] || ls feeds | cut -d . -f 1 | sort | uniq); do
	cd feeds/$d;
	git checkout .;
	cd ../..;
done

# use the github source
sed -i 's/git.openwrt\.org\/openwrt\/openwrt/github.com\/openwrt\/openwrt/g' ./feeds.conf.default
sed -i 's/git.openwrt\.org\/feed/github.com\/openwrt/g' ./feeds.conf.default
sed -i 's/git.openwrt\.org\/project\/luci/github.com\/openwrt\/luci/g' ./feeds.conf.default

# Use the stable release snapshot feeds sources (should upgrade if update the release version).
[ "${link_type}" = "dynamic" ] && sed -i 's/\(\.git\)\^\w\+/\1\;openwrt-21.02/g' ./feeds.conf.default

# Sync with the source
./scripts/feeds update -a

# Use custom libtorrent-rasterbar
rm -rf feeds/packages/libs/libtorrent-rasterbar

# Use custom openssl when static building
[ "${link_type}" = "static" ] && rm -rf feeds/base/package/libs/openssl || rm -rf ../auto-build/rsync/package/self/openssl

mkdir -p package/self
cp -r ../qt_repo/qbittorrent/{luci-app-qbittorrent,qbittorrent,qtbase,qttools} package/self
# Use the libtorrent official latest commit
# cp -r ../libt_repo/qbittorrent/libtorrent-rasterbar package/self
cp -r ../auto-build/rsync/package/self/libtorrent-rasterbar_${libt_ver} package/self/libtorrent-rasterbar
rm -r ../auto-build/rsync/package/self/libtorrent-rasterbar_*

rsync -a ../auto-build/rsync/* ./

# Add no-deprecated when built with openssl 3.0.x, libtorrent RC_2_0 and static linkage.
[ -d package/self/openssl ] && [ "${libt_ver}" = "2_0" ] && [ "${link_type}" = "static" ] && sed -i 's/\(OPENSSL_OPTIONS:=.*\)$/\1 no-deprecated/' package/self/openssl/Makefile

# Update the release number according the tag number
sed -i 's/^\(PKG_RELEASE\)=\S\+/\1='${USE_RELEASE_NUMBER:-1}'/g' package/self/qbittorrent/Makefile

if [ "${qt_ver}" = "5" ]; then
	# Make qmake compile in parallel (should be deleted when update to Qt6)
	mv ../auto-build/test.mk package/self/qtbase
	sed -i '/define Build\/Compile/i include ./test.mk' package/self/qtbase/Makefile

	# Only needed when use openssl 3.0.x
	[ -d package/self/openssl ] && sed -i 's/\(EXTRA_INCLUDE_LIBS =\)/\1 \\\n\tOPENSSL_LIBS="-lssl -lcrypto -latomic"/' package/self/qtbase/Makefile
fi

# Pathes has not been contained in the upstream.
curl -kLOZ --compressed ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY_OWNER}/qBittorrent/commit/daaf8a6f5.patch
mkdir -p package/self/qbittorrent/patches
mv daaf8a6f5.patch package/self/qbittorrent/patches/0001-daaf8a6f5.patch

# Update the indexs
make package/symlinks-install

cat > .config <<EOF
# CONFIG_ALL_KMODS is not set
# CONFIG_ALL is not set
CONFIG_PACKAGE_luci-app-qbittorrent=y
CONFIG_QBT_REMOVE_GUI_TR=y
CONFIG_QBT_LANG-zh=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF

if [ "${link_type}" = "static" ]; then
	cat >> .config <<-EOF
		CONFIG_QT${qt_ver}_OPENSSL_LINKED=y
		CONFIG_QT${qt_ver}_STATIC=y
		# CONFIG_QT${qt_ver}_SYSTEM_DC is not set
		CONFIG_QT${qt_ver}_SYSTEM_PCRE2=y
		CONFIG_QT${qt_ver}_SYSTEM_ZLIB=y
		CONFIG_QBT_STATIC_LINK=y
	EOF

	sed -i 's/\(-DBUILD_SHARED_LIBS=\)ON/\1OFF/' feeds/packages/libs/pcre2/Makefile
	sed -i 's/\(-DBUILD_STATIC_LIBS=\)OFF/\1ON/' feeds/packages/libs/pcre2/Makefile
	sed -i '/(call BuildPackage,libpcre2)/i Package/libpcre2/install=true\nPackage/libpcre2-16/install=true\nPackage/libpcre2-32/install=true' feeds/packages/libs/pcre2/Makefile
	sed -i 's/\(-DBUILD_SHARED_LIBS=\)ON/\1OFF/' package/self/libtorrent-rasterbar/Makefile
	sed -i '/^define Package\/libtorrent-rasterbar$/{:a;N;/endef/!ba;s/\(endef\)/  BUILDONLY:=1\n\1/g}' package/self/libtorrent-rasterbar/Makefile
fi
