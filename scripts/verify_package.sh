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

echo "LVGL host macOS package verified."
