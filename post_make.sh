#! /bin/sh
USE_TARGET=$1
USE_SUBTARGET=$2
USE_ARCH=$3
USE_LINK=$4

export TARGET_PATH=build/bin/targets/${USE_TARGET}/${USE_SUBTARGET}
export SAVE_PATH=${USE_ARCH}-${USE_LINK}

cd ..
mkdir -p ${SAVE_PATH}

if [ "$USE_LINK" = "static" ]; then
	find build/bin/packages -type f -iname *qbittorrent* -exec cp -f {} ${SAVE_PATH} \;
else
	mkdir -p ${SAVE_PATH}/1 ${SAVE_PATH}/2
	find build/bin/packages -type f \( -iname libqt5* -or -iname  *torrent*.ipk \) -exec cp -f {} ${SAVE_PATH}/1 \;

	find build/bin/packages -type f \( \
		-iname libopenssl1* -or \
		-iname boost_* -or \
		-iname boost-system* -or \
		-iname libdouble-conversion* -or \
		-iname libpcre2-16* -or \
		-iname zlib_* \
	\) -exec cp -f {} ${SAVE_PATH}/2 \;

	find build/bin/targets -type f -iname libstdcpp* -exec cp -f {} ${SAVE_PATH}/2 \;

	[ "$USE_ARCH" = "mips_24kc" ] || [ "$USE_ARCH" = "mipsel_24kc" ] && \
		find build/bin/targets -type f -iname libatomic* -exec cp -f {} ${SAVE_PATH}/2 \;
fi

tar -cJf ${SAVE_PATH}.tar.xz ${SAVE_PATH}
