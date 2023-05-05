#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

target_arch=$1
link_type=$2
qt_ver=$3
libt_ver=$4

# Parse json files
JSON_FILE=./${link_type}.json

for item in $(jq -r '.openwrt | to_entries[] | select(.value | type == "string") | "\(.key)=\(.value)"' ${JSON_FILE}); do
	eval "${item}"
done

for option in $(jq -r '.openwrt."'${target_arch}'" | to_entries[] | "\(.key)=\(.value)"' ${JSON_FILE}); do
	eval "${option}"
done

sdkfile="openwrt-sdk-.*.Linux-x86_64.tar.xz"

if [ "${USE_RELEASE}" = "releases" ]; then
	USE_SOURCE_URL=${USE_PROTOCOL}://${USE_DOMAIN}/${USE_RELEASE}/${USE_VERSION}/targets/${USE_TARGET//-/\/}
else
	USE_SOURCE_URL=${USE_PROTOCOL}://${USE_DOMAIN}/${USE_RELEASE}/targets/${USE_TARGET//-/\/}
fi

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
if [ -z "${LIBT_REFS}" -a -d "../auto-build/rsync/common/package/self/libtorrent-rasterbar_${libt_ver}" ]; then
	echo "USE_LIBT_LOCAL=true" >> $GITHUB_ENV
	echo USE_LIBT_HASH=$(git ls-remote -h ${GITHUB_SERVER_URL}/arvidn/libtorrent refs/heads/RC_${libt_ver} | head -c 10) >> $GITHUB_ENV
else
	echo "USE_LIBT_REFS=${LIBT_REFS}" >> $GITHUB_ENV
fi

# Openwrt tag for docker image
USE_OPENWRT_BRANCH=openwrt-$(jq -r '.openwrt.USE_VERSION' dynamic.json | grep -o '[0-9]\+\.[0-9]\+')
echo "USE_OPENWRT_BRANCH=${USE_OPENWRT_BRANCH}" >> $GITHUB_ENV
echo "USE_DOCKER_ROOTFS_TAG=${RUN_ON_TARGET:-${USE_TARGET}}-${USE_OPENWRT_BRANCH}" >> $GITHUB_ENV

# curl SDK info
http_code=$(curl -fskILZ -o /dev/null -w %{http_code} --compressed ${USE_SOURCE_URL}/version.buildinfo)
[ "http_code" != "404" ] && \
	sdk_ver="$(curl -skLZ --compressed ${USE_SOURCE_URL}/version.buildinfo)" || \
	sdk_ver="${GITHUB_RUN_ID}"

echo "USE_SDK_VERSION=${sdk_ver}" >> $GITHUB_ENV

[ "${USE_RELEASE}" = "releases" ] && HEAD=refs/tags/v${USE_VERSION} || HEAD=HEAD
feeds="$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/openwrt.git $HEAD | head -c 10)"
[ "${USE_RELEASE}" = "releases" ] && HEAD=refs/heads/${USE_OPENWRT_BRANCH} || HEAD=HEAD
feeds="${feeds}-$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/packages.git $HEAD | head -c 10)"
# Do not depends on repo luci
# feeds="${feeds}-$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/luci.git $HEAD | head -c 10)"

echo "USE_FEEDS_VERSION=${feeds}" >> $GITHUB_ENV

# Get the release number according the tag number
if [ "${GITHUB_REF}" = "refs/tags/${GITHUB_REF_NAME}" ]; then
	USE_RELEASE_NUMBER=$(git ls-remote --tags ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY} | grep "${GITHUB_REF%%-*}" | wc -l)
fi

echo "USE_RELEASE_NUMBER=${USE_RELEASE_NUMBER:-1}" >> $GITHUB_ENV

# Get the docker image hash
if [ "${RUNTIME_TEST}" = "true" ]; then
	# openwrt/rootfs
	token=$(curl -skL "https://ghcr.io/token?scope=repository:openwrt/rootfs:pull&service=ghcr.io" | jq -r '.token')
	curl -fskILZ -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
		-H "Authorization: Bearer ${token}" "https://ghcr.io/v2/openwrt/rootfs/manifests/${RUN_ON_TARGET:-${USE_TARGET}}-${USE_OPENWRT_BRANCH}" \
		| sed -n 's/docker-content-digest:\s\+sha256:\(\w\+\)/\1/gp' | xargs -i echo "USE_ROOTFS_HASH={}" >> $GITHUB_ENV || exit 1
fi

# Common name of the saved files
echo "SAVED_NAME=${target_arch}-${link_type}-qt${qt_ver}-libtorrent_${libt_ver}" >> $GITHUB_ENV
