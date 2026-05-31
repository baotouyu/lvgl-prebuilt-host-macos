# host macOS SDL2 LVGL 适配包 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `lvgl-prebuilt-host-macos` 从纯 LVGL 核心预编译包升级为启用 SDL2 display/input backend 的 host macOS LVGL 包。

**Architecture:** 本仓库负责 host macOS 的 LVGL 适配，启用 LVGL 官方 SDL2 driver，并输出带 manifest 的 `dist/lvgl/host_macos` 包。验证分两层：核心 `lv_init/lv_deinit` smoke 必跑，SDL2 demo 必须编译；本地有图形环境时运行 SDL2 demo，CI 可以只做编译验证以保持稳定。

**Tech Stack:** Bash、CMake、C11、LVGL v9.1.0、Homebrew SDL2、GitHub Actions macOS runner。

---

## 文件结构

- Modify: `config/host_macos/lv_conf.h`
  - 启用 `LV_USE_SDL=1`。
  - 保持 `LV_USE_DRAW_SDL=0`，不引入 SDL2_image。
  - 明确 SDL2 render mode、buffer count、fullscreen、direct exit 和 mouse wheel 模式。
- Modify: `CMakeLists.txt`
  - 检查 `sdl2-config`。
  - 从 `sdl2-config --cflags` 读取 SDL2 include flags。
  - 给 `lvgl` target 增加 SDL2 include 和 compile options。
- Modify: `scripts/build_host_macos.sh`
  - 构建前检查 `sdl2-config`。
  - 记录 SDL2 版本、cflags、libs 到 `lvgl_package.txt`。
  - manifest 增加 `display_backend=sdl2` 和 `input_backend=sdl2`。
- Modify: `scripts/verify_package.sh`
  - 保留核心 smoke。
  - 编译 SDL2 demo。
  - 默认不在 CI 强制运行窗口 demo。
  - 支持 `LVGL_RUN_SDL2_DEMO=1` 时运行窗口 demo。
- Create: `examples/host_macos_sdl2_demo.c`
  - 最小 SDL2 window、mouse、keyboard、label demo。
  - 自动运行若干帧后退出。
- Modify: `README.md`
  - 更新仓库职责。
  - 写明 `brew install sdl2`。
  - 写明 build、verify 和本地运行 SDL2 demo 的方式。
- Modify: `.github/workflows/host-macos-package.yml`
  - build 前安装 SDL2。
- Create: `tests/test_host_macos_sdl2_package.py`
  - 用 pytest 检查配置、脚本、README、workflow 和 demo 源码。

## Task 1: 添加 SDL2 包结构红测

**Files:**
- Create: `tests/test_host_macos_sdl2_package.py`

- [ ] **Step 1: 写失败测试**

Create `tests/test_host_macos_sdl2_package.py`:

```python
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


def test_cmake_wires_sdl2_config_into_lvgl_target():
    cmake = (REPO_ROOT / "CMakeLists.txt").read_text(encoding="utf-8")

    assert "find_program(SDL2_CONFIG_EXECUTABLE sdl2-config REQUIRED)" in cmake
    assert "execute_process(COMMAND ${SDL2_CONFIG_EXECUTABLE} --cflags" in cmake
    assert "separate_arguments(SDL2_CFLAGS_LIST NATIVE_COMMAND" in cmake
    assert "target_compile_options(lvgl PRIVATE ${SDL2_CFLAGS_LIST})" in cmake


def test_build_script_requires_sdl2_and_writes_manifest_metadata():
    script = (REPO_ROOT / "scripts/build_host_macos.sh").read_text(encoding="utf-8")

    assert "command -v sdl2-config" in script
    assert "brew install sdl2" in script
    assert "sdl2_version=\"$(sdl2-config --version)\"" in script
    assert "sdl2_cflags=\"$(sdl2-config --cflags)\"" in script
    assert "sdl2_libs=\"$(sdl2-config --libs)\"" in script
    assert "display_backend=sdl2" in script
    assert "input_backend=sdl2" in script
    assert "sdl2.version=${sdl2_version}" in script
    assert "sdl2.cflags=${sdl2_cflags}" in script
    assert "sdl2.libs=${sdl2_libs}" in script


def test_verify_script_compiles_sdl2_demo_and_runs_only_when_requested():
    script = (REPO_ROOT / "scripts/verify_package.sh").read_text(encoding="utf-8")

    assert "examples/host_macos_sdl2_demo.c" in script
    assert "sdl2-config --cflags" in script
    assert "sdl2-config --libs" in script
    assert "LVGL_RUN_SDL2_DEMO" in script
    assert "host_macos_sdl2_demo" in script


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
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```bash
pytest tests/test_host_macos_sdl2_package.py -v
```

Expected:

```text
FAILED tests/test_host_macos_sdl2_package.py::test_lv_conf_enables_sdl2_without_sdl_draw_backend
```

至少第一个测试应失败，因为当前 `LV_USE_SDL` 仍为 `0`。

## Task 2: 启用 SDL2 配置和 CMake 接线

**Files:**
- Modify: `config/host_macos/lv_conf.h`
- Modify: `CMakeLists.txt`
- Test: `tests/test_host_macos_sdl2_package.py`

- [ ] **Step 1: 修改 LVGL 配置**

Modify `config/host_macos/lv_conf.h` after draw config block and before demo config:

```c
#define LV_USE_DRAW_SDL 0

