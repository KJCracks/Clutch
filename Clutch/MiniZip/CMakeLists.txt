cmake_minimum_required( VERSION 3.8 )

project( MiniZip LANGUAGES C )

add_library( MiniZip STATIC "" )

target_sources( MiniZip
        PRIVATE
            unzip.h
            zip.h
            crypt.h
            ioapi.h
            ioapi.c
            unzip.c
            zip.c )

target_include_directories( MiniZip PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} )

install( TARGETS MiniZip
        ARCHIVE DESTINATION lib
        PUBLIC_HEADER DESTINATION include )

install( FILES ${HEADER_FILES}
        DESTINATION include )
