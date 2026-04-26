extends CanvasLayer

# ── Palette ──────────────────────────────────────────────────────
const C_BG     = Color(0.07,  0.055, 0.04,  0.97)
const C_BG2    = Color(0.15,  0.115, 0.08,  0.97)
const C_GOLD   = Color(0.72,  0.55,  0.18,  1.0)
const C_GOLD_D = Color(0.38,  0.29,  0.08,  1.0)
const C_GOLD_B = Color(0.92,  0.76,  0.32,  1.0)
const C_HP     = Color(0.85,  0.15,  0.12,  1.0)
const C_MP     = Color(0.22,  0.42,  0.95,  1.0)
const C_SP     = Color(0.18,  0.78,  0.28,  1.0)

var _health_bar:  ProgressBar
var _mana_bar:    ProgressBar
var _stamina_bar: ProgressBar
var _health_val:  Label
var _mana_val:    Label
var _stamina_val: Label
var _skill_slots: Array = []
var _crosshair:   Control

func _ready() -> void:
	_build_bg_bar()
	_build_portrait()
	_build_stats()
	_build_skill_bar()
	_build_crosshair()

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	player.stats_changed.connect(_on_stats_changed)
	_health_bar.max_value  = player.max_health
	_mana_bar.max_value    = player.max_mana
	_stamina_bar.max_value = player.max_stamina
	_on_stats_changed(player.health, player.mana, player.stamina)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	_update_crosshair(player)
	_update_skill_highlights(player.current_skill_mode)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	match event.keycode:
		KEY_1: player.set_skill_mode(1)
		KEY_2: player.set_skill_mode(2)
		KEY_H: player.heal(100.0)

func _on_stats_changed(h: float, m: float, s: float) -> void:
	_health_bar.value  = h
	_mana_bar.value    = m
	_stamina_bar.value = s
	_health_val.text   = "%d / %d" % [int(h), int(_health_bar.max_value)]
	_mana_val.text     = "%d / %d" % [int(m), int(_mana_bar.max_value)]
	_stamina_val.text  = "%d / %d" % [int(s), int(_stamina_bar.max_value)]

# ── Background bar ───────────────────────────────────────────────

func _build_bg_bar() -> void:
	var bar := ColorRect.new()
	bar.anchor_left   = 0.0;  bar.anchor_right  = 1.0
	bar.anchor_top    = 1.0;  bar.anchor_bottom = 1.0
	bar.offset_top    = -90.0; bar.offset_bottom = 0.0
	bar.color = C_BG
	add_child(bar)

	# Gold top edge
	var trim := ColorRect.new()
	trim.anchor_left   = 0.0;  trim.anchor_right  = 1.0
	trim.anchor_top    = 1.0;  trim.anchor_bottom = 1.0
	trim.offset_top    = -90.0; trim.offset_bottom = -88.0
	trim.color = C_GOLD
	add_child(trim)

	# Subtle inner highlight under gold edge
	var trim2 := ColorRect.new()
	trim2.anchor_left   = 0.0;  trim2.anchor_right  = 1.0
	trim2.anchor_top    = 1.0;  trim2.anchor_bottom = 1.0
	trim2.offset_top    = -88.0; trim2.offset_bottom = -87.0
	trim2.color = C_BG2
	add_child(trim2)

# ── Portrait ─────────────────────────────────────────────────────

func _build_portrait() -> void:
	# Outer gold frame
	_add_rect(10.0, -85.0, 79.0, -5.0, C_GOLD)
	# Dark inner bg
	_add_rect(12.0, -83.0, 77.0, -7.0, C_BG2)
	# Player color block
	_add_rect(14.0, -81.0, 75.0, -26.0, Color(0.2, 0.27, 0.85))
	# Name plate bg
	_add_rect(12.0, -26.0, 77.0, -7.0, Color(0.04, 0.03, 0.02))

	# Vertical separator after portrait
	_add_rect(85.0, -84.0, 87.0, -6.0, C_GOLD_D)

	# "PLAYER" name label
	var name_lbl := Label.new()
	name_lbl.text = "PLAYER"
	name_lbl.anchor_left = 0.0;  name_lbl.anchor_right  = 0.0
	name_lbl.anchor_top  = 1.0;  name_lbl.anchor_bottom = 1.0
	name_lbl.offset_left = 12.0; name_lbl.offset_right  = 77.0
	name_lbl.offset_top  = -26.0; name_lbl.offset_bottom = -7.0
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", C_GOLD)
	add_child(name_lbl)

