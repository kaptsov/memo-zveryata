# Мемо Зверята — Godot 4.x Project

## Структура проекта

```
memo_zveryata/
├── project.godot                    # Конфигурация проекта
├── scenes/                          # .tscn сцены (создать в редакторе)
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd          # Центральный контроллер игры
│   │   ├── network_manager.gd       # Сетевой код (ENet LAN)
│   │   └── audio_manager.gd         # Управление звуком
│   ├── data/
│   │   ├── card_data.gd             # Resource: данные карты зверят
│   │   ├── task_data.gd             # Resource: данные задания
│   │   ├── help_card_data.gd        # Resource: данные карты помощи
│   │   └── game_state.gd            # Полное состояние игры + логика
│   ├── game/
│   │   ├── card.gd                  # Визуал карты (переворот, нажатие)
│   │   └── board.gd                 # Сетка 4×4
│   └── ui/
│       ├── main_menu.gd             # Главное меню
│       ├── lobby.gd                 # Лобби (хост/клиент)
│       ├── game_board.gd            # Игровой экран (оркестратор)
│       ├── hud.gd                   # Верхняя панель (очки, ход)
│       ├── task_panel.gd            # Панель заданий
│       ├── help_panel.gd            # Панель карт помощи
│       ├── results.gd               # Экран результатов
│       ├── encyclopedia.gd          # О зверятах
│       └── settings.gd              # Настройки
├── assets/
│   ├── sprites/
│   │   ├── animals/                 # manul_summer.png, saiga_winter.png...
│   │   ├── backgrounds/             # Фоны экранов
│   │   ├── cards/                   # card_back.png (рубашка)
│   │   ├── help/                    # extra_flip.png, change_animal.png...
│   │   └── ui/                      # Кнопки, панели
│   ├── audio/
│   │   ├── sfx/                     # card_flip.ogg, match_success.ogg...
│   │   └── bgm/                     # bgm_menu.ogg, bgm_game.ogg
│   └── fonts/
└── export/                          # Настройки экспорта Android
```

## Быстрый старт

### 1. Откройте проект в Godot 4.x
- File → Open → выберите папку `memo_zveryata`

### 2. Создайте сцены (.tscn)
Скрипты уже готовы, но сцены нужно создать в редакторе Godot.
Инструкции для каждой сцены:

#### main_menu.tscn
```
Control (скрипт: main_menu.gd)
└── VBox: VBoxContainer
    ├── Title: Label
    └── Buttons: VBoxContainer
        ├── CreateGame: Button ("Создать игру")
        ├── JoinGame: Button ("Присоединиться")
        ├── Settings: Button ("Настройки")
        └── Encyclopedia: Button ("О зверятах")
```

#### lobby.tscn
```
Control (скрипт: lobby.gd)
└── VBox: VBoxContainer
    ├── ModeButtons: VBoxContainer
    │   ├── HostButton: Button ("Создать комнату")
    │   └── JoinButton: Button ("Подключиться")
    ├── HostPanel: VBoxContainer (visible=false)
    │   ├── IPDisplay: Label
    │   ├── WaitingLabel: Label
    │   ├── HelpCardsCheck: CheckBox ("Карты помощи")
    │   └── StartButton: Button ("Начать игру")
    ├── JoinPanel: VBoxContainer (visible=false)
    │   ├── IPInput: LineEdit
    │   ├── ConnectButton: Button ("Подключиться")
    │   └── Status: Label
    └── BackButton: Button ("Назад")
```

#### game_board.tscn
```
Control (скрипт: game_board.gd)
└── VBox: VBoxContainer
    ├── HUD: PanelContainer (скрипт: hud.gd)
    │   └── HBox: HBoxContainer
    │       ├── MyScore: Label
    │       ├── TurnIndicator: Label
    │       ├── OpponentScore: Label
    │       └── HelpDeckCount: Label
    ├── TaskPanel: PanelContainer (скрипт: task_panel.gd)
    │   └── ScrollContainer
    │       └── TaskRow: HBoxContainer
    ├── Board: Control (скрипт: board.gd)
    │   └── GridContainer (columns=4)
    └── HelpPanel: PanelContainer (скрипт: help_panel.gd)
        └── VBox: VBoxContainer
            ├── HelpCountLabel: Label
            ├── HelpRow: HBoxContainer
            └── PassButton: Button ("Передать ход")
```

#### card.tscn (одна карта, инстанцируется 16 раз)
```
Control (скрипт: card.gd, custom_minimum_size: 140×180)
├── CardBack: TextureRect
├── CardFace: TextureRect (visible=false)
├── Highlight: Panel (visible=false)
└── AnimationPlayer
```

#### results.tscn
```
Control (скрипт: results.gd)
└── VBox: VBoxContainer
    ├── Title: Label
    ├── Scores: Label
    └── Buttons: HBoxContainer
        ├── PlayAgain: Button ("Играть ещё")
        └── Menu: Button ("В меню")
```

#### encyclopedia.tscn
```
Control (скрипт: encyclopedia.gd)
└── VBox: VBoxContainer
    ├── Scroll: ScrollContainer
    │   └── AnimalsList: VBoxContainer
    └── BackButton: Button ("Назад")
```

#### settings.tscn
```
Control (скрипт: settings.gd)
└── VBox: VBoxContainer
    ├── BGMRow: HBoxContainer
    │   ├── Label ("Музыка")
    │   └── Slider: HSlider
    ├── SFXRow: HBoxContainer
    │   ├── Label ("Звуки")
    │   └── Slider: HSlider
    └── BackButton: Button ("Назад")
```

### 3. Добавьте placeholder-спрайты
Положите любые PNG-изображения в `assets/sprites/animals/`:
- `manul_summer.png`, `manul_winter.png`
- `saiga_summer.png`, `saiga_winter.png`
- `desman_summer.png`, `desman_winter.png`
- `mandarin_duck_summer.png`, `mandarin_duck_winter.png`

И рубашку карты: `assets/sprites/cards/card_back.png`

### 4. Autoload
Autoload'ы уже прописаны в project.godot:
- `GameManager` → `scripts/autoload/game_manager.gd`
- `NetworkManager` → `scripts/autoload/network_manager.gd`
- `AudioManager` → `scripts/autoload/audio_manager.gd`

### 5. Тестирование
1. Запустите проект (F5)
2. Для теста мультиплеера запустите два экземпляра Godot
3. Один создаёт игру (хост), другой подключается по IP

## Архитектура

```
[UI Screens] ←→ [GameManager] ←→ [NetworkManager]
                      ↕
                 [GameState]
                 ├── Board (16 CardData)
                 ├── Tasks (8 slots × 2)
                 ├── Help Deck
                 └── Players
```

- **GameManager** — единая точка входа для игровой логики
- **NetworkManager** — RPC-вызовы между хостом и клиентом
- **GameState** — чистые данные + правила, без UI-зависимостей
