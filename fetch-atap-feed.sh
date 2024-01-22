#!/bin/bash

# Author: lars.niklasson@qisecurity.se
# Date: 2024-01-22
# Version 1.0
# Copyright 2024, Qi Security AB
# License "GPL"

mkdir -p atap

cd atap

wget -o ../logfile.out https://threatfeed.cyberres.com/feed/manifest.json

echo Starting to download cyberres threat feed. It will take 10-20 minutes...

for filename in $(cat manifest.json | jq |grep "\": {" | grep -v Orgc | cut -d\" -f 2)
do
        wget -o ../logfile.out https://threatfeed.cyberres.com/feed/$filename.json
done

tar cfz ../cyberres-atap-feeds.tar.gz .

# Cleaning
rm -rf *.json
cd ..
rmdir atap

echo 1. Move the tar file over to the airgaped environment
echo 2. Install httpd, enable and start httpd
echo 3. Make sure firewall is blocking port 80, this only need to be reachable via localhost
echo 4. Create the folder /var/www/html/feed
echo 5. Untar the file into this directory
echo 6. Install ArcSight Threat Acceleration Connector
echo 7. Enter http://localhost as Threat Intel URL
echo 8. Start the Connector and in ESM configure the Connecotr with a user as "Model import user"
echo 9. Start the import on the Connector under Send Command/Model Import Connector/Start Import
echo Good luck!
