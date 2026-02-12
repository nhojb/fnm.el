(require 'f)

(defvar fnm-test/test-path
  (f-parent (f-this-file)))

(defvar fnm-test/root-path
  (f-parent fnm-test/test-path))

(defvar fnm-test/sandbox-path
  (f-expand "sandbox" fnm-test/test-path))

(defmacro with-sandbox (&rest body)
  `(with-mock
    (when (f-dir? fnm-test/sandbox-path)
      (f-delete fnm-test/sandbox-path 'force))
    (f-mkdir fnm-test/sandbox-path)
    (let ((default-directory fnm-test/sandbox-path)
          (fnm-dir "/path/to/fnm/")
          (process-environment
           '("FNM_BIN=/path/to/fnm/v0.0.1/bin"
             "FNM_PATH=/path/to/fnm/v0.0.1/lib/node"
             "PATH=/path/to/foo/bin/:/path/to/fnm/v0.0.1/bin/:/path/to/bar/bin/")))
      ,@body)))

(defun write-fnmrc (version)
  (f-write version 'utf-8 (f-expand ".fnmrc" fnm-test/sandbox-path)))

(require 'ert)
(require 'el-mock)
(require 'cl-lib)
(require 'fnm (f-expand "fnm" fnm-test/root-path))
