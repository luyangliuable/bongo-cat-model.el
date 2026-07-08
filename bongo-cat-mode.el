;;; bongo-cat-mode.el --- Bongo Cat types in your mode-line -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Luyang Liu

;; Author: Luyang Liu
;; Maintainer: Luyang Liu
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, games, multimedia
;; URL: https://github.com/luyangliu/bongo-cat-mode
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

(defconst bongo-cat-mode-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing bongo-cat-mode assets.")

(defconst bongo-cat-mode--image-files
  ["bongo-cat-idle.png"
   "bongo-cat-type-1.png"
   "bongo-cat-type-2.png"]
  "PNG files used for idle and typing frames.")

(defgroup bongo-cat nil
  "Bongo Cat in the mode-line."
  :group 'mode-line
  :prefix "bongo-cat-")

(defcustom bongo-cat-height 24
  "Height of the Bongo Cat image in pixels."
  :type 'natnum
  :set (lambda (sym val)
         (set-default sym val)
         (when (boundp 'bongo-cat-mode--image-cache)
           (setq bongo-cat-mode--image-cache nil))
         (force-mode-line-update t))
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

(defvar bongo-cat-mode--image-cache nil
  "Cached Bongo Cat image specs.")

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

(defun bongo-cat-mode--image-supported-p ()
  "Return non-nil when PNG images can be created."
  (image-type-available-p 'png))

(defun bongo-cat-mode--image-path (index)
  "Return image path for frame INDEX."
  (let* ((file (aref bongo-cat-mode--image-files index))
         (candidates (list (expand-file-name file bongo-cat-mode-directory)
                           (expand-file-name file
                                             (expand-file-name "img"
                                                               bongo-cat-mode-directory)))))
    (or (seq-find #'file-readable-p candidates)
        (car candidates))))

(defun bongo-cat-mode--create-image (index)
  "Create image spec for frame INDEX."
  (let ((file (bongo-cat-mode--image-path index)))
    (when (and (file-readable-p file)
               (bongo-cat-mode--image-supported-p))
      (create-image file 'png nil
                    :ascent 'center
                    :height bongo-cat-height))))

(defun bongo-cat-mode--images ()
  "Return cached vector of Bongo Cat images."
  (when (bongo-cat-mode--image-supported-p)
    (or bongo-cat-mode--image-cache
        (setq bongo-cat-mode--image-cache
              (vconcat (mapcar #'bongo-cat-mode--create-image '(0 1 2)))))))

(defun bongo-cat-mode--current-frame ()
  "Return current Bongo Cat frame index."
  (if bongo-cat-mode--typing-p
      bongo-cat-mode--frame-index
    0))

(defun bongo-cat-mode--display-string ()
  "Return the image for the current Bongo Cat frame."
  (let* ((index (bongo-cat-mode--current-frame))
         (image (and (bongo-cat-mode--image-supported-p)
                     (aref (bongo-cat-mode--images) index))))
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

(defun bongo-cat-mode--install-mode-line ()
  "Install Bongo Cat into `global-mode-string'."
  (unless (member bongo-cat-mode--mode-line-form global-mode-string)
    (setq global-mode-string
          (append global-mode-string
                  (list bongo-cat-mode--mode-line-form)))))

(defun bongo-cat-mode--uninstall-mode-line ()
  "Remove Bongo Cat from `global-mode-string'."
  (setq global-mode-string
        (delete bongo-cat-mode--mode-line-form global-mode-string)))

;;;###autoload
(define-minor-mode bongo-cat-mode
  "Display a typing Bongo Cat in the mode-line."
  :global t
  :group 'bongo-cat
  (if bongo-cat-mode
      (progn
        (bongo-cat-mode--install-mode-line)
        (add-hook 'post-self-insert-hook
                  #'bongo-cat-mode--post-self-insert))
    (remove-hook 'post-self-insert-hook
                 #'bongo-cat-mode--post-self-insert)
    (bongo-cat-mode--uninstall-mode-line)
    (when (bongo-cat-mode--timer-live-p bongo-cat-mode--idle-timer)
      (cancel-timer bongo-cat-mode--idle-timer)
      (setq bongo-cat-mode--idle-timer nil))
    (bongo-cat-mode--become-idle))
  (force-mode-line-update t))

(provide 'bongo-cat-mode)

;;; bongo-cat-mode.el ends here
