# Мемо Зверята — Руководство разработчика

## Содержание
1. [Обзор проекта](#1-обзор-проекта)
2. [Структура файлов](#2-структура-файлов)
3. [Архитектура и поток данных](#3-архитектура-и-поток-данных)
4. [Игровая логика](#4-игровая-логика)
5. [Сетевой мультиплеер](#5-сетевой-мультиплеер)
6. [UI-экраны](#6-ui-экраны)
7. [Как добавить нового зверька](#7-как-добавить-нового-зверька)
8. [Экспорт и сборка APK для Android](#8-экспорт-и-сборка-apk-для-android)
9. [Типовые проблемы и решения](#9-типовые-проблемы-и-решения)
10. [Правила кодирования проекта](#10-правила-кодирования-проекта)
11. [История версий](#11-история-версий)

---

## 1. Обзор проекта

**Мемо Зверята** — цифровая адаптация настольной карточной игры на память.
Цель: открывать пары карточек с животными из Красной книги России и выполнять задания.

| Параметр | Значение |
|---|---|
| Движок | Godot 4.3-dev6 |
| Язык | GDScript |
| Платформа | Android (portrait 720×1280) |
| Мультиплеер | ENet LAN (одна Wi-Fi сеть) |
| Игроки | 2–6 (локально и по сети), 1 (соло-режим) |

**Животные (8 видов):** Манул, Сайгак, Выхухоль, Утка-мандаринка,
Ирбис, Белая куропатка, Амурский тигр, Сибирский горный козёл.
**Сезоны:** Лето, Зима
**Поле:** 16 карт (4 животных × 2 сезона × 2 копии) — в обычном режиме.
В соло-режиме размер поля выбирается игроком (2×2 до 4×5), задействуется до 8 животных.

### Игровые режимы

| Режим | Описание |
|---|---|
| Локальная игра | 2–6 игроков на одном устройстве, с картами помощи |
| Без карт помощи | То же, но без карт помощи |
| Колода заданий | Задания выдаются по одному из перемешанной колоды |
| Соло игра | Один игрок, выбор сложности (4–20 карт), фаза запоминания |
| Сетевая игра | 2–6 игроков по LAN Wi-Fi или через ZeroTier VPN (хост + клиенты) |

---

## 2. Структура файлов

```
memo_zveryata_godot_project/
│
├── project.godot              # Конфигурация движка. Здесь прописаны autoload-синглтоны.
├── export_presets.cfg         # Настройки экспорта Android (разрешения, путь к APK и т.д.)
├── make_keystore.sh           # Скрипт для создания release-keystore перед публикацией
├── icon.png                   # Иконка проекта в редакторе Godot
├── DEVELOPER_GUIDE.md         # Этот файл
│
├── scenes/                    # Сцены (.tscn) — UI-дерево узлов
│   ├── main_menu.tscn         # Главное меню
│   ├── lobby.tscn             # Лобби (создать/присоединиться по сети)
│   ├── game_board.tscn        # Игровое поле
│   ├── card.tscn              # Одна карта (инстанцируется N раз по размеру поля)
│   ├── results.tscn           # Экран результатов
│   ├── encyclopedia.tscn      # О зверятах
│   └── settings.tscn          # Настройки громкости
│
├── scripts/
│   ├── autoload/              # Синглтоны — доступны из любого скрипта без @onready
│   │   ├── game_manager.gd    # ГЛАВНЫЙ: игровая логика, сигналы, координация
│   │   ├── network_manager.gd # Сетевой код: создание сервера, RPC между игроками
│   │   ├── audio_manager.gd   # Музыка и звуки
│   │   └── debug_log.gd       # Логирование в файл (user://debug.log) и консоль
│   │
│   ├── data/                  # Чистые данные — без зависимостей от UI
│   │   ├── card_data.gd       # Данные одной карты: животное, сезон, ID
│   │   ├── task_data.gd       # Данные задания: тип (simple/hard), очки, проверка совпадения
│   │   ├── help_card_data.gd  # Данные карты помощи: тип (+1 карта / сменить зверька / фон)
│   │   └── game_state.gd      # ВСЁ состояние игры: поле, задания, игроки, логика хода
│   │
│   ├── game/
│   │   ├── board.gd           # Управление сеткой карт: создание, переворот, подсветка
│   │   │                      # Поддерживает динамический размер (cols×rows)
│   │   └── card.gd            # Визуал одной карты: анимация переворота, спрайт
│   │
│   └── ui/
│       ├── main_menu.gd       # Главное меню: кнопки, диалоги (число игроков, сложность),
│       │                      # версия сборки (BUILD_VERSION), правила, соло-режим
│       ├── lobby.gd           # Лобби: создать сервер / подключиться / ждать игроков
│       ├── game_board.gd      # Оркестратор игрового экрана: board, hud, task_panel, help_panel
│       │                      # Фаза запоминания карт в соло-режиме
│       ├── hud.gd             # Верхняя панель: очки всех игроков, чей ход, колода помощи
│       ├── task_panel.gd      # Панель заданий: карточки слотов или режим колоды
│       ├── help_panel.gd      # Карты помощи текущего игрока + кнопка "Завершить ход"
│       ├── results.gd         # Экран победителя и счёта
│       ├── encyclopedia.gd    # О зверятах: сетка 2×2, переворот по нажатию,
│       │                      # динамический размер шрифта под экран
│       └── settings.gd        # Слайдеры громкости музыки и звуков
│
├── assets/
│   ├── sprites/
│   │   ├── animals/           # PNG 512×512: manul_summer.png, manul_winter.png, ...
│   │   ├── cards/             # card_back.png — рубашка карты
│   │   ├── help/              # extra_flip.png, change_animal.png, change_season.png
│   │   └── ui/                # Кнопки, фоны (пока не используются)
│   ├── audio/
│   │   ├── sfx/               # Звуки: card_flip.wav, match_success.wav, match_fail.wav, ...
│   │   └── bgm/               # Музыка: bgm_menu.wav, bgm_game.wav
│   ├── fonts/                 # Шрифты (если добавлены)
│   └── icons/
│       ├── icon_512.png       # Иконка приложения 512×512 для RuStore
│       ├── icon_192.png       # Иконка для AndroidManifest
│       └── icon_432.png       # Adaptive icon foreground
│
└── store/
	├── privacy_policy.html    # Политика конфиденциальности (нужна для публикации)
	└── rustore_listing.md     # Описание и чеклист для публикации в RuStore
```

---

## 3. Архитектура и поток данных

```
[Экраны UI]  <--сигналы-->  [GameManager]  <-->  [NetworkManager]
								  |
							 [GameState]
							 ├── board[]           (N CardData, где N = cols*rows)
							 ├── board_cols         (число столбцов сетки)
							 ├── is_solo            (флаг одиночного режима)
							 ├── task_slots[]       (8 слотов simple+hard, обычный режим)
							 ├── task_deck[]        (режим колоды / соло)
							 ├── help_deck[]        (карты помощи)
							 └── players{}          (счёт, карты помощи каждого)
```

### Autoload-синглтоны (глобальные объекты)

Прописаны в `project.godot`. Доступны **из любого скрипта** по имени:

| Имя | Файл | Назначение |
|---|---|---|
| `GameManager` | `scripts/autoload/game_manager.gd` | Центральный контроллер. Хранит состояние, испускает сигналы об изменениях. |
| `NetworkManager` | `scripts/autoload/network_manager.gd` | ENet-сервер/клиент. RPC между игроками. |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | Воспроизведение музыки и звуков. |
| `DebugLog` | `scripts/autoload/debug_log.gd` | Логи в `user://debug.log`. На Android: `/data/data/ru.memo.zveryata/files/debug.log` |

**Важно:** `NetworkManager` загружается раньше `DebugLog` в порядке autoload.
Поэтому в `network_manager.gd` нельзя вызывать `DebugLog.*()` — использовать `print()`.

### Главные сигналы GameManager

UI-экраны **подписываются** на эти сигналы в `_ready()` и **отписываются** в `_exit_tree()`:

| Сигнал | Когда испускается | Кто слушает |
|---|---|---|
| `card_flipped(index, card_data)` | Карта перевёрнута | `game_board.gd` → анимация |
| `cards_closed(indices)` | Карты закрываются в конце хода | `game_board.gd` → анимация закрытия |
| `task_completed(player_id, task)` | Задание выполнено | `task_panel.gd`, `hud.gd` |
| `hard_task_revealed(slot_i, task)` | Открылось сложное задание | `task_panel.gd` → обновить слот |
| `turn_changed(player_id)` | Смена хода | `hud.gd`, `help_panel.gd` |
| `turn_failed()` | Ход провален (нет совпадения) | `game_board.gd` → shake-анимация |
| `waiting_for_player()` | Ожидание действия игрока (помощь?) | `help_panel.gd` → показать кнопку |
| `help_card_used(pid, card)` | Карта помощи применена | `game_board.gd` → обновить визуал |
| `game_over_signal(winner, scores)` | Игра завершена | `game_board.gd` → переход к results |
| `score_updated(pid, score)` | Очки изменились | `hud.gd` |
| `game_started_signal()` | Игра начата | `lobby.gd` → переход к game_board |
| `state_synced()` | Получено сетевое состояние | `game_board.gd` → перестроить UI |
| `deck_task_changed(task)` | В режиме колоды: сменилось задание | `task_panel.gd` |

---

## 4. Игровая логика

### Файлы данных (scripts/data/)

**Важно:** в этих файлах **нельзя** использовать `class_name` — Godot 4.3-dev6 не резолвит их в static-методах. Используй `preload()` / `load()`.

#### card_data.gd
```
AnimalType: MANUL=0, SAIGA=1, DESMAN=2, MANDARIN_DUCK=3,
			SNOW_LEOPARD=4, PTARMIGAN=5, AMUR_TIGER=6, SIBERIAN_IBEX=7
Season: SUMMER=0, WINTER=1
Поля: card_id, animal_type, season, copy ("A"/"B")
Методы: get_animal_name(), get_animal_name_ru(), get_sprite_path(), to_dict(), from_dict()
Спрайты: assets/sprites/animals/{name}_{season}.png, всегда 512×512 PNG
```

#### task_data.gd
```
TaskType: SIMPLE=0 (2 одинаковых), HARD=1 (4 разных одного сезона)
Поля: task_id, task_type, points, required_animal, required_season, is_active, is_completed
Методы: check_simple(cards), check_hard(cards), to_dict(), from_dict()
```

#### help_card_data.gd
```
HelpType: EXTRA_FLIP=0, CHANGE_ANIMAL=1, CHANGE_SEASON=2
```

#### game_state.gd — центральное хранилище состояния

Создаётся в `GameManager` при старте игры. Содержит:
- `board[]` — CardData в случайном порядке (16 в обычном режиме, N в соло)
- `board_cols` — число столбцов сетки (4 в обычном, переменное в соло)
- `is_solo` — флаг одиночного режима
- `board_flipped[]` — bool для каждой карты (открыта ли постоянно)
- `flipped_this_turn[]` — индексы открытых в этом ходе
- `task_slots[]` — 8 слотов `{simple, hard}` (обычный режим)
- `task_deck[]` и `deck_current_task` — режим колоды / соло
- `players{}` — словарь `{pid: {score, help_cards, tasks_completed}}`
- `turn_modifications[]` — временные изменения карт (от карт помощи)

**Ключевые методы game_state.gd:**

| Метод | Что делает |
|---|---|
| `setup(player_ids, with_help)` | Инициализация обычной игры 4×4 |
| `setup_deck_mode(player_ids, with_help)` | Инициализация режима колоды 4×4 |
| `setup_solo(cols, rows)` | Инициализация соло-игры: переменная сетка, задания из колоды |
| `_create_board_for_size(num_pairs)` | Генерация доски: первые 4 животных (лето→зима) для ≤8 пар, новые 4 для >8 пар. Без повторов — max 16 уникальных пар. |
| `_create_solo_tasks()` | Задания для соло: по одному SIMPLE на каждую уникальную пару на доске |
| `try_flip_card(index)` | Попытка открыть карту. Возвращает false если уже открыта или лимит исчерпан |
| `get_flipped_cards()` | Получить открытые карты С учётом turn_modifications |
| `check_simple_tasks()` | Проверить выполнение простых заданий |
| `check_hard_tasks()` | Проверить выполнение сложных заданий |
| `complete_task(task)` | Засчитать задание, начислить очки, активировать hard |
| `_try_activate_hard(slot)` | Активировать hard только если нет другого active того же сезона |
| `_activate_next_pending_hard(season)` | После выполнения hard — активировать следующий отложенный |
| `use_help_card(pid, card, target, animal)` | Применить карту помощи |
| `end_turn()` | Завершить ход: закрыть карты, выдать карту помощи, передать ход |
| `to_dict() / from_dict()` | Сериализация для передачи по сети |

### Поток одного хода

```
Игрок тапает карту
	→ game_board.gd: _on_card_tapped()
	→ GameManager.on_card_tapped()
		→ _process_flip(): state.try_flip_card(), emit card_flipped
		→ _check_after_flip():
			n=2: проверить simple → если да: _complete_and_end()
							   → если нет и есть hard-задание: ждём ещё 2 карты
							   → если нет и нет hard: провал → _enter_awaiting_state()
			n=4: проверить hard → если да: _complete_and_end()
							   → если нет: провал → _enter_awaiting_state()

_enter_awaiting_state():
	awaiting_player_action = true → emit waiting_for_player
	→ help_panel показывает кнопку "Завершить ход" и доступные карты помощи

_complete_and_end(task):
	state.complete_task() → emit task_completed, score_updated
	_do_end_turn():
		state.end_turn() → возможно выдаёт карту помощи
		emit cards_closed, turn_changed
		(по сети: broadcast_turn_changed)
```

### Режим "Колода заданий"

Вместо 8 фиксированных слотов — колода из 20 заданий (8 simple + 12 hard), перемешанная. Текущее задание показывается одно, при выполнении — следующее из колоды.

### Соло-режим

Один игрок, задания из колоды (только SIMPLE), без карт помощи.

**Поток соло-игры:**
```
Главное меню → "Соло игра" → диалог сложности → GameManager.start_solo_game(cols, rows)
	→ state.setup_solo(cols, rows):
		- _create_board_for_size(cols*rows/2)  # генерация пар
		- _create_solo_tasks()                  # задания по картам на доске
		- _create_players([1])
	→ game_board.tscn открывается
	→ _setup_ui() → board.setup_board(..., cols, face_up=true)
	→ _show_memorization_overlay()
		Игрок видит все карты открытыми → нажимает "Играть!"
		→ board.flip_all_down() → игра начинается
```

**Выбор сложности и соответствие сетки:**

| Кнопка UI | cols | rows | Карт | Пар | Животные |
|---|---|---|---|---|---|
| 2×2 | 2 | 2 | 4 | 2 | Манул, Сайгак (лето) |
| 3×4 | 3 | 4 | 12 | 6 | Оригинальные 4 (лето) + 2 зимних |
| 4×4 | 4 | 4 | 16 | 8 | Все 4 оригинальных × 2 сезона |
| 4×5 | 4 | 5 | 20 | 10 | Все 8 оригинальных + 2 новых (лето) |

Максимум уникальных пар: 8 животных × 2 сезона = 16. Режим 6×6 (18 пар) невозможен без дублей — удалён.

---

## 5. Сетевой мультиплеер

### Принцип работы

- **Хост (сервер)** — peer_id = 1. Вся игровая логика выполняется ТОЛЬКО на хосте.
- **Клиент** — получает обновления через RPC, только отображает данные.
- Транспорт: **ENet**, порт 9876.
- **LAN**: обычная Wi-Fi сеть, IP из диапазона 192.168.x.x.
- **Интернет**: [ZeroTier VPN](https://www.zerotier.com/) — виртуальная LAN поверх интернета.
  Код игры не меняется. Игроки используют виртуальный IP (172.x.x.x) как будто в одной сети.
  Установка: ZeroTier One из Google Play, сеть создаётся на my.zerotier.com (бесплатно до 25 устройств).

### Поток сетевого хода

```
Клиент тапает карту
	→ NetworkManager.send_flip_request(index)  [RPC → хост]
	→ Хост: handle_remote_flip() → _process_flip()
		→ emit card_flipped на хосте (хост видит переворот)
		→ broadcast_card_flipped() [RPC → все клиенты]
		→ Клиент: handle_remote_card_flipped() → emit card_flipped

По завершении хода хост вызывает:
	broadcast_turn_changed() → handle_remote_turn_changed() на клиентах
	broadcast_task_completed() → _rpc_task_completed() на клиентах
	broadcast_game_over() → _rpc_game_over() на клиентах
```

### Важные правила сети

- `@rpc("authority", "reliable")` — вызов только от хоста ко всем клиентам
- `@rpc("any_peer", "reliable")` — вызов от клиента к хосту
- Все RPC-методы начинаются с `_rpc_` в network_manager.gd
- Весь state сериализуется через `to_dict()` / `from_dict()`
- В `network_manager.gd` **нельзя** вызывать `DebugLog` — использовать `print()`
  (причина: порядок загрузки autoload, NetworkManager грузится раньше DebugLog)

### Android: обязательные разрешения

В Godot Editor: **Project → Export → Android → Options → Permissions** включить:
- `Internet`
- `Access Network State`
- `Access Wifi State`

**Важно:** Godot перезаписывает `export_presets.cfg` при открытии проекта.
Всегда устанавливай разрешения через UI редактора, не через ручное редактирование файла.

---

## 6. UI-экраны

### Навигация между сценами

```
main_menu.tscn
	├── → game_board.tscn  (Локальная / Без помощи / Колода / Соло — через GameManager)
	├── → lobby.tscn       (Создать игру / Присоединиться)
	├── → encyclopedia.tscn
	└── → settings.tscn

lobby.tscn
	└── → game_board.tscn  (после start_new_game)

game_board.tscn
	└── → results.tscn     (после game_over)

results.tscn
	├── → game_board.tscn  (Играть ещё)
	└── → main_menu.tscn   (В меню)
```

### Главное меню (main_menu.gd)

Кнопки из .tscn-сцены дополняются динамически создаваемыми кнопками в `_ready()`.
Константа `BUILD_VERSION` определяет номер версии, отображаемый в левом верхнем углу.

**Порядок кнопок:**
1. Локальная игра
2. Без карт помощи
3. **Соло игра** ← добавлена динамически
4. Колода заданий
5. **Правила игры** ← добавлена динамически (popup с текстом правил)
6. **Обучение** ← добавлена динамически (disabled, TODO для монетизации)
7. Создать игру
8. Присоединиться
9. Настройки
10. О зверятах
11. Выход

**Важно о динамических кнопках:**
Динамически добавляемые кнопки должны иметь `size_flags_horizontal = SIZE_SHRINK_CENTER`,
иначе они растягиваются на всю ширину VBoxContainer. Размер синхронизируется с
существующими кнопками через `call_deferred("_sync_dynamic_buttons_size", ...)` — после
того как layout рассчитает реальные размеры.

### Правила подключения сигналов в UI

В каждом UI-скрипте:
- **Подключать** в `_ready()` через `_safe_connect()` (защита от дублей)
- **Отключать** в `_exit_tree()` через `_safe_disconnect()`

Пример:
```gdscript
func _ready():
	_safe_connect(GameManager.turn_changed, _on_turn_changed)

func _exit_tree():
	_safe_disconnect(GameManager.turn_changed, _on_turn_changed)

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
```

### game_board.gd — оркестратор

Главный экран игры. Содержит:
- `board` — узел Board (сетка карт, размер определяется GameState.board_cols)
- `hud` — верхняя панель
- `task_panel` — панель заданий
- `help_panel` — панель карт помощи

Управляет:
- Режимом выбора карты для помощи (`help_select_mode`)
- Попапом выбора животного (`_show_animal_picker`)
- Анимацией закрытия карт при провале хода
- Фазой запоминания в соло-режиме (`_show_memorization_overlay`)
- Отключением соперника (popup с кнопкой выхода)

### board.gd — сетка карт

Поддерживает динамический размер:
```gdscript
board.setup_board(board_data, cols, face_up)
# cols    — число столбцов (по умолчанию 4)
# face_up — показать карты лицом вверх (используется в соло при запоминании)
```

Число строк вычисляется автоматически: `rows = ceil(board_data.size() / cols)`.

### encyclopedia.gd — О зверятах

8 карточек (по числу животных) в сетке 2 колонки с вертикальной прокруткой.
Каждая карточка переворачивается по нажатию: картинка ↔ текст с фактами.

**Анимация переворота:** через `await tween.finished` (не `tween_callback`).
Причина: в Godot 4.3-dev6 `tween_callback` с лямбдами нестабилен.
Флаг `_flipping[index]` блокирует повторные тапы во время анимации.

**Размеры шрифтов и карточки** вычисляются в `_compute_font_sizes()` пропорционально
ширине viewport. Высота карточки: `card_w * 1.25` (как у игровых карт).
Формула шрифта: `font_size = clamp(card_width * коэффициент, min, max)`.

**TextureRect:** использует `expand_mode = EXPAND_IGNORE_SIZE` — обязательно для спрайтов
512×512 и крупнее, иначе контрол принимает натуральный размер текстуры и выламывает сетку.
`stretch_mode = STRETCH_KEEP_ASPECT_CENTERED` вписывает изображение по ширине и центрирует по вертикали.

**ScrollContainer + тап:** дочерние карточки имеют `mouse_filter = MOUSE_FILTER_PASS`
и флаг `_dragging[index]` чтобы различать свайп (скролл) и тап (переворот).

---

## 7. Как добавить нового зверька

В проекте уже 8 животных. Максимум без повторов в соло-режиме — 16 уникальных пар
(8 × 2 сезона). Если добавить 9-е животное, нужно также расширить соло-режим.

### Шаг 1: Спрайты (512×512 PNG)
```
assets/sprites/animals/новый_зверёк_summer.png
assets/sprites/animals/новый_зверёк_winter.png
```
Если исходник больше 512×512: `sips -z 512 512 файл.png`

### Шаг 2: card_data.gd
```gdscript
enum AnimalType { MANUL, SAIGA, DESMAN, MANDARIN_DUCK,
				  SNOW_LEOPARD, PTARMIGAN, AMUR_TIGER, SIBERIAN_IBEX,
				  НОВЫЙ_ЗВЕРЁК }   # добавить в конец — индекс = 8

# Добавить в get_animal_name() и get_animal_name_ru():
AnimalType.НОВЫЙ_ЗВЕРЁК: return "новый_зверёк"
```

### Шаг 3: game_state.gd — _create_board_for_size()
Добавь новое животное в массив `extended` (или создай `extended2`).
Обновлённый порядок определяет, в каких режимах оно появится.

### Шаг 4: encyclopedia.gd
Добавь запись в `ANIMAL_INFO`:
```gdscript
{ "name": "Имя", "latin": "Lateinisch", "description": "...", "sprite": "новый_зверёк" }
```

### Шаг 5: game_board.gd — _show_animal_picker()
```gdscript
const ANIMAL_NAMES = ["Манул", "Сайгак", "Выхухоль", "Мандаринка",
					  "Ирбис", "Куропатка", "Тигр", "Козёл", "Новый зверёк"]
```

---

## 8. Экспорт и сборка APK для Android

### Предварительные требования
- Godot 4.x с Android export template
- Android SDK + JDK (настроены в Editor → Editor Settings → Export → Android)
- Для release: подписанный keystore

### Debug APK (для тестирования)
1. Project → Export → Android
2. Export With Debug
3. APK появится в `build/MemoZveryata.apk`

### Release APK (для публикации)
1. Создать keystore: `bash make_keystore.sh`
2. В export presets указать путь к keystore + пароли
3. Project → Export → Android → Export Release

### Обязательно перед каждым экспортом
Проверить в Project → Export → Android → Options → Permissions:
- [x] Internet
- [x] Access Network State
- [x] Access Wifi State

### Установка на устройство через adb
```bash
adb install build/MemoZveryata.apk
```

### Просмотр логов с устройства
```bash
adb logcat -s godot
# Или читать файл напрямую:
adb shell cat /data/data/ru.memo.zveryata/files/debug.log
```

### Версионирование перед каждым экспортом
```bash
cd ~/memo_zveryata_godot_project
./bump_version.sh          # patch: v0.4.1 → v0.4.2 (каждый билд)
./bump_version.sh --minor  # minor: v0.4.x → v0.5.0 (крупный релиз)
```
Скрипт обновляет `BUILD_VERSION` в `main_menu.gd` и `version/code` в `export_presets.cfg`.
Версия отображается в левом верхнем углу главного меню (z_index=10, поверх VBox).

---

## 9. Типовые проблемы и решения

### err=20 "Can't create" при создании сервера
**Причина:** Не включено разрешение `INTERNET` в Android export.
**Решение:** Project → Export → Android → Permissions → Internet = true.
**Важно:** Godot перезаписывает `export_presets.cfg` при открытии проекта. Настраивать только через UI.

### Экран зависает при создании UI с TextureRect
**Причина:** `expand_mode = EXPAND_FIT_WIDTH` + `size_flags = SIZE_EXPAND_FILL` создают бесконечный цикл пересчёта layout.
**Решение:** Не устанавливать `expand_mode` (по умолчанию 0 = KEEP_SIZE). Использовать `STRETCH_KEEP_ASPECT_CENTERED` и задавать размер через `custom_minimum_size`.

### Свайп не работает в ScrollContainer
**Причина:** Дочерние `PanelContainer` имеют `mouse_filter = STOP` и перехватывают касания.
**Решение:** Установить `mouse_filter = MOUSE_FILTER_PASS` на все дочерние контейнеры внутри ScrollContainer.

### Ошибки class_name в scripts/data/
**Причина:** Godot 4.3-dev6 не резолвит `class_name` при использовании в static-методах.
**Решение:** Никогда не используй `class_name` в папке `scripts/data/`. Вместо этого: `const CD = preload("res://scripts/data/card_data.gd")`.

### Сигнал подключается дважды
**Причина:** Сцена перезагружается, `_ready()` вызывается снова.
**Решение:** Всегда использовать `_safe_connect()` (проверяет `is_connected` перед connect) и `_safe_disconnect()` в `_exit_tree()`.

### Карты помощи не обновляют визуал
**Причина:** `turn_modifications` изменяют данные для проверки заданий, но текстура на карте не обновляется автоматически.
**Решение:** После `help_card_used` сигнала вызывать `board.refresh_card(idx, modified_data)`.

### Анимация переворота карты в энциклопедии "дёргается"
**Причина:** `tween_callback` с лямбдой захватывает переменную по ссылке. В Godot 4.3-dev6 значение может измениться к моменту выполнения callback.
**Решение:** Использовать `await tween.finished` вместо `tween_callback`. Флаг `_flipping[index]` блокирует повторные тапы во время анимации.

### Динамически добавленные кнопки растягиваются на всю ширину
**Причина:** В VBoxContainer кнопки по умолчанию имеют `size_flags_horizontal = SIZE_FILL`.
**Решение:** Установить `size_flags_horizontal = SIZE_SHRINK_CENTER`. Синхронизировать размер с существующими кнопками через `call_deferred`.

### DebugLog не доступен в network_manager.gd
**Причина:** Порядок загрузки autoload — NetworkManager загружается раньше DebugLog.
**Решение:** Использовать `print("[NET] ...")` вместо `DebugLog.*()` в network_manager.gd.

### TextureRect с крупной текстурой выламывает layout
**Причина:** По умолчанию `expand_mode = EXPAND_KEEP_SIZE` — TextureRect требует минимум
натурального размера текстуры. Для 1280×1280 это 1280px, что рвёт сетку.
**Решение:** `tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE` — TextureRect может быть
меньше текстуры. `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED` управляет отображением.

### Enum-значения TextureRect в Godot 4.3-dev6
Рабочие: `STRETCH_KEEP_ASPECT_CENTERED`, `STRETCH_KEEP_ASPECT_COVERED`, `EXPAND_IGNORE_SIZE`
Несуществующие (вызывают parse error): `STRETCH_KEEP_ASPECT_FIT`, `EXPAND_IGNORE`

---

## 10. Правила кодирования проекта

### Именование
- Файлы: `snake_case.gd`
- Переменные: `snake_case`
- Константы: `UPPER_CASE`
- Сигналы: `snake_case` (без префикса `on_`)
- Методы-обработчики сигналов: `_on_имя_сигнала()`
- Приватные методы: `_метод()`

### Структура скрипта
```gdscript
extends ТипУзла

## Краткое описание скрипта

# --- Сигналы ---
signal мой_сигнал(param)

# --- Константы ---
const КОНСТАНТА = значение

# --- Переменные ---
@onready var узел = $Путь/К/Узлу
var переменная: Тип = значение

# --- Lifecycle ---
func _ready() -> void: ...
func _exit_tree() -> void: ...

# --- Публичный API ---
func публичный_метод() -> void: ...

# --- Приватные методы ---
func _приватный_метод() -> void: ...
```

### Сигналы
- Подключать в `_ready()`, отключать в `_exit_tree()`
- Использовать `_safe_connect()` / `_safe_disconnect()` (см. lobby.gd как образец)

### Лямбды в Godot 4.3-dev6
- `Array.filter(func(x): ...)` — **нестабильно**, использовать явный `for`-цикл
- Лямбды в `tween_callback` — **нестабильно**, использовать `await tween.finished`
- Лямбды в `Button.pressed.connect(func(): ...)` — стабильно, допустимо
- `.bind()` для передачи аргументов в Callable — стабильно

### Сеть
- Вся логика только на хосте (`if is_host: ...`)
- Клиент только отображает, никогда не изменяет состояние напрямую
- Все изменения состояния идут через `to_dict()` / `from_dict()` для RPC

### Производительность на Android
- Не использовать `load()` в `_process()` — только в `_ready()` или по событию
- Не устанавливать `expand_mode` в TextureRect без крайней необходимости
- Спрайты: 512×512 PNG, формат RGBA8

### Логирование
```gdscript
DebugLog.log_info("Сообщение")       # INFO
DebugLog.log_warn("Предупреждение")  # WARN
DebugLog.log_error("Ошибка")         # ERROR
# В network_manager.gd вместо DebugLog:
print("[NET] Сообщение")
```
Лог пишется в `user://debug.log`. В лобби есть кнопка "Скопировать лог" для отладки на устройстве.

---

## 11. История версий

| Версия | Что изменилось |
|---|---|
| v0.1 | Локальная игра 2 игрока. Полная механика: простые/сложные задания, карты помощи. Спрайты зверят. |
| v0.2 | Мультиплеер по LAN (2–6 игроков). Режим "Колода заданий". Карты заданий с мини-картинками. Выбор числа игроков (2–6). HUD для N игроков. |
| v0.3 | Исправления: анимация карт помощи (пикер животного), дедупликация заданий. Энциклопедия 2×2 с переворотом карточек. Скроллируемые задания (свайп). Документация разработчика. |
| v0.4.0 | Соло-режим (4 уровня сложности, фаза запоминания). Кнопки "Правила игры" и "Обучение" (placeholder). Версия сборки на главном экране. Динамические шрифты в энциклопедии. Расширенные описания зверят для детей. |
| v0.4.x | 8 животных (добавлены ирбис, куропатка, амурский тигр, горный козёл). Энциклопедия: 8 карточек, вертикальная прокрутка, исправлен layout TextureRect (EXPAND_IGNORE_SIZE). Соло-режим: упорядоченный набор пар без повторов, убран невозможный режим 6×6. Автоинкремент версии (bump_version.sh). Мультиплеер по интернету через ZeroTier. |
| v0.5.0 | Бесконечный соло-режим с таблицей лидеров. Игра не заканчивается при завершении колоды — карты перемешиваются и начинается новый раунд. Конец игры при первой ошибке. Таблица лидеров на сервере (sweateratops.ru, Flask+PostgreSQL). Новый autoload LeaderboardManager (HTTP-клиент). Имя игрока сохраняется в user://player_name.dat. HUD в соло: крупный счёт, скрыт П2 и колода помощи. |

**Как обновить версию перед релизом:**
```bash
./bump_version.sh          # patch-версия
./bump_version.sh --minor  # minor-версия
# затем экспорт в Godot
```
