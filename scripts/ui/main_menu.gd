extends Control

## MainMenu.gd — Главное меню игры.
## BUILD_VERSION отображается в левом верхнем углу (z_index=10, поверх VBox).
## Перед каждым экспортом APK запускать bump_version.sh — он обновляет BUILD_VERSION
## и version/code в export_presets.cfg автоматически.
##
## Динамические кнопки (добавляются в _ready(), после кнопок из .tscn):
##   - Соло игра   → _show_solo_dialog()
##   - Правила игры → _show_rules_popup()
##   - Обучение    (disabled, placeholder)
## Все динамические кнопки: SIZE_SHRINK_CENTER + _sync_dynamic_buttons_size() через call_deferred.

const BUILD_VERSION: String = "v0.4.1"

@onready var local_button: Button = $VBox/Buttons/LocalGame
@onready var local_no_help_button: Button = $VBox/Buttons/LocalNoHelp
@onready var create_button: Button = $VBox/Buttons/CreateGame
@onready var join_button: Button = $VBox/Buttons/JoinGame
@onready var deck_mode_button: Button = $VBox/Buttons/DeckMode
@onready var settings_button: Button = $VBox/Buttons/Settings
@onready var encyclopedia_button: Button = $VBox/Buttons/Encyclopedia
@onready var quit_button: Button = $VBox/Buttons/QuitGame

var _pending_mode: String = ""

func _ready() -> void:
	local_button.pressed.connect(func(): _show_player_count_dialog("normal"))
	local_no_help_button.pressed.connect(func(): _show_player_count_dialog("no_help"))
	deck_mode_button.pressed.connect(func(): _show_player_count_dialog("deck"))
	create_button.pressed.connect(func():
		GameManager.set_meta("lobby_mode", "host")
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	)
	join_button.pressed.connect(func():
		GameManager.set_meta("lobby_mode", "join")
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	)
	settings_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/settings.tscn")
	)
	encyclopedia_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/encyclopedia.tscn")
	)
	quit_button.pressed.connect(func():
		get_tree().quit()
	)
	AudioManager.play_bgm("bgm_menu")

	# --- Версия сборки (верхний левый угол) ---
	var version_lbl = Label.new()
	version_lbl.text = BUILD_VERSION
	version_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	version_lbl.position = Vector2(8, 4)
	version_lbl.custom_minimum_size = Vector2(60, 20)
	version_lbl.z_index = 10
	version_lbl.add_theme_font_size_override("font_size", 13)
	version_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	version_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(version_lbl)

	# --- Динамически добавляем кнопки между DeckMode и CreateGame ---
	var buttons_container = $VBox/Buttons

	var solo_btn = Button.new()
	solo_btn.text = "Соло игра"
	solo_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons_container.add_child(solo_btn)
	buttons_container.move_child(solo_btn, local_no_help_button.get_index() + 1)
	solo_btn.pressed.connect(_show_solo_dialog)

	var rules_btn = Button.new()
	rules_btn.text = "Правила игры"
	rules_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons_container.add_child(rules_btn)
	buttons_container.move_child(rules_btn, deck_mode_button.get_index() + 1)
	rules_btn.pressed.connect(_show_rules_popup)

	var training_btn = Button.new()
	training_btn.text = "Обучение"
	training_btn.disabled = true  # TODO: реализовать позже (монетизация)
	training_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons_container.add_child(training_btn)
	buttons_container.move_child(training_btn, rules_btn.get_index() + 1)

	# Синхронизировать размер новых кнопок с существующими после расчёта лэйаута
	call_deferred("_sync_dynamic_buttons_size", [solo_btn, rules_btn, training_btn])

func _sync_dynamic_buttons_size(btns: Array) -> void:
	var ref_size = local_button.size
	if ref_size.x > 0:
		for btn in btns:
			btn.custom_minimum_size = ref_size

