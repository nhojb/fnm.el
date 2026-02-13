(eval-when-compile
  (defvar fnm-dir))

(defun should-have-env (env value)
  (should (string= (getenv env) value)))

(defun should-use-version (version)
  "Assert that VERSION is active with fnm's node-versions structure."
  (should-have-env "FNM_BIN" (f-join fnm-dir "node-versions" version "installation" "bin"))
  (should-have-env "FNM_PATH" (f-join fnm-dir "node-versions" version "installation" "lib" "node"))
  (should-have-env "PATH" (concat (f-full (f-join fnm-dir "node-versions" version "installation" "bin")) ":/path/to/foo/bin/:/path/to/bar/bin/"))
  (should (string= (car exec-path) (f-join fnm-dir "node-versions" version "installation" "bin"))))

(defun stub-version-tuples-for (versions)
  "Create version tuples for VERSIONS using fnm's node-versions structure.
Each version in VERSIONS is a string like \"v22.18.0\"."
  (let ((as-tuple (lambda (version)
                    (list version (concat "/path/to/fnm/node-versions/" version "/installation")))))
    (cl-map #'list as-tuple versions)))

;;;; fnm-use

(ert-deftest fnm-use-test/version-not-available ()
  (with-sandbox
   (stub fnm--installed-versions => nil)
   (should-error
    (fnm-use "v0.10.1"))))

(ert-deftest fnm-use-test/version-available-no-callback ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.10.1")))
   (fnm-use "v0.10.1")
   (should-use-version "v0.10.1")))

(ert-deftest fnm-use-test/version-available-no-previous-trailing-colon-in-path ()
  (with-sandbox
   (setenv "PATH" "/path/to/foo/bin/:/path/to/bar/bin/:")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.10.1")))
   (fnm-use "v0.10.1")
   (should-use-version "v0.10.1")))

(ert-deftest fnm-use-test/version-available-with-callback ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use "v0.8.2")
   (should-use-version "v0.8.2")
   (fnm-use "v0.10.1"
            (lambda ()
              (should-use-version "v0.10.1")))
   (should-use-version "v0.8.2")))

(ert-deftest fnm-use-test/version-available-with-callback-that-errors ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use "v0.8.2")
   (should-use-version "v0.8.2")
   (should-error
    (fnm-use "v0.10.1" (lambda () (error "BooM"))))
   (should-use-version "v0.8.2")))

(ert-deftest fnm-use-test/version-available-with-callback-that-errors-no-previous ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   ;; NOTE: We are not actually testing what we say we are. It's hard
   ;; to do because the error we are expecting is a
   ;; 'wrong-type-argument error, but the callback error is the one
   ;; that is caught.
   ;;
   ;; The problem before was that if the callback fails and there is
   ;; no previous version, we previously tried to set nil as version.
   ;;
   ;; No idea how to actually test this...?
   (should-error
    (fnm-use "v0.10.1" (lambda () (error "BooM"))))))

(ert-deftest fnm-use-test/short-version ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.10.1")))
   (fnm-use "0.10")
   (should-use-version "v0.10.1")))

(ert-deftest fnm-use-test/major-version ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.10.1" "v12.1.0" "v12.0.1")))
   (fnm-use "12")
   (should-use-version "v12.1.0")))

;;;; fnm-use-for

(ert-deftest fnm-use-for-test/no-config ()
  (with-sandbox
   (should-error
    (fnm-use-for fnm-test/sandbox-path))))

(ert-deftest fnm-use-for-test/config-no-such-version ()
  (with-sandbox
   (write-fnmrc "v0.10.1")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2")))
   (should-error
    (fnm-use-for fnm-test/sandbox-path))))

(ert-deftest fnm-use-for-test/config-no-callback ()
  (with-sandbox
   (write-fnmrc "v0.10.1")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use-for fnm-test/sandbox-path)
   (should-use-version "v0.10.1")))

(ert-deftest fnm-use-for-test/config-callback ()
  (with-sandbox
   (write-fnmrc "v0.10.1")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use "v0.8.2")
   (should-use-version "v0.8.2")
   (fnm-use-for fnm-test/sandbox-path
                (lambda ()
                  (should-use-version "v0.10.1")))
   (should-use-version "v0.8.2")))

(ert-deftest fnm-use-for-test/no-path ()
  (with-sandbox
   (write-fnmrc "v0.8.2")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2")))
   (fnm-use-for)
   (should-use-version "v0.8.2")))

(ert-deftest fnm-use-for-test/short-version ()
  (with-sandbox
   (write-fnmrc "v0.10")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use-for fnm-test/sandbox-path)
   (should-use-version "v0.10.1")))

(ert-deftest fnm-use-for-test/newlines ()
  (with-sandbox
   (write-fnmrc "\nv0.10\n")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use-for fnm-test/sandbox-path)
   (should-use-version "v0.10.1")))

;;;; fnm-use-for with .node-version file

