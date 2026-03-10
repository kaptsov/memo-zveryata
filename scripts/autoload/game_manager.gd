extends Node

## GameManager (Autoload — синглтон, доступен из любого скрипта как "GameManager")
##
## Центральный контроллер игры. Отвечает за:
## - Запуск игры (локальной и сетевой)
## - Обработку действий игрока (тап по карте, карта помощи, конец хода)
## - Проверку заданий и начисление очков
## - Испускание сигналов об изменениях → UI слушает и обновляется

# =============================================
# СИГНАЛЫ (UI подписывается на них в _ready, отписывается в _exit_tree)
# =============================================

signal card_flipped(card_index: int, card_data)       # Карта перевёрнута лицом
signal cards_closed(card_indices: Array)               # Карты закрываются (конец хода)
signal task_completed(player_id: int, task)            # Задание выполнено
signal hard_task_revealed(slot_index: int, task)       # Открылось сложное задание в слоте
signal turn_changed(player_id: int)                    # Смена хода: чей теперь ход
signal help_card_received(player_id: int, help_card)   # Игрок получил карту помощи
signal help_card_used(player_id: int, help_card)       # Игрок использовал карту помощи
signal game_started_signal()                           # Игра началась → переход к game_board
signal game_over_signal(winner_id: int, scores: Dictionary)  # Игра завершена
signal state_synced()                                  # Получено сетевое состояние (клиент)
signal score_updated(player_id: int, new_score: int)   # Счёт изменился
signal turn_failed()                                   # Ход провален (нет совпадения)
signal waiting_for_player()                            # Ждём решения игрока (помощь?)
signal deck_task_changed(task)                         # В режиме колоды: сменилось задание
signal solo_round_complete(total_score: int)           # Соло: раунд завершён без ошибок

# =============================================
# ЗАВИСИМОСТИ (preload вместо class_name — требование Godot 4.3-dev6)
# =============================================

const GS = preload("res://scripts/data/game_state.gd")       # Класс состояния игры
const CD = preload("res://scripts/data/card_data.gd")         # Класс данных карты
const TD = preload("res://scripts/data/task_data.gd")         # Класс данных задания
const HD = preload("res://scripts/data/help_card_data.gd")    # Класс карты помощи

# =============================================
# ПЕРЕМЕННЫЕ
# =============================================

var state = null              # Текущее состояние игры (GameState). null до старта.
var is_host: bool = false     # true если этот экземпляр является хостом (сервером)
var is_local: bool = false    # true если локальная игра (не по сети)
var is_solo: bool = false     # true если одиночная игра (соло-режим)
var my_peer_id: int = 1       # Сетевой ID этого игрока. Хост всегда 1.
var player_names: Dictionary = {}  # Словарь {peer_id: "Имя игрока"}
var _solo_cols: int = 4       # Запомненные параметры для рестарта соло
var _solo_rows: int = 4

# Флаг "ожидание": карты открыты, задание НЕ выполнено.
# В этом состоянии нельзя открывать новые карты, но можно применять помощь.
var awaiting_player_action: bool = false

func _ready() -> void:
	state = GS.new()  # Создаём пустое состояние при запуске приложения

# =============================================
# НАСТРОЙКА ИГРЫ
# =============================================

## Запустить локальную игру в обычном режиме (слоты заданий)
func start_local_game(player_count: int = 2, with_help_cards: bool = true) -> void:
	state = GS.new()
	# Создаём массив ID игроков: [1, 2, ..., player_count]
	var player_ids: Array[int] = []
	for i in range(1, player_count + 1):
		player_ids.append(i)
	state.setup(player_ids, with_help_cards)  # Инициализируем доску, задания, колоду помощи
	state._task_completed_flag = false        # Сбрасываем флаг выполнения задания
	is_host = true    # В локальной игре этот экземпляр всегда хост
	is_local = true   # Помечаем как локальную игру
	is_solo = false
	my_peer_id = 1    # Локальный игрок 1 = "хост"
	# Задаём имена игроков: {1: "Игрок 1", 2: "Игрок 2", ...}
	player_names = {}
	for i in range(1, player_count + 1):
		player_names[i] = "Игрок %d" % i
	awaiting_player_action = false
	game_started_signal.emit()                           # → переход в game_board
	turn_changed.emit(state.get_current_player_id())    # → hud обновляет "чей ход"

