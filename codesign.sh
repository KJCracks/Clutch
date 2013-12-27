#!/bin/bash
strip "$1"
codesign -f -s "iPhone Developer" --entitlements Resources/Clutch.entitlements "$1"
scp "$1" "$SSH_LOCATION":~/
