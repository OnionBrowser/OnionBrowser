#!/bin/bash -euo pipefail
# https://blog.twitch.tv/ios-versioning-89e02f0a5146

if [ ${#} -eq 0 ]
then
# read from STDIN
MAYBE_GIT_HASH=$( cat )
else
MAYBE_GIT_HASH="${1}"
fi

LEGAL_GIT_HASH_CHARACTERS="0123456789ABCDEFabcdef"
# grep regex doesn't allow + metacharacter :(
HASH_GREP_REGEX='^['"${LEGAL_GIT_HASH_CHARACTERS}"']['"${LEGAL_GIT_HASH_CHARACTERS}"']*$'
GIT_HASH=$( echo "${MAYBE_GIT_HASH}" | grep "${HASH_GREP_REGEX}" ) || {
echo "\"${MAYBE_GIT_HASH}\" doesnt look like a git hash. A git hash should have only: \"${LEGAL_GIT_HASH_CHARACTERS}\"" >&2
exit 1
}

# We must prefix the git hash with a 1
# If it starts with a zero, when we decimalize it,
# and later hexify it, we'll lose the zero.
ONE_PREFIXED_GIT_HASH=1"${GIT_HASH}"

# bc requires hex to be uppercase because
# lowercase letters are reserved for bc variables
UPPERCASE_ONE_PREFIXED_GIT_HASH=$( echo "${ONE_PREFIXED_GIT_HASH}" | tr "[:lower:]" "[:upper:]" )

# convert to decimal
# See "with bc": http://stackoverflow.com/a/13280173/9636
echo "ibase=16;obase=A;${UPPERCASE_ONE_PREFIXED_GIT_HASH}" | bc
