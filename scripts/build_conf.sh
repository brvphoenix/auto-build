#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

# Restore the modified feeds sources
rm -rf feeds/${CUR_LOCAL_REPO_NAME}{,.tmp,.index,.targetindex}
for d in feeds/*; do
	if [ -d "$d" -a -d "$d/.git" ]; then
		if $(git -C "$d" status >> /dev/null 2>&1); then
			git -C "$d" checkout .;
			git -C "$d" clean -dfx;
		fi
	fi
done

# use the github source
sed \
	-e 's,https://git\.openwrt\.org/feed/,https://github.com/openwrt/,' \
	-e 's,https://git\.openwrt\.org/openwrt/,https://github.com/openwrt/,' \
	-e 's,https://git\.openwrt\.org/project/,https://github.com/openwrt/,' \
	feeds.conf.default | grep -Ev "^src-git(-full)? (routing|telephony) .*" > feeds.conf

echo "src-cpy ${CUR_LOCAL_REPO_NAME} ${GITHUB_WORKSPACE}/${CUR_QBT_REPO_NAME}" >> feeds.conf

echo "::group::Update feeds"
./scripts/feeds update -f base packages luci ${CUR_LOCAL_REPO_NAME}
echo "::endgroup::"

# Sync openssl module
[ "${CUR_LINK_TYPE}" = "dynamic" -o -n "$(ls include/openssl-*.mk 2>/dev/null)" ] || rsync -a feeds/base/include/openssl-*.mk include

for extra_script in ../${CUR_REPO_NAME}/scripts/extensions/*.sh; do
	echo "::group::Runing ${extra_script}"
	[ ! -f "${extra_script}" ] || bash "${extra_script}"
	echo "::endgroup::"
done

cat > .config <<EOF
# CONFIG_ALL_KMODS is not set
# CONFIG_ALL is not set
CONFIG_PACKAGE_luci-app-qbittorrent=y
CONFIG_QBT_REMOVE_GUI_TR=y
CONFIG_QBT_LANG-zh_CN=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF

if [ "${CUR_LINK_TYPE}" = "static" ]; then
	cat >> .config <<-EOF
		CONFIG_QT${CUR_QT_VERSION}_OPENSSL_LINKED=y
		CONFIG_QT${CUR_QT_VERSION}_STATIC=y
		# CONFIG_QT${CUR_QT_VERSION}_SYSTEM_DC is not set
		CONFIG_QT${CUR_QT_VERSION}_SYSTEM_PCRE2=y
		CONFIG_QT${CUR_QT_VERSION}_SYSTEM_ZLIB=y
		CONFIG_QBT_STATIC_LINK=y
	EOF

	# Disable deprecated features if built statically
	[ "${CUR_LIBT_VERSION}" != "2_0" ] || \
	cat >> .config <<-EOF
		# CONFIG_OPENSSL_ENGINE is not set
		# CONFIG_OPENSSL_WITH_DEPRECATED is not set
	EOF
fi

echo "::group::Install packages"
./scripts/feeds install -p ${CUR_LOCAL_REPO_NAME} luci-app-qbittorrent
echo "::endgroup::"

find -L package/feeds/*/{boost,libtorrent-rasterbar,luci-app-qbittorrent,openssl,pcre2,qbittorrent,qtbase,qttools,zlib} .config \
	-type f -print0 | sort -z | { \
		path=$(xargs --null echo); \
		hash=$(cat -A $path | sha256sum | awk '{print $1}'); \
		permission=$(find $path -printf "%m\n" | sha256sum | awk '{print $1}'); \
		echo "bin-hash=${hash}-${permission}" >> $GITHUB_OUTPUT; \
	}
cat package/feeds/*/{boost,openssl,pcre2,qbittorrent,zlib}/Makefile | grep '\(PKG_HASH\|PKG_MIRROR_HASH\)' | \
	sha256sum | awk '{print $1}' | xargs -i echo "src-hash={}" >> $GITHUB_OUTPUT
