extends Control

## GameBoard.gd — главный игровой экран

const HD_Ref = preload("res://scripts/data/help_card_data.gd")

@onready var board: Control = $VBox/Board
@onready var hud: PanelContainer = $VBox/HUD
@onready var task_panel: PanelContainer = $VBox/TaskPanel
@onready var help_panel: PanelContainer = $VBox/HelpPanel

var help_select_mode: bool = false
var pending_help_card = null
var _is_processing_end_turn: bool = false
var _last_turn_success: bool = false

func _ready() -> void:
	board.card_tapped.connect(_on_card_tapped)
	help_panel.help_card_selected.connect(_on_help_card_selected)
	hud.exit_requested.connect(_on_exit_game)

	if not GameManager.is_local:
		_safe_connect(NetworkManager.player_disconnected, _on_opponent_disconnected)

	_safe_connect(GameManager.card_flipped, _on_card_flipped)
	_safe_connect(GameManager.cards_closed, _on_cards_closed)
	_safe_connect(GameManager.task_completed, _on_task_completed)
	_safe_connect(GameManager.turn_changed, _on_turn_changed)
	_safe_connect(GameManager.turn_failed, _on_turn_failed)
	_safe_connect(GameManager.waiting_for_player, _on_waiting)
	_safe_connect(GameManager.game_over_signal, _on_game_over)
	_safe_connect(GameManager.state_synced, _on_state_synced)
	_safe_connect(GameManager.help_card_used, _on_help_card_used)
	if GameManager.is_solo:
		_safe_connect(GameManager.solo_round_complete, _on_solo_round_complete)

	if GameManager.state and GameManager.state.game_started:
		_setup_ui()
	AudioManager.play_bgm("bgm_game")

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func _exit_tree() -> void:
	for pair in [
		[GameManager.card_flipped, _on_card_flipped],
		[GameManager.cards_closed, _on_cards_closed],
		[GameManager.task_completed, _on_task_completed],
		[GameManager.turn_changed, _on_turn_changed],
		[GameManager.turn_failed, _on_turn_failed],
		[GameManager.waiting_for_player, _on_waiting],
		[GameManager.game_over_signal, _on_game_over],
		[GameManager.state_synced, _on_state_synced],
		[GameManager.help_card_used, _on_help_card_used],
	]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	if GameManager.solo_round_complete.is_connected(_on_solo_round_complete):
		GameManager.solo_round_complete.disconnect(_on_solo_round_complete)

func _setup_ui() -> void:
	var cols: int = GameManager.state.board_cols
	var solo: bool = GameManager.state.is_solo
	board.setup_board(GameManager.state.board, cols, solo)  # face_up=true в соло для запоминания
	if GameManager.state.task_deck_mode:
		task_panel.setup_deck_mode()
	else:
		task_panel.setup_tasks(GameManager.state.task_slots)
	hud.update_display()
	help_panel.update_display()
	if not GameManager.state.use_help_cards:
		help_panel.visible = false
	if solo:
		board.set_all_interactive(false)
		_show_memorization_overlay()

## Оверлей фазы запоминания (соло-режим): показывает "Запомни!" и кнопку "Играть"
func _show_memorization_overlay() -> void:
	var panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -160
	panel.offset_bottom = 0
	panel.z_index = 5
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var lbl = Label.new()
	lbl.text = "Запомни расположение карт!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)
	var btn = Button.new()
	btn.text = "Играть!"
	btn.custom_minimum_size = Vector2(200, 55)
	btn.add_theme_font_size_override("font_size", 20)
	vbox.add_child(btn)
	add_child(panel)
	btn.pressed.connect(_start_solo_play.bind(panel))

## Начать соло-игру: скрыть карты и передать управление игроку
func _start_solo_play(panel: Node) -> void:
	panel.queue_free()
	board.flip_all_down()
	board.set_all_interactive(true)

# --- Выход ---

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hud._on_exit_pressed()

func _on_exit_game() -> void:
	AudioManager.stop_bgm()
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# --- Действия ---

func _on_card_tapped(card_index: int) -> void:
	if _is_processing_end_turn:
		return
	if help_select_mode:
		_apply_help_to_card(card_index)
		return
	GameManager.on_card_tapped(card_index)

func _on_help_card_selected(help_card) -> void:
	help_select_mode = true
	pending_help_card = help_card
	for idx in GameManager.state.flipped_this_turn:
		board.highlight_card(idx, true)

