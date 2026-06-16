extends StaticBody2D
class_name Building

@export var building_name: String = "Building"
@export var building_color: Color = Color(0.5, 0.35, 0.2, 1)
@export var building_size: Vector2 = Vector2(200, 150)
@export var has_door: bool = true
@export var interaction_radius: float = 130.0
# Set per-instance for buildings that fully transition to a separate scene
# (dungeon gates, race-village interiors). Use a res:// path — a PackedScene
# ext_resource here causes circular-load issues when two scenes reference each
# other. Shops do NOT use this — they open an overlay UI instead.
@export_file("*.tscn") var interior_scene_path: String = ""

var player_in_zone: bool = false

@onready var sprite: ColorRect = $Sprite
@onready var door: ColorRect = $Door
@onready var label: Label = $Label
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var interaction_label: Label = $InteractionLabel
@onready var interaction_collision: CollisionShape2D = $InteractionZone/CollisionShape2D


func _ready() -> void:
	add_to_group("building")

	var half_w := building_size.x / 2.0
	var half_h := building_size.y / 2.0

	sprite.offset_left = -half_w
	sprite.offset_top = -half_h
	sprite.offset_right = half_w
	sprite.offset_bottom = half_h
	sprite.color = building_color

	if has_door:
		door.offset_left = -20.0
		door.offset_top = half_h - 20.0
		door.offset_right = 20.0
		door.offset_bottom = half_h
	else:
		door.hide()

	label.offset_left = -half_w
	label.offset_top = -half_h - 30.0
	label.offset_right = half_w
	label.offset_bottom = -half_h - 5.0
	label.text = building_name

	var body_shape := RectangleShape2D.new()
	body_shape.size = building_size
	body_collision.shape = body_shape

	var int_shape := CircleShape2D.new()
	int_shape.radius = interaction_radius
	interaction_collision.shape = int_shape

	interaction_label.offset_left = -half_w
	interaction_label.offset_top = half_h + 10.0
	interaction_label.offset_right = half_w
	interaction_label.offset_bottom = half_h + 35.0
	interaction_label.hide()


func interact() -> void:
	if interior_scene_path != "":
		get_tree().change_scene_to_file(interior_scene_path)
	else:
		print("Entering: ", building_name)


func _on_interaction_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		interaction_label.show()


func _on_interaction_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		interaction_label.hide()
