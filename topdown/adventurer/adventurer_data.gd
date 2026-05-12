class_name AdventurerData
extends Resource

# Hand-authored adventurer template. The guild recruit pool holds references
# to these .tres files; when an adventurer is hired, the template is deep-
# duplicated (`.duplicate(true)`) so each instance owns its own run state.
# Templates are never mutated.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName = ""  # unique within a run
@export var display_name: String = "Adventurer"
@export_multiline var background: String = ""
@export var portrait_color: Color = Color.WHITE  # placeholder until portraits exist

@export var race: RaceData
@export var current_class: ClassData

@export var level: int = 1
@export var xp: int = 0

@export_group("Base Stats")
# Pre-modifier base. Final stat = base + race modifier + equipment bonus.
@export var max_health: int = 30
@export var max_mana: int = 10
@export var max_stamina: int = 50
@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10

@export_group("Loadout")
@export var learned_skills: Array[SkillData] = []
@export var equipped_skill_slots: Array[SkillData] = []  # max 4
# Key: ItemData.EquipmentSlot enum value (int). Value: ItemData or null.
@export var equipment: Dictionary = {}

@export_group("Proficiencies")
# Open-ended tags the combat system interprets (e.g. "sword", "fire_magic")
@export var weapon_proficiencies: Array[StringName] = []
@export var skill_proficiencies: Array[StringName] = []

@export_group("Recruit Pool")
@export var rarity: Rarity = Rarity.COMMON
# 1–5 typical. Higher tier needs higher Strength rep to roll.
@export var recruit_strength_tier: int = 1
# -1 evil, 0 neutral, +1 good. Karma-weighted recruit roll uses this.
@export var karma_alignment: int = 0
@export var hire_cost: int = 100
# Empty = always available. Otherwise gated behind the named achievement.
@export var unlock_achievement: StringName = ""

@export_group("Run State")
@export var is_dead: bool = false
@export var is_player_character: bool = false


func get_equipped(slot: int) -> ItemData:
	return equipment.get(slot, null)


func is_alive() -> bool:
	return not is_dead
