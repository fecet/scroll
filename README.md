# Spiral Layout for Hyprland

This monorepo refines both Hyprland and the hyprscroller layout plugin to introduce a new automatic placement mode: `spiral`.

## Why Spiral
- Center-first cognition: windows grow from screen center outward, forming a Manhattan/chebyshev “square spiral” that matches users’ mental model.
- Stable indexing: the insertion order follows a deterministic spiral sequence, aiding spatial memory and muscle memory.
- Local changes: opening/closing windows primarily affects nearby slots, minimizing layout churn.
- Robust to size/resolution: the directionality and ordering stay consistent across monitor changes.

Spiral is an additional auto-placement strategy beside existing `manual` and `auto`. It requires no `N` parameter; the layout expands as needed.

## Mental Model
Let r be the Chebyshev radius from the center (r = 0, 1, 2, …). For each ring r, we traverse positions in clockwise order. The step lengths follow 1, 1, 2, 2, 3, 3, … with direction repeating →, ↓, ←, ↑ for a horizontal-first (Row) perspective; rotate this mapping by 90° for a vertical-first (Column) perspective.

Examples

Row (landscape):

```
789
612
543
```

Column (portrait):

```
765
814
923
```

## Mode/Position Mapping
Spiral relies solely on flipping the scroller working `mode` and its `ModeModifier::position` to realize the clockwise sequence—no global state machine is introduced.

- Row mapping
  - Extend right (new column to the right) → `mode = Row`, `position = end`.
  - Fill down (append within the column) → `mode = Column`, `position = end`.
  - Extend left (new column to the left) → `mode = Row`, `position = beginning`.
  - Fill up (insert at top of the column) → `mode = Column`, `position = beginning`.

- Column mapping (rotate the above by 90°)
  - Add rows with `mode = Column`; append within a row using `mode = Row`.
  - Choose `position = beginning/end` analogously (top/bottom vs. left/right).

When the next spiral step falls on a non-active column, `find_auto_insert_point` returns a `new_active` pointer to that target column; everything else remains local.

## How It Works
All spiral logic lives in `find_auto_insert_point`, which decides three things per insertion: `mode`, `position`, and `new_active`. The algorithm intentionally keeps no extra metadata and is resilient to user interventions like `expel` or removing middle windows—new windows are guided back onto the spiral track.

High-level procedure

1) Sample the current state
   - Walk existing columns; collect nodes and total window count. If empty, set `mode = Row`, `position = after` to create the first column.

2) Rebuild the theoretical sequence
   - Generate spiral coordinates for indices 1…N+1.
   - Determine current `min_x`/`max_x`, and map each `(x, y)` to a column index by linear normalization with rounding, so center alignment remains stable under changing column counts.

3) Find the first gap
   - “Account” for real windows against the spiral order. The first index that cannot be matched marks `missing_index`; otherwise the target is `total_windows + 1`.

4) Decide the operation
   - If the target column lies beyond current bounds, switch to `mode = Row` and set `position = beginning/end` to grow left/right.
   - Otherwise switch to `mode = Column`, set `new_active` to the mapped column, and choose `position = beginning/after/end` based on `y` relative to that column’s expected range.

5) No external state
   - Only `mode`, `position`, `new_active` are produced. `add_active_window` saves/restores these, so temporary changes do not leak into manual operations.

## Cooperation With Insertions
`Row::add_active_window` persists and restores `mode` and `modifier` around the insertion, so decisions made in `find_auto_insert_point` remain surgical and side-effect free. For in-column inserts, `Column::add_active_window` consults only the current `position` and does not clobber our choices. This keeps spiral fully compatible with existing save/restore mechanics and user dispatchers.

## Status
- Scope: monorepo with minimal Hyprland adjustments plus a hyprscroller plugin providing `spiral`.
- Releases: planned. We will publish binaries in future releases; no build instructions here.
- Reference: see commit `a355bcbeed362903d04ec8fdc0fc6487b1d6dea9` for the initial drop and follow-up refinements.

## Installation via Pacman Repository

This project provides an official Pacman repository for easy installation and updates.

### Add the Repository

Add one of the following to your `/etc/pacman.conf`:

#### Stable Repository
```
[hyprspiral]
SigLevel = Optional
Server = https://github.com/fecet/hyprspiral/releases/latest/download
```

#### Beta Repository (for testing)
```
[hyprspiral-beta]
SigLevel = Optional
Server = https://github.com/fecet/hyprspiral/releases/download/beta
```

### Update Package Database
```bash
sudo pacman -Sy
```

### Install Packages
```bash
# Install the modified Hyprland with spiral support
sudo pacman -S hyprspiral/hyprland-spiral

# Install the spiral layout plugin
sudo pacman -S hyprspiral/hyprland-plugin-spiral
```

### Available Packages
- `hyprland-spiral` - Modified Hyprland compositor with spiral layout support
- `hyprland-plugin-spiral` - Spiral layout plugin for Hyprland

Note: These packages conflict with the standard `hyprland` package and will replace it.

## Notes
- The implementation is deterministic: identical window sets and orders produce identical geometry.
- The layout preserves directionality across monitor changes; geometry adapts but the spiral path remains consistent.

For implementation details, start with `hyprscroller/src/row.cpp` and search for `find_auto_insert_point` and `AUTO_SPIRAL`.
