#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds PC/SC-Lite from sources.

PCSC_VER=1.8.24
PCSC_TAR=pcsc-lite-"$PCSC_VER".tar.bz2
PCSC_DIR=pcsc-lite-"$PCSC_VER"
PKG_NAME=pcsc-lite

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of pcsclite jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_SET" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to test password"
        exit 1
    fi
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

echo
echo "********** PC/SC-Lite **********"
echo

if ! "$WGET" -O "$PCSC_TAR" --ca-certificate="$CA_ZOO" \
     "https://pcsclite.apdu.fr/files/$PCSC_TAR"
then
    echo "Failed to download PC/SC-Lite"
    exit 1
fi

rm -rf "$PCSC_DIR" &>/dev/null
bzip2 -dk < "$PCSC_TAR" | tar xf -
cd "$PCSC_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-static \
    --enable-shared \
    --disable-libsystemd \
    --disable-libudev

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure PC/SC-Lite"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("MAKEINFO=true" "-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PC/SC-Lite"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pc.sh .; ./fix-pc.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test PC/SC-Lite"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test PC/SC-Lite"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -kS "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PCSC_TAR" "$PCSC_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-pcsclite.sh 2>&1 | tee build-pcsclite.log
    if [[ -e build-pcsclite.log ]]; then
        rm -f build-pcsclite.log
    fi
fi

exit 0

