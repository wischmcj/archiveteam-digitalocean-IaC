#!/bin/bash/
scp http://174.138.55.122/

# getting items recieved from tracker 
grep -E " Received item 'https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/\S*)?' from tracker " -o logs/archiveteam_02_20250219_new.log 

# Bytes sent
grep -E "sent \b[0-9]{1,3}(,[0-9]{3})*(\.[0-9]+)?\b bytes" -o logs/archiveteam_13_20250219_new.log 

# Upload rate 
grep -E "bytes \b[0-9]{1,3}(,[0-9]{3})*(\.[0-9]+)?\b bytes/sec" -o logs/archiveteam_13_20250219_new.log 

# Item finished 
grep -E " RsyncUpload for Item https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/\S*)? Starting SendDoneToTracker" -o logs/archiveteam_02_20250219_new.log 

# all urls mentioned 
grep -E " https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/\S*)? " -o logs/archiveteam_02_20250219_new.log

# sent bytes timestamp
grep -E "[0-9]{4}-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9]{9}Z sent \b[0-9]{1,3}(,[0-9]{3})*(\.[0-9]+)?\b bytes " -o archiveteam_agg_20250307.log
