;;; magneto.el --- Composable window management -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Charlie Holland
;;
;; Author: Charlie Holland
;; URL: https://github.com/chiply/magneto
;; Keywords: convenience, windows
;; Package-Requires: ((emacs "29.1") (avy "0.5.0") (ace-window "0.10.0") (repeatable-lite "0.1.0") (which-key "3.5.0"))
;; SPDX-License-Identifier: GPL-3.0-or-later

;; x-release-please-start-version
;; Version: 0.1.0
;; x-release-please-end

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Magneto is a composable window management system for Emacs.  It lets
;; you compose actions through a prefix keymap: choose a source action
;; (move/copy/pull), a destination (split/side/fill), a buffer action,
;; and cursor placement, then execute them all with RET.
;;
;; Usage:
;;   Bind `magneto-map' to a key, then press keys to compose:
;;     m/c/p   - source: move, copy, pull
;;     v/V/h/H - destination: split vertical/horizontal
;;     t/b/l/r - destination: side windows (top/bottom/left/right)
;;     o/O     - cursor: follow destination / stay at origin
;;     w/x/f   - action: switch-buffer, execute-command, find-file
;;     RET     - execute the composed action

;;; Code:

(require 'avy)
(require 'ace-window)
(require 'repeatable-lite)

;;; Customization

(defgroup magneto nil
  "Composable window management."
  :group 'windows
  :prefix "magneto-")

(defcustom magneto-default-source-action "move"
  "Default source action.
One of \"move\", \"copy\", or \"pull\"."
  :type '(choice (const "move") (const "copy") (const "pull"))
  :group 'magneto)

(defcustom magneto-default-destination-action "f"
  "Default destination action.
\"f\" means fill (ace-window select), \"V\"/\"v\" vertical split,
\"H\"/\"h\" horizontal split, or a side-window letter."
  :type 'string
  :group 'magneto)

(defcustom magneto-default-select-action "o"
  "Default cursor placement after move.
\"o\" follows to destination, \"O\" stays at origin."
  :type '(choice (const "o") (const "O"))
  :group 'magneto)

(defcustom magneto-default-action-action "switch-buffer"
  "Default buffer action.
One of \"switch-buffer\", \"consult-buffer\", \"execute-command\",
or \"find-file\"."
  :type 'string
  :group 'magneto)

(defcustom magneto-default-destination-window nil
  "Default pre-selected destination window, or nil for `ace-window' prompt."
  :type '(choice (const nil) window)
  :group 'magneto)

