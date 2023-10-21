#!/bin/sh
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh
target_dir=${1:-feeds/base/package/libs/pcre2}

if [ -f "${target_dir}/Makefile" ]; then
	[ "${CUR_LINK_TYPE}" != "static" ] || \
		sed --follow-symlinks -i \
			-e '/CMAKE_OPTIONS += \\/{:a;n;s/\(-DBUILD_SHARED_LIBS=\)ON/\1OFF/;s/\(-DBUILD_STATIC_LIBS=\)OFF/\1ON/;s/$(CONFIG_PACKAGE_libpcre2-16)/y/g;/^$/!ba}' \
			-e '/^define Package\/libpcre2\/default$/{:b;N;/endef/!bb;/BUILDONLY:=1/!{s/\(endef\)/  BUILDONLY:=1\n\1/g}}' ${target_dir}/Makefile
fi
