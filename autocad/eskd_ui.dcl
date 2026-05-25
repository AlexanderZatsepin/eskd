eskd_main : dialog {
  label = "ESKD";

  : boxed_column {
    label = "Authorization";
    : row {
      : button { key = "login"; label = "Login"; width = 18; }
      : button { key = "status"; label = "Status"; width = 18; }
      : button { key = "logout"; label = "Logout"; width = 18; }
    }
  }

  : boxed_column {
    label = "Current project and cabinet";
    : edit_box { key = "project_id"; label = "PROJECT_ID"; edit_width = 28; }
    : edit_box { key = "project_name"; label = "PROJECT_NAME"; edit_width = 28; }
    : edit_box { key = "project_description"; label = "PROJECT_DESCRIPTION"; edit_width = 28; }
    : edit_box { key = "cabinet_id"; label = "CABINET_ID"; edit_width = 28; }
    : edit_box { key = "cabinet_name"; label = "CABINET_NAME"; edit_width = 28; }
    : edit_box { key = "cabinet_description"; label = "CABINET_DESCRIPTION"; edit_width = 28; }
    : row {
      : button { key = "context_save"; label = "Use context"; width = 18; }
      : button { key = "project_sync"; label = "Project Sync"; width = 18; }
      : button { key = "cabinet_sync"; label = "Cabinet Sync"; width = 18; }
    }
  }

  : boxed_column {
    label = "Marking";
    : row {
      : button { key = "wire_insert"; label = "Add marking block"; width = 24; }
    }
    : row {
      : button { key = "wire_sync"; label = "Marking Sync"; width = 18; }
      : button { key = "wire_link"; label = "Link REF_ID"; width = 18; }
      : button { key = "wire_clear"; label = "Clear REF_ID"; width = 18; }
    }
  }

  : boxed_column {
    label = "Reports";
    : row {
      : button { key = "cambrics_report"; label = "Cambrics report"; width = 24; }
    }
  }

  : row {
    fixed_width = true;
    alignment = centered;
    : cancel_button { key = "close"; label = "Close"; width = 18; }
  }
}
