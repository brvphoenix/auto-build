#!/bin/sh
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

if [ -n "$1" ]; then
	target_dir=$1
elif [ -f "${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/${CUR_LINK_TYPE}/pcre2/Makefile" ]; then
	target_dir=${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/${CUR_LINK_TYPE}/pcre2
elif [ -f "${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/common/pcre2/Makefile" ]; then
	target_dir=${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/common/pcre2
elif [ -f "feeds/base/package/libs/pcre2/Makefile" ]; then
	target_dir=feeds/base/package/libs/pcre2
else
	echo "::error ::${target_dir}/Makefile doesn't not exist.";
	exit 1
fi

[ "${CUR_LINK_TYPE}" != "static" ] || \
	sed --follow-symlinks -i \
		-e '/CMAKE_OPTIONS += \\/{:a;n;s/\(-DBUILD_SHARED_LIBS=\)ON/\1OFF/;s/\(-DBUILD_STATIC_LIBS=\)OFF/\1ON/;s/$(CONFIG_PACKAGE_libpcre2-16)/y/g;/^$/!ba}' \
		-e '/^define Package\/libpcre2\/default$/{:b;N;/endef/!bb;/BUILDONLY:=1/!{s/\(endef\)/  BUILDONLY:=1\n\1/g}}' ${target_dir}/Makefile
