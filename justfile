# Use bash with safety flags for all backticks/recipes
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Default recipe: show available commands
default:
  @just --list

# Project-local default path to the built plugin
project_root := justfile_directory()
plugin_default := (project_root / "hyprscroller" / "hyprscroller.so")
pkgbuilds_dir := (project_root / "pkgbuilds")

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
  hyprctl plugin unload hyprscroller && hyprctl plugin unload /usr/lib/hyprscroller.so && hyprctl plugin unload '{{plugin}}' || true
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

# Build Hyprland and hyprscroller packages
# flags: makepkg flags (default: '-sc' to sync deps and clean)
# Examples: flags='-sCc' for clean build, flags='-sfi' to install

pkg-hyprland flags='-sc' j=jobs:
  #!/usr/bin/env bash
  set -euxo pipefail
  cd '{{pkgbuilds_dir}}/hyprland-spiral'
  export MAKEFLAGS='-j{{j}}'
  makepkg {{flags}}
  ls -1t *.pkg.tar.* 2>/dev/null | head -n1 || true

pkg-plugin flags='-sc' j=jobs:
  #!/usr/bin/env bash
  set -euxo pipefail
  cd '{{pkgbuilds_dir}}/hyprland-plugin-spiral'
  export MAKEFLAGS='-j{{j}}'
  makepkg {{flags}}
  ls -1t *.pkg.tar.* 2>/dev/null | head -n1 || true

# Build both packages
pkg flags='-sc' j=jobs: (pkg-hyprland flags j) (pkg-plugin flags j)

# Generate .SRCINFO files for all packages
srcinfo:
  #!/usr/bin/env bash
  set -euxo pipefail
  for pkg_dir in {{pkgbuilds_dir}}/*/; do
    if [ -f "${pkg_dir}PKGBUILD" ]; then
      echo "Generating .SRCINFO for $(basename "$pkg_dir")"
      cd "$pkg_dir"
      makepkg --printsrcinfo > .SRCINFO
    fi
  done

# Build local repository database
repo-build channel='stable':
  #!/usr/bin/env bash
  set -euxo pipefail
  repo_dir='{{project_root}}/repo/{{channel}}'
  mkdir -p "$repo_dir"

  # Copy all built packages to repo directory
  for pkg_dir in {{pkgbuilds_dir}}/*/; do
    if [ -d "$pkg_dir" ]; then
      find "$pkg_dir" -maxdepth 1 -name "*.pkg.tar.*" -exec cp {} "$repo_dir/" \;
    fi
  done

  # Create repository database
  cd "$repo_dir"
  repo-add hyprspiral-{{channel}}.db.tar.gz *.pkg.tar.* || true

  echo "Repository created at: $repo_dir"
  echo "Add to /etc/pacman.conf:"
  echo "[hyprspiral-{{channel}}]"
  echo "SigLevel = Optional"
  echo "Server = file://$repo_dir"

# Clean build artifacts
clean:
  #!/usr/bin/env bash
  set -euxo pipefail
  echo "Cleaning build artifacts..."

  # Clean hyprscroller build
  make -C hyprscroller clean || true

  # Clean package build directories
  for pkg_dir in {{pkgbuilds_dir}}/*/; do
    if [ -d "$pkg_dir" ]; then
      cd "$pkg_dir"
      rm -rf pkg src *.pkg.tar.* *.log
    fi
  done

  # Clean local repository
  rm -rf '{{project_root}}/repo'

  echo "Clean complete"

# Update version in PKGBUILD files
bump-version version:
  #!/usr/bin/env bash
  set -euxo pipefail
  echo "Updating version to {{version}} in all PKGBUILDs..."

  for pkgbuild in {{pkgbuilds_dir}}/*/PKGBUILD; do
    if [ -f "$pkgbuild" ]; then
      sed -i "s/^pkgver=.*/pkgver={{version}}/" "$pkgbuild"
      echo "Updated $(dirname "$pkgbuild")"
    fi
  done

  # Regenerate .SRCINFO files
  just srcinfo

# Check if GitHub Actions workflow is valid
gh-check:
  #!/usr/bin/env bash
  set -euxo pipefail
  if ! command -v act >/dev/null 2>&1; then
    echo "Warning: 'act' is not installed. Install it to test workflows locally."
    echo "Visit: https://github.com/nektos/act"
    echo ""
    echo "Checking workflow syntax with basic validation..."
    if [ -f ".github/workflows/build-repo.yml" ]; then
      yamllint .github/workflows/build-repo.yml || true
    else
      echo "No workflow file found at .github/workflows/build-repo.yml"
    fi
  else
    echo "Testing GitHub Actions workflow locally with 'act'..."
    act -l
  fi

# Create a test release locally (simulates GitHub release)
test-release:
  #!/usr/bin/env bash
  set -euxo pipefail
  echo "Building packages for test release..."
  just pkg flags='-sc'

  echo "Creating local release directory..."
  release_dir='{{project_root}}/test-release'
  mkdir -p "$release_dir"

  # Copy packages
  for pkg_dir in {{pkgbuilds_dir}}/*/; do
    if [ -d "$pkg_dir" ]; then
      find "$pkg_dir" -maxdepth 1 -name "*.pkg.tar.*" -exec cp {} "$release_dir/" \;
    fi
  done

  # Create repository database
  cd "$release_dir"
  repo-add hyprspiral.db.tar.gz *.pkg.tar.* || true

  echo "Test release created at: $release_dir"
  ls -lh "$release_dir"
