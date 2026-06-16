extends Area2D

# Populated by enemy.gd on death, or set manually in the editor for chests.
var pending_loot: Array = []  # Array of { item: ItemData, quantity: int }

@onready var sprite: ColorRect = $Sprite
@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	add_to_group("loot_container")
	collision_layer = 8
	collision_mask = 0  # player checks via distance in player.gd, not overlap

func setup(loot: Array) -> void:
	pending_loot = loot

func interact() -> void:
	if pending_loot.is_empty():
		queue_free()
		return
	# Send all loot into the shared inventory.
	for entry in pending_loot:
		InventoryManager.add_item(entry["item"], entry["quantity"])
	pending_loot.clear()
	queue_free()
