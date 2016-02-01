if(UNIX)
    exec_program(gcc ARGS -dumpversion OUTPUT_VARIABLE CC_VERSION)
    string(SUBSTRING ${CC_VERSION} 0 3 CC_VERSION)
endif()

if(DEFINED ENV{APPVEYOR})
    set(CI_NAME "Appveyor CI")
    string(SUBSTRING "$ENV{APPVEYOR_REPO_COMMIT}" 0 8 CI_COMMIT_ID)
    set(CI_BUILD_NAME "${CI_COMMIT_ID}-msvc-14.0-($ENV{APPVEYOR_BUILD_NUMBER})")
    set(CI_BUILD_DIR "$ENV{APPVEYOR_BUILD_FOLDER}")
elseif(DEFINED ENV{CIRCLECI})
    set(CI_NAME "Circle CI")
    string(SUBSTRING "$ENV{CIRCLE_SHA1}" 0 8 CI_COMMIT_ID)
    set(CI_BUILD_NAME "${CI_COMMIT_ID}-gcc-${CC_VERSION}-($ENV{CIRCLE_BUILD_NUM})")
    set(CI_BUILD_DIR "$ENV{HOME}/libKD")
elseif(DEFINED ENV{GITLAB_CI})
    set(CI_NAME "GitLab CI")
    string(SUBSTRING "$ENV{CI_BUILD_REF}" 0 8 CI_COMMIT_ID)
    set(CI_BUILD_NAME "${CI_COMMIT_ID}-gcc-${CC_VERSION}-($ENV{CI_BUILD_ID})")
    set(CI_BUILD_DIR "$ENV{CI_PROJECT_DIR}")
elseif(DEFINED ENV{MAGNUM})
    set(CI_NAME "Magnum CI")
    string(SUBSTRING "$ENV{CI_COMMIT}" 0 8 CI_COMMIT_ID)
    set(CI_BUILD_NAME "${CI_COMMIT_ID}-gcc-${CC_VERSION}-($ENV{CI_BUILD_NUMBER})")
    set(CI_BUILD_DIR "$ENV{HOME}/libKD")
elseif(DEFINED ENV{SHIPPABLE})
    set(CI_NAME "Shippable CI")
    string(SUBSTRING "$ENV{COMMIT}" 0 8 CI_COMMIT_ID)
    set(CI_BUILD_NAME "${CI_COMMIT_ID}-gcc-${CC_VERSION}-($ENV{BUILD_NUMBER})")
    set(CI_BUILD_DIR "$ENV{HOME}/workspace/src/github.com/h-s-c/libKD")
elseif(DEFINED ENV{TRAVIS})
    set(CI_NAME "Travis CI")
    string(SUBSTRING "$ENV{TRAVIS_COMMIT}" 0 8 CI_COMMIT_ID)
    set(CI_BUILD_NAME "${CI_COMMIT_ID}-$ENV{CC}-($ENV{TRAVIS_BUILD_NUMBER})")
    set(CI_BUILD_DIR "$ENV{TRAVIS_BUILD_DIR}")
elseif(DEFINED ENV{WERCKER_ROOT})
    set(CI_NAME "Wercker CI")
    string(SUBSTRING "$ENV{WERCKER_GIT_COMMIT}" 0 8 CI_COMMIT_ID)
    set(CI_BUILD_NAME "${CI_COMMIT_ID}-$ENV{CC}-($ENV{GENERATED_BUILD_NR})")
    set(CI_BUILD_DIR "$ENV{WERCKER_ROOT}")
endif()

set(CTEST_SITE ${CI_NAME})
set(CTEST_BUILD_NAME ${CI_BUILD_NAME})

set(CTEST_SOURCE_DIRECTORY ${CI_BUILD_DIR})
set(CTEST_BINARY_DIRECTORY "${CTEST_SOURCE_DIRECTORY}/build")

set(CTEST_BUILD_CONFIGURATION "$ENV{CMAKE_BUILD_TYPE}")
set(CTEST_CONFIGURATION_TYPE "Debug")

if(UNIX)
    set(CTEST_CMAKE_GENERATOR "Unix Makefiles")

    find_program(CTEST_MEMORYCHECK_COMMAND NAMES valgrind)
    set(CTEST_MEMORYCHECK_TYPE "Valgrind")
    set(CTEST_MEMORYCHECK_COMMAND_OPTIONS "--track-origins=yes --leak-check=yes")

    if(DEFINED ENV{SHIPPABLE})
        set(CTEST_COVERAGE_COMMAND "gcov")
    elseif(DEFINED ENV{TRAVIS})
        string(SUBSTRING "$ENV{CC}" 0 3 CC)
        if(CC STREQUAL "gcc")
            string(SUBSTRING "$ENV{CC}" 4 -1 CC_VERSION)
            find_program(CTEST_COVERAGE_COMMAND NAMES gcov-${CC_VERSION})
        endif()
        string(SUBSTRING "$ENV{CC}" 0 5 CC)
        if(CC STREQUAL "clang")
            find_program(CTEST_COVERAGE_COMMAND NAMES llvm-cov-3.6)
        endif()
    else()
        set(CTEST_COVERAGE_COMMAND "gcov")
    endif()
    set(CTEST_CUSTOM_COVERAGE_EXCLUDE ${CTEST_CUSTOM_COVERAGE_EXCLUDE} "/distribution/" "/examples/" "/thirdparty/" "/tests/" "/cov-int/" "/CMakeFiles/" "/usr/")
    set(CTEST_COVERAGE_EXTRA_FLAGS "${CTEST_COVERAGE_EXTRA_FLAGS} -l -p")
else()
    set(CTEST_CMAKE_GENERATOR "Visual Studio 14 2015 Win64")
endif()

ctest_start(Continuous)
ctest_configure()
ctest_build()
ctest_test()
if(CTEST_MEMORYCHECK_COMMAND)
    ctest_memcheck()
endif()
if(CTEST_COVERAGE_COMMAND)
    ctest_coverage()
endif()
ctest_submit()
