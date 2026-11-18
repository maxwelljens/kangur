class_name RangeController
extends Node2D
## Training Range (design §10 "Training Range"): solo player, no AI. Turns the
## authored `Markers` metadata into practice dummies and weapon racks, and
## keeps a live spread/recoil/TTK readout.
##
## Dummies are real Characters with `is_player = false, ai = false` and no
## weapon: hits go through the production BodyModel/Character pipeline (armor,
## parts, bleeding), so what you learn here holds in a match. They sit on the
## player's team, so vision/fairness systems ignore them.

const TargetScript := preload("res://src/entities/character.tscn")
const KangurTheme := preload("res://src/ui/theme.gd")

const KIND_TARGET := "target_dummy"
const KIND_RACK := "weapon_rack"
const KIND_BANDAGE := "bandage_dummy"
## Rail oscillation for dummies authored with `rail = true` (maps.md).
const RAIL_AMPLITUDE_PX := 96.0
const RAIL_PERIOD_S := 4.0
## Rack / dummy reach, px (stand next to it and press E).
const REACH_PX := 56.0
const READOUT_HZ := 8.0
## Wound the bandage dummy inflicts (a live bleed to channel against).
const DUMMY_WOUND_DAMAGE := 6.0
## Dummy class: paper target, no armor/kit.
const DUMMY_CLASS := &"vanguard"

var run: Match = null
var targets: Array[Character] = []
var racks: Array[Vector2] = []
var bandage_dummy: Node2D = null

var _rails: Dictionary[Character, Dictionary] = {}
## Rail phase clock: advanced from the physics tick, never wall clock, so a
## headless sim reaches the same dummy positions as a live session.
var _clock := 0.0
var _rack_index := 0
var _readout_accum := 0.0
var _label: Label = null
var _shots := 0
var _hits := 0
var _last_distance_m := 0.0
var _last_ttk := 0.0
var _hit_since: Dictionary = {}


func setup(match_ref: Match) -> void:
	run = match_ref
	_build()
	_build_readout()
	_place_player()
	EventBus.shot_fired.connect(_on_shot)
	EventBus.character_hit.connect(_on_hit)


func _exit_tree() -> void:
	if EventBus.shot_fired.is_connected(_on_shot):
		EventBus.shot_fired.disconnect(_on_shot)
	if EventBus.character_hit.is_connected(_on_hit):
		EventBus.character_hit.disconnect(_on_hit)


## Stand on the middle firing-line marker: the authored lanes are x 8/16/24/32/40
## at y=26 (maps.md Range); the centre one puts the operator under the reticle
## with the target rows ahead instead of against the HUD edge.
func _place_player() -> void:
	if run == null or run.player == null or run.world == null or run.world.map == null:
		return
	var markers := run.world.map.get_node_or_null(^"Markers")
	if markers == null:
		return
	var lanes: Array[Node2D] = []
	for child: Node in markers.get_children():
		if String(child.get_meta(&"kind", "")) == "firing_line":
			lanes.append(child as Node2D)
	if lanes.is_empty():
		return
	lanes.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.x < b.position.x)
	run.player.global_position = lanes[lanes.size() / 2].global_position


func _physics_process(dt: float) -> void:
	if run == null or run.player == null:
		return
	_tick_rails(dt)
	_tick_infinite_ammo()
	if Input.is_action_just_pressed(&"use"):
		_interact()
	_readout_accum += dt
	if _readout_accum >= 1.0 / READOUT_HZ:
		_readout_accum = 0.0
		_refresh_readout()


# --- world ------------------------------------------------------------------

func _build() -> void:
	if run.world == null or run.world.map == null:
		return
	var root := run.world.map.get_node_or_null(^"Markers")
	if root == null:
		push_warning("RangeController: map has no Markers node (range metadata)")
		return
	for child: Node in root.get_children():
		match String(child.get_meta(&"kind", "")):
			KIND_TARGET:
				var dummy := _spawn_dummy(child as Node2D)
				targets.append(dummy)
				if bool(child.get_meta(&"rail", false)):
					_rails[dummy] = {&"origin": (child as Node2D).global_position,
						&"lane": float(child.get_meta(&"lane", 0.0))}
			KIND_RACK:
				racks.append((child as Node2D).global_position)
			KIND_BANDAGE:
				bandage_dummy = child as Node2D


func _spawn_dummy(marker: Node2D) -> Character:
	var dummy: Character = TargetScript.instantiate()
	dummy.position = marker.global_position
	run.characters_node.add_child(dummy)
	dummy.setup({
		&"team": run.player.team if run.player != null else Enums.Team.BASTION,
		&"class_id": DUMMY_CLASS, &"callsign": String(marker.name),
		&"is_player": false, &"ai": false, &"seed": hash(marker.name),
		&"primary_id": &"", &"sidearm_id": &"",
	})
	# No brain at all: Character._physics_process would otherwise run the
	# PlayerController it falls back to for `ai = false` (cursor aim + trigger),
	# so freeze the whole node. Hits still land through apply_hit().
	dummy.set_physics_process(false)
	dummy.set_physics_process_internal(false)
	return dummy


