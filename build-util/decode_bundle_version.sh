#!/bin/bash -euo pipefail
# https://blog.twitch.tv/ios-versioning-89e02f0a5146

if [ ${#} -eq 0 ]
then
# read from STDIN
MAYBE_CFBUNDLEVERSION=$( cat )
else
MAYBE_CFBUNDLEVERSION="${1}"
fi

MAYBE_DECIMALIZED_MAYBE_ONE_PREFIXED_GIT_HASH=$( echo "${MAYBE_CFBUNDLEVERSION}" | sed 's/[0-9][0-9]*\.\([0-9][0-9]*\)/\1/' )

LEGAL_DECIMALIZED_GIT_HASH_CHARACTERS="0123456789"
# grep regex doesn't allow + metacharacter :(
DECIMALIZED_GREP_REGEX='^['"${LEGAL_DECIMALIZED_GIT_HASH_CHARACTERS}"']['"${LEGAL_DECIMALIZED_GIT_HASH_CHARACTERS}"']*$'
DECIMALIZED_MAYBE_ONE_PREFIXED_GIT_HASH=$( echo "${MAYBE_DECIMALIZED_MAYBE_ONE_PREFIXED_GIT_HASH}" | grep "${DECIMALIZED_GREP_REGEX}" ) || {
echo "\"${MAYBE_CFBUNDLEVERSION}\" doesnt look like a CFBundleVersion we expect. It should contain two dot-separated numbers." >&2
exit 1
}

# convert to hex
# http://stackoverflow.com/a/379422/9636
MAYBE_ONE_PREFIXED_GIT_HASH=$( echo "ibase=10;obase=16;${DECIMALIZED_MAYBE_ONE_PREFIXED_GIT_HASH}" | bc )

#grep doesn't allow + metacharacter. Thus match any one: (.) then any zero or more: (.*)
ONE_PREFIXED_GIT_HASH=$( echo "${MAYBE_ONE_PREFIXED_GIT_HASH}" | grep '^1..*$' ) || {
echo "\"${MAYBE_CFBUNDLEVERSION}\"'s second number, \"${MAYBE_DECIMALIZED_MAYBE_ONE_PREFIXED_GIT_HASH}\", is \"${MAYBE_ONE_PREFIXED_GIT_HASH}\" in hex, which didnt start with a \"1\"." >&2
exit 2
}

# Read ${ONE_PREFIXED_GIT_HASH} starting at position 1.
# See "Variable expansion / Substring replacement" in
# http://www.tldp.org/LDP/abs/html/parameter-substitution.html
UPPERCASED_GIT_HASH="${ONE_PREFIXED_GIT_HASH:1}"

# bc uses uppercase letters for hex because
# it reserves lowercase letters for variables
# but git hashes are written with lowercase letters
# so convert to lowercase to look more git-like
GIT_HASH=$( echo "${UPPERCASED_GIT_HASH}" | tr "[:upper:]" "[:lower:]" )

echo "${GIT_HASH}"
