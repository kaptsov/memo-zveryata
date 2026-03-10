extends Resource

## CardData — данные одной карты зверят.
## 8 видов животных × 2 сезона × 2 копии (A/B).
## Спрайты: assets/sprites/animals/{animal_name}_{season_name}.png (512×512 PNG).
## Внимание: class_name НЕ используется — preload() везде.

enum AnimalType { MANUL, SAIGA, DESMAN, MANDARIN_DUCK, SNOW_LEOPARD, PTARMIGAN, AMUR_TIGER, SIBERIAN_IBEX }
enum Season { SUMMER, WINTER }

@export var card_id: int = -1
@export var animal_type: int = 0
@export var season: int = 0
@export var copy: String = "A"

func get_animal_name() -> String:
	match animal_type:
		AnimalType.MANUL: return "manul"
		AnimalType.SAIGA: return "saiga"
		AnimalType.DESMAN: return "desman"
		AnimalType.MANDARIN_DUCK: return "mandarin_duck"
		AnimalType.SNOW_LEOPARD: return "snow_leopard"
		AnimalType.PTARMIGAN: return "ptarmigan"
		AnimalType.AMUR_TIGER: return "amur_tiger"
		AnimalType.SIBERIAN_IBEX: return "siberian_ibex"
	return "unknown"

func get_animal_name_ru() -> String:
	match animal_type:
		AnimalType.MANUL: return "Манул"
		AnimalType.SAIGA: return "Сайгак"
		AnimalType.DESMAN: return "Выхухоль"
		AnimalType.MANDARIN_DUCK: return "Утка-мандаринка"
		AnimalType.SNOW_LEOPARD: return "Ирбис"
		AnimalType.PTARMIGAN: return "Куропатка"
		AnimalType.AMUR_TIGER: return "Амурский тигр"
		AnimalType.SIBERIAN_IBEX: return "Горный козёл"
	return "Неизвестно"

func get_season_name() -> String:
	match season:
		Season.SUMMER: return "summer"
		Season.WINTER: return "winter"
	return "unknown"

func get_season_name_ru() -> String:
	match season:
		Season.SUMMER: return "Лето"
		Season.WINTER: return "Зима"
	return "Неизвестно"

func get_sprite_path() -> String:
	return "res://assets/sprites/animals/%s_%s.png" % [get_animal_name(), get_season_name()]

func matches(other) -> bool:
	return animal_type == other.animal_type and season == other.season

func to_dict() -> Dictionary:
	return { "card_id": card_id, "animal_type": animal_type, "season": season, "copy": copy }

static func from_dict(data: Dictionary):
	var script = load("res://scripts/data/card_data.gd")
	var card = script.new()
	card.card_id = data.get("card_id", -1)
	card.animal_type = data.get("animal_type", 0)
	card.season = data.get("season", 0)
	card.copy = data.get("copy", "A")
	return card
