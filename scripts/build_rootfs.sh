#!/bin/sh
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

cd ./${CUR_IB_DIR_NAME}
mkdir -p tmp
profile=$(make info | sed -n '/Available Profiles:/{:a;n;/^\w\+:/!ba;s/\(\w\+\):/\1/g;p}')
set -- $(DEVICE_TYPE=basic make info | sed -n -e 's/Default Packages: \(.*\)$/\1/gp' -e '/^'${profile}':/{:a;n;/\s\+Packages:/!ba;s/.*Packages: \(.*\)/\1/g;p}')
unset pkgs unselected
for pkg in $@; do
	[ "$pkg" = "procd" ] && { unselected=1; continue; } || true
	[ "$unselected" != 1 ] || pkgs="${pkgs} $([[ "$pkg" == "-*" ]] || echo -)${pkg}"
done

echo "::group::Create rootfs"
DEVICE_TYPE=basic make image PROFILE=${profile} PACKAGES="${pkgs}"
echo "::endgroup::"
find build_dir/target-* -mindepth 1 -maxdepth 1 -type d -iname "root-*" | xargs -i mv {} ../${CUR_REPO_NAME}/docker/custom/rootfs
