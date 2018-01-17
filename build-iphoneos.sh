#!/bin/bash

BUILD_DIR="build/"
TOOLCHAIN_FILE="cmake/iphoneos.toolchain.cmake"

PROJECT_DIR=$( pwd )
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
pushd "${BUILD_DIR}"

cmake \
    -GNinja \
    -DCMAKE_INSTALL_PREFIX="${PROJECT_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="${PROJECT_DIR}/${TOOLCHAIN_FILE}" \
    ..
cmake --build . --target install

popd
