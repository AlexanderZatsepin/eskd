# ESKD AutoCAD .NET Palette

Второй вариант интерфейса для AutoCAD: dockable-панель на C# через AutoCAD .NET API `PaletteSet`.

Текущий LISP/DCL вариант остается в папке `autocad/`. Этот проект можно развивать параллельно и постепенно переносить функции сюда.

## Что уже есть

- команда `ESKD_PANEL`;
- боковая панель AutoCAD, которую можно оставить открытой во время работы с чертежом;
- авторизация по DRF token;
- зеленый/красный статус входа;
- загрузка активных проектов;
- выбор или создание проекта;
- загрузка шкафов выбранного проекта;
- выбор или создание шкафа;
- создание записи маркировки в БД и вставка `Block_Test_Marking`;
- сверка текущего чертежа с БД по выбранному шкафу.

## Требования

- AutoCAD 2016-2018 x64;
- .NET Framework 4.5 Developer Pack или Visual Studio с .NET Framework targeting pack;
- Visual Studio / MSBuild для .NET Framework;
- ссылки на AutoCAD DLL:
  - `AcMgd.dll`
  - `AcDbMgd.dll`
  - `AcCoreMgd.dll`

## Сборка

Указать папку с DLL AutoCAD через параметр `AutoCADApiPath`.

Пример для AutoCAD 2018:

```bat
msbuild autocad-dotnet\ESKD.AutoCAD.csproj /p:Configuration=Release /p:AutoCADApiPath="C:\Program Files\Autodesk\AutoCAD 2018"
```

Если AutoCAD установлен в другую папку, поменять путь.

После сборки DLL будет здесь:

```text
autocad-dotnet\bin\Release\Eskd.AutoCAD.dll
```

## Загрузка в AutoCAD

```text
NETLOAD
```

Выбрать:

```text
autocad-dotnet\bin\Release\Eskd.AutoCAD.dll
```

Открыть панель:

```text
ESKD_PANEL
```

## Работа

1. Ввести сервер, логин и пароль.
2. Нажать `Войти`.
3. Нажать `Загрузить` в блоке `Проект`.
4. Выбрать проект или ввести `Шифр` и `Название`, затем `Сохранить`.
5. Нажать `Загрузить` в блоке `Шкаф`.
6. Выбрать шкаф или ввести `Код`, `Название`, `Описание`, затем `Сохранить`.
7. Ввести `MARK_1` и `MARK_2`.
8. Нажать `Добавить блок маркировки`.
9. Указать точку вставки в чертеже.

Перед созданием записи маркировки панель проверяет, что в чертеже есть определение блока `Block_Test_Marking`. Если блока нет, запись в БД не создается.

## Блок маркировки

В чертеже должен быть блок:

```text
Block_Test_Marking
```

С атрибутами:

```text
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
