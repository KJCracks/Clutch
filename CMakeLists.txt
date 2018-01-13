cmake_minimum_required( VERSION 3.9 )

project( Clutch )

set( EXECUTABLE_NAME Clutch )
set( MACOSX_BUNDLE_GUI_IDENTIFIER kjc.Clutch )
set( MACOSX_BUNDLE_SHORT_VERSION_STRING "2.0.4" )
set( MACOSX_BUNDLE_BUNDLE_VERSION "1" )
set( DEPLOYMENT_TARGET "9.0" )
set( DEVICE_FAMILY "1,2" )

if( NOT CMAKE_BUILD_TYPE )
    set( CMAKE_BUILD_TYPE Release )
endif( NOT CMAKE_BUILD_TYPE )

if( CMAKE_BUILD_TYPE STREQUAL Debug )
    add_definitions( -DDEBUG )
endif()

include_directories( ${CMAKE_CURRENT_SOURCE_DIR} )
add_subdirectory( Clutch )