# ── Stat bars ────────────────────────────────────────────────────

func _build_stats() -> void:
	var vbox := VBoxContainer.new()
	vbox.anchor_left   = 0.0;   vbox.anchor_right  = 0.0
	vbox.anchor_top    = 1.0;   vbox.anchor_bottom = 1.0
	vbox.offset_left   = 95.0;  vbox.offset_right  = 335.0
	vbox.offset_top    = -87.0; vbox.offset_bottom = -5.0
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)

	var h := _make_bar_row("HP", C_HP)
	vbox.add_child(h[0]); _health_bar = h[1]; _health_val = h[2]

	var m := _make_bar_row("MP", C_MP)
	vbox.add_child(m[0]); _mana_bar = m[1]; _mana_val = m[2]

	var s := _make_bar_row("SP", C_SP)
	vbox.add_child(s[0]); _stamina_bar = s[1]; _stamina_val = s[2]

	# Separator after stats
	_add_rect(341.0, -84.0, 343.0, -6.0, C_GOLD_D)

func _make_bar_row(lbl_text: String, bar_color: Color) -> Array:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	# Colored badge
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(bar_color.r * 0.18, bar_color.g * 0.18, bar_color.b * 0.18)
	badge_style.border_width_left = 1; badge_style.border_width_top    = 1
	badge_style.border_width_right= 1; badge_style.border_width_bottom = 1
	badge_style.border_color = bar_color
	badge_style.content_margin_left = 2.0; badge_style.content_margin_right  = 2.0
	badge_style.content_margin_top  = 1.0; badge_style.content_margin_bottom = 1.0

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(26, 0)
	badge.add_theme_stylebox_override("panel", badge_style)
	hbox.add_child(badge)

	var badge_lbl := Label.new()
	badge_lbl.text = lbl_text
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 9)
	badge_lbl.add_theme_color_override("font_color", bar_color)
	badge.add_child(badge_lbl)

	# Progress bar
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(110, 16)
	bar.max_value = 100.0; bar.value = 100.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.03, 0.02)
	bar_bg.border_width_left = 1; bar_bg.border_width_top    = 1
	bar_bg.border_width_right= 1; bar_bg.border_width_bottom = 1
	bar_bg.border_color = C_GOLD_D
	bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", bar_fill)
	hbox.add_child(bar)

	# Value label
	var val := Label.new()
	val.text = "100 / 100"
	val.custom_minimum_size = Vector2(64, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 9)
	val.add_theme_color_override("font_color", C_GOLD_B)
	hbox.add_child(val)

	return [hbox, bar, val]

# ── Skill bar ────────────────────────────────────────────────────

func _build_skill_bar() -> void:
	var container := HBoxContainer.new()
	container.anchor_left   = 0.5;    container.anchor_right  = 0.5
	container.anchor_top    = 1.0;    container.anchor_bottom = 1.0
	container.offset_left   = -120.0; container.offset_right  = 120.0
	container.offset_top    = -88.0;  container.offset_bottom = -4.0
	container.add_theme_constant_override("separation", 6)
	add_child(container)

	var defs := [
		{"label": "FIREBALL", "key": "1", "color": Color(1.0, 0.45, 0.0), "icon": "res://ui/icon_fireball.svg", "mode": 1,  "cost": "15 MP"},
		{"label": "ARROW",    "key": "2", "color": Color(0.6, 0.75, 1.0), "icon": "res://ui/icon_arrow.svg",    "mode": 2,  "cost": "10 SP"},
		{"label": "HEAL",     "key": "H", "color": Color(0.2, 0.9,  0.4), "icon": "res://ui/icon_heal.svg",     "mode": -1, "cost": "FULL"},
	]

	for d in defs:
		var slot := _make_skill_slot(d)
		container.add_child(slot["panel"])
		_skill_slots.append(slot)

