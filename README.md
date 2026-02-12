# fnm.el

Manage Node versions within Emacs using fnm

## Installation

### Using Cask

Add `fnm` to your [Cask](https://github.com/cask/cask) file:

```lisp
(depends-on "fnm")
```

### Using `use-package` and [straight.el](https://github.com/radian-software/straight.el)

```elisp
(use-package fnm
  :straight (:host github :repo "rejeep/fnm.el")
  :config
  ;; Optionally set a default node version
  (fnm-use "18"))
```

### Using [Quelpa](https://github.com/quelpa/quelpa-use-package)

```elisp
(use-package fnm
  :quelpa ((fnm :fetcher github
                :repo "rejeep/fnm.el")
                :upgrade t)
```

## DSL

### fnm-use `(version &optional callback)`

Use `version`. If `callback` is specified, use `version` in that
callback and then switch back to the previously used version.

### fnm-use-for `(&optional path callback)`

Read version from `.fnmrc` in `path` (or `default-directory`) and use
that. Second `callback` argument is same as for `fnm-use`.

### fnm-use-for-buffer `()`

Call `fnm-use-for` on the file visited by the current buffer. Suitable
for use in a mode hook to automatically activate the correct node
version for a file.

## Contribution

Contribution is much welcome!

Install [cask](https://github.com/cask/cask) if you haven't
already, then:

    $ cd /path/to/fnm.el
    $ cask

Run all tests with:

    $ make
