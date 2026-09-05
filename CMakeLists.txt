####
# This sets up the build system for the 'FprimeBilleeRcm' project, including
# components and deployments from project.cmake. In addition, it imports the core F Prime components.
####

cmake_minimum_required(VERSION 3.24.2)

# Enable Zephyr when not performing a unit testing build
if (NOT BUILD_TESTING)
    find_package(Zephyr HINTS "${CMAKE_CURRENT_LIST_DIR}/lib/zephyr-workspace")
endif()

project(FprimeBilleeRcm C CXX)

###
# F' Core Setup
# This includes all of the F prime core components, and imports the make-system.
###
include("${CMAKE_CURRENT_LIST_DIR}/lib/fprime/cmake/FPrime.cmake")

# NOTE: register custom targets between these two lines
fprime_setup_included_code()

# F Prime's reference subtopologies use desktop-sized 64 KiB task stacks.
# RP2350 has enough RAM for the complete topology, but not for sixteen 64 KiB
# stacks. Keep every component and use the 4 KiB stack size provisioned by
# Zephyr for each active component.
if (BOARD MATCHES "^rpi_pico2")
    add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/config/rp2350-overrides")
endif()

# fprime-zephyr currently selects the newer F Prime counting-semaphore stub,
# which is not present in the pinned F Prime v4.2.2 framework. Provide an empty
# compatibility target because this deployment does not use that interface.
if (NOT TARGET Os_CountingSemaphore_Stub)
    add_library(Os_CountingSemaphore_Stub INTERFACE)
endif()

# This includes project-wide objects
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/FprimeBilleeRcm")

# Register the RP2350 application and attach its sources to Zephyr's app target.
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/rp2350Deployment")
