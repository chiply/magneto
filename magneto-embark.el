;;; magneto-embark.el --- Embark integration for magneto -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Charlie Holland
;;
;; Author: Charlie Holland
;; URL: https://github.com/chiply/magneto
;; Version: 0.1.0
;; Keywords: convenience, windows
;; SPDX-License-Identifier: GPL-3.0-or-later

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
           (magneto-restore-defaults)
           (magneto--set-source-action "copy")
           (setq magneto-embark-candidate (read-from-minibuffer ""))
           (setq magneto-embark-action ',action)
           (magneto-move)))
       (condition-case nil
           (define-key ,keymap ,(kbd (concat "s-o " key-sequence)) ',function-name)
         (error (message ,(concat
                           (symbol-name keymap)
                           " "
                           (symbol-name function-name)
                           " didn't work")))))))

(defun magneto-embark-export ()
  "Export embark candidates then invoke `magneto-move'."
  (interactive)
  (call-interactively #'embark-export)
  (magneto-move))

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
                               (string-match-p "goto-grep" name))
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
        (error nil)))))

(provide 'magneto-embark)
;;; magneto-embark.el ends here
