from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_lv_conf_enables_sdl2_without_sdl_draw_backend():
    lv_conf = (REPO_ROOT / "config/host_macos/lv_conf.h").read_text(encoding="utf-8")

    assert "#define LV_USE_SDL 1" in lv_conf
    assert "#define LV_SDL_INCLUDE_PATH <SDL2/SDL.h>" in lv_conf
    assert "#define LV_SDL_RENDER_MODE LV_DISPLAY_RENDER_MODE_PARTIAL" in lv_conf
    assert "#define LV_SDL_BUF_COUNT 1" in lv_conf
    assert "#define LV_SDL_ACCELERATED 0" in lv_conf
    assert "#define LV_SDL_FULLSCREEN 0" in lv_conf
    assert "#define LV_SDL_DIRECT_EXIT 0" in lv_conf
    assert "#define LV_SDL_MOUSEWHEEL_MODE LV_SDL_MOUSEWHEEL_MODE_ENCODER" in lv_conf
    assert "#define LV_USE_DRAW_SDL 0" in lv_conf
    assert "#define LV_USE_DEMO_WIDGETS 1" in lv_conf


def test_lv_conf_enables_local_file_image_and_font_assets():
    lv_conf = (REPO_ROOT / "config/host_macos/lv_conf.h").read_text(encoding="utf-8")

    assert "#define LV_USE_FS_STDIO 1" in lv_conf
    assert "#define LV_FS_STDIO_LETTER 'A'" in lv_conf
    assert '#define LV_FS_STDIO_PATH ""' in lv_conf
    assert "#define LV_FS_STDIO_CACHE_SIZE 0" in lv_conf
    assert "#define LV_USE_LODEPNG 1" in lv_conf
    assert "#define LV_USE_TJPGD 1" in lv_conf
    assert "#define LV_USE_BMP 1" in lv_conf
    assert "#define LV_USE_TINY_TTF 1" in lv_conf
    assert "#define LV_TINY_TTF_FILE_SUPPORT 1" in lv_conf
    assert "#define LV_USE_LIBPNG 0" in lv_conf
    assert "#define LV_USE_LIBJPEG_TURBO 0" in lv_conf
    assert "#define LV_USE_FREETYPE 0" in lv_conf


def test_cmake_wires_sdl2_config_into_lvgl_target():
    cmake = (REPO_ROOT / "CMakeLists.txt").read_text(encoding="utf-8")

    assert "find_program(SDL2_CONFIG_EXECUTABLE sdl2-config REQUIRED)" in cmake
    assert "execute_process(COMMAND ${SDL2_CONFIG_EXECUTABLE} --cflags" in cmake
    assert "execute_process(COMMAND ${SDL2_CONFIG_EXECUTABLE} --prefix" in cmake
    assert "separate_arguments(SDL2_CFLAGS_LIST NATIVE_COMMAND" in cmake
    assert 'set(SDL2_INCLUDE_DIR "${SDL2_PREFIX}/include")' in cmake
    assert 'target_include_directories(lvgl PRIVATE "${SDL2_INCLUDE_DIR}")' in cmake
    assert "target_compile_options(lvgl PRIVATE ${SDL2_CFLAGS_LIST})" in cmake
    assert "set(LV_CONF_BUILD_DISABLE_DEMOS OFF CACHE BOOL" in cmake


def test_build_script_requires_sdl2_and_writes_manifest_metadata():
    script = (REPO_ROOT / "scripts/build_host_macos.sh").read_text(encoding="utf-8")

    assert "command -v sdl2-config" in script
    assert "brew install sdl2" in script
    assert 'sdl2_version="$(sdl2-config --version)"' in script
    assert 'sdl2_cflags="$(sdl2-config --cflags)"' in script
    assert 'sdl2_libs="$(sdl2-config --libs)"' in script
    assert "display_backend=sdl2" in script
    assert "input_backend=sdl2" in script
    assert "sdl2.version=${sdl2_version}" in script
    assert "sdl2.cflags=${sdl2_cflags}" in script
    assert "sdl2.libs=${sdl2_libs}" in script
    assert "-DLV_CONF_BUILD_DISABLE_DEMOS=OFF" in script
    assert "cmake --build \"${build_dir}\" --target lvgl lvgl_demos" in script
    assert "cp \"${build_dir}/lib/liblvgl_demos.a\" \"${dist_dir}/lib/liblvgl_demos.a\"" in script
    assert "demo_widgets=enabled" in script
    assert "local_assets=enabled" in script
    assert "image_decoders=lodepng,tjpgd,bmp" in script
    assert "font_loader=tiny_ttf_file" in script
    assert "demo_lib_hash=${demo_lib_hash}" in script