#define LV_USE_SDL 1
#define LV_SDL_INCLUDE_PATH <SDL2/SDL.h>
#define LV_SDL_RENDER_MODE LV_DISPLAY_RENDER_MODE_PARTIAL
#define LV_SDL_BUF_COUNT 1
#define LV_SDL_ACCELERATED 0
#define LV_SDL_FULLSCREEN 0
#define LV_SDL_DIRECT_EXIT 0
#define LV_SDL_MOUSEWHEEL_MODE LV_SDL_MOUSEWHEEL_MODE_ENCODER
```

Keep existing:

```c
#define LV_USE_OS LV_OS_NONE
#define LV_USE_DRAW_SW 1
#define LV_USE_DRAW_DAVE2D 0
```

- [ ] **Step 2: 修改 CMake 读取 SDL2 flags**

Modify `CMakeLists.txt` after config checks and before `add_subdirectory`:

```cmake
find_program(SDL2_CONFIG_EXECUTABLE sdl2-config REQUIRED)

execute_process(
  COMMAND ${SDL2_CONFIG_EXECUTABLE} --cflags
  OUTPUT_VARIABLE SDL2_CFLAGS
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

separate_arguments(SDL2_CFLAGS_LIST NATIVE_COMMAND "${SDL2_CFLAGS}")
```

Modify after `add_subdirectory("${LVGL_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/lvgl")`:

```cmake
target_compile_options(lvgl PRIVATE ${SDL2_CFLAGS_LIST})
```

- [ ] **Step 3: 运行结构测试确认相关项通过**

Run:

```bash
pytest tests/test_host_macos_sdl2_package.py::test_lv_conf_enables_sdl2_without_sdl_draw_backend tests/test_host_macos_sdl2_package.py::test_cmake_wires_sdl2_config_into_lvgl_target -v
```

Expected:

```text
2 passed
```

- [ ] **Step 4: 提交配置和 CMake**

Run:

```bash
git add config/host_macos/lv_conf.h CMakeLists.txt tests/test_host_macos_sdl2_package.py
git commit -m "feat: 启用 host macOS SDL2 LVGL 配置"
```

## Task 3: 更新构建脚本和 manifest

**Files:**
- Modify: `scripts/build_host_macos.sh`
- Test: `tests/test_host_macos_sdl2_package.py`

- [ ] **Step 1: 在构建脚本中增加 SDL2 检查**

Modify `scripts/build_host_macos.sh` after variable definitions:

```bash
if ! command -v sdl2-config >/dev/null 2>&1; then
  echo "sdl2-config not found. Install SDL2 with: brew install sdl2" >&2
  exit 1
fi

sdl2_version="$(sdl2-config --version)"
sdl2_cflags="$(sdl2-config --cflags)"
sdl2_libs="$(sdl2-config --libs)"
```

- [ ] **Step 2: 增加 manifest 字段**

Modify manifest heredoc in `scripts/build_host_macos.sh`:

```bash
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
lv_conf_hash=${conf_hash}
lib_hash=${lib_hash}
EOF
```

- [ ] **Step 3: 运行脚本结构测试**

Run:

```bash
pytest tests/test_host_macos_sdl2_package.py::test_build_script_requires_sdl2_and_writes_manifest_metadata -v
```

Expected:

```text
1 passed
```

- [ ] **Step 4: 提交构建脚本**

Run:

```bash
git add scripts/build_host_macos.sh
git commit -m "feat: 记录 host macOS SDL2 包元数据"
```

## Task 4: 增加 SDL2 demo 和验证脚本

**Files:**
- Create: `examples/host_macos_sdl2_demo.c`
- Modify: `scripts/verify_package.sh`
- Test: `tests/test_host_macos_sdl2_package.py`

- [ ] **Step 1: 新增 demo 源码**

Create `examples/host_macos_sdl2_demo.c`:

```c
#include "lvgl.h"
#include "src/drivers/sdl/lv_sdl_keyboard.h"
#include "src/drivers/sdl/lv_sdl_mouse.h"
#include "src/drivers/sdl/lv_sdl_window.h"

#include <SDL2/SDL.h>

int main(void)
{
    lv_display_t *display;
    lv_indev_t *mouse;
    lv_indev_t *keyboard;
    lv_obj_t *label;
    int i;

    lv_init();

    display = lv_sdl_window_create(480, 320);
    if (display == 0) {
        lv_deinit();
        return 1;
    }

    mouse = lv_sdl_mouse_create();
    if (mouse == 0) {
        lv_deinit();
        return 2;
    }

    keyboard = lv_sdl_keyboard_create();
    if (keyboard == 0) {
        lv_deinit();
        return 3;
    }

    label = lv_label_create(lv_screen_active());
    if (label == 0) {
        lv_deinit();
        return 4;
    }

    lv_label_set_text(label, "LVGL host macOS SDL2");
    lv_obj_center(label);

    for (i = 0; i < 30; ++i) {
        (void)lv_timer_handler();
        SDL_Delay(16);
    }

    lv_deinit();
    return 0;
}
```

- [ ] **Step 2: 修改 verify 脚本编译 demo**

Modify `scripts/verify_package.sh` after core smoke compile/run:

```bash
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
```

- [ ] **Step 3: 运行 demo 和 verify 结构测试**

Run:

```bash
pytest tests/test_host_macos_sdl2_package.py::test_verify_script_compiles_sdl2_demo_and_runs_only_when_requested tests/test_host_macos_sdl2_package.py::test_sdl2_demo_uses_lvgl_sdl_window_input_and_label -v
```

Expected:

```text
2 passed
```

- [ ] **Step 4: 提交 demo 和验证脚本**

Run:

```bash
git add examples/host_macos_sdl2_demo.c scripts/verify_package.sh
git commit -m "feat: 增加 host macOS SDL2 LVGL 验证 demo"
```

## Task 5: 更新 README 和 CI

**Files:**
- Modify: `README.md`
- Modify: `.github/workflows/host-macos-package.yml`
- Test: `tests/test_host_macos_sdl2_package.py`

- [ ] **Step 1: 更新 README 职责和依赖**

Modify `README.md` to include:

```markdown
# lvgl-prebuilt-host-macos

这个仓库负责为 Mac host 产出已适配 SDL2 的 LVGL 9.1 预编译包。

它的职责是：

- 固定 LVGL 官方版本。
- 使用 Mac 工具链编译 `liblvgl.a`。
- 启用 host macOS SDL2 display/input backend。
- 导出成 `embedded-platform-core` 可以消费的包结构。

它不负责：

- 编译匠芯创 Luban-Lite 的 LVGL。
- 编译全志 Linux 的 LVGL。
- 封装 LVGL 控件 API。
- 适配 `embedded-platform-core` 的业务 UI。

## 依赖

```bash
brew install sdl2
```

## 本地运行 SDL2 demo

```bash
LVGL_RUN_SDL2_DEMO=1 ./scripts/verify_package.sh
```
```

Keep existing package structure, build, verify, and version sections, but update wording to mention SDL2 backend.

- [ ] **Step 2: 更新 GitHub Actions 安装 SDL2**

Modify `.github/workflows/host-macos-package.yml`:

```yaml
      - name: Install SDL2
        run: brew install sdl2

      - name: Build LVGL package
        run: ./scripts/build_host_macos.sh
```

- [ ] **Step 3: 运行 README/CI 测试**

Run:

```bash
pytest tests/test_host_macos_sdl2_package.py::test_readme_and_ci_document_sdl2_dependency -v
```

Expected:

```text
1 passed
```

- [ ] **Step 4: 提交 README 和 CI**

Run:

```bash
git add README.md .github/workflows/host-macos-package.yml
git commit -m "docs: 说明 host macOS SDL2 LVGL 包依赖"
```

## Task 6: 构建并验证包

**Files:**
- Generated: `dist/lvgl/host_macos/**`

- [ ] **Step 1: 运行完整结构测试**

Run:

```bash
pytest tests/test_host_macos_sdl2_package.py -v
```

Expected:

```text
6 passed
```

- [ ] **Step 2: 构建 LVGL 包**

Run:

```bash
./scripts/build_host_macos.sh
```

Expected:

```text
LVGL host macOS package generated at .../dist/lvgl/host_macos
```

- [ ] **Step 3: 验证包**

Run:

```bash
./scripts/verify_package.sh
```

Expected:

```text
LVGL host macOS package verified.
```

Expected note:

```text
SDL2 LVGL demo compiled. Set LVGL_RUN_SDL2_DEMO=1 to run it locally.
```

- [ ] **Step 4: 本地可选运行窗口 demo**

Run only on local Mac:

```bash
LVGL_RUN_SDL2_DEMO=1 ./scripts/verify_package.sh
```

Expected:

```text
出现短暂 LVGL SDL2 窗口后自动退出
```

If the window cannot open in the current environment, do not block CI; report the exact error and continue with compiled demo verification.

- [ ] **Step 5: 检查 manifest**

Run:

```bash
cat dist/lvgl/host_macos/lvgl_package.txt
```

Expected includes:

```text
display_backend=sdl2
input_backend=sdl2
sdl2.version=
sdl2.cflags=
sdl2.libs=
```

- [ ] **Step 6: 提交 dist 更新**

Run:

```bash
git add dist/lvgl/host_macos
git commit -m "build: 更新 host macOS SDL2 LVGL 预编译包"
```

## Task 7: 全量验证和 PR

**Files:**
- Verify and GitHub PR.

- [ ] **Step 1: 运行最终验证**

Run:

```bash
pytest tests/test_host_macos_sdl2_package.py -v
./scripts/build_host_macos.sh
./scripts/verify_package.sh
git diff --check
git status --short --branch
```

Expected:

```text
pytest 通过
构建通过
验证通过
git diff --check 无输出
工作树干净
```

- [ ] **Step 2: 推送分支**

Run:

```bash
git push -u origin docs/host-macos-sdl2-design
```

- [ ] **Step 3: 创建中文 PR**

Run:

```bash
gh pr create --base main --head docs/host-macos-sdl2-design --title "feat: 启用 host macOS SDL2 LVGL 适配包" --body "$(cat <<'EOF'
## Summary
- 启用 LVGL 官方 SDL2 display/input backend
- 增加 host macOS SDL2 demo 编译验证
- manifest 记录 SDL2 后端和链接信息
- 更新 README 和 GitHub Actions SDL2 依赖

## Validation
- [x] `pytest tests/test_host_macos_sdl2_package.py -v`
- [x] `./scripts/build_host_macos.sh`
- [x] `./scripts/verify_package.sh`
- [x] `git diff --check`

## Notes
- 本 PR 不封装 LVGL 控件 API
- 本 PR 不适配 Luban-Lite 或全志 Linux
- SDL2 window demo 默认只编译；本地可用 `LVGL_RUN_SDL2_DEMO=1 ./scripts/verify_package.sh` 运行窗口
EOF
)"
```

- [ ] **Step 4: 等待 CI**

Run:

```bash
gh pr checks --watch --interval 5
```

Expected:

```text
build-host-macos-package pass
```

- [ ] **Step 5: squash merge**

Run:

```bash
gh pr merge --squash --delete-branch --subject "feat: 启用 host macOS SDL2 LVGL 适配包" --body $'启用 host macOS SDL2 LVGL 适配包：\n\n- 启用 LVGL 官方 SDL2 display/input backend\n- 增加 SDL2 demo 编译验证\n- manifest 记录 SDL2 后端和链接信息\n- 更新 README 和 GitHub Actions SDL2 依赖'
```

- [ ] **Step 6: 清理本地**

If `gh pr merge` fails local cleanup because `main` is already used by the main worktree, run:

```bash
cd /Users/yuwei/Documents/KitchenIdea/项目/C08/lvgl-prebuilt-host-macos
git pull --ff-only
git worktree remove .worktrees/docs-host-macos-sdl2-design
git branch -d docs/host-macos-sdl2-design
git push origin --delete docs/host-macos-sdl2-design
git fetch --prune
git status --short --branch
git branch -vv
git branch -r
git worktree list
```
