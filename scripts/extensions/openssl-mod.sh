#!/bin/sh
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh
target_dir=${1:-feeds/base/package/libs/openssl}

if [ -n "$1" ]; then
	target_dir=$1
elif [ -f "${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/${CUR_LINK_TYPE}/openssl/Makefile" ]; then
	target_dir=${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/${CUR_LINK_TYPE}/openssl
elif [ -f "${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/common/openssl/Makefile" ]; then
	target_dir=${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/common/openssl
elif [ -f "feeds/base/package/libs/openssl/Makefile" ]; then
	target_dir=feeds/base/package/libs/openssl
else
	echo "::error ::${target_dir}/Makefile doesn't not exist.";
	exit 1
fi

	sed --follow-symlinks -i \
		-e '/define Build\/Configure/a\$(SED) '\''/^my @disablables = (/{:a;N;/ *);/!ba;/"apps"/!{s/\\(\\( *\\));\\)/\\2"apps",\\n\\1/g;};}'\'' $(PKG_BUILD_DIR)/Configure' \
		${target_dir}/Makefile

if [ "${CUR_LINK_TYPE}" = "static" ]; then
	if [ "${CUR_LIBT_VERSION}" = "2_0" ]; then
		sed --follow-symlinks -i \
			-e 's/\(OPENSSL_OPTIONS:=.*\) shared\(.*\)/\1\2 no-shared no-dso no-autoload-config no-apps/g' \
			-e 's/\(\/usr\/lib\/lib{crypto,ssl}\.\){a,so\*}/\1a/g' \
			-e '/.*\/usr\/lib\/lib\(crypto\|ssl\)\.so\.\*.*/d' ${target_dir}/Makefile
	else
		sed --follow-symlinks -i \
			-e 's/\(OPENSSL_OPTIONS:=.*\)/\1 no-autoload-config no-apps/g' ${target_dir}/Makefile
	fi
else
	sed --follow-symlinks -i 's/\(OPENSSL_OPTIONS:=.*\)/\1 no-apps/g' ${target_dir}/Makefile
fi
