#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Termcap from sources.

TERMCAP_TAR=termcap-1.3.1.tar.gz
TERMCAP_DIR=termcap-1.3.1
TERMCAP_VER=1.3.1
PKG_NAME=termcap

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
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
echo "********** Termcap **********"
echo

if ! "$WGET" -O "$TERMCAP_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/termcap/$TERMCAP_TAR"
then
    echo "Failed to download Termcap"
    exit 1
fi

rm -rf "$TERMCAP_DIR" &>/dev/null
gzip -d < "$TERMCAP_TAR" | tar xf -
cd "$TERMCAP_DIR" || exit 1

if [[ -e ../patch/termcap.patch ]]; then
    cp ../patch/termcap.patch .
    patch -u -p0 < termcap.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --enable-shared \
    --enable-install-termcap \
    --with-termcap="$INSTX_PREFIX/etc"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Termcap"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

ARFLAGS="cr"
MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! ARFLAGS="$ARFLAGS" "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Termcap"
    exit 1
fi

# Write the *.pc file
{
    echo ""
    echo "prefix=$INSTX_PREFIX"
    echo "exec_prefix=\${prefix}"
    echo "libdir=$INSTX_LIBDIR"
    echo "sharedlibdir=\${libdir}"
    echo "includedir=\${prefix}/include"
    echo ""
    echo "Name: Termcap"
    echo "Description: Terminal capabilites library"
    echo 'URL: https://www.gnu.org/software/termutils'
    echo "Version: $TERMCAP_VER"
    echo ""
    echo "Requires:"
    echo "Libs: -L\${libdir} -ltermcap"
    echo "Cflags: -I\${includedir}"
} > termcap.pc

# Fix flags in *.pc files
cp -p ../fix-pc.sh .; ./fix-pc.sh

echo "**********************"
echo "Testing package"
echo "**********************"

#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Termcap"
#    exit 1
#fi

echo "Package not tested"

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "libdir=$INSTX_LIBDIR")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -kS "$MAKE" "${MAKE_FLAGS[@]}"

    printf "%s\n" "$SUDO_PASSWORD" | sudo -kS mkdir -p "$INSTX_LIBDIR/pkgconfig"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -kS cp termcap.pc "$INSTX_LIBDIR/pkgconfig"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -kS chmod 644 "$INSTX_LIBDIR/pkgconfig/termcap.pc"
else
    "$MAKE" "${MAKE_FLAGS[@]}"

    mkdir -p "$INSTX_LIBDIR/pkgconfig"
    cp termcap.pc "$INSTX_LIBDIR/pkgconfig"
    chmod 644 "$INSTX_LIBDIR/pkgconfig/termcap.pc"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$TERMCAP_TAR" "$TERMCAP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-termcap.sh 2>&1 | tee build-termcap.log
    if [[ -e build-termcap.log ]]; then
        rm -f build-termcap.log
    fi
fi

exit 0
