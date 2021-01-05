#[===[.md:
# vcpkg_find_fortran

Checks if a Fortran compiler can be found.
Windows(x86/x64) Only: If not it will switch/enable MinGW gfortran 
                       and return required cmake args for building. 

## Usage
```cmake
vcpkg_find_fortran(<additional_cmake_args_out>)
```
#]===]

function(vcpkg_find_fortran additional_cmake_args_out)
    set(ARGS_OUT)
    set(CMAKE_BINARY_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}")
    set(CMAKE_CURRENT_BINARY_DIR "${CMAKE_BINARY_DIR}")
    set(CMAKE_PLATFORM_INFO_DIR "${CMAKE_BINARY_DIR}/Platform")
    include(CMakeDetermineFortranCompiler)
    if(NOT CMAKE_Fortran_COMPILER AND NOT VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
    # This intentionally breaks users with a custom toolchain which do not have a Fortran compiler setup
    # because they either need to use a port-overlay (for e.g. lapack), remove the toolchain for the port using fortran
    # or setup fortran in their VCPKG_CHAINLOAD_TOOLCHAIN_FILE themselfs!
        if(WIN32)
            message(STATUS "No Fortran compiler found on the PATH. Using classic flang!")
            if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
                message()
            endif()
            set(FLANG_VERSION "5.0.0")
            if(DEFINED ENV{PROCESSOR_ARCHITEW6432})
                set(HOST_ARCH $ENV{PROCESSOR_ARCHITEW6432})
            else()
                set(HOST_ARCH $ENV{PROCESSOR_ARCHITECTURE})
            endif()

            if(HOST_ARCH MATCHES "(amd|AMD)64")
                set(URLS
                    "https://conda.anaconda.org/conda-forge/win-64/clangdev-${FLANG_VERSION}-flang_3.tar.bz2"
                    "https://conda.anaconda.org/conda-forge/win-64/libflang-${FLANG_VERSION}-vc14_20180208.tar.bz2"
                    "https://conda.anaconda.org/conda-forge/win-64/openmp-${FLANG_VERSION}-vc14_1.tar.bz2"
                    "https://conda.anaconda.org/conda-forge/win-64/flang-${FLANG_VERSION}-vc14_20180208.tar.bz2"
                )
                set(ARCHIVES
                    "clangdev-${FLANG_VERSION}-flang_3.tar.bz2"
                    "libflang-${FLANG_VERSION}-vc14_20180208.tar.bz2"
                    "openmp-${FLANG_VERSION}-vc14_1.tar.bz2"
                    "flang-${FLANG_VERSION}-vc14_20180208.tar.bz2"
                )
                set(HASHS
                    "fd5eb1d39ba631e2e85ecf63906c8a5d0f87e5f3f9a86dbe4cfd28d399e922f9786804f94f2a3372d13c9c4f01d9d253fba31d9695be815b4798108db17939b4"
                    "a8bcb44b344c9ca3571e1de08894d9ee450e2a36e9a604dedb264415adbabb9b0b698b39d96abc8b319041b15ba991b28d463a61523388509038a363cbaebae2"
                    "5277f0a33d8672b711bbf6c97c9e2e755aea411bfab2fce4470bb2dd112cbbb11c913de2062331cc61c3acf7b294a6243148d7cb71b955cc087586a2f598809a"
                    "c72a4532dfc666ad301e1349c1ff0f067049690f53dbf30fd38382a546b619045a34660ee9591ce5c91cf2a937af59e87d0336db2ee7f59707d167cd92a920c4"
                )
                list(LENGTH URLS PACKAGE_COUNT)
            else()
                message(FATAL "Flang not supported for host architecture ${HOST_ARCH}.")
            endif()

            set(FLANG_ROOT "${DOWNLOADS}/tools/flang/${FLANG_VERSION}")
            set(FLANG_BIN "${FLANG_ROOT}/Library/bin")
            set(FLANG_LIB "${FLANG_ROOT}/Library/lib")

            # Download and extract all packages required for Flang if this has not been done yet
            if(NOT EXISTS "${FLANG_BIN}/flang.exe")
                file(MAKE_DIRECTORY "${FLANG_ROOT}")

                math(EXPR PACKAGE_RANGE_END "${PACKAGE_COUNT} - 1")
                foreach(PACKAGE_I RANGE ${PACKAGE_RANGE_END})
                    list(GET URLS ${PACKAGE_I} URL)
                    list(GET ARCHIVES ${PACKAGE_I} ARCHIVE)
                    list(GET HASHS ${PACKAGE_I} HASH)

                    set(ARCHIVE_PATH "${DOWNLOADS}/${ARCHIVE}")

                    file(DOWNLOAD "${URL}" "${ARCHIVE_PATH}"
                        EXPECTED_HASH SHA512=${HASH}
                        SHOW_PROGRESS
                    )

                    execute_process(
                        COMMAND ${CMAKE_COMMAND} -E tar xzf ${ARCHIVE_PATH}
                        WORKING_DIRECTORY ${FLANG_ROOT}
                    )
                endforeach()

                if(NOT EXISTS "${FLANG_BIN}/flang.exe")
                    message(FATAL_ERROR
                    "Error while trying to get Flang. Could not find:\n"
                    "  ${FLANG_BIN}/flang.exe"
                    )
                endif()
            endif()

            # Append the Flang directory to PATH
            vcpkg_add_to_path("${FLANG_BIN}")
            set(ENV{LIB} "$ENV{LIB}${VCPKG_HOST_PATH_SEPARATOR}${FLANG_LIB}")

            list(APPEND ARGS_OUT
                "-DCMAKE_C_COMPILER=cl"
                "-DCMAKE_CXX_COMPILER=cl"
                "-DCMAKE_Fortran_COMPILER=${FLANG_BIN}/flang.exe"
            )
            set(VCPKG_USE_INTERNAL_Fortran TRUE PARENT_SCOPE)
            set(VCPKG_POLICY_ONLY_RELEASE_CRT enabled PARENT_SCOPE)
        else()
            message(FATAL_ERROR "Unable to find a Fortran compiler using 'CMakeDetermineFortranCompiler'. Please install one (e.g. gfortran) and make it available on the PATH!")
        endif()
    endif()
    set(${additional_cmake_args_out} ${ARGS_OUT} PARENT_SCOPE)
endfunction()