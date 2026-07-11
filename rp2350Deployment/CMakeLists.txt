#####
# 'rp2350Deployment' Deployment:
#
# This registers the 'rp2350Deployment' deployment to the build system. 
# Custom components that have not been added at the project-level should be added to 
# the list below.
#
#####

###
# Topology and Components
###

add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/Top/")

# Add custom components to this specific deployment here
# add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/MyComponent/")

# register_fprime_deployment(
#     SOURCES
#         "${CMAKE_CURRENT_LIST_DIR}/Main.cpp"
#     DEPENDS
#         ${FPRIME_CURRENT_MODULE}_Top
# )

include("${FPRIME_PROJECT_ROOT}/cmake/register_fprime_zephyr_4_2_2_deployment.cmake")

register_fprime_zephyr_4_2_2_deployment(
        ${FPRIME_CURRENT_MODULE}
    SOURCES
        "${CMAKE_CURRENT_LIST_DIR}/Main.cpp"
    DEPENDS
        ${FPRIME_CURRENT_MODULE}_Top
)