func _make_skill_slot(d: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(74.0, 80.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var col: Color      = d["color"]
	var active_bg       = Color(col.r * 0.22 + C_BG.r, col.g * 0.22 + C_BG.g, col.b * 0.22 + C_BG.b, 0.97)
	var normal_style    := _slot_style(C_BG2,                        C_GOLD_D)
	var hover_style     := _slot_style(Color(0.22, 0.17, 0.12, 0.97), C_GOLD)
	var active_style    := _slot_style(active_bg,                     col)
	panel.add_theme_stylebox_override("panel", normal_style)

	panel.mouse_entered.connect(func():
		if not _is_slot_active(d["mode"]):
			panel.add_theme_stylebox_override("panel", hover_style)
	)
	panel.mouse_exited.connect(func():
		if not _is_slot_active(d["mode"]):
			panel.add_theme_stylebox_override("panel", normal_style)
	)
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var player := get_tree().get_first_node_in_group("player")
			if not player: return
			if d["mode"] > 0:
				player.set_skill_mode(d["mode"])
			else:
				player.heal(100.0)
	)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var key_lbl := Label.new()
	key_lbl.text = "[%s]" % d["key"]
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_lbl.add_theme_font_size_override("font_size", 8)
	key_lbl.add_theme_color_override("font_color", C_GOLD)
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(key_lbl)

	var tex := TextureRect.new()
	if ResourceLoader.exists(d["icon"]):
		tex.texture = load(d["icon"])
	tex.custom_minimum_size = Vector2(36.0, 36.0)
	tex.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tex)

	var name_lbl := Label.new()
	name_lbl.text = d["label"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", C_GOLD_B)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = d["cost"]
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 8)
	cost_lbl.add_theme_color_override("font_color", Color(0.52, 0.52, 0.52))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_lbl)

	return {"panel": panel, "mode": d["mode"], "normal_style": normal_style, "active_style": active_style}

func _slot_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left   = 2; s.border_width_top    = 2
	s.border_width_right  = 2; s.border_width_bottom = 2
	s.border_color = border
	s.content_margin_left   = 4.0; s.content_margin_right  = 4.0
	s.content_margin_top    = 3.0; s.content_margin_bottom = 3.0
	return s

func _is_slot_active(mode: int) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and mode > 0 and player.current_skill_mode == mode

func _update_skill_highlights(current_mode: int) -> void:
	for slot in _skill_slots:
		var is_active: bool = slot["mode"] > 0 and slot["mode"] == current_mode
		slot["panel"].add_theme_stylebox_override("panel", slot["active_style"] if is_active else slot["normal_style"])

# ── Crosshair ────────────────────────────────────────────────────

func _build_crosshair() -> void:
	var script := load("res://ui/crosshair.gd")
	_crosshair = Control.new()
	_crosshair.set_script(script)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	add_child(_crosshair)

func _update_crosshair(player) -> void:
	var mode: int = player.current_skill_mode
	if mode == 0:
		_crosshair.visible = false
		return
	_crosshair.visible = true
	_crosshair.size = Vector2(140.0, 140.0) if mode == 1 else Vector2(50.0, 50.0)
	_crosshair.position = get_viewport().get_mouse_position() - _crosshair.size * 0.5
	_crosshair.call("set_skill", mode)

# ── Helpers ──────────────────────────────────────────────────────

func _add_rect(left: float, top: float, right: float, bottom: float, color: Color) -> void:
	var r := ColorRect.new()
	r.anchor_left = 0.0;  r.anchor_right  = 0.0
	r.anchor_top  = 1.0;  r.anchor_bottom = 1.0
	r.offset_left = left; r.offset_right  = right
	r.offset_top  = top;  r.offset_bottom = bottom
	r.color = color
	add_child(r)