def test_package_exports_widgets_demo_library_headers_and_manifest():
    script = (REPO_ROOT / "scripts/build_host_macos.sh").read_text(encoding="utf-8")
    verify = (REPO_ROOT / "scripts/verify_package.sh").read_text(encoding="utf-8")

    assert 'test -f "${dist_dir}/lib/liblvgl_demos.a"' in verify
    assert 'test -f "${dist_dir}/include/demos/widgets/lv_demo_widgets.h"' in verify
    assert 'test -f "${dist_dir}/include/demos/lv_demos.h"' in verify
    assert 'find "${source_dir}/demos" -type f -name' in script
    assert 'cp "${header}" "${dist_dir}/include/${relative_path}"' in script
    assert 'grep -q "demo_widgets=enabled" "${dist_dir}/lvgl_package.txt"' in verify
    assert 'grep -q "local_assets=enabled" "${dist_dir}/lvgl_package.txt"' in verify
    assert 'grep -q "image_decoders=lodepng,tjpgd,bmp" "${dist_dir}/lvgl_package.txt"' in verify
    assert 'grep -q "font_loader=tiny_ttf_file" "${dist_dir}/lvgl_package.txt"' in verify


def test_verify_script_compiles_resource_decoder_font_and_sdl2_demos():
    script = (REPO_ROOT / "scripts/verify_package.sh").read_text(encoding="utf-8")

    assert "examples/host_macos_sdl2_demo.c" in script
    assert "sdl2-config --cflags" in script
    assert "sdl2-config --libs" in script
    assert 'sdl2_include_dir="$(sdl2-config --prefix)/include"' in script
    assert '-I"${sdl2_include_dir}"' in script
    assert "LVGL_RUN_SDL2_DEMO" in script
    assert "host_macos_sdl2_demo" in script
    assert "verify_widgets_demo.c" in script
    assert '#include "demos/widgets/lv_demo_widgets.h"' in script
    assert "(void)lv_demo_widgets;" in script
    assert '"${dist_dir}/lib/liblvgl_demos.a"' in script
    assert "verify_local_assets.c" in script
    assert '#include "src/libs/lodepng/lv_lodepng.h"' in script
    assert '#include "src/libs/tjpgd/lv_tjpgd.h"' in script
    assert '#include "src/libs/bmp/lv_bmp.h"' in script
    assert '#include "src/libs/tiny_ttf/lv_tiny_ttf.h"' in script
    assert "void (*png_decoder_init)(void) = lv_lodepng_init;" in script
    assert "void (*jpg_decoder_init)(void) = lv_tjpgd_init;" in script
    assert "void (*bmp_decoder_init)(void) = lv_bmp_init;" in script
    assert "void (*tiny_ttf_init)(void) = lv_tiny_ttf_init;" in script
    assert "lv_font_t * (*create_font_from_file)(const char *, int32_t)" in script
    assert "(void)png_decoder_init;" in script
    assert "(void)jpg_decoder_init;" in script
    assert "(void)bmp_decoder_init;" in script
    assert "(void)tiny_ttf_init;" in script
    assert "(void)create_font_from_file;" in script
    assert '"${tmp_dir}/verify_local_assets"' in script


def test_sdl2_demo_uses_lvgl_sdl_window_input_and_label():
    demo = (REPO_ROOT / "examples/host_macos_sdl2_demo.c").read_text(encoding="utf-8")

    assert '#include "lvgl.h"' in demo
    assert '#include "src/drivers/sdl/lv_sdl_window.h"' in demo
    assert '#include "src/drivers/sdl/lv_sdl_mouse.h"' in demo
    assert '#include "src/drivers/sdl/lv_sdl_keyboard.h"' in demo
    assert "#include <SDL2/SDL.h>" in demo
    assert "lv_sdl_window_create(480, 320)" in demo
    assert "lv_sdl_mouse_create()" in demo
    assert "lv_sdl_keyboard_create()" in demo
    assert "lv_label_create(lv_screen_active())" in demo
    assert 'lv_label_set_text(label, "LVGL host macOS SDL2")' in demo
    assert "SDL_Delay(16)" in demo


def test_readme_and_ci_document_sdl2_dependency():
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    workflow = (REPO_ROOT / ".github/workflows/host-macos-package.yml").read_text(encoding="utf-8")

    assert "host macOS SDL2" in readme
    assert "brew install sdl2" in readme
    assert "LVGL_RUN_SDL2_DEMO=1 ./scripts/verify_package.sh" in readme
    assert "brew install sdl2" in workflow
