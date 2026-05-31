#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${repo_root}/dist/lvgl/host_macos"
tmp_dir="${repo_root}/build/verify"

test -f "${dist_dir}/include/lvgl.h"
test -f "${dist_dir}/include/lv_conf.h"
test -f "${dist_dir}/lib/liblvgl.a"
test -f "${dist_dir}/LVGL_LICENCE.txt"
test -f "${dist_dir}/lvgl_package.txt"

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

sdl2_cflags="$(sdl2-config --cflags)"
sdl2_libs="$(sdl2-config --libs)"
sdl2_demo="${tmp_dir}/host_macos_sdl2_demo"

cc -std=c11 \
  -I"${dist_dir}/include" \
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
