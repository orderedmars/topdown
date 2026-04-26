extends CanvasLayer

@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var mana_bar: ProgressBar = $VBoxContainer/ManaBar
@onready var stamina_bar: ProgressBar = $VBoxContainer/StaminaBar
@onready var heal_button: Button = $VBoxContainer/HealButton
@onready var fireball_button: Button = $VBoxContainer/FireballButton
@onready var arrow_button: Button = $VBoxContainer/ArrowButton
@onready var crosshair: ColorRect = $Crosshair

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.stats_changed.connect(_on_player_stats_changed)
		heal_button.pressed.connect(func(): player.heal(100.0))
		fireball_button.pressed.connect(func(): player.set_skill_mode(1))
		arrow_button.pressed.connect(func(): player.set_skill_mode(2))

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.current_skill_mode != 0:
		crosshair.visible = true
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Change crosshair size based on skill
		if player.current_skill_mode == 1: # FIREBALL
			crosshair.size = Vector2(120, 120) # Diameter of blast (radius 60)
			# Make it a faint circle using a recipe
			crosshair.color = Color(1, 0.3, 0, 0.2)
		else: # ARROW
			crosshair.size = Vector2(10, 10)
			crosshair.color = Color(1, 1, 1, 0.5)
			
		crosshair.global_position = mouse_pos - crosshair.size / 2
	else:
		crosshair.visible = false

func _on_player_stats_changed(h, m, s) -> void:
	health_bar.value = h
	mana_bar.value = m
	stamina_bar.value = s
