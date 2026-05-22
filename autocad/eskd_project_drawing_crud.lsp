;;; ESKD Project/Drawing CRUD for AutoCAD 2016-2018.
;;; Load after autocad/eskd_auth.lsp.
;;;
;;; Project block attributes:
;;;   Block name: Block_Test_Project
;;;   PROJECT_ID, ORDER_NUMBER, PROJECT_NAME, DESCRIPTION
;;;
;;; Drawing block attributes:
;;;   Block name: Block_Test_Drawing
;;;   PROJECT_ID, ORDER_NUMBER, DWG_ID, DWG_NAME, FILE_NAME
;;;
;;; Commands:
;;;   ESKD_PROJECT_GET, ESKD_PROJECT_CREATE, ESKD_PROJECT_UPDATE, ESKD_PROJECT_DELETE, ESKD_PROJECT_SYNC
;;;   ESKD_DRAWING_GET, ESKD_DRAWING_CREATE, ESKD_DRAWING_UPDATE, ESKD_DRAWING_DELETE, ESKD_DRAWING_SYNC

(vl-load-com)

(setq *eskd-project-block-name* "BLOCK_TEST_PROJECT")
(setq *eskd-drawing-block-name* "BLOCK_TEST_DRAWING")
(setq *eskd-marking-block-name* "BLOCK_TEST_MARKING")

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

(defun eskd-project-query-url (attrs)
  (eskd-api-url
    (strcat
      "/api/projects/?project_id=" (eskd-url-encode (eskd-attr attrs "PROJECT_ID"))
      "&order_number=" (eskd-url-encode (eskd-attr attrs "ORDER_NUMBER"))
    )
  )
)

