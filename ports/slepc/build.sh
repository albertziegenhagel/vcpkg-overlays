#!/usr/bin/bash
set -e

PATH_TO_BUILD_DIR="$1"
shift
VCPKG_INSTALL_BIN_DIR="$1"
shift

export PATH=$VCPKG_INSTALL_BIN_DIR:$PATH

echo "PETSC_DIR: $PETSC_DIR"

cd "$PATH_TO_BUILD_DIR"
echo "=== CONFIGURING ==="
echo "executing: python3 $@"
python3 "$@"
echo "=== BUILDING ==="
make V=1 SLEPC_DIR="$PATH_TO_BUILD_DIR"
echo "=== INSTALLING ==="
make  SLEPC_DIR="$PATH_TO_BUILD_DIR" install
