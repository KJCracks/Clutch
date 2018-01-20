#!/bin/bash

LDID="ldid/bin/ldid"
CODESIGN=$( xcrun --sdk iphoneos --find codesign )
CLUTCH_ENTITLEMENTS="Clutch/Clutch.entitlements"
CLUTCH_BINARY="bin/Clutch"

PROJECT_DIR=$( pwd )

echo
echo "#### Setting the entitlements using ldid"
COMMAND_SET="${PROJECT_DIR}/${LDID} -S${PROJECT_DIR}/${CLUTCH_ENTITLEMENTS} ${PROJECT_DIR}/${CLUTCH_BINARY}"
echo "${COMMAND_SET}"
eval "${COMMAND_SET}"

echo
echo "#### Dumping the entitlements using codesign"
COMMAND_CHK="${CODESIGN} -d --entitlements :- ${PROJECT_DIR}/${CLUTCH_BINARY}"
echo "${COMMAND_CHK}"
eval "${COMMAND_CHK}"
