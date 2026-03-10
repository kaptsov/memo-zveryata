extends Resource

## HelpCardData — данные карты помощи

enum HelpType { EXTRA_FLIP, CHANGE_ANIMAL, CHANGE_SEASON }

@export var help_id: int = -1
@export var help_type: int = 0

func get_type_name() -> String:
	match help_type:
		HelpType.EXTRA_FLIP: return "extra_flip"
		HelpType.CHANGE_ANIMAL: return "change_animal"
		HelpType.CHANGE_SEASON: return "change_season"
	return "unknown"

func get_type_name_ru() -> String:
	match help_type:
		HelpType.EXTRA_FLIP: return "Откройте ещё одну карту"
		HelpType.CHANGE_ANIMAL: return "Превратите зверька в другого"
		HelpType.CHANGE_SEASON: return "Поменяйте фон"
	return "Неизвестно"

func get_description_ru() -> String:
	match help_type:
		HelpType.EXTRA_FLIP: return "+1 карта к лимиту хода"
		HelpType.CHANGE_ANIMAL: return "Считать зверька на одной открытой карте другим зверьком"
		HelpType.CHANGE_SEASON: return "Считать летний фон зимним и наоборот на одной карте"
	return ""

func get_icon_path() -> String:
	return "res://assets/sprites/help/%s.png" % get_type_name()

func to_dict() -> Dictionary:
	return { "help_id": help_id, "help_type": help_type }

static func from_dict(data: Dictionary):
	var script = load("res://scripts/data/help_card_data.gd")
	var card = script.new()
	card.help_id = data.get("help_id", -1)
	card.help_type = data.get("help_type", 0)
	return card
