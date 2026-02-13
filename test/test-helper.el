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
           '("FNM_BIN=/path/to/fnm/node-versions/v0.0.1/installation/bin"
             "FNM_PATH=/path/to/fnm/node-versions/v0.0.1/installation/lib/node"
             "PATH=/path/to/foo/bin/:/path/to/fnm/node-versions/v0.0.1/installation/bin/:/path/to/bar/bin/")))
      ,@body)))

(defun write-fnmrc (version)
  (f-write version 'utf-8 (f-expand ".fnmrc" fnm-test/sandbox-path)))

(defun write-node-version (version)
  (f-write version 'utf-8 (f-expand ".node-version" fnm-test/sandbox-path)))

(defun write-nvmrc (version)
  (f-write version 'utf-8 (f-expand ".nvmrc" fnm-test/sandbox-path)))

(require 'ert)
(require 'el-mock)
(require 'cl-lib)
(require 'fnm (f-expand "fnm" fnm-test/root-path))
