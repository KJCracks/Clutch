#!/bin/bash

BUILD_DIR="build/ldid/"
INSTALL_DIR="ldid/"
DIR=$( pwd )

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
git clone https://github.com/palmerc/ldid "${BUILD_DIR}"
pushd "${BUILD_DIR}"
git submodule update --init

LDID_BUILD="build"
mkdir -p "${LDID_BUILD}"
pushd "${LDID_BUILD}"
cmake -DCMAKE_INSTALL_PREFIX="${DIR}/${INSTALL_DIR}" ..
cmake --build . --target install
popd

popd
