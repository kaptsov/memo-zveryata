# Мемо Зверята — Godot 4.x Game Project

## Описание
Цифровая адаптация настольной карточной игры на память "Мемо Зверята".
8 животных из Красной книги России: манул, сайгак, выхухоль, утка-мандаринка,
ирбис, белая куропатка, амурский тигр, сибирский горный козёл.
2 сезона (лето/зима). Обычный режим: сетка 4×4 = 16 карт (первые 4 животных).
Соло-режим: переменная сетка 2×2 до 4×5, до всех 8 животных × 2 сезона.

## Технический стек
- **Engine**: Godot 4.x (4.3-dev6 на машине разработчика)
- **Language**: GDScript
- **Platform**: Android (portrait 720×1280)
- **Multiplayer**: ENet — LAN (Wi-Fi) или интернет через ZeroTier VPN

## Структура проекта
```
scenes/          — .tscn сцены (main_menu, lobby, game_board, card, results, encyclopedia, settings)
scripts/
  autoload/      — GameManager, NetworkManager, AudioManager (синглтоны)
  data/          — CardData, TaskData, HelpCardData, GameState (без class_name!)
  game/          — card.gd, board.gd
  ui/            — main_menu, lobby, game_board, hud, task_panel, help_panel, results, encyclopedia, settings
assets/sprites/  — animals/ (16 PNG 512×512: 8 животных × 2 сезона), cards/, help/
assets/audio/    — sfx/, bgm/ (WAV-заглушки)
bump_version.sh  — инкремент версии перед экспортом APK
```

## Критические правила
- **НЕ использовать `class_name`** в scripts/data/ — Godot 4.3-dev6 не резолвит их в static методах. Используй `preload()` / `load()`.
- **Сигналы**: все сигналы подключать через `_safe_connect()` (проверка `is_connected`), отключать в `_exit_tree()`.
- **mouse_filter = MOUSE_FILTER_IGNORE** на всех дочерних элементах карты, чтобы клики доходили до корневого Control.
- **TextureRect с большими текстурами**: всегда устанавливать `expand_mode = EXPAND_IGNORE_SIZE`, иначе контрол принимает натуральный размер текстуры и ломает layout.
- **Размер окна для десктоп-тестов**: window_width_override=405, window_height_override=720 (половина от 720×1280).

## Игровая логика (rules)
- **Обычный режим**: 16 карт (4 животных × 2 сезона × 2 копии)
- **Соло-режим**: 4–20 карт; для ≤8 пар — только первые 4 животных; для >8 пар — добавляются новые 4
- Простое задание (1 очко): пара одинаковых (животное + сезон)
- Сложное задание (2 очка): 4 разных животных одного сезона
- Карты помощи: +1 карта, сменить зверька, сменить фон
- Ход: открыл 2 карты → проверка простого → если есть сложное — можно до 4 → проверка сложного
- Если нет совпадения и нет помощи → автопровал
- Если есть помощь → awaiting_player_action, показать кнопку "Завершить ход"
- Конец игры: все задания выполнены ИЛИ стопка помощи пуста

## Версионирование
- `BUILD_VERSION` в `scripts/ui/main_menu.gd` — отображается в левом верхнем углу меню
- Формат: `vMAJOR.MINOR.PATCH`, patch инкрементируется при каждом экспорте
- Перед экспортом APK запускать: `./bump_version.sh` (patch) или `./bump_version.sh --minor`
- Скрипт обновляет `main_menu.gd` и `version/code` в `export_presets.cfg` синхронно

## Команды
- Запуск: Cmd+B в Godot (macOS)
- Инкремент версии: `./bump_version.sh`
- Тест мультиплеера: два экземпляра Godot, один хост, один клиент по IP

## Текущий статус
- [x] Локальная игра 2–6 игроков на одном устройстве
- [x] Полная механика: простые/сложные задания, карты помощи
- [x] Режим "Без карт помощи"
- [x] Режим "Колода заданий"
- [x] Соло-режим (4 уровня сложности: 2×2, 3×4, 4×4, 4×5; фаза запоминания)
- [x] Кнопка "Правила игры" (popup со скроллом)
- [x] Кнопка "Обучение" (placeholder, disabled)
- [x] Мультиплеер по LAN (ENet, 2–6 игроков)
- [x] Игра по интернету через ZeroTier VPN (без изменений кода)
- [x] Спрайты 8 животных × 2 сезона (AI-generated, 512×512 PNG)
- [x] Энциклопедия "О зверятах": 8 карточек, прокрутка 2 колонки, переворот с анимацией
- [x] Динамические шрифты в энциклопедии (пропорционально ширине экрана)
- [x] Версия сборки на главном экране + bump_version.sh
- [x] Кнопка выхода (в меню и в игре с подтверждением)
- [x] Android Back button во всех сценах
- [x] HUD для N игроков (компактный формат при 3+)
- [x] Анимации: flip, shake при провале, highlight
- [x] Звуки и музыка (WAV-заглушки)
- [x] Настройки громкости (сохраняются между сессиями)
- [x] Экспорт Android APK (export_presets.cfg)
- [x] Иконка приложения (assets/icons/, icon.png)
- [x] Политика конфиденциальности (store/privacy_policy.html)
- [x] Листинг для RuStore (store/rustore_listing.md)
- [x] Release APK подписан и отправлен на модерацию в RuStore
- [x] Опубликовано на itch.io (Web + Windows)
- [x] Политика конфиденциальности: https://kaptsov.github.io/memo-zveryata/privacy_policy.html
- [x] Иконка приложения — ирбис
- [x] Скриншоты для RuStore (store/screenshots/)
- [x] Модерация RuStore пройдена
- [x] **Таблица лидеров Соло-режима** — бесконечный режим, сервер sweateratops.ru
- [ ] Заменить спрайты 4 новых животных (вотермарки DaoBao) — рекомендуется Ideogram.ai / Leonardo.ai
- [ ] Мультиплеер для режима "Колода заданий"
- [ ] Раздел "Обучение" (монетизация)
- [ ] Финальные звуки и музыка + голоса животных в энциклопедии

