;;; nvm.el --- Manage Node versions within Emacs

;; Copyright (C) 2026 John Buckley

;; Author: John Buckley <nhoj.buckley@gmail.com>
;; Maintainer: Johan Andersson <nhoj.buckley@gmail.com>
;; Version: 0.1.0
;; Keywords: node, nvm
;; URL: http://github.com/nhojb/fnm.el
;; Package-Requires: ((s "1.8.0") (dash "2.18.0") (f "0.14.0"))

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;;; Code:

(require 'f)
(require 's)
(require 'dash)

(defgroup fnm nil
  "Manage Node versions within Emacs"
  :prefix "fnm-"
  :group 'tools
  :link '(url-link :tag "Github" "https://github.com/nhojb/fnm.el"))

(defconst fnm-version-re
  "v[0-9]+\.[0-9]+\.[0-9]+"
  "Regex matching a Node version.")

(defconst fnm-runtime-re
  "\\(?:versions/node/\\|versions/io.js/\\)?")

(defcustom fnm-dir (or (getenv "FNM_DIR") (f-full "~/.local/share/fnm"))
  "Full path to fnm installation directory."
  :group 'fnm
  :type 'directory)

(defcustom fnm-completing-function 'completing-read
  "Completing function for calling `FNM-USE'."
  :group 'fnm
  :type 'function)

(defvar fnm-current-version nil
  "Current active version.")

(defun fnm--using-new-path-schema? ()
  (f-exists? (f-join fnm-dir "versions")))

(defun fnm--installed-versions ()
  (let ((match-fn (lambda (directory)
                    (s-matches? (concat fnm-version-re "$") (f-filename directory)))))
    (-concat
     (fnm--version-directories-new match-fn)
     (fnm--version-directories-old match-fn))))

(defun fnm--version-directories-old (match-fn)
  (--map (list (f-filename it) it) (f-directories fnm-dir match-fn)))

(defun fnm--version-from-string (version-string)
  "Split a VERSION-STRING into a list of (major, minor, patch) numbers."
  (--map (string-to-number it) (s-split "[^0-9]" version-string t)))

(defun fnm--version-match? (matcher version)
  "Does this VERSION satisfy the requirements in MATCHER?"
  (or (eq (car matcher) nil)
      (and (eq (car matcher) (car version))
           (fnm--version-match? (cdr matcher) (cdr version)))))

(defun fnm--version-compare (a b)
  "Comparator for sorting FNM versions, return t if A < B."
  (if (eq (car a) (car b))
      (fnm--version-compare (cdr a) (cdr b))
    (< (car a) (car b))))

(defun fnm--clean-runtime-name (runtime)
  (s-replace "io.js" "iojs" (f-filename runtime)))

(defun fnm--version-name (runtime path)
  "Makes runtime names match those in fnm ls"
  (if (string= "node" runtime)
      (f-filename path)
    (concat (fnm--clean-runtime-name runtime) "-" (f-filename path))))

(defun fnm--version-directories-new (match-fn)
  (when (fnm--using-new-path-schema?)
    (let ((runtime-options
           (lambda (runtime)
             (--map (list (fnm--version-name (f-filename runtime) it) it)
                    (f-directories runtime match-fn)))))
      (-flatten-n 1 (-map runtime-options (f-directories (f-join fnm-dir "versions")))))))

(defun fnm--version-installed? (version)
  "Return true if VERSION is installed, false otherwise."
  (--any? (string= (car it) version) (fnm--installed-versions)))

(defun fnm--find-exact-version-for (short)
  "Find most suitable version for SHORT.

SHORT is a string containing major and optionally minor version.
This function will return the most recent version whose major
and (if supplied, minor) match."
  (when (s-matches? "v?[0-9]+\\(\.[0-9]+\\(\.[0-9]+\\)?\\)?$" short)
    (unless (or (s-starts-with? "v" short)
                 (s-starts-with? "node" short)
                 (s-starts-with? "iojs" short))
      (setq short (concat "v" short)))
    (let* ((versions (fnm--installed-versions))
           (requested (fnm--version-from-string short))
           (first-version
            (--first (string= (car it) short) versions)))
      (if first-version
          first-version
        (let ((possible-versions
               (-filter
                (lambda (version)
                  (fnm--version-match?
                   requested
                   (fnm--version-from-string (car version))))
                versions)))
          (if (eq possible-versions nil)
              nil
            (car (sort possible-versions
                       (lambda (a b)
                         (not (fnm--version-compare
                               (fnm--version-from-string (car a))
                               (fnm--version-from-string (car b)))))
                       ))))))))

;;;###autoload
(defun fnm-use (version &optional callback)
  "Activate Node VERSION.

If CALLBACK is specified, active in that scope and then reset to
previously used version."
  (interactive
   (list (funcall fnm-completing-function "Version: " (fnm--installed-versions))))
  (setq version (fnm--find-exact-version-for version))
  (let ((version-path (-last-item version)))
    (if (fnm--version-installed? (car version))
        (let ((prev-version fnm-current-version)
              (prev-exec-path exec-path))
          (setenv "FNM_BIN" (f-join version-path "bin"))
          (setenv "FNM_PATH" (f-join version-path "lib" "node"))
          (let* ((path-re (concat "^" (f-join fnm-dir fnm-runtime-re) fnm-version-re "/bin/?$"))
                 (new-bin-path (f-full (f-join version-path "bin")))
                 (paths
                  (cons
                   new-bin-path
                   (-reject
                    (lambda (path)
                      (if path (s-matches? path-re path) t))
                    (parse-colon-path (getenv "PATH"))))))
            (setenv "PATH" (s-join path-separator paths))
            (setq exec-path (cons new-bin-path (--remove (s-matches? path-re it) exec-path))))
          (setq fnm-current-version version)
          (when callback
            (unwind-protect
                (funcall callback)
              (when prev-version (fnm-use (car prev-version)))
              (setq exec-path prev-exec-path))))
      (error "No such version %s" version))))

;;;###autoload
(defun fnm-use-for (&optional path callback)
  "Activate Node for PATH or `default-directory'.

This function will look for a .fnmrc file in that path and
activate the version specified in that file.

If CALLBACK is specified, active in that scope and then reset to
previously used version."
  (unless path
    (setq path default-directory))
  (-if-let (fnmrc-path
            (f-traverse-upwards
             (lambda (dir)
               (f-file? (f-expand ".fnmrc" dir)))
             path))
      (fnm-use (s-trim (f-read (f-expand ".fnmrc" fnmrc-path))) callback)
    (error "No .fnmrc found for %s" path)))

;;;###autoload
(defun fnm-use-for-buffer ()
  "Activate Node based on an .fnmrc for the current file.
If buffer is not visiting a file, do nothing."
  (when buffer-file-name
    (condition-case err
        (fnm-use-for buffer-file-name)
      (error (message "%s" err)))))

(provide 'fnm)

;;; fnm.el ends here
