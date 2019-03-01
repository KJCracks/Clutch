# Clutch

*Clutch* is a high-speed iOS decryption tool. Clutch supports the iPhone, iPod Touch, and iPad as well as all iOS version, architecture types, and most binaries. **Clutch is meant only for educational purposes and security research.**

Clutch requires a jailbroken iOS device with version 8.0 or greater.

# Usage

```
Clutch [OPTIONS]
-b --binary-dump     Only dump binary files from specified bundleID
-d --dump            Dump specified bundleID into .ipa file
-i --print-installed Print installed application
--clean              Clean /var/tmp/clutch directory
--version            Display version and exit
-? --help            Display this help and exit
```

Clutch may encounter `Segmentation Fault: 11` when dumping apps with a large number of frameworks. Increase your device's maximum number of open file descriptors with `ulimit -n 512` (default is 256).


# Building

## Requirements

* Xcode (install from [App Store](https://itunes.apple.com/us/app/xcode/id497799835?mt=12) or from [Apple's developer site](http://adcdownload.apple.com/Developer_Tools/Xcode_8.2.1/Xcode_8.2.1.xip))
* Xcode command line tools: `xcode-select --install` (or from [Apple's developer site](http://adcdownload.apple.com/Developer_Tools/Command_Line_Tools_macOS_10.12_for_Xcode_8.2/Command_Line_Tools_macOS_10.12_for_Xcode_8.2.dmg))

## Disable SDK code signing requirement

```sh
killall Xcode
cp /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/SDKSettings.plist ~/
sudo /usr/libexec/PlistBuddy -c "Set :DefaultProperties:CODE_SIGNING_REQUIRED NO" /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/SDKSettings.plist
sudo /usr/libexec/PlistBuddy -c "Set :DefaultProperties:AD_HOC_CODE_SIGNING_ALLOWED YES" /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/SDKSettings.plist
```

Note that if you update Xcode you may need to run these commands again.

## Compiling

### Xcode

```sh
xcodebuild clean build
```

### CMake

```sh
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=../cmake/iphoneos.toolchain.cmake ..
make -j$(sysctl -n hw.logicalcpu)
```

## Installation

After building, a copy of the binary named `Clutch` is placed in the build directory. Copy this to your device:

```sh
scp ./build/Clutch root@<your.device.ip>:/usr/bin/Clutch
```

If you are using [iproxy](http://iphonedevwiki.net/index.php/SSH_Over_USB), use this line (replace `2222` with a different port if necessary):

```sh
scp -P 2222 ./build/Clutch root@localhost:/usr/bin/Clutch
```

When you SSH into your device, run `Clutch`.

If you are using the [unc0ver jailbreak](https://www.theiphonewiki.com/wiki/Unc0ver), you may need to run the following:

```sh
inject /usr/bin/Clutch
```

# Licenses

Clutch uses the following libraries under their respective licenses.

* [optool](https://github.com/alexzielenski/optool) by Alex Zielenski
* [ZipArchive](https://github.com/mattconnolly/ZipArchive/) by Matt Connolly, Edward Patel, et al.
* [MiniZip](http://www.winimage.com/zLibDll/minizip.html) by Gilles Vollant and Mathias Svensson.

# Thanks

Clutch would not be what it is without these people:

* dissident - The original creator of Clutch (pre 1.2.6)
* Nighthawk - Code contributor (pre 1.2.6)
* Rastignac - Inspiration and genius
* TheSexyPenguin - Inspiration

# Contributors

* [iT0ny](https://github.com/iT0ny)
* [ttwj](https://github.com/ttwj)
* [NinjaLikesCheez](https://github.com/NinjaLikesCheez)
* [Tatsh](https://github.com/Tatsh)
* [C0deH4cker](https://github.com/C0deH4cker)
* [DoubleDoughnut](https://github.com/DoubleDoughnut)
* [iD70my](https://github.com/iD70my)
* [OdNairy](https://github.com/OdNairy)
* [palmerc](https://github.com/palmerc)
* [jack980517](https://github.com/jack980517)

# Copyright

© [Kim Jong-Cracks](http://cracksby.kim) 1819-2017
