extends CanvasLayer

var _health_bar: ProgressBar
var _mana_bar: ProgressBar
var _stamina_bar: ProgressBar
var _health_val: Label
var _mana_val: Label
var _stamina_val: Label

var _skill_slots: Array = []
var _crosshair: Control

func _ready() -> void:
	_build_stat_panel()
	_build_skill_bar()
	_build_crosshair()

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	player.stats_changed.connect(_on_stats_changed)
	_health_bar.max_value = player.max_health
	_mana_bar.max_value = player.max_mana
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
	_health_bar.value = h
	_mana_bar.value = m
	_stamina_bar.value = s
	_health_val.text = "%d/%d" % [int(h), int(_health_bar.max_value)]
	_mana_val.text = "%d/%d" % [int(m), int(_mana_bar.max_value)]
	_stamina_val.text = "%d/%d" % [int(s), int(_stamina_bar.max_value)]

# ── Stat Panel ───────────────────────────────────────────────────

func _build_stat_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.0
	panel.anchor_top    = 1.0
	panel.anchor_right  = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = 10.0
	panel.offset_top    = -118.0
	panel.offset_right  = 275.0
	panel.offset_bottom = -10.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left   = 10.0
	style.content_margin_top    = 8.0
	style.content_margin_right  = 10.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var h := _make_bar_row("HP", Color(0.9, 0.15, 0.15))
	vbox.add_child(h[0]); _health_bar = h[1]; _health_val = h[2]

	var m := _make_bar_row("MP", Color(0.25, 0.45, 1.0))
	vbox.add_child(m[0]); _mana_bar = m[1]; _mana_val = m[2]

	var s := _make_bar_row("SP", Color(0.15, 0.85, 0.35))
	vbox.add_child(s[0]); _stamina_bar = s[1]; _stamina_val = s[2]

func _make_bar_row(lbl_text: String, bar_color: Color) -> Array:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)

	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(24.0, 0.0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	hbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150.0, 14.0)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.12)
	bg.corner_radius_top_left     = 3
	bg.corner_radius_top_right    = 3
	bg.corner_radius_bottom_left  = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_color
	fill.corner_radius_top_left     = 3
	fill.corner_radius_top_right    = 3
	fill.corner_radius_bottom_left  = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	hbox.add_child(bar)

	var val := Label.new()
	val.text = "100/100"
	val.custom_minimum_size = Vector2(54.0, 0.0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 10)
	val.add_theme_color_override("font_color", Color(0.58, 0.58, 0.58))
	hbox.add_child(val)

	return [hbox, bar, val]

# ── Skill Bar ────────────────────────────────────────────────────

func _build_skill_bar() -> void:
	var container := HBoxContainer.new()
	container.anchor_left   = 0.5
	container.anchor_top    = 1.0
	container.anchor_right  = 0.5
	container.anchor_bottom = 1.0
	container.offset_left   = -118.0
	container.offset_top    = -90.0
	container.offset_right  = 118.0
	container.offset_bottom = -10.0
	container.add_theme_constant_override("separation", 8)
	add_child(container)

	var defs := [
		{"label": "Fireball", "key": "1", "color": Color(1.0, 0.45, 0.0), "icon": "res://ui/icon_fireball.svg", "mode": 1},
		{"label": "Arrow",    "key": "2", "color": Color(0.6, 0.75, 1.0), "icon": "res://ui/icon_arrow.svg",    "mode": 2},
		{"label": "Heal",     "key": "H", "color": Color(0.2, 0.9,  0.4), "icon": "res://ui/icon_heal.svg",     "mode": -1},
	]

	for d in defs:
		var slot := _make_skill_slot(d)
		container.add_child(slot["panel"])
		_skill_slots.append(slot)

func _make_skill_slot(d: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(72.0, 72.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var normal_style := _slot_style(Color(0.1, 0.1, 0.1, 0.8),  Color(0.3, 0.3, 0.3, 0.8))
	var hover_style  := _slot_style(Color(0.2, 0.2, 0.2, 0.9),  Color(0.55, 0.55, 0.55, 0.9))
	var active_style := _slot_style(Color(d["color"].r, d["color"].g, d["color"].b, 0.22), d["color"])
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
			if not player:
				return
			if d["mode"] > 0:
				player.set_skill_mode(d["mode"])
			else:
				player.heal(100.0)
	)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var tex := TextureRect.new()
	if ResourceLoader.exists(d["icon"]):
		tex.texture = load(d["icon"])
	tex.custom_minimum_size = Vector2(38.0, 38.0)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tex)

	var lbl := Label.new()
	lbl.text = "[%s] %s" % [d["key"], d["label"]]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	return {"panel": panel, "mode": d["mode"], "normal_style": normal_style, "active_style": active_style}

func _slot_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	s.border_width_left   = 2
	s.border_width_top    = 2
	s.border_width_right  = 2
	s.border_width_bottom = 2
	s.border_color = border
	s.content_margin_left   = 4.0
	s.content_margin_top    = 4.0
	s.content_margin_right  = 4.0
	s.content_margin_bottom = 4.0
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
