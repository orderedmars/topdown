extends Node2D

# Controller for the Adventurers Guild interior. On scene load it asks
# GuildManager to roll if it hasn't yet, then instantiates one AdventurerNPC
# at each spawn marker, bound to the corresponding template. Re-entering
# the guild between rerolls shows the same people sitting in the same seats.

const ADVENTURER_NPC_SCENE := preload("res://npc/adventurer_npc.tscn")


func _ready() -> void:
	GuildManager.roll_if_empty()
	_spawn_recruits()


func _spawn_recruits() -> void:
	var markers := $SpawnPoints.get_children()
	var recruits := GuildManager.current_recruits

	var count: int = min(recruits.size(), markers.size())
	for i in count:
		var marker: Node2D = markers[i]
		var npc := ADVENTURER_NPC_SCENE.instantiate()
		# Set the position BEFORE add_child so NPCBase._ready() seeds
		# wander_target from the correct location — otherwise the recruit
		# slowly drifts back toward (0, 0).
		npc.position = marker.position
		add_child(npc)
		npc.bind(recruits[i])
