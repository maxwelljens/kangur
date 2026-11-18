extends Node2D
## Promo capture fixture: one scene, one segment per run. Every segment boots a
## REAL Match (real ballistics, BodyModel, AI, HUD, fog) and choreographs the
## player body through the AIController manual-driver surface — the same Intent
## pipeline a human fills, so nothing on screen is mocked.
##
##   tools/godot.sh --path . --audio-driver Dummy --fixed-fps 30 \
##     --write-movie /tmp/…/raw/combat.png --quit-after 380 \
##     tools/promo/promo_shot.tscn -- --seg=combat
##
## Segments: deploy, combat, combat_slow, wounds, smoke, ai, battle, debrief.
## (title/lobby run their own scenes directly; capture.sh handles those.)
##
## `--still=<seg>` stages the same segment for a one-frame `--shot` capture.
##
## Scripted steps are indexed by physics tick, never wall clock: movie mode runs
## unlocked and delivers a fixed dt, so wall clock would drift.

const MatchScene := preload("res://src/modes/match/match.tscn")
const AiArenaScene := preload("res://tools/shot_ai.tscn")

## Every staged segment spends this many ticks posing before the money moment.
const BOOT_TICKS := 16
## Battle spends longer reaching the objective; that warm-up is trimmed.
const BATTLE_WARMUP := 300

## Head frames capture.sh drops (it reads the `PROMO_TRIM` line this prints).
## Only Battle hides a long warm-up; the staged segments keep their boot lead,
## which reads as anticipation rather than filler.
const TRIM_FRAMES: Dictionary[StringName, int] = {
	&"battle": 150,
	## Fallback only: the debrief measures its own trim once the scene is live.
	&"debrief": 150,
}

## dustworks: 800 px open lane at y≈688 (x=1600..2396); low-cover crates sit at
## x=1536..1568. The player fights east down that lane with the crates behind.
const DUST_PLAYER := Vector2(1700.0, 690.0)
const DUST_ENEMY := Vector2(2080.0, 690.0)
const DUST_ENEMY_FAR := Vector2(2300.0, 720.0)
const DUST_CAMERA := Vector2(1930.0, 700.0)
## compound: 1084 px open north lane at y≈324..380, plus the hall mouth south
## of the crates. Smoke + frag staging uses the wide floor at x=320..1400.
const COMP_LANE_Y := 650.0
const COMP_PLAYER := Vector2(520.0, COMP_LANE_Y)
## The frag is thrown AFTER the advance, so it lands `THROW_REACH` past where
## the squad stopped — that is where the enemy line has to stand for the blast
## (90 px radius) to reach them while the thrower stays well outside it.
const THROW_REACH := 116.0
## Enemies stand just past the smoke's far edge (cloud centre 172 px out, radius
## 140) so the blast reads on bodies the fog is not covering.
const COMP_ENEMY_RANGE := 350.0
const COMP_ENEMY_GAP := 58.0
const COMP_CAMERA := COMP_PLAYER + Vector2(COMP_ENEMY_RANGE * 0.55, 0.0)
const COMP_ZOOM := 1.7
## terminal: A is the first objective (rect 1344,1408 384x192).
const BATTLE_CAMERA := Vector2(1536.0, 1470.0)

const AIM_EAST := Vector2(1.0, 0.0)
const AIM_WEST := Vector2(-1.0, 0.0)

## Zoom for staged segments. 1080p at 2.2 shows a 873x491 world window: two
## 26 px operators read as bodies, and a 700 px tracer lane still fits.
const STAGED_ZOOM := 2.2

# --- combat beats (ticks; 120 ticks = 2 s at 60 Hz) -------------------------
const C_SPRINT_END := 120
const C_BRACE_END := 240
const C_FIRE_END := 420
const C_RELOAD_END := 540
const BURST_ON := 22
const BURST_OFF := 16
const C_ENEMY_BURST := 10
const C_ENEMY_PERIOD := 84
const C_ENEMY_START := 10
## Return fire stops once the hero torso drops below this: the take must not end
## with the player dead. The enemy also aims this far past the hero, so its
## bursts are real misses instead of a corpse.
const C_ENEMY_STOP_RATIO := 0.45
const MISS_BY_PX := 120.0

