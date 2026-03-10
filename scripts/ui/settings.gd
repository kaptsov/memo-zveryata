extends Control

## Settings.gd
## Настройки: громкость музыки, звуков, режим заданий.

@onready var bgm_slider: HSlider = $VBox/BGMRow/Slider
@onready var sfx_slider: HSlider = $VBox/SFXRow/Slider
@onready var task_mode_button: Button = $VBox/TaskModeRow/TaskModeButton
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.05
	bgm_slider.value = AudioManager.bgm_volume

	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = AudioManager.sfx_volume

	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	task_mode_button.pressed.connect(_on_task_mode_toggled)
	back_button.pressed.connect(_on_back)
	_update_task_mode_button()

func _on_bgm_changed(value: float) -> void:
	AudioManager.set_bgm_volume(value)

func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)

func _on_task_mode_toggled() -> void:
	AudioManager.set_task_random_mode(not AudioManager.task_random_mode)
	_update_task_mode_button()

func _update_task_mode_button() -> void:
	task_mode_button.text = "Рандомные" if AudioManager.task_random_mode else "Классические"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
