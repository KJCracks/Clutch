#!/bin/bash
# Clutch xcodebuild script
# Credits to Tatsh

xcodebuild clean install

xcodebuild ARCHS='armv7 armv7s arm64' ONLY_ACTIVE_ARCH=NO -sdk iphoneos7.0 -configuration Release -alltargets clean

# Uncomment to enable CLUTCH_DEBUG with release
# xcodebuild ONLY_ACTIVE_ARCH=NO -sdk iphoneos7.0 -configuration Release CLUTCH_DEBUG=1

xcodebuild ARCHS='armv7 armv7s arm64' ONLY_ACTIVE_ARCH=NO -sdk iphoneos7.0 -configuration Release -alltargets CLUTCH_DEBUG=0 # equivalent to next line where CLUTCH_DEBUG is not set

strip "build/Release-iphoneos/Clutch.app/Clutch"
codesign -f -s "iPhone Developer" --entitlements Resources/Clutch.entitlements "build/Release-iphoneos/Clutch.app/Clutch"
