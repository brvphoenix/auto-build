#!/bin/bash
set -eET -o pipefail
. ${GITHUB_WORKSPACE}/${CUR_REPO_NAME}/scripts/build_default.sh

host_port=28181
req_url=http://127.0.0.1:${host_port}
webui_port=8080
webui_url=http://127.0.0.1:${webui_port}

docker_id=$(docker run -d -p 127.0.0.1:${host_port}:${webui_port} --env-file ${GITHUB_WORKSPACE}/docker_env --mount type=bind,src=$GITHUB_WORKSPACE/${SAVED_NAME},dst=/ci,readonly test-container)

[ -n "${docker_id}" ] || { echo "::error::Can't startup the docker!"; exit 1; }

end_time=$(($(date +%s) + 200))
while [ "${end_time}" -gt "$(date +%s)" ]; do
	if [ -n "$(docker ps -f id=${docker_id} -f status=running -q)" ]; then
		if [ -n "$(docker exec $docker_id netstat -ntul | grep ${webui_port})" ]; then
			sid=$(curl -is -m 10 \
				-H "Host: ${webui_url}" \
				-d 'username=admin&password=adminadmin' \
				${req_url}/api/v2/auth/login \
				| grep '^set-cookie' | sed -n 's/\S\+ SID=\([^\x0-\x1f ",;\\\x7f]\+\); .*/\1/gp' 2>&1);
			[ -z "$sid" ] || break;
		fi

		sleep 1
	else
		echo "::error::The docker is not running!"
		break
	fi
done
printf "Startup delay: %ss\n" $((200 + $(date +%s) - ${end_time}))

if [ -n "$(docker ps -f id=${docker_id} -f status=running -q)" ]; then
	echo "::group::Process list"
	docker exec ${docker_id} sh -c 'top -b -n 1'
	echo "::endgroup::"
	if [ -n "$sid" ]; then
		echo "::group::qBittorrent info"
		echo "-------------------------------------------"
		curl -s -m 10 -H "Host: ${webui_url}" --cookie "SID=${sid}" ${req_url}/api/v2/app/version | xargs echo "qBittorrent:"
		curl -s -m 10 -H "Host: ${webui_url}" --cookie "SID=${sid}" ${req_url}/api/v2/app/webapiVersion | xargs echo "WebAPI:"
		echo "-------------------------------------------"
		curl -s -m 10 -H "Host: ${webui_url}" --cookie "SID=${sid}" ${req_url}/api/v2/app/buildInfo | jq -r 'to_entries[] | "\(.key): \(.value)"'
		echo "::endgroup::"
		echo "::group::qBittorrent logs"
		curl -s -m 10 -H "Host: ${webui_url}" --cookie "SID=${sid}" ${req_url}/api/v2/log/main?last_known_id=-1 | jq -r '.[] | "\(.timestamp | todate) \(.message)"'
		echo "::endgroup::"
		curl -s -m 10 -X POST -H "Host: ${webui_url}" --cookie "SID=${sid}" ${req_url}/api/v2/app/shutdown
		end_time=$(($(date +%s) + 100))
		while [ "${end_time}" -gt "$(date +%s)" ]; do
			[ -n "$(docker ps -f id=${docker_id} -f status=running -q)" ] && sleep 1 || { err_code=0; break; }
		done
	else
		echo "::error::Can't connect to qbittorrent!!!"
	fi
	[ -z "$(docker ps -f id=${docker_id} -f status=running -q)" ] || { echo "::warning::The docker will be forced to kill!"; docker kill ${docker_id}; }
fi

log_path=$(docker inspect --format {{.LogPath}} ${docker_id})
[ -z "${log_path}" ] || {
	echo "::group::Docker logs"
	## keep six digits
	#sudo jq -j '"\(.time | .[0:-1] | [.[0:19], (.[19:] | tonumber * 1e6 | round | tostring | until(length >= 6; "0" + .))] | join("."))Z \(.log)"' "${log_path}"
	# Padding zero
	sudo jq -j '"\(.time | .[0:-1] | until(length >= 29; . + "0"))Z \(.log)"' "${log_path}"
	echo "::endgroup::"
}
docker rm -f "${docker_id}"

exit ${err_code:-1}
