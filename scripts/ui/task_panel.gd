extends PanelContainer

## TaskPanel.gd — панель заданий с мини-картинками

const TD_Ref = preload("res://scripts/data/task_data.gd")

const ANIMAL_NAMES = ["manul", "saiga", "desman", "mandarin_duck", "snow_leopard", "ptarmigan", "amur_tiger", "siberian_ibex"]
const SEASON_NAMES = ["summer", "winter"]

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var task_row: HBoxContainer = $ScrollContainer/TaskRow

var task_slots_ui: Array = []
var _deck_container: Control = null

func _ready() -> void:
	var gm = GameManager
	if not gm.task_completed.is_connected(_on_task_completed):
		gm.task_completed.connect(_on_task_completed)
	if not gm.hard_task_revealed.is_connected(_on_hard_task_revealed):
		gm.hard_task_revealed.connect(_on_hard_task_revealed)
	if not gm.deck_task_changed.is_connected(_on_deck_task_changed):
		gm.deck_task_changed.connect(_on_deck_task_changed)

# =============================================
# ПУБЛИЧНЫЙ API
# =============================================

func setup_tasks(slots: Array) -> void:
	custom_minimum_size.y = 240
	_clear()
	scroll.visible = true
	# Скрыть скроллбар, оставить свайп
	var hbar = scroll.get_h_scroll_bar()
	hbar.custom_minimum_size.y = 0
	hbar.modulate.a = 0.0
	for i in range(slots.size()):
		var slot_ui = _create_slot_panel(i, slots[i]["simple"], slots[i]["hard"])
		task_row.add_child(slot_ui)
		task_slots_ui.append(slot_ui)

func setup_deck_mode() -> void:
	custom_minimum_size.y = 160
	_clear()
	scroll.visible = false
	_deck_container = VBoxContainer.new()
	_deck_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_deck_container)
	_update_deck_display()

# =============================================
# СЛОТЫ (обычный режим)
# =============================================

func _create_slot_panel(index: int, simple, hard) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 224)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.set_meta("simple_task", simple)
	panel.set_meta("hard_task", hard)
	panel.set_meta("slot_index", index)
	_fill_slot(panel, simple)
	return panel

func _fill_slot(panel: PanelContainer, task) -> void:
	_remove_children(panel)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox)

	vbox.add_child(_make_images_small(task))

	var stars = "*" if task.task_type == TD_Ref.TaskType.SIMPLE else "**"
	var lbl = Label.new()
	lbl.text = "%s %d оч." % [stars, task.points]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

func _get_random_display_cards(count: int) -> Array:
	var available: Array = []
	if GameManager.state:
		for card in GameManager.state.board:
			available.append([card.animal_type, card.season])
	if available.is_empty():
		for _i in range(count):
			available.append([randi() % 8, randi() % 2])
	available.shuffle()
	var result: Array = []
	for i in range(count):
		result.append(available[i % available.size()])
	return result

func _make_images_small(task) -> Control:
	if AudioManager.task_random_mode:
		var count = 2 if task.task_type == TD_Ref.TaskType.SIMPLE else 4
		var cards = _get_random_display_cards(count)
		if task.task_type == TD_Ref.TaskType.SIMPLE:
			var hbox = HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			hbox.add_theme_constant_override("separation", 4)
			for c in cards:
				hbox.add_child(_img(c[0], c[1], Vector2(88, 110)))
			return hbox
		else:
			var grid = GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			for c in cards:
				grid.add_child(_img(c[0], c[1], Vector2(88, 110)))
			return grid
	if task.task_type == TD_Ref.TaskType.SIMPLE:
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 4)
		for _i in range(2):
			hbox.add_child(_img(task.required_animal, task.required_season, Vector2(88, 110)))
		return hbox
	else:
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		for animal_idx in [0, 1, 2, 3]:
			grid.add_child(_img(animal_idx, task.required_season, Vector2(88, 110)))
		return grid

# =============================================
# КОЛОДА (deck mode)
# =============================================

