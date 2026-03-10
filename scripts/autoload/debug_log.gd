extends Node

## DebugLog (Autoload)
## Пишет логи в user://debug.log и в print().
## На Android файл лежит в /sdcard/Android/data/ru.memo.zveryata/files/debug.log

const LOG_PATH = "user://debug.log"
const MAX_LINES = 500

var _lines: Array[String] = []
var _file: FileAccess = null

func _ready() -> void:
	# Открываем файл (перезапись при каждом старте приложения)
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	log_info("=== Мемо Зверята запущен ===")
	log_info("OS: %s | версия: %s" % [OS.get_name(), Engine.get_version_info().get("string", "?")])
	log_info("user:// = %s" % OS.get_user_data_dir())
	_log_network_info()

func _log_network_info() -> void:
	log_network_info()

func log_network_info() -> void:
	var addrs = IP.get_local_addresses()
	log_info("Сетевые адреса (%d): %s" % [addrs.size(), str(addrs)])
	# Фильтруем LAN-адреса вручную
	var lan_addrs: Array = []
	for a in addrs:
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			lan_addrs.append(a)
	log_info("LAN-адреса: %s" % str(lan_addrs))
	# Интерфейсы
	var ifaces = IP.get_local_interfaces()
	log_info("Интерфейсов: %d" % ifaces.size())
	for iface in ifaces:
		log_info("  Интерфейс '%s': %s" % [iface.get("name", "?"), str(iface.get("addresses", []))])

func log_info(msg: String) -> void:
	_write("[INFO] " + msg)

func log_error(msg: String) -> void:
	_write("[ERROR] " + msg)

func log_warn(msg: String) -> void:
	_write("[WARN] " + msg)

func _write(msg: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	var line = "%s %s" % [timestamp, msg]
	print(line)
	_lines.append(line)
	if _lines.size() > MAX_LINES:
		_lines.pop_front()
	if _file:
		_file.store_line(line)
		_file.flush()

func get_last_lines(n: int = 30) -> String:
	var start = max(0, _lines.size() - n)
	return "\n".join(_lines.slice(start))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _file:
			_file.close()
			_file = null
