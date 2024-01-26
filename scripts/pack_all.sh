#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

[ -d "${CUR_SDK_DIR_NAME}" ] && cd ${CUR_SDK_DIR_NAME} || { echo "Not exist '${CUR_SDK_DIR_NAME}' directory"; exit 0; }

target_arch=$(perl ./scripts/dump-target-info.pl targets 2>/dev/null | grep "${CUR_TARGET_NAME//-/\/}" | cut -d ' ' -f 2)

SAVE_ROOT_DIR=${GITHUB_WORKSPACE}/qbittorrent_${CUR_TARGET_NAME}
PKGS_DIR=${SAVE_ROOT_DIR}/pkgs
KEY_DIR=${SAVE_ROOT_DIR}/key

if [ "${CACHE_HIT}" = "true" ]; then
	fingerprint=$(ls -t ${KEY_DIR} | head -n 1)
else
	mkdir -p ${SAVE_ROOT_DIR} ${PKGS_DIR} ${KEY_DIR}
	if [ "${CUR_LINK_TYPE}" = "static" ]; then
		[ ! -d "./bin/packages" ] || find ./bin/packages -type f -iname *qbittorrent* -exec cp -f {} ${PKGS_DIR} \;
	else
		[ "$CUR_LIBT_VERSION" = "1_2" ] && {
			[ ! -d "./bin/packages" ] || find ./bin/packages -type f -iname *.ipk -exec cp -f {} ${PKGS_DIR} \;
			[ ! -d "./bin/targets" ] || find ./bin/targets -type f \( \
				-iname libstdcpp*.ipk -o \
				-iname libatomic*.ipk -o \
				-iname librt*.ipk \
			\) -exec cp -f {} ${PKGS_DIR} \;
		} || {
			[ ! -d "./bin/packages" ] || find ./bin/packages -type f -iname *.ipk ! -iname boost_*.ipk ! -iname boost-*.ipk -exec cp -f {} ${PKGS_DIR} \;
			[ ! -d "./bin/targets" ] || find ./bin/targets -type f \( \
				-iname libstdcpp*.ipk -o \
				-iname libatomic*.ipk \
			\) -exec cp -f {} ${PKGS_DIR} \;
		}
	fi

	STAGING_DIR_HOST=$(pwd)/staging_dir/host
	SCRIPT_DIR=$(pwd)/scripts
	BUILD_KEY=qbt-key
	export MKHASH=${STAGING_DIR_HOST}/bin/mkhash
	export PATH=${STAGING_DIR_HOST}/bin:$PATH

	# Index the packages
	cd ${PKGS_DIR}
	${SCRIPT_DIR}/ipkg-make-index.sh . 2>&1 > Packages.manifest
	grep -vE '^(Maintainer|LicenseFiles|Source|SourceName|Require|SourceDateEpoch)' Packages.manifest > Packages
	case "$$(((64 + $$(stat -L -c%s Packages)) % 128))" in
	110|111)
		echo "::warning:: Applying padding in ${PKGS_DIR}/Packages to workaround usign SHA-512 bug!"
		{ echo ""; echo ""; } >> Packages
		;;
	esac
	gzip -9nc Packages > Packages.gz
	cd -

	# Sign the packages
	usign -G -s ${BUILD_KEY} -p ${BUILD_KEY}.pub -c "Local qbt build key"
	usign -S -m "${PKGS_DIR}/Packages" -s "${BUILD_KEY}"

	fingerprint=$(usign -F -p ${BUILD_KEY}.pub)
	cp ${BUILD_KEY}.pub "${KEY_DIR}/$fingerprint"
fi

