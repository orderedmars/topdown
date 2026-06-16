extends Node

signal inventory_changed

signal equipment_changed(character_name: String)

# Shared pool — all party members draw consumables and loot from here.
# Each entry: { "item": ItemData, "quantity": int }
var main_inventory: Array = []
const MAX_SLOTS: int = 40

# Per-character equipment. Key = character name, value = { EquipmentSlot: ItemData or null }
var character_equipment: Dictionary = {}

# Per-character skill loadout. Key = character name, value = Array[SkillData] size 4.
# null = locked slot.
var character_skills: Dictionary = {}

# -------------------------------------------------------------------------
# Character registration — call this from each character's _ready()
# -------------------------------------------------------------------------

func register_character(char_name: String) -> void:
	if not character_equipment.has(char_name):
		character_equipment[char_name] = {
			ItemData.EquipmentSlot.WEAPON:    null,
			ItemData.EquipmentSlot.OFFHAND:   null,
			ItemData.EquipmentSlot.HEAD:      null,
			ItemData.EquipmentSlot.BODY:      null,
			ItemData.EquipmentSlot.LEGGINGS:  null,
			ItemData.EquipmentSlot.BOOTS:     null,
			ItemData.EquipmentSlot.ACCESSORY: null,
			ItemData.EquipmentSlot.SOUL:      null,
		}
	if not character_skills.has(char_name):
		character_skills[char_name] = [null, null, null, null]

# -------------------------------------------------------------------------
# Main inventory — add / remove / query
# -------------------------------------------------------------------------

func add_item(item: ItemData, quantity: int = 1) -> bool:
	# Try to stack onto an existing entry first.
	for entry in main_inventory:
		if entry["item"] == item and entry["quantity"] < item.max_stack:
			var space = item.max_stack - entry["quantity"]
			entry["quantity"] += min(quantity, space)
			inventory_changed.emit()
			return true

	if main_inventory.size() >= MAX_SLOTS:
		return false  # inventory full

	main_inventory.append({ "item": item, "quantity": quantity })
	inventory_changed.emit()
	return true

func remove_item(item: ItemData, quantity: int = 1) -> bool:
	for i in range(main_inventory.size()):
		if main_inventory[i]["item"] == item:
			main_inventory[i]["quantity"] -= quantity
			if main_inventory[i]["quantity"] <= 0:
				main_inventory.remove_at(i)
			inventory_changed.emit()
			return true
	return false

func has_item(item: ItemData) -> bool:
	for entry in main_inventory:
		if entry["item"] == item and entry["quantity"] > 0:
			return true
	return false

func get_quantity(item: ItemData) -> int:
	for entry in main_inventory:
		if entry["item"] == item:
			return entry["quantity"]
	return 0

# -------------------------------------------------------------------------
# Consumables — use on a character node
# -------------------------------------------------------------------------

func use_item(item: ItemData, character: Node) -> bool:
	if item.item_type != ItemData.ItemType.CONSUMABLE:
		return false
	if not has_item(item):
		return false

	match item.consumable_target:
		ItemData.ConsumableTarget.HEALTH:
			if character.has_method("restore_health"):
				character.restore_health(item.effect_value)
		ItemData.ConsumableTarget.MANA:
			if character.has_method("restore_mana"):
				character.restore_mana(item.effect_value)
		ItemData.ConsumableTarget.STAMINA:
			if character.has_method("restore_stamina"):
				character.restore_stamina(item.effect_value)
		ItemData.ConsumableTarget.ALL:
			if character.has_method("heal"):
				character.heal(item.effect_value)

	remove_item(item, 1)
	return true

# -------------------------------------------------------------------------
# Equipment — equip / unequip
# -------------------------------------------------------------------------

func equip_item(item: ItemData, char_name: String) -> bool:
	if item.equipment_slot == ItemData.EquipmentSlot.NONE:
		return false
	if not character_equipment.has(char_name):
		register_character(char_name)

	# Return whatever is currently in that slot to the shared inventory.
	var current = character_equipment[char_name][item.equipment_slot]
	if current != null:
		add_item(current)

	character_equipment[char_name][item.equipment_slot] = item
	remove_item(item)
	equipment_changed.emit(char_name)
	return true

func unequip_item(slot: ItemData.EquipmentSlot, char_name: String) -> bool:
	if not character_equipment.has(char_name):
		return false
	var item = character_equipment[char_name].get(slot, null)
	if item == null:
		return false
	if not add_item(item):
		return false  # inventory full — don't unequip
	character_equipment[char_name][slot] = null
	equipment_changed.emit(char_name)
	return true

func get_equipped(slot: ItemData.EquipmentSlot, char_name: String) -> ItemData:
	if not character_equipment.has(char_name):
		return null
	return character_equipment[char_name].get(slot, null)

# -------------------------------------------------------------------------
# Skills — assign / read per character
# -------------------------------------------------------------------------

func set_skill(char_name: String, slot_index: int, skill: SkillData) -> void:
	if not character_skills.has(char_name):
		register_character(char_name)
	if slot_index >= 0 and slot_index < 4:
		character_skills[char_name][slot_index] = skill

func get_skills(char_name: String) -> Array:
	return character_skills.get(char_name, [null, null, null, null])

func unlock_skill(char_name: String, slot_index: int) -> void:
	var skills = get_skills(char_name)
	if slot_index >= 0 and slot_index < 4 and skills[slot_index] != null:
		skills[slot_index].is_unlocked = true