func _show_player_count_dialog(mode: String) -> void:
	_pending_mode = mode
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
	add_child(overlay)
	var popup = PanelContainer.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.z_index = 11
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	popup.add_child(vbox)
	var lbl = Label.new()
	lbl.text = "Сколько игроков?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(lbl)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	for n in [2, 3, 4, 5, 6]:
		var btn = Button.new()
		btn.text = str(n)
		btn.custom_minimum_size = Vector2(60, 60)
		btn.add_theme_font_size_override("font_size", 22)
		var count = n
		btn.pressed.connect(func():
			overlay.queue_free()
			popup.queue_free()
			_start_local(count)
		)
		hbox.add_child(btn)
	var cancel = Button.new()
	cancel.text = "Отмена"
	cancel.pressed.connect(func():
		overlay.queue_free()
		popup.queue_free()
	)
	vbox.add_child(cancel)
	add_child(popup)

func _start_local(count: int) -> void:
	match _pending_mode:
		"normal":
			GameManager.start_local_game(count, true)
		"no_help":
			GameManager.start_local_game(count, false)
		"deck":
			GameManager.start_local_game_deck(count, true)
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

## Диалог выбора сложности для соло-игры
func _show_solo_dialog() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
	add_child(overlay)

	var popup = PanelContainer.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.z_index = 11
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "Выбери сложность"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(lbl)

	# (название, cols, rows)  — четное cols*rows для пар
	var difficulties = [
		["2×2  (4 карты)", 2, 2],
		["3×4  (12 карт)", 3, 4],
		["4×4  (16 карт)", 4, 4],
		["4×5  (20 карт)", 4, 5],
	]
	for d in difficulties:
		var btn = Button.new()
		btn.text = d[0]
		btn.add_theme_font_size_override("font_size", 18)
		var c = d[1]
		var r = d[2]
		btn.pressed.connect(func():
			overlay.queue_free()
			popup.queue_free()
			GameManager.start_solo_game(c, r)
			get_tree().change_scene_to_file("res://scenes/game_board.tscn")
		)
		vbox.add_child(btn)

	var cancel = Button.new()
	cancel.text = "Отмена"
	cancel.pressed.connect(func():
		overlay.queue_free()
		popup.queue_free()
	)
	vbox.add_child(cancel)
	add_child(popup)

## Экран правил игры
func _show_rules_popup() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
	add_child(overlay)

	var popup = PanelContainer.new()
	popup.anchor_left = 0.05
	popup.anchor_right = 0.95
	popup.anchor_top = 0.05
	popup.anchor_bottom = 0.95
	popup.z_index = 11
	add_child(popup)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)

	var title = Label.new()
	title.text = "Правила игры"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var text = Label.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = """🃏 ПОЛЕ
16 карт с зверятами из Красной книги:
4 вида (Манул, Сайгак, Выхухоль, Мандаринка)
× 2 сезона (Лето, Зима) × 2 копии каждой.

🎯 ЗАДАНИЯ
• Простое (★, 1 очко): найди пару одинаковых карт — одно животное и один сезон.
• Сложное (★★, 2 очка): найди всех 4 животных одного сезона.
  Открывается после выполнения простого задания того же сезона.

▶️ ХОД
1. Открой 2 карты. Если они совпадают с простым заданием — задание выполнено!
2. После выполнения простого открывается сложное: можно открыть ещё 2 карты (итого 4).
3. Если совпадения нет — используй карту помощи или завершай ход.

🃏 КАРТЫ ПОМОЩИ
Выдаются за проигранные ходы (без совпадения):
• +1 карта — открой ещё одну карту в этом ходу.
• Сменить зверька — замени животное на открытой карте.
• Сменить фон — смени сезон на открытой карте.

🏆 КОНЕЦ ИГРЫ
Игра заканчивается, когда выполнены все задания или закончились карты помощи.
Побеждает игрок с наибольшим количеством очков."""
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.add_theme_font_size_override("font_size", 15)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(text)

	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func():
		overlay.queue_free()
		popup.queue_free()
	)
	vbox.add_child(close_btn)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