(ert-deftest fnm-use-for-test/node-version-file ()
  (with-sandbox
   (write-node-version "v0.10.1")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use-for fnm-test/sandbox-path)
   (should-use-version "v0.10.1")))

(ert-deftest fnm-use-for-test/fnmrc-takes-precedence-over-node-version ()
  "When both .fnmrc and .node-version exist, .fnmrc takes precedence."
  (with-sandbox
   (write-fnmrc "v0.8.2")
   (write-node-version "v0.10.1")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use-for fnm-test/sandbox-path)
   (should-use-version "v0.8.2")))

;;;; fnm-use-for with .nvmrc file

(ert-deftest fnm-use-for-test/nvmrc-file ()
  (with-sandbox
   (write-nvmrc "v0.10.1")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use-for fnm-test/sandbox-path)
   (should-use-version "v0.10.1")))

(ert-deftest fnm-use-for-test/fnmrc-takes-precedence-over-nvmrc ()
  "When both .fnmrc and .nvmrc exist, .fnmrc takes precedence."
  (with-sandbox
   (write-fnmrc "v0.8.2")
   (write-nvmrc "v0.10.1")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use-for fnm-test/sandbox-path)
   (should-use-version "v0.8.2")))

(ert-deftest fnm-use-for-test/nvmrc-takes-precedence-over-node-version ()
  "When both .nvmrc and .node-version exist, .nvmrc takes precedence."
  (with-sandbox
   (write-nvmrc "v0.8.2")
   (write-node-version "v0.10.1")
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (fnm-use-for fnm-test/sandbox-path)
   (should-use-version "v0.8.2")))

;;;; fnm--find-exact-version-for

(ert-deftest fnm--find-exact-version-for-test ()
  (with-mock
   (stub
    fnm--installed-versions =>
    (stub-version-tuples-for '("v0.8.2" "v0.8.8" "v0.6.0" "v0.10.7" "v0.10.2" "v0.10.11")))
   (should (string= (car (fnm--find-exact-version-for "0")) "v0.10.11"))
   (should (string= (car (fnm--find-exact-version-for "v0")) "v0.10.11"))
   (should-not (fnm--find-exact-version-for "0.3"))
   (should-not (fnm--find-exact-version-for "v0.6.1"))
   (should-not (fnm--find-exact-version-for "v0.6.0.1"))
   (should-not (fnm--find-exact-version-for "merry christmas"))
   (should (string= (car (fnm--find-exact-version-for "v0.6.0")) "v0.6.0"))
   (should (string= (car (fnm--find-exact-version-for "v0.8.2")) "v0.8.2"))
   (should (string= (car (fnm--find-exact-version-for "v0.10.7")) "v0.10.7"))
   (should (string= (car (fnm--find-exact-version-for "v0.6")) "v0.6.0"))
   (should (string= (car (fnm--find-exact-version-for "0.8")) "v0.8.8"))
   (should (string= (car (fnm--find-exact-version-for "v0.8")) "v0.8.8"))
   (should (string= (car (fnm--find-exact-version-for "v0.10")) "v0.10.11"))
   (should (string= (car (fnm--find-exact-version-for "0.10")) "v0.10.11"))))

;;;; fnm-use-for-buffer

(ert-deftest fnm-use-for-buffer-not-visiting ()
  (with-temp-buffer
    ;; assert that there is no error:
    (fnm-use-for-buffer)))

(ert-deftest fnm-use-for-buffer-no-fnmrc ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (with-temp-buffer
     (setq buffer-file-name (f-expand "test.js" fnm-test/sandbox-path))
     ;; can't use should-use-version since we're not moving the node
     ;; path to the front
     (let ((old-path (getenv "PATH"))
           (old-fnm-bin (getenv "FNM_BIN"))
           (old-fnm-path (getenv "FNM_PATH")))
       (fnm-use-for-buffer)
       (should-have-env "FNM_BIN" old-fnm-bin)
       (should-have-env "FNM_PATH" old-fnm-path)
       (should-have-env "PATH" old-path)))))

(ert-deftest fnm-use-for-buffer-with-fnmrc ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (with-temp-buffer
     (setq buffer-file-name (f-expand "test.js" fnm-test/sandbox-path))
     (write-fnmrc "v0.10.1")
     (fnm-use-for-buffer)
     (should-use-version "v0.10.1"))))

(ert-deftest fnm-use-for-buffer-with-node-version ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (with-temp-buffer
     (setq buffer-file-name (f-expand "test.js" fnm-test/sandbox-path))
     (write-node-version "v0.10.1")
     (fnm-use-for-buffer)
     (should-use-version "v0.10.1"))))

(ert-deftest fnm-use-for-buffer-with-nvmrc ()
  (with-sandbox
   (stub fnm--installed-versions => (stub-version-tuples-for '("v0.8.2" "v0.10.1")))
   (with-temp-buffer
     (setq buffer-file-name (f-expand "test.js" fnm-test/sandbox-path))
     (write-nvmrc "v0.10.1")
     (fnm-use-for-buffer)
     (should-use-version "v0.10.1"))))
