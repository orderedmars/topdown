class_name SkillData
extends Resource

enum SkillType { ACTIVE, PASSIVE }
enum TargetType { SELF, SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES }

@export var skill_name: String = "Skill"
@export_multiline var description: String = ""
@export var skill_type: SkillType = SkillType.ACTIVE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var color: Color = Color.WHITE  # placeholder for skill icon
@export var is_unlocked: bool = false

@export_group("Costs")
@export var mana_cost: float = 0.0
@export var stamina_cost: float = 0.0
@export var cooldown: float = 0.0

@export_group("Effect")
@export var base_damage: float = 0.0
@export var base_heal: float = 0.0
@export var effect_duration: float = 0.0
