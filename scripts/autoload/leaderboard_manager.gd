extends Node

## LeaderboardManager (Autoload)
## HTTP-клиент для таблицы лидеров на sweateratops.ru.
## Регистрировать в Godot: Project → Project Settings → Autoload
##   Path: res://scripts/autoload/leaderboard_manager.gd
##   Name: LeaderboardManager

const API_URL = "https://sweateratops.ru/api/leaderboard"
const PLAYER_NAME_FILE = "user://player_name.dat"

signal leaderboard_fetched(entries: Array)  # [{name, score, rank}, ...]
signal score_submitted(rank: int, total: int)
signal request_failed()

var _http_fetch: HTTPRequest
var _http_submit: HTTPRequest

func _ready() -> void:
	_http_fetch = HTTPRequest.new()
	add_child(_http_fetch)
	_http_fetch.request_completed.connect(_on_fetch_completed)

	_http_submit = HTTPRequest.new()
	add_child(_http_submit)
	_http_submit.request_completed.connect(_on_submit_completed)

## Получить топ-10 для заданной сложности ("2x2", "3x4", "4x4", "4x5")
func fetch(difficulty: String) -> void:
	var url = API_URL + "?difficulty=" + difficulty
	_http_fetch.cancel_request()
	_http_fetch.request(url)

## Отправить результат на сервер
func submit(difficulty: String, player_name: String, score: int) -> void:
	var body = JSON.stringify({
		"difficulty": difficulty,
		"player_name": player_name,
		"score": score,
	})
	var headers = ["Content-Type: application/json"]
	_http_submit.cancel_request()
	_http_submit.request(API_URL, headers, HTTPClient.METHOD_POST, body)

## Сохранить имя игрока локально
func save_player_name(name: String) -> void:
	var f = FileAccess.open(PLAYER_NAME_FILE, FileAccess.WRITE)
	if f:
		f.store_string(name.strip_edges())
		f.close()

## Загрузить имя игрока (пустая строка если не сохранено)
func load_player_name() -> String:
	if not FileAccess.file_exists(PLAYER_NAME_FILE):
		return ""
	var f = FileAccess.open(PLAYER_NAME_FILE, FileAccess.READ)
	if f:
		var name = f.get_as_text().strip_edges()
		f.close()
		return name
	return ""

func _on_fetch_completed(result: int, response_code: int, _headers, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		request_failed.emit()
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		request_failed.emit()
		return
	var data = json.get_data()
	if data is Array:
		leaderboard_fetched.emit(data)
	else:
		request_failed.emit()

func _on_submit_completed(result: int, response_code: int, _headers, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		request_failed.emit()
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		request_failed.emit()
		return
	var data = json.get_data()
	if data is Dictionary:
		score_submitted.emit(data.get("rank", 0), data.get("total", 0))
	else:
		request_failed.emit()
