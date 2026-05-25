;;; ESKD WireEndpoint CRUD for AutoCAD 2016-2018.
;;; Load after:
;;;   autocad/eskd_auth.lsp
;;;   autocad/eskd_project_drawing_crud.lsp
;;;
;;; WireEndpoint block attributes:
;;;   Block name: Block_Test_Marking
;;;   ENDPOINT_ID, PROJECT_ID, ORDER_NUMBER, CABINET_ID, REF_ID,
;;;   MARK_1, MARK_2, WIRE_TYPE, WIRE_COLOR, SYNC_STATUS
;;;   ENDPOINT_ID may be empty before the first successful sync.
;;;
;;; Commands:
;;;   ESKD_WIRE_GET, ESKD_WIRE_CREATE, ESKD_WIRE_UPDATE, ESKD_WIRE_DELETE, ESKD_WIRE_SYNC
;;;   ESKD_WIRE_LINK_REF, ESKD_WIRE_CLEAR_REF, ESKD_WIRE_INSERT

(vl-load-com)

(defun eskd-wire-required-tags ()
  '("PROJECT_ID" "ORDER_NUMBER" "CABINET_ID")
)

(defun eskd-wire-crud-required-tags ()
  '("PROJECT_ID" "ORDER_NUMBER" "CABINET_ID")
)

(defun eskd-wire-existing-required-tags ()
  '("ENDPOINT_ID" "PROJECT_ID" "ORDER_NUMBER" "CABINET_ID")
)

(defun eskd-wire-selected-entity-and-attrs (prompt / entity attrs)
  (setq entity (eskd-select-named-block prompt *eskd-marking-block-name*))
  (if entity
    (progn
      (setq attrs (eskd-block-attrs entity))
      (if (eskd-require-attrs attrs (eskd-wire-required-tags))
        (list entity attrs)
        nil
      )
    )
    nil
  )
)

(defun eskd-wire-query-url (attrs)
  (eskd-api-url
    (strcat
      "/api/wire-endpoints/?project_id=" (eskd-url-encode (eskd-attr attrs "PROJECT_ID"))
      "&order_number=" (eskd-url-encode (eskd-attr attrs "ORDER_NUMBER"))
      "&cabinet_id=" (eskd-url-encode (eskd-attr attrs "CABINET_ID"))
      "&endpoint_id=" (eskd-url-encode (eskd-attr attrs "ENDPOINT_ID"))
    )
  )
)

(defun eskd-find-wire-endpoint-id (attrs / result status response endpoint-id)
  (setq result (eskd-http-json "GET" (eskd-wire-query-url attrs) nil))
  (setq status (car result))
  (setq response (cadr result))
  (if (= status 200)
    (progn
      (setq endpoint-id (eskd-json-token-value response "endpoint_id"))
      endpoint-id
    )
    (progn
      (princ (strcat "\nWireEndpoint lookup failed: HTTP " (itoa status) ": " response))
      nil
    )
  )
)

(defun eskd-store-created-endpoint-id (entity result / status response endpoint-id)
  (setq status (car result))
  (setq response (cadr result))
  (if (and (>= status 200) (< status 300))
    (progn
      (setq endpoint-id (eskd-json-token-value response "endpoint_id"))
      (if (eskd-non-empty endpoint-id)
        (progn
          (eskd-set-block-attr entity "ENDPOINT_ID" endpoint-id)
          (eskd-set-block-attr entity "SYNC_STATUS" "SYNCED")
          (princ (strcat "\nENDPOINT_ID stored in block: " endpoint-id))
        )
      )
    )
  )
  result
)