# --- combat_slow ------------------------------------------------------------
const CS_FIRE_TICK := 50

# --- wounds -----------------------------------------------------------------
## Legs are the body's rear half in the player's own facing frame
## (BodyModel.part_at_offset: forward < -8). Measured with probe_hud.tscn: a
## round aimed 20 px behind the hips lands on a LEG and starts real bleeding;
## 16 px is still torso and 32 px clips an arm.
const WOUND_LEG_LEAD := 20.0
## The shooter stands behind the hero's facing, so the round comes from off the
## fog cone: the hit is heard and felt, not seen coming.
const W_SHOT_TICK := 120
const W_SHOT_ROUNDS := 2
const W_SHOT_GAP := 12
## Limp to the crate at x≈1568. One burst already crippled the leg, so this is
## the real ×0.55 speed, not a scripted slow-motion.
const W_LIMP_TICK := 250
const W_LIMP_END := 360
const W_BANDAGE_TICK := 370
## BodyModel.BANDAGE_TIME is 2.8 s = 168 ticks. Release the hold a few ticks
## after that: holding longer re-starts the channel (Character re-arms it every
## tick while the button is down) and burns a second charge.
const W_BANDAGE_HOLD := 172

# --- smoke ------------------------------------------------------------------
## Throws go through Arsenal -> EventBus -> EquipmentSystem: the grenade leaves
## the thrower's hand and flies along their aim (420 px/s, ~170 px of travel
## before the fuse), so these are timings only.
const S_SMOKE_TICK := 40
const S_ADVANCE_TICK := 150
const S_ADVANCE_END := 290
## How far the squad walks from its start: through the cloud, to its far edge.
## The frag is thrown from there, so it lands on the enemy line and not on the
## squad (the thrower must be outside the 90 px blast).
const S_ADVANCE_PX := 190.0
## Frag goes out while the squad is in the smoke so the blast and the camera
## shake land inside the 8 s clip.
const S_FRAG_TICK := 300

var run: Match = null
var seg: StringName = &""
var _ticks := 0
var _allies: Array[Character] = []
var _enemies: Array[Character] = []
var _shooter: Character = null
var _arena: Node = null
## False until _stage() has finished: physics ticks before that would drive a
## body whose controller is still the default PlayerController.
var _staged := false
## Rendered frame the process started on, for the debrief's measured trim.
var _boot_frame := 0


func _ready() -> void:
	_boot_frame = Engine.get_process_frames()
	var spec := _spec()
	seg = spec[&"seg"]
	print("PROMO_TRIM %d" % int(TRIM_FRAMES.get(seg, 0)))
	if seg == &"ai":
		_boot_ai_arena()
		return

	var config := MatchConfig.new()
	config.mode = spec[&"mode"]
	config.map_id = spec[&"map"]
	config.player_team = spec[&"team"]
	config.player_class_id = spec[&"class"]
	config.primary_id = &"kestrel"
	config.sidearm_id = &"adder"
	config.bot_count_bastion = spec[&"bots"]
	config.bot_count_sirocco = spec[&"bots"]
	config.difficulty_id = &"veteran"
	config.seed = spec[&"seed"]
	Game.match_config = config
	Game.match_seed = spec[&"seed"]

	run = MatchScene.instantiate() as Match
	add_child(run)
	while not run.running:
		await get_tree().process_frame
	await _stage()
	_staged = true


