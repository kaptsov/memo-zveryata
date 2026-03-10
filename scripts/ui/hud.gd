extends PanelContainer

## HUD.gd

signal exit_requested()

@onready var my_score_label: Label = $HBox/MyScore
@onready var opponent_score_label: Label = $HBox/OpponentScore
@onready var turn_label: Label = $HBox/TurnIndicator
@onready var help_deck_label: Label = $HBox/HelpDeckCount
@onready var exit_button: Button = $HBox/ExitButton

var _confirm_exit: bool = false

func _ready() -> void:
	_safe_connect(GameManager.score_updated, _on_update)
	_safe_connect(GameManager.turn_changed, _on_update)
	_safe_connect(GameManager.help_card_received, _on_update)
	exit_button.pressed.connect(_on_exit_pressed)
	update_display()

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func _on_exit_pressed() -> void:
	if _confirm_exit:
		exit_requested.emit()
	else:
		_confirm_exit = true
		exit_button.text = "Выйти?"
		# Сброс через 2 секунды
		await get_tree().create_timer(2.0).timeout
		_confirm_exit = false
		exit_button.text = "✕"

func update_display() -> void:
	if not GameManager.state or not GameManager.state.game_started:
		return
	if GameManager.is_solo:
		var score = GameManager.get_player_score(1)
		my_score_label.text = "★ %d" % score
		my_score_label.add_theme_font_size_override("font_size", 28)
		my_score_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		opponent_score_label.visible = false
		turn_label.text = ""
		help_deck_label.visible = false
		return
	if GameManager.is_local:
		var players = GameManager.state.player_order
		if players.size() <= 2:
			my_score_label.text = "П1: %d" % GameManager.get_player_score(1)
			opponent_score_label.text = "П2: %d" % GameManager.get_player_score(2)
			opponent_score_label.visible = true
		else:
			var parts: Array = []
			for pid in players:
				parts.append("П%d:%d" % [pid, GameManager.get_player_score(pid)])
			my_score_label.text = "  ".join(parts)
			opponent_score_label.visible = false
		turn_label.text = "▶ %s" % GameManager.get_current_player_name()
		turn_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		my_score_label.text = "Я: %d" % GameManager.get_my_score()
		opponent_score_label.text = "Соп: %d" % GameManager.get_opponent_score()
		opponent_score_label.visible = true
		if GameManager.is_my_turn():
			turn_label.text = "▶ Ваш ход"
			turn_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			turn_label.text = "⏳ Ход соперника"
			turn_label.add_theme_color_override("font_color", Color.GRAY)
	help_deck_label.text = "📦 %d" % GameManager.state.help_deck.size()

func _on_update(_a = null, _b = null) -> void:
	update_display()
