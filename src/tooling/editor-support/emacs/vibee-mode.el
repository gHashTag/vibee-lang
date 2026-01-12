;;; vibee-mode.el --- Major mode for VIBEE DSL -*- lexical-binding: t; -*-

;; Copyright (C) 2024 VIBEE Team

;; Author: VIBEE Team
;; Version: 1.0.0
;; Keywords: languages, vibee, dsl, ai
;; Package-Requires: ((emacs "26.1"))
;; URL: https://github.com/vibee/vibee

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Major mode for editing VIBEE DSL files.
;; VIBEE is an AGI Open Source Framework for fault-tolerant AI agents on BEAM.

;; Installation:
;;   (add-to-list 'load-path "/path/to/vibee/editor-support/emacs")
;;   (require 'vibee-mode)

;;; Code:

(require 'font-lock)
(require 'rx)

;; ============================================================================
;; Customization
;; ============================================================================

(defgroup vibee nil
  "Major mode for VIBEE DSL."
  :group 'languages
  :prefix "vibee-")

(defcustom vibee-indent-offset 2
  "Indentation offset for VIBEE code."
  :type 'integer
  :group 'vibee)

(defcustom vibee-tab-width 2
  "Tab width for VIBEE mode."
  :type 'integer
  :group 'vibee)

;; ============================================================================
;; Faces
;; ============================================================================

(defface vibee-decorator-face
  '((t :inherit font-lock-preprocessor-face :weight bold))
  "Face for VIBEE decorators."
  :group 'vibee)

(defface vibee-keyword-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for VIBEE keywords."
  :group 'vibee)

(defface vibee-type-face
  '((t :inherit font-lock-type-face))
  "Face for VIBEE types."
  :group 'vibee)

(defface vibee-operator-face
  '((t :inherit font-lock-builtin-face))
  "Face for VIBEE operators."
  :group 'vibee)

;; ============================================================================
;; Syntax Highlighting
;; ============================================================================

(defconst vibee-keywords
  '("tool" "scene" "fn" "struct" "agent" "machine"
    "on" "enter" "exit" "callback" "message"
    "stay" "transition" "reply"
    "case" "if" "else" "match" "as")
  "VIBEE keywords.")

(defconst vibee-types
  '("str" "int" "float" "bool" "list" "map" "any" "nil" "void")
  "VIBEE built-in types.")

(defconst vibee-constants
  '("true" "false" "nil" "Ok" "Error" "Some" "None")
  "VIBEE constants.")

(defconst vibee-builtins
  '("print" "read_line" "length" "to_string" "parse_int"
    "lowercase" "uppercase" "map" "filter" "reduce"
    "each" "enumerate" "first" "last" "reverse"
    "join" "split" "contains" "starts_with" "ends_with"
    "replace" "trim" "now" "sleep" "random" "generate_id")
  "VIBEE built-in functions.")

(defconst vibee-decorators
  '("@desc" "@spec" "@const" "@import" "@llm"
    "@fallback_models" "@retry" "@timeout" "@budget"
    "@ffi" "@one_of" "@range")
  "VIBEE decorators.")

(defvar vibee-font-lock-keywords
  `(
    ;; Comments
    (,"#.*$" . font-lock-comment-face)

    ;; Decorators
    (,"@[a-zA-Z_][a-zA-Z0-9_]*" . 'vibee-decorator-face)

    ;; Keywords
    (,(regexp-opt vibee-keywords 'words) . 'vibee-keyword-face)

    ;; Types
    (,(regexp-opt vibee-types 'words) . 'vibee-type-face)

    ;; Constants
    (,(regexp-opt vibee-constants 'words) . font-lock-constant-face)

    ;; Built-in functions
    (,(regexp-opt vibee-builtins 'words) . font-lock-builtin-face)

    ;; Function/tool definitions
    (,"\\b\\(tool\\|scene\\|fn\\|struct\\|agent\\|machine\\)\\s-+\\([a-zA-Z_][a-zA-Z0-9_]*\\)"
     (2 font-lock-function-name-face))

    ;; State names (after 'on')
    (,"\\bon\\s-+\\([a-zA-Z_][a-zA-Z0-9_]*\\)"
     (1 font-lock-variable-name-face))

    ;; Parameters with types
    (,"\\b\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\s-*:\\s-*\\([a-zA-Z_][a-zA-Z0-9_]*\\)[!?]?"
     (1 font-lock-variable-name-face)
     (2 'vibee-type-face))

    ;; Operators
    (,"->\\||>\\|<>\\|==\\|!=\\|<=\\|>=\\|&&\\|||" . 'vibee-operator-face)

    ;; Type modifiers
    (,"[!?]" . font-lock-warning-face)

    ;; Strings
    (,"\"\"\"[^\"]*\"\"\"" . font-lock-string-face)
    (,"\"[^\"\\]*\\(?:\\.[^\"\\]*\\)*\"" . font-lock-string-face)

    ;; Numbers
    (,"\\b[0-9]+\\(?:\\.[0-9]+\\)?\\b" . font-lock-constant-face)
    )
  "Font lock keywords for VIBEE mode.")

;; ============================================================================
;; Syntax Table
;; ============================================================================

(defvar vibee-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Comments start with #
    (modify-syntax-entry ?# "<" table)
    (modify-syntax-entry ?\n ">" table)

    ;; Strings
    (modify-syntax-entry ?\" "\"" table)

    ;; Operators
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?* "." table)
    (modify-syntax-entry ?/ "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?| "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?! "." table)

    ;; Brackets
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)

    ;; @ is part of word (for decorators)
    (modify-syntax-entry ?@ "_" table)

    ;; _ is part of word
    (modify-syntax-entry ?_ "w" table)

    table)
  "Syntax table for VIBEE mode.")

;; ============================================================================
;; Indentation
;; ============================================================================

(defun vibee-indent-line ()
  "Indent current line of VIBEE code."
  (interactive)
  (let ((savep (> (current-column) (current-indentation)))
        (indent (vibee--calculate-indent)))
    (if savep
        (save-excursion (indent-line-to indent))
      (indent-line-to indent))))

(defun vibee--calculate-indent ()
  "Calculate the indentation for the current line."
  (save-excursion
    (beginning-of-line)
    (if (bobp)
        0
      (let ((not-indented t)
            (cur-indent 0))
        ;; Check for closing brackets
        (if (looking-at "^\\s-*[}\\])]")
            (progn
              (forward-line -1)
              (setq cur-indent (- (current-indentation) vibee-indent-offset))
              (when (< cur-indent 0)
                (setq cur-indent 0)))
          ;; Check previous line
          (forward-line -1)
          (while not-indented
            (cond
             ;; Blank line - use previous indent
             ((looking-at "^\\s-*$")
              (forward-line -1))
             ;; Line ends with : - increase indent
             ((looking-at ".*:\\s-*$")
              (setq cur-indent (+ (current-indentation) vibee-indent-offset))
              (setq not-indented nil))
             ;; Line ends with { [ ( - increase indent
             ((looking-at ".*[{\\[(]\\s-*$")
              (setq cur-indent (+ (current-indentation) vibee-indent-offset))
              (setq not-indented nil))
             ;; Default - use same indent
             (t
              (setq cur-indent (current-indentation))
              (setq not-indented nil)))))
        cur-indent))))

;; ============================================================================
;; Mode Definition
;; ============================================================================

(defvar vibee-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Add key bindings here
    map)
  "Keymap for VIBEE mode.")

;;;###autoload
(define-derived-mode vibee-mode prog-mode "VIBEE"
  "Major mode for editing VIBEE DSL files.

\\{vibee-mode-map}"
  :syntax-table vibee-mode-syntax-table
  :group 'vibee

  ;; Font lock
  (setq-local font-lock-defaults '(vibee-font-lock-keywords))

  ;; Comments
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "#+ *")

  ;; Indentation
  (setq-local indent-line-function #'vibee-indent-line)
  (setq-local tab-width vibee-tab-width)
  (setq-local indent-tabs-mode nil)

  ;; Electric pairs
  (setq-local electric-pair-pairs '((?\{ . ?\})
                                     (?\[ . ?\])
                                     (?\( . ?\))
                                     (?\" . ?\"))))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.vibee\\'" . vibee-mode))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.vib\\'" . vibee-mode))

(provide 'vibee-mode)

;;; vibee-mode.el ends here
