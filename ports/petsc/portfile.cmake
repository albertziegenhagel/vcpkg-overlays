
set(PETSC_VERSION 3.13.4)

# Detect compilers
set(CMAKE_BINARY_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}")
set(CMAKE_CURRENT_BINARY_DIR "${CMAKE_BINARY_DIR}")
set(CMAKE_PLATFORM_INFO_DIR "${CMAKE_BINARY_DIR}/Platform")

include(CMakeDetermineCCompiler)
include(CMakeDetermineCXXCompiler)

if("fortran" IN_LIST FEATURES OR "scalapack" IN_LIST FEATURES OR "mumps" IN_LIST FEATURES)
    set(PETSC_REQUIRES_FORTRAN_COMPILER ON)
else()
    set(PETSC_REQUIRES_FORTRAN_COMPILER OFF)
endif()

if(PETSC_REQUIRES_FORTRAN_COMPILER)
    include(vcpkg_find_fortran)
    vcpkg_find_fortran(UNUSED)

    include(CMakeDetermineFortranCompiler)
endif()

# Collect additional patches required for enabled features
set(additional_patches)

if("hdf5" IN_LIST FEATURES AND VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    list(APPEND additional_patches
        use-dynamic-hdf5.patch
    )
endif()

if(PETSC_REQUIRES_FORTRAN_COMPILER AND CMAKE_HOST_WIN32 AND CMAKE_Fortran_COMPILER_ID STREQUAL Flang)
    # The PETSc config system appends 'Ws2_32.lib' as a general library to link to but does not handle
    # passing the library to Flang correctly.
    # Since 'Ws2_32.lib' is not required for the Fortran sources anyway, the following patch disables
    # adding that library for Fortran.
    list(APPEND additional_patches
        fix-fortran-flang-libraries.patch
    )
endif()

# Download and extract source code
vcpkg_download_distfile(ARCHIVE
    URLS "http://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-lite-${PETSC_VERSION}.tar.gz"
    FILENAME "petsc-lite-${PETSC_VERSION}.tar.gz"
    SHA512 ea61d23a894607d720807cc2606a3e772468a4ab67f07b9427211d187ddac15c55ec7f70e109b5eab08889f9b50b6ad27b9289a4e4e02dd9872b11f0730aff28
)

vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE ${ARCHIVE}
    PATCHES
        # Patch to support HYPRE 2.19.
        # Based on https://gitlab.com/petsc/petsc/-/commit/22235d61f064e7b802dd7c390aa6bd25310e0ce4
        support-hypre-2.19.patch

        # Patch to support SuperLU_Dist 6.3.1
        support-superludist-6.3.1.patch

        # Flang does not understand the DLLEXPORT attributes correctly, so we disable them for Flang
        # IMPORTANT: This will probably render the fortran bindings of PETSc useless.
        disable-dllexport-flang.patch

        # Mark Fortran imports of the iso_c_bindings as intrinsic (this is at least required to compile with Flang).
        fix-use-intrinsic-module.patch

        # Versions of packages are determined by PETSc by putting "PKG_VERSION_MAJOR.PKG_VERSION_MINOR.PKG_VERSION_PATCH" through a pre-processor,
        # but MSVC does pre-process those identifiers different than GNU.
        # This workaround inserts spaces between the versions so that MSVC generates desired results. The spaces are then ignored during the further
        # processing of the version string in PETScs configure system.
        fix-pkg-versionnames.patch

        # PETSc does not detect the compiler version of MSVC correctly which results in a multi line string
        # ending up as C_VERSION and CXX_VERSION in the 'petscvariables' file.
        fix-compiler-version-detection.patch

        # ...
        windows-disable-runlib.patch

        ${additional_patches}
)

