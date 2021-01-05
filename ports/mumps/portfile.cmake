
vcpkg_download_distfile(ARCHIVE
    URLS
      "http://mumps.enseeiht.fr/MUMPS_5.3.5.tar.gz"
      "http://graal.ens-lyon.fr/MUMPS/MUMPS_5.3.5.tar.gz"
    FILENAME "MUMPS_5.3.5.tar.gz"
    SHA512 6e3bb081f38af8540ada7b4fb54c6e766739c854e2a3dd253e3e012eee05dae30064b1b4a8d7493f10691725aba4cc9e80544b0fe5b71670cb0b2726ccfc4439
)

vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE ${ARCHIVE}
    PATCHES
        no-force-upper-fortran-mangling.patch
        # MS-MPI uses DLLIMPORT in its mpif.h file for MPI_IN_PLACE, which is not understood
        # by all fortran compilers (e.g. flang), so we change the code to not use MPI_IN_PLACE
        workaround-mpi-in-place.patch
)

file(COPY ${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt DESTINATION ${SOURCE_PATH})
file(COPY ${CMAKE_CURRENT_LIST_DIR}/mumps_int_def.h.in DESTINATION ${SOURCE_PATH}/include)
file(MAKE_DIRECTORY ${SOURCE_PATH}/cmake)
file(COPY ${CMAKE_CURRENT_LIST_DIR}/FindMETIS.cmake DESTINATION ${SOURCE_PATH}/cmake)
file(COPY ${CMAKE_CURRENT_LIST_DIR}/FindParMETIS.cmake DESTINATION ${SOURCE_PATH}/cmake)
file(COPY ${CMAKE_CURRENT_LIST_DIR}/FindSCOTCH.cmake DESTINATION ${SOURCE_PATH}/cmake)

include(vcpkg_find_fortran)
vcpkg_find_fortran(FORTRAN_CMAKE)

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
    OPTIONS
        -DMUMPS_USE_MPI=ON
        -DMUMPS_USE_METIS=ON
        -DMUMPS_USE_PARMETIS=ON
        -DMUMPS_USE_SCOTCH=OFF
        -DMUMPS_USE_PTSCOTCH=OFF
        ${FORTRAN_CMAKE}
    OPTIONS_DEBUG
        -DMUMPS_SKIP_INSTALL_HEADERS=ON
)

vcpkg_install_cmake()
vcpkg_copy_pdbs()

# Handle copyright
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