## Таблица лидеров — Соло-режим

### Механика игры (бесконечный соло-режим)
- Карты показываются (фаза запоминания) → игрок нажимает "Играть!"
- Выполняем всю колоду заданий (только SIMPLE)
- Если колода закончилась без единого промаха → карты перемешиваются, новая фаза запоминания, продолжаем
- **При первой неудачной попытке → игра заканчивается**
- Показывается таблица лидеров + место текущего результата
- Счёт = суммарное количество выполненных заданий до промаха

### Раздельные таблицы по сложности
Каждый из 4 режимов (2×2, 3×4, 4×4, 4×5) имеет свою таблицу.

### Серверная часть (sweateratops.ru, Flask + PostgreSQL)
**Новая таблица БД:** `leaderboard`
```
id          SERIAL PRIMARY KEY
difficulty  VARCHAR(8)   -- "2x2", "3x4", "4x4", "4x5"
player_name VARCHAR(32)
score       INTEGER      -- число выполненных заданий
created_at  TIMESTAMP DEFAULT now()
```

**API endpoints** (добавить в app.py на сервере):
```
GET  /api/leaderboard?difficulty=4x4     → top-10 [{name, score, rank}]
POST /api/leaderboard                    → {difficulty, player_name, score} → {rank, total}
```

### Клиентская часть (Godot)
**Новые файлы:**
- `scripts/autoload/leaderboard_manager.gd` — HTTPRequest, методы fetch/submit
- `scenes/leaderboard.tscn` + `scripts/ui/leaderboard.gd` — экран таблицы

**Изменения в существующих файлах:**
- `game_state.gd` — флаг `solo_infinite_mode`, счётчик `solo_total_score`
- `game_manager.gd` — при провале в соло: вместо обычного results → leaderboard
- `game_board.gd` — при конце колоды без промахов: перемешать + фаза запоминания заново
- `main_menu.gd` — кнопка "Таблица лидеров" (опционально)

**Имя игрока:** хранится в `user://player_name.dat` (устанавливается при первом запуске или в настройках)

### Реализовано (код написан)
- [x] `app.py` — модель `Leaderboard` + `GET/POST /api/leaderboard`
- [x] `scripts/autoload/leaderboard_manager.gd` — HTTP клиент, save/load имени
- [x] `scripts/data/game_state.gd` — `solo_difficulty`, `reset_for_next_round()`, fix `_check_game_over`
- [x] `scripts/autoload/game_manager.gd` — `solo_round_complete` сигнал, бесконечный соло
- [x] `scripts/ui/game_board.gd` — `_on_solo_round_complete`, соло game_over → leaderboard
- [x] `scripts/ui/leaderboard.gd` — экран таблицы (строит UI динамически)

### Осталось сделать вручную
1. **Godot Editor**: Project → Project Settings → Autoload → добавить:
   - Path: `res://scripts/autoload/leaderboard_manager.gd`, Name: `LeaderboardManager`
2. **Godot Editor**: создать сцену `scenes/leaderboard.tscn`:
   - Корень: `Control` (скрипт `res://scripts/ui/leaderboard.gd`)
   - Больше ничего не нужно — UI строится в коде
3. **Деплой сервера**:
   ```bash
   scp app.py root@212.109.192.199:/var/www/sweateratops/
   ssh root@212.109.192.199 "cd /var/www/sweateratops && python3 -c 'from app import app, db; app.app_context().push(); db.create_all()'"
   ssh root@212.109.192.199 "systemctl restart sweateratops"
   ```

## Структура релизных файлов
```
store/
  privacy_policy.html  — политика конфиденциальности
  rustore_listing.md   — описание и чеклист для RuStore
assets/icons/
  icon_512.png         — иконка 512×512 (placeholder, заменить)
  icon_192.png         — для AndroidManifest
  icon_432.png         — adaptive icon foreground
icon.png               — иконка проекта Godot
make_keystore.sh       — скрипт создания release keystore
bump_version.sh        — инкремент версии (patch/minor) перед экспортом
export_presets.cfg     — конфиг экспорта Android
build/                 — папка для APK (в .gitignore)
```

## Сетевая игра
- **LAN**: ENet, одна Wi-Fi сеть, порт 9876. Код не менять.
- **Интернет**: ZeroTier VPN — создаёт виртуальную LAN поверх интернета. Код игры не меняется.
  Приложение: ZeroTier One (Google Play). Сеть создаётся на my.zerotier.com (бесплатно до 25 устройств).
  Игроки используют виртуальные IP (172.x.x.x) вместо реальных.
- Хост: "Создать игру" → показывает IP (ZeroTier или LAN) → ждёт подключений
- Клиент: "Присоединиться" → вводит IP хоста
