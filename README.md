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

- `project_id` - UUID проекта, генерируется сервером и не вводится вручную
- `project_code` - шифр проекта, вводится пользователем, уникален
- `name` - название проекта
- `is_active` - активный проект, только активные проекты загружаются в AutoCAD по умолчанию

### Cabinet

- `project` - ссылка на проект
- `cabinet_id` - UUID шкафа, генерируется сервером и не вводится вручную
- `cabinet_code` - код шкафа, уникален внутри проекта
- `name` - название шкафа
- `description` - описание

### WireEndpoint

- `endpoint_id` - UUID маркировки, генерируется сервером
- `cabinet` - ссылка на шкаф
- `ref_id` - UUID связи, присваивается командой связи двух блоков
- `mark_1` - маркировка 1, по умолчанию `-`
- `mark_2` - маркировка 2, по умолчанию `-`
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
  -Uri http://127.0.0.1:8010/api/auth/token/ `
  -Body @{ username = "admin"; password = "awesome1" }
```

## API

- `/api/projects/`
- `/api/cabinets/`
- `/api/wire-types/`
- `/api/wire-colors/`
- `/api/wire-endpoints/`

Фильтры:

- `/api/projects/?project_id=<uuid>`
- `/api/projects/?project_code=<project-code>`
- `/api/projects/?active=all`
- `/api/cabinets/?project_id=<uuid>`
- `/api/cabinets/?project_code=<project-code>`
- `/api/cabinets/?project_id=<uuid>&cabinet_id=<uuid>`
- `/api/cabinets/?project_id=<uuid>&cabinet_code=<cabinet-code>`
- `/api/wire-endpoints/?project_id=<uuid>`
- `/api/wire-endpoints/?project_code=<project-code>`
- `/api/wire-endpoints/?cabinet_id=<uuid>`
- `/api/wire-endpoints/?ref_id=<uuid>`
- `/api/wire-endpoints/?mark_1=K1:14`
- `/api/wire-endpoints/?sync_status=DIRTY`

## Reports

Страница формирования Excel-таблицы кембриков:

```text
http://127.0.0.1:8010/reports/cambrics/
```

Страница требует вход через Django admin. На странице выбирается проект, затем кнопка нужного шкафа. После клика скачивается `.xlsx` файл только по выбранному шкафу.

## Tests

```bat
python manage.py test marking
```

Тесты проверяют, что частичные `PATCH`-запросы из панели AutoCAD не стирают `MARK_1` и `MARK_2`, а Excel-отчет продолжает видеть маркировки после обновления связи, статуса, типа или цвета провода.

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

Один раз проверить и применить новый коммит:

```bat
scripts\windows_autodeploy.bat -Once
```

Запустить постоянную проверку:

```bat
scripts\windows_autodeploy.bat -IntervalSeconds 300
```

Скрипт делает `git pull`, применяет миграции и перезапускает Django `runserver`.

## AutoCAD .NET

Загрузка в AutoCAD:

```text
NETLOAD -> autocad-dotnet/bin/Release/Eskd.AutoCAD.dll
```

Панель:

```text
ESKD_PANEL
```

Проект создается или выбирается через панель. Пользователь вводит `Шифр проекта` и название. Если проект с таким шифром уже есть на сервере, команда `Сохранить проект` не создает дубль, а выбирает существующий проект и возвращает его `PROJECT_ID`.

Шкаф создается или выбирается через панель после выбора проекта. `PROJECT_ID` и `CABINET_ID` генерируются сервером как UUID и показываются в панели после сохранения.

В панели можно:

1. `Загрузить` список активных проектов.
2. Выбрать проект из списка и нажать `Выбрать`.
3. `Загрузить` шкафы выбранного проекта.
4. Выбрать шкаф из списка и нажать `Выбрать`.

Если нужного проекта или шкафа нет, его можно ввести вручную и нажать `Сохранить проект` или `Сохранить шкаф`.

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

В шаблоне `autocad/eskd_blocks_template.dxf` блок содержит только атрибуты, без линий и другой геометрии. Служебные атрибуты `ENDPOINT_ID`, `PROJECT_ID`, `CABINET_ID`, `REF_ID`, `SYNC_STATUS` скрыты. На чертеже видны четыре рабочих атрибута: `MARK_1`, `MARK_2`, `WIRE_TYPE`, `WIRE_COLOR`.

`ENDPOINT_ID` создается сервером и записывается обратно в блок после создания маркировки через панель.

`REF_ID` создается кнопкой `Связать`, когда выбираются два блока маркировки. Сервер сам `REF_ID` не создает.

Кнопка `Добавить блок маркировки` вставляет новый `Block_Test_Marking` и использует значения:

```text
MARK_1
MARK_2
```

`WIRE_TYPE` и `WIRE_COLOR` при вставке получают значение `-`.

Тип и цвет провода назначаются массово из панели:

1. Нажать `Загрузить справочники`.
2. Выбрать `Тип` и `Цвет`.
3. Нажать `Назначить выбранным`.
4. Выбрать блоки `Block_Test_Marking` в чертеже.

Выбранные блоки получают `WIRE_TYPE`, `WIRE_COLOR` и статус `DIRTY`.
