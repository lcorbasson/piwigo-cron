#!/bin/bash

# Cron script to generate pictures.
# See http://fr.piwigo.org/forum/viewtopic.php?pid=207043

set -e
export LC_ALL=C
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"


DURATION=3600 # in seconds
URLS_PER_LOOP=50

. "$(dirname "$0")/credentials.sh"

PIWIGO_URL="${PIWIGO_URL%/}"	# remove trailing slash to avoid unnecessary HTTP 301's

get_urls () {
    cookie_file="$(mktemp)"

    # Connection with the cron account via the Piwigo API.
    # See http://<piwigo hostname>/tools/ws.htm.
    curl --silent --output /dev/null --cookie-jar "$cookie_file" \
      --data-urlencode "method=pwg.session.login" --data-urlencode "username=${PIWIGO_LOGIN}" --data-urlencode "password=${PIWIGO_PASSWD}" \
      "${PIWIGO_URL}/ws.php?format=json"

    # Get a json of the urls to visit with the "pwg.getMissingDerivatives" method.
    json="$(curl --silent --cookie "$cookie_file" \
      "${PIWIGO_URL}/ws.php?format=json&method=pwg.getMissingDerivatives&max_urls=${URLS_PER_LOOP}")"

    rm -f "$cookie_file"

    python_script="import json
s = '$json'
j = json.loads(s)

for url in j['result']['urls']:
    print(url)
"

    # Extracting urls with Python and "json" module.
    if echo "$python_script" | python; then
        return 0
    else
        return 1
    fi
}



begin=$(date "+%s")
loop_number=1

while true; do
    echo ">>> Loop number $loop_number"
    loop_number=$((loop_number + 1))

    # curl on each urls to generate pictures.
    if urls="$(get_urls)"; then
        for url in $urls; do
            echo "$url"
            curl --silent --output /dev/null "$url"
        done
    else
        # If there is a problem, it's finished.
        echo "Problem with the json output, end of the script."
        exit 1
    fi

    # If there is no url, it's finished.
    if [ -z "$urls" ]; then
        echo "There is no url, end of the script."
        exit 0
    fi

    now=$(date "+%s")
    elapsed_time=$((now - begin))

    # If the timeout is exceeded, it's finished.
    if [ $elapsed_time -ge $DURATION ]; then
        echo "Timeout, end of the script."
        exit 0
    fi
done