func _apply_help_to_card(card_index: int) -> void:
	if not card_index in GameManager.state.flipped_this_turn:
		_cancel_help_select()
		return
	_cancel_help_select_highlights()
	help_select_mode = false
	match pending_help_card.help_type:
		HD_Ref.HelpType.CHANGE_SEASON:
			GameManager.on_use_help_card(pending_help_card, card_index)
			pending_help_card = null
			help_panel.update_display()
		HD_Ref.HelpType.CHANGE_ANIMAL:
			_show_animal_picker(card_index)
			return  # pending_help_card будет очищен внутри пикера
	pending_help_card = null

func _show_animal_picker(card_index: int) -> void:
	var popup = PanelContainer.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.z_index = 10
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	var lbl = Label.new()
	lbl.text = "Кого поставить?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(lbl)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)
	const ANIMAL_NAMES = ["Манул", "Сайгак", "Выхухоль", "Мандаринка"]
	for i in range(4):
		var btn = Button.new()
		btn.text = ANIMAL_NAMES[i]
		btn.custom_minimum_size = Vector2(90, 60)
		btn.add_theme_font_size_override("font_size", 16)
		var animal_idx = i
		var saved_card = pending_help_card
		btn.pressed.connect(func():
			GameManager.on_use_help_card(saved_card, card_index, animal_idx)
			pending_help_card = null
			help_panel.update_display()
			popup.queue_free()
		)
		hbox.add_child(btn)
	var cancel_btn = Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.pressed.connect(func():
		pending_help_card = null
		popup.queue_free()
	)
	vbox.add_child(cancel_btn)
	add_child(popup)

func _cancel_help_select() -> void:
	_cancel_help_select_highlights()
	help_select_mode = false
	pending_help_card = null

func _cancel_help_select_highlights() -> void:
	for idx in GameManager.state.flipped_this_turn:
		board.highlight_card(idx, false)

# --- Сигналы ---

func _on_card_flipped(card_index: int, _card_data) -> void:
	board.flip_card_up(card_index)
	help_panel.update_display()

func _on_waiting() -> void:
	help_panel.update_display()

func _on_turn_failed() -> void:
	_last_turn_success = false
	AudioManager.play_sfx("match_fail")

func _on_cards_closed(card_indices: Array) -> void:
	_is_processing_end_turn = true
	board.set_all_interactive(false)
	_cancel_help_select()
	await get_tree().create_timer(0.8).timeout
	if not _last_turn_success:
		board.shake_cards(card_indices)
		await get_tree().create_timer(0.4).timeout
	_last_turn_success = false
	board.flip_cards_down(card_indices)
	_is_processing_end_turn = false
	board.set_all_interactive(true)

func _on_task_completed(_player_id: int, _task) -> void:
	_last_turn_success = true
	AudioManager.play_sfx("match_success")

func _on_turn_changed(_player_id: int) -> void:
	hud.update_display()
	help_panel.update_display()
	if not _is_processing_end_turn:
		board.set_all_interactive(true)
	AudioManager.play_sfx("turn_change")

func _on_game_over(winner_id: int, scores: Dictionary) -> void:
	AudioManager.stop_bgm()
	if GameManager.is_solo:
		# В соло game_over = ошибка → переход к таблице лидеров
		AudioManager.play_sfx("match_fail")
		GameManager.set_meta("solo_score", scores.get(1, 0))
		GameManager.set_meta("solo_difficulty", GameManager.state.solo_difficulty)
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")
		return
	AudioManager.play_sfx("victory")
	GameManager.set_meta("result_data", {
		"winner_id": winner_id, "scores": scores,
		"my_peer_id": GameManager.my_peer_id,
	})
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/results.tscn")

func _on_state_synced() -> void:
	_setup_ui()

func _on_help_card_used(_player_id: int, _help_card) -> void:
	# Обновить визуал открытых карт с учётом модификаций (смена зверька/фона)
	for idx in GameManager.state.flipped_this_turn:
		var modified = GameManager.state._apply_modifications(GameManager.state.board[idx], idx)
		board.refresh_card(idx, modified)

## Соло: все задания раунда выполнены без ошибок → перемешать и начать заново
func _on_solo_round_complete(_total_score: int) -> void:
	board.set_all_interactive(false)
	await get_tree().create_timer(0.6).timeout
	GameManager.state.reset_for_next_round()
	board.setup_board(GameManager.state.board, GameManager.state.board_cols, true)
	task_panel.setup_deck_mode()
	hud.update_display()
	_show_memorization_overlay()

func _on_opponent_disconnected(_peer_id: int) -> void:
	board.set_all_interactive(false)
	var popup = AcceptDialog.new()
	popup.title = "Соединение прервано"
	popup.dialog_text = "Соперник отключился."
	popup.confirmed.connect(_on_exit_game)
	popup.canceled.connect(_on_exit_game)
	add_child(popup)
	popup.popup_centered()
