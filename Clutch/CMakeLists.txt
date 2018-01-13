set( PRECOMPILED_HEADER Clutch-Prefix.pch )

set( HEADERS
    ../LSApplicationProxy.h
    ARM64Dumper.h
    ARMDumper.h
    ASLRDisabler.h
    Application.h
    ApplicationsManager.h
    Binary.h
    BinaryDumpProtocol.h
    BundleDumpOperation.h
    ClutchBundle.h
    ClutchCommands.h
    ClutchPrint.h
    Device.h
    Dumper.h
    Extension.h
    FBApplicationInfo.h
    FinalizeDumpOperation.h
    Framework.h
    Framework64Dumper.h
    FrameworkDumper.h
    FrameworkLoader.h
    LSApplicationWorkspace.h
    NSBundle+Clutch.h
    NSData+Reading.h
    NSFileHandle+Private.h
    NSTask.h
    SCInfoBuilder.h
    ZipArchive.h
    ZipOperation.h
    mach_vm.h
    move_and_sign.sh
    optool-defines.h
    optool-headers.h
    optool-operations.h
    optool.h
    scinfo.h
    sha1.h )

set( SOURCE
    ARM64Dumper.m
    ARMDumper.m
    ASLRDisabler.m
    Application.m
    ApplicationsManager.m
    Binary.m
    BundleDumpOperation.m
    ClutchBundle.m
    ClutchCommands.m
    ClutchPrint.m
    Device.m
    Dumper.m
    Extension.m
    FinalizeDumpOperation.m
    Framework.m
    Framework64Dumper.m
    FrameworkDumper.m
    FrameworkLoader.m
    NSBundle+Clutch.m
    NSData+Reading.m
    NSFileHandle+Private.m
    SCInfoBuilder.m
    ZipArchive.m
    ZipOperation.m
    main.m
    optool-headers.m
    optool-operations.m
    scinfo.m
    sha1.c )

set( RESOURCES
    move_and_sign.sh
    Clutch.entitlements
    Info.plist
    Info.plist.in )

configure_file( Clutch.entitlements Clutch.entitlements COPYONLY )
configure_file( Info.plist.in Info.plist COPYONLY )

add_subdirectory( MiniZip )


find_library( FOUNDATION Foundation )
find_library( UIKIT UIKit )
find_library( MOBILECORESERVICES MobileCoreServices )

add_executable( Clutch ${SOURCE} $<TARGET_OBJECTS:MiniZip> )
target_link_libraries( Clutch
        PRIVATE
            ${FOUNDATION}
            ${UIKIT}
            ${MOBILECORESERVICES} )
target_include_directories( Clutch PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} )
target_compile_options( Clutch PRIVATE -include ${PRECOMPILED_HEADER} )

install( TARGETS Clutch
        RUNTIME DESTINATION bin )

set_target_properties( Clutch
        PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Clutch/Info.plist.in
        XCODE_ATTRIBUTE_ARCHS "$(ARCHS_STANDARD)"
        XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym"
        XCODE_ATTRIBUTE_GCC_PREFIX_HEADER "${PRECOMPILED_HEADER}"
        XCODE_ATTRIBUTE_GCC_PRECOMPILE_PREFIX_HEADER YES
        XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks"
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET ${DEPLOYMENT_TARGET}
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY ${DEVICE_FAMILY}
        XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
        XCODE_ATTRIBUTE_COMBINE_HIDPI_IMAGES NO
        XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
        XCODE_ATTRIBUTE_ENABLE_TESTABILITY YES
        XCODE_ATTRIBUTE_ENABLE_BITCODE NO
        XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN YES )

target_compile_options( Clutch
        PRIVATE
        -mios-version-min=9.0
        -fmodules
        -fobjc-arc )