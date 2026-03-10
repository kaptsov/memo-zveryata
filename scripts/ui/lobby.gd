extends Control

## Lobby.gd

@onready var mode_buttons: VBoxContainer = $VBox/ModeButtons
@onready var host_button: Button = $VBox/ModeButtons/HostButton
@onready var join_button: Button = $VBox/ModeButtons/JoinButton
@onready var host_panel: VBoxContainer = $VBox/HostPanel
@onready var ip_display: Label = $VBox/HostPanel/IPDisplay
@onready var waiting_label: Label = $VBox/HostPanel/WaitingLabel
@onready var copy_log_button: Button = $VBox/HostPanel/CopyLogButton
@onready var help_cards_check: CheckBox = $VBox/HostPanel/HelpCardsCheck
@onready var start_button: Button = $VBox/HostPanel/StartButton
@onready var join_panel: VBoxContainer = $VBox/JoinPanel
@onready var ip_input: LineEdit = $VBox/JoinPanel/IPInput
@onready var connect_button: Button = $VBox/JoinPanel/ConnectButton
@onready var join_status: Label = $VBox/JoinPanel/Status
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	host_panel.visible = false
	join_panel.visible = false
	start_button.disabled = true
	help_cards_check.button_pressed = true
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	back_button.pressed.connect(_on_back_pressed)
	copy_log_button.pressed.connect(_on_copy_log_pressed)
	
	# Сигналы сети — безопасное подключение (не дублируем)
	_safe_connect(NetworkManager.player_connected, _on_player_connected)
	_safe_connect(NetworkManager.player_disconnected, _on_player_disconnected)
	_safe_connect(NetworkManager.connected_to_server, _on_connected)
	_safe_connect(NetworkManager.connection_failed, _on_connection_failed)
	_safe_connect(GameManager.game_started_signal, _on_game_started)
	
	# Авто-режим из меню
	if GameManager.has_meta("lobby_mode"):
		var mode = GameManager.get_meta("lobby_mode")
		GameManager.remove_meta("lobby_mode")
		if mode == "host":
			call_deferred("_on_host_pressed")
		elif mode == "join":
			call_deferred("_on_join_pressed")

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

func _exit_tree() -> void:
	# Отключаем сигналы при уходе со сцены
	_safe_disconnect(NetworkManager.player_connected, _on_player_connected)
	_safe_disconnect(NetworkManager.player_disconnected, _on_player_disconnected)
	_safe_disconnect(NetworkManager.connected_to_server, _on_connected)
	_safe_disconnect(NetworkManager.connection_failed, _on_connection_failed)
	_safe_disconnect(GameManager.game_started_signal, _on_game_started)

func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)

# --- Хост ---

func _on_host_pressed() -> void:
	mode_buttons.visible = false
	host_panel.visible = true
	DebugLog.log_info("Нажата кнопка 'Создать игру'")
	var err = NetworkManager.create_server()
	if err != OK:
		ip_display.text = "Ошибка сервера: код %d\n(%s)" % [err, error_string(err)]
		waiting_label.text = DebugLog.get_last_lines(8)
		copy_log_button.visible = true
		return
	copy_log_button.visible = false
	ip_display.text = "IP: %s" % NetworkManager._get_local_ip()
	waiting_label.text = "Ожидание игрока..."

func _on_copy_log_pressed() -> void:
	var full_log = DebugLog.get_last_lines(50)
	DisplayServer.clipboard_set(full_log)
	copy_log_button.text = "Скопировано!"
	await get_tree().create_timer(2.0).timeout
	copy_log_button.text = "Скопировать лог"

func _on_player_connected(_peer_id: int) -> void:
	var count = NetworkManager.connected_peers.size()
	waiting_label.text = "Подключено игроков: %d ✓" % count
	start_button.disabled = false

func _on_player_disconnected(_peer_id: int) -> void:
	var count = NetworkManager.connected_peers.size()
	if count == 0:
		waiting_label.text = "Ожидание игроков..."
		start_button.disabled = true
	else:
		waiting_label.text = "Подключено игроков: %d" % count

func _on_start_pressed() -> void:
	NetworkManager.host_start_game(help_cards_check.button_pressed)

# --- Клиент ---

func _on_join_pressed() -> void:
	mode_buttons.visible = false
	join_panel.visible = true
	join_status.text = ""

func _on_connect_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		join_status.text = "Введите IP адрес"
		return
	join_status.text = "Подключение..."
	connect_button.disabled = true
	var err = NetworkManager.join_server(ip)
	if err != OK:
		join_status.text = "Ошибка подключения"
		connect_button.disabled = false

func _on_connected() -> void:
	join_status.text = "Подключено! Ожидание начала игры..."

func _on_connection_failed() -> void:
	join_status.text = "Не удалось подключиться"
	connect_button.disabled = false

# --- Навигация ---

func _on_game_started() -> void:
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _on_back_pressed() -> void:
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
