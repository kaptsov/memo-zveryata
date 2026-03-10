extends Node

## NetworkManager (Autoload — синглтон)
##
## Управляет сетевым подключением между игроками через ENet (LAN по Wi-Fi).
## Архитектура: сервер-авторитет. Хост (peer_id=1) выполняет логику,
## клиенты только отправляют запросы и получают обновления.

const TD_Script = preload("res://scripts/data/task_data.gd")
const HD_Script = preload("res://scripts/data/help_card_data.gd")

# =============================================
# СИГНАЛЫ
# =============================================

signal player_connected(peer_id: int)     # Новый игрок подключился к серверу
signal player_disconnected(peer_id: int)  # Игрок отключился
signal connection_failed()                # Клиент не смог подключиться к серверу
signal server_created(ip: String, port: int)  # Сервер успешно создан (для отображения IP)
signal connected_to_server()              # Клиент успешно подключился

# =============================================
# КОНСТАНТЫ
# =============================================

const DEFAULT_PORT: int = 9876  # Порт для ENet-сервера
const MAX_PLAYERS: int = 6      # Максимум игроков (хост + 5 клиентов)

# =============================================
# ПЕРЕМЕННЫЕ
# =============================================

var peer: ENetMultiplayerPeer = null  # Объект ENet-соединения (null если не подключены)
var is_server: bool = false           # true если этот экземпляр является хостом
var connected_peers: Array[int] = []  # Список peer_id подключённых клиентов (без хоста)

# =============================================
# ПОДКЛЮЧЕНИЕ
# =============================================

## Создать сервер. Вызывается хостом из lobby.gd
func create_server(port: int = DEFAULT_PORT) -> Error:
	print("[NET] create_server() port=%d" % port)

	# Если старый peer существует — закрыть его перед созданием нового
	if peer != null:
		print("[NET] Старый peer существует, статус=%d, закрываем" % peer.get_connection_status())
		peer.close()
		peer = null
		multiplayer.multiplayer_peer = null

	peer = ENetMultiplayerPeer.new()

	# Попытка создать сервер на указанном порту
	var err = peer.create_server(port, MAX_PLAYERS)
	print("[NET] peer.create_server(port=%d, max_clients=%d) -> err=%d (%s)" % [port, MAX_PLAYERS, err, error_string(err)])

	if err != OK:
		push_error("Не удалось создать сервер: %s" % error_string(err))
		peer = null
		return err

	multiplayer.multiplayer_peer = peer  # Регистрируем peer в движке
	is_server = true
	GameManager.is_host = true
	GameManager.my_peer_id = 1  # Хост всегда имеет peer_id = 1

	_connect_signals()  # Подключить обработчики сетевых событий

	var ip = _get_local_ip()          # Получить локальный IP для показа игрокам
	server_created.emit(ip, port)
	print("[NET] Сервер создан: %s:%d" % [ip, port])
	return OK

## Подключиться к серверу. Вызывается клиентом из lobby.gd
func join_server(ip: String, port: int = DEFAULT_PORT) -> Error:
	print("[NET] join_server() ip=%s port=%d" % [ip, port])
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)  # Создать клиентское подключение
	print("[NET] peer.create_client() -> err=%d (%s)" % [err, error_string(err)])

	if err != OK:
		push_error("Не удалось подключиться: %s" % error_string(err))
		connection_failed.emit()
		return err

	multiplayer.multiplayer_peer = peer  # Регистрируем peer
	is_server = false
	GameManager.is_host = false

	_connect_signals()

	print("[NET] Подключение к %s:%d..." % [ip, port])
	return OK

## Отключиться от игры (вызывается при выходе в меню)
func disconnect_from_game() -> void:
	if peer:
		peer.close()          # Закрыть ENet-соединение
		peer = null
	multiplayer.multiplayer_peer = null  # Сбросить peer в движке
	connected_peers.clear()
	is_server = false

## Подключить сигналы multiplayer к обработчикам (безопасно — без дублей)
func _connect_signals() -> void:
	var pairs = [
		[multiplayer.peer_connected, _on_peer_connected],
		[multiplayer.peer_disconnected, _on_peer_disconnected],
		[multiplayer.connected_to_server, _on_connected_to_server],
		[multiplayer.connection_failed, _on_connection_failed],
	]
	for pair in pairs:
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])

# =============================================
# ОБРАБОТКА СОБЫТИЙ СЕТИ
# =============================================

## Новый клиент подключился к серверу (срабатывает на хосте)
func _on_peer_connected(id: int) -> void:
	print("Игрок подключился: %d" % id)
	connected_peers.append(id)    # Добавить в список подключённых
	player_connected.emit(id)     # → lobby.gd обновляет счётчик игроков

## Клиент отключился (срабатывает на хосте)
func _on_peer_disconnected(id: int) -> void:
	print("Игрок отключился: %d" % id)
	connected_peers.erase(id)     # Убрать из списка
	player_disconnected.emit(id)  # → lobby.gd или game_board.gd реагируют

## Клиент успешно подключился к серверу (срабатывает на клиенте)
func _on_connected_to_server() -> void:
	GameManager.my_peer_id = multiplayer.get_unique_id()  # Запомнить свой ID
	print("Подключено к серверу. Мой ID: %d" % GameManager.my_peer_id)
	connected_to_server.emit()  # → lobby.gd показывает "Ожидание начала игры"

## Клиент не смог подключиться (срабатывает на клиенте)
func _on_connection_failed() -> void:
	print("Не удалось подключиться к серверу")
	connection_failed.emit()  # → lobby.gd показывает ошибку

