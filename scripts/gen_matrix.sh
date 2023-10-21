#!/bin/bash
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

matrix='[]'
target='[]'
pkg='[]'

for json_file in ./*.json; do
	json_file_name=$(basename $json_file)
	link=${json_file_name%.*}
	[ -z "${inputs_type}" ] || [ "${inputs_type}" = "all" ] || [ "${inputs_type}" = "${link}" ] || continue;

	matrix=$(jq -c --argjson mt "${matrix}" --arg lt "${inputs_lt/./_}" --arg qt "${inputs_qt}" --arg target "${inputs_target}" --arg link "${link}" '
		[foreach (.openwrt | (if (.RUN_SKIP? // false) then [] else . end) | to_entries | .[] | select((.value | type) == "object")) as $item (
			[{
				lt: .qbittorrent.LIBTORRENT_VERSION? | to_entries[]? | .key? | select($lt == "" or $lt == "all" or $lt == .),
				qt: .qbittorrent.QT_VERSION? | to_entries[]? | .key? | select($qt == "" or $qt == "all" or $qt == .),
				link: $link,
				target: .openwrt | to_entries[] | select((.value | type) == "object" and (.value?.RUN_SKIP? // false) != true) | .key | (
					select($target == "" or $target == "all" or (split("-") | .[0]) == $target)
				)
			}];
			map(select(.target == $item.key) += {runtime_test: ($item.value?.RUNTIME_TEST? // false)});
			.[] | select(.target == $item.key)
		)] | . + $mt | unique | sort_by(.lt, .qt, .link, .target)
	' ${link}.json)

	target=$(jq -c --argjson tg "$target" --arg lt "${inputs_lt/./_}" --arg qt "${inputs_qt}" --arg target "${inputs_target}" --arg link "${link}" '
		.openwrt | (if (.RUN_SKIP? // false) then [] else . end) | {
		        sdk_ver: .USE_SDK_VERSION,
	                sdk_keyring: .USE_SDK_KEYRING,
	                rootfs_ver: (.USE_ROOTFS_VERSION? // .USE_SDK_VERSION),
	                rootfs_keyring: (.USE_ROOTFS_KEYRING? // .USE_SDK_KEYRING)
	        } as $info | to_entries | map(select((.value | type == "object") and (.value?.RUN_SKIP? // false) != true and ($target == "" or $target == "all" or (.key | split("-") | .[0]) == $target)) | .value += {
	        	USE_SDK_VERSION: (.value.USE_SDK_VERSION? // $info.sdk_ver),
	        	USE_SDK_KEYRING: (.value.USE_SDK_KEYRING? // $info.sdk_keyring),
	        	USE_ROOTFS_VERSION: (.value.USE_ROOTFS_VERSION? // $info.rootfs_ver),
	        	USE_ROOTFS_KEYRING: (.value.USE_ROOTFS_KEYRING? // $info.rootfs_keyring),
	        	target: .key,
	        	link: $link,
			sdk: false,
			rootfs: false
	        } | .value) | . + $tg | unique_by(.target, .USE_SDK_VERSION, .USE_ROOTFS_VERSION)' ${link}.json)

	pkg=$(jq -c --argjson mt "${matrix}" --argjson pkg "${pkg}" --arg link "${link}" '
		.openwrt | (if (.RUN_SKIP? // false) then [] else . end) | {
	                sdk_ver: .USE_SDK_VERSION
	        } as $info | [foreach (to_entries | .[] | select(.value | type == "object")) as $item (
			$mt;
			map(select(.target == $item.key and .link == $link) += {sdk_ver: ($item.value.USE_SDK_VERSION? // $info.sdk_ver)});
			.[] | select(.target == $item.key and .link == $link)
		)] | . + $pkg | unique_by(.sdk_ver, .qt)' ${link}.json)
done

[ "${matrix}" != "[]" ] || exit 1
echo "matrix={\"include\":${matrix}}" >> $GITHUB_OUTPUT

target=$(echo "$target" | jq -c '[foreach (unique_by(.target, .USE_ROOTFS_VERSION) | .[]) as $item (
	.;
	(map(select(.target == $item.target and .USE_ROOTFS_VERSION == $item.USE_ROOTFS_VERSION)) | .[0].rootfs |= true) +
	map(select(.target != $item.target or .USE_ROOTFS_VERSION != $item.USE_ROOTFS_VERSION));
	.[] | select(.target == $item.target and .USE_ROOTFS_VERSION == $item.USE_ROOTFS_VERSION)
)] | [foreach (unique_by(.target, .USE_SDK_VERSION) | .[]) as $item (
	.;
	(map(select(.target == $item.target and .USE_SDK_VERSION == $item.USE_SDK_VERSION)) | .[0].sdk |= true) +
	map(select(.target != $item.target or .USE_SDK_VERSION != $item.USE_SDK_VERSION));
	.[] | select(.target == $item.target and .USE_SDK_VERSION == $item.USE_SDK_VERSION)
)]')

echo "target={\"include\":${target}}" >> $GITHUB_OUTPUT

echo "pkg={\"include\":${pkg}}" >> $GITHUB_OUTPUT


