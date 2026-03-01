# magneto

[![CI](https://github.com/chiply/magneto/actions/workflows/ci.yml/badge.svg)](https://github.com/chiply/magneto/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Composable window management for Emacs.

## Overview

Magneto lets you compose window operations through a prefix keymap.
Instead of remembering separate commands for every combination of
move/copy/pull + split/side/fill + buffer action + cursor placement,
you press keys to set each parameter and then execute with RET.

## Installation

### With elpaca (use-package)

```elisp
(use-package magneto
  :ensure (:host github :repo "chiply/magneto")
  :bind ("s-m" . magneto-compose))
```

### With straight.el (use-package)

```elisp
(use-package magneto
  :straight (:host github :repo "chiply/magneto")
  :bind ("s-m" . magneto-compose))
```

### Manual

Clone the repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/magneto")
(require 'magneto)
(global-set-key (kbd "s-m") #'magneto-compose)
```

## Usage

Bind `magneto-compose` to a key (e.g. `s-m`), then compose an operation
by pressing keys in any order before executing with RET.

### Keys

**Source** — what happens to the origin window:

| Key | Action |
|-----|--------|
| `m` | **Move** — delete the origin buffer from its window |
| `c` | **Copy** — keep the origin buffer where it is |
| `p` | **Pull** — use `prev-buffer` in the origin window |

**Destination** — where the buffer lands:

| Key | Action |
|-----|--------|
| `0` | **Fill** — pick an existing window with ace-window |
| `v` / `V` | Split vertical (below / above) |
| `h` / `H` | Split horizontal (right / left) |
| `t` / `T` | Side window (top) |
| `b` / `B` | Side window (bottom) |
| `l` / `L` | Side window (left) |
| `r` / `R` | Side window (right) |

**Cursor** — where point ends up:

| Key | Action |
|-----|--------|
| `o` | Follow to the destination window |
| `O` | Stay in the origin window |

**Action** — what to display in the destination:

| Key | Action |
|-----|--------|
| `w` | Switch buffer (via `magneto-buffer-command`) |
| `f` | Find file |
| `x` | Execute command |
| `C-b` | `switch-to-buffer` (built-in) |

**Window select** — pre-pick the target window:

| Key | Action |
|-----|--------|
| `a` / `s` / `d` | Select destination window by position |

Press `RET` to execute.

### Examples

**Open a file in a right split, cursor follows:**

```
s-m h o f RET  →  pick file  →  opens in a new window to the right
```

You're editing `main.rs` and want `Cargo.toml` beside it. `h` = split
right, `o` = follow cursor there, `f` = find-file. After RET you pick
the file and land in the new split.

**Copy the current buffer into an existing window:**

```
s-m c 0 RET  →  ace-window prompt  →  buffer appears in chosen window
```

You want the same buffer visible in two places. `c` = copy (keep
origin), `0` = fill an existing window via ace-window.

**Move a buffer to a bottom side window, stay where you are:**

```
s-m m b O RET
```

Send the current buffer to a bottom side window (`b`) and keep your
cursor in the origin (`O`). The origin window shows its previous buffer.

## Options

| Variable                              | Default              | Description |
|---------------------------------------|----------------------|-------------|
| `magneto-default-source-action`       | `"move"`             | Default source action |
| `magneto-default-destination-action`  | `"f"`                | Default destination |
| `magneto-default-select-action`       | `"o"`                | Default cursor placement |
| `magneto-default-action-action`       | `"switch-buffer"`    | Default buffer action |
| `magneto-default-destination-window`  | `nil`                | Pre-selected window |
| `magneto-default-embark-candidate`    | `nil`                | Embark candidate |
| `magneto-default-embark-action`       | `nil`                | Embark action |
| `magneto-buffer-command`              | `#'switch-to-buffer` | Command for "consult-buffer" action |

## Embark integration

If you use [embark](https://github.com/oantolin/embark), load the
optional `magneto-embark` module:

```elisp
(with-eval-after-load 'embark
  (require 'magneto-embark)
  (magneto-embark-bind-keys))
```

This binds magneto-routed versions of relevant embark actions (find-file,
consult-bookmark, goto-grep) under `s-o` in each embark keymap.

## Dependencies

- Emacs 29.1+
- [avy](https://github.com/abo-abo/avy)
- [ace-window](https://github.com/abo-abo/ace-window)

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
