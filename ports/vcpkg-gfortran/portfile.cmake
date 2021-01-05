vcpkg_fail_port_install(ON_ARCH "arm" ON_TARGET "linux" "osx")
include(vcpkg_find_fortran)
vcpkg_find_fortran(FORTRAN_CMAKE)
if(VCPKG_USE_INTERNAL_Fortran)
    set(VCPKG_CRT_LINKAGE dynamic) # Will always be dynamic no way to overwrite internal CRT linkage here
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
    if(DEFINED ENV{PROCESSOR_ARCHITEW6432})
        set(HOST_ARCH $ENV{PROCESSOR_ARCHITEW6432})
    else()
        set(HOST_ARCH $ENV{PROCESSOR_ARCHITECTURE})
    endif()

    if(HOST_ARCH MATCHES "(amd|AMD)64")

    # elseif(HOST_ARCH MATCHES "(x|X)86")

    else()
        message(FATAL_ERROR "Unsupported host architecture ${HOST_ARCH}!" )
    endif()

    if(VCPKG_TARGET_ARCHITECTURE MATCHES "(x|X)64")

    # elseif(VCPKG_TARGET_ARCHITECTURE MATCHES "(x|X)86")

    else()
        message(FATAL_ERROR "Unsupported target architecture ${VCPKG_TARGET_ARCHITECTURE}!" )
    endif()

    set(FLANG_VERSION "5.0.0")
    set(FLANG_ROOT "${DOWNLOADS}/tools/flang/${FLANG_VERSION}")
    set(FLANG_BIN "${FLANG_ROOT}/Library/bin")
    set(FLANG_INC "${FLANG_ROOT}/Library/include")

    set(FLANG_Fortran_DLLS "${FLANG_BIN}/flang.dll"
                           "${FLANG_BIN}/flangrti.dll"
                           "${FLANG_BIN}/libomp.dll")
    file(INSTALL ${FLANG_Fortran_DLLS} DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    file(INSTALL ${FLANG_Fortran_DLLS} DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")

    set(FLANG_Fortran_MODULES "${FLANG_INC}/ieee_arithmetic.mod"
                              "${FLANG_INC}/ieee_exceptions.mod"
                              "${FLANG_INC}/ieee_features.mod"
                              "${FLANG_INC}/iso_c_binding.mod"
                              "${FLANG_INC}/iso_fortran_env.mod"
                              "${FLANG_INC}/omp_lib.mod"
                              "${FLANG_INC}/omp_lib_kinds.mod")
    file(INSTALL ${FLANG_Fortran_DLLS} DESTINATION "${CURRENT_PACKAGES_DIR}/include")

    set(VCPKG_POLICY_DLLS_WITHOUT_LIBS enabled)
    set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
    file(INSTALL "${FLANG_ROOT}/info/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
else()
    set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
endif()