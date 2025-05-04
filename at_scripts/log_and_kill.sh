
for i in {00..19}; do
  counter = 1
  date_suffix=$(date +%Y%m%d)
  new_file="archiveteam_$i_${date_suffix}.log"
  output="$(sudo docker logs archiveteam_$i)"
  echo $output >> $new_file
  echo $output >> archivelog.log
  docker kill --signal=SIGINT archiveteam_$i
  while [ "$(docker container inspect -f '{{.State.Status}}' archiveteam_$i)" = "running"] && [ "$counter" <10 ];
  do
    echo "wait for sleep counter on iter $i : $counter"
    sleep 30
    counter = counter+1
  done
  echo "archiveteam $i no longer running";
done

