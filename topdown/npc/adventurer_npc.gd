extends NPCBase
class_name AdventurerNPC

# An NPC bound to an AdventurerData. Used in two places:
# - In the Adventurers Guild scene, bound to a template, where the player
#   can hire them. On hire we rebind to the run instance, register with
#   PartyManager, and add to RunState.party — the data becomes the source
#   of truth so the follower persists across scene changes.
# - Spawned by PartyManager in any scene the player enters, bound to a
#   roster instance, already configured as a follower.

var template: AdventurerData = null


func bind(t: AdventurerData) -> void:
	template = t
	if template == null:
		return

	npc_name = template.display_name
	sprite.color = template.portrait_color

	var rarity_word := _rarity_label(template.rarity)
	var class_word := template.current_class.class_title if template.current_class else "Wanderer"
	var race_word := template.race.race_name if template.race else ""

	greeting_idle = "%s\n\n%s\n\n[%s %s %s]" % [
		template.background,
		"\"%s\"" % _flavor_line_for(template),
		rarity_word,
		race_word,
		class_word,
	]
	greeting_party = "%s — what's the move?" % template.display_name


func interact() -> void:
	if template == null:
		super.interact()
		return

	# Already in the party — fall through to NPCBase's kick/stay dialog.
	if current_state == NPCState.FOLLOWING:
		super.interact()
		return

	var choices: Array = []
	var message: String = greeting_idle
	var price_line := "Hire for %dg" % template.hire_cost

	if PartyManager.party_members.size() >= PartyManager.max_party_size:
		message += "\n\n(Your party is full.)"
		choices.append({"text": "Maybe another time", "id": "cancel"})
	elif RunState.gold < template.hire_cost:
		message += "\n\n(You need %dg.)" % template.hire_cost
		choices.append({"text": "Come back when you've got coin", "id": "cancel"})
	else:
		choices.append({"text": price_line, "id": "hire"})
		choices.append({"text": "Not right now", "id": "cancel"})

	DialogueManager.show_dialogue(npc_name, message, choices)

	if not DialogueManager.choice_selected.is_connected(_on_recruit_choice):
		DialogueManager.choice_selected.connect(_on_recruit_choice)


func _on_recruit_choice(choice_id: String) -> void:
	if DialogueManager.choice_selected.is_connected(_on_recruit_choice):
		DialogueManager.choice_selected.disconnect(_on_recruit_choice)

	if choice_id != "hire":
		return

	var instance: AdventurerData = GuildManager.hire(template)
	if instance == null:
		return

	# Rebind to the run instance so PartyManager's reconciliation matches
	# this body to the new party slot instead of spawning a duplicate.
	template = instance
	current_state = NPCState.FOLLOWING
	sprite.color = Color.GREEN
	collision_layer = 0
	collision_mask = 1
	interaction_label.hide()
	InventoryManager.register_character(template.display_name)
	PartyManager.register_existing_body(self)

	# Data layer becomes the source of truth — from here on, this follower
	# survives scene changes by being re-spawned next to the player in
	# whatever scene loads next.
	RunState.add_to_party(instance)


# Override NPCBase.leave_party so the data layer is updated too. Without
# this, dismissing a follower would only remove the visual body; reconcile
# would then respawn them in the next scene from the lingering RunState
# entry.
func leave_party() -> void:
	if template != null:
		RunState.remove_from_party(template)
	super.leave_party()


# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------

func _rarity_label(r: int) -> String:
	match r:
		AdventurerData.Rarity.COMMON: return "Common"
		AdventurerData.Rarity.UNCOMMON: return "Uncommon"
		AdventurerData.Rarity.RARE: return "Rare"
		AdventurerData.Rarity.EPIC: return "Epic"
		AdventurerData.Rarity.LEGENDARY: return "Legendary"
	return "Common"


func _flavor_line_for(adv: AdventurerData) -> String:
	if adv.karma_alignment > 0:
		return "I look for honest work. Pay me fair and I'll see you home."
	if adv.karma_alignment < 0:
		return "I don't ask questions. Bring the gold."
	return "Coin is coin. Where are we headed?"