# Setup host environment
if(CMAKE_HOST_WIN32)
    vcpkg_acquire_msys(MSYS_ROOT
        PACKAGES
            diffutils
            make
        DIRECT_PACKAGES
            "https://repo.msys2.org/msys/x86_64/python-3.8.6-1-x86_64.pkg.tar.zst"
            cd9ddeeb8438d6c7246db68f867afb5ee8bcbe9816957477f17dd258060d9e96d6a946f00c6a15054d81ca41d0f1182d5ee9c12f991398d517018d5a4174ed65
    )
    set(BASH ${MSYS_ROOT}/usr/bin/bash.exe)
    set(CYGPATH ${MSYS_ROOT}/usr/bin/cygpath.exe)
    # NOTE: do not PREPEND this path. Prepending would put link.exe from MSYS before
    #       the one from MSVC toolchain.
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

    to_msys_path("${CURRENT_PACKAGES_DIR}"            PETSC_PACKAGES_DIR)
    to_msys_path("${SOURCE_PATH}"                     PETSC_SOURCE_PATH)
    to_msys_path("${CURRENT_INSTALLED_DIR}"           PETSC_INSTALLED_DIR)
else()
    set(BASH                "bash")
    set(PETSC_PACKAGES_DIR  "${CURRENT_PACKAGES_DIR}")
    set(PETSC_SOURCE_PATH   "${SOURCE_PATH}")
    set(PETSC_INSTALLED_DIR "${CURRENT_INSTALLED_DIR}")
endif()

# Select compilers options
if(CMAKE_HOST_WIN32)
    # Select CRT flag
    if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
        set(RUNTIME_FLAG_NAME "MD")
    else()
        set(RUNTIME_FLAG_NAME "MT")
    endif()
endif()

if(PETSC_REQUIRES_FORTRAN_COMPILER)
    if(CMAKE_HOST_WIN32)
        if(CMAKE_Fortran_COMPILER_ID STREQUAL GNU)
            set(PETSC_Fortran_COMPILER "gfortran")
            set(FFLAGS_RELEASE         "-O3")
            set(FFLAGS_DEBUG           "-Og")
        elseif(CMAKE_Fortran_COMPILER_ID STREQUAL Flang)
            set(PETSC_Fortran_COMPILER "flang")
            set(FFLAGS_RELEASE         "-O3 -DNDEBUG -DWIN32 -D_WINDOWS")
            set(FFLAGS_DEBUG           "-Og -D_DEBUG")
        elseif(CMAKE_Fortran_COMPILER_ID STREQUAL Intel)
            set(PETSC_Fortran_COMPILER "win32fe ifort")
            set(FFLAGS_RELEASE         "-${RUNTIME_FLAG_NAME} -names:lowercase -assume:underscore -O3 -DNDEBUG -DWIN32 -D_WINDOWS")
            set(FFLAGS_DEBUG           "-${RUNTIME_FLAG_NAME}d -names:lowercase -assume:underscore -Od -D_DEBUG")
        else()
            message(FATAL_ERROR "Building PETSc with fortran compiler '${CMAKE_Fortran_COMPILER_ID}' is not yet supported.")
        endif()
    else()
        set(PETSC_Fortran_COMPILER "${CMAKE_Fortran_COMPILER}")
    endif()
else()
    set(PETSC_Fortran_COMPILER "0")
endif()

