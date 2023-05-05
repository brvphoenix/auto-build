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

sdkfile="openwrt-sdk-.*.Linux-x86_64.tar.xz"

[ "${USE_VERSION}" = "snapshots" ] && version_path="snapshots" || version_path="releases/${USE_VERSION}"
USE_SOURCE_URL=${USE_DOWNLOAD_SERVER}/${version_path}/targets/${USE_TARGET//-/\/}

curl -ksLOZ --compressed ${USE_SOURCE_URL}/sha256sums
USE_SDK_FILE=$(grep -io "${sdkfile}" sha256sums)
USE_SDK_SHA256SUM=$(grep -i "${sdkfile}" sha256sums | cut -d' ' -f1)
[ -n "${USE_SDK_FILE}" ] || exit 1;

echo "USE_SDK_FILE=${USE_SDK_FILE}" >> $GITHUB_ENV
echo "USE_SDK_SHA256SUM=${USE_SDK_SHA256SUM}" >> $GITHUB_ENV
echo "USE_SOURCE_URL=${USE_SOURCE_URL}" >> $GITHUB_ENV

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

# curl SDK info
http_code=$(curl -fskILZ -o /dev/null -w %{http_code} --compressed ${USE_SOURCE_URL}/version.buildinfo)
[ "http_code" != "404" ] && \
	sdk_ver="$(curl -skLZ --compressed ${USE_SOURCE_URL}/version.buildinfo)" || \
	sdk_ver="${GITHUB_RUN_ID}"

echo "USE_SDK_VERSION=${sdk_ver}" >> $GITHUB_ENV

case "${USE_VERSION}" in
*-SNAPSHOT)
	version_label=openwrt-$(echo "${USE_VERSION}" | grep -o '[0-9]\+\.[0-9]\+')
	HEAD=refs/heads/openwrt-${USE_VERSION%%-*}
	;;
snapshots)
	version_label=SNAPSHOT
	HEAD=HEAD
	;;
*)
	version_label=v${USE_VERSION}
	;;
esac

unset feeds_rev
if [ -n "$HEAD" ]; then
	for repo in openwrt packages; do
		repo_rev="$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/${repo}.git $HEAD | head -c 10)"
		feeds_rev="${feeds_rev:+${feeds_rev}-}${repo_rev:?Empty revision for repo ${repo}}"
	done
else
	feeds_rev=${sdk_ver##*-}-$(curl -skLZ --compressed ${USE_SOURCE_URL}/feeds.buildinfo | sed -n 's/.*packages\.git^\(\w\+\)/\1/p')
fi
echo "USE_FEEDS_REVISION=${feeds_rev:?Empty feed revisions}" >> $GITHUB_ENV

# Openwrt tag for docker image
docker_rootfs_tag="${RUN_ON_TARGET:-${USE_TARGET}}-${version_label}"
echo "USE_DOCKER_ROOTFS_TAG=${docker_rootfs_tag}" >> $GITHUB_ENV

# Get the docker image hash
if [ "${RUNTIME_TEST}" = "true" ]; then
	# openwrt/rootfs
	token=$(curl -skL "https://ghcr.io/token?scope=repository:openwrt/rootfs:pull&service=ghcr.io" | jq -r '.token')
	curl -fskILZ -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
		-H "Authorization: Bearer ${token}" "https://ghcr.io/v2/openwrt/rootfs/manifests/${docker_rootfs_tag}" \
		| sed -n 's/docker-content-digest:\s\+sha256:\(\w\+\)/\1/gp' | xargs -i echo "USE_ROOTFS_HASH={}" >> $GITHUB_ENV || exit 1
fi

# Common name of the saved files
echo "SAVED_NAME=${target_arch}-${link_type}-qt${qt_ver}-libtorrent_${libt_ver}" >> $GITHUB_ENV
