#!/bin/bash
#  Builds openssl for all three current iPhone targets: iPhoneSimulator-i386,
#  iPhoneOS-armv6, iPhoneOS-armv7.
#
#  Copyright 2012 Mike Tigas <mike@tig.as>
#
#  Based on work by Felix Schulze on 16.12.10.
#  Copyright 2010 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
#  Choose your openssl version and your currently-installed iOS SDK version:
#
VERSION="1.0.1-beta3"
SDKVERSION="5.0"
#
#
###########################################################################
#
# Don't change anything under this line!
#
###########################################################################

ARCHS="i386 armv6 armv7"
DEVELOPER=`xcode-select -print-path`

cd "`dirname \"$0\"`"
REPOROOT=$(pwd)

# Where we'll end up storing things in the end
OUTPUTDIR="${REPOROOT}/dependencies"
mkdir -p ${OUTPUTDIR}/include
mkdir -p ${OUTPUTDIR}/lib


BUILDDIR="${REPOROOT}/build"

# where we will keep our sources and build from.
SRCDIR="${BUILDDIR}/src"
mkdir -p $SRCDIR
# where we will store intermediary builds
INTERDIR="${BUILDDIR}/built"
mkdir -p $INTERDIR

########################################

cd $SRCDIR

set -e
if [ ! -e "${SRCDIR}/openssl-${VERSION}.tar.gz" ]; then
	echo "Downloading openssl-${VERSION}.tar.gz"
    curl -O http://www.openssl.org/source/openssl-${VERSION}.tar.gz
else
	echo "Using openssl-${VERSION}.tar.gz"
fi

for ARCH in ${ARCHS}
do
    cd ${SRCDIR}
    rm -fr "openssl-${VERSION}"
    tar zxf openssl-${VERSION}.tar.gz -C $SRCDIR
    cd "${SRCDIR}/openssl-${VERSION}"

	if [ "${ARCH}" == "i386" ];
	then
		PLATFORM="iPhoneSimulator"
        TARGET="BSD-generic32"
	else
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
		PLATFORM="iPhoneOS"
        TARGET="BSD-arm"
        patch -p2 < "${REPOROOT}/openssl-1.0.1-beta3-armv7-asm.diff"
	fi
	
	echo "Building openssl-${VERSION} for ${PLATFORM} ${SDKVERSION} ${ARCH}"
	echo "Please stand by..."

	mkdir -p "${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
	#LOG="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/build-openssl-${VERSION}.log"

    export CC="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/usr/bin/gcc -arch ${ARCH}"
	./configure no-gost ${TARGET} \
    --openssldir="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk" #> "${LOG}" 2>&1

	# add -isysroot to configure-generated CFLAGS
	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk !" "Makefile"

    # Build the application and install it to the fake SDK intermediary dir
    # we have set up. Make sure to clean up afterward because we will re-use
    # this source tree to cross-compile other targets.
	make #>> "${LOG}" 2>&1
	make install #>> "${LOG}" 2>&1
done

########################################

echo "Build library..."
lipo -create ${INTERDIR}/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/libssl.a \
${INTERDIR}/iPhoneOS${SDKVERSION}-armv6.sdk/lib/libssl.a \
${INTERDIR}/iPhoneOS${SDKVERSION}-armv7.sdk/lib/libssl.a \
-output ${OUTPUTDIR}/lib/libssl.a

lipo -create ${INTERDIR}/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/libcrypto.a \
${INTERDIR}/iPhoneOS${SDKVERSION}-armv6.sdk/lib/libcrypto.a \
${INTERDIR}/iPhoneOS${SDKVERSION}-armv7.sdk/lib/libcrypto.a \
-output ${OUTPUTDIR}/lib/libcrypto.a

cp -R ${INTERDIR}/iPhoneSimulator${SDKVERSION}-i386.sdk/include/* ${OUTPUTDIR}/include/
echo "Building done."
echo "Cleaning up..."
rm -fr ${INTERDIR}
rm -fr "${SRCDIR}/openssl-${VERSION}"
echo "Done."