(defun eskd-wire-body (attrs cabinet-id)
  (eskd-json-object
    (list
      (eskd-json-number "cabinet" cabinet-id)
      (eskd-json-string "ref_id" (eskd-attr attrs "REF_ID"))
      (eskd-json-string "mark_1" (eskd-attr attrs "MARK_1"))
      (eskd-json-string "mark_2" (eskd-attr attrs "MARK_2"))
      (eskd-json-string "wire_type" (eskd-attr attrs "WIRE_TYPE"))
      (eskd-json-string "wire_color" (eskd-attr attrs "WIRE_COLOR"))
      (eskd-json-string
        "sync_status"
        (if (eskd-non-empty (eskd-attr attrs "SYNC_STATUS"))
          (eskd-attr attrs "SYNC_STATUS")
          "NEW"
        )
      )
    )
  )
)

(defun eskd-set-block-attr (entity tag value / next data)
  (setq tag (strcase tag))
  (setq next (entnext entity))
  (while next
    (setq data (entget next))
    (cond
      ((= (cdr (assoc 0 data)) "ATTRIB")
        (if (= (strcase (cdr (assoc 2 data))) tag)
          (progn
            (entmod (subst (cons 1 value) (assoc 1 data) data))
            (entupd entity)
            (setq next nil)
          )
        )
      )
      ((= (cdr (assoc 0 data)) "SEQEND")
        (setq next nil)
      )
    )
    (if next
      (setq next (entnext next))
    )
  )
)

(defun eskd-set-block-attrs (entity pairs)
  (foreach pair pairs
    (eskd-set-block-attr entity (car pair) (cdr pair))
  )
)

(defun eskd-non-empty (value)
  (and value (/= value ""))
)

(defun eskd-generate-ref-id (entity-a entity-b / handle-a handle-b)
  (eskd-new-uuid)
)

