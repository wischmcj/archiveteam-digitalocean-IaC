for i in {00..19}; do
  date_suffix=$(date +%Y%m%d)
  new_file="logs/archiveteam_${i}_${date_suffix}_new.log"
  agg_file="logs/archiveteam_agg_${date_suffix}.log"
  output="$(sudo docker logs archiveteam_$i)"
  touch $new_file
  echo $output >> $new_file
  echo $output >> $agg_file
  echo "wrote logs for ${i} to ${new_file}"
done
exit 0
