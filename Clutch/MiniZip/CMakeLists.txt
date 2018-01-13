cmake_minimum_required( VERSION 3.9 )

project( MiniZip LANGUAGES C )

set( HEADERS
        crypt.h
        ioapi.h
        unzip.h
        zip.h )

set( SOURCE
        ioapi.c
        unzip.c
        zip.c )

add_library( MiniZip OBJECT ${SOURCE} )
target_include_directories( MiniZip PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} )
