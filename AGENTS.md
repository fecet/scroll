# Repository Guidelines

These guidelines help contributors work effectively across this repo’s two main components: `Hyprland/` (the compositor) and `hyprscroller/` (layout plugin), plus packaging under `pkgs/`.

## Project Structure & Module Organization
- `Hyprland/` — C/C++ compositor, Meson/CMake builds, tests in `hyprtester/`, docs/assets/scripts included.
- `hyprscroller/` — C++ plugin with `CMakeLists.txt`, `hyprpm.toml`, Nix flake, example configs.
- `pkgs/` — distro packaging (e.g., `PKGBUILD`).
- Root helpers — `.gitignore`, `justfile` (reserved), no global build.

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

## Coding Style & Naming Conventions
- Formatting: LLVM-based `.clang-format` (4-space indent, no tabs, 180 col limit). Run `clang-format -i` on changed files.
- Linting: `.clang-tidy` is strict; fix warnings. Notable naming: classes `C*`, structs `S*`, enums `e*`, enum constants UPPER_CASE, functions `camelBack`.
- Nix: use the provided flake formatter (from `Hyprland/flake.nix`), e.g., `cd Hyprland && nix fmt`.

## Testing Guidelines
- Prefer adding/adjusting tests in `Hyprland/hyprtester/src/tests/` (see existing `main/*.cpp`).
- Run `make -C Hyprland test`. For plugins, also validate by loading in a local Hyprland session.
- Aim to cover new logic paths and regressions; keep tests self-contained.

## Commit & Pull Request Guidelines
- Commits: short imperative subject (≤50 chars), optional scope prefix (e.g., `Hyprland:`, `hyprscroller:`), body explains “why”, link issues (`#123`).
- PRs: include description, reproduction steps/config snippets (`hypr.conf` if relevant), logs or `hyprctl` output, before/after screenshots or short GIFs for visual changes, and test notes.
- Keep diffs focused; update docs/config examples when behavior changes.

## Security & Configuration Tips
- Do not commit secrets or local paths; avoid system-specific tweaks in examples.
- When working with ASAN or low-level changes, follow `Hyprland/Makefile` notes and avoid running against a live session.

