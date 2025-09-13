# Repository Guidelines

## Overview
这是一个同时微调 Hyprland 与 hyprscroller 的 monorepo，目标是提供新的布局：`spiral`。实现最初引入于提交 `a355bcbeed362903d04ec8fdc0fc6487b1d6dea9`（建议从该提交开始阅读变更脉络）。

## Project Structure
- `Hyprland/`：对 compositor 的必要改动（接口/修复）以支持 `spiral`；测试在 `hyprtester/`。
- `hyprscroller/`：布局插件，含 `spiral` 的核心实现与示例配置。
- `pkgs/`：打包脚本（如 `PKGBUILD`）。

## Build, Test, and Development Commands
- Hyprland (CMake wrappers):
  - Build release: `make -C Hyprland release`
  - Build debug: `make -C Hyprland debug`
  - Run tests: `make -C Hyprland test`
  - Install headers for plugins: `sudo make -C Hyprland installheaders`
- Hyprland (Meson alternative): `cd Hyprland && meson setup build && ninja -C build`
- hyprscroller:
  - Build: `make -C hyprscroller release` (or `debug`)
  - Install to user config: `make -C hyprscroller install` → `~/.config/hypr/plugins/hyprscroller.so`
- Nix (inside component dir): `nix develop` for a shell; `nix build .#hyprland` or `nix build .#hyprscroller` to produce outputs.

## Commits & PRs
- 提交使用英文 Conventional Commits：例如 `feat(spiral): add center-bias tiling`、`fix(Hyprland): guard null monitor in spiral hints`。
- 主题 ≤50 字符、祈使语；正文解释“为何”，并链接 issue（如 `#123`）。
- PR 包含：变更说明、`hypr.conf` 片段、复现步骤、`hyprctl` 日志、前后截图/GIF、测试备注。

## Security & Ops
- 不要提交密钥或本地路径。
- 低层/ASAN 改动请遵循 `Hyprland/Makefile` 提示，避免在真实会话上直接运行。
