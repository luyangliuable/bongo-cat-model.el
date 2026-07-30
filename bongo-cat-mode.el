;;; bongo-cat-mode.el --- Bongo Cat types in your mode-line -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Luyang Liu

;; Author: Luyang Liu <luyang.l@aol.com>
;; Maintainer: Luyang Liu <luyang.l@aol.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, games, multimedia
;; URL: https://github.com/luyangliuable/bongo-cat-model.el
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Bongo Cat Mode displays a small coding cat in the mode-line.  The cat
;; switches between typing frames whenever text is inserted, then returns to an
;; idle frame after typing stops.
;;
;; Enable it with:
;;
;;   M-x bongo-cat-mode
;;
;; Or from init.el:
;;
;;   (bongo-cat-mode 1)

;;; Code:

(require 'seq)

;;;; Constants

(defconst bongo-cat-mode-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing bongo-cat-mode assets.")

(defconst bongo-cat-mode--frame-names
  ["idle" "type-1" "type-2"]
  "Names used for idle and typing frame image files.")

;;;; Customization

(defgroup bongo-cat nil
  "Bongo Cat in the mode-line."
  :group 'mode-line
  :prefix "bongo-cat-")

(defun bongo-cat-mode-clear-cache ()
  "Clear cached Bongo Cat image specs and rendered images."
  (interactive)
  (when (boundp 'bongo-cat-mode--image-cache)
    (setq bongo-cat-mode--image-cache nil))
  (when (boundp 'bongo-cat-mode--rail-cache)
    (setq bongo-cat-mode--rail-cache nil))
  (when (fboundp 'clear-image-cache)
    (ignore-errors
      (clear-image-cache)))
  (force-mode-line-update t))

(defcustom bongo-cat-height 28
  "Height of the Bongo Cat image in pixels."
  :type 'natnum
  :set (lambda (sym val)
         (set-default sym val)
         (bongo-cat-mode-clear-cache))
  :group 'bongo-cat)

(defcustom bongo-cat-color-scheme 'white
  "Color scheme used for Bongo Cat image frames."
  :type '(choice (const :tag "White cat" white)
                 (const :tag "Black cat" black))
  :set (lambda (sym val)
         (set-default sym val)
         (bongo-cat-mode-clear-cache))
  :group 'bongo-cat)

(defcustom bongo-cat-animation-frame-interval 0.12
  "Seconds between typing animation frames."
  :type 'float
  :group 'bongo-cat)

(defcustom bongo-cat-idle-timeout 0.35
  "Seconds to keep Bongo Cat typing after the last insertion."
  :type 'float
  :group 'bongo-cat)

(defcustom bongo-cat-minimum-window-width 40
  "Minimum window width needed before Bongo Cat is shown."
  :type 'natnum
  :group 'bongo-cat)

(defcustom bongo-cat-track-width 48
  "Length of the Bongo Cat scroll track in mode-line cells.
Used by `bongo-cat-scroll-mode' to slide the flat cat left and right
as you move through the buffer."
  :type 'natnum
  :group 'bongo-cat)

(defcustom bongo-cat-track-line-char ?\N{BOX DRAWINGS LIGHT HORIZONTAL}
  "Character used for the track ahead of the cat (remaining scroll)."
  :type 'character
  :group 'bongo-cat)

(defcustom bongo-cat-track-fill-char ?\N{BOX DRAWINGS HEAVY HORIZONTAL}
  "Character used for the track behind the cat (scrolled progress)."
  :type 'character
  :group 'bongo-cat)

(defcustom bongo-cat-track-face 'shadow
  "Face applied to the Bongo Cat scroll track."
  :type 'face
  :group 'bongo-cat)

(defcustom bongo-cat-track-baseline 0.5
  "Fraction of the flat cat image above its body-bottom line.
The flat cat image is padded so its body-underside (table) line is at
the vertical center, so the default of 0.5 puts the track rail on that
line with the paws hanging below."
  :type 'float
  :set (lambda (sym val)
         (set-default sym val)
         (bongo-cat-mode-clear-cache))
  :group 'bongo-cat)

(defcustom bongo-cat-track-raise 0.0
  "Vertical `(raise ...)' offset applied to the track rail characters.
Use this to nudge the rail so it lines up exactly with the bottom of
the cat's body in your font."
  :type 'float
  :group 'bongo-cat)

;;;; Internal state

;; Forward declarations for the minor-mode variables, which are
;; referenced by helpers defined before the modes themselves.
(defvar bongo-cat-mode)
(defvar bongo-cat-scroll-mode)

(defvar bongo-cat-mode--image-cache nil
  "Alist of cached Bongo Cat image vectors.
Each entry is (KEY . IMAGES) where KEY is
\(COLOR-SCHEME HEIGHT VARIANT).")

(defvar bongo-cat-mode--rail-cache nil
  "Alist of cached scroll-track rail-tile images.
Each entry is (KEY . IMAGE) where KEY is
\(COLOR-SCHEME HEIGHT BASELINE KIND).")

(defvar bongo-cat-mode--animation-timer nil
  "Timer used while Bongo Cat is typing.")

(defvar bongo-cat-mode--idle-timer nil
  "Timer that returns Bongo Cat to the idle frame.")

(defvar bongo-cat-mode--frame-index 0
  "Current Bongo Cat frame index.")

(defvar bongo-cat-mode--typing-p nil
  "Non-nil while recent typing should animate Bongo Cat.")

(defconst bongo-cat-mode--mode-line-form
  '(:eval (bongo-cat-mode-format))
  "Mode-line form installed by `bongo-cat-mode'.")

;;;; Images and rail tiles

(defun bongo-cat-mode--image-supported-p ()
  "Return non-nil when PNG images can be created."
  (image-type-available-p 'png))

(defun bongo-cat-mode--image-file (index &optional variant)
  "Return image file name for frame INDEX.
VARIANT is `angled' (default) or `flat'."
  (if (eq variant 'flat)
      (format "bongo-cat-%s-flat-%s.png"
              bongo-cat-color-scheme
              (aref bongo-cat-mode--frame-names index))
    (format "bongo-cat-%s-%s.png"
            bongo-cat-color-scheme
            (aref bongo-cat-mode--frame-names index))))

(defun bongo-cat-mode--asset-path (file)
  "Return a readable path for asset FILE, searching the package dirs."
  (let ((candidates (list (expand-file-name file bongo-cat-mode-directory)
                          (expand-file-name file
                                            (expand-file-name "img"
                                                              bongo-cat-mode-directory)))))
    (or (seq-find #'file-readable-p candidates)
        (car candidates))))

(defun bongo-cat-mode--image-path (index &optional variant)
  "Return image path for frame INDEX and VARIANT."
  (bongo-cat-mode--asset-path (bongo-cat-mode--image-file index variant)))

(defun bongo-cat-mode--rail-image (kind)
  "Return a cached rail-tile image for KIND (`solid' or `faint').
The tile matches the flat cat's border color and thickness and is
aligned so its line sits on the same track baseline as the cat."
  (when (bongo-cat-mode--image-supported-p)
    (let* ((key (list bongo-cat-color-scheme bongo-cat-height
                      bongo-cat-track-baseline kind))
           (cached (assoc key bongo-cat-mode--rail-cache)))
      (if cached
          (cdr cached)
        (let* ((file (bongo-cat-mode--asset-path
                      (format "bongo-cat-%s-rail-%s.png"
                              bongo-cat-color-scheme kind)))
               (ascent (max 0 (min 100 (round (* 100 bongo-cat-track-baseline)))))
               (image (and (file-readable-p file)
                           (create-image file 'png nil
                                         :ascent ascent
                                         :height bongo-cat-height))))
          (push (cons key image) bongo-cat-mode--rail-cache)
          image)))))

(defun bongo-cat-mode--create-image (index &optional variant)
  "Create image spec for frame INDEX and VARIANT."
  (let ((file (bongo-cat-mode--image-path index variant))
        (ascent (if (eq variant 'flat)
                    (max 0 (min 100 (round (* 100 bongo-cat-track-baseline))))
                  'center)))
    (when (and (file-readable-p file)
               (bongo-cat-mode--image-supported-p))
      (create-image file 'png nil
                    :ascent ascent
                    :height bongo-cat-height))))

(defun bongo-cat-mode--images (&optional variant)
  "Return cached vector of Bongo Cat images for VARIANT."
  (when (bongo-cat-mode--image-supported-p)
    (let* ((variant (or variant 'angled))
           (key (list bongo-cat-color-scheme bongo-cat-height variant))
           (cached (assoc key bongo-cat-mode--image-cache)))
      (if cached
          (cdr cached)
        (let ((images (vconcat (mapcar (lambda (i)
                                         (bongo-cat-mode--create-image i variant))
                                       '(0 1 2)))))
          (push (cons key images) bongo-cat-mode--image-cache)
          images)))))

(defun bongo-cat-mode--current-frame ()
  "Return current Bongo Cat frame index."
  (if bongo-cat-mode--typing-p
      bongo-cat-mode--frame-index
    0))

(defun bongo-cat-mode--display-string (&optional variant)
  "Return the image for the current Bongo Cat frame and VARIANT."
  (let* ((index (bongo-cat-mode--current-frame))
         (image (and (bongo-cat-mode--image-supported-p)
                     (aref (bongo-cat-mode--images variant) index))))
    (if image
        (propertize " " 'display image)
      "")))

;;;###autoload
(defun bongo-cat-mode-format ()
  "Return Bongo Cat for use in a mode-line segment."
  (if (< (window-width) bongo-cat-minimum-window-width)
      ""
    (propertize (bongo-cat-mode--display-string)
                'help-echo "Bongo Cat types when you type.")))


;;;; Animation and typing

(defun bongo-cat-mode--timer-live-p (timer)
  "Return non-nil when TIMER is live."
  (and (timerp timer) timer))

(defun bongo-cat-mode--tick ()
  "Advance Bongo Cat's typing animation."
  (when bongo-cat-mode--typing-p
    (setq bongo-cat-mode--frame-index
          (if (= bongo-cat-mode--frame-index 1) 2 1))
    (force-mode-line-update t)))

(defun bongo-cat-mode--start-animation ()
  "Start Bongo Cat's animation timer."
  (unless (bongo-cat-mode--timer-live-p bongo-cat-mode--animation-timer)
    (setq bongo-cat-mode--animation-timer
          (run-with-timer 0 bongo-cat-animation-frame-interval
                          #'bongo-cat-mode--tick))))

(defun bongo-cat-mode--stop-animation ()
  "Stop Bongo Cat's animation timer."
  (when (bongo-cat-mode--timer-live-p bongo-cat-mode--animation-timer)
    (cancel-timer bongo-cat-mode--animation-timer)
    (setq bongo-cat-mode--animation-timer nil)))

(defun bongo-cat-mode--become-idle ()
  "Return Bongo Cat to its idle state."
  (setq bongo-cat-mode--typing-p nil
        bongo-cat-mode--frame-index 0
        bongo-cat-mode--idle-timer nil)
  (bongo-cat-mode--stop-animation)
  (force-mode-line-update t))

(defun bongo-cat-mode--schedule-idle ()
  "Schedule Bongo Cat's return to the idle frame."
  (when (bongo-cat-mode--timer-live-p bongo-cat-mode--idle-timer)
    (cancel-timer bongo-cat-mode--idle-timer))
  (setq bongo-cat-mode--idle-timer
        (run-at-time bongo-cat-idle-timeout nil
                     #'bongo-cat-mode--become-idle)))

(defun bongo-cat-mode--post-self-insert ()
  "Animate Bongo Cat after a self-insert command."
  (setq bongo-cat-mode--typing-p t)
  (when (zerop bongo-cat-mode--frame-index)
    (setq bongo-cat-mode--frame-index 1))
  (bongo-cat-mode--start-animation)
  (bongo-cat-mode--schedule-idle)
  (force-mode-line-update t))

;;;; Mode-line plumbing

(defun bongo-cat-mode--install-mode-line (form)
  "Install FORM into `global-mode-string'."
  (unless (member form global-mode-string)
    (setq global-mode-string
          (append global-mode-string (list form)))))

(defun bongo-cat-mode--uninstall-mode-line (form)
  "Remove FORM from `global-mode-string'."
  (setq global-mode-string
        (delete form global-mode-string)))

(defun bongo-cat-mode--any-active-p ()
  "Return non-nil when any Bongo Cat mode is active."
  (or (bound-and-true-p bongo-cat-mode)
      (bound-and-true-p bongo-cat-scroll-mode)))

(defun bongo-cat-mode--maybe-remove-hook ()
  "Remove the typing hook when no Bongo Cat mode remains active."
  (unless (bongo-cat-mode--any-active-p)
    (remove-hook 'post-self-insert-hook
                 #'bongo-cat-mode--post-self-insert)))

;;;; bongo-cat-mode

;;;###autoload
(define-minor-mode bongo-cat-mode
  "Display a typing Bongo Cat in the mode-line."
  :global t
  :group 'bongo-cat
  (if bongo-cat-mode
      (progn
        (bongo-cat-mode-clear-cache)
        (bongo-cat-mode--install-mode-line bongo-cat-mode--mode-line-form)
        (add-hook 'post-self-insert-hook
                  #'bongo-cat-mode--post-self-insert))
    (bongo-cat-mode--uninstall-mode-line bongo-cat-mode--mode-line-form)
    (bongo-cat-mode--maybe-remove-hook)
    (when (bongo-cat-mode--timer-live-p bongo-cat-mode--idle-timer)
      (cancel-timer bongo-cat-mode--idle-timer)
      (setq bongo-cat-mode--idle-timer nil))
    (bongo-cat-mode--become-idle))
  (force-mode-line-update t))

;;;; bongo-cat-scroll-mode

(defvar bongo-cat-scroll-mode nil)

(defconst bongo-cat-scroll-mode--mode-line-form
  '(:eval (bongo-cat-scroll-mode-format))
  "Mode-line form installed by `bongo-cat-scroll-mode'.")

(defun bongo-cat-scroll-mode--progress ()
  "Return the window's scroll position as a float in [0.0, 1.0].
Mirrors the `sml-modeline'/`%p' convention: 0.0 when the top of the
buffer is visible and 1.0 when the last screenful is shown, so the cat
tracks scrolling (viewport) rather than the cursor."
  (let* ((min (point-min))
         (max (point-max))
         (top (window-start))
         ;; The non-nil UPDATE arg forces an accurate `window-end'.
         (bottom (window-end nil t))
         (span (- bottom top))
         (denom (- (- max min) span)))
    (cond
     ((<= max min) 0.0)
     ;; Whole buffer fits in the window: nothing to scroll.
     ((<= denom 0) 0.0)
     (t (min 1.0 (max 0.0 (/ (float (- top min))
                             (float denom))))))))

(defun bongo-cat-scroll-mode--rail (length kind)
  "Return a rail segment LENGTH cells long for KIND (`solid' or `faint').
Uses matching line-tile images when available, otherwise falls back to
box-drawing characters."
  (if (<= length 0)
      ""
    (let ((image (bongo-cat-mode--rail-image kind)))
      (if image
          ;; Each cell needs its own (non-`eq') display spec, otherwise
          ;; Emacs renders one image for the whole run of identical cells
          ;; and the track collapses to a single tile.
          (mapconcat (lambda (_)
                       (propertize " " 'display (copy-sequence image)))
                     (number-sequence 1 length) "")
        (let ((char (if (eq kind 'solid)
                        bongo-cat-track-fill-char
                      bongo-cat-track-line-char))
              (props (list 'face bongo-cat-track-face)))
          (unless (zerop bongo-cat-track-raise)
            (setq props (append props
                                (list 'display (list 'raise bongo-cat-track-raise)))))
          (apply #'propertize (make-string length char) props))))))

;;;###autoload
(defun bongo-cat-scroll-mode-format ()
  "Return a flat Bongo Cat that slides along a scroll track."
  (if (< (window-width) bongo-cat-minimum-window-width)
      ""
    (let* ((width (max 1 bongo-cat-track-width))
           (progress (bongo-cat-scroll-mode--progress))
           (pos (round (* progress (1- width))))
           (left (bongo-cat-scroll-mode--rail pos 'solid))
           (right (bongo-cat-scroll-mode--rail (- width 1 pos) 'faint))
           (cat (bongo-cat-mode--display-string 'flat)))
      (propertize (concat left cat right)
                  'help-echo "Bongo Cat slides as you scroll."))))

;;;###autoload
(define-minor-mode bongo-cat-scroll-mode
  "Display a flat Bongo Cat that slides along the mode-line as you scroll.
The cat moves right as you move down the buffer and left as you move up,
clamping at both ends.  It still animates its paws while you type."
  :global t
  :group 'bongo-cat
  (if bongo-cat-scroll-mode
      (progn
        (bongo-cat-mode-clear-cache)
        (bongo-cat-mode--install-mode-line
         bongo-cat-scroll-mode--mode-line-form)
        (add-hook 'post-self-insert-hook
                  #'bongo-cat-mode--post-self-insert))
    (bongo-cat-mode--uninstall-mode-line
     bongo-cat-scroll-mode--mode-line-form)
    (bongo-cat-mode--maybe-remove-hook)
    (when (bongo-cat-mode--timer-live-p bongo-cat-mode--idle-timer)
      (cancel-timer bongo-cat-mode--idle-timer)
      (setq bongo-cat-mode--idle-timer nil))
    (bongo-cat-mode--become-idle))
  (force-mode-line-update t))

(provide 'bongo-cat-mode)

;;; bongo-cat-mode.el ends here
