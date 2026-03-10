extends RefCounted

## GameState — полное состояние игры.
## Создаётся в GameManager при старте. Содержит поле, задания, игроков, логику хода.
##
## Методы запуска:
##   setup(player_ids, with_help)          — обычная игра 4×4 (4 животных)
##   setup_deck_mode(player_ids, with_help) — режим колоды 4×4
##   setup_solo(cols, rows)                — соло: переменная сетка, задания из колоды
##
## _create_board_for_size(num_pairs):
##   Порядок пар: MANUL/SAIGA/DESMAN/MANDARIN_DUCK (лето, потом зима),
##   затем SNOW_LEOPARD/PTARMIGAN/AMUR_TIGER/SIBERIAN_IBEX (лето, потом зима).
##   Берёт первые num_pairs без повторов (max 16 уникальных пар).

const CD = preload("res://scripts/data/card_data.gd")
const TD = preload("res://scripts/data/task_data.gd")
const HD = preload("res://scripts/data/help_card_data.gd")

var board: Array = []
var board_flipped: Array = []
var board_cols: int = 4  # количество столбцов в сетке (для соло может отличаться)
var is_solo: bool = false
var solo_difficulty: String = ""  # "2x2", "3x4", "4x4", "4x5"
var task_slots: Array = []
var help_deck: Array = []
var use_help_cards: bool = true
var players: Dictionary = {}
var player_order: Array = []
var current_player_index: int = 0
var flipped_this_turn: Array = []
var extra_flips: int = 0
var turn_modifications: Array = []
var game_started: bool = false
var game_over: bool = false
var _task_completed_flag: bool = false

# Режим "Колода заданий"
var task_deck_mode: bool = false
var task_deck: Array = []
var deck_current_task = null

func setup(player_ids: Array, with_help_cards: bool = true) -> void:
	task_deck_mode = false
	use_help_cards = with_help_cards
	_create_board()
	_create_tasks()
	if use_help_cards:
		_create_help_deck()
	_create_players(player_ids)
	game_started = true
	game_over = false

## Запустить одиночную игру с сеткой cols×rows
func setup_solo(cols: int, rows: int) -> void:
	is_solo = true
	task_deck_mode = true
	use_help_cards = false
	board_cols = cols
	solo_difficulty = "%dx%d" % [cols, rows]
	var num_pairs: int = (cols * rows) / 2
	_create_board_for_size(num_pairs)
	_create_solo_tasks()
	_create_players([1])
	game_started = true
	game_over = false

## Создать доску произвольного размера (num_pairs пар карт).
## Порядок: оригинальные 4 животных (лето, потом зима), затем новые 4 (лето, потом зима).
## Берём первые num_pairs из 16 уникальных пар — без повторов.
func _create_board_for_size(num_pairs: int) -> void:
	board.clear()
	board_flipped.clear()
	var original = [CD.AnimalType.MANUL, CD.AnimalType.SAIGA, CD.AnimalType.DESMAN, CD.AnimalType.MANDARIN_DUCK]
	var extended = [CD.AnimalType.SNOW_LEOPARD, CD.AnimalType.PTARMIGAN, CD.AnimalType.AMUR_TIGER, CD.AnimalType.SIBERIAN_IBEX]
	var ordered_pairs: Array = []
	for animal in original:
		ordered_pairs.append({"animal": animal, "season": CD.Season.SUMMER})
	for animal in original:
		ordered_pairs.append({"animal": animal, "season": CD.Season.WINTER})
	for animal in extended:
		ordered_pairs.append({"animal": animal, "season": CD.Season.SUMMER})
	for animal in extended:
		ordered_pairs.append({"animal": animal, "season": CD.Season.WINTER})
	# Берём ровно num_pairs уникальных пар (без повторов, без зацикливания)
	var selected: Array = ordered_pairs.slice(0, min(num_pairs, ordered_pairs.size()))
	var all_cards: Array = []
	var id_counter: int = 0
	for pair in selected:
		for copy_label in ["A", "B"]:
			var card = CD.new()
			card.card_id = id_counter
			card.animal_type = pair["animal"]
			card.season = pair["season"]
			card.copy = copy_label
			all_cards.append(card)
			id_counter += 1
	all_cards.shuffle()
	for i in range(all_cards.size()):
		all_cards[i].card_id = i
		board.append(all_cards[i])
		board_flipped.append(false)

