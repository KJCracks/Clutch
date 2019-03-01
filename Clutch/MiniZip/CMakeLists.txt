cmake_minimum_required(VERSION 3.8)

project(MiniZip LANGUAGES C)

set(HEADERS_FILES crypt.h ioapi.h unzip.h zip.h)

set(SOURCE_FILES ioapi.c unzip.c zip.c)
source_group("" FILES ${HEADERS_FILES} ${SOURCE_FILES})

add_library(MiniZip OBJECT ${HEADERS_FILES} ${SOURCE_FILES})
target_include_directories(MiniZip PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

if(CMAKE_GENERATOR STREQUAL Xcode)
  set_target_properties(MiniZip
                        PROPERTIES XCODE_ATTRIBUTE_SDKROOT
                                   iphoneos
                                   XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET
                                   ${DEPLOYMENT_TARGET}
                                   XCODE_ATTIRBUTE_ENABLE_BITCODE
                                   YES
                                   XCODE_ATTIRBUTE_SKIP_INSTALL
                                   YES
                                   XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT
                                   dwarf-with-dsym
                                   XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY
                                   ${DEVICE_FAMILY}
                                   XCODE_ATTRIBUTE_INSTALL_PATH
                                   "$(LOCAL_APPS_DIR)"
                                   XCODE_ATTRIBUTE_ENABLE_TESTABILITY
                                   YES
                                   XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN
                                   YES)
else()
  target_compile_options(MiniZip
                         PRIVATE -miphoneos-version-min=${DEPLOYMENT_TARGET})
endif()
