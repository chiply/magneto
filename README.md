# magneto

Composable window management for Emacs.

## Overview

Magneto lets you compose window operations through a prefix keymap.
Instead of remembering separate commands for every combination of
move/copy/pull + split/side/fill + buffer action + cursor placement,
you press keys to set each parameter and then execute with RET.

## Installation

### Using elpaca (with use-package)

```elisp
(use-package magneto
  :ensure (:host github :repo "chiply/magneto")
  :bind ("s-m" . magneto-compose))
```

### Manual

```elisp
(add-to-list 'load-path "/path/to/magneto")
(require 'magneto)
(global-set-key (kbd "s-m") #'magneto-compose)
```

## Usage

Bind `magneto-compose` to a key (e.g. `s-m`), then compose an operation.
The invoking key doubles as the execute key (same key to enter and exit):

| Key       | Action                              |
|-----------|-------------------------------------|
| `m`       | Source: **move** (delete origin)     |
| `c`       | Source: **copy** (keep origin)       |
| `p`       | Source: **pull** (prev-buffer origin)|
| `0`       | Destination: **fill** (ace-window)   |
| `v` / `V` | Destination: split vertical (below/above) |
| `h` / `H` | Destination: split horizontal (right/left) |
| `t` / `T` | Destination: side window top         |
| `b` / `B` | Destination: side window bottom      |
| `l` / `L` | Destination: side window left        |
| `r` / `R` | Destination: side window right       |
| `o`       | Cursor: follow to destination        |
| `O`       | Cursor: stay at origin               |
| `w`       | Action: switch buffer (via `magneto-buffer-command`) |
| `f`       | Action: find-file                    |
| `x`       | Action: execute-command              |
| `C-b`     | Action: switch-buffer (builtin)      |
| `a/s/d`   | Pre-select destination window        |
| `RET`     | **Execute** composed operation       |

Keys stay active while composing — press multiple source or
destination keys to change your mind before committing with RET.

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

GPL-3.0. See [LICENSE](LICENSE).
