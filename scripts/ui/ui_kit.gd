extends Node
## Автозагрузка UIKit: тема интерфейса и маленькие фабрики виджетов.

const DARK := Color("2b2036")
const PAPER := Color("fff6e3")
const BTN := Color("ffd98a")
const BTN_HOVER := Color("ffe8b3")
const BTN_PRESS := Color("f0bd62")
const BTN_OFF := Color("e3dccd")
const ACCENT := Color("ff8f7a")


func box(bg: Color, border := DARK, border_w := 2, radius := 3, pad := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = false
	s.set_content_margin_all(pad)
	return s


func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	t.set_stylebox("panel", "PanelContainer", box(PAPER, DARK, 3, 4, 8))
	t.set_stylebox("panel", "Panel", box(PAPER, DARK, 3, 4, 8))
	t.set_stylebox("normal", "Button", box(BTN))
	t.set_stylebox("hover", "Button", box(BTN_HOVER))
	t.set_stylebox("pressed", "Button", box(BTN_PRESS))
	t.set_stylebox("disabled", "Button", box(BTN_OFF, Color("8f8699")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", DARK)
	t.set_color("font_disabled_color", "Button", Color("8f8699"))
	t.set_color("font_color", "Label", DARK)
	t.set_stylebox("normal", "LineEdit", box(Color.WHITE))
	t.set_stylebox("focus", "LineEdit", box(Color.WHITE, ACCENT))
	t.set_color("font_color", "LineEdit", DARK)
	t.set_color("caret_color", "LineEdit", DARK)
	t.set_color("font_placeholder_color", "LineEdit", Color("a89fb0"))
	t.set_color("font_color", "CheckButton", DARK)
	t.set_color("font_hover_color", "CheckButton", DARK)
	t.set_color("font_pressed_color", "CheckButton", DARK)
	t.set_color("font_hover_pressed_color", "CheckButton", DARK)
	t.set_color("font_focus_color", "CheckButton", DARK)
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	t.set_stylebox("slider", "HSlider", box(Color("e0d4bd"), DARK, 1, 2, 2))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, DARK, 1, 2, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(BTN_PRESS, DARK, 1, 2, 2))
	t.set_stylebox("panel", "TooltipPanel", box(PAPER))
	t.set_color("font_color", "TooltipLabel", DARK)
	return t


func label(text: String, size := 14, color := DARK, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", DARK)
	return l


func button(text: String, icon_path := "", callback := Callable(), vertical := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if icon_path != "":
		b.icon = Art.scaled(icon_path, 2)
		b.expand_icon = false
		if vertical:
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	if callback.is_valid():
		b.pressed.connect(callback)
	b.pressed.connect(func(): Audio.play("sfx_click", 0.02, 0.6))
	return b


## Иконка из спрайта, увеличенная в scale раз (пиксели остаются чёткими).
func icon(path: String, scale := 2.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Art.tex(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = r.texture.get_size() * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Иконка, вписанная в box_size: мелкие увеличиваются целым масштабом, крупные уменьшаются.
func icon_fit(path: String, box_size: Vector2) -> TextureRect:
	var ts: Vector2 = Art.tex(path).get_size()
	var ratio := minf(box_size.x / ts.x, box_size.y / ts.y)
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ratio >= 1.0:
		r.texture = Art.scaled(path, int(floorf(ratio)))
		r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	else:
		r.texture = Art.tex(path)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = box_size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Цветная кнопка-образец для выбора цвета.
func swatch(color: Color, selected: bool, callback: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(24, 24)
	b.focus_mode = Control.FOCUS_NONE
	var border := Color.WHITE if selected else DARK
	var bw := 3 if selected else 2
	b.add_theme_stylebox_override("normal", box(color, border, bw, 3, 0))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15), border, bw, 3, 0))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.1), border, bw, 3, 0))
	b.pressed.connect(callback)
	b.pressed.connect(func(): Audio.play("sfx_click", 0.02, 0.6))
	return b


## Полноэкранная затемняющая подложка для оверлеев.
func dimmer() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.1, 0.07, 0.15, 0.55)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


## Корневой Control на весь экран с темой.
func root_control() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.theme = make_theme()
	return c
