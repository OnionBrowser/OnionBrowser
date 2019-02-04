#!/bin/bash -euo pipefail
# https://blog.twitch.tv/ios-versioning-89e02f0a5146

if [ ${#} -eq 0 ]
then
# read from STDIN
DATE=$( cat )
else
DATE="${1}"
fi

SECONDS_FROM_EPOCH_TO_NOW=$( date "+%s" )
SECONDS_FROM_EPOCH_TO_DATE=$( date -j -f "%Y-%m-%d %H:%M:%S %Z" "${DATE}" "+%s" )

MINUTES_SINCE_DATE=$(( $(( ${SECONDS_FROM_EPOCH_TO_NOW}-${SECONDS_FROM_EPOCH_TO_DATE} ))/60 ))

echo "${MINUTES_SINCE_DATE}"
