extends Node

## AudioManager (Autoload)
## Управляет звуковыми эффектами и фоновой музыкой.

const SETTINGS_PATH = "user://settings.cfg"

var sfx_volume: float = 1.0
var bgm_volume: float = 0.7
var sfx_enabled: bool = true
var bgm_enabled: bool = true
var task_random_mode: bool = false  # false = классический, true = рандомный

func set_task_random_mode(value: bool) -> void:
	task_random_mode = value
	_save_settings()

var _bgm_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS: int = 8

func _ready() -> void:
	_load_settings()
	# BGM-плеер
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	
	# Пул SFX-плееров
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)

## Играть звуковой эффект
func play_sfx(sfx_name: String) -> void:
	if not sfx_enabled:
		return
	
	var path = "res://assets/audio/sfx/%s.ogg" % sfx_name
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/%s.wav" % sfx_name
	if not ResourceLoader.exists(path):
		push_warning("SFX не найден: %s" % sfx_name)
		return
	
	var stream = load(path)
	# Найти свободный плеер
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume)
			player.play()
			return
	
	# Все заняты — используем первый
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = linear_to_db(sfx_volume)
	_sfx_players[0].play()

## Играть фоновую музыку
func play_bgm(bgm_name: String) -> void:
	if not bgm_enabled:
		return

	var path = "res://assets/audio/bgm/%s.ogg" % bgm_name
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/bgm/%s.wav" % bgm_name
	if not ResourceLoader.exists(path):
		push_warning("BGM не найден: %s" % bgm_name)
		return
	
	var stream = load(path)
	if _bgm_player.stream == stream and _bgm_player.playing:
		return  # Уже играет
	
	_bgm_player.stream = stream
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	_bgm_player.play()

## Остановить музыку
func stop_bgm() -> void:
	_bgm_player.stop()

## Обновить громкость
func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_save_settings()

func set_bgm_volume(value: float) -> void:
	bgm_volume = clamp(value, 0.0, 1.0)
	if _bgm_player.playing:
		_bgm_player.volume_db = linear_to_db(bgm_volume)
	_save_settings()

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("game", "task_random_mode", task_random_mode)
	config.save(SETTINGS_PATH)

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	bgm_volume = config.get_value("audio", "bgm_volume", 0.7)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	task_random_mode = config.get_value("game", "task_random_mode", false)
