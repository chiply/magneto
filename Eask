; -*- lexical-binding: t -*-

; x-release-please-start-version
(package "magneto" "0.1.1" "Composable window management")
; x-release-please-end
(website-url "https://github.com/chiply/magneto")
(keywords "convenience" "windows")
(package-file "magneto.el")
(files "magneto.el" "magneto-embark.el")
(script "test" "eask test ert test/magneto-test.el")
(source "gnu")
(source "melpa")
(depends-on "emacs" "29.1")
(depends-on "avy" "0.5.0")
(depends-on "ace-window" "0.10.0")
(depends-on "repeatable-lite" "0.1.0")
(depends-on "which-key" "3.5.0")  ; transitive dep of repeatable-lite, built-in on 30+
(development
 (depends-on "embark")
 (depends-on "package-lint")
 (depends-on "elisp-lint")
 (depends-on "relint"))
