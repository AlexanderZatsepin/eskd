# ESKD marking CRUD service

Минимальный Django REST Framework CRUD-микросервис для таблицы встречной маркировки и выгрузки таблицы кембриков.

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
- `dwg_id` - идентификатор чертежа или DWG-файла
- `name` - название чертежа
- `file_name` - имя файла

Пара `project + dwg_id` уникальна.

### WireEndpoint

Один блок маркировки / одна запись маркировки.

- `endpoint_id` - UUID, генерируется сервером
- `drawing` - ссылка на чертеж
- `ref_id` - UUID связи, присваивается командой связи двух блоков
- `mark_1` - маркировка 1, по умолчанию `-`
- `mark_2` - маркировка 2, по умолчанию `-`
- `position` - позиция/зона/место
- `wire_type` - тип/сечение провода, по умолчанию `-`
- `wire_color` - цвет провода, по умолчанию `-`
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
- `/api/wire-types/`
- `/api/wire-colors/`
- `/api/wire-endpoints/`

Фильтры:

- `/api/projects/?project_id=PRJ-2026-001&order_number=ORD-001`
- `/api/drawings/?project_id=PRJ-2026-001&order_number=ORD-001`
- `/api/drawings/?project_id=PRJ-2026-001&order_number=ORD-001&dwg_id=SHU-01-001`
- `/api/wire-endpoints/?project_id=PRJ-2026-001&order_number=ORD-001`
- `/api/wire-endpoints/?dwg_id=SHU-01-001`
- `/api/wire-endpoints/?ref_id=<uuid>`
- `/api/wire-endpoints/?mark_1=K1:14`
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
APPLOAD -> autocad/eskd_ui.lsp
```

Главное окно:

```text
ESKD
```

Текущий интерфейс сделан на DCL. DCL в AutoCAD модальный: пока окно открыто, чертежом работать нельзя. Поэтому окно закрывается после нажатия кнопки, выполняет команду и возвращает управление AutoCAD. Для постоянно открытой панели нужен отдельный .NET PaletteSet-плагин.

Адрес сервера по умолчанию для `ESKD_LOGIN`:

```text
http://172.16.51.49:8010
```

В меню есть кнопки:

- `Login`
- `Status`
- `Logout`
- `Project Sync`
- `Drawing Sync`
- `Add marking block`
- `Marking Sync`
- `Link REF_ID`
- `Clear REF_ID`
- `Cambrics report`

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
MARK_1
MARK_2
POSITION
WIRE_TYPE
WIRE_COLOR
SYNC_STATUS
```

`ENDPOINT_ID` создается сервером как UUID и записывается обратно в блок после первого успешного `ESKD_WIRE_CREATE` или `ESKD_WIRE_SYNC`.

`REF_ID` создается как UUID командой `ESKD_WIRE_LINK_REF`, когда выбираются два блока маркировки. Сервер сам `REF_ID` не создает.

`ESKD_WIRE_INSERT` / кнопка `Add marking block` вставляет новый `Block_Test_Marking` и спрашивает:

```text
MARK_1
MARK_2
WIRE_TYPE
WIRE_COLOR
```

Значение по умолчанию для этих полей: `-`.

Если блок был скопирован и унаследовал старый `REF_ID`, очисти его командой `ESKD_WIRE_CLEAR_REF`.
