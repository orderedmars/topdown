extends Node

signal party_updated

var party_members: Array[Node2D] = []
var max_party_size: int = 4

# How many frames of position history to keep per member
const HISTORY_SIZE = 100

func add_member(member: Node2D):
	if party_members.size() < max_party_size and not party_members.has(member):
		party_members.append(member)
		# Disable collision with world/player when joining party
		member.collision_layer = 0
		member.collision_mask = 0
		party_updated.emit()
		return true
	return false

func remove_member(member: Node2D):
	if party_members.has(member):
		party_members.erase(member)
		# Restore collision (assuming layer 2 for entities, 1 for world)
		member.collision_layer = 2
		member.collision_mask = 1
		party_updated.emit()
		return true
	return false

func get_leader() -> Node2D:
	return get_tree().get_first_node_in_group("player")

# This helps NPCs know who to follow in the "chain"
func get_follow_target(member: Node2D) -> Node2D:
	var index = party_members.find(member)
	if index == 0:
		return get_leader()
	elif index > 0:
		return party_members[index - 1]
	return null
