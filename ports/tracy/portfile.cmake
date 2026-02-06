vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO wolfpld/tracy
    REF "v${VERSION}"
    SHA512 18c0c589a1d97d0760958c8ab00ba2135bc602fd359d48445b5d8ed76e5b08742d818bb8f835b599149030f455e553a92db86fb7bae049b47820e4401cf9f935
    HEAD_REF master
    PATCHES
        build-tools.patch
        downgrade-capstone.patch # tracy wants capstone-6-alpha but vcpkg ships the most recent production capstone, 5.0.6 as of 2026-02-05
        fix-vendor-cmake.patch
        fix-gitref.patch
)

# imgui is a dependency only for the standalone tools. We use a vendored dependency, the v1.92.5-docking branch, because vcpkg has v1.91.9 as of 2026-02-05
vcpkg_from_github(
   OUT_SOURCE_PATH tracy_imgui_path
   REPO ocornut/imgui
   REF "v1.92.5-docking"
   SHA512 4618b8bd6e65ac27cd7cecb3469d135622279d83f8a580c028231578f7023c4465911c5878ee7e40c2f6dda606aef86f27c3cecfb7bc9a6022bd1d89eed17c29
   PATCHES
        "${SOURCE_PATH}/cmake/imgui-emscripten.patch"
        imgui-loader.patch # For some reason the source patch doesn't work on git imgui
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        on-demand TRACY_ON_DEMAND
        fibers	  TRACY_FIBERS
        verbose   TRACY_VERBOSE
    INVERTED_FEATURES
        crash-handler TRACY_NO_CRASH_HANDLER
)

vcpkg_check_features(OUT_FEATURE_OPTIONS TOOLS_OPTIONS
    FEATURES
        cli-tools VCPKG_CLI_TOOLS
        gui-tools VCPKG_GUI_TOOLS
)

if("cli-tools" IN_LIST FEATURES OR "gui-tools" IN_LIST FEATURES)
    vcpkg_find_acquire_program(PKGCONFIG)
    list(APPEND TOOLS_OPTIONS "-DPKG_CONFIG_EXECUTABLE=${PKGCONFIG}")
endif()

# do not use CPM to fetch dependencies
vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DDOWNLOAD_CAPSTONE=OFF
        -DLEGACY=ON
        -DCMAKE_FIND_PACKAGE_TARGETS_GLOBAL=ON
        -DCPM_DONT_UPDATE_MODULE_PATH=ON
        -DCPM_LOCAL_PACKAGES_ONLY=ON
        -DCPM_SKIP_FETCH=ON
        -DCPM_USE_LOCAL_PACKAGES=ON
        -DFETCHCONTENT_FULLY_DISCONNECTED=ON
        -DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS
        -DImGui_SOURCE_DIR=${tracy_imgui_path}
        ${FEATURE_OPTIONS}
    OPTIONS_RELEASE
        ${TOOLS_OPTIONS}
    MAYBE_UNUSED_VARIABLES
        DOWNLOAD_CAPSTONE
        LEGACY
        CPM_DONT_UPDATE_MODULE_PATH
        CPM_LOCAL_PACKAGES_ONLY
        CPM_SKIP_FETCH
        CPM_USE_LOCAL_PACKAGES
        FETCHCONTENT_TRY_FIND_PACKAGE_MODE
        ImGui_SOURCE_DIR
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME Tracy CONFIG_PATH lib/cmake/Tracy)

function(tracy_copy_tool tool_name tool_dir)
    vcpkg_copy_tools(
        TOOL_NAMES ${tool_name}
        SEARCH_DIR ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/${tool_dir}
        AUTO_CLEAN
    )
endfunction()

if("cli-tools" IN_LIST FEATURES)
    tracy_copy_tool(tracy-capture capture)
    tracy_copy_tool(tracy-csvexport csvexport)
    tracy_copy_tool(tracy-import-chrome import)
    tracy_copy_tool(tracy-import-fuchsia import)
    tracy_copy_tool(tracy-update update)
endif()
if("gui-tools" IN_LIST FEATURES)
    tracy_copy_tool(tracy-profiler profiler)
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
