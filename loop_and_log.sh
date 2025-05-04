#!/bin/bash 
for i in {0..19}; do
  date_suffix=$(date +%Y%m%d)
  new_file="logs/archiveteam_${i}_${date_suffix}_new.log"
  agg_file="logs/archiveteam_agg_${date_suffix}.log"
  output="$(sudo docker logs -t archiveteam_$i)"
  touch $new_file
  echo $output >> $new_file
  # echo $output >> $agg_file
  grep -E "sent \b[0-9]{1,3}(,[0-9]{3})*(\.[0-9]+)?\b bytes" -o $new_file
  echo "wrote logs for ${i} to ${new_file}"
done
# grep -E "[0-9]{4}-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9]{9}Z sent \b[0-9]{1,3}(,[0-9]{3})*(\.[0-9]+)?\b bytes " -o archiveteam_agg_20250307.log >> /sent.log
# grep -E "[0-9]{4}-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9]{9}Z sent \b[0-9]{1,3}(,[0-9]{3})*(\.[0-9]+)?\b bytes " -o archiveteam_agg_20250307.log >> /sent.log

exit 0
