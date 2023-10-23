#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

# add modified pkgs to CUSTOM_DIR
QT_REPO_DIR=./${CUR_QBT_REPO_NAME}
CUSTOM_DIR=${QT_REPO_DIR}/custom
RSYNC_DIR=./${CUR_REPO_NAME}/rsync

[ ! -d "${RSYNC_DIR}/common" ] || rsync -aK ${RSYNC_DIR}/common/ ${CUSTOM_DIR}
[ ! -d "${RSYNC_DIR}/${CUR_LINK_TYPE}" ] || rsync -aK ${RSYNC_DIR}/${CUR_LINK_TYPE}/ ${CUSTOM_DIR}

[ ! -f "${CUSTOM_DIR}/pcre2/Makefile" ] || bash ./${CUR_REPO_NAME}/scripts/extensions/pcre2-mod.sh "${CUSTOM_DIR}/pcre2"

[ ! -f "${CUSTOM_DIR}/libtorrent-rasterbar/Makefile" ] || {
	bash ./${CUR_REPO_NAME}/scripts/extensions/libtorrent-mod.sh "${CUSTOM_DIR}/libtorrent-rasterbar"
	# Use modified libtorrent-rasterbar
	rm -r ${QT_REPO_DIR}/packages/libs/libtorrent-rasterbar
}
