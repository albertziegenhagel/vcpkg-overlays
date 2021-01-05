
include(vcpkg_find_fortran)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO xiaoyeli/superlu_dist
    REF v6.3.1
    SHA512 d4942fd1df72cb4fdd23d05ef0106868f701653c2a24085e4f900f229fd3c69e0aea7a595e139d82721ffb8d61b0a6aa6de29e373796dbff4ee99bdc09ff41f8
    HEAD_REF master
    PATCHES
        fix-find-parmetis.patch
        fix-use-posix.patch
        fix-fortran.patch
        fix-unistd-include.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    parmetis   TPL_ENABLE_PARMETISLIB
    # fortran    enable_fortran
    # fortran    XSDK_ENABLE_Fortran
)

# if("fortran" IN_LIST FEATURES)
    vcpkg_find_fortran(FORTRAN_CMAKE)
# endif()

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        -Denable_doc=OFF
        -Denable_tests=OFF
        -Denable_examples=OFF
        -Denable_fortran=OFF
        -DXSDK_ENABLE_Fortran=OFF
        ${FORTRAN_CMAKE}
        ${FEATURE_OPTIONS}
        -DBUILD_STATIC_LIBS=OFF # This actually still builds the static library if BUILD_SHARED_LIBS is OFF
)

vcpkg_install_cmake()
vcpkg_copy_pdbs()

# vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)

file(INSTALL ${SOURCE_PATH}/License.txt DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
