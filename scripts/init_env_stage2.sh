#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

# Parse json files
JSON_FILE=./${CUR_LINK_TYPE}.json

# QBT source and libtorrent source info
echo USE_QBT_REF=$(jq -r '.qbittorrent.QT_VERSION?."'${CUR_QT_VERSION}'"' ${JSON_FILE}) >> $GITHUB_ENV

# libtorrent
echo USE_LIBT_HASH=$(git ls-remote -h ${GITHUB_SERVER_URL}/arvidn/libtorrent refs/heads/RC_${CUR_LIBT_VERSION} | head -c 10) >> $GITHUB_ENV
libt_ref=$(jq -r '.qbittorrent.LIBTORRENT_VERSION?."'${CUR_LIBT_VERSION}'" // empty' ${JSON_FILE})
[ -z "${libt_ref}" ] || echo "USE_LIBT_REF=${libt_ref}" >> $GITHUB_ENV

USE_SDK_VERSION=$(jq -r '.openwrt."'${CUR_TARGET_NAME}'".USE_SDK_VERSION // .openwrt.USE_SDK_VERSION' ${JSON_FILE})

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
	feeds_rev="$(git ls-remote ${GITHUB_SERVER_URL}/openwrt/openwrt.git refs/tags/v${USE_SDK_VERSION}^{} | head -c 10)"
	feeds_rev=${feeds_rev}-$(curl -skLZ --compressed https://raw.githubusercontent.com/openwrt/openwrt/v${USE_SDK_VERSION}/feeds.conf.default | sed -n 's/.*packages\.git^\(\w\+\)/\1/p' | head -c 10)
fi
echo "USE_FEEDS_REVISION=${feeds_rev:?Empty feed revisions}" >> $GITHUB_ENV
