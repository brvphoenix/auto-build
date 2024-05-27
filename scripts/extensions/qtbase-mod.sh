#!/bin/bash
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

if [ -n "$1" ]; then
	target_dir=$1
elif [ -f "${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/${CUR_LINK_TYPE}/qtbase/Makefile" ]; then
	target_dir=${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/${CUR_LINK_TYPE}/qtbase
elif [ -f "${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/common/qtbase/Makefile" ]; then
	target_dir=${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/common/qtbase
elif [ -f "feeds/${CUR_LOCAL_REPO_NAME:-local}/packages/qt${CUR_QT_VERSION}/qtbase/Makefile" ]; then
	target_dir=feeds/${CUR_LOCAL_REPO_NAME:-local}/packages/qt${CUR_QT_VERSION}/qtbase
else
	echo "::error ::${target_dir}/Makefile doesn't not exist.";
	exit 1
fi

if [ "${CUR_QT_VERSION}" = "5" ]; then
	# Make qmake compile in parallel (should be deleted when update to Qt6)
	cat <<-'EOF' | sed 's/^    //g' | sed -i '/define Build\/Compile/{
		r/dev/stdin
		:a;N;/^endef/!ba;N
	}' ${target_dir}/Makefile
	    define Build/Configure
	    	$(SED) 's;\(cd "\$$$$\w*\/qmake".*"\$$$$\w*"\);\1 "\-j$(NPROC)";g' $(PKG_BUILD_DIR)/configure
	    	$(call Build/Configure/Default)
	    endef
	
	EOF

	# Only needed when use openssl 3.0.x
	sed --follow-symlinks -i 's/\(EXTRA_INCLUDE_LIBS =\)/\1 \\\n\tOPENSSL_LIBS="-lssl -lcrypto -latomic"/' ${target_dir}/Makefile
else
	sed --follow-symlinks -i '/CMAKE_OPTIONS += \\/a\\t--log-level=DEBUG \\' ${target_dir}/Makefile
fi

echo "qt-version=$(sed -n '/PKG_BASE:=/{N;s/PKG_BASE:=\([0-9.]\+\)\s\+PKG_BUGFIX:=\(\w\+\)/\1.\2/gp}' ${target_dir}/Makefile)" >> $GITHUB_OUTPUT
