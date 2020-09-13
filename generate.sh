#! /bin/sh
USE_TARGET=$1
USE_SUBTARGET=$2
USE_ARCH=$3
USE_LINK=$4

find ./SomePackages/qbittorrent -mindepth 1 -maxdepth 1 -path ./SomePackages/qbittorrent/CMake -prune -o -type d -exec cp -r {} ./build/package/ \;
find build/package -maxdepth 2 -type d -name libtorrent-rasterbar | xargs rm -rf
mv ./libtorrent-rasterbar build/package/

cd build

sed -i 's/git\.openwrt\.org\/openwrt\/openwrt/github\.com\/openwrt\/openwrt/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/feed\/packages/github\.com\/openwrt\/packages/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/project\/luci/github\.com\/openwrt\/luci/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/feed\/telephony/github\.com\/openwrt\/telephony/g' ./feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

rm .config && touch .config

[ "$USE_LINK" = "static" ] && {
	cat >> .config <<EOF
CONFIG_QT5_OPENSSL_LINKED=y
CONFIG_QT5_STATIC=y
# CONFIG_QT5_SYSTEM_DC is not set
CONFIG_QT5_SYSTEM_PCRE2=y
CONFIG_QT5_SYSTEM_ZLIB=y
CONFIG_QBT_STATIC_LINK=y
EOF

sed -i '/HOST_FPIC:=-fPIC/aFPIC:=-fPIC' rules.mk
find feeds -type d -name 'pcre2' | xargs rm -rf;
mv ../pcre2 package/
}

cat >> .config <<EOF
CONFIG_QBT_REMOVE_GUI_TR=y
CONFIG_QBT_DAEMON_LANG-zh=y
CONFIG_QBT_WEBUI_LANG-zh=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF

cat >> .config <<EOF
# CONFIG_boost-libs-all is not set
# CONFIG_boost-test-pkg is not set
# CONFIG_boost-graph-parallel is not set
CONFIG_PACKAGE_boost-atomic=m
CONFIG_PACKAGE_boost-chrono=m
# CONFIG_PACKAGE_boost-container is not set
CONFIG_PACKAGE_boost-context=m
# CONFIG_PACKAGE_boost-contract is not set
# CONFIG_PACKAGE_boost-coroutine is not set
CONFIG_PACKAGE_boost-date_time=m
# CONFIG_PACKAGE_boost-fiber is not set
CONFIG_PACKAGE_boost-filesystem=m
# CONFIG_PACKAGE_boost-graph is not set
CONFIG_PACKAGE_boost-iostreams=m
# CONFIG_PACKAGE_boost-log is not set
# CONFIG_PACKAGE_boost-math is not set
CONFIG_PACKAGE_boost-program_options=m
# CONFIG_PACKAGE_boost-python3 is not set
# CONFIG_PACKAGE_boost-random is not set
CONFIG_PACKAGE_boost-regex=m
# CONFIG_PACKAGE_boost-serialization is not set
# CONFIG_PACKAGE_boost-wserialization is not set
# CONFIG_PACKAGE_boost-stacktrace is not set
CONFIG_PACKAGE_boost-system=m
CONFIG_PACKAGE_boost-thread=m
# CONFIG_PACKAGE_boost-timer is not set
# CONFIG_PACKAGE_boost-type_erasure is not set
# CONFIG_PACKAGE_boost-wave is not set
EOF

make defconfig

make package/luci-app-qbittorrent/compile V=s -j$(nproc) 2>&1 | tee ${USE_ARCH}-${USE_LINK}.log
XZ_OPT=-9 tar -cJf ${USE_ARCH}-${USE_LINK}.log.tar.xz ${USE_ARCH}-${USE_LINK}.log && mv ${USE_ARCH}-${USE_LINK}.log.tar.xz ../

export TARGET_PATH=build/bin/targets/${USE_TARGET}/${USE_SUBTARGET}
export SAVE_PATH=${USE_ARCH}-${USE_LINK}

cd ..
mkdir -p ${SAVE_PATH}

if [ "$USE_LINK" = "static" ]; then
	find build/bin/packages -type f -iname *qbittorrent* -exec cp -f {} ${SAVE_PATH} \;
else
	mkdir -p ${SAVE_PATH}/1 ${SAVE_PATH}/2
	find build/bin/packages -type f \( -iname qt5* -or -iname  *torrent*.ipk \) -exec cp -f {} ${SAVE_PATH}/1 \;

	find build/bin/packages -type f \( \
		-iname libopenssl1* -or \
		-iname boost-system* -or \
		-iname libdouble-conversion* -or \
		-iname libpcre2-16* -or \
		-iname zlib_* \
	\) -exec cp -f {} ${SAVE_PATH}/2 \;

	find build/bin/targets -type f -iname libstdcpp* -exec cp -f {} ${SAVE_PATH}/2 \;

	[ "$USE_ARCH" = "mips_24kc" ] || [ "$USE_ARCH" = "mipsel_24kc" ] && \
		find build/bin/targets -type f -iname libatomic* -exec cp -f {} ${SAVE_PATH}/2 \;
fi

tar -cJf ${SAVE_PATH}.tar.xz ${SAVE_PATH}

