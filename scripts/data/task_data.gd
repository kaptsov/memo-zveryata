extends Resource

## TaskData — данные карты задания

enum TaskType { SIMPLE, HARD }

@export var task_id: int = -1
@export var task_type: int = 0
@export var points: int = 1
@export var is_active: bool = false
@export var is_completed: bool = false
@export var required_animal: int = 0
@export var required_season: int = 0

func check_simple(cards: Array) -> bool:
	if task_type != TaskType.SIMPLE:
		return false
	if cards.size() != 2:
		return false
	var a = cards[0]
	var b = cards[1]
	return (a.animal_type == b.animal_type
		and a.season == b.season
		and a.animal_type == required_animal
		and a.season == required_season)

func check_hard(cards: Array) -> bool:
	if task_type != TaskType.HARD:
		return false
	if cards.size() != 4:
		return false
	var animals: Array = []
	for card in cards:
		if card.animal_type in animals:
			return false
		animals.append(card.animal_type)
	for card in cards:
		if card.season != required_season:
			return false
	return true

func get_description_ru() -> String:
	var CD = load("res://scripts/data/card_data.gd")
	if task_type == TaskType.SIMPLE:
		var card_temp = CD.new()
		card_temp.animal_type = required_animal
		card_temp.season = required_season
		return "Найди двух %s (%s)" % [
			card_temp.get_animal_name_ru().to_lower(),
			card_temp.get_season_name_ru().to_lower()
		]
	else:
		var card_temp = CD.new()
		card_temp.season = required_season
		return "Найди 4 разных зверят (%s)" % card_temp.get_season_name_ru().to_lower()

func to_dict() -> Dictionary:
	return {
		"task_id": task_id, "task_type": task_type, "points": points,
		"is_active": is_active, "is_completed": is_completed,
		"required_animal": required_animal, "required_season": required_season,
	}

static func from_dict(data: Dictionary):
	var script = load("res://scripts/data/task_data.gd")
	var task = script.new()
	task.task_id = data.get("task_id", -1)
	task.task_type = data.get("task_type", 0)
	task.points = data.get("points", 1)
	task.is_active = data.get("is_active", false)
	task.is_completed = data.get("is_completed", false)
	task.required_animal = data.get("required_animal", 0)
	task.required_season = data.get("required_season", 0)
	return task
