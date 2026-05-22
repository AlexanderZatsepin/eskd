# ESKD marking CRUD service

Минимальный Django REST Framework CRUD-микросервис для таблицы встречной маркировки.

## Stack

- Python 3.9
- Django 4.2
- Django REST Framework
- DRF TokenAuthentication
- SQLite для локальной разработки

## Models

### Project

Проект верхнего уровня.

- `project_id` - внешний идентификатор проекта, например `PRJ-2026-001`
- `order_number` - номер заказа
- `name` - название проекта
- `description` - описание

### Drawing

Чертеж внутри проекта.

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

## Authorization

Все CRUD-запросы требуют токен в HTTP-заголовке:

```text
Authorization: Token <token>
```

Получить токен можно по логину и паролю:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8000/api/auth/token/ `
  -Body @{ username = "admin"; password = "password" }
```

Создать пользователя:

```powershell
.\.venv\Scripts\python.exe manage.py createsuperuser
```

## API

- `/api/projects/`
- `/api/drawings/`
- `/api/wire-endpoints/`

Фильтры:

- `/api/drawings/?project_id=PRJ-2026-001`
- `/api/wire-endpoints/?project_id=PRJ-2026-001`
- `/api/wire-endpoints/?dwg_id=SHU-01-001`
- `/api/wire-endpoints/?ref_id=W-000101`
- `/api/wire-endpoints/?sync_status=DIRTY`

## Reports

Страница формирования Excel-таблицы кембриков:

```text
http://127.0.0.1:8000/reports/cambrics/
```

Страница требует вход через Django. Можно зайти пользователем `admin` через:

```text
http://127.0.0.1:8000/admin/
```

Форма принимает:

```text
PROJECT_ID
ORDER_NUMBER
```

После отправки скачивается `.xlsx` файл. Таблица сортируется по чертежу, маркировке и `REF_ID`.

## Run

```powershell
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

После запуска:

```text
http://127.0.0.1:8000/api/
```

## AutoCAD LISP auth

Первый LISP-скрипт лежит здесь:

```text
autocad/eskd_auth.lsp
```

CRUD-скрипт для проектов и чертежей:

```text
autocad/eskd_project_drawing_crud.lsp
```

CRUD-скрипт для маркировки:

```text
autocad/eskd_wire_endpoint_crud.lsp
```

Загрузка в AutoCAD:

```text
APPLOAD -> autocad/eskd_auth.lsp
APPLOAD -> autocad/eskd_project_drawing_crud.lsp
APPLOAD -> autocad/eskd_wire_endpoint_crud.lsp
```

Команды авторизации:

- `ESKD_LOGIN` - спросит server URL, username, password и получит токен
- `ESKD_STATUS` - покажет, есть ли токен в памяти AutoCAD
- `ESKD_LOGOUT` - удалит токен из памяти

Токен хранится только в памяти текущей сессии AutoCAD. В DWG он не записывается.

Команды CRUD проекта:

- `ESKD_PROJECT_GET`
- `ESKD_PROJECT_CREATE`
- `ESKD_PROJECT_UPDATE`
- `ESKD_PROJECT_DELETE`
- `ESKD_PROJECT_SYNC` - создать, если проекта нет; обновить, если есть

Команды CRUD чертежа:

- `ESKD_DRAWING_GET`
- `ESKD_DRAWING_CREATE`
- `ESKD_DRAWING_UPDATE`
- `ESKD_DRAWING_DELETE`
- `ESKD_DRAWING_SYNC` - создать, если чертежа нет; обновить, если есть

Команды выбирают блок на чертеже и читают его атрибуты.

Атрибуты блока проекта:

```text
Block name: Block_Test_Project
PROJECT_ID
ORDER_NUMBER
PROJECT_NAME
DESCRIPTION
```

Атрибуты блока чертежа:

```text
Block name: Block_Test_Drawing
PROJECT_ID
ORDER_NUMBER
DWG_ID
DWG_NAME
FILE_NAME
```

Команды CRUD маркировки:

- `ESKD_WIRE_GET`
- `ESKD_WIRE_CREATE`
- `ESKD_WIRE_UPDATE`
- `ESKD_WIRE_DELETE`
- `ESKD_WIRE_SYNC` - создать, если конца провода нет; обновить, если есть
- `ESKD_WIRE_LINK_REF` - выбрать два блока маркировки и записать одинаковый `REF_ID` в оба

Атрибуты блока маркировки:

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

Для `ESKD_WIRE_LINK_REF` можно выбирать блоки с пустым `REF_ID`. Команда возьмет существующий `REF_ID` из одного из блоков или создаст новый по handles выбранных блоков, затем запишет его в оба блока и поставит `SYNC_STATUS = DIRTY`.
