
extends PanelContainer

## HelpPanel.gd

const HD_Ref = preload("res://scripts/data/help_card_data.gd")

signal help_card_selected(help_card)
signal pass_turn_pressed()

@onready var help_row: HBoxContainer = $VBox/HelpRow
@onready var pass_button: Button = $VBox/PassButton
@onready var help_count_label: Label = $VBox/HelpCountLabel

func _ready() -> void:
	pass_button.pressed.connect(_on_pass_or_end)
	_safe_connect(GameManager.help_card_received, func(_a, _b): update_display())
	_safe_connect(GameManager.help_card_used, func(_a, _b): update_display())
	_safe_connect(GameManager.turn_changed, func(_a): update_display())
	_safe_connect(GameManager.card_flipped, func(_a, _b): update_display())
	_safe_connect(GameManager.waiting_for_player, func(): update_display())
	update_display()

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func update_display() -> void:
	for child in help_row.get_children():
		child.queue_free()

	if not GameManager.state or not GameManager.state.game_started:
		pass_button.disabled = true
		pass_button.visible = false
		help_count_label.text = ""
		return

	var flipped = GameManager.state.flipped_this_turn.size()
	var has_hard = GameManager.state.has_open_hard_task()
	var awaiting = GameManager.awaiting_player_action

	# Карты помощи текущего игрока
	var my_cards = GameManager.get_my_help_cards()
	if GameManager.state.use_help_cards and my_cards.size() > 0:
		help_count_label.text = "Карты помощи: %d" % my_cards.size()
		for card in my_cards:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(140, 40)
			var captured_card = card
			
			match card.help_type:
				HD_Ref.HelpType.EXTRA_FLIP:
					btn.text = "🃏 +1 карта"
					btn.pressed.connect(func():
						GameManager.on_use_help_card(captured_card)
						update_display()
					)
				HD_Ref.HelpType.CHANGE_ANIMAL:
					btn.text = "🔄 Сменить зверька"
					btn.pressed.connect(func(): help_card_selected.emit(captured_card))
					btn.disabled = flipped == 0
				HD_Ref.HelpType.CHANGE_SEASON:
					btn.text = "🌦 Сменить фон"
					btn.pressed.connect(func(): help_card_selected.emit(captured_card))
					btn.disabled = flipped == 0
			
			help_row.add_child(btn)
	else:
		help_count_label.text = "" if not GameManager.state.use_help_cards else "Карты помощи: 0"

	# Кнопка действия
	if awaiting:
		# Ход провален, карты открыты — показываем "Завершить ход"
		pass_button.visible = true
		pass_button.disabled = false
		pass_button.text = "⏭ Завершить ход"
	elif flipped >= 2 and has_hard and flipped < GameManager.state.get_max_flips():
		# Можно передать ход досрочно (есть сложное задание, открыто 2-3 карты)
		pass_button.visible = true
		pass_button.disabled = false
		pass_button.text = "⏭ Передать ход"
	else:
		pass_button.visible = false

func _on_pass_or_end() -> void:
	if GameManager.awaiting_player_action:
		GameManager.on_end_turn()
	else:
		GameManager.on_pass_turn()

