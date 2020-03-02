#! /bin/sh

cd build

sed -i 's/git\.openwrt\.org\/openwrt\/openwrt/github\.com\/openwrt\/openwrt/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/feed\/packages/github\.com\/openwrt\/packages/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/project\/luci/github\.com\/openwrt\/luci/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/feed\/telephony/github\.com\/openwrt\/telephony/g' ./feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

make defconfig V=s

sed -i "s/.*CONFIG_qbt_daemon_Lang-zh[=\| ].*/CONFIG_qbt_daemon_Lang-zh=y/g" .config
sed -i "s/.*CONFIG_qbt_webui_Lang-zh[=\| ].*/CONFIG_qbt_webui_Lang-zh=y/g" .config

make package/luci-app-qbittorrent/compile V=s -j$(nproc)

export TARGET_PATH=build/bin/targets/${{env.USE_TARGET}}/${{env.USE_SUBTARGET}}
export PACKAGE_PATH=build/bin/packages/${{env.USE_ARCH}}

mkdir -p ./${{env.USE_ARCH}}/1 ./${{env.USE_ARCH}}/2
cp -f ${PACKAGE_PATH}/base/qt5* ./${{env.USE_ARCH}}/1
cp -f ${PACKAGE_PATH}/base/*torrent*.ipk ./${{env.USE_ARCH}}/1
cp -f ${PACKAGE_PATH}/base/libopenssl* ./${{env.USE_ARCH}}/2
cp -f ${PACKAGE_PATH}/packages/boost-system* ./${{env.USE_ARCH}}/2
cp -f ${PACKAGE_PATH}/packages/libdouble-conversion* ./${{env.USE_ARCH}}/2
cp -f ${PACKAGE_PATH}/packages/libpcre2-16* ./${{env.USE_ARCH}}/2
cp -f ${PACKAGE_PATH}/base/zlib_* ./${{env.USE_ARCH}}/2
cp -f ${TARGET_PATH}/packages/libstdcpp* ./${{env.USE_ARCH}}/2
tar -cJvf ${{env.USE_ARCH}}.tar.xz ${{env.USE_ARCH}}
