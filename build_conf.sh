#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

qt_ver=$1
libt_ver=$2
link_type=$3

# Restore the modified feeds sources
rm -rf feeds/local{,.tmp,.index,.targetindex}
for d in feeds/*; do
	if [ -d "$d" ] && [ -d "$d/.git" ]; then
		cd $d;
		if $(git status >> /dev/null 2>&1); then
			git checkout .;
			git clean -df;
		fi
		cd -
	fi
done

# use the github source
sed \
	-e 's,https://git\.openwrt\.org/feed/,https://github.com/openwrt/,' \
	-e 's,https://git\.openwrt\.org/openwrt/,https://github.com/openwrt/,' \
	-e 's,https://git\.openwrt\.org/project/,https://github.com/openwrt/,' \
	feeds.conf.default | grep -v "^src-git-full \(routing\|telephony\) .*" > feeds.conf

echo "src-cpy local ${GITHUB_WORKSPACE}/qt_repo" >> feeds.conf

echo "::group::Update feeds"
if [ "${IGNORE_UPDATE_FEEDS}" != "true" ]; then
	# Sync with the source
	./scripts/feeds update -f base packages luci local
else
	# Update custom feeds
	./scripts/feeds update local
fi
echo "::endgroup::"

# Sync openssl module
[ "${link_type}" = "dynamic" -o -n "$(ls include/openssl-*.mk 2>/dev/null)" ] || rsync -a feeds/base/include/openssl-*.mk include

for extra_script in ../auto-build/scripts/tmp/*.sh; do
	. "${extra_script}"
done

cat > .config <<EOF
# CONFIG_ALL_KMODS is not set
# CONFIG_ALL is not set
CONFIG_PACKAGE_luci-app-qbittorrent=y
CONFIG_QBT_REMOVE_GUI_TR=y
CONFIG_QBT_LANG-zh_CN=y
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

	# Disable deprecated features if built statically
	[ "${libt_ver}" != "2_0" ] || \
	cat >> .config <<-EOF
		# CONFIG_OPENSSL_ENGINE is not set
		# CONFIG_OPENSSL_WITH_DEPRECATED is not set
	EOF
fi

echo "::group::Install packages"
./scripts/feeds install -p local luci-app-qbittorrent
echo "::endgroup::"

find -L package/feeds/*/{boost,libtorrent-rasterbar,luci-app-qbittorrent,openssl,pcre2,qbittorrent,qtbase,qttools,zlib} .config \
	-type f -print0 | sort -z | xargs -0 cat | sha256sum | awk '{print $1}' | xargs -i echo "USE_BINARY_HASH={}" >> $GITHUB_ENV
cat package/feeds/*/{boost,openssl,pcre2,qbittorrent,zlib}/Makefile | grep '\(PKG_HASH\|PKG_MIRROR_HASH\)' | \
	sha256sum | awk '{print $1}' | xargs -i echo "USE_DL_HASH={}" >> $GITHUB_ENV
