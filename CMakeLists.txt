####
# This sets up the build system for the 'FprimeBilleeRcm' project, including
# components and deployments from project.cmake. In addition, it imports the core F Prime components.
####

cmake_minimum_required(VERSION 3.24.2)

# Enable Zephyr only when fprime-util selected the Zephyr toolchain.  Commands
# such as `fprime-util new` use a native cache for FPP metadata; loading Zephyr
# for that cache prevents CMake from completing a normal F Prime configure.
get_filename_component(FPRIME_TOOLCHAIN_NAME "${CMAKE_TOOLCHAIN_FILE}" NAME)
if (FPRIME_TOOLCHAIN_NAME STREQUAL "zephyr.cmake")
    set(FPRIME_USE_ZEPHYR ON)
    find_package(Zephyr HINTS "${CMAKE_CURRENT_LIST_DIR}/lib/zephyr-workspace")
else()
    set(FPRIME_USE_ZEPHYR OFF)
endif()

project(FprimeBilleeRcm C CXX)

set(FPRIME_DEPLOYMENT_PROFILE "default" CACHE STRING "Selects the Zephyr deployment profile")

###
# F' Core Setup
# This includes all of the F prime core components, and imports the make-system.
###
include("${CMAKE_CURRENT_LIST_DIR}/lib/fprime/cmake/FPrime.cmake")

# NOTE: register custom targets between these two lines
fprime_setup_included_code()

# RP2040 needs significantly smaller framework/subtopology config than the
# reference deployment defaults. Apply project-owned config overrides only for
# that board so larger Zephyr targets keep the roomier defaults.
if (FPRIME_USE_ZEPHYR AND BOARD STREQUAL "rpi_pico")
    add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/config/rp2040-overrides")
endif()

# F Prime v4.2.2's FpySequencer stack uses std::make_unsigned without pulling
# in <type_traits>. Force-include it from the project so lib/fprime stays clean.
if (TARGET Svc_FpySequencer)
    target_compile_options(Svc_FpySequencer PRIVATE
        $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang,AppleClang>:-include type_traits>
    )
endif()

# fprime-zephyr currently selects the newer F Prime counting-semaphore stub,
# which is not present in the pinned F Prime v4.2.2 framework. Provide an empty
# compatibility target because this deployment does not use that interface.
if (FPRIME_USE_ZEPHYR AND NOT TARGET Os_CountingSemaphore_Stub)
    add_library(Os_CountingSemaphore_Stub INTERFACE)
endif()

# This includes project-wide objects
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/FprimeBilleeRcm")

# Register the selected Zephyr application only when Zephyr has created its app target.
if (FPRIME_USE_ZEPHYR)
    if (FPRIME_DEPLOYMENT_PROFILE STREQUAL "rp2040")
        add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/rp2040Deployment")
    else()
        add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/rp2350Deployment")
    endif()
endif()

# Register project components for native metadata and Zephyr builds.
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/Components/HelloWorld/")