if(CMAKE_HOST_WIN32)
    if(CMAKE_C_COMPILER_ID STREQUAL MSVC)
        set(PETSC_C_COMPILER "win32fe cl")

        set(CFLAGS_RELEASE "-${RUNTIME_FLAG_NAME} -O2 -Oi -Gy -DNDEBUG -Z7 -DWIN32 -D_WINDOWS -W3 -utf-8 -MP")
        set(CPPFLAGS_RELEASE "-DNDEBUG -DWIN32 -D_WINDOWS")
        set(CFLAGS_DEBUG "-${RUNTIME_FLAG_NAME}d -D_DEBUG -Z7 -Ob0 -Od -RTC1")
        set(CPPFLAGS_DEBUG "-D_DEBUG")
    # elseif(CMAKE_C_COMPILER_ID STREQUAL Clang)
    #     if(CMAKE_C_SIMULATE_ID STREQUAL MSVC)
    #         set(PETSC_C_COMPILER "win32fe clang-cl")
    #     else()
    #         set(PETSC_C_COMPILER "clang")
    #     endif()
    elseif(CMAKE_C_COMPILER_ID STREQUAL GNU)
        set(PETSC_C_COMPILER "gcc")

        set(CFLAGS_RELEASE "-O3")
        set(CPPFLAGS_RELEASE "")
        set(CFLAGS_DEBUG "-Og")
        set(CPPFLAGS_DEBUG "")
    else()
        message(FATAL_ERROR "Building PETSc with C compiler '${CMAKE_C_COMPILER_ID}' is not yet supported.")
    endif()

    if(CMAKE_CXX_COMPILER_ID STREQUAL MSVC)
        set(PETSC_CXX_COMPILER "win32fe cl")

        set(CXXFLAGS_RELEASE "-${RUNTIME_FLAG_NAME} -O2 -Oi -Gy -DNDEBUG -Z7 -DWIN32 -D_WINDOWS -W3 -utf-8 -GR -EHsc -MP")
        set(CXXPPFLAGS_RELEASE "-DNDEBUG -DWIN32 -D_WINDOWS")
        set(CXXFLAGS_DEBUG "-${RUNTIME_FLAG_NAME}d -D_DEBUG -Z7 -Ob0 -Od -RTC1")
        set(CXXPPFLAGS_DEBUG "-D_DEBUG")
    # elseif(CMAKE_CXX_COMPILER_ID STREQUAL Clang)
    #     if(CMAKE_CXX_SIMULATE_ID STREQUAL MSVC)
    #         set(PETSC_CXX_COMPILER "win32fe clang-cl")
    #     else()
    #         set(PETSC_CXX_COMPILER "clang++")
    #     endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL GNU)
        set(PETSC_CXX_COMPILER "g++")

        set(CXXFLAGS_RELEASE "-O3")
        set(CXXPPFLAGS_RELEASE "")
        set(CXXFLAGS_DEBUG "-Og")
        set(CXXPPFLAGS_DEBUG "")
    else()
        message(FATAL_ERROR "Building PETSc with C++ compiler '${CMAKE_CXX_COMPILER_ID}' is not yet supported.")
    endif()
