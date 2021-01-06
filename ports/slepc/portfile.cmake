
set(SLEPC_VERSION 3.13.3)

vcpkg_from_gitlab(
    OUT_SOURCE_PATH SOURCE_PATH
    GITLAB_URL https://gitlab.com
    REPO slepc/slepc
    REF v${SLEPC_VERSION}
    SHA512 044dd75f6d96b8549e2a992290f610128dfe79c53f43b06ec28d9fccea1344bc3821ba5e20828f7c7a9e412256abbff9ae8e9e1be567218d7f0d99ffb578dad3
    PATCHES 
        vcpkg-install-workarounds.patch
        windows-disable-runlib.patch
)

# Setup host environment
if(CMAKE_HOST_WIN32)
    vcpkg_acquire_msys(MSYS_ROOT
        PACKAGES
            diffutils
            make

            # dependencies for python:
            libbz2
            #libexpat
            #libffi
            liblzma
            #libopenssl
            libreadline
            #libsqlite
            #mpdecimal
            ncurses
            zlib
        DIRECT_PACKAGES
            "https://repo.msys2.org/msys/x86_64/python-3.8.6-1-x86_64.pkg.tar.zst"
            cd9ddeeb8438d6c7246db68f867afb5ee8bcbe9816957477f17dd258060d9e96d6a946f00c6a15054d81ca41d0f1182d5ee9c12f991398d517018d5a4174ed65
    )
    set(BASH ${MSYS_ROOT}/usr/bin/bash.exe)
    set(CYGPATH ${MSYS_ROOT}/usr/bin/cygpath.exe)
    vcpkg_add_to_path("${MSYS_ROOT}/usr/bin")

    macro(to_msys_path PATH OUTPUT_VAR)
        execute_process(
            COMMAND ${CYGPATH} "${PATH}"
            OUTPUT_VARIABLE ${OUTPUT_VAR}
            ERROR_VARIABLE ${OUTPUT_VAR}
            RESULT_VARIABLE error_code
        )
        if(error_code)
            message(FATAL_ERROR "cygpath failed: ${${OUTPUT_VAR}}")
        endif()
        string(REGEX REPLACE "\n" "" ${OUTPUT_VAR} "${${OUTPUT_VAR}}")
    endmacro()

    to_msys_path("${CURRENT_PACKAGES_DIR}"            SLEPC_PACKAGES_DIR)
    to_msys_path("${SOURCE_PATH}"                     SLEPC_SOURCE_PATH)
    to_msys_path("${CURRENT_INSTALLED_DIR}"           SLEPC_INSTALLED_DIR)
else()
    set(BASH                "bash")
    set(SLEPC_PACKAGES_DIR  "${CURRENT_PACKAGES_DIR}")
    set(SLEPC_SOURCE_PATH   "${SOURCE_PATH}")
    set(SLEPC_INSTALLED_DIR "${CURRENT_INSTALLED_DIR}")
endif()

include(vcpkg_find_fortran)
vcpkg_find_fortran(FORTRAN_CMAKE)

# Generic options
set(OPTIONS
    "${SLEPC_SOURCE_PATH}/config/configure.py"
)
set(OPTIONS_RELEASE
    "--prefix=${SLEPC_PACKAGES_DIR}"
)

set(OPTIONS_DEBUG
    "--prefix=${SLEPC_PACKAGES_DIR}/debug"
)

if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
    message(STATUS "Building slepc for Release")
    file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel)
    set(ENV{PETSC_DIR} "${SLEPC_INSTALLED_DIR}")
    vcpkg_execute_required_process(
        COMMAND ${BASH} --noprofile --norc "${CMAKE_CURRENT_LIST_DIR}/build.sh"
            "${SLEPC_SOURCE_PATH}" # BUILD DIR : In source build
            "${SLEPC_INSTALLED_DIR}/bin"
            ${OPTIONS} ${OPTIONS_RELEASE}
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel
        LOGNAME build-${TARGET_TRIPLET}-rel
    )
endif()

if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    message(STATUS "Building slepc for Debug")
    file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg)
    set(ENV{PETSC_DIR} "${SLEPC_INSTALLED_DIR}/debug")
    vcpkg_execute_required_process(
        COMMAND ${BASH} --noprofile --norc "${CMAKE_CURRENT_LIST_DIR}/build.sh"
            "${SLEPC_SOURCE_PATH}" # BUILD DIR : In source build
            "${SLEPC_INSTALLED_DIR}/debug/bin"
            ${OPTIONS} ${OPTIONS_DEBUG}
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg
        LOGNAME build-${TARGET_TRIPLET}-dbg
    )
endif()

# Remove the generated executables
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/bin)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/bin)

if(VCPKG_TARGET_IS_WINDOWS)
    # Move the dlls to the bin folder
    if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/bin)
        file(RENAME ${CURRENT_PACKAGES_DIR}/lib/libslepc.dll ${CURRENT_PACKAGES_DIR}/bin/libslepc.dll)
        file(RENAME ${CURRENT_PACKAGES_DIR}/lib/libslepc.pdb ${CURRENT_PACKAGES_DIR}/bin/libslepc.pdb)
    endif()

    if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/debug/bin)
        file(RENAME ${CURRENT_PACKAGES_DIR}/debug/lib/libslepc.dll ${CURRENT_PACKAGES_DIR}/debug/bin/libslepc.dll)
        file(RENAME ${CURRENT_PACKAGES_DIR}/debug/lib/libslepc.pdb ${CURRENT_PACKAGES_DIR}/debug/bin/libslepc.pdb)
    endif()
endif()

# Remove other debug folders
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/share)

# Handle copyright
file(INSTALL ${SOURCE_PATH}/LICENSE.md DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
