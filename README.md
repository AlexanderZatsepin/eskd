# ESKD marking CRUD service

Минимальный Django REST Framework CRUD-микросервис для встречной маркировки и выгрузки таблицы кембриков.

## Stack

- Python 3.9+
- Django 4.2
- Django REST Framework
- DRF TokenAuthentication
- SQLite для локальной разработки
- openpyxl для Excel-отчета

## Models

### Project

- `project_id` - идентификатор проекта, например `PRJ-2026-001`
- `name` - название проекта
- `description` - описание

`project_id` уникален.

### Cabinet

- `project` - ссылка на проект
- `cabinet_id` - идентификатор шкафа
- `name` - название шкафа
- `description` - описание

Пара `project + cabinet_id` уникальна.

### WireType

- `name` - тип/сечение провода
- `description` - описание

### WireColor

- `name` - цвет провода
- `description` - описание

### WireEndpoint

Один блок маркировки / одна запись маркировки.

- `endpoint_id` - UUID, генерируется сервером
- `cabinet` - ссылка на шкаф
- `ref_id` - UUID связи, присваивается командой связи двух блоков
- `mark_1` - маркировка 1, по умолчанию `-`
- `mark_2` - маркировка 2, по умолчанию `-`
- `wire_type` - ссылка на справочник типа провода, по умолчанию `-`
- `wire_color` - ссылка на справочник цвета провода, по умолчанию `-`
- `sync_status` - `NEW`, `SYNCED`, `DIRTY`, `ERROR`

## Authorization

Все CRUD-запросы требуют токен:

```text
Authorization: Token <token>
```

Получить токен:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8010/api/auth/token/ `
  -Body @{ username = "admin"; password = "awesome1" }
```

Создать админа:

```powershell
python manage.py createsuperuser
```

## API

- `/api/projects/`
- `/api/cabinets/`
- `/api/wire-types/`
- `/api/wire-colors/`
- `/api/wire-endpoints/`

Фильтры:

- `/api/projects/?project_id=PRJ-2026-001`
- `/api/cabinets/?project_id=PRJ-2026-001`
- `/api/cabinets/?project_id=PRJ-2026-001&cabinet_id=SHU-01`
- `/api/wire-endpoints/?project_id=PRJ-2026-001`
- `/api/wire-endpoints/?cabinet_id=SHU-01`
- `/api/wire-endpoints/?ref_id=<uuid>`
- `/api/wire-endpoints/?mark_1=K1:14`
- `/api/wire-endpoints/?sync_status=DIRTY`

## Reports

Страница формирования Excel-таблицы кембриков:

```text
http://127.0.0.1:8010/reports/cambrics/
```

Страница требует вход через Django admin:

```text
http://127.0.0.1:8010/admin/
```

Форма принимает:

```text
PROJECT_ID
```

После отправки скачивается `.xlsx` файл. Таблица сортируется по шкафу, маркировке и `REF_ID`.

## Run On Windows

```bat
py -3.9 -m venv .venv
.\.venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8010
```

## Auto Deploy On Windows

Простой вариант для тестовой VM: скрипт сам проверяет `origin/master`, делает `git pull`, применяет миграции и перезапускает Django `runserver`.

Один раз проверить и применить новый коммит:

```bat
scripts\windows_autodeploy.bat -Once
```

Запустить постоянную проверку каждые 30 секунд:

```bat
scripts\windows_autodeploy.bat
```

Другой интервал или порт:

```bat
scripts\windows_autodeploy.bat -IntervalSeconds 60 -Port 8010
```

Скрипт требует чистую рабочую папку Git. Если на VM есть локальные изменения, он остановится и не будет делать `pull`.

Если нужен конкретный IP:

```bat
set ALLOWED_HOSTS=127.0.0.1,localhost,172.16.51.49
python manage.py runserver 0.0.0.0:8010
```

## AutoCAD LISP

Загрузка в AutoCAD:

```text
APPLOAD -> autocad/eskd_auth.lsp
APPLOAD -> autocad/eskd_project_drawing_crud.lsp
APPLOAD -> autocad/eskd_wire_endpoint_crud.lsp
APPLOAD -> autocad/eskd_ui.lsp
```

Главное окно:

```text
ESKD
```

Текущий интерфейс сделан на DCL. DCL в AutoCAD модальный: пока окно открыто, с чертежом работать нельзя. Поэтому окно закрывается после нажатия кнопки, выполняет команду и возвращает управление AutoCAD. Для постоянно открытой панели нужен отдельный .NET PaletteSet-плагин.

Адрес сервера по умолчанию для `ESKD_LOGIN`:

```text
http://172.16.51.49:8010
```

В меню есть кнопки:

- `Login`
- `Status`
- `Logout`
- `Use context`
- `Project Sync`
- `Cabinet Sync`
- `Add marking block`
- `Marking Sync`
- `Link REF_ID`
- `Clear REF_ID`
- `Cambrics report`

## AutoCAD Block

Проект и шкаф выбираются в панели `ESKD`, отдельные блоки проекта и шкафа в DWG больше не нужны.

В чертеже нужен только блок маркировки:

```text
Block name: Block_Test_Marking
ENDPOINT_ID
PROJECT_ID
CABINET_ID
REF_ID
MARK_1
MARK_2
WIRE_TYPE
WIRE_COLOR
SYNC_STATUS
```

`ENDPOINT_ID` создается сервером как UUID и записывается обратно в блок после первого успешного `ESKD_WIRE_CREATE` или `ESKD_WIRE_SYNC`.

`REF_ID` создается как UUID командой `ESKD_WIRE_LINK_REF`, когда выбираются два блока маркировки. Сервер сам `REF_ID` не создает.

В панели `ESKD` заполняются поля текущего контекста:

```text
PROJECT_ID
PROJECT_NAME
PROJECT_DESCRIPTION
CABINET_ID
CABINET_NAME
CABINET_DESCRIPTION
```

`ESKD_WIRE_INSERT` / кнопка `Add marking block` вставляет новый `Block_Test_Marking` и спрашивает:

```text
MARK_1
MARK_2
WIRE_TYPE
WIRE_COLOR
```

Значение по умолчанию для этих полей: `-`.

Если блок был скопирован и унаследовал старый `REF_ID`, очисти его командой `ESKD_WIRE_CLEAR_REF`.
