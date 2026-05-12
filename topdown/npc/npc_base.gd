extends CharacterBody2D
class_name NPCBase


enum NPCState { IDLE, FOLLOWING, WANDERING }
var current_state: NPCState = NPCState.IDLE

@export var npc_name: String = "NPC"
@export_multiline var greeting_idle: String = "Need some help?"
@export_multiline var greeting_party: String = "Yes, what do you need?"
@export var walk_speed: float = 200.0

const FOLLOW_DISTANCE: float = 60.0

var wander_target: Vector2
var wander_timer: float = 0.0

# Trail for the person behind this NPC in the party chain
var position_history: Array[Dictionary] = []

@onready var sprite: ColorRect = $Sprite
@onready var interaction_label: Label = $InteractionLabel

func _ready() -> void:
	add_to_group("npc")
	wander_target = global_position
	interaction_label.hide()

func _physics_process(delta: float) -> void:
	match current_state:
		NPCState.FOLLOWING:
			handle_following(delta)
			record_history()
		NPCState.WANDERING, NPCState.IDLE:
			handle_wandering(delta)

	move_and_slide()

func record_history():
	var data = {
		"pos": global_position,
		"sprint": false,
		"crouch": sprite.color == Color("#111155")
	}

	if position_history.is_empty() or global_position.distance_to(position_history.back()["pos"]) > 2.0:
		position_history.append(data)
		if position_history.size() > 120:
			position_history.remove_at(0)

func handle_following(delta: float) -> void:
	var target = PartyManager.get_follow_target(self)
	if not target or not "position_history" in target:
		velocity = Vector2.ZERO
		return

	var history: Array = target.position_history
	if history.is_empty():
		velocity = Vector2.ZERO
		return

	# Hard teleport recovery if somehow very far away (e.g. scene load)
	if global_position.distance_to(target.global_position) > 500.0:
		global_position = target.global_position
		velocity = Vector2.ZERO
		return

	var trail := _sample_trail(history, FOLLOW_DISTANCE)

	# Mirror the leader's movement state at this point in the trail
	sprite.color = Color("#111155") if trail["crouch"] else Color.GREEN

	var dist: float = global_position.distance_to(trail["pos"])
	if dist > 2.0:
		# Match the leader's speed at that trail point so sprint/crouch feel correct
		var base_speed: float = walk_speed
		if trail["sprint"]:
			base_speed = walk_speed * 1.75
		elif trail["crouch"]:
			base_speed = walk_speed * 0.6

		# Scale up when falling behind, but never overshoot the target in one frame
		var speed: float = base_speed * clamp(dist / (FOLLOW_DISTANCE * 0.5), 1.0, 2.0)
		speed = min(speed, dist / delta)
		velocity = (trail["pos"] - global_position).normalized() * speed
	else:
		velocity = Vector2.ZERO

# Walk backwards along the leader's path trail and return the point
# that is exactly `distance` pixels behind the leader.
func _sample_trail(history: Array, distance: float) -> Dictionary:
	var accumulated := 0.0
	for i in range(history.size() - 1, 0, -1):
		var seg: float = history[i]["pos"].distance_to(history[i - 1]["pos"])
		if accumulated + seg >= distance:
			var t: float = (distance - accumulated) / seg
			return {
				"pos": history[i]["pos"].lerp(history[i - 1]["pos"], t),
				"crouch": history[i - 1]["crouch"],
				"sprint": history[i - 1]["sprint"]
			}
		accumulated += seg
	return history[0]

func handle_wandering(delta: float):
	wander_timer -= delta
	if wander_timer <= 0:
		current_state = NPCState.WANDERING if randf() > 0.5 else NPCState.IDLE
		wander_target = global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		wander_timer = randf_range(2, 4)

	if current_state == NPCState.WANDERING:
		var dir = (wander_target - global_position).normalized()
		velocity = dir * (walk_speed * 0.5)
		if global_position.distance_to(wander_target) < 10:
			current_state = NPCState.IDLE
	else:
		velocity = Vector2.ZERO

func interact():
	var choices = []
	var message: String

	if current_state != NPCState.FOLLOWING:
		message = greeting_idle
		choices.append({"text": "Join my party", "id": "join"})
		choices.append({"text": "Nevermind", "id": "cancel"})
	else:
		message = greeting_party
		choices.append({"text": "Kick from party", "id": "kick"})
		choices.append({"text": "Stay close", "id": "cancel"})

	DialogueManager.show_dialogue(npc_name, message, choices)

	if not DialogueManager.choice_selected.is_connected(_on_dialogue_choice):
		DialogueManager.choice_selected.connect(_on_dialogue_choice)

func _on_dialogue_choice(choice_id: String):
	if DialogueManager.choice_selected.is_connected(_on_dialogue_choice):
		DialogueManager.choice_selected.disconnect(_on_dialogue_choice)

	match choice_id:
		"join": join_party()
		"kick": leave_party()

func join_party():
	if PartyManager.add_member(self):
		current_state = NPCState.FOLLOWING
		sprite.color = Color.GREEN
		collision_layer = 0
		collision_mask = 1
		InventoryManager.register_character(npc_name)

func leave_party():
	if PartyManager.remove_member(self):
		current_state = NPCState.IDLE
		sprite.color = Color.WHITE
		collision_layer = 2
		collision_mask = 1

func _on_interaction_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		interaction_label.show()

func _on_interaction_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		interaction_label.hide()
