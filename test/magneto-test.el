;;; magneto-test.el --- Tests for magneto -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for magneto.

;;; Code:

(require 'ert)
(require 'magneto)

;;; Defaults and restore

(ert-deftest magneto-test-restore-defaults-source ()
  "Restoring defaults resets source action."
  (let ((magneto-default-source-action "move"))
    (setq magneto-source-action "copy")
    (magneto-restore-defaults)
    (should (string= magneto-source-action "move"))))

(ert-deftest magneto-test-restore-defaults-destination ()
  "Restoring defaults resets destination action."
  (let ((magneto-default-destination-action "f"))
    (setq magneto-destination-action "V")
    (magneto-restore-defaults)
    (should (string= magneto-destination-action "f"))))

(ert-deftest magneto-test-restore-defaults-select ()
  "Restoring defaults resets select action."
  (let ((magneto-default-select-action "o"))
    (setq magneto-select-action "O")
    (magneto-restore-defaults)
    (should (string= magneto-select-action "o"))))

(ert-deftest magneto-test-restore-defaults-action ()
  "Restoring defaults resets action action."
  (let ((magneto-default-action-action "switch-buffer"))
    (setq magneto-action-action "find-file")
    (magneto-restore-defaults)
    (should (string= magneto-action-action "switch-buffer"))))

(ert-deftest magneto-test-restore-defaults-embark-state ()
  "Restoring defaults clears embark candidate and action."
  (let ((magneto-default-embark-candidate nil)
        (magneto-default-embark-action nil))
    (setq magneto-embark-candidate "foo"
          magneto-embark-action #'ignore)
    (magneto-restore-defaults)
    (should (null magneto-embark-candidate))
    (should (null magneto-embark-action))))

;;; Setter functions

(ert-deftest magneto-test-set-source-action ()
  "Setting source action updates the variable."
  (magneto--set-source-action "copy")
  (should (string= magneto-source-action "copy"))
  (magneto-restore-defaults))

(ert-deftest magneto-test-set-destination-action ()
  "Setting destination action updates the variable."
  (magneto--set-destination-action "V")
  (should (string= magneto-destination-action "V"))
  (magneto-restore-defaults))

(ert-deftest magneto-test-set-select-action ()
  "Setting select action updates the variable."
  (magneto--set-select-action "O")
  (should (string= magneto-select-action "O"))
  (magneto-restore-defaults))

(ert-deftest magneto-test-set-action-action ()
  "Setting action action updates the variable."
  (magneto--set-action-action "find-file")
  (should (string= magneto-action-action "find-file"))
  (magneto-restore-defaults))

;;; Keymap

(ert-deftest magneto-test-magneto-map-is-keymap ()
  "The magneto-map should be a keymap."
  (should (keymapp magneto-map)))

(ert-deftest magneto-test-magneto-map-return-binding ()
  "RET should be bound to `magneto-move' in magneto-map."
  (should (eq (lookup-key magneto-map (kbd "<return>")) #'magneto-move)))

(ert-deftest magneto-test-magneto-map-has-source-keys ()
  "Source keys m, c, p should be bound in magneto-map."
  (should (lookup-key magneto-map (kbd "m")))
  (should (lookup-key magneto-map (kbd "c")))
  (should (lookup-key magneto-map (kbd "p"))))

;;; Defcustom defaults

(ert-deftest magneto-test-buffer-command-default ()
  "The `magneto-buffer-command' should default to `switch-to-buffer'."
  (should (eq magneto-buffer-command #'switch-to-buffer)))

;;; Process functions

(ert-deftest magneto-test-process-source-copy-preserves-window ()
  "Copy source action should not delete the origin window."
  (let ((magneto-source-action "copy"))
    (save-window-excursion
      (let ((win (selected-window)))
        (magneto-process-source win)
        (should (window-live-p win))))))

(ert-deftest magneto-test-process-select-follow ()
  "Select action 'o' should place cursor in destination window."
  (save-window-excursion
    (split-window)
    (let* ((win-orig (selected-window))
           (win-dest (next-window))
           (magneto-select-action "o"))
      (magneto-process-select win-orig win-dest)
      (should (eq (selected-window) win-dest))
      (delete-window win-dest))))

(ert-deftest magneto-test-process-select-stay ()
  "Select action 'O' should keep cursor in origin window."
  (save-window-excursion
    (split-window)
    (let* ((win-orig (selected-window))
           (win-dest (next-window))
           (magneto-select-action "O"))
      (magneto-process-select win-orig win-dest)
      (should (eq (selected-window) win-orig))
      (delete-window win-dest))))

;;; Indirect buffer

(ert-deftest magneto-test-make-indirect ()
  "Creating an indirect buffer should produce a buffer with the expected name."
  (with-temp-buffer
    (rename-buffer "test-buf" t)
    (let ((orig (current-buffer)))
      (magneto-make-indirect)
      (should (string-match-p "\\*indirect--test-buf\\*" (buffer-name)))
      (let ((indirect (current-buffer)))
        (switch-to-buffer orig)
        (kill-buffer indirect)))))

;;; magneto-move is interactive

(ert-deftest magneto-test-magneto-move-interactive ()
  "`magneto-move' should be an interactive command."
  (should (commandp #'magneto-move)))

;;; Compose mode

(ert-deftest magneto-test-magneto-compose-interactive ()
  "`magneto-compose' should be an interactive command."
  (should (commandp #'magneto-compose)))

(ert-deftest magneto-test-composing-starts-nil ()
  "`magneto--composing' should be nil by default."
  (should (null magneto--composing)))

(ert-deftest magneto-test-magneto-move-clears-composing ()
  "`magneto-move' should clear `magneto--composing'."
  (setq magneto--composing t)
  (condition-case nil
      (magneto-move)
    (error nil))
  (should (null magneto--composing)))

(provide 'magneto-test)
;;; magneto-test.el ends here
