;;; ESKD Project/Cabinet CRUD for AutoCAD 2016-2018.
;;; Load after autocad/eskd_auth.lsp.
;;;
;;; Commands:
;;;   ESKD_CONTEXT_SET, ESKD_CONTEXT_STATUS
;;;   ESKD_PROJECT_GET, ESKD_PROJECT_FIND, ESKD_PROJECT_CREATE, ESKD_PROJECT_UPDATE, ESKD_PROJECT_DELETE, ESKD_PROJECT_SYNC
;;;   ESKD_CABINET_GET, ESKD_CABINET_CREATE, ESKD_CABINET_UPDATE, ESKD_CABINET_DELETE, ESKD_CABINET_SYNC

(vl-load-com)

(setq *eskd-project-block-name* "BLOCK_TEST_PROJECT")
(setq *eskd-cabinet-block-name* "BLOCK_TEST_CABINET")
(setq *eskd-marking-block-name* "BLOCK_TEST_MARKING")

(if (not *eskd-current-project-id*) (setq *eskd-current-project-id* ""))
(if (not *eskd-current-project-code*) (setq *eskd-current-project-code* ""))
(if (not *eskd-current-project-name*) (setq *eskd-current-project-name* ""))
(if (not *eskd-current-cabinet-id*) (setq *eskd-current-cabinet-id* ""))
(if (not *eskd-current-cabinet-code*) (setq *eskd-current-cabinet-code* ""))
(if (not *eskd-current-cabinet-name*) (setq *eskd-current-cabinet-name* ""))
(if (not *eskd-current-cabinet-description*) (setq *eskd-current-cabinet-description* ""))
(if (not *eskd-project-records*) (setq *eskd-project-records* nil))
(if (not *eskd-project-options*) (setq *eskd-project-options* '("-")))
(if (not *eskd-selected-project-index*) (setq *eskd-selected-project-index* 0))
(if (not *eskd-cabinet-records*) (setq *eskd-cabinet-records* nil))
(if (not *eskd-cabinet-options*) (setq *eskd-cabinet-options* '("-")))
(if (not *eskd-selected-cabinet-index*) (setq *eskd-selected-cabinet-index* 0))

(defun eskd-require-auth ()
  (if (and *eskd-server-url* *eskd-token*)
    T
    (progn
      (princ "\nESKD is not authorized. Run ESKD_LOGIN first.")
      nil
    )
  )
)

(defun eskd-url-encode (value / result i ch code hex)
  (setq result "")
  (setq i 1)
  (while (<= i (strlen value))
    (setq ch (substr value i 1))
    (setq code (ascii ch))
    (if (or (and (>= code 48) (<= code 57))
            (and (>= code 65) (<= code 90))
            (and (>= code 97) (<= code 122))
            (member ch '("-" "_" "." "~")))
      (setq result (strcat result ch))
      (progn
        (setq hex "0123456789ABCDEF")
        (setq result
          (strcat
            result
            "%"
            (substr hex (1+ (/ code 16)) 1)
            (substr hex (1+ (rem code 16)) 1)
          )
        )
      )
    )
    (setq i (1+ i))
  )
  result
)

(defun eskd-api-url (path)
  (strcat (eskd-trim-right-slash *eskd-server-url*) path)
)

(defun eskd-http-json (method url body / http status response)
  (setq http (vlax-create-object "WinHttp.WinHttpRequest.5.1"))
  (vlax-invoke-method http "Open" method url :vlax-false)
  (vlax-invoke-method http "SetRequestHeader" "Accept" "application/json")
  (vlax-invoke-method http "SetRequestHeader" "Authorization" (eskd-auth-header))
  (if body
    (vlax-invoke-method http "SetRequestHeader" "Content-Type" "application/json")
  )
  (if body
    (vlax-invoke-method http "Send" body)
    (vlax-invoke-method http "Send")
  )
  (setq status (vlax-get-property http "Status"))
  (setq response (vlax-get-property http "ResponseText"))
  (vlax-release-object http)
  (list status response)
)

(defun eskd-json-string (key value)
  (strcat "\"" key "\":\"" (eskd-json-escape (if value value "")) "\"")
)

(defun eskd-json-number (key value)
  (strcat "\"" key "\":" (itoa value))
)

(defun eskd-json-object (pairs / result first)
  (setq result "{")
  (setq first T)
  (foreach pair pairs
    (if first
      (setq first nil)
      (setq result (strcat result ","))
    )
    (setq result (strcat result pair))
  )
  (strcat result "}")
)

(defun eskd-json-number-value (json key / pattern start end ch value)
  (setq pattern (strcat "\"" key "\":"))
  (setq start (vl-string-search pattern json))
  (if start
    (progn
      (setq start (+ start (strlen pattern)))
      (while (and (< start (strlen json))
                  (member (substr json (1+ start) 1) '(" " "\t" "\r" "\n")))
        (setq start (1+ start))
      )
      (setq end (1+ start))
      (while (and (<= end (strlen json))
                  (setq ch (substr json end 1))
                  (>= (ascii ch) 48)
                  (<= (ascii ch) 57))
        (setq end (1+ end))
      )
      (setq value (atoi (substr json (1+ start) (- end start 1))))
    )
  )
  value
)

(defun eskd-select-block (prompt / selected entity data)
  (setq selected (entsel prompt))
  (if selected
    (progn
      (setq entity (car selected))
      (setq data (entget entity))
      (if (= (cdr (assoc 0 data)) "INSERT")
        entity
        (progn
          (princ "\nSelected entity is not a block reference.")
          nil
        )
      )
    )
    nil
  )
)

(defun eskd-block-name (entity / object name effective-name)
  (setq name (cdr (assoc 2 (entget entity))))
  (setq object (vlax-ename->vla-object entity))
  (if (vlax-property-available-p object 'EffectiveName)
    (progn
      (setq effective-name (vlax-get-property object 'EffectiveName))
      (if effective-name
        (setq name effective-name)
      )
    )
  )
  (strcase name)
)

(defun eskd-select-named-block (prompt expected-name / entity actual-name)
  (setq entity (eskd-select-block prompt))
  (if entity
    (progn
      (setq actual-name (eskd-block-name entity))
      (if (= actual-name (strcase expected-name))
        entity
        (progn
          (princ
            (strcat
              "\nWrong block name. Expected: "
              expected-name
              ", selected: "
              actual-name
            )
          )
          nil
        )
      )
    )
    nil
  )
)

(defun eskd-block-attrs (entity / result next data tag value)
  (setq result nil)
  (setq next (entnext entity))
  (while next
    (setq data (entget next))
    (cond
      ((= (cdr (assoc 0 data)) "ATTRIB")
        (setq tag (strcase (cdr (assoc 2 data))))
        (setq value (cdr (assoc 1 data)))
        (setq result (cons (cons tag value) result))
      )
      ((= (cdr (assoc 0 data)) "SEQEND")
        (setq next nil)
      )
    )
    (if next
      (setq next (entnext next))
    )
  )
  result
)

(defun eskd-attr (attrs tag)
  (cdr (assoc (strcase tag) attrs))
)

(defun eskd-non-empty (value)
  (and value (/= value ""))
)


(defun eskd-list-at (items index / i result)
  (setq i 0)
  (setq result nil)
  (foreach item items
    (if (= i index)
      (setq result item)
    )
    (setq i (1+ i))
  )
  result
)

(defun eskd-json-object-for-key (json key from / key-pos start end)
  (setq key-pos (vl-string-search (strcat "\"" key "\"") json from))
  (if key-pos
    (progn
      (setq start key-pos)
      (while (and (> start 0) (/= (substr json (1+ start) 1) "{"))
        (setq start (1- start))
      )
      (setq end key-pos)
      (while (and (< end (strlen json)) (/= (substr json (1+ end) 1) "}"))
        (setq end (1+ end))
      )
      (list (substr json (1+ start) (1+ (- end start))) (1+ end))
    )
    nil
  )
)

(defun eskd-json-records-by-key (json key / records pos pair)
  (setq records nil)
  (setq pos 0)
  (while (setq pair (eskd-json-object-for-key json key pos))
    (setq records (append records (list (car pair))))
    (setq pos (cadr pair))
  )
  records
)

(defun eskd-record-value (record key)
  (cdr (assoc key record))
)

(defun eskd-project-record-label (record / code name)
  (setq code (or (eskd-record-value record "PROJECT_CODE") (eskd-record-value record "PROJECT_ID") "-"))
  (setq name (eskd-record-value record "PROJECT_NAME"))
  (if (eskd-non-empty name)
    (strcat code " - " name)
    code
  )
)

(defun eskd-cabinet-record-label (record / code name)
  (setq code (or (eskd-record-value record "CABINET_CODE") (eskd-record-value record "CABINET_ID") "-"))
  (setq name (eskd-record-value record "CABINET_NAME"))
  (if (eskd-non-empty name)
    (strcat code " - " name)
    code
  )
)

(defun eskd-project-options-from-records (records / result)
  (setq result nil)
  (foreach record records
    (setq result (append result (list (eskd-project-record-label record))))
  )
  (if result result '("-"))
)

(defun eskd-cabinet-options-from-records (records / result)
  (setq result nil)
  (foreach record records
    (setq result (append result (list (eskd-cabinet-record-label record))))
  )
  (if result result '("-"))
)

(defun eskd-project-records-from-json (json / result objects project-id project-code project-name id)
  (setq result nil)
  (setq objects (eskd-json-records-by-key json "project_id"))
  (foreach object objects
    (setq id (eskd-json-number-value object "id"))
    (setq project-id (eskd-json-token-value object "project_id"))
    (setq project-code (eskd-json-token-value object "project_code"))
    (setq project-name (eskd-json-token-value object "name"))
    (if (eskd-non-empty project-id)
      (setq result
        (append result
          (list
            (list
              (cons "ID" id)
              (cons "PROJECT_ID" project-id)
              (cons "PROJECT_CODE" project-code)
              (cons "PROJECT_NAME" project-name)
            )
          )
        )
      )
    )
  )
  result
)

(defun eskd-cabinet-records-from-json (json / result objects cabinet-id cabinet-code cabinet-name cabinet-description id)
  (setq result nil)
  (setq objects (eskd-json-records-by-key json "cabinet_id"))
  (foreach object objects
    (setq id (eskd-json-number-value object "id"))
    (setq cabinet-id (eskd-json-token-value object "cabinet_id"))
    (setq cabinet-code (eskd-json-token-value object "cabinet_code"))
    (setq cabinet-name (eskd-json-token-value object "name"))
    (setq cabinet-description (eskd-json-token-value object "description"))
    (if (eskd-non-empty cabinet-id)
      (setq result
        (append result
          (list
            (list
              (cons "ID" id)
              (cons "CABINET_ID" cabinet-id)
              (cons "CABINET_CODE" cabinet-code)
              (cons "CABINET_NAME" cabinet-name)
              (cons "CABINET_DESCRIPTION" cabinet-description)
            )
          )
        )
      )
    )
  )
  result
)

(defun eskd-require-attrs (attrs tags / ok value)
  (setq ok T)
  (foreach tag tags
    (setq value (eskd-attr attrs tag))
    (if (or (not value) (= value ""))
      (progn
        (princ (strcat "\nMissing required attribute: " tag))
        (setq ok nil)
      )
    )
  )
  ok
)

(defun eskd-project-id-query-url (attrs)
  (eskd-api-url
    (strcat
      "/api/projects/?project_id=" (eskd-url-encode (eskd-attr attrs "PROJECT_ID"))
    )
  )
)

(defun eskd-project-code-query-url (attrs)
  (eskd-api-url
    (strcat
      "/api/projects/?project_code=" (eskd-url-encode (eskd-attr attrs "PROJECT_CODE"))
    )
  )
)

(defun eskd-project-query-url (attrs)
  (if (eskd-non-empty (eskd-attr attrs "PROJECT_ID"))
    (eskd-project-id-query-url attrs)
    (eskd-project-code-query-url attrs)
  )
)

(defun eskd-cabinet-query-url (attrs)
  (eskd-api-url
    (strcat
      "/api/cabinets/?project_id=" (eskd-url-encode (eskd-attr attrs "PROJECT_ID"))
      (if (eskd-non-empty (eskd-attr attrs "CABINET_ID"))
        (strcat "&cabinet_id=" (eskd-url-encode (eskd-attr attrs "CABINET_ID")))
        (strcat "&cabinet_code=" (eskd-url-encode (eskd-attr attrs "CABINET_CODE")))
      )
    )
  )
)

(defun eskd-find-project-id (attrs / result status response id)
  (setq result (eskd-http-json "GET" (eskd-project-query-url attrs) nil))
  (setq status (car result))
  (setq response (cadr result))
  (if (= status 200)
    (progn
      (setq id (eskd-json-number-value response "id"))
      id
    )
    (progn
      (princ (strcat "\nProject lookup failed: HTTP " (itoa status) ": " response))
      nil
    )
  )
)

(defun eskd-find-cabinet-id (attrs / result status response id)
  (setq result (eskd-http-json "GET" (eskd-cabinet-query-url attrs) nil))
  (setq status (car result))
  (setq response (cadr result))
  (if (= status 200)
    (progn
      (setq id (eskd-json-number-value response "id"))
      id
    )
    (progn
      (princ (strcat "\nCabinet lookup failed: HTTP " (itoa status) ": " response))
      nil
    )
  )
)

(defun eskd-project-body (attrs)
  (eskd-json-object
    (list
      (eskd-json-string "project_code" (eskd-attr attrs "PROJECT_CODE"))
      (eskd-json-string "name" (eskd-attr attrs "PROJECT_NAME"))
    )
  )
)

(defun eskd-cabinet-body (attrs project-id)
  (eskd-json-object
    (list
      (eskd-json-number "project" project-id)
      (eskd-json-string "cabinet_code" (eskd-attr attrs "CABINET_CODE"))
      (eskd-json-string "name" (eskd-attr attrs "CABINET_NAME"))
      (eskd-json-string "description" (eskd-attr attrs "CABINET_DESCRIPTION"))
    )
  )
)

(defun eskd-print-http-result (action result / status response)
  (setq status (car result))
  (setq response (cadr result))
  (if (and (>= status 200) (< status 300))
    (princ (strcat "\n" action " OK: HTTP " (itoa status)))
    (princ (strcat "\n" action " failed: HTTP " (itoa status) ": " response))
  )
  result
)

(defun eskd-current-project-attrs ()
  (list
    (cons "PROJECT_ID" *eskd-current-project-id*)
    (cons "PROJECT_CODE" *eskd-current-project-code*)
    (cons "PROJECT_NAME" *eskd-current-project-name*)
  )
)

(defun eskd-current-cabinet-attrs ()
  (append
    (eskd-current-project-attrs)
    (list
      (cons "CABINET_ID" *eskd-current-cabinet-id*)
      (cons "CABINET_CODE" *eskd-current-cabinet-code*)
      (cons "CABINET_NAME" *eskd-current-cabinet-name*)
      (cons "CABINET_DESCRIPTION" *eskd-current-cabinet-description*)
    )
  )
)

(defun eskd-context-has-project ()
  (eskd-non-empty *eskd-current-project-id*)
)

(defun eskd-context-has-project-name ()
  (eskd-non-empty *eskd-current-project-name*)
)

(defun eskd-context-has-project-code ()
  (eskd-non-empty *eskd-current-project-code*)
)

(defun eskd-set-current-project-code (project-code)
  (if (/= project-code *eskd-current-project-code*)
    (progn
      (setq *eskd-current-project-id* "")
      (setq *eskd-current-cabinet-id* "")
      (setq *eskd-current-cabinet-code* "")
    )
  )
  (setq *eskd-current-project-code* project-code)
)

(defun eskd-clear-current-project-name ()
  (setq *eskd-current-project-name* "")
)

(defun eskd-context-has-cabinet ()
  (and
    (eskd-context-has-project)
    (eskd-non-empty *eskd-current-cabinet-id*)
  )
)

(defun eskd-context-has-cabinet-name ()
  (eskd-non-empty *eskd-current-cabinet-name*)
)

(defun eskd-context-has-cabinet-code ()
  (eskd-non-empty *eskd-current-cabinet-code*)
)

(defun eskd-require-project-name ()
  (if (eskd-context-has-project-name)
    T
    (progn
      (princ "\nВведите название проекта.")
      nil
    )
  )
)

(defun eskd-require-project-code ()
  (if (eskd-context-has-project-code)
    T
    (progn
      (princ "\nВведите шифр проекта.")
      nil
    )
  )
)

(defun eskd-require-project-context ()
  (if (eskd-context-has-project)
    T
    (progn
      (princ "\nСначала сохраните проект, чтобы сервер выдал PROJECT_ID.")
      nil
    )
  )
)

(defun eskd-require-cabinet-name ()
  (if (eskd-context-has-cabinet-name)
    T
    (progn
      (princ "\nВведите название шкафа.")
      nil
    )
  )
)


(defun eskd-require-cabinet-code ()
  (if (eskd-context-has-cabinet-code)
    T
    (progn
      (princ "\nВведите код шкафа.")
      nil
    )
  )
)

(defun eskd-require-cabinet-context ()
  (if (eskd-context-has-cabinet)
    T
    (progn
      (princ "\nСначала сохраните проект и шкаф, чтобы сервер выдал PROJECT_ID и CABINET_ID.")
      nil
    )
  )
)

(defun eskd-context-print ()
  (princ
    (strcat
      "\nCurrent ESKD context:"
      "\n  PROJECT_ID: " *eskd-current-project-id*
      "\n  PROJECT_CODE: " *eskd-current-project-code*
      "\n  PROJECT_NAME: " *eskd-current-project-name*
      "\n  CABINET_ID: " *eskd-current-cabinet-id*
      "\n  CABINET_CODE: " *eskd-current-cabinet-code*
      "\n  CABINET_NAME: " *eskd-current-cabinet-name*
    )
  )
)

(defun eskd-store-current-project-id (result / status response project-id project-code project-name)
  (setq status (car result))
  (setq response (cadr result))
  (if (and (>= status 200) (< status 300))
    (progn
      (setq project-id (eskd-json-token-value response "project_id"))
      (setq project-code (eskd-json-token-value response "project_code"))
      (setq project-name (eskd-json-token-value response "name"))
      (if (eskd-non-empty project-id)
        (progn
          (setq *eskd-current-project-id* project-id)
          (princ (strcat "\nPROJECT_ID: " project-id))
        )
      )
      (if (eskd-non-empty project-code)
        (setq *eskd-current-project-code* project-code)
      )
      (if (eskd-non-empty project-name)
        (setq *eskd-current-project-name* project-name)
      )
    )
  )
  result
)

(defun eskd-store-current-cabinet-id (result / status response cabinet-id cabinet-code cabinet-name cabinet-description)
  (setq status (car result))
  (setq response (cadr result))
  (if (and (>= status 200) (< status 300))
    (progn
      (setq cabinet-id (eskd-json-token-value response "cabinet_id"))
      (setq cabinet-code (eskd-json-token-value response "cabinet_code"))
      (setq cabinet-name (eskd-json-token-value response "name"))
      (setq cabinet-description (eskd-json-token-value response "description"))
      (if (eskd-non-empty cabinet-id)
        (progn
          (setq *eskd-current-cabinet-id* cabinet-id)
          (princ (strcat "\nCABINET_ID: " cabinet-id))
        )
      )
      (if (eskd-non-empty cabinet-code)
        (setq *eskd-current-cabinet-code* cabinet-code)
      )
      (if (eskd-non-empty cabinet-name)
        (setq *eskd-current-cabinet-name* cabinet-name)
      )
      (if (eskd-non-empty cabinet-description)
        (setq *eskd-current-cabinet-description* cabinet-description)
      )
    )
  )
  result
)

(defun eskd-getstring-default (prompt default / value)
  (setq value (getstring T (strcat "\n" prompt " <" default ">: ")))
  (if (= value "")
    default
    value
  )
)

(defun c:ESKD_CONTEXT_SET ()
  (eskd-set-current-project-code (eskd-getstring-default "PROJECT_CODE" *eskd-current-project-code*))
  (setq *eskd-current-project-name* (eskd-getstring-default "PROJECT_NAME" *eskd-current-project-name*))
  (setq *eskd-current-cabinet-code* (eskd-getstring-default "CABINET_CODE" *eskd-current-cabinet-code*))
  (setq *eskd-current-cabinet-name* (eskd-getstring-default "CABINET_NAME" *eskd-current-cabinet-name*))
  (setq *eskd-current-cabinet-description* (eskd-getstring-default "CABINET_DESCRIPTION" *eskd-current-cabinet-description*))
  (eskd-context-print)
  (princ)
)

(defun c:ESKD_CONTEXT_STATUS ()
  (eskd-context-print)
  (princ)
)


(defun c:ESKD_PROJECTS_LOAD (/ result status response)
  (if (eskd-require-auth)
    (progn
      (setq result (eskd-http-json "GET" (eskd-api-url "/api/projects/") nil))
      (setq status (car result))
      (setq response (cadr result))
      (if (= status 200)
        (progn
          (setq *eskd-project-records* (eskd-project-records-from-json response))
          (setq *eskd-project-options* (eskd-project-options-from-records *eskd-project-records*))
          (setq *eskd-selected-project-index* 0)
          (princ (strcat "
Projects loaded: " (itoa (length *eskd-project-records*))))
        )
        (princ (strcat "
Projects load failed: HTTP " (itoa status) ": " response))
      )
    )
  )
  (princ)
)

(defun c:ESKD_PROJECT_SELECT (/ record)
  (setq record (eskd-list-at *eskd-project-records* *eskd-selected-project-index*))
  (if record
    (progn
      (setq *eskd-current-project-id* (eskd-record-value record "PROJECT_ID"))
      (setq *eskd-current-project-code* (eskd-record-value record "PROJECT_CODE"))
      (setq *eskd-current-project-name* (eskd-record-value record "PROJECT_NAME"))
      (setq *eskd-current-cabinet-id* "")
      (setq *eskd-current-cabinet-code* "")
      (setq *eskd-current-cabinet-name* "")
      (setq *eskd-current-cabinet-description* "")
      (setq *eskd-cabinet-records* nil)
      (setq *eskd-cabinet-options* '("-"))
      (setq *eskd-selected-cabinet-index* 0)
      (princ (strcat "\n" "Проект выбран: " *eskd-current-project-code*))
    )
    (princ "\nСписок проектов пуст. Сначала загрузите проекты.")
  )
  (princ)
)

(defun c:ESKD_CABINETS_LOAD (/ result status response)
  (if (and (eskd-require-auth) (eskd-require-project-context))
    (progn
      (setq result (eskd-http-json "GET" (eskd-api-url (strcat "/api/cabinets/?project_id=" (eskd-url-encode *eskd-current-project-id*))) nil))
      (setq status (car result))
      (setq response (cadr result))
      (if (= status 200)
        (progn
          (setq *eskd-cabinet-records* (eskd-cabinet-records-from-json response))
          (setq *eskd-cabinet-options* (eskd-cabinet-options-from-records *eskd-cabinet-records*))
          (setq *eskd-selected-cabinet-index* 0)
          (princ (strcat "
Cabinets loaded: " (itoa (length *eskd-cabinet-records*))))
        )
        (princ (strcat "
Cabinets load failed: HTTP " (itoa status) ": " response))
      )
    )
  )
  (princ)
)

(defun c:ESKD_CABINET_SELECT (/ record)
  (setq record (eskd-list-at *eskd-cabinet-records* *eskd-selected-cabinet-index*))
  (if record
    (progn
      (setq *eskd-current-cabinet-id* (eskd-record-value record "CABINET_ID"))
      (setq *eskd-current-cabinet-code* (eskd-record-value record "CABINET_CODE"))
      (setq *eskd-current-cabinet-name* (eskd-record-value record "CABINET_NAME"))
      (setq *eskd-current-cabinet-description* (eskd-record-value record "CABINET_DESCRIPTION"))
      (princ (strcat "\n" "Шкаф выбран: " *eskd-current-cabinet-code*))
    )
    (princ "\nСписок шкафов пуст. Сначала загрузите шкафы.")
  )
  (princ)
)

(defun c:ESKD_PROJECT_GET (/ attrs result)
  (if (eskd-require-auth)
    (progn
      (if (or (eskd-context-has-project) (eskd-require-project-code))
        (progn
          (setq attrs (eskd-current-project-attrs))
          (setq result (eskd-print-http-result "Project GET" (eskd-http-json "GET" (eskd-project-query-url attrs) nil)))
          (eskd-store-current-project-id result)
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_PROJECT_FIND (/ attrs result id)
  (if (eskd-require-auth)
    (progn
      (if (eskd-require-project-code)
        (progn
          (setq attrs (eskd-current-project-attrs))
          (setq result (eskd-print-http-result "Project FIND" (eskd-http-json "GET" (eskd-project-code-query-url attrs) nil)))
          (setq id (eskd-json-number-value (cadr result) "id"))
          (if id
            (progn
              (eskd-store-current-project-id result)
              (princ "\nПроект найден и выбран.")
            )
            (princ "\nПроект с таким шифром не найден.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_PROJECT_CREATE (/ attrs result)
  (if (eskd-require-auth)
    (progn
      (if (and (eskd-require-project-code) (eskd-require-project-name))
        (progn
          (setq attrs (eskd-current-project-attrs))
          (setq result
            (eskd-print-http-result
              "Project CREATE"
              (eskd-http-json "POST" (eskd-api-url "/api/projects/") (eskd-project-body attrs))
            )
          )
          (eskd-store-current-project-id result)
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_PROJECT_UPDATE (/ attrs id)
  (if (eskd-require-auth)
    (progn
      (if (eskd-require-project-context)
        (progn
          (setq attrs (eskd-current-project-attrs))
          (setq id (eskd-find-project-id attrs))
          (if id
            (eskd-print-http-result
              "Project UPDATE"
              (eskd-http-json
                "PATCH"
                (eskd-api-url (strcat "/api/projects/" (itoa id) "/"))
                (eskd-project-body attrs)
              )
            )
            (princ "\nProject was not found.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_PROJECT_DELETE (/ attrs id)
  (if (eskd-require-auth)
    (progn
      (if (eskd-require-project-context)
        (progn
          (setq attrs (eskd-current-project-attrs))
          (setq id (eskd-find-project-id attrs))
          (if id
            (eskd-print-http-result
              "Project DELETE"
              (eskd-http-json "DELETE" (eskd-api-url (strcat "/api/projects/" (itoa id) "/")) nil)
            )
            (princ "\nProject was not found.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_PROJECT_SYNC (/ attrs id)
  (if (eskd-require-auth)
    (progn
      (if (eskd-require-project-code)
        (progn
          (setq attrs (eskd-current-project-attrs))
          (setq id nil)
          (if (eskd-context-has-project)
            (setq id (eskd-find-project-id attrs))
            (setq id (eskd-find-project-id attrs))
          )
          (if id
            (if (eskd-context-has-project)
              (eskd-store-current-project-id
                (eskd-print-http-result
                  "Project SYNC update"
                  (eskd-http-json
                    "PATCH"
                    (eskd-api-url (strcat "/api/projects/" (itoa id) "/"))
                    (eskd-project-body attrs)
                  )
                )
              )
              (progn
                (eskd-store-current-project-id
                  (eskd-print-http-result "Project SYNC found" (eskd-http-json "GET" (eskd-project-code-query-url attrs) nil))
                )
                  (princ "\nПроект уже есть на сервере, выбран существующий.")
              )
            )
            (if (eskd-require-project-name)
              (eskd-store-current-project-id
                (eskd-print-http-result
                  "Project SYNC create"
                  (eskd-http-json "POST" (eskd-api-url "/api/projects/") (eskd-project-body attrs))
                )
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_CABINET_GET (/ attrs)
  (if (eskd-require-auth)
    (progn
      (if (eskd-require-cabinet-context)
        (progn
          (setq attrs (eskd-current-cabinet-attrs))
        (eskd-print-http-result "Cabinet GET" (eskd-http-json "GET" (eskd-cabinet-query-url attrs) nil))
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_CABINET_CREATE (/ attrs project-id)
  (if (eskd-require-auth)
    (progn
      (if (and (eskd-require-project-context) (eskd-require-cabinet-code))
        (progn
          (setq attrs (eskd-current-cabinet-attrs))
          (setq project-id (eskd-find-project-id attrs))
          (if project-id
            (eskd-store-current-cabinet-id
              (eskd-print-http-result
                "Cabinet CREATE"
                (eskd-http-json "POST" (eskd-api-url "/api/cabinets/") (eskd-cabinet-body attrs project-id))
              )
            )
            (princ "\nПроект не найден. Сначала создайте или выберите проект.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_CABINET_UPDATE (/ attrs id project-id)
  (if (eskd-require-auth)
    (progn
      (if (eskd-require-cabinet-context)
        (progn
          (setq attrs (eskd-current-cabinet-attrs))
          (setq id (eskd-find-cabinet-id attrs))
          (setq project-id (eskd-find-project-id attrs))
          (cond
            ((not id) (princ "\nШкаф не найден."))
            ((not project-id) (princ "\nПроект не найден."))
            (T
              (eskd-print-http-result
                "Cabinet UPDATE"
                (eskd-http-json
                  "PATCH"
                  (eskd-api-url (strcat "/api/cabinets/" (itoa id) "/"))
                  (eskd-cabinet-body attrs project-id)
                )
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_CABINET_DELETE (/ attrs id)
  (if (eskd-require-auth)
    (progn
      (if (eskd-require-cabinet-context)
        (progn
          (setq attrs (eskd-current-cabinet-attrs))
          (setq id (eskd-find-cabinet-id attrs))
          (if id
            (eskd-print-http-result
              "Cabinet DELETE"
              (eskd-http-json "DELETE" (eskd-api-url (strcat "/api/cabinets/" (itoa id) "/")) nil)
            )
            (princ "\nШкаф не найден.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_CABINET_SYNC (/ attrs id project-id)
  (if (eskd-require-auth)
    (progn
      (if (and (eskd-require-project-context) (eskd-require-cabinet-code))
        (progn
          (setq attrs (eskd-current-cabinet-attrs))
          (setq project-id (eskd-find-project-id attrs))
          (if project-id
            (progn
              (setq id (eskd-find-cabinet-id attrs))
              (if id
                (eskd-store-current-cabinet-id
                  (eskd-print-http-result
                    "Cabinet SYNC update"
                    (eskd-http-json
                      "PATCH"
                      (eskd-api-url (strcat "/api/cabinets/" (itoa id) "/"))
                      (eskd-cabinet-body attrs project-id)
                    )
                  )
                )
                (eskd-store-current-cabinet-id
                  (eskd-print-http-result
                    "Cabinet SYNC create"
                    (eskd-http-json "POST" (eskd-api-url "/api/cabinets/") (eskd-cabinet-body attrs project-id))
                  )
                )
              )
            )
            (princ "\nПроект не найден. Сначала создайте или выберите проект.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_DRAWING_GET () (c:ESKD_CABINET_GET))
(defun c:ESKD_DRAWING_CREATE () (c:ESKD_CABINET_CREATE))
(defun c:ESKD_DRAWING_UPDATE () (c:ESKD_CABINET_UPDATE))
(defun c:ESKD_DRAWING_DELETE () (c:ESKD_CABINET_DELETE))
(defun c:ESKD_DRAWING_SYNC () (c:ESKD_CABINET_SYNC))
(defun eskd-find-drawing-id (attrs) (eskd-find-cabinet-id attrs))

(princ "\nESKD project/cabinet CRUD loaded.")
(princ "\nCommands: ESKD_CONTEXT_SET, ESKD_PROJECT_SYNC, ESKD_CABINET_SYNC, plus GET/CREATE/UPDATE/DELETE variants.")
(princ)
