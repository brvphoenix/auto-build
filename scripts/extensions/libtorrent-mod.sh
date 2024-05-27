#!/bin/sh
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

if [ -n "$1" ]; then
	target_dir=$1
elif [ -f "${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/${CUR_LINK_TYPE}/libtorrent-rasterbar/Makefile" ]; then
	target_dir=${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/${CUR_LINK_TYPE}/libtorrent-rasterbar
elif [ -f "${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/common/libtorrent-rasterbar/Makefile" ]; then
	target_dir=${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/rsync/common/libtorrent-rasterbar
elif [ -f "feeds/${CUR_LOCAL_REPO_NAME:-local}/packages/libs/libtorrent-rasterbar/Makefile" ]; then
	target_dir=feeds/${CUR_LOCAL_REPO_NAME:-local}/packages/libs/libtorrent-rasterbar
else
	echo "::error ::${target_dir}/Makefile doesn't not exist.";
	exit 1
fi

if [ "${CUR_LINK_TYPE}" = "static" ]; then
	sed --follow-symlinks -i \
		-e 's/\(-DBUILD_SHARED_LIBS=\)ON/\1OFF/' \
		-e '/^define Package\/libtorrent-rasterbar$/{:a;N;/endef/!ba;/BUILDONLY:=1/!{s/\(endef\)/  BUILDONLY:=1\n\1/g}}' ${target_dir}/Makefile
fi

_pkg_name=$(sed --follow-symlinks -n 's/PKG_NAME:=\(\S\+\)/\1/gp' ${target_dir}/Makefile)
build_dir=${_pkg_name}-$(date +%s)

mkdir -p dl
cd dl
git clone --depth 1 --recurse-submodules --shallow-submodules -b RC_${CUR_LIBT_VERSION} ${GITHUB_SERVER_URL}/arvidn/libtorrent ${build_dir}
cd ${build_dir}

_timestamp=$(git log -1 --format="@%ct")
_pkg_src_ver=$(git rev-parse HEAD)
_pkg_src_date="$(date --utc --date="$_timestamp" "+%Y-%m-%d")"
_pkg_ver=${_pkg_src_date}-$(printf '%.8s' ${_pkg_src_ver})

rm -rf ./.git
cd ..
mv "${build_dir}" "${_pkg_name}-${_pkg_ver}"
build_dir=${_pkg_name}-${_pkg_ver}

tar --numeric-owner --owner=0 --group=0 --mode=a-s --sort=name \
	${_timestamp:+--mtime="$_timestamp"} -c ${build_dir} | xz -zc -7e > ${build_dir}.tar.xz
rm -rf ${build_dir}
_pkg_mirror_hash=$(sha256sum ${build_dir}.tar.xz | head -c 64)
cd ..

# patch the Makefile
_patch_path=$(pwd)/p_${_timestamp}.patch

cat > ${_patch_path} <<-'EOF'
	--- a/Makefile
	+++ b/Makefile
	@@ -5,12 +5,13 @@
	 include $(TOPDIR)/rules.mk
	 
	 PKG_NAME:=
	-PKG_VERSION:=
	 PKG_RELEASE:=
	 
	-PKG_SOURCE:=
	-PKG_SOURCE_URL:=
	-PKG_HASH:=
	+PKG_SOURCE_PROTO:=git
	+PKG_SOURCE_URL:=https://github.com/arvidn/libtorrent.git
	+PKG_SOURCE_VERSION:=
	+PKG_SOURCE_DATE:=
	+PKG_MIRROR_HASH:=
	 
	 PKG_LICENSE:=BSD-3-Clause
	 PKG_LICENSE_FILES:=COPYING
EOF

if [ "${CUR_LIBT_VERSION}" = 1_2 ]; then
	cat >> ${_patch_path} <<-'EOF'
		@@ -55,6 +56,11 @@ CONFIGURE_ARGS += \
		 	--with-boost=$(STAGING_DIR)/usr \
		 	--with-libiconv
		 
		+define Build/Prepare
		+	$(call Build/Prepare/Default)
		+	cd $(PKG_BUILD_DIR) && ./autotool.sh
		+endef
		+
		 define Build/InstallDev
		 	$(INSTALL_DIR) $(1)
		 	$(CP) $(PKG_INSTALL_DIR)/* $(1)
	EOF
fi

set -- $(sed --follow-symlinks -n \
	-e 's/PKG_VERSION:=\(.*\)/\1/gp' \
	-e 's/PKG_RELEASE:=\(.*\)/\1/gp' \
	-e 's/PKG_SOURCE:=\(.*\)/\1/gp' \
	-e 's/PKG_SOURCE_URL:=\(.*\)/\1/gp' \
	-e 's/PKG_HASH:=\(.*\)/\1/gp' \
	${target_dir}/Makefile)

sed --follow-symlinks -i \
	-e 's/\( PKG_NAME:=\).*/\1'${_pkg_name////'\/'}'/g' \
	-e 's/\(-PKG_VERSION:=\).*/\1'${1////'\/'}'/g' \
	-e 's/\( PKG_RELEASE:=\).*/\1'${2////'\/'}'/g' \
	-e 's/\(-PKG_SOURCE:=\).*/\1'${3////'\/'}'/g' \
	-e 's/\(-PKG_SOURCE_URL:=\).*/\1'${4////'\/'}'/g' \
	-e 's/\(-PKG_HASH:=\).*/\1'${5////'\/'}'/g' \
	-e 's/\(+PKG_SOURCE_VERSION:=\).*/\1'${_pkg_src_ver////'\/'}'/g' \
	-e 's/\(+PKG_SOURCE_DATE:=\).*/\1'${_pkg_src_date////'\/'}'/g' \
	-e 's/\(+PKG_MIRROR_HASH:=\).*/\1'${_pkg_mirror_hash////'\/'}'/g' \
	${_patch_path}
set --

patch -p1 -d ${target_dir} < ${_patch_path}
rm -rf ${_patch_path}
