class_name RaceData
extends Resource

@export var race_name: String = "Race"
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE  # placeholder until race portrait sprites exist

@export_group("Stat Modifiers")
@export var modifier_strength: int = 0
@export var modifier_dexterity: int = 0
@export var modifier_constitution: int = 0
@export var modifier_intelligence: int = 0
@export var modifier_wisdom: int = 0
@export var modifier_charisma: int = 0

@export_group("Passive")
# Race-locked passive skill (SkillData with skill_type = PASSIVE)
@export var passive: SkillData

@export_group("Race-Only Skills")
# Skills the player can unlock at this race's village as their level rises
@export var race_skills: Array[SkillData] = []
