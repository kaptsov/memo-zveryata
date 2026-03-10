extends Control

## Board.gd
## Управляет сеткой 4×4 карт зверят.

signal card_tapped(card_index: int)

const GRID_COLS: int = 4
const GRID_ROWS: int = 4
const CARD_SPACING: int = 10

var cards: Array = []  # Array of Card nodes

@onready var grid: GridContainer = $GridContainer

# Preload card scene
var CardScene: PackedScene = preload("res://scenes/card.tscn")

# =============================================
# ИНИЦИАЛИЗАЦИЯ
# =============================================

func setup_board(board_data: Array, cols: int = GRID_COLS, face_up: bool = false) -> void:
	_clear_board()
	var rows: int = ceili(float(board_data.size()) / float(cols))
	grid.columns = cols

	# Рассчитать размер карт по доступному пространству
	await get_tree().process_frame  # Ждём чтобы размеры обновились
	var available_w = size.x - 20  # Отступы
	var available_h = size.y - 20
	var card_w = (available_w - (cols - 1) * 6) / cols
	var card_h = (available_h - (rows - 1) * 6) / rows
	var card_size = min(card_w, card_h)
	card_size = min(card_size, 170)  # Максимум
	
	for i in range(board_data.size()):
		var card_node = CardScene.instantiate()
		card_node.custom_minimum_size = Vector2(card_size, card_size * 1.25)
		grid.add_child(card_node)
		card_node.setup(i, board_data[i])
		if face_up:
			card_node.flip_face_up()
		card_node.pivot_offset = Vector2(card_size / 2, card_size * 1.25 / 2)
		card_node.card_pressed.connect(_on_card_pressed)
		cards.append(card_node)
	
	# Центрировать грид
	await get_tree().process_frame
	var grid_w = grid.size.x
	var grid_h = grid.size.y
	grid.position = Vector2((size.x - grid_w) / 2, (size.y - grid_h) / 2)

func _clear_board() -> void:
	for card in cards:
		card.queue_free()
	cards.clear()

# =============================================
# УПРАВЛЕНИЕ КАРТАМИ
# =============================================

func _on_card_pressed(card_index: int) -> void:
	card_tapped.emit(card_index)

## Открыть карту
func flip_card_up(card_index: int) -> void:
	if card_index >= 0 and card_index < cards.size():
		cards[card_index].flip_face_up()

## Закрыть карты
func flip_cards_down(card_indices: Array) -> void:
	for idx in card_indices:
		if idx >= 0 and idx < cards.size():
			cards[idx].flip_face_down()

## Открыть все карты (фаза запоминания в соло-режиме)
func flip_all_up() -> void:
	for card in cards:
		card.flip_face_up()

## Закрыть все карты
func flip_all_down() -> void:
	for card in cards:
		card.flip_face_down()

## Установить интерактивность всех карт
func set_all_interactive(enabled: bool) -> void:
	for card in cards:
		card.set_interactive(enabled)

## Подсветить конкретную карту
func highlight_card(card_index: int, enabled: bool) -> void:
	if card_index >= 0 and card_index < cards.size():
		cards[card_index].set_highlighted(enabled)

## Обновить лицевую сторону карты (после карты помощи)
func refresh_card(card_index: int, card_data) -> void:
	if card_index >= 0 and card_index < cards.size():
		cards[card_index].update_face(card_data)

## Покачать карты (неудача)
func shake_cards(card_indices: Array) -> void:
	for idx in card_indices:
		if idx >= 0 and idx < cards.size():
			cards[idx].shake()