func _update_deck_display() -> void:
	if _deck_container == null:
		return
	_remove_children(_deck_container)

	if not GameManager.state or not GameManager.state.task_deck_mode:
		return

	var task = GameManager.state.deck_current_task
	if task == null:
		var lbl = Label.new()
		lbl.text = "Все задания выполнены!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_deck_container.add_child(lbl)
		return

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	_deck_container.add_child(hbox)

	# Карточка текущего задания
	hbox.add_child(_create_deck_card(task))

	# Колонка с инфо
	var info = VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var type_lbl = Label.new()
	type_lbl.text = "Пара" if task.task_type == TD_Ref.TaskType.SIMPLE else "Четвёрка"
	type_lbl.add_theme_font_size_override("font_size", 15)
	info.add_child(type_lbl)

	var pts_lbl = Label.new()
	pts_lbl.text = "%d %s" % [task.points, "очко" if task.points == 1 else "очка"]
	pts_lbl.add_theme_font_size_override("font_size", 13)
	info.add_child(pts_lbl)

	var count_lbl = Label.new()
	count_lbl.text = "Колода:\n%d карт" % GameManager.state.task_deck.size()
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 12)
	info.add_child(count_lbl)

func _create_deck_card(task) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 130)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)
	vbox.add_child(_make_images_deck(task))
	return panel

func _make_images_deck(task) -> Control:
	if AudioManager.task_random_mode:
		var count = 2 if task.task_type == TD_Ref.TaskType.SIMPLE else 4
		var cards = _get_random_display_cards(count)
		if task.task_type == TD_Ref.TaskType.SIMPLE:
			var hbox = HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			hbox.add_theme_constant_override("separation", 3)
			for c in cards:
				hbox.add_child(_img(c[0], c[1], Vector2(48, 60)))
			return hbox
		else:
			var grid = GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 3)
			grid.add_theme_constant_override("v_separation", 3)
			for c in cards:
				grid.add_child(_img(c[0], c[1], Vector2(48, 60)))
			return grid
	if task.task_type == TD_Ref.TaskType.SIMPLE:
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 3)
		for _i in range(2):
			hbox.add_child(_img(task.required_animal, task.required_season, Vector2(48, 60)))
		return hbox
	else:
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 3)
		grid.add_theme_constant_override("v_separation", 3)
		for animal_idx in [0, 1, 2, 3]:
			grid.add_child(_img(animal_idx, task.required_season, Vector2(48, 60)))
		return grid

# =============================================
# УТИЛИТЫ
# =============================================

func _img(animal_idx: int, season: int, size: Vector2) -> TextureRect:
	var img = TextureRect.new()
	img.custom_minimum_size = size
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path = "res://assets/sprites/animals/%s_%s.png" % [ANIMAL_NAMES[animal_idx], SEASON_NAMES[season]]
	if ResourceLoader.exists(path):
		img.texture = load(path)
	return img

func _remove_children(node: Node) -> void:
	for i in range(node.get_child_count() - 1, -1, -1):
		var c = node.get_child(i)
		node.remove_child(c)
		c.queue_free()

func _clear() -> void:
	for child in task_row.get_children():
		child.queue_free()
	task_slots_ui.clear()
	if _deck_container:
		_remove_children(_deck_container)
		_deck_container.queue_free()
		_deck_container = null

# =============================================
# СОБЫТИЯ
# =============================================

func _on_task_completed(_player_id: int, task) -> void:
	if GameManager.state.task_deck_mode:
		return  # обновление через deck_task_changed
	for slot_ui in task_slots_ui:
		var hard = slot_ui.get_meta("hard_task")
		if task == hard:
			slot_ui.modulate = Color(0.45, 0.45, 0.45, 0.6)
			break
		# Простое выполнено — не серим, ждём hard_task_revealed

func _on_hard_task_revealed(slot_index: int, task) -> void:
	if slot_index < 0 or slot_index >= task_slots_ui.size():
		return
	var slot_ui = task_slots_ui[slot_index]
	slot_ui.modulate = Color(1, 1, 1, 1)
	_fill_slot(slot_ui, task)

func _on_deck_task_changed(_task) -> void:
	_update_deck_display()
