#!/usr/bin/env bash

cd "$PROJECT_DIR"
! [ -d build ] && mkdir build
cp "$BUILT_PRODUCTS_DIR/$EXECUTABLE_PATH" "build/"
codesign -fs- --entitlements 'Clutch/Clutch.entitlements' "build/$EXECUTABLE_NAME"
