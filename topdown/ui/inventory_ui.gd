extends CanvasLayer

# Which character's equipment panel is currently shown.
var current_character: String = "Player"
var is_open: bool = false

@onready var backdrop = $Backdrop
@onready var item_list = $Backdrop/Panel/Margin/VBox/ContentSplit/LeftPane/ItemScroll/ItemList
@onready var char_tabs = $Backdrop/Panel/Margin/VBox/ContentSplit/RightPane/CharTabs
@onready var slot_list = $Backdrop/Panel/Margin/VBox/ContentSplit/RightPane/SlotList
@onready var close_btn = $Backdrop/Panel/Margin/VBox/TitleBar/CloseBtn

const SLOT_NAMES = {
	ItemData.EquipmentSlot.WEAPON:    "Weapon",
	ItemData.EquipmentSlot.OFFHAND:   "Off-hand",
	ItemData.EquipmentSlot.HEAD:      "Head",
	ItemData.EquipmentSlot.BODY:      "Body",
	ItemData.EquipmentSlot.LEGGINGS:  "Leggings",
	ItemData.EquipmentSlot.BOOTS:     "Boots",
	ItemData.EquipmentSlot.ACCESSORY: "Accessory",
	ItemData.EquipmentSlot.SOUL:      "Soul",
}

func _ready() -> void:
	close_btn.pressed.connect(close)
	InventoryManager.inventory_changed.connect(_refresh_inventory)
	InventoryManager.equipment_changed.connect(_on_equipment_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		toggle()
	elif event.is_action_pressed("ui_cancel") and is_open:
		close()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	is_open = true
	backdrop.visible = true
	_refresh_char_tabs()
	_refresh_inventory()
	_refresh_equipment()
	get_viewport().set_input_as_handled()

func close() -> void:
	is_open = false
	backdrop.visible = false

# -------------------------------------------------------------------------
# Refresh helpers
# -------------------------------------------------------------------------

func _refresh_inventory() -> void:
	for child in item_list.get_children():
		child.queue_free()

	if InventoryManager.main_inventory.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No items."
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		item_list.add_child(empty_label)
		return

	for entry in InventoryManager.main_inventory:
		var item: ItemData = entry["item"]
		var qty: int = entry["quantity"]
		item_list.add_child(_make_item_row(item, qty))

func _refresh_equipment() -> void:
	for child in slot_list.get_children():
		child.queue_free()

	for slot in SLOT_NAMES.keys():
		var equipped: ItemData = InventoryManager.get_equipped(slot, current_character)
		slot_list.add_child(_make_slot_row(slot, equipped))

func _refresh_char_tabs() -> void:
	for child in char_tabs.get_children():
		child.queue_free()

	var characters = _get_party_names()
	for char_name in characters:
		var btn = Button.new()
		btn.text = char_name
		btn.toggle_mode = true
		btn.button_pressed = (char_name == current_character)
		btn.pressed.connect(func():
			current_character = char_name
			_refresh_char_tabs()
			_refresh_equipment()
		)
		char_tabs.add_child(btn)

func _on_equipment_changed(char_name: String) -> void:
	if char_name == current_character:
		_refresh_equipment()

# -------------------------------------------------------------------------
# Row builders
# -------------------------------------------------------------------------

func _make_item_row(item: ItemData, qty: int) -> HBoxContainer:
	var row = HBoxContainer.new()

	# Colour swatch placeholder for icon
	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(20, 20)
	swatch.color = item.color
	row.add_child(swatch)

	# Name + quantity
	var name_label = Label.new()
	name_label.text = "%s  x%d" % [item.item_name, qty]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if item.item_type == ItemData.ItemType.SOUL:
		name_label.text += "  [Soul]"
	row.add_child(name_label)

	# Action button
	var action_btn = Button.new()
	match item.item_type:
		ItemData.ItemType.CONSUMABLE:
			action_btn.text = "Use"
			action_btn.pressed.connect(func(): _on_use_pressed(item))
		ItemData.ItemType.WEAPON, ItemData.ItemType.ARMOUR, ItemData.ItemType.SOUL:
			action_btn.text = "Equip"
			action_btn.pressed.connect(func(): _on_equip_pressed(item))
		_:
			action_btn.text = "—"
			action_btn.disabled = true
	row.add_child(action_btn)

	# Tooltip-style description on hover via tooltip_text
	row.tooltip_text = item.description
	if item.item_type == ItemData.ItemType.SOUL and item.soul_passive_type != ItemData.SoulPassiveType.NONE:
		row.tooltip_text += "\nPassive: " + item.soul_passive_description

	return row

func _make_slot_row(slot: ItemData.EquipmentSlot, equipped: ItemData) -> HBoxContainer:
	var row = HBoxContainer.new()

	var slot_label = Label.new()
	slot_label.text = SLOT_NAMES[slot]
	slot_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(slot_label)

	var item_label = Label.new()
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if equipped:
		item_label.text = equipped.item_name
		item_label.modulate = equipped.color
	else:
		item_label.text = "—"
		item_label.modulate = Color(0.5, 0.5, 0.5)
	row.add_child(item_label)

	if equipped:
		var unequip_btn = Button.new()
		unequip_btn.text = "Remove"
		unequip_btn.pressed.connect(func(): _on_unequip_pressed(slot))
		row.add_child(unequip_btn)

	return row

# -------------------------------------------------------------------------
# Actions
# -------------------------------------------------------------------------

func _on_use_pressed(item: ItemData) -> void:
	var character = _get_character_node(current_character)
	if character:
		InventoryManager.use_item(item, character)

func _on_equip_pressed(item: ItemData) -> void:
	InventoryManager.equip_item(item, current_character)
	_refresh_equipment()

func _on_unequip_pressed(slot: ItemData.EquipmentSlot) -> void:
	InventoryManager.unequip_item(slot, current_character)
	_refresh_equipment()

# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------

func _get_party_names() -> Array:
	var names = ["Player"]
	for member in PartyManager.party_members:
		if "npc_name" in member:
			names.append(member.npc_name)
	return names

func _get_character_node(char_name: String) -> Node:
	if char_name == "Player":
		return get_tree().get_first_node_in_group("player")
	for member in PartyManager.party_members:
		if "npc_name" in member and member.npc_name == char_name:
			return member
	return null
