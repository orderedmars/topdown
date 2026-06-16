class_name BossPlaceholder
extends Area2D

# Stand-in boss until the combat system lands. Walking into it counts as a
# "defeat" so we can iterate on the boss-room → descend-portal flow without
# waiting for combat. The collaborator's combat system can replace this script
# (or emit the same `defeated` signal) when ready.

signal defeated

@export var size_px: Vector2 = Vector2(64, 64)
@export var body_color: Color = Color(0.85, 0.15, 0.15)


func _ready() -> void:
	monitoring = true
	collision_mask = 2  # player is on collision_layer 2 (see player.gd)
	var shape := RectangleShape2D.new()
	shape.size = size_px
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	# Defeat-on-contact is a stub; if the player is already overlapping when
	# we spawn (e.g. they walked straight into the boss's tile in the frame
	# the room was revealed), trigger after the first physics frame.
	_check_initial_overlap.call_deferred()


func _check_initial_overlap() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _draw() -> void:
	draw_rect(Rect2(-size_px / 2.0, size_px), body_color)
	draw_circle(Vector2(-12, -6), 5, Color(1, 0.9, 0.3))
	draw_circle(Vector2(12, -6), 5, Color(1, 0.9, 0.3))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		defeated.emit()
