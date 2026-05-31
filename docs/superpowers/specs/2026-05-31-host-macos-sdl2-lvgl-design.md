# host macOS SDL2 LVGL 适配包设计

## 背景

当前仓库已经可以为 Mac host 构建 LVGL 9.1.0 静态库，并导出 `include/`、`lv_conf.h`、`liblvgl.a` 和 `lvgl_package.txt`。这个包已经被 `embedded-platform-core` 消费，用来完成 LVGL 最小生命周期接口。

但当前 `config/host_macos/lv_conf.h` 没有启用 SDL2：

```c
#define LV_USE_SDL 0
#define LV_USE_DRAW_SDL 0
```

这意味着包只能验证 `lv_init()`、`lv_deinit()` 这类核心 API，不能创建 macOS 窗口，也不能验证 display、mouse、keyboard 这些平台 port。

新的工程边界是：

- 每个平台的 LVGL 仓库负责把 LVGL 针对该平台适配好。
- `embedded-platform-core` 只消费适配好的头文件、配置、静态库和 manifest。

因此 host macOS 的 SDL2 display/input 适配应该放在本仓库，而不是放进 `embedded-platform-core`。

## 目标

- 将本仓库职责从“只构建 LVGL 核心静态库”扩展为“构建已适配 host macOS SDL2 的 LVGL 包”。
- 启用 LVGL 官方 SDL2 driver，支持 `lv_sdl_window_create()`、`lv_sdl_mouse_create()`、`lv_sdl_keyboard_create()`。
- 保持 LVGL 官方版本仍固定为 `v9.1.0`。
- 构建脚本检查并使用 Homebrew SDL2。
- 验证脚本编译并运行一个最小 SDL2 窗口 demo。
- `lvgl_package.txt` 记录 display/input 后端和 SDL2 版本。
- README 用中文说明本仓库负责 host macOS 的 LVGL SDL2 适配，主工程只消费包。

## 非目标

- 不在本仓库封装 LVGL 控件 API。
- 不在本仓库适配匠芯创 Luban-Lite。
- 不在本仓库适配全志 Linux。
- 不改变 LVGL 版本。
- 不引入 `embedded-platform-core` 依赖。
- 不把 SDL2 源码 vendor 进仓库。
- 不做复杂 demo，只做最小窗口、输入和 label 验证。
- 不解决代码签名、打包 app bundle 或发布安装包。

## 方案比较

### 方案一：继续保持纯核心 LVGL 包

继续只构建 `liblvgl.a`，不启用 SDL2。

优点：

- 包最小。
- 不需要额外依赖。

缺点：

- 无法在 host macOS 上验证真实 LVGL display/input。
- `embedded-platform-core` 后续如果想看到窗口，会被迫自己做移植，破坏仓库边界。
- 不能体现“每个平台 LVGL 仓库负责适配好”的思路。

### 方案二：启用 LVGL 官方 SDL2 driver

在 `lv_conf.h` 中启用：

```c
#define LV_USE_SDL 1
#define LV_SDL_INCLUDE_PATH <SDL2/SDL.h>
#define LV_SDL_RENDER_MODE LV_DISPLAY_RENDER_MODE_PARTIAL
#define LV_SDL_BUF_COUNT 1
#define LV_SDL_ACCELERATED 0
#define LV_USE_DRAW_SDL 0
```

使用 Homebrew 安装的 SDL2 头文件和库构建 LVGL。验证 demo 调用：

- `lv_init()`
- `lv_sdl_window_create(480, 320)`
- `lv_sdl_mouse_create()`
- `lv_sdl_keyboard_create()`
- `lv_label_create()`
- 多次 `lv_timer_handler()`
- `lv_deinit()`

优点：

- 使用 LVGL 官方 host 模拟器路径。
- macOS 开发体验清晰，后续可以直接看到窗口。
- 包的职责完整：核心、配置、display/input backend、验证 demo 都在同一仓库。
- 不需要主工程理解 SDL2 移植细节。

缺点：

- 构建环境必须有 SDL2。
- 消费这个 `liblvgl.a` 的上层如果调用 SDL2 driver，也需要链接 SDL2。

### 方案三：自己写 macOS 原生 Cocoa display port

不用 SDL2，直接写 macOS 原生窗口和输入适配。

优点：

- 可以避免 SDL2 运行时依赖。
- 更贴近 macOS 原生窗口系统。

缺点：

- 实现成本高。
- 需要 Objective-C/Cocoa 边界，复杂度明显增加。
- 和未来 Linux/RTOS 平台迁移经验不通用。
- 第一阶段没有必要。

## 推荐方案

采用方案二：启用 LVGL 官方 SDL2 driver。

理由：

- LVGL 官方文档推荐 PC simulator 使用 SDL2。
- 当前目标是 host macOS 快速跑出真实窗口，而不是做 macOS 原生窗口框架。
- SDL2 依赖可通过 Homebrew 管理，GitHub Actions 的 macOS runner 也可以安装。
- 后续全志 Linux 和匠芯创 Luban-Lite 仍然各自维护独立 LVGL 包，不受这个 host macOS 包影响。

## 配置设计

修改 `config/host_macos/lv_conf.h`：

```c
#define LV_USE_SDL 1
#define LV_SDL_INCLUDE_PATH <SDL2/SDL.h>
#define LV_SDL_RENDER_MODE LV_DISPLAY_RENDER_MODE_PARTIAL
#define LV_SDL_BUF_COUNT 1
#define LV_SDL_ACCELERATED 0
#define LV_SDL_FULLSCREEN 0
#define LV_SDL_DIRECT_EXIT 0
#define LV_SDL_MOUSEWHEEL_MODE LV_SDL_MOUSEWHEEL_MODE_ENCODER

#define LV_USE_DRAW_SDL 0
```

