;;; treesitter-grammar-ensure.el --- Automatically downloads and builds treesitter grammars -*- lexical-binding: t; read-symbol-shorthands: (("my/" . "treesitter-grammar-ensure--")) -*-

;; Package-Requires: ((emacs "29.0"))

;;; Commentary:

;; Defines simple hooks which automatically download and compile treesitter
;; grammars from known locations on the internet, and provide them to Emacs at a
;; standard location.
;;
;; This is intended for use with Emacs 29+ built-in treesitter capabilities. If
;; you use `elisp-tree-sitter', you should not use this package, use
;; `tree-sitter-langs' instead.
;;
;; This package is in fact a simple shim around this tool which automates
;; building treesitter grammars: https://github.com/casouri/tree-sitter-module
;;
;; and furthermore this package simply hooks the functionality created in
;; https://leba.dev/blog/2022/12/12/(ab)using-straightel-for-easy-tree-sitter-grammar-installations/
;; in an appropriate place.
;;
;; This package requires an internet connection and git to download grammars. It
;; relies on having both a C and C++ compiler on the PATH. Internally it depends
;; on `straight.el' so you should load this package after bootstrapping
;; straight.

;;; Code:

(require 'treesit)
(require 'cl)

;;; see https://leba.dev/blog/2022/12/12/(ab)using-straightel-for-easy-tree-sitter-grammar-installations/
;;;###autoload
(cl-defun tree-sitter-compile-grammar (&key destination path)
  "Compile grammar at PATH (which may be absolute, or relative to
the buffer `default-directory', or nil for `default-directory',
and place the resulting shared library in directory DESTINATION
(which must be absolute, or nil to use default treesitter
directory)."
  (setq destination
        (or destination
            ;; default search path according to `treesit-extra-load-path'
            (expand-file-name "tree-sitter" user-emacs-directory)))
  (setq path
        (cond
         ((stringp path)
          (if (f-absolute? path)
              path
            (concat default-directory "/" path))
          )
         (t default-directory)))

  (make-directory destination 'parents)

  (let* ((default-directory
          (expand-file-name "src/" path))
         (_
          (message "Compiling treesitter grammar at %s" default-directory))
         (parser-name
          (thread-last (expand-file-name "grammar.json" default-directory)
                       (json-read-file)
                       (alist-get 'name)))
         (emacs-module-url
          "https://raw.githubusercontent.com/casouri/tree-sitter-module/master/emacs-module.h")
         (tree-sitter-lang-in-url
          "https://raw.githubusercontent.com/casouri/tree-sitter-module/master/tree-sitter-lang.in")
         (needs-cpp-compiler nil))

    (url-copy-file emacs-module-url "emacs-module.h" :ok-if-already-exists)
    (url-copy-file tree-sitter-lang-in-url "tree-sitter-lang.in" :ok-if-already-exists)

    (with-temp-buffer
      (unless
          (zerop
           (apply #'call-process
                  (if (file-exists-p "scanner.cc") "c++" "cc") nil t nil
                  "parser.c" "-I." "--shared" "-o"
                  (expand-file-name
                   (format "libtree-sitter-%s%s" parser-name module-file-suffix)
                   destination)
                  (cond ((file-exists-p "scanner.c") '("scanner.c"))
                        ((file-exists-p "scanner.cc") '("scanner.cc")))))
        (error
         "Unable to compile grammar, please file a bug report\n%s"
         (buffer-string))))
    (message "Tresitter grammar completed compilation")))

;; install straight.el
;; https://github.com/radian-software/straight.el#getting-started
(defvar bootstrap-version)
(defun my/ensure-straight()
  (when (not (fboundp 'straight-use-package))
    (let ((bootstrap-file
           (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
          (bootstrap-version 6))
      (unless (file-exists-p bootstrap-file)
        (with-current-buffer
            (url-retrieve-synchronously
             "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
             'silent 'inhibit-cookies)
          (goto-char (point-max))
          (eval-print-last-sexp)))
      (load bootstrap-file nil 'nomessage))))

(defconst my/straight-recipe-name-prefix "ensure-treesitter-grammar--")

(defun tree-sitter-ensure-have-grammar-via-straight+standard-github(language &optional repo compile-grammar-params)
  "Uses straight to ensure that the treesitter grammar for LANGUAGE,
which is expected to be found in the \"standard\" locations in
the \"tree-sitter\" organization on github, is installed on this
machine. REPO is the github-style repository
identifier. COMPILE-GRAMMAR-PARAMS are the parameters passed to
`tree-sitter-compile-grammar'."

  (my/ensure-straight)

  (let* ((straight-recipe-name (concat my/straight-recipe-name-prefix (symbol-name language)))
         (straight-recipe-symbol (intern straight-recipe-name))
         (repo (or repo (concat "tree-sitter/tree-sitter-" (symbol-name language)))))

    ;; edge case: we have build the package before via straight, and it
    ;; succeeded, but did not produce the desired result: the language is still
    ;; not "ready". potentially the dynamic lib got deleted
    (when (not (treesit-ready-p language 'quiet))
      (ht-remove straight--build-cache straight-recipe-name))

    (straight-use-package
     `(,straight-recipe-symbol
       :type git
       :host github
       :repo ,repo
       :post-build
       (tree-sitter-compile-grammar ,@compile-grammar-params)))
    ))

(defcustom tree-sitter-grammar-ensurers
  '(
    (agda
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (bash
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (c
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (c-sharp
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (cpp
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (css
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (elm
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (fluent
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (go
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (haskell
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (html
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (java
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (javascript
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (jsdoc
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (json
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (julia
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (ocaml
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (php
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (python
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (ruby
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (rust
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (scala
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (swift
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github))

    (typescript
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github nil (:path "typescript")))

    (tsx
     .
     (tree-sitter-ensure-have-grammar-via-straight+standard-github "tree-sitter/tree-sitter-typescript" (:path "tsx")))
    )

  "Mapping from symbols corresponding to languages, to the function
which creates the language treesitter grammar and places it in an
appropriate location for Emacs to find (typically somewhere in
`treesit-extra-load-path').

The actual language symbol is passed as the first argument to the specified function."

  :group
  'treesit

  :type
  '(alist
    :key-type (symbol :tag "Language name")
    :value-type
    (cons (function :tag "Function which loads the language treesitter grammar")
          (repeat :tag "Additional arguments to the function" sexp)))
  )

(defun my/try-ensure-have-treesitter-grammar(language)
  (when-let (act (alist-get language tree-sitter-grammar-ensurers))
    (apply (car act)
           (cons language (cdr act)))))

(when (treesit-available-p)
  (define-advice treesit-ready-p
      (:around (fn language &optional quiet) ensure-have-grammar)
    (if (funcall fn language t) ;; first check is always quiet
        t ;; success!
      (with-demoted-errors "Error while trying to automatically download and build treesitter grammar: %s"
        (cl-letf
            ;; within the scope of this call, we pretend this advice doesn't
            ;; exist, so that somebody who calls treeset-ready-p from within the
            ;; language ensure function won't enter an infinite loop.
            (((symbol-function 'treesit-ready-p) fn)
             )
          (my/try-ensure-have-treesitter-grammar language)
          )
        )
      (funcall fn language quiet) ;; check again
      )))

(provide 'treesitter-grammar-ensure)