func _spec() -> Dictionary:
	var out := {&"seg": &"deploy", &"map": &"compound",
		&"mode": Enums.Mode.ELIMINATION, &"team": Enums.Team.BASTION,
		&"bots": 5, &"seed": 101, &"class": &"vanguard"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seg="):
			out[&"seg"] = StringName(arg.trim_prefix("--seg="))
		elif arg.begins_with("--still="):
			out[&"seg"] = StringName(arg.trim_prefix("--still="))
	match out[&"seg"]:
		&"deploy":
			out[&"map"] = &"compound"
		&"combat", &"combat_slow":
			out[&"map"] = &"dustworks"
			out[&"seed"] = 202
		&"wounds":
			out[&"map"] = &"dustworks"
			out[&"seed"] = 303
			out[&"bots"] = 1
			out[&"class"] = &"bulwark"
		&"smoke":
			out[&"map"] = &"compound"
			out[&"seed"] = 404
			out[&"class"] = &"bulwark"
		&"battle":
			out[&"map"] = &"terminal"
			out[&"seed"] = 505
			out[&"bots"] = 6
			out[&"mode"] = Enums.Mode.BATTLE
			out[&"team"] = Enums.Team.SIROCCO
		&"debrief":
			out[&"map"] = &"dustworks"
			out[&"seed"] = 606
			out[&"bots"] = 3
			out[&"class"] = &"bulwark"
	return out


## The AI segment is the existing 4v4 overlay arena; its own camera already fits
## the whole map, which is what makes every cone and nav path readable at once.
func _boot_ai_arena() -> void:
	_arena = AiArenaScene.instantiate()
	add_child(_arena)


func _stage() -> void:
	# Effect jitter (brass, chips, blood) is the only unseeded randomness left in
	# a take: seed it from the match seed so two recordings of a segment match.
	var effects := run.effects as Node
	if effects != null:
		var rng: Variant = effects.get(&"_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = Game.match_seed
	EventBus.character_died.connect(_on_death)
	for character: Character in run.characters:
		if character == run.player:
			continue
		if character.team == run.player.team:
			_allies.append(character)
		else:
			_enemies.append(character)
	match seg:
		&"combat", &"combat_slow":
			_stage_duel()
		&"wounds":
			_stage_wounds()
		&"smoke":
			_stage_smoke()
		&"battle":
			_stage_battle()
		&"debrief":
			await _run_debrief()
		_:
			_drive_player()


# --- staging ---------------------------------------------------------------

## Player body runs the real utility AI: no manual input at all (deploy).
func _drive_player() -> void:
	if run.player != null:
		run.player.controller.set_script(load("res://src/entities/ai_controller.gd"))
		run.player.controller.call(&"setup", run.player)


## Real CameraRig, but parked: `player`/`target` null means update() leaves the
## position alone while recoil kick and blast shake keep working. The default
## rig lerps toward the OS cursor, which a headless capture cannot place.
func _park_camera(at: Vector2, zoom: float) -> void:
	var rig: CameraRig = run.camera_rig
	if rig == null:
		return
	rig.player = null
	rig.target = null
	rig.spectate_target = null
	rig.global_position = at
	rig.zoom = Vector2(zoom, zoom)


func _stage_duel() -> void:
	var player := run.player
	if player == null:
		return
	_park(_allies, Vector2(300.0, 1800.0))
	_park(_enemies.slice(2), Vector2(420.0, 1760.0))
	_place(player, DUST_PLAYER)
	_drive_player()
	if _enemies.size() >= 2:
		_place(_enemies[0], DUST_ENEMY)
		_manual(_enemies[0], AIM_WEST)
		_place(_enemies[1], DUST_ENEMY_FAR)
		_manual(_enemies[1], AIM_WEST)
		# combat kills the near lane enemy; combat_slow kills the far one so the
		# tracer flight is visible. Each is the other's return-fire source.
		_shooter = _enemies[0] if seg == &"combat" else _enemies[1]
	_park_camera(DUST_CAMERA, 2.0)
	await _settle(BOOT_TICKS)


## Player advancing on cover when a round takes the leg from behind; then the
## limp to that cover and a 2.8 s bandage channel.
func _stage_wounds() -> void:
	var player := run.player
	if player == null:
		return
	_park(_allies, Vector2(2400.0, 1800.0))
	_park(_enemies.slice(1), Vector2(2500.0, 1760.0))
	_place(player, DUST_PLAYER)
	_drive_player()
	# The player faces east into the lane, so the fog cone carries the framing
	# and the lane reads. The shooter stands BEHIND that facing: BodyModel puts
	# the legs in the body's rear half, so a round from the front can only ever
	# resolve as torso.
	player.aim_dir = AIM_EAST
	var foe := _enemies[0] if not _enemies.is_empty() else null
	if foe != null:
		_shooter = foe
		_place(foe, DUST_PLAYER + Vector2(-430.0, 0.0))
		_manual(foe, AIM_EAST)
	_park_camera(DUST_PLAYER + Vector2(60.0, 0.0), 2.4)
	await _settle(BOOT_TICKS)


## Smoke into the lane, squad advances through it, then a frag into the same
## lane. Both are real grenades from the live EquipmentSystem.
func _stage_smoke() -> void:
	var player := run.player
	if player == null:
		return
	_place(player, COMP_PLAYER)
	_drive_player()
	# One enemy stands on the frag's landing point (it is a real blast on a real
	# BodyModel, so the kill has to be earned by where the grenade goes), the
	# others hold the shoulders of that line.
	for i: int in _enemies.size():
		var lane_offset := COMP_ENEMY_GAP * float(i - 1)
		_place(_enemies[i],
			COMP_PLAYER + Vector2(COMP_ENEMY_RANGE, lane_offset))
		_manual(_enemies[i], AIM_WEST)
	for i: int in _allies.size():
		_place(_allies[i], COMP_PLAYER + Vector2(-76.0, 52.0 * float(i) - 100.0))
		_manual(_allies[i], AIM_EAST)
	_park_camera(COMP_CAMERA, COMP_ZOOM)
	await _settle(BOOT_TICKS)


## Battle: the player attacks A with the real BattleRules chain running.
func _stage_battle() -> void:
	_drive_player()
	_park_camera(BATTLE_CAMERA, 1.1)
	await _settle(BATTLE_WARMUP)


## A short real match, the production force_finish, then the real debrief
## hand-off. Detached to the tree root (like tools/shot_flow.gd) so Game's
## change_scene cannot free this fixture mid-flow.
func _run_debrief() -> void:
	var tree := get_tree()
	tree.root.remove_child.call_deferred(self)
	await tree.process_frame
	tree.root.add_child(self)
	tree.current_scene = null
	_drive_player()
	await _settle(120)
	run.force_finish(Enums.Team.BASTION, &"elimination")
	var arrived := false
	for _i: int in 600:
		if tree.current_scene != null \
				and tree.current_scene.scene_file_path == Game.DEBRIEF_SCENE:
			# Production frees the Match with the scene swap; this fixture kept it
			# alive for staging, and its HUD/fog CanvasLayers ignore a parent's
			# visibility, so the whole runtime is freed once the debrief is live.
			if run != null:
				run.queue_free()
				run = null
			arrived = true
			break
		await tree.process_frame
	if not arrived:
		return
	# Trim to the frame the scene became current: Game's own fade-out is part of
	# the transition, and the debrief's entrance animation (UiFx.fade_in) has to
	# stay inside the kept range.
	var at_arrival := Engine.get_process_frames() - _boot_frame
	await _settle(40)
	# Everything before this frame is the match beat plus Game's cross-fade; the
	# cut must start on the debrief itself. capture.sh keeps the LAST
	# PROMO_TRIM line, so this overrides the static table entry.
	print("PROMO_TRIM %d" % at_arrival)


func _place(character: Character, at: Vector2) -> void:
	if character == null:
		return
	character.global_position = at
	character.velocity = Vector2.ZERO
	character.motor.model.velocity = Vector2.ZERO
	character.rig.position = Vector2.ZERO


func _park(members: Array[Character], base: Vector2) -> void:
	for i: int in members.size():
		_place(members[i], base + Vector2(0.0, 44.0 * float(i)))
		_manual(members[i], AIM_EAST)


## Manual driver: a real Character with its real weapon, scripted aim only.
## These are the documented AIController scripting setters (no gameplay change).
## The draw timer is cleared so a staged burst starts on the beat instead of
## waiting out the weapon's equip animation (same trick as shot_combat.gd).
func _manual(character: Character, aim: Vector2) -> void:
	if character == null:
		return
	character.controller.set_script(load("res://src/entities/ai_controller.gd"))
	character.controller.call(&"setup", character)
	character.controller.call(&"set_move_target", Vector2.ZERO)
	character.controller.call(&"set_aim_target", aim)
	var weapon: WeaponModel = character.arsenal.current()
	if weapon != null:
		weapon.equip_timer = 0.0


func _settle(ticks: int) -> void:
	for _i: int in ticks:
		await get_tree().physics_frame


# --- tick ------------------------------------------------------------------

func _physics_process(_dt: float) -> void:
	if run == null or not run.running or not _staged:
		return
	_ticks += 1
	match seg:
		&"combat":
			_combat_tick()
		&"combat_slow":
			_combat_slow_tick()
		&"wounds":
			_wounds_tick()
		&"smoke":
			_smoke_tick()


## 0-2 s sprint, 2-4 s crouch+brace, 4-7 s bursts, 7-9 s reload, 9-12 s re-engage.
func _combat_tick() -> void:
	var player := run.player
	if player == null:
		return
	var ai: Node = player.controller
	if _ticks <= C_SPRINT_END:
		# Sprint to the crate, then hold: the pose is "arrived at cover", not
		# "still running off the right of the frame".
		var to_cover := DUST_PLAYER - player.global_position
		ai.call(&"set_sprint", to_cover.length() > 8.0)
		ai.call(&"set_move_target", to_cover.normalized() if to_cover.length() > 8.0
			else Vector2.ZERO)
	elif _ticks <= C_BRACE_END:
		ai.call(&"set_sprint", false)
		ai.call(&"set_move_target", Vector2.ZERO)
		ai.call(&"set_stance", Enums.Stance.CROUCH)
		ai.call(&"set_focus", true)
	elif _ticks <= C_FIRE_END:
		var phase := (_ticks - C_BRACE_END) % (BURST_ON + BURST_OFF)
		ai.call(&"set_fire", phase < BURST_ON)
	elif _ticks == C_FIRE_END + 1:
		ai.call(&"set_fire", false)
		ai.call(&"set_focus", false)
		ai.set(&"want_reload", true)
	elif _ticks == C_FIRE_END + 4:
		ai.set(&"want_reload", false)
	elif _ticks == C_RELOAD_END + 1:
		ai.call(&"set_stance", Enums.Stance.STAND)
	elif _ticks > C_RELOAD_END:
		var phase := (_ticks - C_RELOAD_END) % (BURST_ON * 2 + BURST_OFF)
		ai.call(&"set_fire", phase < BURST_ON * 2)
	ai.call(&"set_aim_target", AIM_EAST)
	_enemy_return_fire()


## Tracers down the lane from the real enemy weapon. The enemy aims a body-width
## past the hero's flank, so the rounds are real misses rather than the take
## ending with a corpse.
func _enemy_return_fire() -> void:
	if _shooter == null or not _shooter.alive or run.player == null:
		return
	var body: BodyModel = run.player.body.model
	if _ticks < C_ENEMY_START or body.part_ratio(Enums.Part.TORSO) < C_ENEMY_STOP_RATIO:
		_shooter.controller.call(&"set_fire", false)
		return
	var past := run.player.global_position + Vector2(0.0, MISS_BY_PX)
	_shooter.controller.call(&"set_aim_target",
		(past - _shooter.global_position).normalized())
	var phase := (_ticks - C_ENEMY_START) % C_ENEMY_PERIOD
	_shooter.controller.call(&"set_fire", phase < C_ENEMY_BURST)


## Half-speed take: the player opens fire at once and the lane enemy drops at
## sim ≈1.2 s, so tracer, blood and the collapse all read in 120 slow frames.
func _combat_slow_tick() -> void:
	var player := run.player
	if player == null or _shooter == null:
		return
	var ai: Node = player.controller
	ai.call(&"set_aim_target", AIM_EAST)
	ai.call(&"set_sprint", false)
	ai.call(&"set_move_target", Vector2.ZERO)
	ai.call(&"set_stance", Enums.Stance.CROUCH)
	ai.call(&"set_focus", true)
	ai.call(&"set_fire", _ticks >= CS_FIRE_TICK and _shooter.alive)


func _wounds_tick() -> void:
	var player := run.player
	if player == null:
		return
	var ai: Node = player.controller
	if _shooter != null and _shooter.alive:
		var leg := player.global_position - player.aim_dir * WOUND_LEG_LEAD
		_shooter.controller.call(&"set_aim_target",
			(leg - _shooter.global_position).normalized())
		var wounded: BodyModel = player.body.model
		var firing := _ticks >= W_SHOT_TICK \
			and _ticks < W_SHOT_TICK + W_SHOT_ROUNDS * W_SHOT_GAP \
			and not wounded.is_bleeding_any()
		_shooter.controller.call(&"set_fire", firing)
	elif _shooter != null:
		_shooter.controller.call(&"set_fire", false)
	if _ticks <= W_LIMP_TICK:
		ai.call(&"set_move_target", Vector2.ZERO)
		ai.call(&"set_aim_target", AIM_EAST)
	elif _ticks <= W_LIMP_END:
		# The crippled leg halves speed (BodyModel.CRIPPLED_LEG_SPEED_MULT): the
		# limp is the wound made visible, not an animation.
		ai.call(&"set_move_target", AIM_WEST)
		ai.call(&"set_sprint", false)
		ai.call(&"set_aim_target", AIM_EAST)
	elif _ticks <= W_BANDAGE_TICK + W_BANDAGE_HOLD:
		ai.call(&"set_move_target", Vector2.ZERO)
		ai.call(&"set_stance", Enums.Stance.CROUCH)
		ai.call(&"set_aim_target", AIM_EAST)
		ai.set(&"want_bandage", _ticks >= W_BANDAGE_TICK)
	else:
		ai.set(&"want_bandage", false)


func _smoke_tick() -> void:
	var player := run.player
	if player == null:
		return
	var ai: Node = player.controller
	ai.call(&"set_aim_target", AIM_EAST)
	match true:
		_ when _ticks == S_SMOKE_TICK:
			_lob(player, &"smoke")
		_ when _ticks > S_ADVANCE_TICK and _ticks <= S_ADVANCE_END:
			# Stop short of the grenade line: the squad walks into the smoke's
			# near edge, not through the frag it just threw.
			if player.global_position.distance_to(COMP_PLAYER) < S_ADVANCE_PX:
				ai.call(&"set_move_target", AIM_EAST)
			else:
				ai.call(&"set_move_target", Vector2.ZERO)
			for ally in _allies:
				if ally.global_position.distance_to(COMP_PLAYER) < S_ADVANCE_PX:
					ally.controller.call(&"set_move_target", AIM_EAST)
				else:
					ally.controller.call(&"set_move_target", Vector2.ZERO)
		_ when _ticks > S_ADVANCE_END:
			ai.call(&"set_move_target", Vector2.ZERO)
			for ally in _allies:
				ally.controller.call(&"set_move_target", Vector2.ZERO)
	if _ticks == S_FRAG_TICK:
		_lob(player, &"frag")


## Throw a real grenade through the production path: Arsenal decrements the kit,
## emits equipment_thrown from the thrower's hand (+10 px along the aim) and the
## live EquipmentSystem spawns the grenade body from that bus event. Only the
## aim is scripted, so what flies, fuses, detonates and smokes is all real.
func _lob(who: Character, kind: StringName) -> void:
	var slot := who.arsenal.kit_ids.find(kind)
	if slot < 0:
		return
	who.arsenal.throw_equipment(slot)


func _on_death(victim: Node, _attacker: Node, _weapon: StringName,
		_position: Vector2, _distance: float) -> void:
	if victim == _shooter:
		_shooter = null