## Создать задания для соло: SIMPLE для каждой уникальной пары + HARD если ≥4 разных
## животных одного сезона на доске.
func _create_solo_tasks() -> void:
	task_deck.clear()
	task_slots.clear()
	var seen: Dictionary = {}
	var id_counter: int = 0
	for card in board:
		var key = "%d_%d" % [card.animal_type, card.season]
		if not seen.has(key):
			seen[key] = true
			var task = TD.new()
			task.task_id = id_counter
			task.task_type = TD.TaskType.SIMPLE
			task.points = 1
			task.required_animal = card.animal_type
			task.required_season = card.season
			task.is_active = true
			task_deck.append(task)
			id_counter += 1
	# Добавить HARD задание если на доске ≥4 разных животных одного сезона
	for season in [CD.Season.SUMMER, CD.Season.WINTER]:
		var season_animals: Array = []
		for key in seen.keys():
			var parts = key.split("_")
			if int(parts[1]) == season:
				season_animals.append(int(parts[0]))
		if season_animals.size() >= 4:
			var task = TD.new()
			task.task_id = id_counter
			task.task_type = TD.TaskType.HARD
			task.points = 2
			task.required_season = season
			task.is_active = true
			task_deck.append(task)
			id_counter += 1
	task_deck.shuffle()
	deck_current_task = task_deck.front() if not task_deck.is_empty() else null

func setup_deck_mode(player_ids: Array, with_help_cards: bool = true) -> void:
	task_deck_mode = true
	use_help_cards = with_help_cards
	_create_board()
	_create_deck_tasks()
	if use_help_cards:
		_create_help_deck()
	_create_players(player_ids)
	game_started = true
	game_over = false

func _create_board() -> void:
	board.clear()
	board_flipped.clear()
	var id_counter: int = 0
	for animal in [CD.AnimalType.MANUL, CD.AnimalType.SAIGA, CD.AnimalType.DESMAN, CD.AnimalType.MANDARIN_DUCK]:
		for season in [CD.Season.SUMMER, CD.Season.WINTER]:
			for copy_label in ["A", "B"]:
				var card = CD.new()
				card.card_id = id_counter
				card.animal_type = animal
				card.season = season
				card.copy = copy_label
				board.append(card)
				board_flipped.append(false)
				id_counter += 1
	board.shuffle()
	for i in range(board.size()):
		board[i].card_id = i

func _create_deck_tasks() -> void:
	task_deck.clear()
	task_slots.clear()
	var id_counter: int = 0
	for animal in [CD.AnimalType.MANUL, CD.AnimalType.SAIGA, CD.AnimalType.DESMAN, CD.AnimalType.MANDARIN_DUCK]:
		for season in [CD.Season.SUMMER, CD.Season.WINTER]:
			var task = TD.new()
			task.task_id = id_counter
			task.task_type = TD.TaskType.SIMPLE
			task.points = 1
			task.required_animal = animal
			task.required_season = season
			task.is_active = true
			task_deck.append(task)
			id_counter += 1
	for _i in range(4):
		for season in [CD.Season.SUMMER, CD.Season.WINTER]:
			var task = TD.new()
			task.task_id = id_counter
			task.task_type = TD.TaskType.HARD
			task.points = 2
			task.required_season = season
			task.is_active = true
			task_deck.append(task)
			id_counter += 1
	task_deck.shuffle()
	deck_current_task = task_deck.front() if not task_deck.is_empty() else null

