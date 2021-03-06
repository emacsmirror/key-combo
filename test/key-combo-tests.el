(require 'ert)
(require 'key-combo)



;;; INIT

(setq kc-mode-map (make-sparse-keymap))
(define-derived-mode kc-mode fundamental-mode "Test key-combo"
  (switch-to-buffer (current-buffer)))

(define-minor-mode kc-minor-mode
  "Test key-combo minor."
  :lighter " KC"
  :group 'key-combo
  :keymap kc-mode-map
  (if kc-minor-mode
      (progn
	(switch-to-buffer (current-buffer))
	(setq key-combo-mode t)
	(add-hook 'pre-command-hook
		  'key-combo-pre-command-function nil t))
    (setq key-combo-mode nil)
    (remove-hook 'pre-command-hook
		 'key-combo-pre-command-function t)))

(defun kc-execute-keyseq (keys)
  (execute-kbd-macro (key-combo-read-kbd-macro keys))
  (key-combo-finalize))

(defun kc-execute-command (cmd &optional buffer no-erase)
  (save-window-excursion
    (with-current-buffer (get-buffer-create (or buffer (make-temp-name "kc-tmp-")))
      (switch-to-buffer (current-buffer))
      (unless no-erase
	(erase-buffer))
      (kc-minor-mode 1)
      (if (stringp cmd)
	  (execute-kbd-macro (key-combo-read-kbd-macro cmd))
	(key-combo-command-execute cmd))
      (key-combo-finalize)
      (prog1 (buffer-substring-no-properties (point-min) (point-max))
	(unless buffer (kill-buffer (current-buffer)))))))



;;; GENERIC
(ert-deftest test-kc-command-hooks ()
  (with-temp-buffer 
    (kc-minor-mode 1)
    (should (memq 'key-combo-pre-command-function pre-command-hook))
    (kc-minor-mode -1)
    (should-not (memq 'key-combo-pre-command-function pre-command-hook))))

(ert-deftest test-kc-C-a ()
  (with-temp-buffer
    (erase-buffer)
    (kc-minor-mode 1)
    (key-combo-load-default-1 kc-mode-map key-combo-global-default)
    (should (key-combo-key-binding (kbd "C-a C-a")))
    (insert "B\n IP")
    (execute-kbd-macro (key-combo-read-kbd-macro "C-a"))
    (key-combo-finalize)
    (kc-execute-keyseq (kbd "C-a"))
    (should (equal (char-to-string (following-char)) "I"))
    (goto-char (point-max))
    (kc-execute-keyseq "C-a C-a")
    (should (equal (char-to-string (following-char)) " "))
    (goto-char (point-max))
    (kc-execute-keyseq "C-a C-a C-a")
    (should (equal (char-to-string (following-char)) "B"))))

(ert-deftest test-kc-execute-commands ()
  (should (string= (kc-execute-command "a") "a"))
  (let ((last-command-event ?b))
    (should (string= (kc-execute-command 'self-insert-command) "b")))
  (should (string= (kc-execute-command (lambda () (insert "a"))) "a"))
  (with-temp-buffer
    (switch-to-buffer (current-buffer))
    (key-combo-command-execute (key-combo-get-command "a`!!'a"))
    (should (string= (buffer-string) "aa"))
    (should (eq (point) 2)))
  (should-error (kc-execute-command 'wrong-command)))



;;; COMBOS
(ert-deftest test-kc-combo ()
  (with-temp-buffer
    (kc-minor-mode 1)
    (key-combo-define kc-mode-map (kbd "M-C-d") '(test1 test2))
    (kc-reset)
    (kc-execute-keyseq "M-C-d")
    (should (equal kc-counters '(1 0 0)))
    (kc-reset)
    (kc-execute-keyseq "M-C-d M-C-d")
    (should (equal kc-counters '(1 1 0)))
    (kc-reset)
    (kc-execute-keyseq "M-C-d M-C-d M-C-d")
    (should (equal kc-counters '(2 1 0)))))

(ert-deftest test-kc-special ()
  (with-temp-buffer`
   (let ((bf (current-buffer)))
     (kc-minor-mode 1)
     (buffer-enable-undo)
     (key-combo-load-default-1 kc-mode-map key-combo-common-default)
     (insert "\"")
     (should (string= (kc-execute-command "=" bf t) "\"="))
     (erase-buffer)
     (insert ";")
     (should (string= (kc-execute-command "=" bf t) ";="))
     (erase-buffer)
     (insert ";")
     (should (string= (kc-execute-command "," bf t) ";,"))
     (erase-buffer)
     (insert ";\n")
     (should (string= (kc-execute-command ";" bf t) ";\n;; "))
     (erase-buffer)
     (insert ";")
     (should (string= (kc-execute-command "." bf t) ";."))
     (erase-buffer)
     (insert "\"\"\n")
     (goto-char 3)
     (should (string= (kc-execute-command "." bf t) "\"\".\n"))
     (erase-buffer)
     (insert "\"\"a")
     (goto-char 3)
     (should (string= (kc-execute-command "." bf t) "\"\".a"))
     (erase-buffer)
     (insert "\"\"")
     (goto-char 3)
     (should (string= (kc-execute-command "." bf t) "\"\"."))
     (erase-buffer)
     (insert "\"\"")
     (goto-char 2)
     (should (string= (kc-execute-command "." bf t) "\".\""))
     (erase-buffer)
     (insert "a\"\"")
     (goto-char 2)
     (should (string= (kc-execute-command "." bf t) "a.\"\"")))))

(ert-deftest test-kc-vectors ()
  (with-temp-buffer`
   (let ((bf (current-buffer)))
     (kc-minor-mode 1)
     (buffer-enable-undo)
     (should (string= (kc-execute-command "=") " = "))
     (should (string= (kc-execute-command "==") " == "))
     (should (string= (kc-execute-command [?=]) " = "))
     (should (string= (kc-execute-command [?= ?=]) " == "))
     (should (string= (kc-execute-command [?= ?>]) " => "))
     (should (string= (kc-execute-command [?= ?= ?=]) " === ")))))

(ert-deftest test-kc-undo ()
    (with-temp-buffer`
      (let ((bf (current-buffer)))
	(kc-minor-mode 1)
	(buffer-enable-undo)
	(key-combo-load-default-1 kc-mode-map key-combo-common-default)
	(insert "init:")
	(should (string= (kc-execute-command "=" bf t) "init:= "))
	(undo -1)
	(should (string= (buffer-string) "init:="))
	(undo-more 1)
	(should (string= (buffer-string) ""))
	(should (string= (kc-execute-command "=" bf) " = "))
	(undo)
	(should (string= (buffer-string) "="))
	(should (string= (kc-execute-command "= C-x u" bf) "="))
	(should (string= (kc-execute-command "== C-x u" bf) " = ")))))



;;; COUNTERS

(defvar kc-counters '(0 3 0))
(defun kc-reset ()
  (set 'kc-counters (copy-list '(0 0 0))))
(defun test1 ()
  (interactive)
  (setf (nth 0 kc-counters) (+ (nth 0 kc-counters) 1))
  (message "test1"))
(defun test2 ()
  (interactive)
  (setf (nth 1 kc-counters) (+ (nth 1 kc-counters) 1))
  (message "test2"))
(defun test3 ()
  (interactive)
  (setf (nth 2 kc-counters) (+ (nth 2 kc-counters) 1))
  (message "test3"))
(defun not-a-command ())

(ert-deftest test-kc-count:simple ()
  (with-temp-buffer
    (kc-minor-mode 1)
    (key-combo-define kc-mode-map "ab" 'test1)
    (key-combo-define kc-mode-map "ac" 'test2)
    (kc-reset)
    (kc-execute-keyseq "ab")
    (should (equal kc-counters '(1 0 0)))))

(ert-deftest test-kc-count:modifiers-1 ()
  (with-temp-buffer
    (kc-minor-mode 1)
    (define-key kc-mode-map (kbd "M-c") 'test1)
    (key-combo-define kc-mode-map (kbd "M-c a") 'test2)
    (key-combo-define kc-mode-map (kbd "M-c a b") 'test3)
    (kc-reset)
    (kc-execute-keyseq "M-c a b")
    (should (equal kc-counters '(1 1 1)))))

(ert-deftest test-kc-count:modifiers-2 ()
  (with-temp-buffer
    (kc-minor-mode 1)
    (define-key kc-mode-map (kbd "M-c") 'test1)
    (key-combo-define kc-mode-map (kbd "M-c a") 'test2)
    (key-combo-define kc-mode-map (kbd "M-c b") 'test3)
    (kc-reset)
    (kc-execute-keyseq "M-c a")
    (should (equal kc-counters '(1 1 0)))))

;; Not working. Prefix command is not triggering pre-command-hook.
;; (ert-deftest test-kc-count:prefix ()
;;   (with-temp-buffer
;;     (kc-minor-mode 1)
;;     (switch-to-buffer (current-buffer))
;;     (define-prefix-command 'test-map)
;;     (define-key kc-mode-map (kbd "M-s") 'test-map)
;;     (define-key test-map (kbd "z") 'test3)
;;     (key-combo-define kc-mode-map (kbd "M-s") 'test1)
;;     (key-combo-define kc-mode-map (kbd "M-s a") 'test2)
;;     (kc-reset)
;;     (kc-execute-keyseq "M-s z")
;;     (should (equal kc-counters '(1 0 1)))))



;;; MODES

(ert-deftest test-kc-isearch-mode ()
  ;; don't raise error from isearch-search
  (with-temp-buffer
    (kc-minor-mode)
    (key-combo-load-default-1 kc-mode-map key-combo-common-default)
    (execute-kbd-macro "=")
    (should (string= (buffer-string) " = "))
    (isearch-mode nil "=") ;; backward search
    (execute-kbd-macro "=")
    (should (string= (buffer-string) " = "))
    (should (eq (point) 2))))

(ert-deftest test-kc-lisp-mode ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (kc-minor-mode 1)
    (key-combo-load-default-1 kc-mode-map key-combo-lisp-default)
    (let ((bf (current-buffer)))
      (should (string= (kc-execute-command ";." bf) ";; ."))
      (should (string= (kc-execute-command "=" bf) "= "))
      (should (string= (kc-execute-command "==" bf) "eq "))
      (should (string= (kc-execute-command "," bf) ","))
      (should (string= (kc-execute-command ",," bf) ",,"))
      (should (string= (kc-execute-command "." bf) "."))
      (should (string= (kc-execute-command ". SPC" bf) " . "))
      (should (string= (kc-execute-command ";" bf) ";; "))
      (should (string= (kc-execute-command ";," bf) ";; ,"))
      (erase-buffer)
      (insert ";")
      (should (string= (kc-execute-command "=" bf t) ";=")))))

(ert-deftest test-kc-ruby ()
  (with-temp-buffer
    (let ((bf (current-buffer)))
      (setq ruby-mode-hook nil)
      (ruby-mode)
      (kc-minor-mode 1)
      (key-combo-load-default-1 kc-mode-map key-combo-common-default)
      (should (string= (kc-execute-command "=~" bf) " =~ "))
      (should (string= (kc-execute-command "&&=" bf) " &&= "))
      (should (string= (kc-execute-command "||=" bf) " ||= "))
      (buffer-enable-undo)
      (should (string= (kc-execute-command "." bf) "."))
      (should (string= (kc-execute-command ".." bf) ".."))
      (should (string= (kc-execute-command "..." bf) "..."))
      (should (string= (kc-execute-command "!~" bf) " !~ "))
      (should (string= (kc-execute-command "**" bf) "**"))
      (should (string= (kc-execute-command "||=" bf) " ||= ")))))

(ert-deftest test-kc-c ()
  (with-temp-buffer
    (let ((bf (current-buffer)))
      (setq c-mode-hook nil)
      (c-mode)
      (kc-minor-mode 1)
      (key-combo-load-default-1 kc-mode-map key-combo-common-default)
      (should (string= (kc-execute-command "+" bf) " + "))
      (should (string= (kc-execute-command "++" bf) "++"))
      (should (equal (listify-key-sequence "+") '(43)))
      (should (string= (key-description '(?+)) "+"))
      (should (equal (key-combo-make-key-vector '(?+)) [key-combo _+]))
      (should (key-binding (key-combo-make-key-vector '(?+))))
      (should (lookup-key (current-local-map) (key-combo-make-key-vector '(?+))))
      (should (key-combo-get-command "+"))
      (should-not (equal (key-binding (key-combo-make-key-vector '(?+))) 'key-combo-execute-original))
      (should-not (equal (key-combo-get-command "+") 'key-combo-execute-original))
      (key-combo-define-local "a" nil)
      ;; accept-default bug?
      (should (eq (lookup-key (current-local-map) (key-combo-make-key-vector '(?a))) nil))
      (key-combo-define-local "a" "a")
      (should (not (equal (lookup-key (current-local-map) (key-combo-make-key-vector '(?a))) nil)))
      (key-combo-define-local "a" nil)
      (buffer-enable-undo)
      (should (string= (kc-execute-command "+" bf) " + "))
      (should (string= (kc-execute-command "++" bf) "++")))))



;;; MISC

(when (require 'el-mock nil t)
  (ert-deftest test-kc-mocks ()
    (with-temp-buffer
      (kc-mode)
      ;; the following definitions should not trigger errors
      (with-mock
       (mock (define-key * * *) :times 1)
       (key-combo-define-local "a" "a"))
      (with-mock
       (mock (define-key * * *) :times 1)
       (key-combo-define-local "a" '("a")))
      (with-mock
       (mock (define-key * * *) :times 2)
       (key-combo-define-local "a" '("a" "b")))
      (with-mock
       (mock (lookup-key * *) => t :times 2)
       (mock (define-key * * *) :times 2) ;; 1 for recursive call?
       (key-combo-define-local "a" '("a" "b"))))))

(when (require 'skk-autoloads nil t)
  (ert-deftest test-kc-skk ()
    (with-temp-buffer
      (skk-mode 1)
      (kc-minor-mode 1)
      (setq this-command 'skk-insert)
      (let ((bf (current-buffer)))
	(insert ";")
	(should (string= (kc-execute-command "," bf t) ";、"))
	(erase-buffer)
	(insert ";")
	(should (string= (kc-execute-command "." bf t) ";。"))))))
