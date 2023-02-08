#!/bin/sh

set -eET -o pipefail
. ./build_default.sh

VERSION=${1:-0.0.0}
GITHUB_SERVER_URL=https://github.com

for ver in RC_1_2 RC_2_0; do
	eval "hash_full=$(git ls-remote ${GITHUB_SERVER_URL}/arvidn/libtorrent refs/heads/$ver | cut -f1)"
	hash_9="$(echo -n $hash_full | head -c 9)"
	sed -i 's;\['$ver'@\w\{9\}\]\(('$GITHUB_SERVER_URL'/arvidn/libtorrent/commits/'$ver'?before\)=\w\{40\}\(+35&branch='$ver')\);['$ver'@'$hash_9']\1='$hash_full'\2;g' ./README.md
done

sed -i 's/\(# Version\) \S\+$/\1 '$VERSION'/g' ./README.md
