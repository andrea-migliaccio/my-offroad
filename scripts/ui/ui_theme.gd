class_name UITheme
extends RefCounted
## Pixel-style Theme for all menus: dark navy panels with a yellow frame,
## Press Start 2P at 16px, clear hover/focus states for mouse and keyboard.

const YELLOW := Color8(250, 214, 32)
const NAVY := Color8(14, 16, 44)
const NAVY_LIGHT := Color8(34, 38, 96)
const RED := Color8(220, 44, 32)
const GREEN := Color8(120, 255, 120)
const SKY := Color8(150, 190, 255)
const GRAY := Color8(150, 150, 166)


static func box(bg: Color, border: Color, width := 2, margin_h := 14, margin_v := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	# Hard pixel shadow under every box.
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(4, 4)
	return sb


static func build(font: Font) -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 16

	var normal := box(NAVY_LIGHT.darkened(0.25), Color8(80, 84, 150))
	var hover := box(NAVY_LIGHT, YELLOW)
	var pressed := box(RED, YELLOW)
	var disabled := box(Color8(30, 30, 44), Color8(56, 56, 70))
	for k in ["Button", "OptionButton"]:
		t.set_stylebox("normal", k, normal)
		t.set_stylebox("hover", k, hover)
		t.set_stylebox("pressed", k, pressed)
		t.set_stylebox("hover_pressed", k, pressed)
		t.set_stylebox("disabled", k, disabled)
		t.set_stylebox("focus", k, box(Color(0, 0, 0, 0), YELLOW))
		t.set_color("font_color", k, Color.WHITE)
		t.set_color("font_hover_color", k, YELLOW)
		t.set_color("font_focus_color", k, YELLOW)
		t.set_color("font_pressed_color", k, Color.WHITE)
		t.set_color("font_hover_pressed_color", k, Color.WHITE)
		t.set_color("font_disabled_color", k, Color8(90, 90, 104))
		t.set_constant("outline_size", k, 0)

	var panel := box(Color(NAVY, 0.94), YELLOW, 2, 18, 14)
	panel.shadow_size = 1
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0))
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)

	t.set_stylebox("normal", "LineEdit", box(Color8(6, 8, 24), YELLOW))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), YELLOW))
	t.set_color("font_color", "LineEdit", YELLOW)
	t.set_color("caret_color", "LineEdit", Color.WHITE)
	t.set_font_size("font_size", "LineEdit", 32)

	var track := StyleBoxFlat.new()
	track.bg_color = Color8(40, 40, 80)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = YELLOW
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _square(14, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _square(14, YELLOW))

	t.set_stylebox("panel", "TooltipPanel", box(NAVY, YELLOW, 2, 8, 6))
	return t


static func _square(size: int, c: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
