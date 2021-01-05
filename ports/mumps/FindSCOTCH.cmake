# - Try to find Scotch
# Once done this will define
#
#  SCOTCH_FOUND        - system has Scotch
#  SCOTCH_INCLUDE_DIRS - include directories for all components of Scotch
#  SCOTCH_LIBRARIES    - libraries for all components of Scotch
#
# Available components are
#
#  scotch
#  ptscotch
#  esmumps
#  ptesmumps
#
# For each component the following variables are defined
#
#  SCOTCH_<component>_FOUND        - system has the <component> of Scotch
#  SCOTCH_<component>_INCLUDE_DIRS - include directories for the <component> of Scotch
#  SCOTCH_<component>_LIBRARIES    - libraries for the <component> of Scotch
#
# The following imported targets will be defined for each component that is found
#
#  SCOTCH::scotch
#  SCOTCH::ptscotch
#  SCOTCH::esmumps
#  SCOTCH::ptesmumps

include(FindPackageHandleStandardArgs)

set(_scotch_components
  scotch
  ptscotch
  esmumps
  ptesmumps
)

# Find scotch
find_path(SCOTCH_INCLUDE_DIR scotch.h
  DOC "Directory where the Scotch header files are located"
)

find_library(SCOTCH_LIBRARY
  NAMES scotch
  DOC "Directory where the scotch library is located"
)
find_library(SCOTCH_ERR_LIBRARY
  NAMES scotcherr
  DOC "Directory where the scotcherr library is located"
)
find_library(SCOTCH_ERREXIT_LIBRARY
  NAMES scotcherrexit
  DOC "Directory where the scotcherrexit library is located"
)

set(_scotch_scotch_include_vars
  SCOTCH_INCLUDE_DIR
)
set(_scotch_scotch_lib_vars
  SCOTCH_LIBRARY
  SCOTCH_ERR_LIBRARY
  SCOTCH_ERREXIT_LIBRARY
)
set(_scotch_scotch_dependencies)

mark_as_advanced(${_scotch_scotch_include_vars} ${_scotch_scotch_lib_vars})

# Find esmumps
find_path(SCOTCH_ESMUMPS_INCLUDE_DIR esmumps.h
  DOC "Directory where the Scotch esmumps header files are located"
)

find_library(SCOTCH_ESMUMPS_LIBRARY
  NAMES esmumps
  DOC "Directory where the esmumps library is located"
)

set(_scotch_esmumps_include_vars
  SCOTCH_ESMUMPS_INCLUDE_DIR
)
set(_scotch_esmumps_lib_vars
  SCOTCH_ESMUMPS_LIBRARY
)
set(_scotch_esmumps_dependencies
  scotch
)

mark_as_advanced(${_scotch_esmumps_include_vars} ${_scotch_esmumps_lib_vars})

# Find pt-scotch
find_path(PTSCOTCH_INCLUDE_DIR ptscotch.h
  DOC "Directory where the PT-Scotch header files are located"
)

find_library(PTSCOTCH_LIBRARY
  NAMES ptscotch
  DOC "Directory where the ptscotch library is located"
)
find_library(PTSCOTCH_ERR_LIBRARY
  NAMES ptscotcherr
  DOC "Directory where the ptscotcherr library is located"
)
find_library(PTSCOTCH_ERREXIT_LIBRARY
  NAMES ptscotcherrexit
  DOC "Directory where the ptscotcherrexit library is located"
)
find_library(PTSCOTCH_PARMETIS_LIBRARY
  NAMES ptscotchparmetis
  DOC "Directory where the ptscotchparmetis library is located"
)

set(_scotch_ptscotch_include_vars
  PTSCOTCH_INCLUDE_DIR
)
set(_scotch_ptscotch_lib_vars
  PTSCOTCH_LIBRARY
  PTSCOTCH_ERR_LIBRARY
  PTSCOTCH_ERREXIT_LIBRARY
  PTSCOTCH_PARMETIS_LIBRARY
)
set(_scotch_ptscotch_dependencies
  scotch
)

mark_as_advanced(${_scotch_ptscotch_include_vars} ${_scotch_ptscotch_lib_vars})

# Find pt-esmumps
find_library(PTSCOTCH_ESMUMPS_LIBRARY
  NAMES ptesmumps
  DOC "Directory where the ptesmumps library is located"
)

