extends Node

# Cross-scene party system. Followers persist via their AdventurerData living
# in `RunState.party` (slot 0 = player). Each scene the player enters, one
# follower body is spawned per data slot 1..N next to the player. Bodies are
# transient (freed with their scene); the data is the source of truth, so
# walking from town → dungeon → guild → town carries the same follower along.

signal party_updated

const FOLLOWER_BODY_SCENE := preload("res://npc/adventurer_npc.tscn")
const HISTORY_SIZE = 100

# Live follower bodies in the current scene. Order mirrors RunState.party[1..]
# for data-backed followers, with any legacy (non-data) NPC bodies appended.
var party_members: Array[Node2D] = []
# Max follower count (excludes the player). 4 followers → 5 total in party.
var max_party_size: int = 4


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	RunState.party_changed.connect(_reconcile_deferred)


# -------------------------------------------------------------------------
# Reconciliation — keeps party_members in sync with RunState.party
# -------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	# A new Player just entered the tree, which happens on scene change.
	# Defer reconcile so the rest of the scene has finished building.
	if node.is_in_group("player"):
		_reconcile_deferred()


func _reconcile_deferred() -> void:
	call_deferred("_reconcile_now")


func _reconcile_now() -> void:
	var leader := get_leader()
	if leader == null:
		return
	var parent: Node = leader.get_parent()
	if parent == null:
		return

	# Drop bodies whose nodes were freed (e.g. by the previous scene change).
	var live_members: Array[Node2D] = []
	for body in party_members:
		if is_instance_valid(body):
			live_members.append(body)
	party_members = live_members

	# Separate data-backed bodies (have a `template`) from legacy bodies.
	# Legacy bodies are world NPCs like John who joined via add_member()
	# without an AdventurerData behind them — they stay scene-local and
	# don't participate in reconciliation against RunState.party.
	var data_backed: Array[Node2D] = []
	var legacy: Array[Node2D] = []
	for body in party_members:
		if "template" in body and body.template != null:
			data_backed.append(body)
		else:
			legacy.append(body)

	# Mirror RunState.party[1..] with data-backed bodies, reusing matches
	# and spawning new bodies for follower data that has no body yet.
	var new_data_bodies: Array[Node2D] = []
	var unmatched := data_backed.duplicate()
	for i in range(1, RunState.party.size()):
		var data: AdventurerData = RunState.party[i]
		var existing := _find_body_for(data, unmatched)
		if existing != null:
			new_data_bodies.append(existing)
			unmatched.erase(existing)
		else:
			var spawned := _spawn_follower_body(data, parent, leader, i)
			new_data_bodies.append(spawned)

	# Anyone still unmatched had their data dropped from the party — free
	# their body (e.g. dismissed via dialogue while in the world).
	for body in unmatched:
		if is_instance_valid(body):
			body.queue_free()

	party_members = new_data_bodies + legacy
	party_updated.emit()


func _find_body_for(data: AdventurerData, candidates: Array) -> Node2D:
	for body in candidates:
		if not is_instance_valid(body):
			continue
		if "template" in body and body.template == data:
			return body
	return null


func _spawn_follower_body(data: AdventurerData, parent: Node, leader: Node2D, slot_index: int) -> Node2D:
	var body: Node2D = FOLLOWER_BODY_SCENE.instantiate()
	# Stagger the spawn offset per slot so multiple followers don't stack.
	body.position = leader.position + Vector2(-30 - slot_index * 4, 30 + slot_index * 6)
	parent.add_child(body)
	if body.has_method("bind"):
		body.bind(data)
	# Already hired — skip the recruit dialog flow and start following.
	body.current_state = body.NPCState.FOLLOWING
	body.collision_layer = 0
	body.collision_mask = 1
	if "sprite" in body and body.sprite != null:
		body.sprite.color = Color.GREEN
	InventoryManager.register_character(data.display_name)
	return body


# -------------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------------

func get_leader() -> Node2D:
	return get_tree().get_first_node_in_group("player")


# Used by NPCBase.handle_following. Index 0 in party_members follows the
# player; later indices chain off the previous member.
func get_follow_target(member: Node2D) -> Node2D:
	var index := party_members.find(member)
	if index <= 0:
		return get_leader()
	return party_members[index - 1]


# Called by an AdventurerNPC that just got hired in-place — it's already
# correctly positioned and configured as a follower, so we register it
# without going through the spawn path. Reconcile will then match it
# against the new RunState.party entry instead of duplicating.
func register_existing_body(body: Node2D) -> void:
	if not party_members.has(body):
		party_members.append(body)


# -------------------------------------------------------------------------
# Legacy API — for world NPCs that have no AdventurerData (e.g. John).
# These bodies survive only within their scene; cross-scene persistence
# requires going through the data-backed flow above.
# -------------------------------------------------------------------------

func add_member(member: Node2D) -> bool:
	if party_members.size() >= max_party_size:
		return false
	if party_members.has(member):
		return false
	party_members.append(member)
	party_updated.emit()
	return true


func remove_member(member: Node2D) -> bool:
	if not party_members.has(member):
		return false
	party_members.erase(member)
	# Restore default collision (entity layer 2 over world layer 1) so the
	# dismissed NPC behaves like a normal world NPC again.
	member.collision_layer = 2
	member.collision_mask = 1
	party_updated.emit()
	return true