## Запустить локальную игру в режиме "Колода заданий"
func start_local_game_deck(player_count: int = 2, with_help_cards: bool = true) -> void:
	state = GS.new()
	var player_ids: Array[int] = []
	for i in range(1, player_count + 1):
		player_ids.append(i)
	state.setup_deck_mode(player_ids, with_help_cards)  # Режим колоды: 20 заданий в очереди
	state._task_completed_flag = false
	is_host = true
	is_local = true
	is_solo = false
	my_peer_id = 1
	player_names = {}
	for i in range(1, player_count + 1):
		player_names[i] = "Игрок %d" % i
	awaiting_player_action = false
	game_started_signal.emit()
	turn_changed.emit(state.get_current_player_id())

## Запустить одиночную игру с заданным размером сетки (cols × rows)
func start_solo_game(cols: int, rows: int) -> void:
	state = GS.new()
	state.setup_solo(cols, rows)
	state._task_completed_flag = false
	is_host = true
	is_local = true
	is_solo = true
	my_peer_id = 1
	_solo_cols = cols
	_solo_rows = rows
	player_names = {1: "Игрок"}
	awaiting_player_action = false
	game_started_signal.emit()
	turn_changed.emit(state.get_current_player_id())

## Запустить сетевую игру (вызывается только хостом)
func start_new_game(player_ids, with_help_cards: bool = true) -> void:
	state = GS.new()
	state.setup(player_ids, with_help_cards)
	state._task_completed_flag = false
	is_host = true
	is_local = false  # Сетевая игра
	awaiting_player_action = false
	game_started_signal.emit()
	turn_changed.emit(state.get_current_player_id())
	NetworkManager.sync_game_state(state.to_dict())  # Отправить состояние всем клиентам

## Применить состояние, полученное от хоста по сети (вызывается только клиентом)
func apply_synced_state(data: Dictionary) -> void:
	state = GS.from_dict(data)  # Восстановить state из словаря
	state_synced.emit()          # → game_board перестраивает UI

# =============================================
# ДЕЙСТВИЯ ИГРОКА
# =============================================

## Игрок тапнул по карте. Вызывается из game_board.gd
func on_card_tapped(card_index: int) -> void:
	if awaiting_player_action:
		return  # Нельзя открывать карты во время ожидания решения
	if is_local:
		_process_flip(card_index)  # Локально — сразу обрабатываем
	elif is_host:
		# Сетевая игра, хост: обрабатываем только если сейчас наш ход
		if state.get_current_player_id() == my_peer_id:
			_process_flip(card_index)
	else:
		# Сетевая игра, клиент: отправляем запрос хосту
		if state.get_current_player_id() == my_peer_id:
			NetworkManager.send_flip_request(card_index)

## Выполнить переворот карты и обработать последствия
func _process_flip(card_index: int) -> void:
	if not state.try_flip_card(card_index):
		return  # Карта уже открыта или превышен лимит — игнорируем
	var card_data = state.board[card_index]       # Получаем данные карты
	card_flipped.emit(card_index, card_data)      # → board.gd анимирует переворот
	if not is_local:
		NetworkManager.broadcast_card_flipped(card_index, card_data.to_dict())  # Показать всем клиентам
	_check_after_flip()  # Проверить: выполнено ли задание?

## Главная логика проверки после каждого переворота
func _check_after_flip() -> void:
	var n = state.flipped_this_turn.size()  # Сколько карт открыто в этом ходу

	# Режим колоды — отдельная логика проверки
	if state.task_deck_mode:
		_check_after_flip_deck(n)
		return

	if n == 2:
		# После 2-й карты: проверяем простые задания
		var simple = state.check_simple_tasks()
		if simple:
			_complete_and_end(simple)  # Задание выполнено! Завершаем ход с успехом
			return
		if state.has_open_hard_task():
			return  # Есть активное сложное задание — ждём ещё 2 карты
		# Нет совпадения и нет сложного задания → ход провален
		if state.use_help_cards:
			_enter_awaiting_state()  # Дать шанс использовать карту помощи
		else:
			turn_failed.emit()  # → анимация shake на картах
			_do_end_turn()
		return

	if n == 3:
		return  # Ждём 4-ю карту (нужна для сложного задания)

	if n == 4:
		# После 4-й карты: проверяем сложные задания
		var hard = state.check_hard_tasks()
		if hard:
			_complete_and_end(hard)
			return
		# Не совпало
		if state.use_help_cards:
			_enter_awaiting_state()
		else:
			turn_failed.emit()
			_do_end_turn()
		return

	# 5+ карт (если была использована карта помощи "+1 карта")
	if n >= state.get_max_flips():
		var simple = state.check_simple_tasks()
		if simple:
			_complete_and_end(simple)
			return
		var hard = state.check_hard_tasks()
		if hard:
			_complete_and_end(hard)
			return
		_enter_awaiting_state()

