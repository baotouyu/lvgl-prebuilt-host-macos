cmake_minimum_required(VERSION 3.16)

project(lvgl_host_macos_prebuilt C)

set(LVGL_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/lvgl" CACHE PATH "LVGL source directory")
set(LVGL_CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/config/host_macos" CACHE PATH "LVGL config directory")

if(NOT EXISTS "${LVGL_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "LVGL source not found at ${LVGL_SOURCE_DIR}. Run scripts/build_host_macos.sh first.")
endif()

if(NOT EXISTS "${LVGL_CONFIG_DIR}/lv_conf.h")
  message(FATAL_ERROR "lv_conf.h not found at ${LVGL_CONFIG_DIR}/lv_conf.h")
endif()

find_program(SDL2_CONFIG_EXECUTABLE sdl2-config REQUIRED)

execute_process(COMMAND ${SDL2_CONFIG_EXECUTABLE} --cflags
  OUTPUT_VARIABLE SDL2_CFLAGS
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

separate_arguments(SDL2_CFLAGS_LIST NATIVE_COMMAND "${SDL2_CFLAGS}")

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(LV_CONF_PATH "${LVGL_CONFIG_DIR}/lv_conf.h" CACHE STRING "" FORCE)
set(LV_CONF_BUILD_DISABLE_EXAMPLES ON CACHE BOOL "" FORCE)
set(LV_CONF_BUILD_DISABLE_DEMOS ON CACHE BOOL "" FORCE)
set(LV_CONF_BUILD_DISABLE_THORVG_INTERNAL ON CACHE BOOL "" FORCE)

add_subdirectory("${LVGL_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/lvgl")

target_compile_options(lvgl PRIVATE ${SDL2_CFLAGS_LIST})
