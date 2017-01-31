#!/usr/bin/env bash

cd "$PROJECT_DIR"
! [ -d build ] && mkdir build
cp "$BUILT_PRODUCTS_DIR/$EXECUTABLE_PATH" "build/"
codesign -fs- --entitlements "$CODE_SIGN_ENTITLEMENTS" "build/$EXECUTABLE_NAME"