# Generate the install script
sed 's/^    //g' > ${SAVE_ROOT_DIR}/install.sh <<-"EOF"
    #!/bin/sh
    work_dir=$(pwd)
    script_dir="$(cd "$( dirname "$0" )" && pwd)"

    cd ${work_dir}

    if [ "$(opkg print-architecture | sed -n 's/arch \(\S\+\) 10/\1/pg')" != "${target_arch}" ]; then
    	add_arch=1
    	cat >> /etc/opkg.conf <<-EOF1
    		# qbt add start
    		$(opkg print-architecture)
    		arch ${target_arch} 1
    		# qbt add end"
    	EOF1
    fi

    case "$1" in
    	install)
    		shift
    		cp ${script_dir}/key/$fingerprint /etc/opkg/keys
    		sed -i "\$asrc\/gz openwrt_qbt file:\/\/$(echo ${script_dir}/pkgs | sed 's/\//\\\//g')" /etc/opkg/customfeeds.conf

    		echo "-------------------------------------------"
    		opkg print-architecture
    		echo "-------------------------------------------"

    		mkdir -p /var/opkg-lists/
    		cp ${script_dir}/pkgs/Packages.gz /var/opkg-lists/openwrt_qbt
    		cp ${script_dir}/pkgs/Packages.sig /var/opkg-lists/openwrt_qbt.sig

    		[ "$#" -gt 0 ] || set -- qbittorrent luci-app-qbittorrent luci-i18n-qbittorrent-zh-cn
    		opkg install $@
    		sed -i "/src\/gz openwrt_qbt file:\/\/$(echo ${script_dir}/pkgs | sed 's/\//\\\//g')/d" /etc/opkg/customfeeds.conf
    		rm -rf /etc/opkg/keys/$fingerprint
    	;;
    	remove)
    		opkg --force-removal-of-dependent-packages $@
    	;;
    	*)
    		echo "Usage:"
    		echo "	$0 [sub-command]"
    		echo ""
    		echo "Commands:"
    		echo "	install			Install qbittorrent and its depends"
    		echo "	remove <pkgs>		Uninstall pkgs"
    		echo ""
    	;;
    esac

    [ "$add_arch" != 1 ] || sed -i '/# qbt add start/{:a;N;/# qbt add end/!ba;d}' /etc/opkg.conf
EOF

sed -i -e "s/\${target_arch}/${target_arch}/g" \
	-e "s/\$fingerprint/${fingerprint}/g" ${SAVE_ROOT_DIR}/install.sh

SAVED_NAME="${target_arch}-${CUR_LINK_TYPE}-qt${CUR_QT_VERSION}-lt_${CUR_LIBT_VERSION}"
# Add SAVED_NAME to the environment variables
echo "SAVED_NAME=${SAVED_NAME}" >> $GITHUB_ENV

[ ! -f ${PKGS_DIR}/qbittorrent*.ipk ] || {
	echo "pkgs=true" >> $GITHUB_OUTPUT
	cd ..
	ln -sf "${SAVE_ROOT_DIR}" "${SAVED_NAME}"
	XZ_OPT="-T0" tar -cJf "${SAVED_NAME}.tar.xz" ${SAVED_NAME}/*
	sha256sum -b ${SAVED_NAME}.tar.xz > ${SAVED_NAME}.sha256sum
	cd -
}

[ ! -d "./logs" ] || {
	echo "logs=true" >> $GITHUB_OUTPUT
	XZ_OPT="-T0" tar -cJf "../${SAVED_NAME}.logs.tar.xz" "logs"
}

## Compress and encrypt the keychain
# tar -czvf - ${BUILD_KEY}.pub ${BUILD_KEY} | \
# openssl enc -aes-256-ctr -pbkdf2 -pass pass:${KEYCHAIN_SECRET} > ${SAVE_ROOT_DIR}-keychain.bin
## openssl enc -d -aes-256-ctr -pbkdf2 -pass pass:123456 -in ${SAVE_ROOT_DIR}-keychain.bin | tar -xz

# Clean up the obsolete packages
if [ -d "./dl" ]; then
	./scripts/dl_cleanup.py dl 2>/dev/null
	rm -rf dl/libtorrent-rasterbar-*.tar.gz
fi
