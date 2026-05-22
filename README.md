# ESKD marking CRUD service

Минимальный Django REST Framework CRUD-микросервис для таблицы встречной маркировки.

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
- `order_number` - номер заказа
- `name` - название проекта
- `description` - описание

Пара `project_id + order_number` уникальна.

### Drawing

- `project` - ссылка на проект
- `dwg_id` - идентификатор чертежа или DWG-файла, например `SHU-01-001`
- `name` - название чертежа
- `file_name` - имя файла

Пара `project + dwg_id` уникальна.

### WireEndpoint

Один конец провода / один блок маркировки.

- `endpoint_id` - уникальный идентификатор, например `END-8F3A2C9D`
- `drawing` - ссылка на чертеж
- `ref_id` - общий идентификатор связи/провода, например `W-000101`
- `mark` - точка подключения, например `K1:14`
- `position` - позиция/зона/место
- `wire_type` - тип/сечение провода
- `wire_color` - цвет провода
- `sync_status` - `NEW`, `SYNCED`, `DIRTY`, `ERROR`

`endpoint_id` можно не передавать при создании: сервер сгенерирует его сам.

## Authorization

Все CRUD-запросы требуют токен:

```text
Authorization: Token <token>
```

Получить токен:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8000/api/auth/token/ `
  -Body @{ username = "admin"; password = "awesome1" }
```

Создать админа:

```powershell
python manage.py createsuperuser
```

## API

- `/api/projects/`
- `/api/drawings/`
- `/api/wire-endpoints/`

Фильтры:

- `/api/projects/?project_id=PRJ-2026-001&order_number=ORD-001`
- `/api/drawings/?project_id=PRJ-2026-001&order_number=ORD-001`
- `/api/drawings/?project_id=PRJ-2026-001&order_number=ORD-001&dwg_id=SHU-01-001`
- `/api/wire-endpoints/?project_id=PRJ-2026-001&order_number=ORD-001`
- `/api/wire-endpoints/?dwg_id=SHU-01-001`
- `/api/wire-endpoints/?ref_id=W-000101`
- `/api/wire-endpoints/?sync_status=DIRTY`

## Reports

Страница формирования Excel-таблицы кембриков:

```text
http://127.0.0.1:8000/reports/cambrics/
```

Страница требует вход через Django admin:

```text
http://127.0.0.1:8000/admin/
```

Форма принимает:

```text
PROJECT_ID
ORDER_NUMBER
```

После отправки скачивается `.xlsx` файл. Таблица сортируется по чертежу, маркировке и `REF_ID`.

## Run On Windows

```bat
py -3.9 -m venv .venv
.\.venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8010
```

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
```

Команды авторизации:

- `ESKD_LOGIN`
- `ESKD_STATUS`
- `ESKD_LOGOUT`

Команды проекта:

- `ESKD_PROJECT_GET`
- `ESKD_PROJECT_CREATE`
- `ESKD_PROJECT_UPDATE`
- `ESKD_PROJECT_DELETE`
- `ESKD_PROJECT_SYNC`

Команды чертежа:

- `ESKD_DRAWING_GET`
- `ESKD_DRAWING_CREATE`
- `ESKD_DRAWING_UPDATE`
- `ESKD_DRAWING_DELETE`
- `ESKD_DRAWING_SYNC`

Команды маркировки:

- `ESKD_WIRE_GET`
- `ESKD_WIRE_CREATE`
- `ESKD_WIRE_UPDATE`
- `ESKD_WIRE_DELETE`
- `ESKD_WIRE_SYNC`
- `ESKD_WIRE_LINK_REF`
- `ESKD_WIRE_CLEAR_REF`

## AutoCAD Blocks

Блок проекта:

```text
Block name: Block_Test_Project
PROJECT_ID
ORDER_NUMBER
PROJECT_NAME
DESCRIPTION
```

Блок чертежа:

```text
Block name: Block_Test_Drawing
PROJECT_ID
ORDER_NUMBER
DWG_ID
DWG_NAME
FILE_NAME
```

Блок маркировки:

```text
Block name: Block_Test_Marking
ENDPOINT_ID
PROJECT_ID
ORDER_NUMBER
DWG_ID
REF_ID
MARK
POSITION
WIRE_TYPE
WIRE_COLOR
SYNC_STATUS
```

`ENDPOINT_ID` в новом блоке можно оставлять пустым. При первом `ESKD_WIRE_CREATE` или `ESKD_WIRE_SYNC` сервер создаст ID вида `END-XXXXXXXXX`, а LISP запишет его обратно в атрибут блока.

`ESKD_WIRE_LINK_REF` выбирает два блока маркировки и записывает одинаковый `REF_ID` в оба. Если `REF_ID` уже есть в одном из блоков, используется он. Если оба пустые, создается новый по handles выбранных блоков.

`REF_ID` не создается сервером при создании маркировки. Его нужно назначать отдельной командой `ESKD_WIRE_LINK_REF`. Если блок был скопирован и унаследовал старый `REF_ID`, очисти его командой `ESKD_WIRE_CLEAR_REF`.