func _create_tasks() -> void:
	task_slots.clear()
	var simple_tasks: Array = []
	var task_id: int = 0
	for animal in [CD.AnimalType.MANUL, CD.AnimalType.SAIGA, CD.AnimalType.DESMAN, CD.AnimalType.MANDARIN_DUCK]:
		for season in [CD.Season.SUMMER, CD.Season.WINTER]:
			var task = TD.new()
			task.task_id = task_id
			task.task_type = TD.TaskType.SIMPLE
			task.points = 1
			task.required_animal = animal
			task.required_season = season
			task.is_active = true
			simple_tasks.append(task)
			task_id += 1
	var hard_tasks: Array = []
	for i in range(4):
		for season in [CD.Season.SUMMER, CD.Season.WINTER]:
			var task = TD.new()
			task.task_id = task_id
			task.task_type = TD.TaskType.HARD
			task.points = 2
			task.required_season = season
			task.is_active = false
			hard_tasks.append(task)
			task_id += 1
	simple_tasks.shuffle()
	hard_tasks.shuffle()
	for i in range(8):
		task_slots.append({ "simple": simple_tasks[i], "hard": hard_tasks[i] })

func _create_help_deck() -> void:
	help_deck.clear()
	var distribution = [0,0,0,0,0,0, 1,1,1,1,1, 2,2,2,2,2]
	distribution.shuffle()
	for i in range(16):
		var card = HD.new()
		card.help_id = i
		card.help_type = distribution[i]
		help_deck.append(card)

func _create_players(player_ids: Array) -> void:
	players.clear()
	player_order = player_ids.duplicate()
	player_order.shuffle()
	current_player_index = 0
	for pid in player_ids:
		players[pid] = { "score": 0, "help_cards": [], "tasks_completed": [] }

func get_current_player_id() -> int:
	if player_order.is_empty():
		return -1
	return player_order[current_player_index]

func get_max_flips() -> int:
	var base = 2
	if has_open_hard_task():
		base = 4
	return base + extra_flips

func has_open_hard_task() -> bool:
	if task_deck_mode:
		return deck_current_task != null and deck_current_task.task_type == TD.TaskType.HARD
	for slot in task_slots:
		var simple = slot["simple"]
		var hard = slot["hard"]
		if simple.is_completed and not hard.is_completed and hard.is_active:
			return true
	return false

func try_flip_card(card_index: int) -> bool:
	if card_index < 0 or card_index >= board.size():
		return false
	if board_flipped[card_index]:
		return false
	if card_index in flipped_this_turn:
		return false
	if flipped_this_turn.size() >= get_max_flips():
		return false
	flipped_this_turn.append(card_index)
	board_flipped[card_index] = true
	return true

func get_flipped_cards() -> Array:
	var cards: Array = []
	for idx in flipped_this_turn:
		var card = board[idx]
		var modified = _apply_modifications(card, idx)
		cards.append(modified)
	return cards

func check_simple_tasks():
	if flipped_this_turn.size() != 2:
		return null
	var cards = get_flipped_cards()
	for slot in task_slots:
		var simple = slot["simple"]
		if not simple.is_completed and simple.is_active:
			if simple.check_simple(cards):
				return simple
	return null

func check_hard_tasks():
	if flipped_this_turn.size() != 4:
		return null
	var cards = get_flipped_cards()
	for slot in task_slots:
		var hard = slot["hard"]
		if not hard.is_completed and hard.is_active:
			if hard.check_hard(cards):
				return hard
	return null

func complete_task(task) -> void:
	var pid = get_current_player_id()
	task.is_completed = true
	players[pid]["score"] += task.points
	players[pid]["tasks_completed"].append(task)
	_task_completed_flag = true
	if task.task_type == TD.TaskType.SIMPLE:
		for slot in task_slots:
			if slot["simple"] == task:
				_try_activate_hard(slot)
				break
	elif task.task_type == TD.TaskType.HARD:
		# После выполнения сложного — активировать следующее отложенное того же сезона
		_activate_next_pending_hard(task.required_season)

func _try_activate_hard(slot: Dictionary) -> void:
	var season = slot["hard"].required_season
	# Активировать только если нет уже активного незавершённого hard-задания этого сезона
	for other in task_slots:
		if other["hard"].required_season == season and other["hard"].is_active and not other["hard"].is_completed:
			return
	slot["hard"].is_active = true

