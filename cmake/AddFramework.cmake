macro(AddFramework TARGET NAME)
  find_library(FRAMEWORK_${NAME}
               NAMES ${NAME}
               PATHS ${CMAKE_OSX_SYSROOT}/System/Library
               PATH_SUFFIXES Frameworks CMAKE_FIND_FRAMEWORK only
               NO_DEFAULT_PATH)
  if(${FRAMEWORK_${NAME}} STREQUAL FRAMEWORK_${NAME}-NOTFOUND)
    message(ERROR ": Framework ${NAME} not found")
  else()
    target_link_libraries(${TARGET} ${FRAMEWORK_${NAME}})
    message(STATUS "Framework ${NAME} found at ${FRAMEWORK_${NAME}}")
  endif()
endmacro(AddFramework)
