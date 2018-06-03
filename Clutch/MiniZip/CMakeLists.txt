cmake_minimum_required( VERSION 3.8 )

project( MiniZip LANGUAGES C )

set( HEADERS_FILES
        crypt.h
        ioapi.h
        unzip.h
        zip.h )

set( SOURCE_FILES
        ioapi.c
        unzip.c
        zip.c )
source_group( "" FILES ${HEADERS_FILES} ${SOURCE_FILES} )

add_library( MiniZip OBJECT ${HEADERS_FILES} ${SOURCE_FILES} )
target_compile_options( MiniZip
        PRIVATE
        -miphoneos-version-min=${MACOSX_DEPLOYMENT_TARGET} )

target_include_directories( MiniZip PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} )