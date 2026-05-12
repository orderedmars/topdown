class_name ClassData
extends Resource

@export var class_title: String = "Class"
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE  # placeholder until class icons exist

@export_group("Starter Kit")
# Granted when this is the starter class chosen at character creation
@export var starter_items: Array[ItemData] = []
@export var starter_skills: Array[SkillData] = []

@export_group("Skill Pool")
# Skills available to learn while in this class (unlock as level rises)
@export var skill_pool: Array[SkillData] = []

@export_group("Evolution")
# 0 = no further evolution. When level >= evolution_level, the player picks
# one of `evolutions` (Pokemon-style split branching). Each branch is itself
# a ClassData with its own evolution chain.
@export var evolution_level: int = 0
@export var evolutions: Array[ClassData] = []

@export_group("Unlocks")
# Empty = always available. Otherwise, this class is gated behind the named
# achievement (e.g., "kill_100_zombies"). Resolved by the meta-progression layer.
@export var unlock_achievement: StringName = ""
