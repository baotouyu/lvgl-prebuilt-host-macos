#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lvgl_tag="v9.1.0"
lvgl_commit="e1c0b21b2723d391b885de4b2ee5cc997eccca91"
lvgl_url="https://github.com/lvgl/lvgl.git"
source_dir="${repo_root}/src/lvgl"
build_dir="${repo_root}/build/host_macos"
dist_dir="${repo_root}/dist/lvgl/host_macos"

if ! command -v sdl2-config >/dev/null 2>&1; then
  echo "sdl2-config not found. Install SDL2 with: brew install sdl2" >&2
  exit 1
fi

sdl2_version="$(sdl2-config --version)"
sdl2_cflags="$(sdl2-config --cflags)"
sdl2_libs="$(sdl2-config --libs)"

mkdir -p "${repo_root}/src"

if [ ! -d "${source_dir}/.git" ]; then
  git clone --branch "${lvgl_tag}" --depth 1 "${lvgl_url}" "${source_dir}"
fi

actual_commit="$(git -C "${source_dir}" rev-parse HEAD)"
if [ "${actual_commit}" != "${lvgl_commit}" ]; then
  echo "LVGL commit mismatch: expected ${lvgl_commit}, got ${actual_commit}" >&2
  exit 1
fi

cmake -S "${repo_root}" -B "${build_dir}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="$(uname -m)" \
  -DLV_CONF_PATH="${repo_root}/config/host_macos/lv_conf.h" \
  -DLV_CONF_BUILD_DISABLE_EXAMPLES=ON \
  -DLV_CONF_BUILD_DISABLE_DEMOS=OFF \
  -DLV_CONF_BUILD_DISABLE_THORVG_INTERNAL=ON

cmake --build "${build_dir}" --target lvgl lvgl_demos

rm -rf "${dist_dir}"
mkdir -p "${dist_dir}/include" "${dist_dir}/lib"

cp "${build_dir}/lib/liblvgl.a" "${dist_dir}/lib/liblvgl.a"
cp "${build_dir}/lib/liblvgl_demos.a" "${dist_dir}/lib/liblvgl_demos.a"
cp "${source_dir}/lvgl.h" "${dist_dir}/include/lvgl.h"
cp "${repo_root}/config/host_macos/lv_conf.h" "${dist_dir}/include/lv_conf.h"
cp "${source_dir}/LICENCE.txt" "${dist_dir}/LVGL_LICENCE.txt"

find "${source_dir}/src" -type f -name '*.h' | while IFS= read -r header; do
  relative_path="${header#${source_dir}/}"
  mkdir -p "${dist_dir}/include/$(dirname "${relative_path}")"
  cp "${header}" "${dist_dir}/include/${relative_path}"
done

find "${source_dir}/demos" -type f -name '*.h' | while IFS= read -r header; do
  relative_path="${header#${source_dir}/}"
  mkdir -p "${dist_dir}/include/$(dirname "${relative_path}")"
  cp "${header}" "${dist_dir}/include/${relative_path}"
done

lib_hash="$(shasum -a 256 "${dist_dir}/lib/liblvgl.a" | awk '{print $1}')"
demo_lib_hash="$(shasum -a 256 "${dist_dir}/lib/liblvgl_demos.a" | awk '{print $1}')"
conf_hash="$(shasum -a 256 "${dist_dir}/include/lv_conf.h" | awk '{print $1}')"
toolchain="$(cc --version | head -1)"
arch="$(uname -m)"

cat > "${dist_dir}/lvgl_package.txt" <<EOF
lvgl.version=9.1.0
lvgl.tag=${lvgl_tag}
lvgl.commit=${lvgl_commit}
platform=host_macos
display_backend=sdl2
input_backend=sdl2
toolchain=${toolchain}
arch=${arch}
sdl2.version=${sdl2_version}
sdl2.cflags=${sdl2_cflags}
sdl2.libs=${sdl2_libs}
demo_widgets=enabled
local_assets=enabled
filesystem=stdio:A
image_decoders=lodepng,tjpgd,bmp
font_loader=tiny_ttf_file
lv_conf_hash=${conf_hash}
lib_hash=${lib_hash}
demo_lib_hash=${demo_lib_hash}
EOF

echo "LVGL host macOS package generated at ${dist_dir}"
