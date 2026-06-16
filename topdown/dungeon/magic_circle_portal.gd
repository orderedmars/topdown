class_name MagicCirclePortal
extends Area2D

# Floor-painted magic circle. Non-blocking (Area2D, no StaticBody) so it never
# walls off a path. Emits `activated` when the player steps onto it; the
# consumer decides what the activation does (return to town, descend, etc.).

signal activated

@export var radius: float = 48.0
@export var ring_color: Color = Color(0.6, 0.9, 1.0)

var _t: float = 0.0
var _fired: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_mask = 2  # player is on collision_layer 2 (see player.gd)
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	# If a body is already inside when monitoring kicks in (e.g. the player
	# already standing where the portal just spawned), trigger after one
	# physics frame so they don't need to step off and back on.
	_check_initial_overlap.call_deferred()


func _check_initial_overlap() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.0)
	var fill := Color(ring_color.r, ring_color.g, ring_color.b, 0.12 + 0.12 * pulse)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring_color, 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 64, ring_color, 1.5, true)
	for i in 8:
		var angle: float = TAU * float(i) / 8.0 + _t * 0.4
		var p1: Vector2 = Vector2.from_angle(angle) * (radius * 0.78)
		var p2: Vector2 = Vector2.from_angle(angle) * (radius * 0.95)
		draw_line(p1, p2, ring_color, 2.0)


func _on_body_entered(body: Node2D) -> void:
	if _fired:
		return
	if not body.is_in_group("player"):
		return
	_fired = true
	activated.emit()
