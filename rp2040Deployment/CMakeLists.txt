#####
# 'rp2040Deployment' Deployment:
#####

add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/Top/")

include("${FPRIME_PROJECT_ROOT}/cmake/register_fprime_zephyr_4_2_2_deployment.cmake")

register_fprime_zephyr_4_2_2_deployment(
        ${FPRIME_CURRENT_MODULE}
    SOURCES
        "${CMAKE_CURRENT_LIST_DIR}/Main.cpp"
    DEPENDS
        ${FPRIME_CURRENT_MODULE}_Top
)
