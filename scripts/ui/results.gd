extends Control

## Results.gd — экран результатов

@onready var title_label: Label = $VBox/Title
@onready var scores_label: Label = $VBox/Scores
@onready var play_again_button: Button = $VBox/Buttons/PlayAgain
@onready var menu_button: Button = $VBox/Buttons/Menu

func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_menu)
	_display_results()

func _display_results() -> void:
	if not GameManager.has_meta("result_data"):
		title_label.text = "Игра окончена"
		return

	var result_data = GameManager.get_meta("result_data")
	var winner_id: int = result_data["winner_id"]
	var scores: Dictionary = result_data["scores"]

	if GameManager.is_local:
		# Локальный режим
		if winner_id == -1:
			title_label.text = "🤝 Ничья!"
		else:
			title_label.text = "🎉 %s победил!" % GameManager.get_player_name(winner_id)
		var text = ""
		for pid in scores:
			text += "%s: %d очков\n" % [GameManager.get_player_name(pid), scores[pid]]
		scores_label.text = text
	else:
		# Сетевой режим
		var my_id: int = result_data["my_peer_id"]
		if winner_id == -1:
			title_label.text = "🤝 Ничья!"
		elif winner_id == my_id:
			title_label.text = "🎉 Вы победили!"
		else:
			title_label.text = "😔 Вы проиграли"
		var text = ""
		for pid in scores:
			var label = "Вы" if pid == my_id else "Соперник"
			text += "%s: %d очков\n" % [label, scores[pid]]
		scores_label.text = text

func _on_play_again() -> void:
	if GameManager.is_local:
		GameManager.start_local_game(true)
		get_tree().change_scene_to_file("res://scenes/game_board.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_menu()

func _on_menu() -> void:
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
