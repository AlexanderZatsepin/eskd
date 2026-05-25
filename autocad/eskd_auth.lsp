;;; ESKD API authorization helper for AutoCAD 2016-2018.
;;; Loads with APPLOAD, then use commands: ESKD_LOGIN, ESKD_STATUS, ESKD_LOGOUT.
;;; Token is stored only in AutoCAD memory for the current session.

(vl-load-com)

(setq *eskd-server-url* nil)
(setq *eskd-username* nil)
(setq *eskd-token* nil)
(setq *eskd-default-server-url* "http://172.16.51.49:8010")

(defun eskd-trim-right-slash (value / len)
  (if (and value (> (strlen value) 0))
    (progn
      (setq len (strlen value))
      (while (and (> len 0) (= (substr value len 1) "/"))
        (setq value (substr value 1 (1- len)))
        (setq len (strlen value))
      )
      value
    )
    value
  )
)

(defun eskd-json-escape (value / result i ch)
  (setq result "")
  (setq i 1)
  (while (<= i (strlen value))
    (setq ch (substr value i 1))
    (cond
      ((= ch "\\") (setq result (strcat result "\\\\")))
      ((= ch "\"") (setq result (strcat result "\\\"")))
      ((= ch "\n") (setq result (strcat result "\\n")))
      ((= ch "\r") (setq result (strcat result "\\r")))
      ((= ch "\t") (setq result (strcat result "\\t")))
      (T (setq result (strcat result ch)))
    )
    (setq i (1+ i))
  )
  result
)

(defun eskd-json-token-value (json key / pattern start end value)
  ;; Minimal parser for flat JSON responses like {"token":"..."}.
  (setq pattern (strcat "\"" key "\":"))
  (setq start (vl-string-search pattern json))
  (if start
    (progn
      (setq start (+ start (strlen pattern)))
      (while (and (< start (strlen json))
                  (member (substr json (1+ start) 1) '(" " "\t" "\r" "\n")))
        (setq start (1+ start))
      )
      (if (= (substr json (1+ start) 1) "\"")
        (progn
          (setq start (+ start 2))
          (setq end start)
          (while (and (<= end (strlen json))
                      (/= (substr json end 1) "\""))
            (setq end (1+ end))
          )
          (setq value (substr json start (- end start)))
        )
      )
    )
  )
  value
)

(defun eskd-http-post-json (url body / http status response)
  (setq http (vlax-create-object "WinHttp.WinHttpRequest.5.1"))
  (vlax-invoke-method http "Open" "POST" url :vlax-false)
  (vlax-invoke-method http "SetRequestHeader" "Content-Type" "application/json")
  (vlax-invoke-method http "SetRequestHeader" "Accept" "application/json")
  (vlax-invoke-method http "Send" body)
  (setq status (vlax-get-property http "Status"))
  (setq response (vlax-get-property http "ResponseText"))
  (vlax-release-object http)
  (list status response)
)

(defun eskd-login-request (server-url username password / url body result status response token)
  (setq url (strcat (eskd-trim-right-slash server-url) "/api/auth/token/"))
  (setq body
    (strcat
      "{\"username\":\"" (eskd-json-escape username)
      "\",\"password\":\"" (eskd-json-escape password)
      "\"}"
    )
  )
  (setq result (eskd-http-post-json url body))
  (setq status (car result))
  (setq response (cadr result))
  (if (= status 200)
    (progn
      (setq token (eskd-json-token-value response "token"))
      (if (and token (> (strlen token) 0))
        (list T token response)
        (list nil nil "Token was not found in server response.")
      )
    )
    (list nil nil (strcat "HTTP " (itoa status) ": " response))
  )
)

(defun c:ESKD_LOGIN (/ default-url server-url username password result)
  (setq default-url
    (if *eskd-server-url*
      *eskd-server-url*
      *eskd-default-server-url*
    )
  )
  (setq server-url (getstring T (strcat "\nESKD server URL <" default-url ">: ")))
  (if (= server-url "")
    (setq server-url default-url)
  )
  (setq username (getstring T "\nUsername: "))
  (setq password (getstring T "\nPassword: "))
  (princ "\nRequesting token...")
  (setq result (eskd-login-request server-url username password))
  (if (car result)
    (progn
      (setq *eskd-server-url* (eskd-trim-right-slash server-url))
      (setq *eskd-username* username)
      (setq *eskd-token* (cadr result))
      (princ "\nESKD login successful. Token is stored in memory.")
    )
    (progn
      (setq *eskd-token* nil)
      (princ (strcat "\nESKD login failed: " (caddr result)))
    )
  )
  (princ)
)

(defun c:ESKD_STATUS ()
  (if (and *eskd-server-url* *eskd-username* *eskd-token*)
    (progn
      (princ (strcat "\nESKD server: " *eskd-server-url*))
      (princ (strcat "\nESKD username: " *eskd-username*))
      (princ "\nESKD token: present in memory")
    )
    (princ "\nESKD is not authorized in this AutoCAD session.")
  )
  (princ)
)

(defun c:ESKD_LOGOUT ()
  (setq *eskd-token* nil)
  (setq *eskd-username* nil)
  (princ "\nESKD token removed from memory.")
  (princ)
)

(defun eskd-auth-header ()
  (if *eskd-token*
    (strcat "Token " *eskd-token*)
    nil
  )
)

(princ "\nESKD auth loaded. Commands: ESKD_LOGIN, ESKD_STATUS, ESKD_LOGOUT.")
(princ)