## Проверка в режиме "Колода заданий"
func _check_after_flip_deck(n: int) -> void:
	var task = state.deck_current_task  # Текущее задание из колоды
	if task == null:
		return  # Колода закончилась

	if task.task_type == TD.TaskType.SIMPLE:
		if n == 2:
			if task.check_simple(state.get_flipped_cards()):
				_complete_and_end(task)  # Пара найдена!
				return
			# Нет совпадения
			if state.use_help_cards:
				_enter_awaiting_state()
			else:
				turn_failed.emit()
				_do_end_turn()
		return

	# Сложное задание в режиме колоды — нужно 4 карты
	if n < 4:
		return  # Ещё не все карты открыты
	if n == 4:
		if task.check_hard(state.get_flipped_cards()):
			_complete_and_end(task)
			return
		if state.use_help_cards:
			_enter_awaiting_state()
		else:
			turn_failed.emit()
			_do_end_turn()
		return
	if n >= state.get_max_flips():
		if task.check_hard(state.get_flipped_cards()):
			_complete_and_end(task)
			return
		_enter_awaiting_state()

## Задание выполнено: засчитать, обновить UI, завершить ход
func _complete_and_end(task) -> void:
	awaiting_player_action = false  # Снимаем режим ожидания
	var pid = state.get_current_player_id()
	if state.task_deck_mode:
		state.complete_deck_task()               # Удалить задание из колоды, перейти к следующему
		deck_task_changed.emit(state.deck_current_task)  # → task_panel обновляет отображение
	else:
		state.complete_task(task)                # Начислить очки, активировать hard-задание
		_check_newly_revealed_hard_tasks()       # Уведомить task_panel о новых hard-заданиях
	task_completed.emit(pid, task)               # → task_panel затемняет выполненный слот
	score_updated.emit(pid, state.players[pid]["score"])  # → hud обновляет счёт
	if not is_local:
		NetworkManager.broadcast_task_completed(pid, task.to_dict())  # Сообщить клиентам
	_do_end_turn()  # Завершить ход

## Войти в режим ожидания: карты открыты, ход не завершён
func _enter_awaiting_state() -> void:
	awaiting_player_action = true   # Блокирует новые тапы по картам
	waiting_for_player.emit()       # → help_panel показывает карты помощи и кнопку "Завершить"

## Проверить все слоты: не появились ли новые активные hard-задания
func _check_newly_revealed_hard_tasks() -> void:
	for i in range(state.task_slots.size()):
		var slot = state.task_slots[i]
		var hard = slot["hard"]
		# Если hard активен и не выполнен — оповестить task_panel
		if hard.is_active and not hard.is_completed:
			hard_task_revealed.emit(i, hard)  # → task_panel перерисует слот

## Игрок нажал "Завершить ход" после провала (awaiting_player_action = true)
func on_end_turn() -> void:
	if state.flipped_this_turn.is_empty():
		return  # Нечего закрывать
	awaiting_player_action = false
	turn_failed.emit()   # → shake-анимация на картах
	_do_end_turn()

## Игрок передал ход досрочно (открыл 2-3 карты при активном сложном задании)
func on_pass_turn() -> void:
	if state.flipped_this_turn.size() < 2:
		return  # Нужно минимум 2 карты чтобы передать ход
	awaiting_player_action = false
	turn_failed.emit()
	_do_end_turn()

