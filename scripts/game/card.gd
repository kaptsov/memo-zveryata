extends Control

## Card.gd — визуальное представление карты зверят

const CardDataScript = preload("res://scripts/data/card_data.gd")

signal card_pressed(card_index: int)

@export var card_index: int = -1

var card_data = null
var is_face_up: bool = false
var is_animating: bool = false
var is_interactive: bool = true

@onready var card_back: Control = $CardBack
@onready var card_face: Control = $CardFace
@onready var highlight: Panel = $Highlight
@onready var anim_player: AnimationPlayer = $AnimationPlayer

const SEASON_COLORS = {
	"summer": Color(0.55, 0.82, 0.45, 1),
	"winter": Color(0.65, 0.82, 0.95, 1),
}
const ANIMAL_EMOJI = {
	"manul": "🐱", "saiga": "🦌", "desman": "🐭", "mandarin_duck": "🦆",
}

func _ready() -> void:
	card_face.visible = false
	card_back.visible = true
	highlight.visible = false
	gui_input.connect(_on_gui_input)
	
	# Загрузить текстуру рубашки
	var back_tex_path = "res://assets/sprites/cards/card_back.png"
	if ResourceLoader.exists(back_tex_path):
		var back_tex_rect = card_back as TextureRect
		if back_tex_rect:
			back_tex_rect.texture = load(back_tex_path)
			# Скрыть placeholder элементы
			var back_color = card_back.get_node_or_null("BackColor")
			if back_color: back_color.visible = false
			var back_label = card_back.get_node_or_null("BackLabel")
			if back_label: back_label.visible = false

func setup(index: int, data) -> void:
	card_index = index
	card_data = data
	
	# Попробовать загрузить спрайт лицевой стороны
	var sprite_path = data.get_sprite_path()
	if ResourceLoader.exists(sprite_path):
		var face_tex_rect = card_face as TextureRect
		if face_tex_rect:
			face_tex_rect.texture = load(sprite_path)
			# Скрыть placeholder элементы
			var face_color = card_face.get_node_or_null("FaceColor")
			if face_color: face_color.visible = false
			var face_label = card_face.get_node_or_null("FaceLabel")
			if face_label: face_label.visible = false
			return
	
	# Fallback: placeholder
	_setup_placeholder(data)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_interactive and not is_animating:
				card_pressed.emit(card_index)

func flip_face_up() -> void:
	if is_face_up or is_animating:
		return
	is_animating = true
	is_face_up = true
	var tween = create_tween()
	tween.tween_property(self, "scale:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(_show_face)
	tween.tween_property(self, "scale:x", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): is_animating = false)
	AudioManager.play_sfx("card_flip")

func flip_face_down() -> void:
	if not is_face_up or is_animating:
		return
	is_animating = true
	is_face_up = false
	var tween = create_tween()
	tween.tween_property(self, "scale:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(_show_back)
	tween.tween_property(self, "scale:x", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): is_animating = false)

func _show_face() -> void:
	card_back.visible = false
	card_face.visible = true

func _show_back() -> void:
	card_back.visible = true
	card_face.visible = false

func set_highlighted(enabled: bool) -> void:
	highlight.visible = enabled

func shake() -> void:
	var tween = create_tween()
	var orig_pos = position
	tween.tween_property(self, "position:x", orig_pos.x + 8, 0.05)
	tween.tween_property(self, "position:x", orig_pos.x - 8, 0.1)
	tween.tween_property(self, "position:x", orig_pos.x + 4, 0.1)
	tween.tween_property(self, "position:x", orig_pos.x, 0.05)

func update_face(data) -> void:
	card_data = data
	var sprite_path = data.get_sprite_path()
	if ResourceLoader.exists(sprite_path):
		var face_tex_rect = card_face as TextureRect
		if face_tex_rect:
			face_tex_rect.texture = load(sprite_path)
	else:
		_setup_placeholder(data)

func set_interactive(enabled: bool) -> void:
	is_interactive = enabled
	modulate.a = 1.0 if enabled else 0.6

func _setup_placeholder(data) -> void:
	var color_rect = card_face.get_node_or_null("FaceColor")
	if color_rect:
		color_rect.color = SEASON_COLORS.get(data.get_season_name(), Color.WHITE)
	var face_label = card_face.get_node_or_null("FaceLabel")
	if face_label:
		var emoji = ANIMAL_EMOJI.get(data.get_animal_name(), "❓")
		face_label.text = "%s\n%s\n%s" % [emoji, data.get_animal_name_ru(), data.get_season_name_ru()]
		face_label.add_theme_font_size_override("font_size", 16)
