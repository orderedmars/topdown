extends Node

# Adventurers Guild singleton. Owns the recruit pool and the currently-rolled
# storefront. The roll persists between guild visits within a single trip to
# town so the player can leave and re-enter without the room reshuffling; it
# only refreshes when the design says so (currently: `clear_for_new_pool()`
# is called between dungeon expeditions — hook is exposed for the caller).

signal recruits_rolled
signal recruit_hired(adv: AdventurerData)
signal hire_failed(reason: String)

const RECRUITS_DIR := "res://adventurer/recruits/"
const STOREFRONT_SIZE := 5

# Base weight per rarity (lower = rarer). Used as the seed weight before
# tier/karma multipliers.
const RARITY_BASE_WEIGHT := {
	AdventurerData.Rarity.COMMON: 64,
	AdventurerData.Rarity.UNCOMMON: 32,
	AdventurerData.Rarity.RARE: 12,
	AdventurerData.Rarity.EPIC: 4,
	AdventurerData.Rarity.LEGENDARY: 1,
}

var pool: Array[AdventurerData] = []
var current_recruits: Array[AdventurerData] = []


func _ready() -> void:
	_load_pool()
	RunState.run_started.connect(_on_run_started)
	RunState.floor_changed.connect(_on_floor_changed)


func _on_run_started() -> void:
	# Fresh run wipes any stale recruits from the previous one.
	clear_for_new_pool()


func _on_floor_changed(new_floor: int) -> void:
	# Returning from a dungeon back to town refreshes the recruit pool so
	# the player sees a different crowd next time they walk into the guild.
	if new_floor == 0:
		clear_for_new_pool()


func _load_pool() -> void:
	pool.clear()
	var dir := DirAccess.open(RECRUITS_DIR)
	if dir == null:
		push_warning("GuildManager: could not open " + RECRUITS_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var res := load(RECRUITS_DIR + file) as AdventurerData
			if res != null:
				pool.append(res)
		file = dir.get_next()


# Roll a fresh storefront. Called when the player has done something that
# should refresh the guild (e.g., returned from a dungeon expedition).
func clear_for_new_pool() -> void:
	current_recruits.clear()
	roll_recruits()


# Called by the guild scene on enter. No-op if the storefront is already
# populated, so leaving and re-entering keeps the same five NPCs.
func roll_if_empty() -> void:
	if current_recruits.is_empty():
		roll_recruits()


func roll_recruits() -> void:
	current_recruits.clear()

	var eligible := _eligible_templates()
	var guaranteed: Array[AdventurerData] = []
	var rollable: Array[AdventurerData] = []
	for adv in eligible:
		if adv.guaranteed_spawn:
			guaranteed.append(adv)
		else:
			rollable.append(adv)

	# Pinned guaranteed picks go in first (truncated if there are more
	# guaranteed adventurers than seats; unlikely but safe).
	for adv in guaranteed:
		if current_recruits.size() >= STOREFRONT_SIZE:
			break
		current_recruits.append(adv)

	# Weighted random fill for the remaining slots.
	var remaining := STOREFRONT_SIZE - current_recruits.size()
	for _i in remaining:
		if rollable.is_empty():
			break
		var pick := _weighted_pick(rollable)
		current_recruits.append(pick)
		rollable.erase(pick)  # no duplicates in a single roll

	recruits_rolled.emit()


func hire(template: AdventurerData) -> AdventurerData:
	if template == null:
		hire_failed.emit("invalid")
		return null
	if RunState.gold < template.hire_cost:
		hire_failed.emit("gold")
		return null

	# If they were hired earlier this run and later dismissed alive, reuse
	# the existing roster instance so we don't lose accumulated level,
	# equipment, or skill state. Otherwise mint a fresh run instance from
	# the immutable template.
	var instance: AdventurerData = _find_roster_instance(template.id)
	if instance != null:
		if instance.is_dead:
			hire_failed.emit("dead")
			return null
		if instance in RunState.party:
			hire_failed.emit("already_hired")
			return null
	else:
		instance = template.duplicate(true)
		RunState.roster.append(instance)

	RunState.adjust_gold(-template.hire_cost)

	# Take them out of the storefront so the seat empties out for this visit.
	current_recruits.erase(template)

	recruit_hired.emit(instance)
	return instance


func _find_roster_instance(adv_id: StringName) -> AdventurerData:
	for member in RunState.roster:
		if member.id == adv_id:
			return member
	return null


# -------------------------------------------------------------------------
# Eligibility + weighting
# -------------------------------------------------------------------------

func _eligible_templates() -> Array[AdventurerData]:
	var out: Array[AdventurerData] = []
	for adv in pool:
		if not _is_eligible(adv):
			continue
		out.append(adv)
	return out


func _is_eligible(adv: AdventurerData) -> bool:
	if adv.unlock_achievement != StringName("") and not _achievement_unlocked(adv.unlock_achievement):
		return false
	if RunState.strength_rep < adv.min_strength_rep:
		return false
	if RunState.karma < adv.min_karma or RunState.karma > adv.max_karma:
		return false
	# Currently in the party? They're already with you — don't double-roll.
	# Already permadied this run? They never come back. Otherwise (including
	# dismissed-alive adventurers) they're free to roll into the pool again.
	var hired := _find_roster_instance(adv.id)
	if hired != null:
		if hired.is_dead:
			return false
		if hired in RunState.party:
			return false
	return true


func _achievement_unlocked(_achievement: StringName) -> bool:
	# Meta-progression layer doesn't exist yet. Until it does, any recruit
	# with an `unlock_achievement` set is treated as locked. This keeps
	# secret unlocks invisible by default — flip this when the achievement
	# autoload lands.
	return false


func _weighted_pick(candidates: Array[AdventurerData]) -> AdventurerData:
	var total := 0.0
	var weights: Array[float] = []
	for adv in candidates:
		var w := _weight_for(adv)
		weights.append(w)
		total += w

	if total <= 0.0:
		return candidates[randi() % candidates.size()]

	var roll := randf() * total
	var acc := 0.0
	for i in candidates.size():
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates.back()


func _weight_for(adv: AdventurerData) -> float:
	var w: float = RARITY_BASE_WEIGHT.get(adv.rarity, 1)

	# Tier bias — recruits whose tier matches the player's progression band
	# get a boost; mismatched tiers are damped (but never zero, so very
	# strong recruits can still occasionally surprise low-rep players).
	var ideal_tier: float = 1.0 + float(RunState.strength_rep) / 4.0
	var tier_distance: float = abs(float(adv.recruit_strength_tier) - ideal_tier)
	var tier_mult: float = 1.0 / (1.0 + tier_distance * 0.6)

	# Karma alignment — neutral recruits are always unmodified. Aligned
	# recruits get boosted when the player's karma matches their sign and
	# damped when it doesn't.
	var karma_mult := 1.0
	if adv.karma_alignment != 0:
		var same_sign := (adv.karma_alignment > 0 and RunState.karma > 0) \
				or (adv.karma_alignment < 0 and RunState.karma < 0)
		if same_sign:
			karma_mult = 1.0 + clamp(abs(RunState.karma) / 5.0, 0.0, 1.5)
		elif RunState.karma == 0:
			karma_mult = 1.0
		else:
			karma_mult = 0.4

	return w * tier_mult * karma_mult
