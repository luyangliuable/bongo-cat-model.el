;;; bongo-cat-mode-test.el --- Tests for bongo-cat-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Luyang Liu

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT test suite for bongo-cat-mode.  These tests cover the pure,
;; non-GUI logic; image creation is only exercised where PNG support is
;; available.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'bongo-cat-mode)

;;;; Image file naming

(ert-deftest bongo-cat-mode-test-image-file-angled ()
  "Angled frames use the plain naming scheme."
  (let ((bongo-cat-color-scheme 'white))
    (should (equal (bongo-cat-mode--image-file 0) "bongo-cat-white-idle.png"))
    (should (equal (bongo-cat-mode--image-file 1) "bongo-cat-white-type-1.png"))
    (should (equal (bongo-cat-mode--image-file 2) "bongo-cat-white-type-2.png"))))

(ert-deftest bongo-cat-mode-test-image-file-flat ()
  "Flat frames include the `flat' segment and honour the color scheme."
  (let ((bongo-cat-color-scheme 'black))
    (should (equal (bongo-cat-mode--image-file 0 'flat)
                   "bongo-cat-black-flat-idle.png"))
    (should (equal (bongo-cat-mode--image-file 2 'flat)
                   "bongo-cat-black-flat-type-2.png"))))

;;;; Color schemes

(ert-deftest bongo-cat-mode-test-auto-color-scheme-light-mode-line ()
  "Automatic color selection uses white artwork on a light mode-line."
  (let ((bongo-cat-color-scheme 'auto))
    (cl-letf (((symbol-function 'face-background)
               (lambda (&rest _) "light"))
              ((symbol-function 'color-values)
               (lambda (_) '(65535 65535 65535))))
      (should (eq (bongo-cat-mode--effective-color-scheme) 'white)))))

(ert-deftest bongo-cat-mode-test-auto-color-scheme-dark-mode-line ()
  "Automatic color selection uses black artwork on a dark mode-line."
  (let ((bongo-cat-color-scheme 'auto))
    (cl-letf (((symbol-function 'face-background)
               (lambda (&rest _) "dark"))
              ((symbol-function 'color-values)
               (lambda (_) '(0 0 0))))
      (should (eq (bongo-cat-mode--effective-color-scheme) 'black)))))

(ert-deftest bongo-cat-mode-test-explicit-color-scheme-overrides-theme ()
  "An explicit color scheme does not inspect the mode-line face."
  (let ((bongo-cat-color-scheme 'white))
    (should (eq (bongo-cat-mode--effective-color-scheme) 'white))))

(ert-deftest bongo-cat-mode-test-mode-line-selected-compat-fallback ()
  "Mode-line selection has a fallback for older Emacs versions."
  (cl-letf (((symbol-function 'fboundp) (lambda (_) nil))
            ((symbol-function 'get-buffer-window)
             (lambda (_) (selected-window))))
    (should (bongo-cat-mode--mode-line-window-selected-p))))

(ert-deftest bongo-cat-mode-test-auto-color-scheme-uses-window-frame ()
  "Automatic color selection passes the mode-line frame to face lookup."
  (let ((bongo-cat-color-scheme 'auto)
        (expected-frame (selected-frame))
        seen-frame)
    (cl-letf (((symbol-function 'bongo-cat-mode--mode-line-frame)
               (lambda () expected-frame))
              ((symbol-function 'face-background)
               (lambda (_face frame _inherit)
                 (setq seen-frame frame)
                 "dark"))
              ((symbol-function 'color-values)
               (lambda (_) '(0 0 0))))
      (should (eq (bongo-cat-mode--effective-color-scheme) 'black))
      (should (eq seen-frame expected-frame)))))

;;;; Scroll progress

(ert-deftest bongo-cat-mode-test-progress-empty-buffer ()
  "An empty buffer reports zero scroll progress."
  (with-temp-buffer
    (should (equal (bongo-cat-scroll-mode--progress) 0.0))))

(ert-deftest bongo-cat-mode-test-progress-clamped ()
  "Progress is always a float within [0.0, 1.0]."
  (with-temp-buffer
    (dotimes (_ 500) (insert "line of text\n"))
    (let ((p (bongo-cat-scroll-mode--progress)))
      (should (floatp p))
      (should (<= 0.0 p))
      (should (<= p 1.0)))))

;;;; Rail rendering

(ert-deftest bongo-cat-mode-test-rail-empty ()
  "A non-positive rail length renders as the empty string."
  (should (equal (bongo-cat-scroll-mode--rail 0 'solid) ""))
  (should (equal (bongo-cat-scroll-mode--rail -3 'faint) "")))

(ert-deftest bongo-cat-mode-test-rail-length ()
  "A rail spans exactly LENGTH mode-line cells."
  (should (= (length (bongo-cat-scroll-mode--rail 5 'solid)) 5))
  (should (= (length (bongo-cat-scroll-mode--rail 12 'faint)) 12)))

;;;; Window-scoped animation

(ert-deftest bongo-cat-mode-test-typing-window-isolation ()
  "Only the window where insertion occurred is considered to be typing."
  (save-window-excursion
    (let* ((first (selected-window))
           (second (split-window-right))
           (bongo-cat-mode--typing-p t)
           (bongo-cat-mode--typing-window first))
      (with-selected-window first
        (should (bongo-cat-mode--typing-window-p)))
      (with-selected-window second
        (should-not (bongo-cat-mode--typing-window-p))))))

(ert-deftest bongo-cat-mode-test-tick-updates-only-typing-window ()
  "Animation ticks request redisplay only for the typing window."
  (let ((window (selected-window))
        (bongo-cat-mode--typing-p t)
        (bongo-cat-mode--typing-window (selected-window))
        (bongo-cat-mode--frame-index 1)
        updated-window)
    (cl-letf (((symbol-function 'force-window-update)
               (lambda (target) (setq updated-window target))))
      (bongo-cat-mode--tick))
    (should (eq updated-window window))
    (should (= bongo-cat-mode--frame-index 2))))

(ert-deftest bongo-cat-mode-test-deleted-typing-window-becomes-idle ()
  "A deleted typing window stops the animation without a global redisplay."
  (let ((bongo-cat-mode--typing-p t)
        (bongo-cat-mode--typing-window nil)
        (bongo-cat-mode--frame-index 1))
    (bongo-cat-mode--tick)
    (should-not bongo-cat-mode--typing-p)
    (should-not bongo-cat-mode--typing-window)
    (should (= bongo-cat-mode--frame-index 0))))

(ert-deftest bongo-cat-mode-test-become-idle-cancels-idle-timer ()
  "Becoming idle cancels the previous idle timer before clearing it."
  (let ((bongo-cat-mode--typing-p t)
        (bongo-cat-mode--typing-window nil)
        (bongo-cat-mode--frame-index 1)
        (bongo-cat-mode--idle-timer (timer-create))
        cancelled)
    (cl-letf (((symbol-function 'cancel-timer)
               (lambda (timer) (setq cancelled timer))))
      (bongo-cat-mode--become-idle))
    (should cancelled)
    (should-not bongo-cat-mode--idle-timer)))

;;;; Cache clearing

(ert-deftest bongo-cat-mode-test-clear-cache ()
  "Clearing the cache resets both image caches."
  (let ((bongo-cat-mode--image-cache '((key . vec)))
        (bongo-cat-mode--rail-cache '((key . img))))
    (bongo-cat-mode-clear-cache)
    (should (null bongo-cat-mode--image-cache))
    (should (null bongo-cat-mode--rail-cache))))

(provide 'bongo-cat-mode-test)

;;; bongo-cat-mode-test.el ends here