(defcustom magneto-default-embark-candidate nil
  "Default embark candidate, or nil."
  :type '(choice (const nil) string)
  :group 'magneto)

(defcustom magneto-default-embark-action nil
  "Default embark action function, or nil."
  :type '(choice (const nil) function)
  :group 'magneto)

(defcustom magneto-buffer-command #'switch-to-buffer
  "Command used for the \"consult-buffer\" action.
Set to `consult-buffer' if you use consult."
  :type 'function
  :group 'magneto)

;;; State variables

(defvar magneto-source-action nil
  "Current source action for the pending magneto operation.")

(defvar magneto-destination-action nil
  "Current destination action for the pending magneto operation.")

(defvar magneto-select-action nil
  "Current cursor placement for the pending magneto operation.")

(defvar magneto-action-action nil
  "Current buffer action for the pending magneto operation.")

(defvar magneto-destination-window nil
  "Pre-selected destination window, or nil.")

(defvar magneto-embark-candidate nil
  "Current embark candidate, or nil.")

(defvar magneto-embark-action nil
  "Current embark action function, or nil.")

;;; Internal functions

(defun magneto-avy-read (initial-input tree display-fn cleanup-fn)
  "Read avy selection from TREE with INITIAL-INPUT as the first key.
DISPLAY-FN and CLEANUP-FN are passed to avy for overlay management."
  (catch 'done
    (setq avy-current-path initial-input)
    (let ((counter 0))
      (while tree
        (setq counter (1+ counter))
        (let ((avy--leafs nil))
          (avy-traverse tree
                        (lambda (path leaf)
                          (push (cons path leaf) avy--leafs)))
          (dolist (x avy--leafs)
            (funcall display-fn (car x) (cdr x))))
        (let ((char (funcall
                     avy-translate-char-function
                     (if (eq counter 1)
                         (cond
                          ((string-equal initial-input "a") 97)
                          ((string-equal initial-input "s") 115)
                          ((string-equal initial-input "d") 100))
                       (read-key))))
              window
              branch)
          (funcall cleanup-fn)
          (if (setq window (avy-mouse-event-window char))
              (throw 'done (cons char window))
            (if (setq branch (assoc char tree))
                (progn
                  (setq avy-current-path
                        (concat avy-current-path (string (avy--key-to-char char))))
                  (if (eq (car (setq tree (cdr branch))) 'leaf)
                      (throw 'done (cdr tree))))
              (funcall avy-handler-function char))))))))

(defun magneto-ace-get-window (initial-input)
  "Select a window using `ace-window' with INITIAL-INPUT as the first key."
  (interactive)
  (let* ((wnd-list (aw-window-list))
         (candidate-list
          (mapcar (lambda (wnd)
                    (cons (aw-offset wnd) wnd))
                  wnd-list))
         (win (cdr (magneto-avy-read initial-input (avy-tree candidate-list aw-keys)
                                     (if (and ace-window-display-mode
                                              (null aw-display-mode-overlay))
                                         (lambda (_path _leaf))
                                       aw--lead-overlay-fn)
                                     aw--remove-leading-chars-fn))))
    win))

(defun magneto--set-source-action (setting)
  "Set `magneto-source-action' to SETTING."
  (interactive)
  (setq magneto-source-action setting))

(defun magneto--set-destination-action (setting)
  "Set `magneto-destination-action' to SETTING."
  (interactive)
  (setq magneto-destination-action setting))

(defun magneto--set-select-action (setting)
  "Set `magneto-select-action' to SETTING."
  (interactive)
  (setq magneto-select-action setting))

(defun magneto--set-action-action (setting)
  "Set `magneto-action-action' to SETTING."
  (interactive)
  (setq magneto-action-action setting))

(defun magneto--set-destination-window (setting)
  "Pre-select a destination window using `ace-window' with SETTING as input."
  (interactive)
  (setq magneto-destination-window (magneto-ace-get-window setting)))

;;; Core logic

(defun magneto-restore-defaults ()
  "Reset all magneto state variables to their default values."
  (interactive)
  (setq magneto-source-action magneto-default-source-action
        magneto-destination-action magneto-default-destination-action
        magneto-select-action magneto-default-select-action
        magneto-action-action magneto-default-action-action
        magneto-destination-window magneto-default-destination-window
        magneto-embark-candidate magneto-default-embark-candidate
        magneto-embark-action magneto-default-embark-action))

;; Initialize state from defaults
(magneto-restore-defaults)

(defun magneto-make-indirect ()
  "Create and switch to an indirect buffer clone of the current buffer."
  (interactive)
  (switch-to-buffer
   (clone-indirect-buffer
    (format "*indirect--%s*" (buffer-name (current-buffer)))
    nil)))

(defun magneto-move-after-select (buf-orig)
  "Apply destination split and buffer action with BUF-ORIG as the source buffer."
  (cond
   ((string= magneto-destination-action "f") nil)
   ((string= magneto-destination-action "V") (split-window))
   ((string= magneto-destination-action "v") (split-window) (windmove-down))
   ((string= magneto-destination-action "H") (split-window-horizontally))
   ((string= magneto-destination-action "h") (split-window-horizontally) (windmove-right)))
  (cond
   (magneto-embark-action (if magneto-embark-candidate
                              (funcall magneto-embark-action magneto-embark-candidate)
                            (funcall magneto-embark-action)))
   ((string= magneto-action-action "switch-buffer")
    (switch-to-buffer buf-orig))
   ((string= magneto-action-action "execute-command")
    (command-execute (read-extended-command)))
   ((string= magneto-action-action "find-file")
    (call-interactively #'find-file))
   ((string= magneto-action-action "consult-buffer")
    (call-interactively magneto-buffer-command)))
  (selected-window))

(defun magneto-select-win-dest-ace (buf-orig)
  "Select destination window via `ace-window', then apply action on BUF-ORIG."
  (if magneto-destination-window
      (progn
        (select-window magneto-destination-window)
        (magneto-move-after-select buf-orig))
    (aw-select "Select a window!: "
               (lambda (window)
                 (aw-switch-to-window window)
                 (magneto-move-after-select buf-orig)))))

(defun magneto-select-win-dest-side (buf-orig)
  "Display BUF-ORIG in a side window based on `magneto-destination-action'."
  (let ((side (cond
               ((member magneto-destination-action '("t" "T")) 'top)
               ((member magneto-destination-action '("b" "B")) 'bottom)
               ((member magneto-destination-action '("r" "R")) 'right)
               ((member magneto-destination-action '("l" "L")) 'left)))
        (slot (cond
               ((member magneto-destination-action '("t" "b" "r" "l")) 10)
               ((member magneto-destination-action '("T" "B" "R" "L")) -10)))
        (display-buffer-alist nil))
    (display-buffer
     buf-orig
     `((display-buffer-in-side-window)
       (side . ,side)
       (slot . ,slot)
       (window-parameters . ((no-delete-other-windows . 1)))))))

(defun magneto-select-win-dest (buf-orig)
  "Route BUF-ORIG to the appropriate destination handler."
  (cond
   ((member magneto-destination-action '("f" "V" "v" "H" "h"))
    (magneto-select-win-dest-ace buf-orig))
   ((member magneto-destination-action '("t" "T" "b" "B" "r" "R" "l" "L"))
    (magneto-select-win-dest-side buf-orig))))

(defun magneto-process-source (win-orig)
  "Handle the source window WIN-ORIG according to `magneto-source-action'."
  (cond
   ((string= magneto-source-action "move") (delete-window win-orig))
   ((string= magneto-source-action "pull") (switch-to-prev-buffer win-orig))
   ((string= magneto-source-action "copy") nil)))

(defun magneto-process-select (win-orig win-dest)
  "Place cursor in WIN-ORIG or WIN-DEST based on `magneto-select-action'."
  (cond
   ((string= magneto-select-action "o") (select-window win-dest))
   ((string= magneto-select-action "O") (select-window win-orig))))

;;;###autoload
(defun magneto-move (&optional _repeat)
  "Execute the composed magneto window operation.
Moves/copies/pulls the current buffer to the selected destination,
then restores defaults."
  (interactive)
  (let* ((buf-orig (current-buffer))
         (win-orig (selected-window))
         (win-dest (magneto-select-win-dest buf-orig)))
    (magneto-process-source win-orig)
    (magneto-process-select win-orig win-dest))
  (magneto-restore-defaults))

;;; Keymap

(defvar magneto-map nil
  "Keymap for composing magneto window operations.")

;;;###autoload
(define-prefix-command 'magneto-map)

(define-key magneto-map (kbd "<return>") #'magneto-move)

;; Source actions
(define-key magneto-map (kbd "m") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-source-action "move"))))
(define-key magneto-map (kbd "c") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-source-action "copy"))))
(define-key magneto-map (kbd "p") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-source-action "pull"))))

;; Destination actions
(define-key magneto-map (kbd "0") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "f"))))
(define-key magneto-map (kbd "h") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "h"))))
(define-key magneto-map (kbd "H") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "H"))))
(define-key magneto-map (kbd "v") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "v"))))
(define-key magneto-map (kbd "V") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "V"))))
(define-key magneto-map (kbd "t") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "t"))))
(define-key magneto-map (kbd "T") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "T"))))
(define-key magneto-map (kbd "b") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "b"))))
(define-key magneto-map (kbd "B") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "B"))))
(define-key magneto-map (kbd "l") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "l"))))
(define-key magneto-map (kbd "L") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "L"))))
(define-key magneto-map (kbd "r") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "r"))))
(define-key magneto-map (kbd "R") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-action "R"))))

;; Select actions (cursor placement)
(define-key magneto-map (kbd "o") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-select-action "o"))))
(define-key magneto-map (kbd "O") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-select-action "O"))))

;; Buffer actions
(define-key magneto-map (kbd "w") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-action-action "consult-buffer"))))
(define-key magneto-map (kbd "x") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-action-action "execute-command"))))
(define-key magneto-map (kbd "f") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-action-action "find-file"))))
(define-key magneto-map (kbd "C-b") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-action-action "switch-buffer"))))

;; Pre-select destination window (ace keys a/s/d)
(define-key magneto-map (kbd "a") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-window "a"))))
(define-key magneto-map (kbd "s") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-window "s"))))
(define-key magneto-map (kbd "d") (repeatable-lite-wrap (lambda () (interactive) (magneto--set-destination-window "d"))))

(provide 'magneto)
;;; magneto.el ends here
