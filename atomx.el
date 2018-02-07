;;; atomx.el --- Atomx API Client          -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Daniel Kraus

;; Author: Daniel Kraus <daniel@atomx.com>
;; Version: 0.1
;; Package-Requires: ((request "0.3.0") (emacs "24.4"))
;; Keywords: tools request atomx api
;; URL: https://github.com/atomx/atomx-api-elisp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Interface for the atomx rest api.
;;
;; You have to set `atomx-email' and `atomx-password' to your
;; atomx api credentials either by setting those variables directly
;; or by adding a line like the following to your `.authinfo' / `.authinfo.gpg'
;; "machine api.atomx.com login yourname@example.com password your-atomx-pass"

;; To use in elisp you first have to call `atomx-login' before you can
;; request resources from the api.
;; E.g. Login, get the publishers list and show the name of the first:
;;
;; (atomx-login)
;;
;; (atomx-get
;;  'publisher
;;  (lambda (p)
;;    (message "First publisher name: %s"
;;             (assoc-default 'name (aref atomx-pub 0)))))

;; Usage with restclient:
;; You must have an `:api' variable in your restclient buffer that specifies
;; the atomx api endpoint, e.g.:
;;
;;     :api = https://sandbox-api.atomx.com/v3
;;
;; and an `:auth-token' variable that holds the value of the auth-token.
;;
;; Then you can just call `M-x atomx-restclient-update-auth-token'
;; and atomx.el will parse the `:api' variable, get the correct
;; login info from your `.authinfo.gpg', fetch a new auth token
;; and set `:auth-token' accordingly.

;;; Code:

(require 'cl-lib)
(require 'request)

(defgroup atomx nil
  "Atomx"
  :prefix "atomx-"
  :group 'tools)

(defcustom atomx-api-domain "api.atomx.com"
  "Atomx API domain."
  :type 'string
  :safe #'stringp
  :group 'atomx)

(defcustom atomx-api-version "v3"
  "Atomx API version."
  :type 'string
  :safe #'stringp
  :group 'atomx)

(defcustom atomx-api-port 443
  "Atomx API port."
  :type 'integer
  :safe #'integerp
  :group 'atomx)

(defcustom atomx-email nil
  "Your atomx api email.
When nil read email from authinfo."
  :type 'string
  :safe #'stringp
  :group 'atomx)

(defcustom atomx-password nil
  "Your atomx api password.
When nil read password from authinfo."
  :type 'string
  :safe #'stringp
  :group 'atomx)

(defvar atomx--auth-token nil
  "Atomx API auth token.")


(defun atomx-api-url (model &rest slug)
  "Return atomx api url for MODEL with optional SLUG."
  (let ((proto (format "http%s" (if (= atomx-api-port 443) "s" "")))
        (domain atomx-api-domain)
        (port (if (not (or (= atomx-api-port 80) (= atomx-api-port 443)))
                  (format ":%s" atomx-api-port)
                ""))
        (version atomx-api-version)
        (slug (format "%s%s" model
                      (if slug
                          (concat "/" (mapconcat (lambda (s) (format "%s" s)) slug "/"))
                        ""))))
    (format "%s://%s%s/%s/%s" proto domain port version slug)))

;;;###autoload
(defun atomx-login (&optional callback api)
  "Login to atomx API and call CALLBACK with auth-token."
  (interactive)
  (let* ((atomx-api-domain (or api atomx-api-domain))
         (auth (auth-source-user-and-password atomx-api-domain))
         (email (or atomx-email (car auth)))
         (password (or atomx-password (cadr auth))))
    (if (and email password)
        (request
         (atomx-api-url 'login)
         :type "POST"
         :data (json-encode `(("email" . ,email)
                              ("password" . ,password)))
         :headers '(("User-Agent" . "Atomx Emacs Client")
                    ("Accept" . "application/json")
                    ("Content-Type" . "application/json;charset=utf-8"))
         :parser 'json-read
         :success (cl-function
                   (lambda (&key data &allow-other-keys)
                     (let ((_user (cdr (assoc 'user data)))
                           (atomx-message (cdr (assoc 'message data)))
                           (auth-token (cdr (assoc 'auth_token data))))
                       (setq atomx--auth-token auth-token)
                       (message atomx-message)
                       (when callback
                         (funcall callback auth-token)))))
         :error (cl-function (lambda (&rest args &key error-thrown &allow-other-keys)
                               (message "Got error %S while getting token" error-thrown))))
      (error "You have to set atomx api email and password"))))

(defun atomx-logout ()
  "Forget atomx auth-token."
  (interactive)
  (setq atomx--auth-token nil))


;;;###autoload
(defun atomx-get (model &optional success &rest slug)
  "Get atomx MODEL with optional SLUG attributes and SUCCESS callback."
  (interactive "sModel to get: ")
  (when (and success (not (functionp success)))
    (setq slug (cons success slug))
    (setq success nil))
  (request
   (apply #'atomx-api-url model slug)
   :type "GET"
   :headers `(("User-Agent" . "Atomx Emacs Client")
              ("Accept" . "application/json")
              ("Content-Type" . "application/json;charset=utf-8")
              ("Authorization" . ,(format "Bearer %s" atomx--auth-token)))
   :parser 'json-read
   :success (cl-function
             (lambda (&key data &allow-other-keys)
               (let* ((resource (cdr (assoc 'resource data)))
                      (model (cdr (assoc-string resource data))))
                 (if success
                     (funcall success model)
                   (message "%s: %S" resource model)))))
   :error (cl-function (lambda (&rest args &key error-thrown &allow-other-keys)
                         (message "Got error %S while getting model" error-thrown)))))



(defun atomx--restclient-get-endpoint ()
  "Extract the atomx api info from restclient buffer.
In your restclient buffer you should have some line like:
:api = https://api.atomx.com/v3"
  (save-excursion
    (goto-char (point-min))
    (re-search-forward "^:api")
    (skip-chars-forward " =")
    (let* ((url (buffer-substring-no-properties (point) (line-end-position)))
           (api (split-string url "/+"))
           (port (string-to-number
                  (or (cadr (split-string (nth 1 api) ":"))
                      (if (equal "https:" (nth 0 api)) "443" "80"))))
           (domain (car (split-string (nth 1 api) ":")))
           (version (nth 2 api)))
      (list `(domain . ,domain) `(version . ,version) `(port . ,port)))))

(defun atomx--restclient-update-auth (buffer auth-token)
  "Replace the `:auth-token` value in BUFFER with AUTH-TOKEN."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (re-search-forward "^:auth-token")
      (skip-chars-forward " =")
      (delete-region (point) (line-end-position))
      (insert auth-token))))

;;;###autoload
(defun atomx-restclient-update-auth-token ()
  "Update auth-token in buffer with new auth-token for selected endpoint.
Your restclient buffer should have a variable `:api' which ist the
api endpoint url e.g. `https://api.atomx.com/v3' and
a `:auth-token' variable which is used to store the auth token."
  (interactive)
  (if (eq major-mode 'restclient-mode)
      (let* ((buffer (current-buffer))
             (rest-endpoint (atomx--restclient-get-endpoint))
             (atomx-api-domain (cdr (assoc 'domain rest-endpoint)))
             (atomx-api-port (cdr (assoc 'port rest-endpoint)))
             (atomx-api-version (cdr (assoc 'version rest-endpoint))))
        (atomx-login (lambda (auth-token) (atomx--restclient-update-auth buffer auth-token))))
    (error "You need to be in a restclient buffer")))

(provide 'atomx)
;;; atomx.el ends here
