cmake_minimum_required(VERSION 3.18.0)

project(MUMPS VERSION 5.3.5 LANGUAGES C Fortran)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

include(CMakeDependentOption)

# =============================================================================
# Options
# =============================================================================

option(MUMPS_BUILD_SINGLE    "Build MUMPS Single Precision" ON)
option(MUMPS_BUILD_DOUBLE    "Build MUMPS Double Precision" ON)
option(MUMPS_BUILD_COMPLEX   "Build MUMPS Complex Precision" ON)
option(MUMPS_BUILD_COMPLEX16 "Build MUMPS Double Complex Precision" ON)

option(MUMPS_USE_MPI         "Build MUMPS with MPI parallel support" ON)

option(MUMPS_USE_PORD        "Build MUMPS with PORD orderning support" ON)
option(MUMPS_USE_METIS       "Build MUMPS with Metis orderning support" ON)
option(MUMPS_USE_SCOTCH      "Build MUMPS with SCOTCH orderning support" OFF)

cmake_dependent_option(MUMPS_USE_PARMETIS    "Build MUMPS with ParMetis orderning support" ON MUMPS_USE_MPI OFF)
cmake_dependent_option(MUMPS_USE_PTSCOTCH    "Build MUMPS with PT-SCOTCH orderning support" OFF MUMPS_USE_MPI OFF)

option(MUMPS_WITH_INT64      "Build MUMPS with 64bit integers" OFF)

option(MUMPS_SKIP_INSTALL_HEADERS "Do not install header files" OFF)

set(MUMPS_INSTALL_INC_DIR "include" CACHE STRING "The folder where header files will be installed.")
set(MUMPS_INSTALL_LIB_DIR "lib"     CACHE STRING "The folder where libraries will be installed.")
set(MUMPS_INSTALL_BIN_DIR "bin"     CACHE STRING "The folder where runtime components will be installed.")

# =============================================================================
# Dependencies
# =============================================================================

find_package(BLAS REQUIRED)
list(APPEND MUMPS_3RD_PARTY_LIBS BLAS::BLAS)

find_package(LAPACK REQUIRED)
list(APPEND MUMPS_3RD_PARTY_LIBS LAPACK::LAPACK)

if(MUMPS_USE_MPI)
  find_package(MPI REQUIRED)
  list(APPEND MUMPS_3RD_PARTY_LIBS MPI::MPI_C MPI::MPI_Fortran)

  find_package(ScaLAPACK REQUIRED)
  list(APPEND MUMPS_3RD_PARTY_LIBS scalapack)
endif()

if(MUMPS_USE_METIS)
  find_package(METIS REQUIRED)

  list(APPEND MUMPS_3RD_PARTY_LIBS METIS::METIS)
  list(APPEND MUMPS_DEFINITIONS -Dmetis)
endif()

if(MUMPS_USE_PARMETIS)
  find_package(ParMETIS REQUIRED)

  list(APPEND MUMPS_3RD_PARTY_LIBS ParMETIS::ParMETIS)
  list(APPEND MUMPS_DEFINITIONS -Dparmetis)
endif()

set(MUMPS_REQUIRED_SCOTCH_COMPONENTS)
if(MUMPS_USE_SCOTCH)
  list(APPEND MUMPS_REQUIRED_SCOTCH_COMPONENTS scotch esmumps)
endif()
if(MUMPS_USE_PTSCOTCH)
  list(APPEND MUMPS_REQUIRED_SCOTCH_COMPONENTS ptscotch ptesmumps)
endif()

if(MUMPS_REQUIRED_SCOTCH_COMPONENTS)
  find_package(SCOTCH COMPONENTS ${MUMPS_REQUIRED_SCOTCH_COMPONENTS} REQUIRED)

  if(MUMPS_USE_SCOTCH)
    list(APPEND MUMPS_3RD_PARTY_LIBS SCOTCH::scotch SCOTCH::esmumps)
    list(APPEND MUMPS_DEFINITIONS -Dscotch)
  endif()
  if(MUMPS_USE_PTSCOTCH)
    list(APPEND MUMPS_3RD_PARTY_LIBS SCOTCH::ptscotch SCOTCH::ptesmumps)
    list(APPEND MUMPS_DEFINITIONS -Dptscotch)
  endif()
endif()

if(NOT WIN32 OR MINGW)
  find_package(Threads REQUIRED)
  list(APPEND MUMPS_3RD_PARTY_LIBS Threads::Threads)
endif()

# =============================================================================
# Sources
# =============================================================================

