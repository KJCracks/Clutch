# Building Clutch using CMake

In order to build Clutch and run it on a device you need to include the entitlements in the binary from the Clutch.entitlements file.

Apple's `codesign` tool can do the job, but Saurik's [ldid][1] tool does the job without needing to sign too. Which means to quickly build a functioning Clutch, you'll need to build or acquire ldid.

## Building ldid

    ./build-ldid.sh
    ./build-iphoneos.sh
    ./add-entitlements.sh

The result should be a fully functioning Clutch in the `bin` directory

[1]: http://git.saurik.com/ldid.git