func _tick_rails(dt: float) -> void:
	_clock += dt
	for dummy: Character in _rails:
		if dummy == null or not is_instance_valid(dummy):
			continue
		var rail: Dictionary = _rails[dummy]
		var offset := sin(_clock * TAU / RAIL_PERIOD_S + float(rail[&"lane"])) \
			* RAIL_AMPLITUDE_PX
		dummy.global_position = rail[&"origin"] + Vector2.RIGHT * offset


## The toggle is a setting so it survives across range sessions.
func _tick_infinite_ammo() -> void:
	if not bool(Settings.get_value(&"gameplay", &"infinite_ammo", false)):
		return
	for weapon: WeaponModel in [run.player.arsenal.primary, run.player.arsenal.sidearm]:
		if weapon != null:
			weapon.reserve_rounds = maxi(weapon.reserve_rounds, weapon.def.mag_size)


func _interact() -> void:
	var player := run.player
	if player == null or not player.alive:
		return
	var pos := player.global_position
	if bandage_dummy != null and pos.distance_to(bandage_dummy.global_position) <= REACH_PX:
		player.apply_hit(Enums.Part.LEG_L, DUMMY_WOUND_DAMAGE, 1.0, null)
		return
	for rack: Vector2 in racks:
		if pos.distance_to(rack) <= REACH_PX:
			_cycle_rack()
			return


## Any indexed weapon can be drawn here (design §10), not just class ones.
func _cycle_rack() -> void:
	var weapons := Defs.all_weapons()
	if weapons.is_empty():
		return
	_rack_index = (_rack_index + 1) % weapons.size()
	var def: WeaponDef = weapons[_rack_index]
	var player := run.player
	var weapon: WeaponModel = player.arsenal.call(&"_make_weapon", def.id, def)
	player.arsenal.primary = weapon
	player.arsenal.slot = player.arsenal.SLOT_PRIMARY
	weapon.equip()
	weapon.equip_timer = 0.0
	player.rig.set_weapon(def)
	EventBus.weapon_switched.emit(player, def.id)


# --- stats ------------------------------------------------------------------

func _on_shot(shooter: Node, _weapon: StringName, _origin: Vector2,
		_dir: Vector2, pellets: int) -> void:
	if shooter == run.player:
		_shots += maxi(pellets, 1)


func _on_hit(victim: Node, attacker: Node, _part: int, _damage: float,
		fatal: bool, _pos: Vector2) -> void:
	if attacker != run.player or not (victim is Character):
		return
	_hits += 1
	if not _hit_since.has(victim):
		_hit_since[victim] = run.elapsed
	_last_distance_m = run.player.global_position.distance_to(
		(victim as Character).global_position) / Tiles.SIZE
	if fatal:
		_last_ttk = run.elapsed - float(_hit_since.get(victim, run.elapsed))
		_hit_since.erase(victim)
		_revive_dummy(victim as Character)


func _revive_dummy(dummy: Character) -> void:
	dummy.body.setup(dummy, dummy.class_def)
	dummy.alive = true
	dummy.body.model.alive = true
	dummy.rig.call(&"revive")
	dummy.pending_shots.clear()


# --- readout ----------------------------------------------------------------

func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -330.0
	panel.offset_right = -24.0
	panel.offset_top = 132.0
	panel.offset_bottom = 320.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color(KangurTheme.PANEL_SOLID, 0.86)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	_label = Label.new()
	_label.position = Vector2(14.0, 10.0)
	_label.theme_type_variation = &"MonoSmall"
	_label.add_theme_color_override(&"font_color", KangurTheme.TEXT)
	panel.add_child(_label)
	var note := Label.new()
	note.text = "E at a rack: next weapon   ·   E at the red dummy: take a wound"
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	note.offset_left = 24.0
	note.offset_right = -24.0
	note.offset_top = -48.0
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.theme_type_variation = &"MonoSmall"
	note.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	layer.add_child(note)
	_refresh_readout()


func _refresh_readout() -> void:
	var player := run.player
	if player == null or _label == null:
		return
	var current := player.arsenal.current()
	var def := player.arsenal.current_def()
	var accuracy := 0.0 if _shots <= 0 else float(_hits) / float(_shots)
	_label.text = "\n".join(PackedStringArray([
		"RANGE READOUT",
		"WEAPON    %s" % (def.display_name.to_upper() if def != null else "—"),
		"SPREAD    %.2f°   bloom %.2f°" % [player.spread_deg(),
			current.bloom if current != null else 0.0],
		"RECOIL    %.1f px" % (current.recoil_offset.length() if current != null else 0.0),
		"AMMO      %d / %d%s" % [player.mag(), player.reserve_rounds(),
			"   ∞" if bool(Settings.get_value(&"gameplay", &"infinite_ammo", false)) else ""],
		"SHOTS %d   HITS %d   ACC %s" % [_shots, _hits, KangurTheme.format_pct(accuracy)],
		"LAST TTK  %s   @ %.0f m" % ["—" if _last_ttk <= 0.0 else "%.2fs" % _last_ttk,
			_last_distance_m],
	]))


## Lobby/console toggle for infinite ammo (persisted like any setting).
func set_infinite_ammo(on: bool) -> void:
	Settings.set_value(&"gameplay", &"infinite_ammo", on)