extends Control

## Encyclopedia.gd
## Экран "О зверятах": 8 карточек животных в прокручиваемой сетке 2 колонки.
## Нажатие на карточку → анимация переворота: картинка ↔ текст с фактами.
##
## Ключевые технические детали:
## - TextureRect.expand_mode = EXPAND_IGNORE_SIZE — обязательно для крупных спрайтов (512px+),
##   иначе контрол принимает натуральный размер текстуры и выламывает сетку.
## - Высота карточки фиксирована (_card_h = card_w * 1.25), SIZE_SHRINK_BEGIN по вертикали.
## - Анимация: await tween.finished + флаг _flipping[i] (tween_callback нестабилен в dev6).
## - Тап vs свайп: флаг _dragging[i] + MOUSE_FILTER_PASS на обёртке карточки.

# Кнопка "Назад" из сцены encyclopedia.tscn
@onready var back_button: Button = $VBox/BackButton

# Данные о каждом животном
const ANIMAL_INFO = [
	{
		"name": "Манул",
		"latin": "Otocolobus manul",
		"description": "Самый пушистый дикий кот в мире — его шерсть в два раза длиннее, чем у домашней кошки! Живёт в степях и горах Центральной Азии.\n\n🐾 Интересные факты:\n• У манула круглые зрачки — почти как у людей, а не щелевидные, как у большинства кошек.\n• Умеет корчить забавные «рожи» — выглядит то сердитым, то удивлённым.\n• Охотится исключительно ночью, а днём спит в чужих норах или расщелинах скал.\n• Очень тихий и скрытный — учёные долго не могли его сфотографировать в дикой природе.\n• Занесён в Красную книгу России.",
		"sprite": "manul",
	},
	{
		"name": "Сайгак",
		"latin": "Saiga tatarica",
		"description": "Степная антилопа с необычным горбатым носом-«хоботком». Жила ещё в эпоху мамонтов — это настоящий «живой ископаемый»!\n\n🐾 Интересные факты:\n• Нос-хоботок работает как кондиционер: зимой согревает холодный воздух, летом фильтрует степную пыль.\n• Бегает со скоростью до 80 км/ч — быстрее гоночного велосипеда!\n• Каждый год совершает миграцию на сотни километров в поисках корма.\n• Рога есть только у самцов и немного похожи на лиру.\n• Занесён в Красную книгу России.",
		"sprite": "saiga",
	},
	{
		"name": "Выхухоль",
		"latin": "Desmana moschata",
		"description": "Крошечный водный зверёк с вытянутым хоботком — родственник крота. Один из самых редких зверей России!\n\n🐾 Интересные факты:\n• Почти слепой, но зато хоботок — суперчувствительный орган: находит добычу под водой на ощупь.\n• Съедает за день столько еды, сколько весит сам — примерно 500 граммов!\n• Строит нору с подводным входом, чтобы хищники не добрались.\n• Умеет закрывать ноздри и уши, когда ныряет.\n• Водится только в России — нигде больше в мире!\n• Занесён в Красную книгу России.",
		"sprite": "desman",
	},
	{
		"name": "Утка-мандаринка",
		"latin": "Aix galericulata",
		"description": "Самая красивая утка в мире! Самец покрыт ярчайшим оперением — оранжевым, зелёным, фиолетовым. Самка скромная — серо-коричневая.\n\n🐾 Интересные факты:\n• Названа в честь китайских чиновников-мандаринов, которые носили яркие расшитые халаты.\n• Гнездится не на земле, а в дуплах деревьев — иногда на высоте 10 метров!\n• Птенцы в первый день жизни прыгают из гнезда вниз — и не разбиваются, потому что очень лёгкие.\n• В Китае и Японии считается символом верной любви и счастливого брака.\n• Гнездится на Дальнем Востоке России.\n• Занесён в Красную книгу России.",
		"sprite": "mandarin_duck",
	},
	{
		"name": "Ирбис",
		"latin": "Uncia uncia",
		"description": "Горный кот с пятнистой шубой и огромным хвостом — почти таким же длинным, как само тело! Живёт высоко в горах Алтая и Саян.\n\n🐾 Интересные факты:\n• Хвост ирбиса длиной до 90 сантиметров. Кот оборачивает им нос как шарфом, чтобы не мёрзнуть!\n• Умеет прыгать на 9 метров в длину — это как три больших дивана!\n• Очень тихий: ирбис не рычит, только мурлычет, как домашняя кошка.\n• Лапы такие широкие, что кот не проваливается в снег — природные снегоступы!\n• Один из самых редких хищников планеты — их осталось меньше 4 тысяч.\n• Занесён в Красную книгу России.",
		"sprite": "snow_leopard",
	},
	{
		"name": "Белая куропатка",
		"latin": "Lagopus lagopus rossicus",
		"description": "Птица-волшебница! Летом она коричнево-рыжая, а зимой становится белоснежной — меняет «одёжку» как по мановению волшебной палочки.\n\n🐾 Интересные факты:\n• Ноги покрыты перьями до самых когтей — как меховые сапожки-снегоступы!\n• Зимой зарывается в снег и ночует там — снег её согревает, как одеяло.\n• Умеет выдерживать морозы до −50°C — холоднее, чем в морозилке!\n• Летом откладывает до 12 яиц сразу — большая семья!\n• Живёт стаями — вместе теплее и безопаснее.\n• Занесён в Красную книгу России.",
		"sprite": "ptarmigan",
	},
	{
		"name": "Амурский тигр",
		"latin": "Panthera tigris altaica",
		"description": "Самая большая кошка в мире! Амурский тигр живёт в дальневосточной тайге и не боится ни морозов, ни снега — его густая шуба спасает даже при −40°C.\n\n🐾 Интересные факты:\n• Шерсть тигра намного толще, чем у его южных сородичей — специальная защита от сибирских морозов.\n• Любит воду и отлично плавает — переплывает широкие реки запросто!\n• Каждый тигр уникален: полосы у всех разные, как отпечатки пальцев у людей.\n• Территория одного тигра — до 1000 км². Это как весь город Москва и ещё столько же!\n• В дикой природе осталось около 500 амурских тигров — почти все живут в России.\n• Занесён в Красную книгу России.",
		"sprite": "amur_tiger",
	},
	{
		"name": "Горный козёл",
		"latin": "Capra sibirica",
		"description": "Горный акробат! Этот козёл карабкается по отвесным скалам, где не удержится ни один человек. Огромные рога — его главное украшение и оружие.\n\n🐾 Интересные факты:\n• Может стоять на уступе шириной всего 10 сантиметров — как на краю линейки!\n• Рога самца вырастают до 1,5 метра — длиннее, чем у любой другой козы в мире.\n• Прыгает на 5 метров между скалами — ни разу не промахнулся!\n• Зимой копытами разгребает снег в поисках травы.\n• Осенью самцы стукаются рогами так громко, что слышно за километр.\n• Занесён в Красную книгу России.",
		"sprite": "siberian_ibex",
	},
]

