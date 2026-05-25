eskd_main : dialog {
  label = "ESKD";

  : boxed_column {
    label = "Авторизация";
    : row {
      : button { key = "login"; label = "Войти"; width = 18; }
      : button { key = "status"; label = "Статус"; width = 18; }
      : button { key = "logout"; label = "Выйти"; width = 18; }
    }
  }

  : boxed_column {
    label = "Текущий проект и шкаф";
    : row {
      : text { label = "UUID проекта:"; width = 20; }
      : text { key = "project_id"; label = ""; width = 40; }
    }
    : edit_box { key = "project_name"; label = "Название проекта"; edit_width = 28; }
    : edit_box { key = "project_description"; label = "Описание проекта"; edit_width = 28; }
    : row {
      : text { label = "UUID шкафа:"; width = 20; }
      : text { key = "cabinet_id"; label = ""; width = 40; }
    }
    : edit_box { key = "cabinet_name"; label = "Название шкафа"; edit_width = 28; }
    : edit_box { key = "cabinet_description"; label = "Описание шкафа"; edit_width = 28; }
    : row {
      : button { key = "context_save"; label = "Запомнить"; width = 18; }
      : button { key = "project_sync"; label = "Сохранить проект"; width = 20; }
      : button { key = "cabinet_sync"; label = "Сохранить шкаф"; width = 20; }
    }
  }

  : boxed_column {
    label = "Маркировка";
    : row {
      : button { key = "wire_insert"; label = "Добавить блок маркировки"; width = 32; }
    }
    : row {
      : button { key = "wire_sync"; label = "Сохранить"; width = 18; }
      : button { key = "wire_link"; label = "Связать"; width = 18; }
      : button { key = "wire_clear"; label = "Очистить связь"; width = 18; }
    }
  }

  : boxed_column {
    label = "Отчеты";
    : row {
      : button { key = "cambrics_report"; label = "Таблица кембриков"; width = 32; }
    }
  }

  : row {
    fixed_width = true;
    alignment = centered;
    : cancel_button { key = "close"; label = "Закрыть"; width = 18; }
  }
}