# =============================================
# RPC: КЛИЕНТ → ХОСТ (запросы от клиентов)
# =============================================

## Клиент хочет открыть карту → отправить запрос хосту
func send_flip_request(card_index: int) -> void:
	_rpc_flip_request.rpc_id(1, card_index)  # rpc_id(1) = отправить хосту (peer_id=1)

@rpc("any_peer", "reliable")  # any_peer: может вызвать любой клиент
func _rpc_flip_request(card_index: int) -> void:
	if not is_server:
		return  # Только хост обрабатывает запросы
	GameManager.handle_remote_flip(card_index)

## Клиент передаёт ход → отправить запрос хосту
func send_pass_turn() -> void:
	_rpc_pass_turn.rpc_id(1)

@rpc("any_peer", "reliable")
func _rpc_pass_turn() -> void:
	if not is_server:
		return
	GameManager.handle_remote_pass()

## Клиент использует карту помощи → отправить хосту
func send_use_help(help_dict: Dictionary, target: int, new_animal: int) -> void:
	_rpc_use_help.rpc_id(1, help_dict, target, new_animal)

@rpc("any_peer", "reliable")
func _rpc_use_help(help_dict: Dictionary, target: int, new_animal: int) -> void:
	if not is_server:
		return
	var sender_id = multiplayer.get_remote_sender_id()  # Кто прислал запрос
	GameManager.handle_remote_use_help(sender_id, help_dict, target, new_animal)

# =============================================
# RPC: ХОСТ → КЛИЕНТЫ (рассылка обновлений)
# =============================================

## Отправить полное состояние игры всем клиентам (в начале игры)
func sync_game_state(state_dict: Dictionary) -> void:
	if is_server:
		_rpc_sync_state.rpc(state_dict)  # rpc() без ID = всем клиентам

@rpc("authority", "reliable")  # authority: только хост может вызывать
func _rpc_sync_state(state_dict: Dictionary) -> void:
	var is_initial = not GameManager.state.game_started  # Первая синхронизация?
	GameManager.apply_synced_state(state_dict)
	if is_initial:
		GameManager.game_started_signal.emit()  # → переход в game_board на клиенте

## Уведомить всех о перевороте карты
func broadcast_card_flipped(card_index: int, card_dict: Dictionary) -> void:
	if is_server:
		_rpc_card_flipped.rpc(card_index, card_dict)

@rpc("authority", "reliable")
func _rpc_card_flipped(card_index: int, card_dict: Dictionary) -> void:
	GameManager.handle_remote_card_flipped(card_index, card_dict)  # → анимация на клиенте

## Уведомить о выполнении задания
func broadcast_task_completed(player_id: int, task_dict: Dictionary) -> void:
	if is_server:
		_rpc_task_completed.rpc(player_id, task_dict)

@rpc("authority", "reliable")
func _rpc_task_completed(player_id: int, task_dict: Dictionary) -> void:
	var task = TD_Script.from_dict(task_dict)
	# Обновить счёт на клиенте
	GameManager.task_completed.emit(player_id, task)
	GameManager.score_updated.emit(player_id, GameManager.state.players.get(player_id, {}).get("score", 0))

## Уведомить о смене хода
func broadcast_turn_changed(next_player_id: int, help_dict: Dictionary, closed_indices: Array) -> void:
	if is_server:
		_rpc_turn_changed.rpc(next_player_id, help_dict, closed_indices)

@rpc("authority", "reliable")
func _rpc_turn_changed(next_player_id: int, help_dict: Dictionary, closed_indices: Array) -> void:
	GameManager.handle_remote_turn_changed(next_player_id, help_dict, closed_indices)

## Уведомить об использовании карты помощи
func broadcast_help_used(player_id: int, help_dict: Dictionary, target: int, new_animal: int) -> void:
	if is_server:
		_rpc_help_used.rpc(player_id, help_dict, target, new_animal)

@rpc("authority", "reliable")
func _rpc_help_used(player_id: int, help_dict: Dictionary, _target: int, _new_animal: int) -> void:
	var help_card = HD_Script.from_dict(help_dict)
	GameManager.help_card_used.emit(player_id, help_card)  # → обновить визуал карты

## Уведомить о конце игры
func broadcast_game_over(winner_id: int, scores: Dictionary) -> void:
	if is_server:
		_rpc_game_over.rpc(winner_id, scores)

@rpc("authority", "reliable")
func _rpc_game_over(winner_id: int, scores: Dictionary) -> void:
	GameManager.state.game_over = true
	GameManager.game_over_signal.emit(winner_id, scores)  # → переход к results

# =============================================
# ЛОББИ
# =============================================

## Хост начинает игру (после того как нужное число клиентов подключилось)
func host_start_game(with_help_cards: bool = true) -> void:
	if not is_server:
		return
	# Собрать всех игроков: хост (1) + клиенты
	var player_ids: Array[int] = [1]
	for pid in connected_peers:
		player_ids.append(pid)
	GameManager.start_new_game(player_ids, with_help_cards)

# =============================================
# УТИЛИТЫ
# =============================================

## Найти локальный IP-адрес в LAN-сети для показа другим игрокам
func _get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# Ищем IPv4 адрес локальной сети (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"  # Fallback: loopback (для тестирования на одном устройстве)

## Получить количество подключённых игроков (включая хоста)
func get_connected_player_count() -> int:
	return connected_peers.size() + (1 if is_server else 0)

## Проверить: активно ли сетевое соединение
func is_network_connected() -> bool:
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
