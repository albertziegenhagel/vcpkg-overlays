#!/usr/bin/bash
set -e

PATH_TO_BUILD_DIR="$1"
shift
VCPKG_INSTALL_BIN_DIR="$1"
shift

export PATH=$VCPKG_INSTALL_BIN_DIR:$PATH

echo "LINK:"
echo `which link`

cd "$PATH_TO_BUILD_DIR"
echo "=== CONFIGURING ==="
echo "executing: python3 $@"
python3 "$@"
echo "=== BUILDING ==="
make V=1
echo "=== INSTALLING ==="
make install
