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

(defun eskd-ui-value (value)
  (if value value "")
)

(defun eskd-ui-fill-context ()
  (set_tile "project_id" (eskd-ui-value *eskd-current-project-id*))
  (set_tile "project_name" (eskd-ui-value *eskd-current-project-name*))
  (set_tile "project_description" (eskd-ui-value *eskd-current-project-description*))
  (set_tile "cabinet_id" (eskd-ui-value *eskd-current-cabinet-id*))
  (set_tile "cabinet_name" (eskd-ui-value *eskd-current-cabinet-name*))
  (set_tile "cabinet_description" (eskd-ui-value *eskd-current-cabinet-description*))
)

(defun eskd-ui-save-context ()
  (setq *eskd-current-project-name* (get_tile "project_name"))
  (setq *eskd-current-project-description* (get_tile "project_description"))
  (setq *eskd-current-cabinet-name* (get_tile "cabinet_name"))
  (setq *eskd-current-cabinet-description* (get_tile "cabinet_description"))
)

(defun c:ESKD (/ dcl-path dcl-id action)
  (setq dcl-path (eskd-ui-dcl-path))
  (if (not dcl-path)
    (progn
      (princ "\nНе найден eskd_ui.dcl. Добавьте папку autocad в Support File Search Path или загружайте LISP из этой папки.")
      (princ)
    )
    (progn
      (setq dcl-id (load_dialog dcl-path))
      (if (not (new_dialog "eskd_main" dcl-id))
        (progn
          (unload_dialog dcl-id)
          (princ "\nНе удалось открыть окно ESKD.")
        )
        (progn
          (setq action nil)
          (eskd-ui-fill-context)

          (action_tile "login" "(setq action \"login\")(done_dialog 1)")
          (action_tile "status" "(setq action \"status\")(done_dialog 1)")
          (action_tile "logout" "(setq action \"logout\")(done_dialog 1)")
          (action_tile "context_save" "(eskd-ui-save-context)(setq action \"context_save\")(done_dialog 1)")
          (action_tile "project_sync" "(eskd-ui-save-context)(setq action \"project_sync\")(done_dialog 1)")
          (action_tile "cabinet_sync" "(eskd-ui-save-context)(setq action \"cabinet_sync\")(done_dialog 1)")
          (action_tile "wire_sync" "(eskd-ui-save-context)(setq action \"wire_sync\")(done_dialog 1)")
          (action_tile "wire_insert" "(eskd-ui-save-context)(setq action \"wire_insert\")(done_dialog 1)")
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
            ((= action "context_save") (c:ESKD_CONTEXT_STATUS))
            ((= action "project_sync") (c:ESKD_PROJECT_SYNC))
            ((= action "cabinet_sync") (c:ESKD_CABINET_SYNC))
            ((= action "wire_sync") (c:ESKD_WIRE_SYNC))
            ((= action "wire_insert") (c:ESKD_WIRE_INSERT))
            ((= action "wire_link") (c:ESKD_WIRE_LINK_REF))
            ((= action "wire_clear") (c:ESKD_WIRE_CLEAR_REF))
            ((= action "cambrics_report")
              (if *eskd-server-url*
                (eskd-ui-open-url (strcat (eskd-trim-right-slash *eskd-server-url*) "/reports/cambrics/"))
                (princ "\nАдрес сервера ESKD не задан. Сначала выполните вход.")
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

(princ "\nИнтерфейс ESKD загружен. Команда: ESKD.")
(princ)
