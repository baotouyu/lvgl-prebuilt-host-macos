#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${repo_root}/dist/lvgl/host_macos"
tmp_dir="${repo_root}/build/verify"

test -f "${dist_dir}/include/lvgl.h"
test -f "${dist_dir}/include/lv_conf.h"
test -f "${dist_dir}/lib/liblvgl.a"
test -f "${dist_dir}/lib/liblvgl_demos.a"
test -f "${dist_dir}/LVGL_LICENCE.txt"
test -f "${dist_dir}/lvgl_package.txt"
test -f "${dist_dir}/include/demos/lv_demos.h"
test -f "${dist_dir}/include/demos/widgets/lv_demo_widgets.h"
grep -q "demo_widgets=enabled" "${dist_dir}/lvgl_package.txt"
grep -q "local_assets=enabled" "${dist_dir}/lvgl_package.txt"
grep -q "image_decoders=lodepng,tjpgd,bmp" "${dist_dir}/lvgl_package.txt"
grep -q "font_loader=tiny_ttf_file" "${dist_dir}/lvgl_package.txt"

rm -rf "${tmp_dir}"
mkdir -p "${tmp_dir}"

cat > "${tmp_dir}/verify_lvgl.c" <<'EOF'
#include "lvgl.h"

int main(void)
{
    lv_init();
    lv_deinit();
    return 0;
}
EOF

cc -std=c11 \
  -I"${dist_dir}/include" \
  "${tmp_dir}/verify_lvgl.c" \
  "${dist_dir}/lib/liblvgl.a" \
  -o "${tmp_dir}/verify_lvgl"

"${tmp_dir}/verify_lvgl"

cat > "${tmp_dir}/verify_widgets_demo.c" <<'EOF'
#include "lvgl.h"
#include "demos/widgets/lv_demo_widgets.h"

int main(void)
{
    (void)lv_demo_widgets;
    return 0;
}
EOF

cc -std=c11 \
  -I"${dist_dir}/include" \
  "${tmp_dir}/verify_widgets_demo.c" \
  "${dist_dir}/lib/liblvgl_demos.a" \
  "${dist_dir}/lib/liblvgl.a" \
  -o "${tmp_dir}/verify_widgets_demo"

cat > "${tmp_dir}/verify_local_assets.c" <<'EOF'
#include "lvgl.h"
#include "src/libs/lodepng/lv_lodepng.h"
#include "src/libs/tjpgd/lv_tjpgd.h"
#include "src/libs/bmp/lv_bmp.h"
#include "src/libs/tiny_ttf/lv_tiny_ttf.h"

int main(void)
{
    lv_init();
    lv_lodepng_init();
    lv_tjpgd_init();
    lv_bmp_init();
    lv_tiny_ttf_init();

    (void)lv_tiny_ttf_create_file("A:/tmp/font.ttf", 16);

    lv_tiny_ttf_deinit();
    lv_bmp_deinit();
    lv_tjpgd_deinit();
    lv_lodepng_deinit();
    lv_deinit();
    return 0;
}
EOF

cc -std=c11 \
  -I"${dist_dir}/include" \
  "${tmp_dir}/verify_local_assets.c" \
  "${dist_dir}/lib/liblvgl.a" \
  -o "${tmp_dir}/verify_local_assets"

sdl2_cflags="$(sdl2-config --cflags)"
sdl2_libs="$(sdl2-config --libs)"
sdl2_include_dir="$(sdl2-config --prefix)/include"
sdl2_demo="${tmp_dir}/host_macos_sdl2_demo"

cc -std=c11 \
  -I"${dist_dir}/include" \
  -I"${sdl2_include_dir}" \
  ${sdl2_cflags} \
  "${repo_root}/examples/host_macos_sdl2_demo.c" \
  "${dist_dir}/lib/liblvgl.a" \
  ${sdl2_libs} \
  -o "${sdl2_demo}"

if [ "${LVGL_RUN_SDL2_DEMO:-0}" = "1" ]; then
  "${sdl2_demo}"
else
  echo "SDL2 LVGL demo compiled. Set LVGL_RUN_SDL2_DEMO=1 to run it locally."
fi

echo "LVGL host macOS package verified."
