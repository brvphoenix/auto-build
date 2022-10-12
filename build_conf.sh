#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

qt_ver=$1
link_type=$2

# Restore the modified feeds sources
for d in $([ ! -d feeds ] || ls feeds | cut -d . -f 1 | sort | uniq); do
	cd feeds/$d;
	git checkout .;
	git clean -df;
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

# Use customized pkgs
if [ "${link_type}" = "static" ]; then
	rm -rf feeds/base/package/libs/openssl
	rm -rf feeds/packages/libs/pcre2
fi

[ -d '../mirror' ] && rsync -a ../mirror/* ./ || exit 1

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
	 sed -i "s/tool_present('aria2c', 'aria2')/0/g" scripts/download.pl
fi
