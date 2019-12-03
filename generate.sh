#! /bin/sh

cd build

sed -i 's/git\.openwrt\.org\/openwrt\/openwrt/github\.com\/openwrt\/openwrt/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/feed\/packages/github\.com\/openwrt\/packages/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/project\/luci/github\.com\/openwrt\/luci/g' ./feeds.conf.default
sed -i 's/git\.openwrt\.org\/feed\/telephony/github\.com\/openwrt\/telephony/g' ./feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

make defconfig V=s -j1

sed -i "s/.*CONFIG_qbt_daemon_Lang-zh[=\| ].*/CONFIG_qbt_daemon_Lang-zh=y/g" .config
sed -i "s/.*CONFIG_qbt_webui_Lang-zh[=\| ].*/CONFIG_qbt_webui_Lang-zh=y/g" .config
