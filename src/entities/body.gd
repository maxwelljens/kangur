extends Node
## Body — BodyModel wrapper. Applies class armor, translates hits/bandages into
## EventBus signals. HUD reads the getters; nothing here touches the Rig.
## Contract: docs/architecture.md §4 ("Body: BodyModel"), design §7.

## ClassDef armor is a durability pool; 0 means the slot is absent.
const NO_ARMOR := 0.0
const NO_BANDAGES := 0

var model: BodyModel = null
## Bandage charges left for this life (ClassDef.bandages).
var bandages_left: int = 0

var _host: Node2D = null

func setup(host: Node2D, class_def: ClassDef) -> void:
	_host = host
	var vest: float = class_def.armor_vest if class_def != null else NO_ARMOR
	var helmet: float = class_def.armor_helmet if class_def != null else NO_ARMOR
	model = BodyModel.new(vest > NO_ARMOR, helmet > NO_ARMOR)
	model.vest_durability = vest
	model.helmet_durability = helmet
	bandages_left = class_def.bandages if class_def != null else NO_BANDAGES

## One bullet. Emits character_hit with the damage actually taken (after armor
## and the part multiplier) so killfeed/damage numbers stay honest.
func apply_hit(part: int, base_dmg: float, pen: float, attacker: Node, armor_piercing: bool = false) -> HitResult:
	var result := HitResult.new()
	if model == null:
		return result
	result = model.apply_hit(part, base_dmg, pen, attacker, armor_piercing)
	var dealt := base_dmg * Enums.PART_DAMAGE_MULT[part] * pen - result.absorbed
	EventBus.character_hit.emit(
		_host, attacker, part, maxf(dealt, 0.0), result.died, _host.global_position)
	return result

## Bleed drain, regen, bandage channel. Detects channel completion for the
## bandage_finished event (BodyModel only flips its own flag).
func tick(dt: float) -> void:
	if model == null:
		return
	# Capture the channel target before the model zeroes its bleed on completion.
	var channel_part := _bandaged_part() if model.bandaging else -1
	var will_finish := model.bandaging \
		and model.bandage_progress + dt / BodyModel.BANDAGE_TIME >= 1.0
	model.tick(dt)
	if will_finish and not model.bandaging:
		EventBus.bandage_finished.emit(_host, channel_part)

func try_start_bandage() -> bool:
	if model == null or bandages_left <= 0:
		return false
	if not model.start_bandage():
		return false
	bandages_left -= 1
	EventBus.bandage_started.emit(_host)
	return true

## Cancel an active channel. No event: only start/finish are part of the
## EventBus contract (architecture §5); the HUD reads is_bandaging().
func interrupt_bandage() -> void:
	if model != null:
		model.interrupt_bandage()

func is_bandaging() -> bool:
	return model != null and model.bandaging

func bandage_progress() -> float:
	return model.bandage_progress if model != null else 0.0

func alive() -> bool:
	return model != null and model.alive

func part_hp(part: int) -> float:
	return model.part_hp(part) if model != null else 0.0

func part_ratio(part: int) -> float:
	return model.part_ratio(part) if model != null else 0.0

func is_bleeding_any() -> bool:
	return model != null and model.is_bleeding_any()

func bleed_total() -> float:
	return model.bleed_rate_total() if model != null else 0.0

func torso_ratio() -> float:
	return part_ratio(Enums.Part.TORSO)

func vest_durability() -> float:
	return model.vest_durability if model != null else 0.0

func helmet_durability() -> float:
	return model.helmet_durability if model != null else 0.0

## Target part of the active channel: the worst-hp part, matching BodyModel's
## own candidate choice (bleed first, then most damaged). -1 while idle.
func _bandaged_part() -> int:
	if model == null:
		return -1
	var target := -1
	var worst := 0.0
	for i: int in Enums.PART_COUNT:
		if model.bleed[i] <= 0.0:
			continue
		if model.bleed[i] > worst:
			worst = model.bleed[i]
			target = i
	if target >= 0:
		return target
	var worst_ratio := 1.0
	for i: int in Enums.PART_COUNT:
		if model.part_ratio(i) < worst_ratio:
			worst_ratio = model.part_ratio(i)
			target = i
	return target