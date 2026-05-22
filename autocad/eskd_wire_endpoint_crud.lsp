;;; ESKD WireEndpoint CRUD for AutoCAD 2016-2018.
;;; Load after:
;;;   autocad/eskd_auth.lsp
;;;   autocad/eskd_project_drawing_crud.lsp
;;;
;;; WireEndpoint block attributes:
;;;   Block name: Block_Test_Marking
;;;   ENDPOINT_ID, PROJECT_ID, ORDER_NUMBER, DWG_ID, REF_ID,
;;;   MARK, POSITION, WIRE_TYPE, WIRE_COLOR, SYNC_STATUS
;;;   ENDPOINT_ID may be empty before the first successful sync.
;;;
;;; Commands:
;;;   ESKD_WIRE_GET, ESKD_WIRE_CREATE, ESKD_WIRE_UPDATE, ESKD_WIRE_DELETE, ESKD_WIRE_SYNC
;;;   ESKD_WIRE_LINK_REF, ESKD_WIRE_CLEAR_REF

(vl-load-com)

(defun eskd-wire-required-tags ()
  '("PROJECT_ID" "ORDER_NUMBER" "DWG_ID")
)

(defun eskd-wire-crud-required-tags ()
  '("PROJECT_ID" "ORDER_NUMBER" "DWG_ID")
)

(defun eskd-wire-existing-required-tags ()
  '("ENDPOINT_ID" "PROJECT_ID" "ORDER_NUMBER" "DWG_ID" "REF_ID" "MARK" "POSITION")
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
      "&dwg_id=" (eskd-url-encode (eskd-attr attrs "DWG_ID"))
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

(defun eskd-wire-body (attrs drawing-id)
  (eskd-json-object
    (list
      (eskd-json-number "drawing" drawing-id)
      (eskd-json-string "ref_id" (eskd-attr attrs "REF_ID"))
      (eskd-json-string "mark" (eskd-attr attrs "MARK"))
      (eskd-json-string "position" (eskd-attr attrs "POSITION"))
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

(defun eskd-non-empty (value)
  (and value (/= value ""))
)

(defun eskd-generate-ref-id (entity-a entity-b / handle-a handle-b)
  (setq handle-a (cdr (assoc 5 (entget entity-a))))
  (setq handle-b (cdr (assoc 5 (entget entity-b))))
  (strcat "W-" handle-a "-" handle-b)
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

(defun c:ESKD_WIRE_CREATE (/ pair entity attrs drawing-id result)
  (if (eskd-require-auth)
    (progn
      (setq pair (eskd-wire-selected-entity-and-attrs "\nSelect WireEndpoint block: "))
      (if pair
        (progn
          (setq entity (car pair))
          (setq attrs (cadr pair))
          (if (eskd-require-attrs attrs (eskd-wire-crud-required-tags))
            (progn
              (setq drawing-id (eskd-find-drawing-id attrs))
              (if drawing-id
                (progn
                  (setq result (eskd-http-json "POST" (eskd-api-url "/api/wire-endpoints/") (eskd-wire-body attrs drawing-id)))
                  (eskd-print-http-result "WireEndpoint CREATE" result)
                  (eskd-store-created-endpoint-id entity result)
                )
                (princ "\nParent drawing was not found. Create/sync drawing first.")
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(defun c:ESKD_WIRE_UPDATE (/ attrs endpoint-id drawing-id)
  (if (eskd-require-auth)
    (progn
      (setq attrs (eskd-wire-selected-existing-attrs))
      (if attrs
        (progn
          (setq endpoint-id (eskd-find-wire-endpoint-id attrs))
          (setq drawing-id (eskd-find-drawing-id attrs))
          (cond
            ((not endpoint-id) (princ "\nWireEndpoint was not found."))
            ((not drawing-id) (princ "\nParent drawing was not found."))
            (T
              (eskd-print-http-result
                "WireEndpoint UPDATE"
                (eskd-http-json
                  "PATCH"
                  (eskd-api-url (strcat "/api/wire-endpoints/" endpoint-id "/"))
                  (eskd-wire-body attrs drawing-id)
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

(defun c:ESKD_WIRE_SYNC (/ pair entity attrs endpoint-id drawing-id result)
  (if (eskd-require-auth)
    (progn
      (setq pair (eskd-wire-selected-entity-and-attrs "\nSelect WireEndpoint block: "))
      (if pair
        (progn
          (setq entity (car pair))
          (setq attrs (cadr pair))
          (if (eskd-require-attrs attrs (eskd-wire-crud-required-tags))
            (progn
              (setq drawing-id (eskd-find-drawing-id attrs))
              (if drawing-id
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
                        (eskd-wire-body attrs drawing-id)
                      )
                    )
                    (progn
                      (setq result (eskd-http-json "POST" (eskd-api-url "/api/wire-endpoints/") (eskd-wire-body attrs drawing-id)))
                      (eskd-print-http-result "WireEndpoint SYNC create" result)
                      (eskd-store-created-endpoint-id entity result)
                    )
                  )
                )
                (princ "\nParent drawing was not found. Create/sync drawing first.")
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
(princ "\nCommands: ESKD_WIRE_LINK_REF, ESKD_WIRE_CLEAR_REF, ESKD_WIRE_SYNC, plus GET/CREATE/UPDATE/DELETE variants.")
(princ)
