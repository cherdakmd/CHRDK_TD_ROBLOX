# Как дорабатывать «РУБЕЖ»

Спасибо за интерес к проекту! Ниже — короткий порядок работы, чтобы изменения не расходились между сервером, клиентом и Studio-сборкой.

## Подготовка

Нужны Roblox Studio, Python 3.11+, Git и [Luau CLI](https://github.com/luau-lang/luau/releases). Для live-sync необязателен, но удобен [Rojo](https://rojo.space/).

```bash
git clone https://github.com/cherdakmd/CHRDK_TD_ROBLOX.git
cd CHRDK_TD_ROBLOX
python3 -m venv .venv
# Linux/macOS
.venv/bin/pip install -r requirements-dev.txt
# Windows
.venv\Scripts\pip install -r requirements-dev.txt
```

## Где что лежит

- `src/shared/Config.luau` — цены, урон, радиусы, волны, таймеры и координаты карты.
- `src/shared/` — чистая общая логика без изменения состояния матча.
- `src/server/` — авторитетное состояние, бой, экономика, сохранения.
- `src/client/` — ввод, камера, HUD и локальные визуальные эффекты.
- `tests/` — headless-проверки на Luau и Python.
- `tools/build_place.py` — сборка `release/CHRDK_Rubezh.rbxlx` без Rojo.
- `docs/` — архитектура, чек-лист Studio и схема карты.

## Правила изменений

1. Сервер принимает решение о золоте, уроне, строительстве и наградах. Клиент отправляет только намерение.
2. Новое RemoteEvent-действие должно проверять тип полей, фазу матча, права игрока и лимит действий.
3. Балансные числа держим в `Config.luau`, а не копируем в UI и тесты.
4. Не добавляйте в Git `.venv`, секреты, токены, локальные `.rbxl.lock` и пользовательские данные.
5. Не меняйте схему DataStore без миграции и теста совместимости.
6. После изменения исходников пересоберите Studio-файл той же командой, что использует CI.

## Проверка перед pull request

```bash
python -m unittest discover -s tests -p 'test_*.py' -v
python tests/run_tests.py --luau /path/to/luau
python tools/build_place.py
python tools/render_preview.py
```

Если менялся UI, ввод, камера, репликация или сохранения, дополнительно пройдите [`docs/STUDIO_CHECKLIST_RU.md`](docs/STUDIO_CHECKLIST_RU.md). Headless mock не эмурирует настоящий Roblox-клиент и не заменяет тест с несколькими игроками.

В PR опишите: что изменилось, как проверено, какие параметры баланса затронуты и нужны ли скриншоты/видео. Не прикладывайте секреты и логи с персональными данными.

## Стиль

- Luau: tab-отступы, `PascalCase` для сервисов/модулей, `camelCase` для локальных переменных.
- Игровые тексты для игроков — на русском; комментарии к протоколу и внутренним инвариантам можно писать по-английски.
- Один модуль — одна зона ответственности. Не смешивайте визуальные эффекты с расчётом урона.
- Версию меняйте в `Config.luau`, `CHANGELOG.md` и тегах релиза согласованно.