else()
    set(PETSC_C_COMPILER "${CMAKE_C_COMPILER}")
    set(PETSC_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
endif()

# Generic options
set(OPTIONS
    "${PETSC_SOURCE_PATH}/config/configure.py"
    "--with-cc=${PETSC_C_COMPILER}"
    "--with-cxx=${PETSC_CXX_COMPILER}"
    "--with-cxx-dialect=C++11"
    "--with-fc=${PETSC_Fortran_COMPILER}"
    "--with-fortran-bindings=0"
)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    list(APPEND OPTIONS "--with-shared-libraries=1")
else()
    list(APPEND OPTIONS "--with-shared-libraries=0")
endif()

if(CMAKE_HOST_WIN32)
    list(APPEND OPTIONS
        "--ignore-cygwin-link"
    )
endif()

# Release and Debug options.
set(OPTIONS_RELEASE
    "--with-debugging=0"
    "--prefix=${PETSC_PACKAGES_DIR}"
    "--CFLAGS=${CFLAGS_RELEASE} ${VCPKG_C_FLAGS} ${VCPKG_C_FLAGS_RELEASE}"
    "--CXXFLAGS=${CXXFLAGS_RELEASE} ${VCPKG_CXX_FLAGS} ${VCPKG_CXX_FLAGS_RELEASE}"
    "--FFLAGS=${FFLAGS_RELEASE}"
    "--CPPFLAGS=${CPPFLAGS_RELEASE} ${VCPKG_C_FLAGS} ${VCPKG_C_FLAGS_RELEASE}"
    "--CXXCPPFLAGS=${CXXPPFLAGS_RELEASE} ${VCPKG_CXX_FLAGS} ${VCPKG_CXX_FLAGS_RELEASE}"
)

set(OPTIONS_DEBUG
    "--with-debugging=1"
    "--prefix=${PETSC_PACKAGES_DIR}/debug"
    "--CFLAGS=${CFLAGS_DEBUG} ${VCPKG_C_FLAGS} ${VCPKG_C_FLAGS_DEBUG}"
    "--CXXFLAGS=${CXXFLAGS_DEBUG} ${VCPKG_CXX_FLAGS} ${VCPKG_CXX_FLAGS_DEBUG}"
    "--FFLAGS=${FFLAGS_DEBUG}"
    "--CPPFLAGS=${CPPFLAGS_DEBUG} ${VCPKG_C_FLAGS} ${VCPKG_C_FLAGS_DEBUG}"
    "--CXXCPPFLAGS=${CXXPPFLAGS_DEBUG} ${VCPKG_CXX_FLAGS} ${VCPKG_CXX_FLAGS_DEBUG}"
)

# Dependency options:
# Libraries paths have to be passed explicitly because PETSc is always prefixing library names with 'lib' on windows if no absolute path is passed.
macro(find_dependent_library)
    cmake_parse_arguments(_fdl "" "OUT_VAR" "NAMES" ${ARGV})

    if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        unset(_LIBRARY_REL CACHE)
        find_library(_LIBRARY_REL
            NAMES ${_fdl_NAMES}
            PATHS "${CURRENT_INSTALLED_DIR}/lib"
            NO_DEFAULT_PATH
        )
        if(NOT _LIBRARY_REL)
            message(FATAL_ERROR "Could not find library with names: ${_fdl_NAMES}")
        endif()

        if(CMAKE_HOST_WIN32)
            to_msys_path("${_LIBRARY_REL}" ${_fdl_OUT_VAR}_RELEASE)
        else()
            set(${_fdl_OUT_VAR}_RELEASE "${_LIBRARY_REL}")
        endif()
    endif()

    if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        unset(_LIBRARY_DEB CACHE)
        find_library(_LIBRARY_DEB
            NAMES ${_fdl_NAMES}
            PATHS "${CURRENT_INSTALLED_DIR}/debug/lib"
            NO_DEFAULT_PATH
        )
        if(NOT _LIBRARY_DEB)
            message(FATAL_ERROR "Could not find debug library with names: ${_fdl_NAMES}")
        endif()

        if(CMAKE_HOST_WIN32)
            to_msys_path("${_LIBRARY_DEB}" ${_fdl_OUT_VAR}_DEBUG)
        else()
            set(${_fdl_OUT_VAR}_DEBUG "${_LIBRARY_DEB}")
        endif()
    endif()
endmacro()

# BLAS
find_dependent_library(
    OUT_VAR BLAS_LIB
    NAMES   blas openblas
)
list(APPEND OPTIONS_RELEASE "--with-blas-lib=${BLAS_LIB_RELEASE}")
list(APPEND OPTIONS_DEBUG   "--with-blas-lib=${BLAS_LIB_DEBUG}")

# LAPACK
find_dependent_library(
    OUT_VAR LAPACK_LIB
    NAMES   lapack
)
list(APPEND OPTIONS_RELEASE "--with-lapack-lib=${LAPACK_LIB_RELEASE}")
list(APPEND OPTIONS_DEBUG   "--with-lapack-lib=${LAPACK_LIB_DEBUG}")

# MPI
find_dependent_library(
    OUT_VAR MPI_LIB
    NAMES   mpi msmpi
)
list(APPEND OPTIONS "--with-mpi-include=${PETSC_INSTALLED_DIR}/include")
if(PETSC_REQUIRES_FORTRAN_COMPILER AND VCPKG_TARGET_IS_WINDOWS)
    find_dependent_library(
        OUT_VAR MSMPIFORTRAN_LIB
        NAMES   msmpifec
    )
    list(APPEND OPTIONS_RELEASE "--with-mpi-lib=[${MSMPIFORTRAN_LIB_RELEASE},${MPI_LIB_RELEASE}]")
    list(APPEND OPTIONS_DEBUG   "--with-mpi-lib=[${MSMPIFORTRAN_LIB_DEBUG},${MPI_LIB_DEBUG}]")
else()
    list(APPEND OPTIONS_RELEASE "--with-mpi-lib=${MPI_LIB_RELEASE}")
    list(APPEND OPTIONS_DEBUG   "--with-mpi-lib=${MPI_LIB_DEBUG}")
endif()

# ScaLAPACK
if("scalapack" IN_LIST FEATURES)
    find_dependent_library(
        OUT_VAR SCALAPACK_LIB
        NAMES   scalapack
    )
    list(APPEND OPTIONS         "--with-scalapack-include=${PETSC_INSTALLED_DIR}/include")
    list(APPEND OPTIONS_RELEASE "--with-scalapack-lib=${SCALAPACK_LIB_RELEASE}")
    list(APPEND OPTIONS_DEBUG   "--with-scalapack-lib=${SCALAPACK_LIB_DEBUG}")
endif()

# METIS
if("metis" IN_LIST FEATURES)
    find_dependent_library(
        OUT_VAR METIS_LIB
        NAMES   metis
    )
    list(APPEND OPTIONS         "--with-metis-include=${PETSC_INSTALLED_DIR}/include")
    list(APPEND OPTIONS_RELEASE "--with-metis-lib=${METIS_LIB_RELEASE}")
    list(APPEND OPTIONS_DEBUG   "--with-metis-lib=${METIS_LIB_DEBUG}")
endif()

# ParMETIS
if("parmetis" IN_LIST FEATURES)
    find_dependent_library(
        OUT_VAR PARMETIS_LIB
        NAMES   parmetis
    )
    list(APPEND OPTIONS         "--with-parmetis-include=${PETSC_INSTALLED_DIR}/include")
    list(APPEND OPTIONS_RELEASE "--with-parmetis-lib=${PARMETIS_LIB_RELEASE}")
    list(APPEND OPTIONS_DEBUG   "--with-parmetis-lib=${PARMETIS_LIB_DEBUG}")
endif()

# HYPRE
if("hypre" IN_LIST FEATURES)
    find_dependent_library(
        OUT_VAR HYPRE_LIB
        NAMES   HYPRE
    )
    list(APPEND OPTIONS         "--with-hypre-include=${PETSC_INSTALLED_DIR}/include")
    list(APPEND OPTIONS_RELEASE "--with-hypre-lib=${HYPRE_LIB_RELEASE}")
    list(APPEND OPTIONS_DEBUG   "--with-hypre-lib=${HYPRE_LIB_DEBUG}")
endif()

# SuperLU_Dist
if("superludist" IN_LIST FEATURES)
    find_dependent_library(
        OUT_VAR SUPERLUDIST_LIB
        NAMES   superlu_dist
    )
    list(APPEND OPTIONS         "--with-superlu_dist-include=${PETSC_INSTALLED_DIR}/include")
    list(APPEND OPTIONS_RELEASE "--with-superlu_dist-lib=${SUPERLUDIST_LIB_RELEASE}")
    list(APPEND OPTIONS_DEBUG   "--with-superlu_dist-lib=${SUPERLUDIST_LIB_DEBUG}")
endif()

# MUMPS
if("mumps" IN_LIST FEATURES)
    find_dependent_library(
        OUT_VAR MUMPS_COMMON_LIB
        NAMES   mumps_common
    )
    find_dependent_library(
        OUT_VAR SMUMPS_LIB
        NAMES   smumps
    )
    find_dependent_library(
        OUT_VAR DMUMPS_LIB
        NAMES   dmumps
    )
    find_dependent_library(
        OUT_VAR CMUMPS_LIB
        NAMES   cmumps
    )
    find_dependent_library(
        OUT_VAR ZMUMPS_LIB
        NAMES   zmumps
    )
    list(APPEND OPTIONS         "--with-mumps-include=${PETSC_INSTALLED_DIR}/include")
    list(APPEND OPTIONS_RELEASE "--with-mumps-lib=[${MUMPS_COMMON_LIB_RELEASE},${SMUMPS_LIB_RELEASE},${DMUMPS_LIB_RELEASE},${CMUMPS_LIB_RELEASE},${ZMUMPS_LIB_RELEASE}]")
    list(APPEND OPTIONS_DEBUG   "--with-mumps-lib=[${MUMPS_COMMON_LIB_DEBUG},${SMUMPS_LIB_DEBUG},${DMUMPS_LIB_DEBUG},${CMUMPS_LIB_DEBUG},${ZMUMPS_LIB_DEBUG}]")
endif()

# HDF5
if("hdf5" IN_LIST FEATURES)
    find_dependent_library(
        OUT_VAR HDF5_LIB
        NAMES   hdf5 hdf5_D
    )
    find_dependent_library(
        OUT_VAR HDF5HL_LIB
        NAMES   hdf5_hl hdf5_hl_D
    )
    list(APPEND OPTIONS         "--with-hdf5-include=${PETSC_INSTALLED_DIR}/include")
    list(APPEND OPTIONS_RELEASE "--with-hdf5-lib=[${HDF5_LIB_RELEASE},${HDF5HL_LIB_RELEASE}]")
    list(APPEND OPTIONS_DEBUG   "--with-hdf5-lib=[${HDF5_LIB_DEBUG},${HDF5HL_LIB_DEBUG}]")
endif()

# Complex scalar type
if("complex" IN_LIST FEATURES)
    list(APPEND OPTIONS "--with-scalar-type=complex")

    if("hypre" IN_LIST FEATURES)
        message(FATAL_ERROR "HYPRE cannot be used when building PETSc with complex scalars. Please disable HYPRE or complex scalars.")
    endif()
endif()

if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
    message(STATUS "Building petsc for Release")
    file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel)
    vcpkg_execute_required_process(
        COMMAND ${BASH} --noprofile --norc "${CMAKE_CURRENT_LIST_DIR}/build.sh"
            "${PETSC_SOURCE_PATH}" # BUILD DIR : In source build
            "${PETSC_INSTALLED_DIR}/bin"
            ${OPTIONS} ${OPTIONS_RELEASE}
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel
        LOGNAME build-${TARGET_TRIPLET}-rel
    )
