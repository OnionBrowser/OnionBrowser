#!/bin/sh

#  get-geoip.sh
#  OnionBrowser2
#
#  Created by Benjamin Erhart on 04.02.19.
#  Copyright © 2019 Guardian Project. All rights reserved.

# Only downloads new geoip files, if they are missing or older than a day.

if [ ! -f ./geoip ] || [ ! -f ./geoip6 ] || test `find . -name geoip -mtime +1`
then
    curl -Lo ./geoip https://gitweb.torproject.org/tor.git/plain/src/config/geoip?h=tor-0.4.0.5
    curl -Lo ./geoip6 https://gitweb.torproject.org/tor.git/plain/src/config/geoip6?h=tor-0.4.0.5
fi
