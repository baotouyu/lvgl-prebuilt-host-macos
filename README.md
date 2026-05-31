# lvgl-prebuilt-host-macos

这个仓库负责为 Mac host 产出 LVGL 9.1 预编译包。

它的职责是：

- 固定 LVGL 官方版本。
- 使用 Mac 工具链编译 `liblvgl.a`。
- 导出成 `embedded-platform-core` 可以消费的包结构。

它不负责：

- 编译匠芯创 Luban-Lite 的 LVGL。
- 编译全志 Linux 的 LVGL。
- 封装 LVGL 控件 API。
- 提供显示窗口、输入设备或平台 port。

## 产物结构

构建后生成：

```text
dist/lvgl/host_macos/
  include/
    lvgl.h
    lv_conf.h
    src/
      ... 只包含 LVGL 头文件
  lib/
    liblvgl.a
  LVGL_LICENCE.txt
  lvgl_package.txt
```

`include/`、`lv_conf.h`、`lib/liblvgl.a` 必须成套使用，不能和其他平台的 LVGL 包混用。

## 构建

```bash
./scripts/build_host_macos.sh
```

## 验证

```bash
./scripts/verify_package.sh
```

## 版本

- LVGL tag: `v9.1.0`
- LVGL commit: `e1c0b21b2723d391b885de4b2ee5cc997eccca91`
- 平台: `host_macos`
