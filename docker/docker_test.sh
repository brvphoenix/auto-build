#!/bin/bash
set -eET -o pipefail

docker_logs() {
	local _docker_id=$1
	[ -n "${_docker_id}" ] || return

	log_path=$(docker inspect --format {{.LogPath}} ${_docker_id})
	[ -z "${log_path}" ] || {
		echo "::group::Docker logs"
		# Padding zero
		sudo jq -j '"\(.time | .[0:-1] | until(length >= 29; . + "0"))Z \(.log)"' "${log_path}"
		echo "::endgroup::"
	}
	docker rm -f "${_docker_id}"
}

failure() {
	echo "Failed at line $1: $2"
	docker_logs ${docker_id}
}

trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

docker_name=test-container
host_port=28181
req_url=http://127.0.0.1:${host_port}
webui_port=8080
webui_url=http://127.0.0.1:${webui_port}

salt=$(openssl rand -hex 16)
pass=$(openssl rand -hex 12)
dkey=$(openssl kdf -keylen 64 -binary \
	-kdfopt digest:SHA512 \
	-kdfopt pass:${pass} \
	-kdfopt hexsalt:${salt} \
	-kdfopt iter:100000 PBKDF2 | base64 -w 0)

pass_pkdf2=$(printf '%s:%s' $(echo ${salt} | sed 's/\([0-9A-F]\{2\}\)/\\\\\x\1/gI' | xargs echo -ne | base64 -w 0) ${dkey})

docker_id=$(docker run -d \
	-p 127.0.0.1:${host_port}:${webui_port} \
	-e Password_PBKDF2=${pass_pkdf2} \
	--env-file ${GITHUB_WORKSPACE}/docker_env \
	--mount type=bind,src=$GITHUB_WORKSPACE/${SAVED_NAME},dst=/ci,readonly \
	${docker_name})

[ -n "${docker_id}" ] || { echo "::error::Can't startup the docker!"; false; }

end_time=$(($(date +%s) + 200))
while [ "${end_time}" -gt "$(date +%s)" ]; do
	if [ -n "$(docker ps -f id=${docker_id} -f status=running -q)" ]; then
		if [ -n "$(docker exec $docker_id netstat -ntul | grep ${webui_port})" ]; then
			sid=$(curl -is -m 10 \
				-H "Host: ${webui_url}" \
				-d "username=admin&password=${pass}" \
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
		#curl -s -m 10 -X POST -H "Host: ${webui_url}" --cookie "SID=${sid}" ${req_url}/api/v2/app/shutdown
		docker exec $docker_id sh -c 'kill -15 $(pidof qbittorrent-nox)'
		end_time=$(($(date +%s) + 100))
		while [ "${end_time}" -gt "$(date +%s)" ]; do
			[ -n "$(docker ps -f id=${docker_id} -f status=running -q)" ] && sleep 1 || { err_code=0; break; }
		done
	else
		echo "::error::Can't connect to qbittorrent!!!"
	fi
	[ -z "$(docker ps -f id=${docker_id} -f status=running -q)" ] || { echo "::warning::The docker will be forced to kill!"; docker kill ${docker_id}; }
fi

docker_logs ${docker_id}

[ "${err_code:-1}" == 0 ] || false
