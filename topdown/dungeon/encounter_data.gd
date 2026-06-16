class_name EncounterData
extends Resource

# Content for a random encounter room. Two flavors:
#   - `encounter_scene`: a fully custom mini-scene with its own logic
#   - dialogue-driven: a prompt + choices + outcomes (uses DialogueManager)

@export var encounter_name: String = "Encounter"
@export_multiline var description: String = ""

# Fully custom mini-scene. If set, the room instances this and the dialogue
# fields below are ignored.
@export var encounter_scene: PackedScene

@export_group("Dialogue Encounter")
@export var speaker_name: String = ""
@export_multiline var prompt_text: String = ""
# Each entry: { "text": String (button label), "outcome_id": String }
@export var choices: Array[Dictionary] = []

@export_group("Default Outcome")
# Applied when the encounter resolves "positively" (or always, if no branching).
@export var loot_table: LootTable
@export var karma_delta: int = 0
@export var strength_rep_delta: int = 0
@export var gold_delta: int = 0
