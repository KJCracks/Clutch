#!/bin/bash
# Clutch xcodebuild script
# Credits to Tatsh

# Default Xcode
if [ -z "$BUILD" ]; then
    BUILD=$(which xcodebuild)
    SDK='iphoneos8.1'
fi

$BUILD clean install

$BUILD ARCHS='armv7 armv7s arm64' ONLY_ACTIVE_ARCH=NO -sdk "$SDK" -configuration Release -alltargets clean

# Uncomment to enable CLUTCH_DEBUG and DEV with release
$BUILD ARCHS='armv7 armv7s arm64' ONLY_ACTIVE_ARCH=NO -sdk "$SDK" -configuration Release -alltargets CLUTCH_DEV=1

#$BUILD ARCHS='armv7 armv7s arm64' ONLY_ACTIVE_ARCH=NO -sdk "$SDK" -configuration Release -alltargets CLUTCH_DEV=0 # equivalent to next line where CLUTCH_DEV is not set


strip "build/Release-iphoneos/Clutch.app/Clutch"
codesign -f -s "iPhone Developer" --entitlements Resources/Clutch.entitlements "build/Release-iphoneos/Clutch.app/Clutch"
