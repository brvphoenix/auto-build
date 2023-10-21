#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

USE_DOWNLOAD_SERVER=$(jq -r '.openwrt.USE_DOWNLOAD_SERVER' ${CUR_LINK_TYPE}.json)

generate_variant() {
	local name=$1
	local version=$2
	local keyring=$3
	local pattern=$4
	local name_upper=$(echo $name | tr 'a-z' 'A-Z')

	if [ -z "$(eval echo \${USE_${name_upper}_URL})" ]; then
		[ "${version}" = "snapshots" ] && version_path="snapshots" || version_path="releases/${version}"
		download_url=${USE_DOWNLOAD_SERVER}/${version_path}/targets/${CUR_TARGET_NAME//-/\/}
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
generate_variant "sdk" "${CUR_SDK_VERSION}" "${CUR_SDK_KEYRING}" "${sdk_pattern}"

if [ "${CUR_RUNTIME_TEST}" = "true" ]; then
	if [ "${CUR_USE_IMAGEBUILDER}" = 'true' ]; then
		imagebuilder_pattern="openwrt-imagebuilder-.*.Linux-x86_64.tar.xz"
		generate_variant "imagebuilder" "${CUR_ROOTFS_VERSION}" "${CUR_ROOTFS_KEYRING}" "${imagebuilder_pattern}"
	else
		rootfs_pattern="openwrt-.*${CUR_TARGET_NAME}-.*rootfs.tar.gz"
		generate_variant "rootfs" "${CUR_ROOTFS_VERSION}" "${CUR_ROOTFS_KEYRING}" "${rootfs_pattern}"
	fi
fi

echo "CHCHE_SDK_PATH=./${USE_SDK_FILE}" >> ${CUR_TARGET_NAME}-${CUR_LINK_TYPE}
echo "CHCHE_SDK_KEY=${CUR_LINK_TYPE}-${CUR_TARGET_NAME}-${USE_SDK_REVISION}" >> ${CUR_TARGET_NAME}-${CUR_LINK_TYPE}
echo "CHCHE_ROOTFS_PATH=${CUR_REPO_NAME}/docker/custom/rootfs" >> ${CUR_TARGET_NAME}-${CUR_LINK_TYPE}
echo "CHCHE_ROOTFS_KEY=rootfs-${CUR_TARGET_NAME}-${USE_IMAGEBUILDER_REVISION}${USE_ROOTFS_REVISION}" >> ${CUR_TARGET_NAME}-${CUR_LINK_TYPE}

cat ${CUR_TARGET_NAME}-${CUR_LINK_TYPE} >> ${GITHUB_ENV}
