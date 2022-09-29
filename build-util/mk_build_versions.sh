#!/bin/bash -euo pipefail
# https://blog.twitch.tv/ios-versioning-89e02f0a5146

# When incrementing OB_BUNDLE_SHORT_VERSION_STRING
# also update OB_BUNDLE_SHORT_VERSION_DATE to the current date/time.
# You don't have to be very exact, but it should be updated at least
# once every 18 months because iTunes requires that a CFBundleVersion
# be at most 18 characters long, and DECIMALIZED_GIT_HASH will be
# at most 10 characters long. Thus, MINUTES_SINCE_DATE needs to be
# at most 7 characters long so we can use the format:
# ${MINUTES_SINCE_DATE}.${DECIMALIZED_GIT_HASH}
#
# NOTE: DON'T UPDATE the date, if you DIDN'T INCREASE the version!
# Otherwise, you may end up having older builds looking like newer builds
# for TestFlight users!

# 2.3.X epoch: 2019-10-07 20:00 UTC
# 2.4.X epoch: 2019-12-05 21:00 UTC
# 2.5.X epoch: 2020-01-22 20:57 UTC
# epoch changes at v2.9.0 (or next major version) OR April 2023
OB_BUNDLE_SHORT_VERSION_DATE="2022-05-26 11:00:00 GMT"
OB_BUNDLE_SHORT_VERSION_STRING=2.8.2

BASH_SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

MINUTES_SINCE_DATE="$( cd "${BASH_SOURCE_DIR}" && ./minutes_since_date.bash "${OB_BUNDLE_SHORT_VERSION_DATE}" )"

# decimalized git hash is guaranteed to be 10 characters or fewer because
# the biggest short=7 git hash we can get is FFFFFFF and
# $ ./decimalize_git_hash.bash FFFFFFF | wc -c
# > 10
DECIMALIZED_GIT_HASH="$( cd "${BASH_SOURCE_DIR}"; ./decimalize_git_hash.bash $( git rev-parse --short=7 HEAD ) )"
echo "Decimalized: \"${DECIMALIZED_GIT_HASH}\""

OB_BUNDLE_VERSION="${MINUTES_SINCE_DATE}"."${DECIMALIZED_GIT_HASH}"

echo $OB_BUNDLE_SHORT_VERSION_STRING
echo $OB_BUNDLE_VERSION

cat <<EOF > "${SRCROOT}"/OnionBrowser/version.h
#define OBBundleShortVersionString ${OB_BUNDLE_SHORT_VERSION_STRING}
#define OBBundleVersion ${OB_BUNDLE_VERSION}
EOF

cat "${SRCROOT}"/Resources/credits.html.in | \
sed "s/XX_OB_BUNDLE_SHORT_VERSION_STRING_XX/${OB_BUNDLE_SHORT_VERSION_STRING}/g" | \
sed "s/XX_OB_BUNDLE_VERSION_XX/${OB_BUNDLE_VERSION}/g" \
  > "${SRCROOT}"/Resources/credits.html
