#! /usr/bin/env bash

set -e

docker kill $(docker ps -q --filter="name=warrior") || true
docker rm $(docker ps -qa --filter="name=warrior") || true

# TODO replace with variable
for i in {1..${warriors}}
do
  port=$((8000 + i))
  docker run --name warrior-$i -d --env-file=/tmp/env --publish $port:8001 --restart=always archiveteam/warrior-dockerfile
 done
