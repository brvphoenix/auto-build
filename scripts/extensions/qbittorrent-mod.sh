#!/bin/bash
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

# Update the release number according the tag number
target_dir=${1:-feeds/${CUR_LOCAL_REPO_NAME:-local}/packages/net/qbittorrent}

[ -f "${target_dir}/Makefile" ] || { echo "::error ::${target_dir}/Makefile doesn't not exist."; exit 1; }

if [ "${GITHUB_REF}" = "refs/tags/${GITHUB_REF_NAME}" ]; then
	release_count=$(git ls-remote -t ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY} "${GITHUB_REF%%-*}*" | wc -l)
	grep -oF "PKG_RELEASE=${release_count:-1}" ${target_dir}/Makefile || \
		sed --follow-symlinks -i 's/^\(PKG_RELEASE\)=\S\+/\1='${release_count:-1}'/g' ${target_dir}/Makefile
fi

# Pathes has not been contained in the upstream.
patch_dir=${target_dir}/patches
mkdir -p ${patch_dir}

PKG_REF=release-$(sed --follow-symlinks -n 's/PKG_VERSION:=\(\w\+\)/\1/gp' ${target_dir}/Makefile)

# Hotfixes
curl -kLZ --compressed -o ${patch_dir}/0001.patch https://github.com/brvphoenix/qBittorrent/compare/${PKG_REF}...stable_backup.patch

# Backport
curl -kLZ --compressed -o ${patch_dir}/0002.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/19741.patch

# # Log view
# curl -kLZ --compressed -o ${patch_dir}/0003.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18290.patch

# # Log setting
# curl -kLZ --compressed -o ${patch_dir}/0004-1.patch https://patch-diff.githubusercontent.com/raw/qbittorrent/qBittorrent/pull/18506.patch

# # Log compressing
# curl -kLZ --compressed -o ${patch_dir}/0004-2.patch https://github.com/brvphoenix/qBittorrent/compare/compress-backup~1...compress.patch
rm -rf ${patch_dir}/0806-filelogger.patch

## CleanUp
#curl -kLZ --compressed -o ${patch_dir}/0005.patch https://github.com/brvphoenix/qBittorrent/compare/cleanup~2...cleanup.patch
