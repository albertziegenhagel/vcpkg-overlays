
set(SCALAPACK_VERSION 2.1.0)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Reference-ScaLAPACK/scalapack
    REF bc6cad585362aa58e05186bb85d4b619080c45a9
    SHA512 bf5987b4394bead23db6d80b90ea13d77bcae8744108dc7fa20417c4d7b91390727892ef00a7ca3d88326232459e039a2568e7f274ab5eb28fa6152d83481bfa
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)

include(vcpkg_find_fortran)
vcpkg_find_fortran(FORTRAN_CMAKE)

set(CONFIGURE_OPTIONS)
if(VCPKG_TARGET_IS_WINDOWS)
    set(FORTRAN_MPI_LIBS msmpifec msmpi)
    string(REPLACE ";" "\\\\\\\\\\\\\;" FORTRAN_MPI_LIBS "${FORTRAN_MPI_LIBS}")
    list(APPEND CONFIGURE_OPTIONS
        "-DMPI_Fortran_LIB_NAMES=${FORTRAN_MPI_LIBS}"
    )
endif()

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        -DBUILD_TESTING=OFF
        ${CONFIGURE_OPTIONS}
        ${FORTRAN_CMAKE}
        -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON
)

vcpkg_install_cmake()

vcpkg_copy_pdbs()

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

if(VCPKG_TARGET_IS_WINDOWS)
    file(RENAME ${CURRENT_PACKAGES_DIR}/Testing ${CURRENT_PACKAGES_DIR}/bin)
    file(RENAME ${CURRENT_PACKAGES_DIR}/debug/Testing ${CURRENT_PACKAGES_DIR}/debug/bin)
    
    file(READ ${CURRENT_PACKAGES_DIR}/lib/cmake/scalapack-${SCALAPACK_VERSION}/scalapack-targets-release.cmake RELEASE_CONFIG)
    string(REPLACE "Testing" "bin" RELEASE_CONFIG "${RELEASE_CONFIG}")
    file(WRITE ${CURRENT_PACKAGES_DIR}/lib/cmake/scalapack-${SCALAPACK_VERSION}/scalapack-targets-release.cmake "${RELEASE_CONFIG}")
    
    file(READ ${CURRENT_PACKAGES_DIR}/debug/lib/cmake/scalapack-${SCALAPACK_VERSION}/scalapack-targets-debug.cmake DEBUG_CONFIG)
    string(REPLACE "Testing" "bin" DEBUG_CONFIG "${DEBUG_CONFIG}")
    file(WRITE ${CURRENT_PACKAGES_DIR}/debug/lib/cmake/scalapack-${SCALAPACK_VERSION}/scalapack-targets-debug.cmake "${DEBUG_CONFIG}")
endif()

vcpkg_fixup_cmake_targets(CONFIG_PATH lib/cmake/scalapack-${SCALAPACK_VERSION} TARGET_PATH share/scalapack)

# The pkg-config files contain a reference to mpi which does not always have a pkg-config file (e.g. msmpi)
# so we can not use pkgconfig yet
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/lib/pkgconfig)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig)

# Handle copyright
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

# Post-build test for cmake libraries
vcpkg_test_cmake(PACKAGE_NAME scalapack)
