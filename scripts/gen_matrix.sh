#!/bin/bash
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

matrix='[]'
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
done

[ "${matrix}" != "[]" ] || exit 1
echo "matrix={\"include\":${matrix}}" >> $GITHUB_OUTPUT
