#! /bin/sh
USE_TARGET=$1
USE_SUBTARGET=$2
USE_ARCH=$3

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

sed -i "s/.*\(CONFIG_QT5_STATIC_BUILD\).*/\1=y/g" .config
sed -i "s/.*\(CONFIG_QT5_USING_SYSTEM_DC\).*/# \1 is not set/g" .config
sed -i "s/.*\(CONFIG_QT5_USING_SYSTEM_PCRE2\).*/# \1 is not set/g" .config
sed -i "s/.*\(CONFIG_QT5_USING_SYSTEM_ZLIB\).*/# \1 is not set/g" .config

sed -i "s/.*\(CONFIG_QBT_LIBTORRENT_STATIC_LINK\).*/\1=y/g" .config
sed -i "s/.*\(CONFIG_QBT_ZLIB_STATIC_LINK\).*/\1=y/g" .config

sed -i "s/.*CONFIG_QBT_DAEMON_LANG-zh[=\| ].*/CONFIG_QBT_DAEMON_LANG-zh=y/g" .config
sed -i "s/.*CONFIG_QBT_WEBUI_LANG-zh[=\| ].*/CONFIG_QBT_WEBUI_LANG-zh=y/g" .config

make defconfig

sed -i "s/.*\(CONFIG_QT5_OPENSSL_STATIC_RUNTIME\).*/\1=y/g" .config
sed -i "s/.*\(CONFIG_LUCI_LANG_zh_Hans\).*/\1=y/g" .config

make package/luci-app-qbittorrent/compile V=s -j$(nproc)

export TARGET_PATH=build/bin/targets/${USE_TARGET}/${USE_SUBTARGET}
export PACKAGE_PATH=build/bin/packages/${USE_ARCH}

cd ..
mkdir -p ./${USE_ARCH}-static
cp -f ${PACKAGE_PATH}/base/*qbittorrent*.ipk ./${USE_ARCH}-static/
cp -f ${TARGET_PATH}/packages/libstdcpp* ./${USE_ARCH}-static/

[ "$USE_ARCH" = "mips_24kc" ] || [ "$USE_ARCH" = "mipsel_24kc" ] && cp -f ${TARGET_PATH}/packages/libatomic* ./${USE_ARCH}-static/

tar -cJvf ${USE_ARCH}-static.tar.xz ${USE_ARCH}-static
