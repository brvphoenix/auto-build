#! /bin/sh
USE_TARGET=$1
USE_SUBTARGET=$2
USE_ARCH=$3

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

export TARGET_PATH=build/bin/targets/${USE_TARGET}/${USE_SUBTARGET}
export PACKAGE_PATH=build/bin/packages/${USE_ARCH}

cd ..
mkdir -p ./${USE_ARCH}/1 ./${USE_ARCH}/2
cp -f ${PACKAGE_PATH}/base/qt5* ./${USE_ARCH}/1
cp -f ${PACKAGE_PATH}/base/*torrent*.ipk ./${USE_ARCH}/1
cp -f ${PACKAGE_PATH}/base/libopenssl* ./${USE_ARCH}/2
cp -f ${PACKAGE_PATH}/packages/boost-system* ./${USE_ARCH}/2
cp -f ${PACKAGE_PATH}/packages/libdouble-conversion* ./${USE_ARCH}/2
cp -f ${PACKAGE_PATH}/packages/libpcre2-16* ./${USE_ARCH}/2
cp -f ${PACKAGE_PATH}/base/zlib_* ./${USE_ARCH}/2
cp -f ${TARGET_PATH}/packages/libstdcpp* ./${USE_ARCH}/2
tar -cJvf ${USE_ARCH}.tar.xz ${USE_ARCH}