endif()

if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    message(STATUS "Building petsc for Debug")
    file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg)
    vcpkg_execute_required_process(
        COMMAND ${BASH} --noprofile --norc "${CMAKE_CURRENT_LIST_DIR}/build.sh"
            "${PETSC_SOURCE_PATH}" # BUILD DIR : In source build
            "${PETSC_INSTALLED_DIR}/debug/bin"
            ${OPTIONS} ${OPTIONS_DEBUG}
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg
        LOGNAME build-${TARGET_TRIPLET}-dbg
    )
endif()

# Remove the generated executables
file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/tools)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/lib/petsc/bin/__pycache__)
file(RENAME ${CURRENT_PACKAGES_DIR}/lib/petsc/bin ${CURRENT_PACKAGES_DIR}/tools/petsc)

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/bin)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/lib/petsc/bin)

if(VCPKG_TARGET_IS_WINDOWS)
    # Move the dlls to the bin folder
    if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/bin)
        file(RENAME ${CURRENT_PACKAGES_DIR}/lib/libpetsc.dll ${CURRENT_PACKAGES_DIR}/bin/libpetsc.dll)
        file(RENAME ${CURRENT_PACKAGES_DIR}/lib/libpetsc.pdb ${CURRENT_PACKAGES_DIR}/bin/libpetsc.pdb)
    endif()

    if(NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/debug/bin)
        file(RENAME ${CURRENT_PACKAGES_DIR}/debug/lib/libpetsc.dll ${CURRENT_PACKAGES_DIR}/debug/bin/libpetsc.dll)
        file(RENAME ${CURRENT_PACKAGES_DIR}/debug/lib/libpetsc.pdb ${CURRENT_PACKAGES_DIR}/debug/bin/libpetsc.pdb)
    endif()
