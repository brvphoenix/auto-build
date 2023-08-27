#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

target_name=$1
link_type=$2
qt_ver=$3
libt_ver=$4

# Parse json files
JSON_FILE=./${link_type}.json

for item in $(jq -r '.openwrt | to_entries[] | select(.value | (type != "object" and type != "array")) | "\(.key)=\(.value)"' ${JSON_FILE}); do
	eval "${item}"
done

for option in $(jq -r '.openwrt."'${target_name}'" | to_entries[] | "\(.key)=\(.value)"' ${JSON_FILE}); do
	eval "${option}"
done

generate_variant() {
	local name=$1
	local version=$2
	local keyring=$3
	local pattern=$4
	local name_upper=$(echo $name | tr 'a-z' 'A-Z')

	if [ -z "$(eval echo \${USE_${name_upper}_URL})" ]; then
		[ "${version}" = "snapshots" ] && version_path="snapshots" || version_path="releases/${version}"
		download_url=${USE_DOWNLOAD_SERVER}/${version_path}/targets/${target_name//-/\/}
		echo "USE_${name_upper}_URL=${download_url}" >> $GITHUB_ENV
	fi

	[ -f "${version}.sha256sums" ] || curl -ksLZ --compressed -o "${version}.sha256sums" ${download_url}/sha256sums
	[ -f "${version}.sha256sums.asc" ] || curl -ksLZ --compressed -o "${version}.sha256sums.asc" ${download_url}/sha256sums.asc

	# Verify the sha256sum with sha256sum.asc
	[ -f "${keyring}" ] || curl -fskLOZ --compressed --connect-timeout 10 --retry 5 https://raw.githubusercontent.com/openwrt/docker/main/keys/${keyring}
	gpg --import "${keyring}"
	gpg --with-fingerprint --verify ${version}.sha256sums.asc ${version}.sha256sums

	if [ -z "$(eval echo \${USE_${name_upper}_FILE})" -o -z "$(eval echo \${USE_${name_upper}_REVISION})" ]; then
		grep -i "${pattern}" ${version}.sha256sums > "${name}.sha256sums"
		fname=$(grep -io "${pattern}" "${name}.sha256sums")
		rev_info=$(grep -ioE "^\w+" "${name}.sha256sums" | head -c 10)
		echo "USE_${name_upper}_FILE=${fname}" >> $GITHUB_ENV
		echo "USE_${name_upper}_REVISION=${rev_info}" >> $GITHUB_ENV
	fi

	. $GITHUB_ENV
}

sdk_pattern="openwrt-sdk-.*.Linux-x86_64.tar.xz"
generate_variant "sdk" "${USE_SDK_VERSION}" "${USE_SDK_KEYRING}" "${sdk_pattern}"

if [ "${RUNTIME_TEST}" = "true" ]; then
	[ -n "${USE_QEMU_CPU}" ] && echo "QEMU_CPU=${USE_QEMU_CPU}" >> ${GITHUB_WORKSPACE}/docker_env || touch ${GITHUB_WORKSPACE}/docker_env

	if [ "${USE_IMAGEBUILDER}" = 'true' ]; then
		imagebuilder_pattern="openwrt-imagebuilder-.*.Linux-x86_64.tar.xz"
		generate_variant "imagebuilder" "${USE_ROOTFS_VERSION}" "${USE_ROOTFS_KEYRING}" "${imagebuilder_pattern}"
	else
		rootfs_pattern="openwrt-.*${target_name}-.*rootfs.tar.gz"
		generate_variant "rootfs" "${USE_ROOTFS_VERSION}" "${USE_ROOTFS_KEYRING}" "${rootfs_pattern}"
	fi
	echo "USE_IMAGEBUILDER=${USE_IMAGEBUILDER}" >> $GITHUB_ENV
fi

# QBT source and libtorrent source info
echo USE_QBT_REFS=$(jq -r '.qbittorrent.QT_VERSION?."'${qt_ver}'"' ${JSON_FILE}) >> $GITHUB_ENV

LIBT_REFS=$(jq -r '.qbittorrent.LIBTORRENT_VERSION?."'${libt_ver}'" // empty' ${JSON_FILE})
if [ -z "${LIBT_REFS}" ]; then
	[ -d "../auto-build/rsync/common/libtorrent-rasterbar_${libt_ver}" ] && {
		echo "USE_LIBT_LOCAL=true" >> $GITHUB_ENV
		echo USE_LIBT_HASH=$(git ls-remote -h ${GITHUB_SERVER_URL}/arvidn/libtorrent refs/heads/RC_${libt_ver} | head -c 10) >> $GITHUB_ENV
	} || exit 1
else
	echo "USE_LIBT_REFS=${LIBT_REFS}" >> $GITHUB_ENV
fi

case "${USE_SDK_VERSION}" in
*-SNAPSHOT)
	HEAD=refs/heads/openwrt-${USE_SDK_VERSION%%-*}
	;;
snapshots)
	HEAD=HEAD
	;;
esac

unset feeds_rev
if [ -n "$HEAD" ]; then
	for repo in openwrt packages; do
		repo_rev="$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/${repo}.git $HEAD | head -c 10)"
		feeds_rev="${feeds_rev:+${feeds_rev}-}${repo_rev:?Empty revision for repo ${repo}}"
	done
else
	feeds_rev=${USE_SDK_REVISION##*-}-$(curl -skLZ --compressed ${USE_SDK_URL}/feeds.buildinfo | sed -n 's/.*packages\.git^\(\w\+\)/\1/p')
fi
echo "USE_FEEDS_REVISION=${feeds_rev:?Empty feed revisions}" >> $GITHUB_ENV
