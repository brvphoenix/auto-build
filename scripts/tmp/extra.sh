#!/bin/bash
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/auto-build/build_default.sh

if [ "${link_type}" = "static" ]; then
	cd feeds/base
	curl -kLZ --compressed https://patch-diff.githubusercontent.com/raw/openwrt/openwrt/pull/12813.patch | patch -p1
	rsync -aK package/libs/openssl ../local/custom
	git checkout .
	git clean -df
	cd -
	./scripts/feeds update -i local
fi
