class_name LootTable
extends Resource

# These drops auto-spawn as floor pickups the player walks over (coins, herbs, common junk).
@export var auto_drops: Array[LootEntry] = []

# These drops go into a loot container the player must press E to open.
@export var container_drops: Array[LootEntry] = []

# Roll the table and return two lists: { auto: [...], container: [...] }
# Each entry in the lists is { item: ItemData, quantity: int }
func roll() -> Dictionary:
	var result = { "auto": [], "container": [] }

	for entry in auto_drops:
		if randf() <= entry.drop_chance:
			var qty = randi_range(entry.min_count, entry.max_count)
			result["auto"].append({ "item": entry.item, "quantity": qty })

	for entry in container_drops:
		if randf() <= entry.drop_chance:
			var qty = randi_range(entry.min_count, entry.max_count)
			result["container"].append({ "item": entry.item, "quantity": qty })

	return result
