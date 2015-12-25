#!/bin/sh

CRON_LOGIN="admin_cron"
CRON_PWD="xxxxxx"

cookie_file=$(mktemp)

curl --silent --output /dev/null --cookie-jar "$cookie_file" \
  --data "method=pwg.session.login&username=${CRON_LOGIN}&password=${CRON_PWD}" \
  "http://localhost/ws.php?format=json"

json=$(curl --silent --cookie "$cookie_file" \
  "http://localhost/ws.php?format=json&method=pwg.getMissingDerivatives&max_urls=200")

rm -f "$cookie_file"

urls=$(echo "
import json
s = '$json'
j = json.loads(s)

for url in j['result']['urls']:
    print url

" | python) || {
    echo "Problem with the json output. End of the script."
    exit 1
}

for url in $urls
do
    echo "$url"
    curl --silent --output /dev/null "$url"
done