set(ARITHS)
if(MUMPS_BUILD_SINGLE)
  list(APPEND ARITHS s)
endif()
if(MUMPS_BUILD_DOUBLE)
  list(APPEND ARITHS d)
endif()
if(MUMPS_BUILD_COMPLEX)
  list(APPEND ARITHS c)
endif()
if(MUMPS_BUILD_COMPLEX16)
  list(APPEND ARITHS z)
endif()

set(SRCS_COMMON_MOD
  src/ana_omp_m.F
  src/ana_blk_m.F
  src/ana_orderings_wrappers_m.F
  src/double_linked_list.F
  src/fac_asm_build_sort_index_ELT_m.F
  src/fac_asm_build_sort_index_m.F
  src/fac_descband_data_m.F
  src/fac_future_niv2_mod.F
  src/fac_ibct_data_m.F
  src/fac_maprow_data_m.F
  src/front_data_mgt_m.F
  src/lr_common.F
  src/mumps_comm_ibcast.F
  src/mumps_l0_omp_m.F
  src/mumps_memory_mod.F
  src/mumps_mpitoomp_m.F
  src/mumps_ooc_common.F
  src/mumps_static_mapping.F
  src/omp_tps_common_m.F
)

set(SRCS_COMMON_OTHER
  src/ana_blk.F
  src/ana_orderings.F
  src/ana_set_ordering.F
  src/ana_AMDMF.F
  src/bcast_errors.F
  src/estim_flops.F
  src/mumps_type_size.F
  src/mumps_type2_blocking.F
  src/mumps_version.F
  src/mumps_print_defined.F
  src/mumps_common.c
  src/mumps_pord.c
  src/mumps_metis.c
  src/mumps_metis64.c
  src/mumps_metis_int.c
  src/mumps_scotch.c
  src/mumps_scotch64.c
  src/mumps_scotch_int.c
  src/mumps_size.c
  src/mumps_io.c
  src/mumps_io_basic.c
  src/mumps_io_thread.c
  src/mumps_io_err.c
  src/mumps_numa.c
  src/mumps_thread.c
  src/mumps_save_restore_C.c
  src/mumps_config_file_C.c
  src/mumps_thread_affinity.c
  src/tools_common.F
  src/sol_common.F
)

