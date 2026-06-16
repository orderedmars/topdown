extends CanvasLayer

@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var mana_bar: ProgressBar = $VBoxContainer/ManaBar
@onready var stamina_bar: ProgressBar = $VBoxContainer/StaminaBar
@onready var heal_button: Button = $VBoxContainer/HealButton
@onready var fireball_button: Button = $VBoxContainer/FireballButton
@onready var arrow_button: Button = $VBoxContainer/ArrowButton
@onready var crosshair: ColorRect = $Crosshair

@onready var member_list: VBoxContainer = $PartyContainer/MemberList

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.stats_changed.connect(_on_player_stats_changed)
		heal_button.pressed.connect(func(): player.heal(100.0))
		fireball_button.pressed.connect(func(): player.set_skill_mode(1))
		arrow_button.pressed.connect(func(): player.set_skill_mode(2))
	
	PartyManager.party_updated.connect(_update_party_ui)
	_update_party_ui()

func _update_party_ui():
	# Clear old list
	for child in member_list.get_children():
		child.queue_free()
	
	# Add new members
	for member in PartyManager.party_members:
		var label = Label.new()
		label.text = member.npc_name if "npc_name" in member else "Unknown"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		member_list.add_child(label)

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.current_skill_mode != player.SkillMode.NONE:
		crosshair.visible = true
		var mouse_pos = get_viewport().get_mouse_position()

		if player.current_skill_mode == player.SkillMode.FIREBALL:
			crosshair.size = Vector2(120, 120)
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
