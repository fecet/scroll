# Use bash with safety flags for all backticks/recipes
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Project-local default path to the built plugin
project_root := justfile_directory()
plugin_default := (project_root / "hyprscroller" / "hyprscroller.so")
pkgs_dir := (project_root / "pkgs")

# Default parallelism for builds (Linux-friendly fallbacks)
jobs := `nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4`

# Build hyprscroller in Release
scroller-build j=jobs:
  #!/usr/bin/env bash
  set -euxo pipefail
  make -C hyprscroller release -j{{j}}
  # Ensure the convenience symlink exists (hyprscroller.so -> Release/hyprscroller.so)
  if [ ! -e "hyprscroller/hyprscroller.so" ] && [ -e "hyprscroller/Release/hyprscroller.so" ]; then
    ln -sf ./Release/hyprscroller.so hyprscroller/hyprscroller.so
  fi

# Reload hyprscroller directly with hyprctl (no external script)
# - switches layout to dwindle
# - unloads plugin (by name, then by path)
# - loads plugin
# - switches layout back to scroller
scroller-reload plugin=plugin_default:
  #!/usr/bin/env bash
  set -euxo pipefail
  echo "[scroller-reload] plugin: {{plugin}}"
  if ! command -v hyprctl >/dev/null 2>&1; then
    echo "[scroller-reload] error: hyprctl not found in PATH" >&2
    exit 127
  fi
  hyprctl keyword general:layout dwindle || true
  # Try unloading by name first, then by path; ignore if not loaded
  hyprctl plugin unload hyprscroller || hyprctl plugin unload '{{plugin}}' || true
  # Ensure plugin file exists
  if [ ! -e '{{plugin}}' ]; then
    echo "[scroller-reload] error: plugin not found at {{plugin}}" >&2
    echo "Build it first: make -C hyprscroller release" >&2
    exit 2
  fi
  hyprctl plugin load '{{plugin}}'
  hyprctl keyword general:layout scroller
  echo "[scroller-reload] done"

# Build then reload (compose via dependencies)
scroller j=jobs plugin=plugin_default: (scroller-build j) (scroller-reload plugin)

# Build Arch package from pkgs/PKGBUILD
# - flags default to `-sc` (sync deps and clean up) without installing the package
# - pass e.g. flags='-sCc' for clean build, or flags='-sfi' to install
pkg-build flags='-sc' j=jobs:
  #!/usr/bin/env bash
  set -euxo pipefail
  if ! command -v makepkg >/dev/null 2>&1; then
    echo "[pkg-build] error: makepkg not found. Are you on Arch/Artix?" >&2
    exit 127
  fi
  cd '{{pkgs_dir}}'
  if [ ! -f PKGBUILD ]; then
    echo "[pkg-build] error: PKGBUILD not found in {{pkgs_dir}}" >&2
    exit 2
  fi
  export MAKEFLAGS='-j{{j}}'
  makepkg {{flags}}
  # Show newest artifact if any
  ls -1t *.pkg.tar.* 2>/dev/null | head -n1 || true

# Build Arch package using local working tree as source (override PKGBUILD url)
pkg-build-local flags='-sc' j=jobs:
  #!/usr/bin/env bash
  set -euxo pipefail
  if ! command -v makepkg >/dev/null 2>&1; then
    echo "[pkg-build-local] error: makepkg not found. Are you on Arch/Artix?" >&2
    exit 127
  fi
  cd '{{pkgs_dir}}'
  if [ ! -f PKGBUILD ]; then
    echo "[pkg-build-local] error: PKGBUILD not found in {{pkgs_dir}}" >&2
    exit 2
  fi
  repo_root="$(realpath '{{project_root}}')"
  # Create a temporary PKGBUILD overriding upstream URL to local working tree via git+file://
  sed -E "s|^url=.*$|url=\"file://${repo_root}\"|" PKGBUILD > PKGBUILD.local
  export MAKEFLAGS='-j{{j}}'
  makepkg -p PKGBUILD.local {{flags}}
  ls -1t *.pkg.tar.* 2>/dev/null | head -n1 || true

# Backwards-compat aliases (deprecated):
pkg-hyprland-build flags='-sc' j=jobs: (pkg-build flags j)
pkg-hyprland-build-local flags='-sc' j=jobs: (pkg-build-local flags j)
