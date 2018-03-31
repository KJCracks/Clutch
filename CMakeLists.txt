cmake_minimum_required( VERSION 3.8 )

project( Clutch )

set( PRODUCT_NAME Clutch )
set( EXECUTABLE_NAME Clutch )
set( MACOSX_BUNDLE_GUI_IDENTIFIER kjc.Clutch )

set( PRECOMPILED_HEADER ${CMAKE_CURRENT_SOURCE_DIR}/Clutch/Clutch-Prefix.pch )

# Find version string in Clutch-Prefix.pch
file( STRINGS ${PRECOMPILED_HEADER} VERSION_LINE REGEX "#define CLUTCH_VERSION_" )
string( LENGTH ${VERSION_LINE} VERSION_LINE_LENGTH)
# remove beginning of #define CLUTCH_VERSION_ @" and 1 for the end "
math( EXPR VERSION_LINE_LENGTH "${VERSION_LINE_LENGTH}-27")
string( SUBSTRING ${VERSION_LINE} 26 ${VERSION_LINE_LENGTH} CLUTCH_VERSION)

set( MACOSX_BUNDLE_SHORT_VERSION_STRING "${CLUTCH_VERSION}" )
set( MACOSX_BUNDLE_BUNDLE_VERSION "1" )
set( MACOSX_DEPLOYMENT_TARGET 9.0 )
set( DEVICE_FAMILY "1,2" )
set( CODE_SIGN_IDENTITY "" )


# set default release type
if( NOT CMAKE_BUILD_TYPE )
    set( CMAKE_BUILD_TYPE Release )
endif( NOT CMAKE_BUILD_TYPE )

# 
if( CMAKE_BUILD_TYPE STREQUAL Debug )
    add_definitions( -DDEBUG )
endif()

string( TOLOWER ${CMAKE_GENERATOR} GENERATOR )
if( GENERATOR STREQUAL xcode )
    add_executable( Clutch MACOSX_BUNDLE "" )
else()
    add_executable( Clutch "" )
endif()

add_subdirectory( Clutch/MiniZip MiniZip EXCLUDE_FROM_ALL )

target_sources( Clutch PRIVATE
    LSApplicationProxy.h 
)

target_include_directories( Clutch PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR} 
)

include( Clutch/CMakeLists.txt)

install( TARGETS Clutch
    RUNTIME DESTINATION bin
    BUNDLE DESTINATION bin 
)

add_definitions( -include ${PRECOMPILED_HEADER} )

set_target_properties( Clutch PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Clutch/Info.plist.in
    XCODE_ATTRIBUTE_ARCHS "$(ARCHS_STANDARD)"
    XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym"
    XCODE_ATTRIBUTE_GCC_PREFIX_HEADER "${PRECOMPILED_HEADER}"
    XCODE_ATTRIBUTE_GCC_PRECOMPILE_PREFIX_HEADER YES
    XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/Frameworks"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET ${MACOSX_DEPLOYMENT_TARGET}
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "${CODE_SIGN_IDENTITY}"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY ${DEVICE_FAMILY}
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
    XCODE_ATTRIBUTE_COMBINE_HIDPI_IMAGES NO
    XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
    XCODE_ATTRIBUTE_ENABLE_TESTABILITY YES
    XCODE_ATTRIBUTE_ENABLE_BITCODE NO
    XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN YES 
)

target_compile_options( Clutch PRIVATE
    -mios-version-min=${MACOSX_DEPLOYMENT_TARGET}
    -fmodules
    -fobjc-arc 
)

target_compile_options( MiniZip PRIVATE
    -mios-version-min=${MACOSX_DEPLOYMENT_TARGET} 
)

find_library( FOUNDATION Foundation )
find_library( UIKIT UIKit )
find_library( MOBILECORESERVICES MobileCoreServices )
find_library( LIBZ z )
find_library( NCURSES ncurses )

target_link_libraries( Clutch
        MiniZip
        ${LIBZ}
        ${NCURSES}
        ${FOUNDATION}
        ${UIKIT}
        ${MOBILECORESERVICES} 
)
