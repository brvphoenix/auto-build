#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

function cloneBySha() {
	local url=$1
	local directory=$2
	local rev=$3
	local branch=${rev:-tmp}
	local curdir=$(pwd)
	mkdir -p $directory
	cd $directory
	git init 2>&1 >>/dev/null
	git remote add origin "$url"
	git fetch --depth 1 origin $rev 2>&1 >>/dev/null
	git switch -C "$branch" FETCH_HEAD 2>&1 >>/dev/null
	# git log -1 --pretty=format:"%h"
	echo $(git rev-parse --short=10 HEAD)
	cd ${curdir}
}

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

USE_SOURCE_URL=${USE_PROTOCOL}://${USE_DOMAIN}/${USE_RELEASE}
SDK_FILE_LEADING=openwrt-sdk

if [ "${USE_RELEASE}" = "releases" ]; then
	USE_SOURCE_URL=${USE_SOURCE_URL}/${USE_VERSION}
	SDK_FILE_LEADING=${SDK_FILE_LEADING}-${USE_VERSION}
fi
SDK_FILE_LEADING="${SDK_FILE_LEADING}-$([ "${USE_UNIQUE}" = "true" ] && echo ${USE_TARGET} | cut -d '-' -f1 || echo ${USE_TARGET})_gcc"

USE_SOURCE_URL="${USE_SOURCE_URL}/targets/$(echo ${USE_TARGET} | tr '-' '/')"
curl -ksLOZ --compressed ${USE_SOURCE_URL}/sha256sums
USE_SDK_SHA256SUM=$(grep -i "${SDK_FILE_LEADING}*" sha256sums | cut -d " " -f1)
USE_SDK_FILE=$(grep -i "${SDK_FILE_LEADING}*" sha256sums | cut -d "*" -f2)
[ -n "${USE_SDK_FILE}" ] || exit 1;

echo "RUN_ON_TARGET=${RUN_ON_TARGET:-${USE_TARGET}}" >> $GITHUB_ENV
echo "USE_SDK_FILE=${USE_SDK_FILE}" >> $GITHUB_ENV
echo "USE_SDK_SHA256SUM=${USE_SDK_SHA256SUM}" >> $GITHUB_ENV
echo "USE_SOURCE_URL=${USE_SOURCE_URL}" >> $GITHUB_ENV

# QBT source and libtorrent source info
QBT_BRANCH=$(jq -r '.qbittorrent.QT_VERSION?."'${qt_ver}'"' ${JSON_FILE})
cloneBySha https://${GITHUB_REPOSITORY_OWNER}:${SUPER_TOKEN}@github.com/${GITHUB_REPOSITORY_OWNER}/SomePackages.git ../qt_repo "${QBT_BRANCH}" >> /dev/null

LIBT_BRANCH=$(jq -r '.qbittorrent.LIBTORRENT_VERSION?."'${libt_ver}'" // empty' ${JSON_FILE})
if [ -z "${LIBT_BRANCH}" -a -d "../auto-build/rsync/common/package/self/libtorrent-rasterbar_${libt_ver}" ]; then
	echo "USE_LIBT_LOCAL=true" >> $GITHUB_ENV
	echo USE_LIBT_HASH=$(git ls-remote ${GITHUB_SERVER_URL}/arvidn/libtorrent refs/heads/RC_${libt_ver} | head -c 10) >> $GITHUB_ENV
else
	echo USE_LIBT_HASH=$(cloneBySha https://${GITHUB_REPOSITORY_OWNER}:${SUPER_TOKEN}@github.com/${GITHUB_REPOSITORY_OWNER}/SomePackages.git ../libt_repo "${LIBT_BRANCH}") >> $GITHUB_ENV
fi

# Openwrt tag for docker image
USE_OPENWRT_BRANCH=openwrt-22.03
echo "USE_OPENWRT_BRANCH=${USE_OPENWRT_BRANCH}" >> $GITHUB_ENV

# curl SDK info
http_code=$(curl -fksILZ -o /dev/null -w %{http_code} --compressed ${USE_SOURCE_URL}/version.buildinfo)
echo $http_code
[ "http_code" != "404" ] && \
	sdk_ver="$(curl -ksLZ --compressed ${USE_SOURCE_URL}/version.buildinfo)" || \
	sdk_ver="$(echo ${GITHUB_RUN_ID})"

echo "USE_SDK_VERSION=${sdk_ver}" >> $GITHUB_ENV

[ "${USE_RELEASE}" = "releases" ] && HEAD=v${USE_VERSION} || HEAD=HEAD
feeds="${feeds}-$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/openwrt.git $HEAD | head -c 10)"
[ "${USE_RELEASE}" = "releases" ] && HEAD=${USE_OPENWRT_BRANCH} || HEAD=HEAD
feeds="${feeds}-$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/packages.git $HEAD | head -c 10)"
# Do not depends on repo luci
# feeds="${feeds}-$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/luci.git $HEAD | head -c 10)"

echo "USE_FEEDS_VERSION=${feeds}" >> $GITHUB_ENV

# Get the release number according the tag number
if [ "${GITHUB_REF}" = "refs/tags/${GITHUB_REF_NAME}" ]; then
	USE_RELEASE_NUMBER=$(git ls-remote --tags ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY} | cut -f2 | sed 's;refs/tags/;;g' | cut -d '-' -f1 | grep "$(echo ${GITHUB_REF_NAME} | cut -d '-' -f1)" | wc -l)
fi

echo "USE_RELEASE_NUMBER=${USE_RELEASE_NUMBER:-1}" >> $GITHUB_ENV

# Get the docker image hash
if [ "${RUNTIME_TEST}" = "true" ]; then
	token=$(curl --silent "https://auth.docker.io/token?scope=repository:aptman/qus:pull&service=registry.docker.io" | jq -r '.token')
	curl -s -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
		-H "Authorization: Bearer ${token}" "https://registry-1.docker.io/v2/aptman/qus/manifests/latest" \
		| jq -r '.manifests | .[] | select(.platform.architecture == "amd64") | .digest' \
		| sed 's/sha256:\(\w\+\)/\1/g' \
		| xargs -i echo "USE_DOCKER_HASH={}" >> $GITHUB_ENV || exit 1
fi

# Common name of the saved files
echo "SAVED_NAME=${target_arch}-${link_type}-qt${qt_ver}-libtorrent_${libt_ver}" >> $GITHUB_ENV
