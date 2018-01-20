#!/bin/bash

BUILD_DIR="build/"
TOOLCHAIN_FILE="cmake/iphoneos.toolchain.cmake"

PROJECT_DIR=$( pwd )
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
pushd "${BUILD_DIR}"

cmake \
    -GXcode \
    -DCMAKE_TOOLCHAIN_FILE="${PROJECT_DIR}/${TOOLCHAIN_FILE}" \
    -DCMAKE_BUILD_TYPE=Release \
    ..

popd
