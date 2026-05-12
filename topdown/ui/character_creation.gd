extends Control

const RACES_DIR := "res://adventurer/races/"
const CLASSES_DIR := "res://adventurer/classes/"

var race_options: Array[RaceData] = []
var class_options: Array[ClassData] = []

var selected_race: RaceData = null
var selected_class: ClassData = null

var race_buttons: Array[Button] = []
var class_buttons: Array[Button] = []

@onready var name_input: LineEdit = $Panel/Margin/VBox/NameInput
@onready var race_container: VBoxContainer = $Panel/Margin/VBox/HBox/RaceColumn/RaceButtons
@onready var class_container: VBoxContainer = $Panel/Margin/VBox/HBox/ClassColumn/ClassButtons
@onready var preview: Label = $Panel/Margin/VBox/PreviewLabel
@onready var confirm_button: Button = $Panel/Margin/VBox/ConfirmButton


func _ready() -> void:
	_load_races()
	_load_classes()
	_populate_race_buttons()
	_populate_class_buttons()
	confirm_button.pressed.connect(_on_confirm)
	confirm_button.disabled = true
	_update_preview()


func _load_races() -> void:
	var dir := DirAccess.open(RACES_DIR)
	if dir == null:
		push_warning("Could not open " + RACES_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var res := load(RACES_DIR + file) as RaceData
			if res != null and _is_unlocked(res):
				race_options.append(res)
		file = dir.get_next()


func _load_classes() -> void:
	var dir := DirAccess.open(CLASSES_DIR)
	if dir == null:
		push_warning("Could not open " + CLASSES_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var res := load(CLASSES_DIR + file) as ClassData
			if res != null and _is_unlocked(res):
				class_options.append(res)
		file = dir.get_next()


func _is_unlocked(res) -> bool:
	if not "unlock_achievement" in res:
		return true
	return res.unlock_achievement == StringName("")


func _populate_race_buttons() -> void:
	for race in race_options:
		var btn := Button.new()
		btn.text = race.race_name
		btn.toggle_mode = true
		btn.pressed.connect(_on_race_selected.bind(race, btn))
		race_container.add_child(btn)
		race_buttons.append(btn)


func _populate_class_buttons() -> void:
	for cls in class_options:
		var btn := Button.new()
		btn.text = cls.class_title
		btn.toggle_mode = true
		btn.pressed.connect(_on_class_selected.bind(cls, btn))
		class_container.add_child(btn)
		class_buttons.append(btn)


func _on_race_selected(race: RaceData, btn: Button) -> void:
	selected_race = race
	for b in race_buttons:
		b.button_pressed = (b == btn)
	_update_preview()


func _on_class_selected(cls: ClassData, btn: Button) -> void:
	selected_class = cls
	for b in class_buttons:
		b.button_pressed = (b == btn)
	_update_preview()


func _update_preview() -> void:
	var lines: Array[String] = []
	if selected_race:
		lines.append("Race: %s" % selected_race.race_name)
		lines.append(selected_race.description)
	if selected_class:
		if not lines.is_empty():
			lines.append("")
		lines.append("Class: %s" % selected_class.class_title)
		lines.append(selected_class.description)
	preview.text = "\n".join(lines) if not lines.is_empty() else "Pick a race and a class."
	confirm_button.disabled = not (selected_race and selected_class)


func _on_confirm() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Adventurer"

	var player_data := AdventurerData.new()
	player_data.id = StringName("player_%d" % int(Time.get_unix_time_from_system()))
	player_data.display_name = player_name
	player_data.race = selected_race
	player_data.current_class = selected_class
	player_data.is_player_character = true
	player_data.learned_skills = selected_class.starter_skills.duplicate()
	player_data.equipped_skill_slots = selected_class.starter_skills.duplicate()

	RunState.start_new_run(player_data)
	get_tree().change_scene_to_file("res://scenes/town.tscn")
