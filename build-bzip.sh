#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bzip2 from sources.

# shellcheck disable=SC2191

# Bzip lost its website. It is now located on Sourceware.

BZIP2_TAR=bzip2-1.0.8.tar.gz
BZIP2_DIR=bzip2-1.0.8
BZIP2_VER=1.0.8
PKG_NAME=bzip2

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

# Needed to unpack the new Makefiles
if [[ -z $(command -v unzip 2>/dev/null) ]]; then
    echo ""
    echo "Please install unzip command."
    exit 1
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
echo "********** Bzip **********"
echo

if ! "$WGET" -O "$BZIP2_TAR" \
     "ftp://sourceware.org/pub/bzip2/$BZIP2_TAR"
then
    echo "Failed to download Bzip"
    exit 1
fi

rm -rf "$BZIP2_DIR" &>/dev/null
gzip -d < "$BZIP2_TAR" | tar xf -
cd "$BZIP2_DIR" || exit 1

# The Makefiles needed so much work it was easier to rewrite them.
cp ../patch/bzip-makefiles.zip .
unzip -oq bzip-makefiles.zip

# Now, patch them for this script.
if [[ -e ../patch/bzip.patch ]]; then
    cp ../patch/bzip.patch .
    patch -u -p0 < bzip.patch
    echo ""
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-f" "Makefile" "-j" "$INSTX_JOBS"
            CC="${CC}" CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip archive"
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
    echo "Name: Bzip2"
    echo "Description: Bzip2 compression library"
    echo "Version: $BZIP2_VER"
    echo ""
    echo "Requires:"
    echo "Libs: -L\${libdir} -lbz2"
    echo "Cflags: -I\${includedir}"
} > libbz2.pc

# Fix flags in *.pc files
cp -p ../fix-pc.sh .; ./fix-pc.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("-f" "Makefile" "check" "-j" "$INSTX_JOBS"
            CC="${CC}" CPPFLAGS="${BUILD_CPPFLAGS[*]}"
            CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Bzip"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Bzip"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

if [[ -n "$SUDO_PASSWORD" ]]
then
    echo "Installing static archive..."
    MAKE_FLAGS=("-f" "Makefile" install PREFIX="$INSTX_PREFIX")
    echo "$SUDO_PASSWORD" | sudo -kS "$MAKE" "${MAKE_FLAGS[@]}"

    echo "Installing pkgconfig file..."
    echo "$SUDO_PASSWORD" | sudo -kS mkdir -p "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -kS cp libbz2.pc "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -kS chmod 644 "$INSTX_LIBDIR/pkgconfig/libbz2.pc"
else
    echo "Installing static archive..."
    MAKE_FLAGS=("-f" "Makefile" install PREFIX="$INSTX_PREFIX")
    "$MAKE" "${MAKE_FLAGS[@]}"

    echo "Installing pkgconfig file..."
    mkdir -p "$INSTX_LIBDIR/pkgconfig"
    cp libbz2.pc "$INSTX_LIBDIR/pkgconfig"
    chmod 644 "$INSTX_LIBDIR/pkgconfig/libbz2.pc"
fi

# Clean old artifacts
"$MAKE" clean 2>/dev/null

###############################################################################

echo "**********************"
echo "Building package"
echo "**********************"

if [[ "$IS_DARWIN" -ne 0 ]]; then
    MAKEFILE=Makefile-libbz2_dylib
else
    MAKEFILE=Makefile-libbz2_so
fi

MAKE_FLAGS=("-f" "$MAKEFILE" "-j" "$INSTX_JOBS"
            CC="${CC}" CPPFLAGS="${BUILD_CPPFLAGS[*]}"
            CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip shared object"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

if [[ -n "$SUDO_PASSWORD" ]]
then
    echo "Installing shared object..."
    MAKE_FLAGS=("-f" "$MAKEFILE" install PREFIX="$INSTX_PREFIX")
    echo "$SUDO_PASSWORD" | sudo -kS "$MAKE" "${MAKE_FLAGS[@]}"

    echo "Installing pkgconfig file..."
    echo "$SUDO_PASSWORD" | sudo -kS mkdir -p "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -kS cp libbz2.pc "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -kS chmod 644 "$INSTX_LIBDIR/pkgconfig/libbz2.pc"
else
    echo "Installing shared object..."
    MAKE_FLAGS=("-f" "$MAKEFILE" install PREFIX="$INSTX_PREFIX")
    "$MAKE" "${MAKE_FLAGS[@]}"

    echo "Installing pkgconfig file..."
    mkdir -p "$INSTX_LIBDIR/pkgconfig"
    cp libbz2.pc "$INSTX_LIBDIR/pkgconfig"
    chmod 644 "$INSTX_LIBDIR/pkgconfig/libbz2.pc"
fi

###############################################################################

cd "$CURR_DIR" || exit 1

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

    ARTIFACTS=("$BZIP2_TAR" "$BZIP2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-bzip.sh 2>&1 | tee build-bzip.log
    if [[ -e build-bzip.log ]]; then
        rm -f build-bzip.log
    fi
fi

exit 0