(defun eskd-new-uuid (/ typelib guid)
  (setq guid nil)
  (setq typelib (vl-catch-all-apply 'vlax-create-object (list "Scriptlet.TypeLib")))
  (if (not (vl-catch-all-error-p typelib))
    (progn
      (setq guid (vlax-get-property typelib 'Guid))
      (vlax-release-object typelib)
      (setq guid (vl-string-subst "" "{" guid))
      (setq guid (vl-string-subst "" "}" guid))
    )
  )
  (if guid
    (strcase guid T)
    (strcat
      (cdr (assoc 5 (entget (car (entsel "\nSelect any entity for UUID fallback seed: ")))))
      "-"
      (rtos (getvar "CDATE") 2 8)
    )
  )
)

(defun eskd-getstring-default (prompt default / value)
  (setq value (getstring T (strcat "\n" prompt " <" default ">: ")))
  (if (= value "")
    default
    value
  )
)

(defun eskd-insert-block-reference (block-name insert-point / before after old-attreq)
  (setq old-attreq (getvar "ATTREQ"))
  (setq before (entlast))
  (setvar "ATTREQ" 0)
  (command "_.-INSERT" block-name insert-point 1.0 1.0 0.0)
  (setvar "ATTREQ" old-attreq)
  (setq after (entlast))
  (if (/= before after)
    after
    nil
  )
)

(defun eskd-wire-selected-attrs (/ pair)
  (setq pair (eskd-wire-selected-entity-and-attrs "\nSelect WireEndpoint block: "))
  (if pair
    (progn
      (if (eskd-require-attrs (cadr pair) (eskd-wire-crud-required-tags))
        (cadr pair)
        nil
      )
    )
    nil
  )
)

(defun eskd-wire-selected-existing-attrs (/ pair)
  (setq pair (eskd-wire-selected-entity-and-attrs "\nSelect WireEndpoint block: "))
  (if pair
    (progn
      (if (eskd-require-attrs (cadr pair) (eskd-wire-existing-required-tags))
        (cadr pair)
        nil
      )
    )
    nil
  )
)

(defun c:ESKD_WIRE_LINK_REF (/ pair-a pair-b entity-a entity-b attrs-a attrs-b ref-id)
  (setq pair-a (eskd-wire-selected-entity-and-attrs "\nSelect first WireEndpoint block: "))
  (if pair-a
    (progn
      (setq pair-b (eskd-wire-selected-entity-and-attrs "\nClick linked WireEndpoint block: "))
      (if pair-b
        (progn
          (setq entity-a (car pair-a))
          (setq attrs-a (cadr pair-a))
          (setq entity-b (car pair-b))
          (setq attrs-b (cadr pair-b))
          (setq ref-id
            (cond
              ((eskd-non-empty (eskd-attr attrs-a "REF_ID")) (eskd-attr attrs-a "REF_ID"))
              ((eskd-non-empty (eskd-attr attrs-b "REF_ID")) (eskd-attr attrs-b "REF_ID"))
              (T (eskd-generate-ref-id entity-a entity-b))
            )
          )
          (eskd-set-block-attr entity-a "REF_ID" ref-id)
          (eskd-set-block-attr entity-b "REF_ID" ref-id)
          (eskd-set-block-attr entity-a "SYNC_STATUS" "DIRTY")
          (eskd-set-block-attr entity-b "SYNC_STATUS" "DIRTY")
          (princ (strcat "\nREF_ID assigned to both blocks: " ref-id))
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_WIRE_CLEAR_REF (/ pair entity)
  (setq pair (eskd-wire-selected-entity-and-attrs "\nSelect WireEndpoint block to clear REF_ID: "))
  (if pair
    (progn
      (setq entity (car pair))
      (eskd-set-block-attr entity "REF_ID" "")
      (eskd-set-block-attr entity "SYNC_STATUS" "DIRTY")
      (princ "\nREF_ID cleared. SYNC_STATUS set to DIRTY.")
    )
  )
  (princ)
)

(defun c:ESKD_WIRE_INSERT (/ project-id order-number cabinet-id mark-1 mark-2 wire-type wire-color point entity)
  (setq project-id (eskd-getstring-default "PROJECT_ID" (if *eskd-last-project-id* *eskd-last-project-id* "-")))
  (setq order-number (eskd-getstring-default "ORDER_NUMBER" (if *eskd-last-order-number* *eskd-last-order-number* "-")))
  (setq cabinet-id (eskd-getstring-default "CABINET_ID" (if *eskd-last-cabinet-id* *eskd-last-cabinet-id* "-")))
  (setq mark-1 (eskd-getstring-default "MARK_1" "-"))
  (setq mark-2 (eskd-getstring-default "MARK_2" "-"))
  (setq wire-type (eskd-getstring-default "WIRE_TYPE" "-"))
  (setq wire-color (eskd-getstring-default "WIRE_COLOR" "-"))
  (setq point (getpoint "\nInsertion point for marking block: "))
  (if point
    (progn
      (setq entity (eskd-insert-block-reference "Block_Test_Marking" point))
      (if entity
        (progn
          (setq *eskd-last-project-id* project-id)
          (setq *eskd-last-order-number* order-number)
          (setq *eskd-last-cabinet-id* cabinet-id)
          (eskd-set-block-attrs
            entity
            (list
              (cons "ENDPOINT_ID" "")
              (cons "PROJECT_ID" project-id)
              (cons "ORDER_NUMBER" order-number)
              (cons "CABINET_ID" cabinet-id)
              (cons "REF_ID" "")
              (cons "MARK_1" mark-1)
              (cons "MARK_2" mark-2)
              (cons "WIRE_TYPE" wire-type)
              (cons "WIRE_COLOR" wire-color)
              (cons "SYNC_STATUS" "NEW")
            )
          )
          (princ "\nMarking block inserted.")
        )
        (princ "\nBlock_Test_Marking was not inserted. Make sure the block definition exists in this drawing.")
      )
    )
  )
  (princ)
)

(defun c:ESKD_WIRE_GET (/ attrs)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-wire-selected-existing-attrs))
      (if attrs
        (eskd-print-http-result "WireEndpoint GET" (eskd-http-json "GET" (eskd-wire-query-url attrs) nil))
      )
    )
  )
  (princ)
)

(defun c:ESKD_WIRE_CREATE (/ pair entity attrs cabinet-id result)
  (if (eskd-require-auth)
    (progn
      (setq pair (eskd-wire-selected-entity-and-attrs "\nSelect WireEndpoint block: "))
      (if pair
        (progn
          (setq entity (car pair))
          (setq attrs (cadr pair))
          (if (eskd-require-attrs attrs (eskd-wire-crud-required-tags))
            (progn
              (setq cabinet-id (eskd-find-cabinet-id attrs))
              (if cabinet-id
                (progn
                  (setq result (eskd-http-json "POST" (eskd-api-url "/api/wire-endpoints/") (eskd-wire-body attrs cabinet-id)))
                  (eskd-print-http-result "WireEndpoint CREATE" result)
                  (eskd-store-created-endpoint-id entity result)
                )
                (princ "\nParent cabinet was not found. Create/sync cabinet first.")
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_WIRE_UPDATE (/ attrs endpoint-id cabinet-id)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-wire-selected-existing-attrs))
      (if attrs
        (progn
          (setq endpoint-id (eskd-find-wire-endpoint-id attrs))
          (setq cabinet-id (eskd-find-cabinet-id attrs))
          (cond
            ((not endpoint-id) (princ "\nWireEndpoint was not found."))
            ((not cabinet-id) (princ "\nParent cabinet was not found."))
            (T
              (eskd-print-http-result
                "WireEndpoint UPDATE"
                (eskd-http-json
                  "PATCH"
                  (eskd-api-url (strcat "/api/wire-endpoints/" endpoint-id "/"))
                  (eskd-wire-body attrs cabinet-id)
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

(defun c:ESKD_WIRE_DELETE (/ attrs endpoint-id)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-wire-selected-existing-attrs))
      (if attrs
        (progn
          (setq endpoint-id (eskd-find-wire-endpoint-id attrs))
          (if endpoint-id
            (eskd-print-http-result
              "WireEndpoint DELETE"
              (eskd-http-json "DELETE" (eskd-api-url (strcat "/api/wire-endpoints/" endpoint-id "/")) nil)
            )
            (princ "\nWireEndpoint was not found.")
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_WIRE_SYNC (/ pair entity attrs endpoint-id cabinet-id result)
  (if (eskd-require-auth)
    (progn
      (setq pair (eskd-wire-selected-entity-and-attrs "\nSelect WireEndpoint block: "))
      (if pair
        (progn
          (setq entity (car pair))
          (setq attrs (cadr pair))
          (if (eskd-require-attrs attrs (eskd-wire-crud-required-tags))
            (progn
              (setq cabinet-id (eskd-find-cabinet-id attrs))
              (if cabinet-id
                (progn
                  (setq endpoint-id nil)
                  (if (eskd-non-empty (eskd-attr attrs "ENDPOINT_ID"))
                    (setq endpoint-id (eskd-find-wire-endpoint-id attrs))
                  )
                  (if endpoint-id
                    (eskd-print-http-result
                      "WireEndpoint SYNC update"
                      (eskd-http-json
                        "PATCH"
                        (eskd-api-url (strcat "/api/wire-endpoints/" endpoint-id "/"))
                        (eskd-wire-body attrs cabinet-id)
                      )
                    )
                    (progn
                      (setq result (eskd-http-json "POST" (eskd-api-url "/api/wire-endpoints/") (eskd-wire-body attrs cabinet-id)))
                      (eskd-print-http-result "WireEndpoint SYNC create" result)
                      (eskd-store-created-endpoint-id entity result)
                    )
                  )
                )
                (princ "\nParent cabinet was not found. Create/sync cabinet first.")
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(princ "\nESKD WireEndpoint CRUD loaded.")
(princ "\nCommands: ESKD_WIRE_INSERT, ESKD_WIRE_LINK_REF, ESKD_WIRE_CLEAR_REF, ESKD_WIRE_SYNC, plus GET/CREATE/UPDATE/DELETE variants.")
(princ)
