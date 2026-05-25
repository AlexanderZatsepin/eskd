;;; ESKD simple DCL UI for AutoCAD 2016-2018.
;;; Load after:
;;;   autocad/eskd_auth.lsp
;;;   autocad/eskd_project_drawing_crud.lsp
;;;   autocad/eskd_wire_endpoint_crud.lsp
;;;
;;; Command:
;;;   ESKD

(vl-load-com)

(defun eskd-ui-dcl-path (/ current)
  (setq current (findfile "eskd_ui.dcl"))
  (if current
    current
    (findfile "autocad/eskd_ui.dcl")
  )
)

(defun eskd-ui-open-url (url)
  (startapp "cmd.exe" (strcat "/c start \"\" \"" url "\""))
)

(defun c:ESKD (/ dcl-path dcl-id action)
  (setq dcl-path (eskd-ui-dcl-path))
  (if (not dcl-path)
    (progn
      (princ "\nCannot find eskd_ui.dcl. Add the autocad folder to Support File Search Path or load from that folder.")
      (princ)
    )
    (progn
      (setq dcl-id (load_dialog dcl-path))
      (if (not (new_dialog "eskd_main" dcl-id))
        (progn
          (unload_dialog dcl-id)
          (princ "\nCannot open ESKD dialog.")
        )
        (progn
          (setq action nil)

          (action_tile "login" "(setq action \"login\")(done_dialog 1)")
          (action_tile "status" "(setq action \"status\")(done_dialog 1)")
          (action_tile "logout" "(setq action \"logout\")(done_dialog 1)")
          (action_tile "project_sync" "(setq action \"project_sync\")(done_dialog 1)")
          (action_tile "cabinet_insert" "(setq action \"cabinet_insert\")(done_dialog 1)")
          (action_tile "cabinet_sync" "(setq action \"cabinet_sync\")(done_dialog 1)")
          (action_tile "wire_sync" "(setq action \"wire_sync\")(done_dialog 1)")
          (action_tile "wire_insert" "(setq action \"wire_insert\")(done_dialog 1)")
          (action_tile "wire_link" "(setq action \"wire_link\")(done_dialog 1)")
          (action_tile "wire_clear" "(setq action \"wire_clear\")(done_dialog 1)")
          (action_tile "cambrics_report" "(setq action \"cambrics_report\")(done_dialog 1)")
          (action_tile "close" "(setq action \"close\")(done_dialog 0)")

          (start_dialog)
          (unload_dialog dcl-id)

          (cond
            ((= action "login") (c:ESKD_LOGIN))
            ((= action "status") (c:ESKD_STATUS))
            ((= action "logout") (c:ESKD_LOGOUT))
            ((= action "project_sync") (c:ESKD_PROJECT_SYNC))
            ((= action "cabinet_insert") (c:ESKD_CABINET_INSERT))
            ((= action "cabinet_sync") (c:ESKD_CABINET_SYNC))
            ((= action "wire_sync") (c:ESKD_WIRE_SYNC))
            ((= action "wire_insert") (c:ESKD_WIRE_INSERT))
            ((= action "wire_link") (c:ESKD_WIRE_LINK_REF))
            ((= action "wire_clear") (c:ESKD_WIRE_CLEAR_REF))
            ((= action "cambrics_report")
              (if *eskd-server-url*
                (eskd-ui-open-url (strcat (eskd-trim-right-slash *eskd-server-url*) "/reports/cambrics/"))
                (princ "\nESKD server URL is not set. Run ESKD_LOGIN first.")
              )
            )
            (T nil)
          )
        )
      )
    )
  )
  (princ)
)

(princ "\nESKD UI loaded. Command: ESKD.")
(princ)