set(_scotch_ptesmumps_include_vars
  SCOTCH_ESMUMPS_INCLUDE_DIR
)
set(_scotch_ptesmumps_lib_vars
  PTSCOTCH_ESMUMPS_LIBRARY
)
set(_scotch_ptesmumps_dependencies
  ptscotch
  esmumps
)

mark_as_advanced(${_scotch_ptesmumps_include_vars} ${_scotch_ptesmumps_lib_vars})

# Get Scotch version
if(NOT SCOTCH_VERSION_STRING AND SCOTCH_INCLUDE_DIR AND EXISTS "${SCOTCH_INCLUDE_DIR}/scotch.h")
  set(version_pattern "^#define[\t ]+SCOTCH_(VERSION|RELEASE|PATCHLEVEL)[\t ]+([0-9\\.]+)$")
  file(STRINGS "${SCOTCH_INCLUDE_DIR}/scotch.h" scotch_version REGEX ${version_pattern})

  foreach(match ${scotch_version})
    if(SCOTCH_VERSION_STRING)
      set(SCOTCH_VERSION_STRING "${SCOTCH_VERSION_STRING}.")
    endif()
    string(REGEX REPLACE ${version_pattern} "${SCOTCH_VERSION_STRING}\\2" SCOTCH_VERSION_STRING ${match})
    set(SCOTCH_VERSION_${CMAKE_MATCH_1} ${CMAKE_MATCH_2})
  endforeach()
  unset(scotch_version)
  unset(version_pattern)
endif()

set(_scotch_required_vars)
foreach(_component IN LISTS _scotch_components)
  set(_dependencies_found_vars)
  foreach(_dependency_component IN LISTS _scotch_${_component}_dependencies)
    list(APPEND _dependencies_found_vars SCOTCH_${_dependency_component}_FOUND)
  endforeach()

  find_package_handle_standard_args(SCOTCH_${_component} NAME_MISMATCHED
    REQUIRED_VARS
      ${_scotch_${_component}_lib_vars}
      ${_scotch_${_component}_include_vars}
      ${_dependencies_found_vars}
    VERSION_VAR
      SCOTCH_VERSION_STRING
  )
  list(APPEND _scotch_required_vars SCOTCH_${_component}_FOUND)
endforeach()

# Standard package handling
find_package_handle_standard_args(SCOTCH
  REQUIRED_VARS
    ${_scotch_required_vars}
  VERSION_VAR
    SCOTCH_VERSION_STRING
  HANDLE_COMPONENTS
)

set(SCOTCH_INCLUDE_DIRS)
set(SCOTCH_LIBRARIES)

foreach(_component IN LISTS _scotch_components)
  if(SCOTCH_${_component}_FOUND)
    if(NOT TARGET SCOTCH::${_component})
      add_library(SCOTCH::${_component} INTERFACE IMPORTED)
    endif()

    set(SCOTCH_${_component}_LIBRARIES)
    foreach(_lib IN LISTS _scotch_${_component}_lib_vars)
      list(APPEND SCOTCH_${_component}_LIBRARIES ${${_lib}})
    endforeach()

    set(SCOTCH_${_component}_INCLUDE_DIRS)
    foreach(_lib IN LISTS _scotch_${_component}_include_vars)
      list(APPEND SCOTCH_${_component}_INCLUDE_DIRS ${${_lib}})
    endforeach()

    set(_component_link_libraries ${SCOTCH_${_component}_LIBRARIES})
    foreach(_dependency_component IN LISTS _scotch_${_component}_dependencies)
      list(APPEND _component_link_libraries SCOTCH::${_dependency_component})
    endforeach()

    set_property(TARGET SCOTCH::${_component} PROPERTY INTERFACE_LINK_LIBRARIES "${_component_link_libraries}")
    set_property(TARGET SCOTCH::${_component} PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${SCOTCH_${_component}_INCLUDE_DIRS}")

    list(APPEND SCOTCH_LIBRARIES ${SCOTCH_${_component}_LIBRARIES})
    list(APPEND SCOTCH_INCLUDE_DIRS ${SCOTCH_${_component}_INCLUDE_DIRS})
  endif()
endforeach()

list(REMOVE_DUPLICATES SCOTCH_INCLUDE_DIRS)
