# fnm.el

Manage Node versions within Emacs using [fnm](https://github.com/Schniz/fnm) (Fast Node Manager).

## Installation

### Using Cask

Add `fnm` to your [Cask](https://github.com/cask/cask) file:

```lisp
(depends-on "fnm")
```

### Using `use-package` and [straight.el](https://github.com/radian-software/straight.el)

```elisp
(use-package fnm
  :straight (:host github :repo "nhojb/fnm.el")
  :config
  ;; Optionally set a default node version
  (fnm-use "22"))
```

### Using [Quelpa](https://github.com/quelpa/quelpa-use-package)

```elisp
(use-package fnm
  :quelpa ((fnm :fetcher github
                :repo "nhojb/fnm.el")
           :upgrade t))
```

## API

### fnm-use `(version &optional callback)`

Activate `version`. If `callback` is specified, use `version` in that
callback and then switch back to the previously used version.

Version can be a full version (e.g., "v22.18.0"), major.minor (e.g., "22.18"),
or just major (e.g., "22"). The most recent matching installed version will be used.

### fnm-use-for `(&optional path callback)`

Read version from `.fnmrc`, `.nvmrc`, or `.node-version` file in `path` (or
`default-directory`) and activate it. Files are checked in that order of
precedence. Second `callback` argument is same as for `fnm-use`.

### fnm-use-for-buffer `()`

Call `fnm-use-for` on the file visited by the current buffer. Suitable
for use in a mode hook to automatically activate the correct Node
version for a file.

Example:

```elisp
(add-hook 'js-mode-hook #'fnm-use-for-buffer)
```

## Configuration

### fnm-dir

The fnm installation directory. Defaults to `~/.local/share/fnm` or the
value of the `FNM_DIR` environment variable.

## Contribution

Contribution is much welcome!

Install [cask](https://github.com/cask/cask) if you haven't
already, then:

    $ cd /path/to/fnm.el
    $ cask

Run all tests with:

    $ make

## Acknowledgements

fnm.el is based on [nvm.el](https://github.com/rejeep/nvm.el)
