#!/bin/sh

#  move_and_sign.sh
#  Clutch
#
#  Created by dev on 10/01/2017.
#

if [ ! -d build ]; then
    mkdir "build"
fi

cp "$BUILT_PRODUCTS_DIR/$EXECUTABLE_PATH" "build/"

codesign -fs- --entitlements "$CODE_SIGN_ENTITLEMENTS" "build/$EXECUTABLE_NAME"
