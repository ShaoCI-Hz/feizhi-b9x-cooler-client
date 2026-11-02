cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# --- BLE bridge (C++/WinRT) ---------------------------------------------------
# Built as its own static library because C++/WinRT needs exceptions enabled,
# while Flutter's standard settings force _HAS_EXCEPTIONS=0 and /WX.
file(GLOB WINRT_SDK_DIRS "C:/Program Files (x86)/Windows Kits/10/Include/*/cppwinrt")
if(WINRT_SDK_DIRS)
  list(SORT WINRT_SDK_DIRS)
  list(GET WINRT_SDK_DIRS -1 WINRT_SDK_DIR)
else()
  set(WINRT_SDK_DIR "")
endif()

add_library(b9x_ble STATIC "ble_bridge.cpp")
target_compile_features(b9x_ble PUBLIC cxx_std_17)
target_compile_options(b9x_ble PRIVATE /W3 /EHsc /utf-8)
target_compile_definitions(b9x_ble PRIVATE "NOMINMAX" "UNICODE" "_UNICODE")
if(WINRT_SDK_DIR)
  target_include_directories(b9x_ble PRIVATE "${WINRT_SDK_DIR}")
  target_include_directories(${BINARY_NAME} PRIVATE "${WINRT_SDK_DIR}")
endif()
target_link_libraries(b9x_ble PUBLIC "windowsapp.lib" "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE b9x_ble)

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