func _activate_next_pending_hard(season: int) -> void:
	# Найти первое простое задание, у которого выполнен simple но hard ещё не активирован
	for slot in task_slots:
		if slot["simple"].is_completed and not slot["hard"].is_active and not slot["hard"].is_completed:
			if slot["hard"].required_season == season:
				slot["hard"].is_active = true
				return

func end_turn():
	var help_card = null
	if not _task_completed_flag and use_help_cards and not help_deck.is_empty():
		help_card = help_deck.pop_front()
		var pid = get_current_player_id()
		players[pid]["help_cards"].append(help_card)
	for idx in flipped_this_turn:
		board_flipped[idx] = false
	flipped_this_turn.clear()
	extra_flips = 0
	turn_modifications.clear()
	_task_completed_flag = false
	current_player_index = (current_player_index + 1) % player_order.size()
	_check_game_over()
	return help_card

func use_help_card(pid: int, help_card, target_card_index: int = -1, new_animal: int = -1) -> bool:
	if pid != get_current_player_id():
		return false
	var player_hand: Array = players[pid]["help_cards"]
	var card_idx = -1
	for i in range(player_hand.size()):
		if player_hand[i].help_id == help_card.help_id:
			card_idx = i
			break
	if card_idx == -1:
		return false
	match help_card.help_type:
		HD.HelpType.EXTRA_FLIP:
			extra_flips += 1
		HD.HelpType.CHANGE_ANIMAL:
			if target_card_index < 0 or target_card_index not in flipped_this_turn:
				return false
			if new_animal < 0:
				return false
			turn_modifications.append({ "type": "change_animal", "card_index": target_card_index, "new_animal": new_animal })
		HD.HelpType.CHANGE_SEASON:
			if target_card_index < 0 or target_card_index not in flipped_this_turn:
				return false
			turn_modifications.append({ "type": "change_season", "card_index": target_card_index })
	player_hand.remove_at(card_idx)
	return true

func _apply_modifications(card, card_index: int):
	var modified = CD.new()
	modified.card_id = card.card_id
	modified.animal_type = card.animal_type
	modified.season = card.season
	modified.copy = card.copy
	for mod in turn_modifications:
		if mod["card_index"] == card_index:
			match mod["type"]:
				"change_animal":
					modified.animal_type = mod["new_animal"]
				"change_season":
					if modified.season == CD.Season.SUMMER:
						modified.season = CD.Season.WINTER
					else:
						modified.season = CD.Season.SUMMER
	return modified

func complete_deck_task() -> void:
	if deck_current_task == null:
		return
	var pid = get_current_player_id()
	deck_current_task.is_completed = true
	players[pid]["score"] += deck_current_task.points
	players[pid]["tasks_completed"].append(deck_current_task)
	_task_completed_flag = true
	task_deck.pop_front()
	deck_current_task = task_deck.front() if not task_deck.is_empty() else null
	_check_game_over()

func fail_deck_task() -> void:
	if deck_current_task == null or task_deck.is_empty():
		return
	var failed = task_deck.pop_front()
	task_deck.append(failed)
	deck_current_task = task_deck.front() if not task_deck.is_empty() else null

func _check_game_over() -> void:
	if task_deck_mode:
		if is_solo:
			# Соло бесконечный: конец игры только при ошибке (выставляется из GameManager).
			# Пустая колода = конец раунда, не конец игры.
			return
		var help_empty = use_help_cards and help_deck.is_empty()
		if task_deck.is_empty() or help_empty:
			game_over = true
		return
	var all_tasks_done = true
	for slot in task_slots:
		if not slot["simple"].is_completed or not slot["hard"].is_completed:
			all_tasks_done = false
			break
	var help_empty = use_help_cards and help_deck.is_empty()
	if all_tasks_done or help_empty:
		game_over = true

func get_winner() -> int:
	var max_score: int = -1
	var winner_id: int = -1
	var tie: bool = false
	for pid in player_order:
		var score = players[pid]["score"]
		if score > max_score:
			max_score = score
			winner_id = pid
			tie = false
		elif score == max_score:
			tie = true
	return -1 if tie else winner_id

