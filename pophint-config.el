;;; pophint-config.el --- provide configuration for pophint.el.

;; Copyright (C) 2013  Hiroaki Otsu

;; Author: Hiroaki Otsu <ootsuhiroaki@gmail.com>
;; Keywords: popup
;; URL: https://github.com/aki2o/emacs-pophint
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; 
;; This extension provides configuration for pophint.el.

;;; Dependency:
;; 
;; - pophint.el ( see <https://github.com/aki2o/emacs-pophint> )

;;; Installation:
;;
;; Put this to your load-path.
;; And put the following lines in your .emacs or site-start.el file.
;; 
;; (require 'pophint-config)

;;; Configuration:
;; 
;; ;; When set-mark-command, start pop-up hint automatically.
;; (pophint:set-automatically-when-marking t)
;; 
;; ;; When isearch, start pop-up hint automatically after exit isearch.
;; (pophint:set-automatically-when-isearch t)

;;; Customization:
;; 
;; Nothing

;;; API:
;; 
;; Nothing
;; 
;; [Note] Functions and variables other than listed above, Those specifications may be changed without notice.

;;; Tested On:
;; 
;; - Emacs ... GNU Emacs 23.3.1 (i386-mingw-nt5.1.2600) of 2011-08-15 on GNUPACK


;; Enjoy!!!


(require 'pophint)


;; Add yank action

(defvar pophint-config:yank-action (lambda (hint)
                                     (kill-new (pophint:hint-value hint))))

(pophint:defaction :key "y"
                   :name "Yank"
                   :description "Yank the text of selected hint-tip."
                   :action 'pophint-config:yank-action)

(defvar pophint-config:yank-startpt nil)

(defvar pophint-config:yank-range-action
  (lambda (hint)
    (let* ((buff (pophint:hint-buffer hint)))
      (save-window-excursion
        (save-excursion
          (when (and (buffer-live-p buff)
                     (get-buffer-window buff)
                     (not (eq (current-buffer) buff)))
            (switch-to-buffer buff))
          (goto-char (pophint:hint-startpt hint))
          (setq pophint-config:yank-startpt (point))
          (recenter 0)
          (delete-other-windows)
          (pophint:do :source '((regexp . "[a-zA-Z0-9_]+\\([^a-zA-Z0-9_]\\)")
                                (requires . 1))
                      :direction 'forward
                      :not-highlight t
                      :not-switch-window t
                      :action (lambda (hint)
                                (when (number-or-marker-p pophint-config:yank-startpt)
                                  (kill-new (buffer-substring-no-properties pophint-config:yank-startpt
                                                                            (pophint:hint-startpt hint)))))))))))

(pophint:defaction :key "Y"
                   :name "RangeYank"
                   :description "Yank the text getting end point by do pop-up at the selected point."
                   :action 'pophint-config:yank-range-action)


;; For mark

(defadvice set-mark-command (after do-pophint disable)
  (pophint--trace "start do when set-mark")
  (pophint:do :direction 'forward
              :not-highlight t
              :not-switch-window t
              :source '((method . (lambda ()
                                    (let* ((currpt (point))
                                           (startpt (progn (forward-word)
                                                           (point)))
                                           (endpt (save-excursion
                                                    (forward-word)
                                                    (point)))
                                           (value (buffer-substring-no-properties startpt endpt)))
                                      (when (< currpt startpt)
                                        (make-pophint:hint :startpt startpt :endpt endpt :value value))))))))

(defun pophint:set-automatically-when-marking (activate)
  "Whether the pop-up is automatically or not when set mark."
  (if activate
      (ad-enable-advice 'set-mark-command 'after 'do-pophint)
    (ad-disable-advice 'set-mark-command 'after 'do-pophint))
  (ad-activate 'set-mark-command))


;; For isearch

(defvar pophint-config:active-when-isearch-exit-p nil)
(defvar pophint-config:index-of-isearch-overlays 0)
(defadvice isearch-exit (before do-pophint disable)
  (when pophint-config:active-when-isearch-exit-p
    (pophint--trace "start do when isearch-exit")
    (pophint:do :not-highlight t
                :not-switch-window t
                :source '((init . (lambda ()
                                    (setq pophint-config:index-of-isearch-overlays 0)))
                          (method . (lambda ()
                                      (pophint--trace "overlay count:[%s] index:[%s]"
                                                      (length isearch-lazy-highlight-overlays)
                                                      pophint-config:index-of-isearch-overlays)
                                      (let* ((idx pophint-config:index-of-isearch-overlays)
                                             (ov (when (< idx (length isearch-lazy-highlight-overlays))
                                                   (nth idx isearch-lazy-highlight-overlays)))
                                             (pt (when ov (overlay-start ov)))
                                             (ret (when pt
                                                    (make-pophint:hint :startpt (overlay-start ov)
                                                                       :endpt (overlay-end ov)
                                                                       :value (buffer-substring-no-properties
                                                                               (overlay-start ov)
                                                                               (overlay-end ov))))))
                                        (when ov (incf pophint-config:index-of-isearch-overlays))
                                        (when pt (goto-char pt))
                                        ret)))
                          (action . (lambda (hint)
                                      (goto-char (pophint:hint-startpt hint))))))))

(defun pophint:set-automatically-when-isearch (activate)
  "Whether the pop-up is automatically or not when exit isearch."
  (if activate
      (ad-enable-advice 'isearch-exit 'before 'do-pophint)
    (ad-disable-advice 'isearch-exit 'before 'do-pophint))
  (ad-activate 'isearch-exit)
  (setq pophint-config:active-when-isearch-exit-p activate))


;; For elisp

(pophint:defsource :name "sexp-head"
                   :description "Head word of sexp."
                   :source '((shown . "SexpHead")
                             (regexp . "(+\\([^() \t\n]+\\)")
                             (requires . 1)))

(defun pophint:config-elisp-setup ()
  (add-to-list 'pophint:sources 'pophint:source-sexp-head))

(add-hook 'emacs-lisp-mode-hook 'pophint:config-elisp-setup t)


;; For Help

(pophint:defsource :name "help-btn"
                   :description "Button on help-mode."
                   :source '((shown . "Link")
                             (method . ((lambda ()
                                          (when (forward-button 1)
                                            (let* ((btn (button-at (point)))
                                                   (startpt (when btn (button-start btn)))
                                                   (endpt (when btn (button-end btn)))
                                                   (value (when btn (buffer-substring-no-properties startpt endpt))))
                                              (pophint--trace "found button. startpt:[%s] endpt:[%s] value:[%s]"
                                                              startpt endpt value)
                                              (when btn (make-pophint:hint :startpt startpt :endpt endpt :value value)))))
                                        (lambda ()
                                          (when (backward-button 1)
                                            (let* ((btn (button-at (point)))
                                                   (startpt (when btn (button-start btn)))
                                                   (endpt (when btn (button-end btn)))
                                                   (value (when btn (buffer-substring-no-properties startpt endpt))))
                                              (pophint--trace "found button. startpt:[%s] endpt:[%s] value:[%s]"
                                                              startpt endpt value)
                                              (when btn (make-pophint:hint :startpt startpt :endpt endpt :value value)))))))
                             (action . (lambda (hint)
                                         (goto-char (pophint:hint-startpt hint))
                                         (push-button)))))

(defun pophint:config-help-setup ()
  (add-to-list 'pophint:sources 'pophint:source-help-btn))

(add-hook 'help-mode-hook 'pophint:config-help-setup t)


;; For Info

(pophint:defsource :name "info-ref"
                   :description "Reference on info-mode."
                   :source '((shown . "Link")
                             (method . ((lambda ()
                                          (let* ((currpt (point))
                                                 (startpt (progn (Info-next-reference)
                                                                 (point)))
                                                 (endpt (next-property-change startpt))
                                                 (value (buffer-substring-no-properties startpt endpt)))
                                            (when (< currpt startpt)
                                              (make-pophint:hint :startpt startpt :endpt endpt :value value))))
                                        (lambda ()
                                          (let* ((currpt (point))
                                                 (startpt (progn (Info-prev-reference)
                                                                 (point)))
                                                 (endpt (next-property-change startpt))
                                                 (value (buffer-substring-no-properties startpt endpt)))
                                            (when (> currpt startpt)
                                              (make-pophint:hint :startpt startpt :endpt endpt :value value))))))
                             (action . (lambda (hint)
                                         (goto-char (pophint:hint-startpt hint))
                                         (Info-follow-nearest-node)))))

(defun pophint:config-info-setup ()
  (add-to-list 'pophint:sources 'pophint:source-info-ref))

(add-hook 'Info-mode-hook 'pophint:config-info-setup t)


;; For w3m

(pophint:defsource :name "w3m-anchor"
                   :description "Anchor on w3m."
                   :source '((shown . "Link")
                             (method . ((lambda ()
                                          (when (w3m-goto-next-anchor)
                                            (let* ((a (w3m-anchor (point)))
                                                   (title (w3m-anchor-title (point)))
                                                   (seq (w3m-anchor-sequence (point))))
                                              (pophint--trace "found anchor. a:[%s] title:[%s] seq:[%s]" a title seq)
                                              (make-pophint:hint :startpt (point)
                                                                 :endpt (+ (point) (length title))
                                                                 :value a))))
                                        (lambda ()
                                          (when (w3m-goto-previous-anchor)
                                            (let* ((a (w3m-anchor (point)))
                                                   (title (w3m-anchor-title (point)))
                                                   (seq (w3m-anchor-sequence (point))))
                                              (pophint--trace "found anchor. a:[%s] title:[%s] seq:[%s]" a title seq)
                                              (make-pophint:hint :startpt (point)
                                                                 :endpt (+ (point) (length title))
                                                                 :value a))))))
                             (action . (lambda (hint)
                                         (goto-char (pophint:hint-startpt hint))
                                         (w3m-view-this-url)))))

(defun pophint:config-w3m-setup ()
  (add-to-list 'pophint:sources 'pophint:source-w3m-anchor))

(add-hook 'w3m-mode-hook 'pophint:config-w3m-setup t)


(provide 'pophint-config)
;;; pophint-config.el ends here