#!/bin/bash 
for i in {0..19}; do
  counter=1
  docker kill --signal=SIGINT archiveteam_$i
  while [ "$(docker container inspect -f '{{.State.Status}}' archiveteam_$i )" == "running"] && [ $counter \< 10 ];
  do
    echo "wait for sleep counter on iter $i : $counter"
    sleep 30
    ((counter=$counter+1))
  done
  echo "archiveteam $i no longer running";
done
