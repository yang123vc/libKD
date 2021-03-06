###############################################################################
# libKD
# zlib/libpng License
###############################################################################
# Copyright (c) 2014-2016 Kevin Schmidt
#
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
###############################################################################

###############################################################################
# CMake toolchain file notes:
#
# Android:  https://github.com/taka-no-me/android-cmake
#           or try NVIDIA Nsight Tegra Visual Studio Edition
# Emscripten: $EMSCRIPTEN/cmake/Modules/Platform/Emscripten.cmake
###############################################################################

cmake_minimum_required(VERSION 3.1)
cmake_policy(SET CMP0025 NEW)
cmake_policy(SET CMP0054 NEW)

include(CheckIncludeFiles)
include(CheckLibraryExists)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})

set(KD_BUILD_EXAMPLES "On" CACHE BOOL "Build with examples")
set(KD_BUILD_TESTS "On" CACHE BOOL "Build with tests")
set(KD_BUILD_STDLIB "default" CACHE STRING "Build with libc (default/musl/none)")
set_property(CACHE KD_BUILD_STDLIB PROPERTY STRINGS "default" "musl" "none") 

# Nvidia Tegra Nsight doesnt set this
if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    set(ANDROID "On")
endif()

project (KD C)
    include(CPack)
    include(CTest)

    if(DEFINED ENV{CI})
        if(DEFINED CI_FLAGS)
            set(KD_CC_FLAGS "${CI_FLAGS}")
        endif()
    endif()

    if(MSVC)
        set(KD_CC_FLAGS "${KD_CC_FLAGS} /W4 /WX /wd4100 /wd4127")
    else()
        set(KD_CC_FLAGS "${KD_CC_FLAGS} -Wall -Wextra -Werror -Wshadow -pedantic -Wno-attributes -Wno-missing-field-initializers -Wno-unused-parameter")
        if(KD_BUILD_STDLIB MATCHES "musl")
            set(KD_CC_FLAGS "${KD_CC_FLAGS} -mmusl")
        elseif(KD_BUILD_STDLIB MATCHES "none")
            set(KD_CC_FLAGS "${KD_CC_FLAGS} -nostdlib -ffreestanding")
            # disable __chkstk_ms
            set(KD_CC_FLAGS "${KD_CC_FLAGS} -mno-stack-arg-probe")
            set(KD_FREESTANDING "On")
        endif()
        if(CTEST_CONFIGURATION_TYPE STREQUAL "Debug")
            set(KD_CC_FLAGS "${KD_CC_FLAGS} -fno-omit-frame-pointer")
        endif()
        if(EMSCRIPTEN)
            # -s USE_PTHREADS=1 -s PTHREAD_POOL_SIZE=20
            set(KD_CC_FLAGS "${KD_CC_FLAGS} -s FULL_ES2=1 -s EMTERPRETIFY=1 -s EMTERPRETIFY_ASYNC=1")
        endif()
        set(KD_LD_FLAGS "${KD_CC_FLAGS}")
    endif()

    list(APPEND KD_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/source/kd.c)
    list(APPEND KD_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/include)

    set(KD_WINDOW_SUPPORTED "On")
    if(ANDROID)
        set(KD_WINDOW_ANDROID "On")
    elseif(EMSCRIPTEN OR APPLE)
        set(KD_WINDOW_NULL "On")
    elseif(WIN32)
        set(KD_WINDOW_WIN32 "On")
    else()
        find_package(EGL)
        list(APPEND KD_INCLUDE_DIRS ${EGL_INCLUDE_DIR})
        find_package(X11)
        if(X11_FOUND)
            set(KD_WINDOW_X11 "On")
            list(APPEND KD_LIBRARIES ${X11_LIBRARIES})
            list(APPEND KD_INCLUDE_DIRS ${X11_INCLUDE_DIR})
        else()
            set(KD_WINDOW_SUPPORTED "Off")
        endif()
    endif()

    if(NOT KD_BUILD_STDLIB MATCHES "none")
        find_package(Threads)
        list(APPEND KD_LIBRARIES ${CMAKE_THREAD_LIBS_INIT})
        list(APPEND KD_LIBRARIES ${CMAKE_DL_LIBS})
        if(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
            list(APPEND KD_LIBRARIES stdthreads)
        endif()
    endif()

    if(ANDROID)
        list(APPEND KD_LIBRARIES android)
        list(APPEND KD_LIBRARIES log)
    endif()

    list(APPEND KD_INCLUDE_DIRS ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/include/KD)
    configure_file(${CMAKE_SOURCE_DIR}/include/KD/kdplatform.h.in ${CMAKE_BINARY_DIR}/include/KD/kdplatform.h)
    include_directories(${KD_INCLUDE_DIRS})

    if(WIN32)
        add_definitions(-D_WIN32_WINNT=0x0600)
    endif()
    if(EMSCRIPTEN OR MINGW OR ANDROID OR KD_FREESTANDING)
        add_library(KD STATIC ${KD_SOURCE})
    else()
        add_library(KD SHARED ${KD_SOURCE})
    endif()
    add_definitions(-DKD_EXPORTS)
    target_link_libraries(KD ${KD_LIBRARIES})
    set_target_properties(KD PROPERTIES C_STANDARD 11 C_EXTENSIONS "OFF")
    set_target_properties(KD PROPERTIES POSITION_INDEPENDENT_CODE "True")
    set_target_properties(KD PROPERTIES COMPILE_FLAGS "${KD_CC_FLAGS}" LINK_FLAGS "${KD_LD_FLAGS}")
    if(EMSCRIPTEN)
        set_target_properties(KD PROPERTIES SUFFIX ".bc")
    endif()
    find_program(CLANG_TIDY NAMES clang-tidy)
    if(CLANG_TIDY AND CMAKE_MAJOR_VERSION GREATER 2 AND CMAKE_MINOR_VERSION GREATER 5)
        set_target_properties(KD PROPERTIES C_CLANG_TIDY ${CLANG_TIDY})
    endif()

    install(TARGETS KD DESTINATION lib)
    file(GLOB KD_HEADERS "${CMAKE_SOURCE_DIR}/include/KD/*.h")
    install(FILES ${KD_HEADERS} ${CMAKE_BINARY_DIR}/include/KD/kdplatform.h  DESTINATION include/KD)

    # Tests
    if(KD_BUILD_TESTS)
        function(test_helper TEST_NAME)
            add_executable(${TEST_NAME} ${CMAKE_SOURCE_DIR}/test/${TEST_NAME}.c)
            target_link_libraries(${TEST_NAME} KD)
            set_target_properties(${TEST_NAME} PROPERTIES C_STANDARD 11 C_EXTENSIONS "OFF")
            set_target_properties(${TEST_NAME} PROPERTIES POSITION_INDEPENDENT_CODE "True")
            set_target_properties(${TEST_NAME} PROPERTIES COMPILE_FLAGS "${KD_CC_FLAGS}" LINK_FLAGS "${KD_LD_FLAGS}")
            if(MSVC)
                set_target_properties(${TEST_NAME} PROPERTIES COMPILE_FLAGS "${KD_CC_FLAGS} /wd4718" LINK_FLAGS "/EXPORT:kdMain")
            elseif(MINGW)
                set_target_properties(${TEST_NAME} PROPERTIES LINK_FLAGS "${KD_LD_FLAGS} -Wl,--export-all-symbols")
            elseif(EMSCRIPTEN)
                set_target_properties(${TEST_NAME} PROPERTIES SUFFIX ".html" LINK_FLAGS "${KD_LD_FLAGS} --emrun")
            elseif(CMAKE_C_COMPILER_ID STREQUAL "TinyCC")
                set_target_properties(${TEST_NAME} PROPERTIES LINK_FLAGS "-rdynamic")
            endif()
            add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
            if(CMAKE_C_COMPILER_ID STREQUAL "TinyCC")
                set_tests_properties(${TEST_NAME} PROPERTIES ENVIRONMENT "LD_LIBRARY_PATH=.")
            endif()
        endfunction()
        file(GLOB TESTS test/*.c)
        foreach(TEST ${TESTS})
            get_filename_component(TEST ${TEST} NAME)
            string(REGEX REPLACE "\\.[^.]*$" "" TEST ${TEST})
            test_helper(${TEST})
        endforeach()
    endif()

    # Examples
    if(NOT DEFINED ENV{CI} AND KD_BUILD_EXAMPLES)
        find_package(EGL REQUIRED)
        find_package(GLES2 REQUIRED)
        function(example_helper EXAMPLE_NAME)
            include_directories(${EGL_INCLUDE_DIR} ${GLES2_INCLUDE_DIR})
            add_executable(${EXAMPLE_NAME} ${CMAKE_SOURCE_DIR}/example/${EXAMPLE_NAME}.c)
            target_link_libraries(${EXAMPLE_NAME} KD ${EGL_LIBRARY} ${GLES2_LIBRARY})
            set_target_properties(${EXAMPLE_NAME} PROPERTIES C_STANDARD 11 C_EXTENSIONS "OFF")
            set_target_properties(${EXAMPLE_NAME} PROPERTIES POSITION_INDEPENDENT_CODE "True")
            set_target_properties(${EXAMPLE_NAME} PROPERTIES COMPILE_FLAGS "${KD_CC_FLAGS}" LINK_FLAGS "${KD_LD_FLAGS}")
            if(MSVC)
                set_target_properties(${EXAMPLE_NAME} PROPERTIES LINK_FLAGS "/EXPORT:kdMain")
            elseif(MINGW)
                set_target_properties(${EXAMPLE_NAME} PROPERTIES LINK_FLAGS "${KD_LD_FLAGS} -Wl,--export-all-symbols")
            elseif(EMSCRIPTEN)
                set_target_properties(${EXAMPLE_NAME} PROPERTIES SUFFIX ".html" LINK_FLAGS "${KD_LD_FLAGS} --emrun")
            elseif(CMAKE_C_COMPILER_ID STREQUAL "TinyCC")
                set_target_properties(${EXAMPLE_NAME} PROPERTIES LINK_FLAGS "-rdynamic")
            endif()
        endfunction()
        file(GLOB EXAMPLES example/*.c)
        foreach(EXAMPLE ${EXAMPLES})
            get_filename_component(EXAMPLE ${EXAMPLE} NAME)
            string(REGEX REPLACE "\\.[^.]*$" "" EXAMPLE ${EXAMPLE})
            example_helper(${EXAMPLE})
        endforeach()
    endif()
