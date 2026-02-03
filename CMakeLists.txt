cmake_minimum_required(VERSION 3.16)
project(NetscapeCEF VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Options
option(USE_SANDBOX "Enable CEF sandbox" OFF)

# ============================================================================
# Find Qt6
# ============================================================================
find_package(Qt6 REQUIRED COMPONENTS Widgets Core Gui)

# ============================================================================
# CEF Configuration
# ============================================================================
set(CEF_ROOT "${CMAKE_SOURCE_DIR}/third_party/cef" CACHE PATH "CEF binary distribution root")

if(NOT EXISTS "${CEF_ROOT}/include/cef_version.h")
    message(FATAL_ERROR
        "CEF not found at ${CEF_ROOT}\n"
        "Please download CEF from https://cef-builds.spotifycdn.com/index.html\n"
        "and extract to ${CEF_ROOT}"
    )
endif()

# CEF include directories
set(CEF_INCLUDE_DIRS
    ${CEF_ROOT}
    ${CEF_ROOT}/include
)

# CEF library directories
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CEF_LIB_DIR "${CEF_ROOT}/Release")
    set(CEF_RESOURCE_DIR "${CEF_ROOT}/Resources")
    set(CEF_LIBRARIES
        ${CEF_LIB_DIR}/libcef.so
    )
    # Build the CEF wrapper library
    set(CEF_WRAPPER_DIR "${CEF_ROOT}/libcef_dll_wrapper")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(CEF_LIB_DIR "${CEF_ROOT}/Release")
    set(CEF_RESOURCE_DIR "${CEF_ROOT}/Resources")
    set(CEF_LIBRARIES
        ${CEF_LIB_DIR}/libcef.lib
    )
    set(CEF_WRAPPER_DIR "${CEF_ROOT}/libcef_dll_wrapper")
endif()

# Build CEF wrapper if needed
if(NOT TARGET libcef_dll_wrapper)
    add_subdirectory(${CEF_ROOT}/libcef_dll_wrapper ${CMAKE_BINARY_DIR}/libcef_dll_wrapper)
endif()

# ============================================================================
# Asset Processing
# ============================================================================
set(ASSET_1X_DIR "${CMAKE_SOURCE_DIR}/assets/1x")
set(ASSET_2X_DIR "${CMAKE_BINARY_DIR}/assets/2x")
set(ASSET_3X_DIR "${CMAKE_BINARY_DIR}/assets/3x")

find_package(Python3 COMPONENTS Interpreter)
if(Python3_FOUND)
    add_custom_target(scale_assets
        COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tools/scale_assets.py
            --input ${ASSET_1X_DIR} --output ${ASSET_2X_DIR} --scale 2
        COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tools/scale_assets.py
            --input ${ASSET_1X_DIR} --output ${ASSET_3X_DIR} --scale 3
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Scaling assets for HiDPI displays"
    )
endif()

# ============================================================================
# Sources
# ============================================================================
set(SOURCES
    src/main.cpp
    src/app/NetscapeApp.cpp
    src/app/NetscapeApp.h
    src/browser/CefBrowserWidget.cpp
    src/browser/CefBrowserWidget.h
    src/browser/NetscapeClient.cpp
    src/browser/NetscapeClient.h
    src/browser/NetscapeLoadHandler.cpp
    src/browser/NetscapeLoadHandler.h
    src/browser/NetscapeDisplayHandler.cpp
    src/browser/NetscapeDisplayHandler.h
    src/browser/NetscapeRequestHandler.cpp
    src/browser/NetscapeRequestHandler.h
    src/ui/NetscapeMainWindow.cpp
    src/ui/NetscapeMainWindow.h
    src/ui/NavigationToolbar.cpp
    src/ui/NavigationToolbar.h
    src/ui/LocationToolbar.cpp
    src/ui/LocationToolbar.h
    src/ui/NetscapeStatusBar.cpp
    src/ui/NetscapeStatusBar.h
    src/ui/NetscapeMenuBar.cpp
    src/ui/NetscapeMenuBar.h
    src/ui/widgets/NetscapeButton.cpp
    src/ui/widgets/NetscapeButton.h
    src/ui/widgets/ThrobberWidget.cpp
    src/ui/widgets/ThrobberWidget.h
    src/ui/widgets/NetscapeStyle.cpp
    src/ui/widgets/NetscapeStyle.h
    src/assets/AssetManager.cpp
    src/assets/AssetManager.h
)

# Resources
qt6_add_resources(RESOURCES resources/netscape.qrc)

# ============================================================================
# Main Executable
# ============================================================================
add_executable(netscape-browser ${SOURCES} ${RESOURCES})

target_include_directories(netscape-browser PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CEF_INCLUDE_DIRS}
)

target_link_libraries(netscape-browser PRIVATE
    Qt6::Widgets
    Qt6::Core
    Qt6::Gui
    libcef_dll_wrapper
    ${CEF_LIBRARIES}
)

# Linux-specific
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_link_libraries(netscape-browser PRIVATE
        pthread
        X11
    )

    # RPATH for finding libcef.so
    set_target_properties(netscape-browser PROPERTIES
        BUILD_RPATH "${CEF_LIB_DIR}"
        INSTALL_RPATH "${CEF_LIB_DIR}"
    )
endif()

# ============================================================================
# CEF Helper Process (Linux/Mac multi-process)
# ============================================================================
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    add_executable(netscape-helper
        src/helper/main_helper.cpp
    )

    target_include_directories(netscape-helper PRIVATE
        ${CEF_INCLUDE_DIRS}
    )

    target_link_libraries(netscape-helper PRIVATE
        libcef_dll_wrapper
        ${CEF_LIBRARIES}
    )
endif()

# ============================================================================
# Post-build: Copy CEF resources
# ============================================================================
add_custom_command(TARGET netscape-browser POST_BUILD
    # Copy CEF binaries
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CEF_LIB_DIR}
        $<TARGET_FILE_DIR:netscape-browser>
    # Copy CEF resources
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CEF_RESOURCE_DIR}
        $<TARGET_FILE_DIR:netscape-browser>
    COMMENT "Copying CEF binaries and resources"
)

# ============================================================================
# Install
# ============================================================================
install(TARGETS netscape-browser
    RUNTIME DESTINATION bin
)

install(DIRECTORY ${CEF_LIB_DIR}/
    DESTINATION lib
    FILES_MATCHING PATTERN "*.so*"
)

install(DIRECTORY ${CEF_RESOURCE_DIR}/
    DESTINATION share/netscape
)
