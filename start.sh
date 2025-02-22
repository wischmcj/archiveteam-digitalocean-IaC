set -e

docker kill $(docker ps -q --filter="name=watchtower") || true
docker rm $(docker ps -qa --filter="name=watchtower") || true

docker kill $(docker ps -q --filter="name=archiveteam") || true
docker rm $(docker ps -qa --filter="name=archiveteam") || true

docker run --detach --name watchtower --restart=on-failure --volume /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --label-enable --include-restarting --cleanup --interval 3600
# 
for i in {0..${warriors}}; do
    port=$((8000 + i))
    docker run -d --name archiveteam_$i  --env-file=/tmp/env --publish 32770:8001 --restart=on-failure --label=com.centurylinklabs.watchtower.enable=true --log-driver json-file --log-opt max-size=50m atdr.meo.ws/archiveteam/usgovernment-grab --concurrent 1 penguaman
    # docker run --name warrior_00 -d --env-file=/tmp/env --publish $port:8001 --restart=on-failure --label=com.centurylinklabs.watchtower.enable=true --log-driver json-file --log-opt max-size=50m  atdr.meo.ws/archiveteam/warrior-dockerfile penguaman
    echo "archiveteam_$i  container started";
done
exit 0
# start your project container
# for i in {00..01}; do
# #   docker run -d --name archiveteam_$i --label=com.centurylinklabs.watchtower.enable=true --log-driver json-file --log-opt max-size=50m --restart=unless-stopped atdr.meo.ws/archiveteam/usgovernment-grab --concurrent 1 penguaman
# #   docker run --name warrior-$i -d --env-file=/tmp/env --publish $port:8001 --restart=always archiveteam/warrior-dockerfile penguaman
#   docker run --name warrior_$i -d --env-file=/tmp/env --publish $port:8001 --restart=on-failure --label=com.centurylinklabs.watchtower.enable=true --log-driver json-file --log-opt max-size=50m  atdr.meo.ws/archiveteam/warrior-dockerfile penguaman
#   echo "archiveteam $i container started";
# done
# exit 0
