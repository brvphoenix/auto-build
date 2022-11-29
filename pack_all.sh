#!/bin/bash

set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

if [ "${CACHE_HIT}" = "true" ]; then
	[ -f "${SAVED_NAME}.tar.xz" ] && {
		tar -xJf ${SAVED_NAME}.tar.xz;
		echo "hash=$(sha256sum ${SAVED_NAME}.tar.xz | cut -d ' ' -f1)" >> $GITHUB_OUTPUT;
		echo "pkgs=true" >> $GITHUB_OUTPUT
	} || echo "Not exist: ${SAVED_NAME}.tar.xz"

	[ -f "${SAVED_NAME}.log.tar.xz" ] && echo "logs=true" >> $GITHUB_OUTPUT || echo "Not exist: ${SAVED_NAME}.log.tar.xz"
	exit 0
fi

target_arch=$1
link_type=$2

# Compress the log files
[ -d "build/logs" ] && { \
	cd build && XZ_OPT=-9 tar -cJvf ../${SAVED_NAME}.log.tar.xz logs
	cd ..
	echo "logs=true" >> $GITHUB_OUTPUT
}

# The save path of the packages
PKGS_DIR=${SAVED_NAME}/pkgs
KEY_DIR=${SAVED_NAME}/key
mkdir -p ${PKGS_DIR} ${KEY_DIR}

if [ "${link_type}" = "static" ]; then
	[ ! -d "build/bin/packages" ] || find build/bin/packages -type f -iname *qbittorrent* -exec cp -f {} ${PKGS_DIR} \;
else
	[ ! -d "build/bin/packages" ] || find build/bin/packages -type f -iname *.ipk -exec cp -f {} ${PKGS_DIR} \;

	[ ! -d "build/bin/targets" ] || find build/bin/targets -type f \( \
		-iname libstdcpp* -or \
		-iname libatomic* \
	\) -exec cp -f {} ${PKGS_DIR} \;
fi

# Add to repository
STAGING_DIR_HOST=$(pwd)/build/staging_dir/host
SCRIPT_DIR=$(pwd)/build/scripts
BUILD_KEY=qbt-key
export MKHASH=${STAGING_DIR_HOST}/bin/mkhash
export PATH=${STAGING_DIR_HOST}/bin:$PATH
usign -G -s ${BUILD_KEY} -p ${BUILD_KEY}.pub -c "Local qbt build key"

fingerprint=$(usign -F -p ${BUILD_KEY}.pub)
cp ${BUILD_KEY}.pub "${KEY_DIR}/$fingerprint"

cd ${PKGS_DIR} && \
	${SCRIPT_DIR}/ipkg-make-index.sh . > Packages && \
	gzip -9nc Packages > Packages.gz
cd "$(echo ${PKGS_DIR} | sed 's/^\///g' | sed 's/\// /g' | sed 's/\S\+/../g' | sed 's/ /\//g')"

usign -S -m "${PKGS_DIR}/Packages" -s "${BUILD_KEY}"

# Generate the install script
sed 's/^    //g' > ${SAVED_NAME}/install.sh <<-"EOF"
    #!/bin/sh
    work_dir=$(pwd)
    script_dir="$( cd "$( dirname "$0" )" && pwd )"

    cd ${work_dir}

    if [ -n "$(opkg print-architecture | awk '{print $2}' | grep '^${target_arch}$')" ]; then
    	add_arch=0
    else
    	add_arch=1
    	sed -i "\$a# qbt add start\n$(opkg print-architecture | sed ':a;N;$!ba;s/\n/\\\n/g')\narch ${target_arch} 1\n# qbt add end" /etc/opkg.conf
    fi

    case "$1" in
    	install)
    		cp ${script_dir}/key/$fingerprint /etc/opkg/keys
    		sed -i "\$asrc\/gz openwrt_qbt file:\/\/$(echo ${script_dir}/pkgs | sed 's/\//\\\//g')" /etc/opkg/customfeeds.conf

    		opkg print-architecture

    		mkdir -p /var/opkg-lists/
    		cp ${script_dir}/pkgs/Packages.gz /var/opkg-lists/openwrt_qbt
    		cp ${script_dir}/pkgs/Packages.sig /var/opkg-lists/openwrt_qbt.sig

    		opkg install qbittorrent
    		opkg install luci-app-qbittorrent
    		opkg install luci-i18n-qbittorrent-zh-cn
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

    [ "$add_arch" = 1 ] && sed -i '/# qbt add start/{:a;N;/# qbt add end/!ba;d}' /etc/opkg.conf || exit 0
EOF

sed -i "s/\${target_arch}/${target_arch}/g" ${SAVED_NAME}/install.sh
sed -i "s/\$fingerprint/${fingerprint}/g" ${SAVED_NAME}/install.sh

# Compress the pkgs
tar -cJf ${SAVED_NAME}.tar.xz ${SAVED_NAME}
echo "pkgs=true" >> $GITHUB_OUTPUT

# hashFiles has different value with sha256sum
echo "hash=$(sha256sum ${SAVED_NAME}.tar.xz | cut -d ' ' -f1)" >> $GITHUB_OUTPUT

## Compress and encrypt the keychain
# tar -czvf - ${BUILD_KEY}.pub ${BUILD_KEY} | \
# openssl enc -aes-256-ctr -pbkdf2 -pass pass:${KEYCHAIN_SECRET} > ${SAVED_NAME}-keychain.bin
## openssl enc -d -aes-256-ctr -pbkdf2 -pass pass:123456 -in ${SAVED_NAME}-keychain.bin | tar -xz

# Clean up the obsolete packages
if [ ! -d "build/dl" ]; then
	cd build
	./scripts/dl_cleanup.py 2>&1 >/dev/null
	rm -rf dl/libtorrent-rasterbar-*.tar.gz
	cd ..
fi
