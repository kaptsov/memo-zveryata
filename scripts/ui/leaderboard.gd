extends Control

## leaderboard.gd — Экран таблицы лидеров (соло-режим).
## Получает solo_score и solo_difficulty из GameManager.get_meta().
## Запрашивает топ-10 с сервера, отправляет результат.
##
## Сцена (создать в редакторе): scenes/leaderboard.tscn
## Корень: Control → скрипт leaderboard.gd
## Дочерние узлы (создаются динамически в _ready, сцена может быть пустой Control)

const DIFFICULTY_LABELS = {
	"2x2": "2×2 (4 карты)",
	"3x4": "3×4 (12 карт)",
	"4x4": "4×4 (16 карт)",
	"4x5": "4×5 (20 карт)",
}

var _score: int = 0
var _difficulty: String = "4x4"
var _player_name: String = ""
var _submitted: bool = false

var _rank_label: Label
var _table_container: VBoxContainer
var _name_panel: PanelContainer
var _name_input: LineEdit
var _status_label: Label

func _ready() -> void:
	_score = GameManager.get_meta("solo_score", 0)
	_difficulty = GameManager.get_meta("solo_difficulty", "4x4")
	_player_name = LeaderboardManager.load_player_name()

	_build_ui()

	LeaderboardManager.leaderboard_fetched.connect(_on_leaderboard_fetched)
	LeaderboardManager.score_submitted.connect(_on_score_submitted)
	LeaderboardManager.request_failed.connect(_on_request_failed)

	if _player_name.is_empty():
		_show_name_input()
	else:
		_submit_score()

func _exit_tree() -> void:
	if LeaderboardManager.leaderboard_fetched.is_connected(_on_leaderboard_fetched):
		LeaderboardManager.leaderboard_fetched.disconnect(_on_leaderboard_fetched)
	if LeaderboardManager.score_submitted.is_connected(_on_score_submitted):
		LeaderboardManager.score_submitted.disconnect(_on_score_submitted)
	if LeaderboardManager.request_failed.is_connected(_on_request_failed):
		LeaderboardManager.request_failed.disconnect(_on_request_failed)

func _build_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	scroll.add_child(margin)

	# Заголовок
	var title = Label.new()
	title.text = "Таблица лидеров"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	# Сложность
	var diff_lbl = Label.new()
	diff_lbl.text = DIFFICULTY_LABELS.get(_difficulty, _difficulty)
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.add_theme_font_size_override("font_size", 18)
	diff_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(diff_lbl)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Результат игрока
	_rank_label = Label.new()
	_rank_label.text = "Твой результат: %d %s" % [_score, _pluralize(_score)]
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override("font_size", 22)
	_rank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_rank_label)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Таблица
	var table_title = Label.new()
	table_title.text = "Топ-10"
	table_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(table_title)

	_table_container = VBoxContainer.new()
	_table_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_table_container)

	var loading = Label.new()
	loading.text = "Загрузка..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_theme_font_size_override("font_size", 16)
	loading.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_table_container.add_child(loading)

	# Статус (место игрока, ошибки)
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# Кнопки
	var btn_again = Button.new()
	btn_again.text = "Играть снова"
	btn_again.add_theme_font_size_override("font_size", 20)
	btn_again.custom_minimum_size = Vector2(220, 55)
	btn_again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_again.pressed.connect(_on_play_again)
	vbox.add_child(btn_again)

	var btn_menu = Button.new()
	btn_menu.text = "В меню"
	btn_menu.add_theme_font_size_override("font_size", 18)
	btn_menu.custom_minimum_size = Vector2(220, 50)
	btn_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_menu.pressed.connect(_on_go_menu)
	vbox.add_child(btn_menu)

	# Панель ввода имени (скрытая по умолчанию)
	_name_panel = PanelContainer.new()
	_name_panel.visible = false
	_name_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_name_panel.z_index = 10
	var np_vbox = VBoxContainer.new()
	np_vbox.add_theme_constant_override("separation", 14)
	_name_panel.add_child(np_vbox)

	var np_lbl = Label.new()
	np_lbl.text = "Введи своё имя\nдля таблицы лидеров:"
	np_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	np_lbl.add_theme_font_size_override("font_size", 20)
	np_vbox.add_child(np_lbl)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Имя (до 16 символов)"
	_name_input.max_length = 16
	_name_input.custom_minimum_size = Vector2(280, 50)
	_name_input.add_theme_font_size_override("font_size", 20)
	np_vbox.add_child(_name_input)

	var np_btn = Button.new()
	np_btn.text = "Сохранить"
	np_btn.add_theme_font_size_override("font_size", 20)
	np_btn.pressed.connect(_on_name_confirm)
	np_vbox.add_child(np_btn)

	add_child(_name_panel)

func _show_name_input() -> void:
	_name_panel.visible = true
	_name_input.grab_focus()

func _on_name_confirm() -> void:
	var name = _name_input.text.strip_edges()
	if name.is_empty():
		return
	_player_name = name
	LeaderboardManager.save_player_name(name)
	_name_panel.visible = false
	_submit_score()

func _submit_score() -> void:
	if _submitted:
		return
	_submitted = true
	LeaderboardManager.submit(_difficulty, _player_name, _score)

func _on_score_submitted(rank: int, total: int) -> void:
	_status_label.text = "Твоё место: %d из %d" % [rank, total]
	LeaderboardManager.fetch(_difficulty)

func _on_leaderboard_fetched(entries: Array) -> void:
	# Очищаем таблицу
	for child in _table_container.get_children():
		child.queue_free()
	if entries.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Таблица пока пуста"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 16)
		_table_container.add_child(empty_lbl)
		return
	for entry in entries:
		var row = _make_row(entry.get("rank", 0), entry.get("name", "?"), entry.get("score", 0))
		_table_container.add_child(row)

func _make_row(rank: int, name: String, score: int) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var rank_lbl = Label.new()
	rank_lbl.text = "%d." % rank
	rank_lbl.custom_minimum_size = Vector2(36, 0)
	rank_lbl.add_theme_font_size_override("font_size", 17)
	if rank == 1:
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hbox.add_child(rank_lbl)

	var name_lbl = Label.new()
	name_lbl.text = name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.clip_text = true
	hbox.add_child(name_lbl)

	var score_lbl = Label.new()
	score_lbl.text = str(score)
	score_lbl.custom_minimum_size = Vector2(50, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.add_theme_font_size_override("font_size", 17)
	hbox.add_child(score_lbl)

	return hbox

func _on_request_failed() -> void:
	_status_label.text = "Нет соединения с сервером"
	for child in _table_container.get_children():
		child.queue_free()
	var err_lbl = Label.new()
	err_lbl.text = "Не удалось загрузить таблицу"
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.add_theme_font_size_override("font_size", 16)
	err_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	_table_container.add_child(err_lbl)

func _on_play_again() -> void:
	AudioManager.play_bgm("bgm_game")
	GameManager.start_solo_game(GameManager._solo_cols, GameManager._solo_rows)
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

func _on_go_menu() -> void:
	AudioManager.play_bgm("bgm_menu")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_go_menu()

func _pluralize(n: int) -> String:
	# "очко" / "очка" / "очков"
	var mod10 = n % 10
	var mod100 = n % 100
	if mod100 >= 11 and mod100 <= 14:
		return "очков"
	if mod10 == 1:
		return "очко"
	if mod10 >= 2 and mod10 <= 4:
		return "очка"
	return "очков"