# true = карточка перевёрнута (показывает текст), false = показывает картинку
var _flipped: Array = []
var _flipping: Array = []  # блокировка повторных тапов во время анимации
var _dragging: Array = []  # флаг: был ли свайп в этом касании (чтобы не flipить при скролле)

# Пары [face_node, back_node] для каждой карточки
var _card_nodes: Array = []

# Размеры шрифтов и карточки — вычисляются в _ready() по ширине экрана
var _font_name: int = 18
var _font_latin: int = 12
var _font_desc: int = 11
var _card_h: float = 220  # фиксированная высота карточки (не зависит от числа строк)

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	# Скрываем оригинальный ScrollContainer из сцены — он нам не нужен
	var old_scroll = get_node_or_null("VBox/Scroll")
	if old_scroll:
		old_scroll.visible = false
	_compute_font_sizes()
	_build_grid()

## Вычислить размеры шрифтов и карточки пропорционально ширине экрана
func _compute_font_sizes() -> void:
	var vp_w: float = get_viewport().size.x
	var card_w: float = (vp_w - 24.0) / 2.0  # 2 столбца, ~8px отступы и разделитель
	_card_h = card_w * 1.25  # соотношение сторон как у карточек в игре
	_font_name  = clamp(int(card_w * 0.07),  14, 30)
	_font_latin = clamp(int(card_w * 0.038),  9, 14)
	_font_desc  = clamp(int(card_w * 0.050),  9, 18)

func _build_grid() -> void:
	# Инициализируем массивы динамически по числу животных
	_flipped.resize(ANIMAL_INFO.size())
	_flipped.fill(false)
	_flipping.resize(ANIMAL_INFO.size())
	_flipping.fill(false)
	_dragging.resize(ANIMAL_INFO.size())
	_dragging.fill(false)

	# ScrollContainer — вертикальный свайп по всем карточкам
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$VBox.add_child(scroll)
	$VBox.move_child(scroll, 0)  # до BackButton

	# GridContainer — сетка 2 колонки
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for i in range(ANIMAL_INFO.size()):
		var result = _create_card(i)  # возвращает [wrapper, face, back]
		grid.add_child(result[0])
		_card_nodes.append([result[1], result[2]])

