set -e

docker kill $(docker ps -q --filter="name=watchtower") || true
docker rm $(docker ps -qa --filter="name=watchtower") || true

docker kill $(docker ps -q --filter="name=archiveteam") || true
docker rm $(docker ps -qa --filter="name=archiveteam") || true

docker run --detach --name watchtower --restart=on-failure --volume /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --label-enable --include-restarting --cleanup --interval 3600
port=8001
docker run -d --name archiveteam  --env-file=/tmp/env --publish 8001:8001 --restart=on-failure --label=com.centurylinklabs.watchtower.enable=true --log-driver json-file --log-opt max-size=50m atdr.meo.ws/archiveteam/usgovernment-grab --concurrent 1 penguaman