(defun eskd-drawing-query-url (attrs)
  (eskd-api-url
    (strcat
      "/api/drawings/?project_id=" (eskd-url-encode (eskd-attr attrs "PROJECT_ID"))
      "&order_number=" (eskd-url-encode (eskd-attr attrs "ORDER_NUMBER"))
      "&dwg_id=" (eskd-url-encode (eskd-attr attrs "DWG_ID"))
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

(defun eskd-find-drawing-id (attrs / result status response id)
  (setq result (eskd-http-json "GET" (eskd-drawing-query-url attrs) nil))
  (setq status (car result))
  (setq response (cadr result))
  (if (= status 200)
    (progn
      (setq id (eskd-json-number-value response "id"))
      id
    )
    (progn
      (princ (strcat "\nDrawing lookup failed: HTTP " (itoa status) ": " response))
      nil
    )
  )
)

(defun eskd-project-body (attrs)
  (eskd-json-object
    (list
      (eskd-json-string "project_id" (eskd-attr attrs "PROJECT_ID"))
      (eskd-json-string "order_number" (eskd-attr attrs "ORDER_NUMBER"))
      (eskd-json-string "name" (eskd-attr attrs "PROJECT_NAME"))
      (eskd-json-string "description" (eskd-attr attrs "DESCRIPTION"))
    )
  )
)

(defun eskd-drawing-body (attrs project-id)
  (eskd-json-object
    (list
      (eskd-json-number "project" project-id)
      (eskd-json-string "dwg_id" (eskd-attr attrs "DWG_ID"))
      (eskd-json-string "name" (eskd-attr attrs "DWG_NAME"))
      (eskd-json-string "file_name" (eskd-attr attrs "FILE_NAME"))
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

(defun eskd-project-selected-attrs (/ entity attrs)
  (setq entity (eskd-select-named-block "\nSelect project block: " *eskd-project-block-name*))
  (if entity
    (progn
      (setq attrs (eskd-block-attrs entity))
      (if (eskd-require-attrs attrs '("PROJECT_ID" "ORDER_NUMBER" "PROJECT_NAME"))
        attrs
        nil
      )
    )
    nil
  )
)

(defun eskd-drawing-selected-attrs (/ entity attrs)
  (setq entity (eskd-select-named-block "\nSelect drawing block: " *eskd-drawing-block-name*))
  (if entity
    (progn
      (setq attrs (eskd-block-attrs entity))
      (if (eskd-require-attrs attrs '("PROJECT_ID" "ORDER_NUMBER" "DWG_ID"))
        attrs
        nil
      )
    )
    nil
  )
)

(defun c:ESKD_PROJECT_GET (/ attrs result)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-project-selected-attrs))
      (if attrs
        (eskd-print-http-result "Project GET" (eskd-http-json "GET" (eskd-project-query-url attrs) nil))
      )
    )
  )
  (princ)
)

(defun c:ESKD_PROJECT_CREATE (/ attrs result)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-project-selected-attrs))
      (if attrs
        (eskd-print-http-result
          "Project CREATE"
          (eskd-http-json "POST" (eskd-api-url "/api/projects/") (eskd-project-body attrs))
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_PROJECT_UPDATE (/ attrs id)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-project-selected-attrs))
      (if attrs
        (progn
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
      (setq attrs (eskd-project-selected-attrs))
      (if attrs
        (progn
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
      (setq attrs (eskd-project-selected-attrs))
      (if attrs
        (progn
          (setq id (eskd-find-project-id attrs))
          (if id
            (eskd-print-http-result
              "Project SYNC update"
              (eskd-http-json
                "PATCH"
                (eskd-api-url (strcat "/api/projects/" (itoa id) "/"))
                (eskd-project-body attrs)
              )
            )
            (eskd-print-http-result
              "Project SYNC create"
              (eskd-http-json "POST" (eskd-api-url "/api/projects/") (eskd-project-body attrs))
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_DRAWING_GET (/ attrs)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-drawing-selected-attrs))
      (if attrs
        (eskd-print-http-result "Drawing GET" (eskd-http-json "GET" (eskd-drawing-query-url attrs) nil))
      )
    )
  )
  (princ)
)

(defun c:ESKD_DRAWING_CREATE (/ attrs project-id)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-drawing-selected-attrs))
      (if attrs
        (progn
          (setq project-id (eskd-find-project-id attrs))
          (if project-id
            (eskd-print-http-result
              "Drawing CREATE"
              (eskd-http-json "POST" (eskd-api-url "/api/drawings/") (eskd-drawing-body attrs project-id))
            )
            (princ "\nParent project was not found. Create/sync project first.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_DRAWING_UPDATE (/ attrs id project-id)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-drawing-selected-attrs))
      (if attrs
        (progn
          (setq id (eskd-find-drawing-id attrs))
          (setq project-id (eskd-find-project-id attrs))
          (cond
            ((not id) (princ "\nDrawing was not found."))
            ((not project-id) (princ "\nParent project was not found."))
            (T
              (eskd-print-http-result
                "Drawing UPDATE"
                (eskd-http-json
                  "PATCH"
                  (eskd-api-url (strcat "/api/drawings/" (itoa id) "/"))
                  (eskd-drawing-body attrs project-id)
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

(defun c:ESKD_DRAWING_DELETE (/ attrs id)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-drawing-selected-attrs))
      (if attrs
        (progn
          (setq id (eskd-find-drawing-id attrs))
          (if id
            (eskd-print-http-result
              "Drawing DELETE"
              (eskd-http-json "DELETE" (eskd-api-url (strcat "/api/drawings/" (itoa id) "/")) nil)
            )
            (princ "\nDrawing was not found.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_DRAWING_SYNC (/ attrs id project-id)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-drawing-selected-attrs))
      (if attrs
        (progn
          (setq project-id (eskd-find-project-id attrs))
          (if project-id
            (progn
              (setq id (eskd-find-drawing-id attrs))
              (if id
                (eskd-print-http-result
                  "Drawing SYNC update"
                  (eskd-http-json
                    "PATCH"
                    (eskd-api-url (strcat "/api/drawings/" (itoa id) "/"))
                    (eskd-drawing-body attrs project-id)
                  )
                )
                (eskd-print-http-result
                  "Drawing SYNC create"
                  (eskd-http-json "POST" (eskd-api-url "/api/drawings/") (eskd-drawing-body attrs project-id))
                )
              )
            )
            (princ "\nParent project was not found. Create/sync project first.")
          )
        )
      )
    )
  )
  (princ)
)

(princ "\nESKD project/drawing CRUD loaded.")
(princ "\nCommands: ESKD_PROJECT_SYNC, ESKD_DRAWING_SYNC, plus GET/CREATE/UPDATE/DELETE variants.")
(princ)