## Создаёт одну карточку животного. Возвращает [wrapper, face_node, back_node].
func _create_card(index: int) -> Array:
	var info = ANIMAL_INFO[index]

	# --- ОБЁРТКА --- фиксированная высота по ширине экрана, растягивается по ширине колонки
	var wrapper = Control.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # НЕ растягиваться по высоте
	wrapper.custom_minimum_size = Vector2(0, _card_h)        # фиксированная высота
	# MOUSE_FILTER_PASS: wrapper получает события И пропускает их к ScrollContainer
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

	# --- ЛИЦЕВАЯ СТОРОНА: картинка (без отступов PanelContainer) ---
	var face = Control.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex = TextureRect.new()
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# expand_mode=IGNORE_SIZE: TextureRect может быть меньше натурального размера текстуры.
	# Это ключевое исправление для спрайтов 1280×1280 — без него они выламывают ячейку.
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path = "res://assets/sprites/animals/%s_summer.png" % info["sprite"]
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	face.add_child(tex)

	# Подпись с именем поверх картинки
	var name_overlay = Label.new()
	name_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_overlay.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_overlay.add_theme_font_size_override("font_size", _font_name)
	name_overlay.add_theme_color_override("font_color", Color.WHITE)
	name_overlay.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_overlay.add_theme_constant_override("shadow_offset_x", 1)
	name_overlay.add_theme_constant_override("shadow_offset_y", 1)
	name_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(name_overlay)

	wrapper.add_child(face)

	# --- ОБРАТНАЯ СТОРОНА: текст (изначально скрыта) ---
	var back = PanelContainer.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.visible = false
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mg = MarginContainer.new()
	mg.add_theme_constant_override("margin_left", 8)
	mg.add_theme_constant_override("margin_right", 8)
	mg.add_theme_constant_override("margin_top", 6)
	mg.add_theme_constant_override("margin_bottom", 6)
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(mg)

	var scroll_back = ScrollContainer.new()
	scroll_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_back.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_back.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg.add_child(scroll_back)

	var tvb = VBoxContainer.new()
	tvb.add_theme_constant_override("separation", 4)
	tvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_back.add_child(tvb)

	# Название
	var nlbl = Label.new()
	nlbl.text = info["name"]
	nlbl.add_theme_font_size_override("font_size", _font_name)
	nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tvb.add_child(nlbl)

	# Латинское название
	var llbl = Label.new()
	llbl.text = info["latin"]
	llbl.add_theme_font_size_override("font_size", _font_latin)
	llbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	llbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tvb.add_child(llbl)

	# Разделитель
	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tvb.add_child(sep)

	# Описание
	var dlbl = Label.new()
	dlbl.text = info["description"]
	dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	dlbl.add_theme_font_size_override("font_size", _font_desc)
	dlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tvb.add_child(dlbl)

	wrapper.add_child(back)

	# Обработка касания: переворачиваем только если это тап, а не свайп-скролл
	wrapper.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenDrag:
			# Пользователь свайпит — помечаем как скролл, не переворачиваем
			_dragging[index] = true
		elif event is InputEventScreenTouch:
			if event.pressed:
				_dragging[index] = false  # начало нового касания
			elif not _dragging[index]:
				_flip_card(index)         # тап без свайпа — переворачиваем
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_flip_card(index)         # клик мышью (десктоп-тест)
	)

	return [wrapper, face, back]

## Переворачивает карточку с анимацией масштаба по X
func _flip_card(index: int) -> void:
	if _flipping[index]:
		return  # игнорируем тапы во время анимации
	_flipping[index] = true
	_flipped[index] = not _flipped[index]
	var face = _card_nodes[index][0]
	var back = _card_nodes[index][1]
	var wrapper = face.get_parent()
	var show_back: bool = _flipped[index]

	# Фаза 1: сжать карточку до нуля
	var t1 = create_tween()
	t1.tween_property(wrapper, "scale:x", 0.0, 0.15)
	await t1.finished

	# Переключить стороны при нулевом масштабе (невидимый момент)
	face.visible = not show_back
	back.visible = show_back

	# Фаза 2: развернуть обратно
	var t2 = create_tween()
	t2.tween_property(wrapper, "scale:x", 1.0, 0.15)
	await t2.finished

	_flipping[index] = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
