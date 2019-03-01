cmake_minimum_required(VERSION 3.8)

project(Clutch)

set(PRODUCT_NAME Clutch)
set(EXECUTABLE_NAME Clutch)
set(PRODUCT_BUNDLE_IDENTIFIER kjc.Clutch)
set(MACOSX_BUNDLE_SHORT_VERSION_STRING "2.0.4")
set(MACOSX_BUNDLE_BUNDLE_VERSION "1")
set(DEVICE_FAMILY "1,2")
set(DEPLOYMENT_TARGET 8.0 CACHE STRING "")
set(CODE_SIGN_IDENTITY "iPhone Developer")

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif(NOT CMAKE_BUILD_TYPE)

if(CMAKE_BUILD_TYPE STREQUAL Debug)
  add_definitions(-DDEBUG)
endif()

include_directories(${CMAKE_CURRENT_SOURCE_DIR})

include(cmake/DebugUtils.cmake)
include(cmake/AddFramework.cmake)
add_subdirectory(Clutch)