第一版不启用 `LV_USE_DRAW_SDL`，继续使用软件渲染。原因是 `LV_USE_DRAW_SDL` 会引入 `SDL2_image`，第一阶段没有必要。

`LV_USE_OS` 继续保持 `LV_OS_NONE`。SDL2 driver 内部使用 `SDL_GetTicks()` 给 LVGL tick callback，第一版不引入 pthread 或 LVGL OS 抽象。

## 构建脚本设计

`scripts/build_host_macos.sh` 增加 SDL2 检查：

- 优先使用 `sdl2-config`。
- 如果不存在，提示安装：

```bash
brew install sdl2
```

CMake 配置时传入 SDL2 头文件和链接参数，或在顶层 `CMakeLists.txt` 中通过 `sdl2-config` 查询 include/lib flags。

构建目标仍然是：

```bash
cmake --build "${build_dir}" --target lvgl
```

产物仍然放在：

```text
dist/lvgl/host_macos/
```

## CMake 设计

顶层 `CMakeLists.txt` 负责：

- 检查 `sdl2-config`。
- 读取 SDL2 include flags。
- 读取 SDL2 lib flags。
- 把 SDL2 include 传给 `lvgl` target。
- 把 SDL2 链接参数记录给 demo/verify 使用。

需要注意：

- `liblvgl.a` 是静态库，静态库本身不会“保存”所有外部动态库依赖。
- 消费方只要调用 SDL2 driver 符号，最终链接可执行文件时仍然需要链接 SDL2。
- 因此 `lvgl_package.txt` 必须记录 SDL2 链接要求。

## 验证 demo 设计

新增 `examples/host_macos_sdl2_demo.c` 或由 `scripts/verify_package.sh` 临时生成 demo。

第一版建议在仓库中保留 demo 源码，原因是它本身就是包的契约示例。

demo 行为：

```c
lv_init();
lv_display_t *display = lv_sdl_window_create(480, 320);
lv_indev_t *mouse = lv_sdl_mouse_create();
lv_indev_t *keyboard = lv_sdl_keyboard_create();
lv_obj_t *label = lv_label_create(lv_screen_active());
lv_label_set_text(label, "LVGL host macOS SDL2");
lv_obj_center(label);
循环若干次：
  lv_timer_handler();
  SDL_Delay(16);
lv_deinit();
```

demo 只验证：

- LVGL 能创建 SDL2 window。
- mouse/keyboard input device 可以创建。
- 基础 widget 可以创建。
- timer handler 可以跑。
- 程序可以自动退出。

demo 不要求人工关闭窗口，不做截图断言。

## 包 manifest 设计

`lvgl_package.txt` 增加字段：

```text
display_backend=sdl2
input_backend=sdl2
sdl2.version=<sdl2-config --version>
sdl2.cflags=<sdl2-config --cflags>
sdl2.libs=<sdl2-config --libs>
```

这些字段用于提醒消费方：

- 这个包已经包含 LVGL SDL2 driver。
- 需要显示窗口或输入时，最终可执行文件要链接 SDL2。
- 如果主工程只调用 `lv_init()` 等核心 API，也可以暂时不使用窗口 driver，但链接策略后续要统一处理。

## README 更新

README 需要调整职责说明：

旧职责：

- 不提供显示窗口、输入设备或平台 port。

新职责：

- 提供 host macOS 的 LVGL 9.1.0 预编译包。
- 该包启用 SDL2 display/input backend。
- `embedded-platform-core` 只消费这个包，不在主工程里适配 LVGL host macOS。

README 需要补充依赖：

```bash
brew install sdl2
```

并说明验证命令：

```bash
./scripts/build_host_macos.sh
./scripts/verify_package.sh
```

## CI 设计

GitHub Actions 继续使用 `macos-latest`。

在 build 前增加：

```bash
brew install sdl2
```

CI 验证：

- 构建 LVGL 包。
- 编译最小 SDL2 demo。
- 运行 demo。

如果 GitHub Actions 无法打开图形窗口，需要将验证 demo 设计成可以在 macOS runner 上短暂运行。如果远端环境不允许窗口显示，则 CI 至少编译 demo；本地机器负责运行窗口 demo。这个差异需要在验证脚本里显式处理，不能让 CI 长期不稳定。

第一版倾向：

- `scripts/verify_package.sh` 默认编译并运行核心 `lv_init/lv_deinit` smoke。
- 在本地检测到可用图形环境时运行 SDL2 demo。
- CI 至少编译 SDL2 demo，保证链接参数正确。

## 验收标准

- `./scripts/build_host_macos.sh` 成功。
- `./scripts/verify_package.sh` 成功。
- `dist/lvgl/host_macos/include/lv_conf.h` 中 `LV_USE_SDL` 为 `1`。
- `dist/lvgl/host_macos/include/src/drivers/sdl/*.h` 仍随包导出。
- `dist/lvgl/host_macos/lib/liblvgl.a` 包含 SDL2 driver 对应对象。
- `lvgl_package.txt` 记录 `display_backend=sdl2`、`input_backend=sdl2` 和 SDL2 版本。
- README 说明本仓库负责 host macOS SDL2 适配。
- GitHub Actions 通过。

## 后续扩展

本设计完成后，后续步骤是：

- 把新包同步到 `embedded-platform-core`。
- 在 `embedded-platform-core` 的 CMake 中补充 host macOS SDL2 链接信息。
- 在主工程增加一个可选 host UI demo target。
- 后续为全志 Linux、匠芯创 Luban-Lite 分别建立自己的 LVGL prebuilt 仓库。