foreach(ARITH ${ARITHS})
  set(SRCS_${ARITH}_MOD
    src/${ARITH}ana_aux.F
    src/${ARITH}ana_aux_par.F
    src/${ARITH}ana_lr.F
    src/${ARITH}fac_asm_master_ELT_m.F
    src/${ARITH}fac_asm_master_m.F
    src/${ARITH}fac_front_aux.F
    src/${ARITH}fac_front_LU_type1.F
    src/${ARITH}fac_front_LU_type2.F
    src/${ARITH}fac_front_LDLT_type1.F
    src/${ARITH}fac_front_LDLT_type2.F
    src/${ARITH}fac_front_type2_aux.F
    src/${ARITH}fac_sispointers_m.F
    src/${ARITH}fac_lr.F
    src/${ARITH}fac_mem_dynamic.F
    src/${ARITH}fac_omp_m.F
    src/${ARITH}fac_par_m.F
    src/${ARITH}fac_sol_l0omp_m.F
    src/${ARITH}lr_core.F
    src/${ARITH}lr_stats.F
    src/${ARITH}lr_type.F
    src/${ARITH}mumps_comm_buffer.F
    src/${ARITH}mumps_config_file.F
    src/${ARITH}mumps_load.F
    src/${ARITH}mumps_lr_data_m.F
    src/${ARITH}mumps_ooc_buffer.F
    src/${ARITH}mumps_ooc.F
    src/${ARITH}mumps_sol_es.F
    src/${ARITH}mumps_save_restore.F
    src/${ARITH}mumps_save_restore_files.F
    src/${ARITH}mumps_struc_def.F
    src/${ARITH}omp_tps_m.F
    src/${ARITH}sol_lr.F
    src/${ARITH}sol_omp_m.F
    src/${ARITH}static_ptr_m.F
  )

  set(SRCS_${ARITH}_OTHER
    src/${ARITH}ini_driver.F
    src/${ARITH}ana_driver.F
    src/${ARITH}fac_driver.F
    src/${ARITH}sol_driver.F
    src/${ARITH}sol_distrhs.F
    src/${ARITH}end_driver.F
    src/${ARITH}ana_aux_ELT.F
    src/${ARITH}ana_dist_m.F
    src/${ARITH}ana_LDLT_preprocess.F
    src/${ARITH}ana_reordertree.F
    src/${ARITH}arrowheads.F
    src/${ARITH}bcast_int.F
    src/${ARITH}fac_asm_ELT.F
    src/${ARITH}fac_asm.F
    src/${ARITH}fac_b.F
    src/${ARITH}fac_distrib_distentry.F
    src/${ARITH}fac_distrib_ELT.F
    src/${ARITH}fac_lastrtnelind.F
    src/${ARITH}fac_mem_alloc_cb.F
    src/${ARITH}fac_mem_compress_cb.F
    src/${ARITH}fac_mem_free_block_cb.F
    src/${ARITH}fac_mem_stack_aux.F
    src/${ARITH}fac_mem_stack.F
    src/${ARITH}fac_process_band.F
    src/${ARITH}fac_process_blfac_slave.F
    src/${ARITH}fac_process_blocfacto_LDLT.F
    src/${ARITH}fac_process_blocfacto.F
    src/${ARITH}fac_process_bf.F
    src/${ARITH}fac_process_end_facto_slave.F
    src/${ARITH}fac_process_contrib_type1.F
    src/${ARITH}fac_process_contrib_type2.F
    src/${ARITH}fac_process_contrib_type3.F
    src/${ARITH}fac_process_maprow.F
    src/${ARITH}fac_process_master2.F
    src/${ARITH}fac_process_message.F
    src/${ARITH}fac_process_root2slave.F
    src/${ARITH}fac_process_root2son.F
    src/${ARITH}fac_process_rtnelind.F
    src/${ARITH}fac_root_parallel.F
    src/${ARITH}fac_scalings.F
    src/${ARITH}fac_determinant.F
    src/${ARITH}fac_scalings_simScaleAbs.F
    src/${ARITH}fac_scalings_simScale_util.F
    src/${ARITH}fac_sol_pool.F
    src/${ARITH}fac_type3_symmetrize.F
    src/${ARITH}ini_defaults.F
    src/mumps_c.c
    src/${ARITH}mumps_driver.F
    src/${ARITH}mumps_f77.F
    src/${ARITH}mumps_gpu.c
    src/${ARITH}mumps_iXamax.F
    src/${ARITH}ana_mtrans.F
    src/${ARITH}ooc_panel_piv.F
    src/${ARITH}rank_revealing.F
    src/${ARITH}sol_aux.F
    src/${ARITH}sol_bwd_aux.F
    src/${ARITH}sol_bwd.F
    src/${ARITH}sol_c.F
    src/${ARITH}sol_fwd_aux.F
    src/${ARITH}sol_fwd.F
    src/${ARITH}sol_matvec.F
    src/${ARITH}sol_root_parallel.F
    src/${ARITH}tools.F
    src/${ARITH}type3_root.F
  )
endforeach()

if(MUMPS_WITH_INT64)
  set(MUMPS_INTSIZE "MUMPS_INTSIZE64")
  list(APPEND MUMPS_DEFINITIONS -DINTSIZE64)
else()
  set(MUMPS_INTSIZE "MUMPS_INTSIZE32")
endif()

configure_file(${CMAKE_SOURCE_DIR}/include/mumps_int_def.h.in ${CMAKE_BINARY_DIR}/include/mumps_int_def.h)

# =============================================================================
# Fortran to C interface
# =============================================================================
include(FortranCInterface)
if(FortranCInterface_GLOBAL_CASE STREQUAL "UPPER")
  list(APPEND MUMPS_DEFINITIONS -DUPPER)
endif()
if(FortranCInterface_GLOBAL_SUFFIX STREQUAL "_")
  list(APPEND MUMPS_DEFINITIONS -DAdd_)
elseif(FortranCInterface_GLOBAL_SUFFIX STREQUAL "__")
  list(APPEND MUMPS_DEFINITIONS -DAdd__)
endif()

# =============================================================================
# Targets
# =============================================================================

set(MUMPS_COMPILE_OPTIONS)
if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU" AND CMAKE_Fortran_COMPILER_VERSION VERSION_GREATER_EQUAL "10.0")
  list(APPEND MUMPS_COMPILE_OPTIONS "-fallow-argument-mismatch")
endif()