## Финальная обработка конца хода: закрыть карты, передать ход, проверить конец игры
func _do_end_turn() -> void:
	# Соло бесконечный: первая ошибка = немедленный конец игры
	if is_solo and state.task_deck_mode and not state._task_completed_flag:
		var closed = state.flipped_this_turn.duplicate()
		for idx in closed:
			state.board_flipped[idx] = false
		state.flipped_this_turn.clear()
		state.extra_flips = 0
		state.turn_modifications.clear()
		state._task_completed_flag = false
		state.game_over = true
		cards_closed.emit(closed)  # → анимация shake + закрытие
		var scores = {1: state.players[1]["score"]}
		game_over_signal.emit(1, scores)
		return

	# В режиме колоды (не соло): если задание не выполнено — отправить в конец колоды
	if state.task_deck_mode and not state._task_completed_flag:
		state.fail_deck_task()
		deck_task_changed.emit(state.deck_current_task)

	var closed_indices = state.flipped_this_turn.duplicate()  # Копия до очистки в end_turn()
	var help_card = state.end_turn()   # Закрыть карты, сдвинуть ход, возможно выдать карту помощи
	cards_closed.emit(closed_indices)  # → game_board запускает анимацию закрытия
	if help_card:
		# Вычислить ID предыдущего игрока (тот, кто только что ходил)
		var prev_idx = (state.current_player_index - 1 + state.player_order.size()) % state.player_order.size()
		var prev_pid = state.player_order[prev_idx]
		help_card_received.emit(prev_pid, help_card)  # → help_panel добавляет карту
	if state.game_over:
		# Игра завершена — собрать счёт и уведомить
		var scores = {}
		for pid in state.players:
			scores[pid] = state.players[pid]["score"]
		game_over_signal.emit(state.get_winner(), scores)  # → переход к results
		if not is_local:
			NetworkManager.broadcast_game_over(state.get_winner(), scores)
		return
	# Соло: раунд завершён без ошибок (колода исчерпана)
	if is_solo and state.task_deck.is_empty():
		solo_round_complete.emit(state.players[1]["score"])
		return
	turn_changed.emit(state.get_current_player_id())  # → hud обновляет "чей ход"
	if not is_local:
		# Оповестить клиентов о смене хода
		NetworkManager.broadcast_turn_changed(state.get_current_player_id(),
			help_card.to_dict() if help_card else {}, closed_indices)

# =============================================
# КАРТЫ ПОМОЩИ
# =============================================

## Публичный метод применения карты помощи. Вызывается из help_panel / game_board.
func on_use_help_card(help_card, target_card_index: int = -1, new_animal: int = -1) -> void:
	if is_local:
		_process_use_help(state.get_current_player_id(), help_card, target_card_index, new_animal)
	elif is_host:
		_process_use_help(my_peer_id, help_card, target_card_index, new_animal)
	else:
		# Клиент: отправить запрос хосту
		NetworkManager.send_use_help(help_card.to_dict(), target_card_index, new_animal)

## Выполнить применение карты помощи и обновить состояние
func _process_use_help(pid: int, help_card, target_card_index: int, new_animal: int) -> void:
	if state.use_help_card(pid, help_card, target_card_index, new_animal):
		help_card_used.emit(pid, help_card)  # → game_board обновляет визуал карты
		if not is_local:
			NetworkManager.broadcast_help_used(pid, help_card.to_dict(), target_card_index, new_animal)
		_recheck_tasks_after_help()  # Проверить: вдруг теперь задание выполнено?

## После карты помощи — проверить задания заново с учётом модификаций
func _recheck_tasks_after_help() -> void:
	var n = state.flipped_this_turn.size()
	if n == 2:
		var simple = state.check_simple_tasks()
		if simple:
			_complete_and_end(simple)  # Смена животного/сезона помогла выполнить задание
			return
	if n == 4:
		var hard = state.check_hard_tasks()
		if hard:
			_complete_and_end(hard)
			return
	# Если карта "+1 карта" увеличила лимит — разблокировать ход
	if awaiting_player_action and n < state.get_max_flips():
		awaiting_player_action = false  # Можно открывать ещё карту

## Найти оптимальную замену зверька среди открытых карт (для help_panel.gd)
## Возвращает {"card_index": int, "new_animal": int} или {} если нет выгодной замены
func find_best_animal_swap() -> Dictionary:
	var flipped = state.flipped_this_turn
	var cards = []
	for idx in flipped:
		cards.append(state.board[idx])
	for i in range(cards.size()):
		for animal in [0, 1, 2, 3]:  # Перебрать всех зверьков
			if animal == cards[i].animal_type:
				continue  # Не заменять на того же
			var test_cards = []
			for j in range(cards.size()):
				# Применить текущие модификации хода
				var modified = state._apply_modifications(cards[j], flipped[j])
				if j == i:
					modified.animal_type = animal  # Заменить зверька на тестируемого
				test_cards.append(modified)
			# Проверить: помогает ли замена выполнить простое задание?
			if test_cards.size() == 2:
				for slot in state.task_slots:
					var simple = slot["simple"]
					if not simple.is_completed and simple.is_active:
						if simple.check_simple(test_cards):
							return { "card_index": flipped[i], "new_animal": animal }
			# Проверить: помогает ли замена выполнить сложное задание?
			if test_cards.size() == 4:
				for slot in state.task_slots:
					var hard = slot["hard"]
					if not hard.is_completed and hard.is_active:
						if hard.check_hard(test_cards):
							return { "card_index": flipped[i], "new_animal": animal }
	return {}  # Нет выгодной замены

