#! /bin/sh
USE_TARGET=$1
USE_SUBTARGET=$2
USE_ARCH=$3
USE_LINK=$4

mv ./SomePackages/qbittorrent ./build/package/
rm -rf build/package/qbittorrent/libtorrent-rasterbar
mv ./libtorrent-rasterbar build/package/qbittorrent/

cd build

sed -i 's/git\.openwrt\.org\/openwrt\/openwrt/github\.com\/openwrt\/openwrt/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/feed\/packages/github\.com\/openwrt\/packages/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/project\/luci/github\.com\/openwrt\/luci/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/feed\/telephony/github\.com\/openwrt\/telephony/g' ./feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

make defconfig

[ "$USE_LINK" = "static" ] && {
	sed -i "s/.*\(CONFIG_QT5_STATIC_BUILD\).*/\1=y/g" .config
	sed -i "s/.*\(CONFIG_QT5_USING_SYSTEM_DC\).*/# \1 is not set/g" .config
	sed -i "s/.*\(CONFIG_QT5_USING_SYSTEM_PCRE2\).*/# \1 is not set/g" .config
	sed -i "s/.*\(CONFIG_QT5_USING_SYSTEM_ZLIB\).*/\1=y/g" .config

	sed -i "s/.*\(CONFIG_QBT_LIBTORRENT_STATIC_LINK\).*/\1=y/g" .config
	sed -i "s/.*\(CONFIG_QBT_ZLIB_STATIC_LINK\).*/\1=y/g" .config
}

make defconfig

[ "$USE_LINK" = "static" ] && sed -i "s/.*\(CONFIG_QT5_OPENSSL_STATIC_RUNTIME\).*/\1=y/g" .config

sed -i "s/.*CONFIG_QBT_DAEMON_LANG-zh[=\| ].*/CONFIG_QBT_DAEMON_LANG-zh=y/g" .config
sed -i "s/.*CONFIG_QBT_WEBUI_LANG-zh[=\| ].*/CONFIG_QBT_WEBUI_LANG-zh=y/g" .config
sed -i "s/.*\(CONFIG_LUCI_LANG_zh_Hans\).*/\1=y/g" .config

make package/luci-app-qbittorrent/compile V=s -j$(nproc)

export TARGET_PATH=build/bin/targets/${USE_TARGET}/${USE_SUBTARGET}
export SAVE_PATH=${USE_ARCH}-${USE_LINK}

cd ..
mkdir -p ${SAVE_PATH}

if [ "$USE_LINK" = "static" ]; then
	cp -f $(find build/bin/packages -type f -iname *qbittorrent*.ipk) ${SAVE_PATH}
	cp -f ${TARGET_PATH}/packages/libstdcpp* ${SAVE_PATH}

	[ "$USE_ARCH" = "mips_24kc" ] || [ "$USE_ARCH" = "mipsel_24kc" ] && cp -f ${TARGET_PATH}/packages/libatomic* ${SAVE_PATH}
else
	mkdir -p ${SAVE_PATH}/1 ${SAVE_PATH}/2
	cp -f $(find build/bin/packages -type f -iname qt5*) ${SAVE_PATH}/1
	cp -f $(find build/bin/packages -type f -iname  *torrent*.ipk) ${SAVE_PATH}/1
	cp -f $(find build/bin/packages -type f -iname  libopenssl1*) ${SAVE_PATH}/2
	cp -f $(find build/bin/packages -type f -iname boost-system*) ${SAVE_PATH}/2
	cp -f $(find build/bin/packages -type f -iname libdouble-conversion*) ${SAVE_PATH}/2
	cp -f $(find build/bin/packages -type f -iname libpcre2-16*) ${SAVE_PATH}/2
	cp -f $(find build/bin/packages -type f -iname  zlib_*) ${SAVE_PATH}/2
	cp -f ${TARGET_PATH}/packages/libstdcpp* ${SAVE_PATH}/2

	[ "$USE_ARCH" = "mips_24kc" ] || [ "$USE_ARCH" = "mipsel_24kc" ] && cp -f ${TARGET_PATH}/packages/libatomic* ${SAVE_PATH}/2
fi

tar -cJvf ${SAVE_PATH}.tar.xz ${SAVE_PATH}

