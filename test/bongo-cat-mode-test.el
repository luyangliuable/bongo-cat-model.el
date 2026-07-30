;;; bongo-cat-mode-test.el --- Tests for bongo-cat-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Luyang Liu

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT test suite for bongo-cat-mode.  These tests cover the pure,
;; non-GUI logic; image creation is only exercised where PNG support is
;; available.

;;; Code:

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