## Найти оптимальную карту для смены сезона
## Возвращает {"card_index": int} или {} если нет выгодной замены
func find_best_season_swap() -> Dictionary:
	var flipped = state.flipped_this_turn
	var cards = []
	for idx in flipped:
		cards.append(state.board[idx])
	for i in range(cards.size()):
		var test_cards = []
		for j in range(cards.size()):
			var modified = state._apply_modifications(cards[j], flipped[j])
			if j == i:
				# Инвертировать сезон тестируемой карты
				if modified.season == CD.Season.SUMMER:
					modified.season = CD.Season.WINTER
				else:
					modified.season = CD.Season.SUMMER
			test_cards.append(modified)
		if test_cards.size() == 2:
			for slot in state.task_slots:
				var simple = slot["simple"]
				if not simple.is_completed and simple.is_active:
					if simple.check_simple(test_cards):
						return { "card_index": flipped[i] }
		if test_cards.size() == 4:
			for slot in state.task_slots:
				var hard = slot["hard"]
				if not hard.is_completed and hard.is_active:
					if hard.check_hard(test_cards):
						return { "card_index": flipped[i] }
	return {}

# =============================================
# СЕТЕВЫЕ СОБЫТИЯ (вызываются из NetworkManager по RPC)
# =============================================

## Хост получил запрос переворота от клиента
func handle_remote_flip(card_index: int) -> void:
	if is_host: _process_flip(card_index)

## Хост получил запрос передачи хода от клиента
func handle_remote_pass() -> void:
	if is_host: on_pass_turn()

## Хост получил запрос использования карты помощи от клиента
func handle_remote_use_help(pid: int, help_data: Dictionary, target: int, animal: int) -> void:
	if is_host:
		_process_use_help(pid, HD.from_dict(help_data), target, animal)

## Клиент получил уведомление о перевороте карты (от хоста или другого игрока)
func handle_remote_card_flipped(card_index: int, card_dict: Dictionary) -> void:
	var card_data = CD.from_dict(card_dict)
	if card_index >= 0 and card_index < state.board.size():
		state.board_flipped[card_index] = true            # Отметить карту как открытую
		state.flipped_this_turn.append(card_index)        # Добавить в список хода
	card_flipped.emit(card_index, card_data)              # → board.gd анимирует переворот

## Клиент получил уведомление о смене хода
func handle_remote_turn_changed(next_player_id: int, help_dict: Dictionary, closed: Array) -> void:
	for idx in closed:
		if idx >= 0 and idx < state.board_flipped.size():
			state.board_flipped[idx] = false  # Пометить карты как закрытые
	state.flipped_this_turn.clear()       # Сбросить список карт этого хода
	state.extra_flips = 0                 # Сбросить дополнительные перевороты
	state.turn_modifications.clear()      # Сбросить модификации (помощь)
	cards_closed.emit(closed)             # → анимация закрытия карт
	if not help_dict.is_empty():
		help_card_received.emit(state.get_current_player_id(), HD.from_dict(help_dict))
	# Найти индекс следующего игрока в массиве порядка ходов
	for i in range(state.player_order.size()):
		if state.player_order[i] == next_player_id:
			state.current_player_index = i
			break
	turn_changed.emit(next_player_id)  # → hud обновляет "чей ход"

# =============================================
# УТИЛИТЫ
# =============================================

## Это мой ход? (для сетевой игры)
func is_my_turn() -> bool:
	return true if is_local else state.get_current_player_id() == my_peer_id

## Получить имя текущего игрока
func get_current_player_name() -> String:
	return player_names.get(state.get_current_player_id(), "Игрок %d" % state.get_current_player_id())

## Получить имя игрока по ID
func get_player_name(pid: int) -> String:
	return player_names.get(pid, "Игрок %d" % pid)

## Получить карты помощи текущего игрока (для help_panel)
func get_my_help_cards() -> Array:
	var pid = state.get_current_player_id() if is_local else my_peer_id
	return state.players.get(pid, {}).get("help_cards", [])

## Счёт "своего" игрока (для hud в сетевой игре)
func get_my_score() -> int:
	if is_local: return state.players.get(1, {}).get("score", 0)
	return state.players.get(my_peer_id, {}).get("score", 0)

## Счёт "соперника" (для hud в сетевой игре с 2 игроками)
func get_opponent_score() -> int:
	if is_local: return state.players.get(2, {}).get("score", 0)
	for pid in state.players:
		if pid != my_peer_id: return state.players[pid]["score"]
	return 0

## Счёт конкретного игрока по ID
func get_player_score(pid: int) -> int:
	return state.players.get(pid, {}).get("score", 0)
