cmake_minimum_required(VERSION 3.8)

set(SOURCE_COMMANDS ClutchCommands.h ClutchCommands.m)
source_group("Commands" FILES ${SOURCE_COMMANDS})
list(APPEND SOURCE_FILES ${SOURCE_COMMANDS})

set(SOURCE_OPERATIONS
    ZipOperation.h
    ZipOperation.m
    BundleDumpOperation.h
    BundleDumpOperation.m
    FinalizeDumpOperation.h
    FinalizeDumpOperation.m)
source_group("Operations" FILES ${SOURCE_OPERATIONS})
list(APPEND SOURCE_FILES ${SOURCE_OPERATIONS})

set(SOURCE_DUMPERS
    ASLRDisabler.h
    ASLRDisabler.m
    ARMDumper.h
    ARMDumper.m
    ARM64Dumper.h
    ARM64Dumper.m
    FrameworkDumper.h
    FrameworkDumper.m
    Framework64Dumper.h
    Framework64Dumper.m
    FrameworkLoader.h
    FrameworkLoader.m)
source_group("Dumpers" FILES ${SOURCE_DUMPERS})
list(APPEND SOURCE_FILES ${SOURCE_DUMPERS})

set(SOURCE_PROTOCOL_PARENT_DUMPER BinaryDumpProtocol.h Dumper.h Dumper.m)
source_group("Dumpers\\Protocol + Parent Dumper" FILES
             ${SOURCE_PROTOCOL_PARENT_DUMPER})
list(APPEND SOURCE_FILES ${SOURCE_PROTOCOL_PARENT_DUMPER})

set(SOURCE_APPLICATION
    Application.h
    Application.m
    Extension.h
    Extension.m
    Framework.h
    Framework.m)
source_group("Application" FILES ${SOURCE_APPLICATION})
list(APPEND SOURCE_FILES ${SOURCE_APPLICATION})

set(SOURCE_CLUTCH_BUNDLE Binary.h Binary.m ClutchBundle.h ClutchBundle.m)
source_group("Application\\ClutchBundle" FILES ${SOURCE_CLUTCH_BUNDLE})
list(APPEND SOURCE_FILES ${SOURCE_CLUTCH_BUNDLE})

set(SOURCE_MAIN
    KJApplicationManager.h
    KJApplicationManager.m
    Device.h
    Device.m
    main.m
    ClutchPrint.h
    ClutchPrint.m)
source_group("" FILES ${SOURCE_MAIN})
list(APPEND SOURCE_FILES ${SOURCE_MAIN})

set(PRECOMPILED_HEADER ${CMAKE_CURRENT_SOURCE_DIR}/Clutch-Prefix.pch)
set(SOURCE_SUPPORTING_FILES
    ../LSApplicationProxy.h
    ${PRECOMPILED_HEADER}
    SCInfoBuilder.h
    SCInfoBuilder.m
    sha1.c
    sha1.h
    Clutch.entitlements
    mach_vm.h
    NSTask.h
    scinfo.h
    scinfo.m
    LSApplicationWorkspace.h
    FBApplicationInfo.h
    Info.plist
    NSFileHandle+Private.h
    NSFileHandle+Private.m
    NSBundle+Clutch.h
    NSBundle+Clutch.m)
source_group("Supporting Files" FILES ${SOURCE_SUPPORTING_FILES})
list(APPEND SOURCE_FILES ${SOURCE_SUPPORTING_FILES})

set(SOURCE_OPTOOL
    optool.h
    optool-defines.h
    optool-headers.h
    optool-headers.m
    optool-operations.h
    optool-operations.m
    NSData+Reading.h
    NSData+Reading.m)
source_group("Supporting Files\\optools" FILES ${SOURCE_OPTOOL})
list(APPEND SOURCE_FILES ${SOURCE_OPTOOL})

set(SOURCE_ZIP ZipArchive.h ZipArchive.m)
source_group("Supporting Files\\Zip" FILES ${SOURCE_ZIP})
list(APPEND SOURCE_FILES ${SOURCE_ZIP})

set(RESOURCE_SCRIPTS move_and_sign.sh)
source_group("scripts" FILES ${RESOURCE_SCRIPTS})
list(APPEND SOURCE_FILES ${RESOURCE_SCRIPTS})

configure_file(Clutch.entitlements Clutch.entitlements COPYONLY)
configure_file(Info.plist.in Info.plist COPYONLY)

add_subdirectory(MiniZip)

add_executable(Clutch MACOSX_BUNDLE ${SOURCE_FILES} $<TARGET_OBJECTS:MiniZip>)
addframework(Clutch Foundation)
addframework(Clutch UIKit)
addframework(Clutch MobileCoreServices)
target_include_directories(Clutch PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

if(CMAKE_GENERATOR STREQUAL Xcode)
  set_target_properties(
    Clutch
    PROPERTIES MACOSX_BUNDLE_INFO_PLIST
               "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
               XCODE_ATTRIBUTE_SDKROOT
               iphoneos
               XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER
               "${PRODUCT_BUNDLE_IDENTIFIER}"
               XCODE_ATTRIBUTE_CODE_SIGN_STYLE
               "Manual"
               XCODE_ATTRIBUTE_CODE_SIGN_INJECT_BASE_ENTITLEMENTS
               YES
               XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET
               ${DEPLOYMENT_TARGET}
               XCODE_ATTRIBUTE_ARCHS
               "$(ARCHS_STANDARD)"
               XCODE_ATTRIBUTE_ENABLE_BITCODE
               YES
               XCODE_ATTRIBUTE_SKIP_INSTALL
               YES
               XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES
               YES
               XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT
               dwarf-with-dsym
               XCODE_ATTRIBUTE_GCC_PREFIX_HEADER
               "${PRECOMPILED_HEADER}"
               XCODE_ATTRIBUTE_GCC_PRECOMPILE_PREFIX_HEADER
               YES
               XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY
               ${DEVICE_FAMILY}
               XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC
               YES
               XCODE_ATTRIBUTE_INSTALL_PATH
               "$(LOCAL_APPS_DIR)"
               XCODE_ATTRIBUTE_ENABLE_TESTABILITY
               YES
               XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN
               YES)
else()
  target_compile_options(Clutch
                         PRIVATE -include
                                 "${PRECOMPILED_HEADER}"
                                 -miphoneos-version-min=${DEPLOYMENT_TARGET}
                                 -fobjc-arc
                                 -fmodules)
endif()

add_custom_command(
  TARGET Clutch POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/build"
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:Clutch>
          "${CMAKE_BINARY_DIR}/build/"
  COMMAND codesign -fs-
          --entitlements "${CMAKE_CURRENT_BINARY_DIR}/Clutch.entitlements"
                         "${CMAKE_BINARY_DIR}/build/Clutch")
