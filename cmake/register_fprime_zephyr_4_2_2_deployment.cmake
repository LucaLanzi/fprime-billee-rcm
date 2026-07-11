####
# Project-local deployment registration for F Prime 4.2.2 and newer
# fprime-zephyr revisions.
#
# This mirrors register_fprime_zephyr_deployment from fprime-zephyr, but runs
# the generated CMake installer directly. F Prime 4.2.2 does not contain the
# cmake/target/fprime_install.cmake wrapper expected by newer fprime-zephyr.
####

function(register_fprime_zephyr_4_2_2_deployment)
    include(utilities)
    set(BUILD_TARGET_NAME "${FPRIME_CURRENT_MODULE}")
    cmake_parse_arguments(
        INTERNAL
        "EXCLUDE_FROM_ALL"
        ""
        "CHOOSES_IMPLEMENTATIONS;SOURCES;HEADERS;DEPENDS"
        ${ARGN}
    )

    list(LENGTH INTERNAL_UNPARSED_ARGUMENTS UNPARSED_COUNT)
    fprime_cmake_ASSERT(
        "Failed to parse: ${INTERNAL_UNPARSED_ARGUMENTS}"
        UNPARSED_COUNT LESS 2
    )
    if (INTERNAL_UNPARSED_ARGUMENTS)
        list(LENGTH INTERNAL_UNPARSED_ARGUMENTS UNKNOWN_LENGTH)
        fprime_cmake_ASSERT(
            "Unknown argument supplied: ${INTERNAL_UNPARSED_ARGUMENTS}"
            UNKNOWN_LENGTH EQUAL 1
        )
        set(BUILD_TARGET_NAME "${INTERNAL_UNPARSED_ARGUMENTS}")
    endif()

    fprime_cmake_ASSERT(
        "Zephyr supports only one deployment per project"
        NOT TARGET fprime-zephyr-deployment
    )

    set(EMPTY_SOURCE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/zephyr_empty.cpp")
    add_library(fprime-zephyr-deployment "${EMPTY_SOURCE}")
    fprime_target_dependencies(
        fprime-zephyr-deployment
        PUBLIC
        ${INTERNAL_DEPENDS}
    )
    set_target_properties(
        fprime-zephyr-deployment
        PROPERTIES FPRIME_TYPE Deployment
    )
    fprime_attach_custom_targets(fprime-zephyr-deployment)

    target_sources(app PRIVATE ${INTERNAL_SOURCES})
    fprime_target_implementations(app ${INTERNAL_CHOOSES_IMPLEMENTATIONS})
    target_link_libraries(app PRIVATE fprime-zephyr-deployment)

    install(
        DIRECTORY "${CMAKE_BINARY_DIR}/zephyr/"
        COMPONENT fprime-zephyr-binaries
        DESTINATION .
        FILES_MATCHING PATTERN "zephyr/zephyr.*"
        REGEX "zephyr/[^z]" EXCLUDE
    )

    add_custom_target(
        ${BUILD_TARGET_NAME} ALL
        DEPENDS zephyr_final fprime-zephyr-deployment_dictionary
        COMMAND "${CMAKE_COMMAND}" -E env
            "DESTDIR=${FPRIME_INSTALL_DEST}"
            "${CMAKE_COMMAND}"
            -DCMAKE_INSTALL_PREFIX=/
            -DCMAKE_INSTALL_COMPONENT=fprime-zephyr-binaries
            -P "${CMAKE_BINARY_DIR}/cmake_install.cmake"
    )

    include(fprime-util)
    fprime_util_metadata_add_build_target("${BUILD_TARGET_NAME}")
endfunction()