# Dummy MPI
if(NOT MUMPS_USE_MPI)
  set(SRCS_LIBSEQ
    libseq/mpi.f
    libseq/mpic.c
    libseq/elapse.c
  )

  add_library(libseq STATIC ${SRCS_LIBSEQ})
  target_include_directories(libseq PUBLIC libseq)
  if(BUILD_SHARED_LIBS)
    set_property(TARGET libseq PROPERTY POSITION_INDEPENDENT_CODE ON)
  endif()

  list(APPEND MUMPS_3RD_PARTY_LIBS libseq)
endif()

# PORD
if(MUMPS_USE_PORD)
  set(SRCS_PORD
    PORD/lib/graph.c
    PORD/lib/gbipart.c
    PORD/lib/gbisect.c
    PORD/lib/ddcreate.c
    PORD/lib/ddbisect.c
    PORD/lib/nestdiss.c
    PORD/lib/multisector.c
    PORD/lib/gelim.c
    PORD/lib/bucket.c
    PORD/lib/tree.c
    PORD/lib/symbfac.c
    PORD/lib/interface.c
    PORD/lib/sort.c
    PORD/lib/minpriority.c
  )
  
  add_library(pord STATIC ${SRCS_PORD})
  target_include_directories(pord PUBLIC PORD/include)
  if(BUILD_SHARED_LIBS)
    set_property(TARGET pord PROPERTY POSITION_INDEPENDENT_CODE ON)
  endif()

  list(APPEND MUMPS_3RD_PARTY_LIBS pord)

  list(APPEND MUMPS_DEFINITIONS -Dpord)
endif()

set(MUMPS_INCLUDE_DIRS include ${CMAKE_BINARY_DIR}/include)

# mumps_common
add_library(mumps_common STATIC ${SRCS_COMMON_MOD} ${SRCS_COMMON_OTHER})

target_link_libraries(mumps_common PRIVATE ${MUMPS_3RD_PARTY_LIBS})
target_include_directories(mumps_common PRIVATE ${MUMPS_INCLUDE_DIRS})
target_compile_definitions(mumps_common PRIVATE ${MUMPS_DEFINITIONS})
target_compile_options(mumps_common PRIVATE ${MUMPS_COMPILE_OPTIONS})
if(BUILD_SHARED_LIBS)
  set_property(TARGET mumps_common PROPERTY POSITION_INDEPENDENT_CODE ON)
endif()

# smumps, dmumps, cmumps and zmumps
foreach(ARITH ${ARITHS})
  add_library(${ARITH}mumps ${SRCS_${ARITH}_MOD} ${SRCS_${ARITH}_OTHER})

  set_target_properties(${ARITH}mumps PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
  target_link_libraries(${ARITH}mumps PRIVATE mumps_common ${MUMPS_3RD_PARTY_LIBS})
  target_include_directories(${ARITH}mumps PRIVATE ${MUMPS_INCLUDE_DIRS})
  target_compile_definitions(${ARITH}mumps PRIVATE ${MUMPS_DEFINITIONS} -DMUMPS_ARITH=MUMPS_ARITH_${ARITH})
  target_compile_options(${ARITH}mumps PRIVATE ${MUMPS_COMPILE_OPTIONS})
endforeach()

# =============================================================================
# INSTALL
# =============================================================================
install(
  TARGETS mumps_common
  EXPORT MUMPSExports
  RUNTIME DESTINATION ${MUMPS_INSTALL_BIN_DIR}
  LIBRARY DESTINATION ${MUMPS_INSTALL_LIB_DIR}
  ARCHIVE DESTINATION ${MUMPS_INSTALL_LIB_DIR}
)

if(NOT MUMPS_SKIP_INSTALL_HEADERS)
  install(
    FILES
      include/mumps_compat.h
      include/mumps_c_types.h
      ${CMAKE_BINARY_DIR}/include/mumps_int_def.h
    DESTINATION ${MUMPS_INSTALL_INC_DIR}
  )
endif()

foreach(ARITH ${ARITHS})
  install(
    TARGETS ${ARITH}mumps
    EXPORT MUMPSExports
    RUNTIME DESTINATION ${MUMPS_INSTALL_BIN_DIR}
    LIBRARY DESTINATION ${MUMPS_INSTALL_LIB_DIR}
    ARCHIVE DESTINATION ${MUMPS_INSTALL_LIB_DIR}
  )
  
  if(NOT MUMPS_SKIP_INSTALL_HEADERS)
    install(
      FILES
        include/${ARITH}mumps_c.h
        include/${ARITH}mumps_root.h
        include/${ARITH}mumps_struc.h
      DESTINATION ${MUMPS_INSTALL_INC_DIR}
    )
  endif()
endforeach()
