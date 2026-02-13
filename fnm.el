;;; fnm.el --- Manage Node versions within Emacs using fnm

;; Copyright (C) 2026 John Buckley

;; Author: John Buckley <nhoj.buckley@gmail.com>
;; Maintainer: John Buckley <nhoj.buckley@gmail.com>
;; Version: 0.1.0
;; Keywords: node, fnm, nvm
;; URL: https://github.com/nhojb/fnm.el
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

;; This package provides functions for managing and switching between
;; Node.js versions installed via fnm (Fast Node Manager).
;;
;; Use `fnm-use' to switch to a specific version, `fnm-use-for' to
;; activate the version specified in a .fnmrc, .nvmrc, or .node-version
;; file, and `fnm-use-for-buffer' in mode hooks to automatically
;; activate the correct Node version for a file.

;;; Code:

(require 'f)
(require 's)
(require 'dash)

(defgroup fnm nil
  "Manage Node versions within Emacs using fnm."
  :prefix "fnm-"
  :group 'tools
  :link '(url-link :tag "Github" "https://github.com/nhojb/fnm.el"))

(defconst fnm-version-re
  "v[0-9]+\\.[0-9]+\\.[0-9]+"
  "Regex matching a Node version.")

(defcustom fnm-dir (or (getenv "FNM_DIR") (f-full "~/.local/share/fnm"))
  "Full path to fnm installation directory."
  :group 'fnm
  :type 'directory)

(defcustom fnm-completing-function 'completing-read
  "Completing function for calling `fnm-use'."
  :group 'fnm
  :type 'function)

(defvar fnm-current-version nil
  "Current active version.")

(defun fnm--node-versions-dir ()
  "Return the path to fnm's node-versions directory."
  (f-join fnm-dir "node-versions"))

(defun fnm--installed-versions ()
  "Return list of installed Node versions as (name . path) pairs.
Each element is a list of (version-name installation-path)."
  (let* ((versions-dir (fnm--node-versions-dir))
         (match-fn (lambda (directory)
                     (s-matches? (concat fnm-version-re "$") (f-filename directory)))))
    (when (f-exists? versions-dir)
      (--map (list (f-filename it) (f-join it "installation"))
             (f-directories versions-dir match-fn)))))

(defun fnm--version-from-string (version-string)
  "Split VERSION-STRING into a list of (major minor patch) numbers."
  (--map (string-to-number it) (s-split "[^0-9]" version-string t)))

(defun fnm--version-match? (matcher version)
  "Return t if VERSION satisfies the requirements in MATCHER.
MATCHER is a partial version list, VERSION is a full version list."
  (or (eq (car matcher) nil)
      (and (eq (car matcher) (car version))
           (fnm--version-match? (cdr matcher) (cdr version)))))

(defun fnm--version-compare (a b)
  "Comparator for sorting fnm versions, return t if A < B."
  (if (eq (car a) (car b))
      (fnm--version-compare (cdr a) (cdr b))
    (< (car a) (car b))))

(defun fnm--version-installed? (version)
  "Return t if VERSION is installed, nil otherwise."
  (--any? (string= (car it) version) (fnm--installed-versions)))

(defun fnm--find-exact-version-for (short)
  "Find most suitable installed version for SHORT.

SHORT is a string containing major and optionally minor version.
This function will return the most recent installed version whose
major and (if supplied) minor version components match."
  (when (s-matches? "v?[0-9]+\\(\\.[0-9]+\\(\\.[0-9]+\\)?\\)?$" short)
    (unless (s-starts-with? "v" short)
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
          (when possible-versions
            (car (sort possible-versions
                       (lambda (a b)
                         (not (fnm--version-compare
                               (fnm--version-from-string (car a))
                               (fnm--version-from-string (car b)))))))))))))

;;;###autoload
(defun fnm-use (version &optional callback)
  "Activate Node VERSION.

If CALLBACK is specified, activate in that scope and then reset to
previously used version."
  (interactive
   (list (funcall fnm-completing-function "Version: " (fnm--installed-versions))))
  (setq version (fnm--find-exact-version-for version))
  (unless version
    (error "No such version installed"))
  (let ((version-path (-last-item version)))
    (if (fnm--version-installed? (car version))
        (let ((prev-version fnm-current-version)
              (prev-exec-path exec-path))
          (setenv "FNM_BIN" (f-join version-path "bin"))
          (setenv "FNM_PATH" (f-join version-path "lib" "node"))
          (let* ((path-re (concat "^" (regexp-quote (fnm--node-versions-dir))
                                  "/" fnm-version-re "/installation/bin/?$"))
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

(defun fnm--find-version-file (path)
  "Search upward from PATH for .fnmrc, .nvmrc, or .node-version file.
Returns the directory containing the file, or nil if not found."
  (f-traverse-upwards
   (lambda (dir)
     (or (f-file? (f-expand ".fnmrc" dir))
         (f-file? (f-expand ".nvmrc" dir))
         (f-file? (f-expand ".node-version" dir))))
   path))

(defun fnm--read-version-file (dir)
  "Read version string from .fnmrc, .nvmrc, or .node-version file in DIR.
Files are checked in order: .fnmrc, .nvmrc, .node-version."
  (let ((fnmrc (f-expand ".fnmrc" dir))
        (nvmrc (f-expand ".nvmrc" dir))
        (node-version (f-expand ".node-version" dir)))
    (s-trim (f-read (cond ((f-file? fnmrc) fnmrc)
                          ((f-file? nvmrc) nvmrc)
                          (t node-version))))))

;;;###autoload
(defun fnm-use-for (&optional path callback)
  "Activate Node for PATH or `default-directory'.

This function will look for a .fnmrc, .nvmrc, or .node-version file
in that path or its parent directories and activate the version specified.

If CALLBACK is specified, activate in that scope and then reset to
previously used version."
  (unless path
    (setq path default-directory))
  (-if-let (version-file-dir (fnm--find-version-file path))
      (fnm-use (fnm--read-version-file version-file-dir) callback)
    (error "No .fnmrc, .nvmrc, or .node-version found for %s" path)))

;;;###autoload
(defun fnm-use-for-buffer ()
  "Activate Node based on .fnmrc, .nvmrc, or .node-version for current file.
If buffer is not visiting a file, do nothing."
  (when buffer-file-name
    (condition-case err
        (fnm-use-for buffer-file-name)
      (error (message "%s" err)))))

(provide 'fnm)

;;; fnm.el ends here