func to_dict() -> Dictionary:
	var board_data = []
	for card in board:
		board_data.append(card.to_dict())
	var slots_data = []
	for slot in task_slots:
		slots_data.append({ "simple": slot["simple"].to_dict(), "hard": slot["hard"].to_dict() })
	var help_data = []
	for card in help_deck:
		help_data.append(card.to_dict())
	var players_data = {}
	for pid in players:
		var p = players[pid]
		var help_hand = []
		for hc in p["help_cards"]:
			help_hand.append(hc.to_dict())
		var tasks_done = []
		for td in p["tasks_completed"]:
			tasks_done.append(td.to_dict())
		players_data[pid] = { "score": p["score"], "help_cards": help_hand, "tasks_completed": tasks_done }
	var deck_data = []
	for t in task_deck:
		deck_data.append(t.to_dict())
	return {
		"board": board_data, "board_flipped": board_flipped, "task_slots": slots_data,
		"help_deck": help_data, "use_help_cards": use_help_cards,
		"players": players_data, "player_order": player_order,
		"current_player_index": current_player_index, "flipped_this_turn": flipped_this_turn,
		"extra_flips": extra_flips, "game_started": game_started, "game_over": game_over,
		"task_deck_mode": task_deck_mode,
		"task_deck": deck_data,
		"deck_current_task": deck_current_task.to_dict() if deck_current_task else null,
	}

## Перезапустить раунд соло (доска перемешивается, колода заданий пересоздаётся).
## Вызывается из GameManager при solo_round_complete.
func reset_for_next_round() -> void:
	board.shuffle()
	for i in range(board.size()):
		board[i].card_id = i
		board_flipped[i] = false
	flipped_this_turn.clear()
	extra_flips = 0
	turn_modifications.clear()
	_task_completed_flag = false
	game_over = false
	_create_solo_tasks()

static func from_dict(data: Dictionary):
	var GS = load("res://scripts/data/game_state.gd")
	var CDScript = load("res://scripts/data/card_data.gd")
	var TDScript = load("res://scripts/data/task_data.gd")
	var HDScript = load("res://scripts/data/help_card_data.gd")
	var state = GS.new()
	state.board.clear()
	for cd in data.get("board", []):
		state.board.append(CDScript.from_dict(cd))
	state.board_flipped = data.get("board_flipped", [])
	state.task_slots.clear()
	for sd in data.get("task_slots", []):
		state.task_slots.append({ "simple": TDScript.from_dict(sd["simple"]), "hard": TDScript.from_dict(sd["hard"]) })
	state.help_deck.clear()
	for hd in data.get("help_deck", []):
		state.help_deck.append(HDScript.from_dict(hd))
	state.use_help_cards = data.get("use_help_cards", true)
	state.player_order = data.get("player_order", [])
	state.current_player_index = data.get("current_player_index", 0)
	state.flipped_this_turn = data.get("flipped_this_turn", [])
	state.extra_flips = data.get("extra_flips", 0)
	state.game_started = data.get("game_started", false)
	state.game_over = data.get("game_over", false)
	state.task_deck_mode = data.get("task_deck_mode", false)
	state.task_deck.clear()
	for td in data.get("task_deck", []):
		state.task_deck.append(TDScript.from_dict(td))
	var dct = data.get("deck_current_task", null)
	state.deck_current_task = TDScript.from_dict(dct) if dct else null
	state.players.clear()
	var pd = data.get("players", {})
	for pid_str in pd:
		var pid = int(pid_str) if pid_str is String else pid_str
		var p = pd[pid_str]
		var help_hand: Array = []
		for hc in p.get("help_cards", []):
			help_hand.append(HDScript.from_dict(hc))
		var tasks_done: Array = []
		for td in p.get("tasks_completed", []):
			tasks_done.append(TDScript.from_dict(td))
		state.players[pid] = { "score": p.get("score", 0), "help_cards": help_hand, "tasks_completed": tasks_done }
	return state
