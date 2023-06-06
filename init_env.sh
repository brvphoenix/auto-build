#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

target_arch=$1
link_type=$2
qt_ver=$3
libt_ver=$4

# Parse json files
JSON_FILE=./${link_type}.json

for item in $(jq -r '.openwrt | to_entries[] | select(.value | (type != "object" and type != "array")) | "\(.key)=\(.value)"' ${JSON_FILE}); do
	eval "${item}"
done

for option in $(jq -r '.openwrt."'${target_arch}'" | to_entries[] | "\(.key)=\(.value)"' ${JSON_FILE}); do
	eval "${option}"
done

generate_variant() {
	local name=$1
	local version=$2
	local target=$3
	local keyring=$4
	local name_upper=$(echo $name | tr 'a-z' 'A-Z')
	local pattern="openwrt-${name}-.*.Linux-x86_64.tar.xz"

	if [ -z "$(eval echo \${USE_${name_upper}_URL})" ]; then
		[ "${version}" = "snapshots" ] && version_path="snapshots" || version_path="releases/${version}"
		download_url=${USE_DOWNLOAD_SERVER}/${version_path}/targets/${target//-/\/}
		echo "USE_${name_upper}_URL=${download_url}" >> $GITHUB_ENV
	fi

	[ -f "${version}.sha256sums" ] || curl -ksLZ --compressed -o "${version}.sha256sums" ${download_url}/sha256sums
	[ -f "${version}.sha256sums.asc" ] || curl -ksLZ --compressed -o "${version}.sha256sums.asc" ${download_url}/sha256sums.asc

	# Verify the sha256sum with sha256sum.asc
	[ -f "${keyring}" ] || curl -fskLOZ --compressed --connect-timeout 10 --retry 5 https://raw.githubusercontent.com/openwrt/docker/main/keys/${keyring}
	gpg --import "${keyring}"
	gpg --with-fingerprint --verify ${version}.sha256sums.asc ${version}.sha256sums

	if [ -z "$(eval echo \${USE_${name_upper}_FILE})" ]; then
		grep -i "${pattern}" ${version}.sha256sums > "${name}.sha256sums"
		fname=$(grep -io "${pattern}" "${name}.sha256sums")
		echo "USE_${name_upper}_FILE=${fname}" >> $GITHUB_ENV
	fi

	if [ -z "$(eval echo \${USE_${name_upper}_VERSION})" ]; then
		http_code=$(curl -fskILZ -o /dev/null -w %{http_code} --compressed ${download_url}/version.buildinfo)
		[ "http_code" != "404" ] && \
			ver_info="$(curl -skLZ --compressed ${download_url}/version.buildinfo)" || \
			ver_info="${GITHUB_RUN_ID}"

		echo "USE_${name_upper}_VERSION=${ver_info}" >> $GITHUB_ENV
	fi

	. $GITHUB_ENV
}

generate_variant "sdk" "${USE_VERSION}" "${USE_TARGET}" "${USE_KEYRING}" "${sdk_pattern}"
[ -n "${USE_SDK_FILE}" ] || exit 1;

if [ "${USE_IMAGEBUILDER}" = 'true' -a "${RUNTIME_TEST}" = "true" ]; then
	echo "USE_IMAGEBUILDER=${USE_IMAGEBUILDER}" >> $GITHUB_ENV
	generate_variant "imagebuilder" "${USE_RUNTIME_TEST_VER}" "${USE_TARGET}" "${USE_RUNTIME_TEST_KEYRING}"
	[ -n "${USE_IMAGEBUILDER_FILE}" ] || exit 1
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

case "${USE_VERSION}" in
*-SNAPSHOT)
	HEAD=refs/heads/openwrt-${USE_VERSION%%-*}
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
	feeds_rev=${USE_SDK_VERSION##*-}-$(curl -skLZ --compressed ${USE_SDK_URL}/feeds.buildinfo | sed -n 's/.*packages\.git^\(\w\+\)/\1/p')
fi
echo "USE_FEEDS_REVISION=${feeds_rev:?Empty feed revisions}" >> $GITHUB_ENV

case "${USE_RUNTIME_TEST_VER}" in
*-SNAPSHOT)
	version_label=openwrt-$(echo "${USE_RUNTIME_TEST_VER}" | grep -o '[0-9]\+\.[0-9]\+')
	;;
snapshots)
	version_label=SNAPSHOT
	;;
*)
	version_label=v${USE_RUNTIME_TEST_VER}
	;;
esac

# Openwrt tag for docker image
docker_rootfs_tag="${RUN_ON_TARGET:-${USE_TARGET}}-${version_label}"
echo "USE_DOCKER_ROOTFS_TAG=${docker_rootfs_tag}" >> $GITHUB_ENV

# Get the docker image hash
if [ "${RUNTIME_TEST}" = "true" ]; then
	[ -n "${USE_QEMU_CPU}" ] && echo "QEMU_CPU=${USE_QEMU_CPU}" >> ${GITHUB_WORKSPACE}/docker_env || touch ${GITHUB_WORKSPACE}/docker_env

	if [ "${USE_IMAGEBUILDER}" != 'true' ]; then
		# openwrt/rootfs
		token=$(curl -skL "https://ghcr.io/token?scope=repository:openwrt/rootfs:pull&service=ghcr.io" | jq -r '.token')
		curl -fskILZ -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
			-H "Authorization: Bearer ${token}" "https://ghcr.io/v2/openwrt/rootfs/manifests/${docker_rootfs_tag}" \
			| sed -n 's/docker-content-digest:\s\+sha256:\(\w\+\)/\1/gp' | xargs -i echo "USE_ROOTFS_HASH={}" >> $GITHUB_ENV || exit 1
	fi
fi

# Common name of the saved files
echo "SAVED_NAME=${target_arch}-${link_type}-qt${qt_ver}-libtorrent_${libt_ver}" >> $GITHUB_ENV
