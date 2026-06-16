class_name ItemData
extends Resource

enum ItemType { CONSUMABLE, WEAPON, ARMOUR, SOUL, KEY_ITEM }

enum EquipmentSlot { NONE, WEAPON, OFFHAND, HEAD, BODY, LEGGINGS, BOOTS, ACCESSORY, SOUL }

enum ConsumableTarget { NONE, HEALTH, MANA, STAMINA, ALL }

enum SoulPassiveType { NONE, MOVE_SPEED, MAX_HEALTH, MAX_MANA, DAMAGE_BONUS, DEFENCE_BONUS }

@export var item_name: String = "Item"
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var color: Color = Color.WHITE  # placeholder until real sprites exist
@export var max_stack: int = 1

# Consumable fields
@export_group("Consumable")
@export var consumable_target: ConsumableTarget = ConsumableTarget.NONE
@export var effect_value: float = 0.0

# Equipment fields — slot this item occupies when equipped
@export_group("Equipment")
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var stat_bonus_health: float = 0.0
@export var stat_bonus_mana: float = 0.0
@export var stat_bonus_stamina: float = 0.0
@export var stat_bonus_damage: float = 0.0
@export var stat_bonus_defence: float = 0.0
@export var stat_bonus_speed: float = 0.0

# Soul fields — filled in when item_type == SOUL
@export_group("Soul")
@export var soul_passive_type: SoulPassiveType = SoulPassiveType.NONE
@export var soul_passive_value: float = 0.0
@export_multiline var soul_passive_description: String = ""
