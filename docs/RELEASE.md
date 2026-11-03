# Выпуск версии

## Что считается готовым

- Все Python- и Luau-тесты проходят.
- `release/CHRDK_Rubezh.rbxlx` пересобран из текущих `src/`.
- Пройден [`STUDIO_CHECKLIST_RU.md`](STUDIO_CHECKLIST_RU.md), включая 4 игрока и мобильный экран.
- Версия в `src/shared/Config.luau` совпадает с записью в `CHANGELOG.md`.
- В репозитории нет токенов, паролей, `.venv`, локальных lock-файлов Studio и персональных данных.

## Автоматический GitHub Release

Workflow `.github/workflows/release.yml` запускается на тегах `v*`, повторяет тесты, собирает place и прикладывает:

- `CHRDK_Rubezh.rbxlx` — открыть в Roblox Studio;
- `CHRDK_Rubezh_Source.zip` — исходники из Git-архива;
- `SHA256SUMS.txt` — контрольные суммы.

```bash
git tag v0.1.0
git push origin v0.1.0
```

Теги `v0.*` публикуются как prerelease. Для публичного релиза опыта сначала объедините проверенную ветку с `main`, затем ставьте тег на проверенный коммит. Не выпускайте тег с непроверенными изменениями сохранений.

## Ручная сборка

```bash
python tools/build_place.py
python tools/render_preview.py
```

Studio-файл содержит скрипты; карта создаётся сервером при запуске. После публикации настройте **Max Players = 4** и проверьте DataStore. Исходники иplace не заменяют настройки опубликованного опыта на стороне Roblox.

## Проверка артефакта

```bash
cd release
sha256sum -c SHA256SUMS.txt
```

На Windows можно сравнить `Get-FileHash .\CHRDK_Rubezh.rbxlx -Algorithm SHA256` со значением в `SHA256SUMS.txt`.
