extends Area2D

@export var item: ItemData

@export var quantity: int = 1

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label

func _ready() -> void:
	add_to_group("item_pickup")
	body_entered.connect(_on_body_entered)
	collision_layer = 8
	collision_mask = 2  # detect player body (layer 2)
	if item:
		sprite.color = item.color
		label.text = item.item_name

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if InventoryManager.add_item(item, quantity):
			queue_free()
