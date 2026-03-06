;;; magneto-embark.el --- Embark integration for magneto -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <mister.chiply@gmail.com>
;; Maintainer: Charlie Holland <mister.chiply@gmail.com>
;; URL: https://github.com/chiply/magneto
;; Version: 0.1.0
;; Keywords: convenience, windows
;; SPDX-License-Identifier: GPL-3.0-or-later
;;
;; This file is not part of GNU Emacs.
;;
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

;; Optional embark integration for magneto.  Provides functions to bind
;; embark actions so they route through magneto's composable window
;; management before executing.
;;
;; Usage:
;;   (with-eval-after-load 'embark
;;     (require 'magneto-embark)
;;     (magneto-embark-bind-keys))

;;; Code:

(require 'magneto)
(require 'embark)

(defun magneto-embark--make-action (keymap action key-sequence)
  "Create a magneto-routed embark action and bind it in KEYMAP.
ACTION is the embark action symbol.  KEY-SEQUENCE is the key to bind
under a prefix in KEYMAP."
  (let ((function-name (intern (concat "magneto-embark--" (symbol-name action)))))
    `(progn
       (defun ,function-name ()
         ,(format "Embark action `%s' routed through magneto." action)
         (interactive)
         (with-demoted-errors "%s"
           (let ((candidate (read-from-minibuffer "")))
             (magneto-compose)
             (magneto--set-source-action "copy")
             (setq magneto-embark-candidate candidate)
             (setq magneto-embark-action ',action))))
       (condition-case nil
           (define-key ,keymap ,(kbd (concat "s-o " key-sequence)) ',function-name)
         (error (message ,(concat
                           (symbol-name keymap)
                           " "
                           (symbol-name function-name)
                           " didn't work")))))))

;;; Collect / Export with magneto placement

(defun magneto-embark--act-advice (orig-fn action target &optional quit)
  "Advise `embark--act' to run magneto export/collect in the minibuffer.
ORIG-FN is the original `embark--act'.  ACTION, TARGET, and QUIT are
passed through.  This ensures our commands get the same treatment as
`embark-export' and `embark-collect' (running in the current buffer
without target injection)."
  (if (memq action '(magneto-embark-export magneto-embark-collect))
      (progn
        (embark--run-action-hooks embark-pre-action-hooks action target quit)
        (unwind-protect (embark--run-around-action-hooks action target quit)
          (embark--run-action-hooks embark-post-action-hooks
                                    action target quit)))
    (funcall orig-fn action target quit)))

(defun magneto-embark--start-compose-with-buffer (buffer)
  "Enter magneto compose to place BUFFER at a user-chosen destination."
  (magneto-compose)
  (magneto--set-source-action "copy")
  (setq magneto--buffer-override buffer
        magneto-embark-candidate nil
        magneto-embark-action (lambda () (switch-to-buffer buffer))))

(defun magneto-embark--collect-no-display (buffer-name)
  "Create an Embark Collect buffer named BUFFER-NAME without displaying it.
Like `embark--collect' but skips `display-buffer', running mode hooks
directly in the buffer instead."
  (let ((buffer (generate-new-buffer buffer-name))
        (rerun (embark--rerun-function #'embark-collect)))
    (with-current-buffer buffer
      (delay-mode-hooks (embark-collect-mode)))
    (embark--cache-info buffer)
    (unless (embark-collect--update-candidates buffer)
      (user-error "No candidates to collect"))
    (with-current-buffer buffer
      (setq tabulated-list-use-header-line nil
            header-line-format nil
            tabulated-list--header-string nil)
      (setq embark--rerun-function rerun)
      (run-mode-hooks)
      (tabulated-list-revert))
    buffer))

;;;###autoload
(defun magneto-embark-collect ()
  "Collect embark candidates and place the buffer via magneto compose.
Like `embark-collect' but instead of displaying the buffer immediately,
enters magneto compose mode so you can choose a destination window."
  (interactive)
  (let ((buffer (magneto-embark--collect-no-display
                 (embark--descriptive-buffer-name 'collect))))
    (if (minibufferp)
        (progn
          (embark--run-after-command
           #'magneto-embark--start-compose-with-buffer buffer)
          (embark--quit-and-run #'message nil))
      (magneto-embark--start-compose-with-buffer buffer))))

;;;###autoload
(defun magneto-embark-export ()
  "Export embark candidates and place the buffer via magneto compose.
Like `embark-export' but instead of displaying the buffer with
`pop-to-buffer', enters magneto compose mode so you can choose a
destination window."
  (interactive)
  (let* ((transformed (embark--maybe-transform-candidates))
         (candidates (or (plist-get transformed :candidates)
                         (user-error "No candidates for export")))
         (type (plist-get transformed :type)))
    (let ((exporter (or (alist-get type embark-exporters-alist)
                        (alist-get t embark-exporters-alist))))
      (if (eq exporter 'embark-collect)
          (magneto-embark-collect)
        (let* ((after embark-after-export-hook)
               (cmd embark--command)
               (name (embark--descriptive-buffer-name 'export))
               (rerun (embark--rerun-function #'embark-export))
               (buffer (save-excursion
                         (funcall exporter candidates)
                         (rename-buffer name t)
                         (current-buffer))))
          (embark--quit-and-run
           (lambda ()
             (set-buffer buffer)
             (setq embark--rerun-function rerun)
             (use-local-map
              (make-composed-keymap
               '(keymap
                 (remap keymap
                        (revert-buffer . embark-rerun-collect-or-export)))
               (current-local-map)))
             (let ((embark-after-export-hook after)
                   (embark--command cmd))
               (run-hooks 'embark-after-export-hook))
             (magneto-embark--start-compose-with-buffer buffer))))))))

;;; Keymap parsing and binding

(defun magneto-embark--parse-keymap (keymap &optional prefix)
  "Parse KEYMAP into a list of (command key-string) entries.
PREFIX is prepended to key descriptions for nested keymaps."
  (let (result)
    (map-keymap
     (lambda (key command)
       (let* ((key-str (single-key-description key))
              (new-prefix (if prefix (concat prefix " " key-str) key-str)))
         (if (keymapp command)
             (setq result
                   (append result
                           (magneto-embark--parse-keymap
                            command
                            (replace-regexp-in-string " " "-" new-prefix))))
           (push (list command new-prefix) result))))
     keymap)
    (nreverse result)))

(defun magneto-embark--bind-keymap (keymap)
  "Bind magneto-routed actions for relevant commands in KEYMAP."
  (dolist (entry (seq-filter
                  (lambda (x)
                    (let ((name (symbol-name (car x))))
                      (and (or (string-match-p "find-file" name)
                               (string-match-p "consult-bookmark" name)
                               (string-match-p "goto-grep" name)
                               (string-match-p "switch-to-buffer" name)
                               (string-match-p "bookmark-jump" name)
                               (string-match-p "find-library" name)
                               (string-match-p "^eww" name)
                               (string-match-p "embark-find-definition" name)
                               (string-match-p "xref-find-definitions" name)
                               (string-match-p "xref-find-references" name)
                               (string-match-p "describe-symbol" name)
                               (string-match-p "describe-package" name)
                               (string-match-p "describe-face" name)
                               (string-match-p "embark-dired-jump" name)
                               (string-match-p "org-tree-to-indirect-buffer" name)
                               (string-match-p "embark-vc-visit-pr" name))
                           (not (or (string-match-p "digit-arg" name)
                                    (string-match-p "magneto-embark" name)
                                    (string-match-p "embark-org-link-map" name))))))
                  (magneto-embark--parse-keymap (eval keymap))))
    (eval (magneto-embark--make-action keymap (car entry) (cadr entry)))))

;;;###autoload
(defun magneto-embark-bind-keys ()
  "Bind magneto actions in all embark keymaps.
Call this after embark has been loaded."
  (let ((embark-maps (mapcar (lambda (x)
                               (if (listp (cdr x)) (cadr x) (cdr x)))
                             embark-keymap-alist)))
    (dolist (km embark-maps)
      (condition-case nil
          (magneto-embark--bind-keymap km)
        (error nil))))
  ;; Bind collect/export in the general map
  (define-key embark-general-map (kbd "s-o E") #'magneto-embark-export)
  (define-key embark-general-map (kbd "s-o S") #'magneto-embark-collect)
  ;; Ensure embark--act treats our commands like embark-export/embark-collect
  (advice-add 'embark--act :around #'magneto-embark--act-advice))

(provide 'magneto-embark)
;;; magneto-embark.el ends here