endif()

# set(VCPKG_POLICY_SKIP_ARCHITECTURE_CHECK enabled)

# Patch config files
function(fix_petsc_config_file FILEPATH)
    file(READ "${FILEPATH}" FILE_CONTENT)
    string(REPLACE "${PETSC_PACKAGES_DIR}/debug/lib/petsc/bin" "${PETSC_INSTALLED_DIR}/tools" FILE_CONTENT "${FILE_CONTENT}")
    string(REPLACE "${PETSC_PACKAGES_DIR}/debug/include" "${PETSC_INSTALLED_DIR}/include" FILE_CONTENT "${FILE_CONTENT}")
    string(REPLACE "${PETSC_PACKAGES_DIR}/lib/petsc/bin" "${PETSC_INSTALLED_DIR}/tools" FILE_CONTENT "${FILE_CONTENT}")
    string(REPLACE "${PETSC_PACKAGES_DIR}" "${PETSC_INSTALLED_DIR}" FILE_CONTENT "${FILE_CONTENT}")
    file(WRITE "${FILEPATH}" "${FILE_CONTENT}")
endfunction()

fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/lib/petsc/conf/variables")
fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/lib/petsc/conf/rules")
fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/lib/petsc/conf/petscvariables")

fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/debug/lib/petsc/conf/variables")
fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/debug/lib/petsc/conf/rules")
fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/debug/lib/petsc/conf/petscvariables")

vcpkg_apply_patches(
    SOURCE_PATH ${CURRENT_PACKAGES_DIR}
    PATCHES
        ${CMAKE_CURRENT_LIST_DIR}/vcpkg-install-workarounds.patch
)

# Remove other debug folders
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/share)

# Handle copyright
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
