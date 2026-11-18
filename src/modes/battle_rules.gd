class_name BattleRules
extends MatchRules
## Attack/defend objective chain with attacker tickets (design §10 "Battle").
## Pure: the runner feeds occupancy + death counts, the rules answer state and
## RuleEvents. No nodes, no EventBus (architecture §4).
##
## Attackers (SIROCCO by default) take A→B→C in order: the lowest unlocked
## objective is the only one that can be captured. Hold-to-capture: attackers
## alone in the zone fill the bar in `capture_time` seconds; a contested zone
## pauses; defenders alone empty a *partially* filled bar at 2× speed, but a
## locked objective never reopens. Each capture grants tickets and unlocks the
## next objective.
##
## Win: last objective locked → attackers (&"objectives"). Tickets 0 and every
## attacker dead → defenders (&"tickets"). Time limit (plus a contest grace) →
## defenders (&"timeout").

const ATTACKER_DEFAULT := Enums.Team.SIROCCO
const REASON_OBJECTIVES := &"objectives"
const REASON_TICKETS := &"tickets"
const REASON_TIMEOUT := &"timeout"

## Tickets granted per captured objective (design §10).
const CAPTURE_TICKETS := 8
## Each attacker death costs one ticket (design §10).
const TICKETS_PER_ATTACKER_DEATH := 1
## Reinforcement cadence: attackers 6 s, defenders 8 s (design §10).
const ATTACKER_WAVE_S := 6.0
const DEFENDER_WAVE_S := 8.0
## Defenders recapture a partial bar at twice the capture speed (design §10).
const RECAPTURE_MULT := 2.0
## Progress change that is worth an event: 1/200th of a bar.
const PROGRESS_EMIT_EPSILON := 0.005

var attack_team: int = ATTACKER_DEFAULT
var tickets: int = 0

## {id, order, capture_time, pos} in chain order (set by setup()).
var _objectives: Array[Dictionary] = []
var _progress: Dictionary[StringName, float] = {}
var _locked: Dictionary[StringName, bool] = {}
var _owner: Dictionary[StringName, int] = {}
var _attacker_wave := 0.0
var _defender_wave := 0.0
var _last_emitted_progress: Dictionary[StringName, float] = {}
var _last_tickets := -1
var _phase_key := ""
## id -> consecutive ticks the attackers have held the active zone uncontested.
var _hold_ticks: Dictionary[StringName, int] = {}
## Set the first tick the horn sounds; bounds the contest grace window.
var _overtime := false


func setup(objective_defs: Array[Dictionary], attacker_tickets: int,
		p_attack_team: int = ATTACKER_DEFAULT) -> void:
	attack_team = p_attack_team
	tickets = maxi(attacker_tickets, 0)
	_objectives.clear()
	for def: Dictionary in objective_defs:
		_objectives.append(def.duplicate())
	_objectives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get(&"order", 0)) < int(b.get(&"order", 0)))
	_progress.clear()
	_locked.clear()
	_owner.clear()
	_last_emitted_progress.clear()
	for def: Dictionary in _objectives:
		var id: StringName = def[&"id"]
		_progress[id] = 0.0
		_locked[id] = false
		_owner[id] = -1
	_attacker_wave = 0.0
	_defender_wave = 0.0
	_last_tickets = tickets
	_phase_key = ""
	_overtime = false
	_hold_ticks.clear()


func defender_team() -> int:
	return Enums.other_team(attack_team)


func attacker_team() -> int:
	return attack_team


func tickets_left() -> int:
	return tickets


## HUD value for the defenders' bar: they never run out (design §10), so the
## bar stays full; only the attackers' bar is a resource.
func defender_tickets_display() -> int:
	return maxi(tickets, CAPTURE_TICKETS * maxi(_objectives.size(), 1))


func tick(snapshot: MatchSnapshot, dt: float) -> Array[RuleEvent]:
	var out: Array[RuleEvent] = []
	if _objectives.is_empty():
		return out
	_tick_attacker_deaths(snapshot, out)
	_tick_capture(snapshot, dt, out)
	_tick_waves(snapshot, dt, out)
	_tick_phase(snapshot, out)
	out.append_array(_check_end(snapshot))
	return out


# --- capture ----------------------------------------------------------------

func _tick_attacker_deaths(snapshot: MatchSnapshot, out: Array[RuleEvent]) -> void:
	var deaths := snapshot.deaths_this_tick[attack_team] \
		if attack_team < snapshot.deaths_this_tick.size() else 0
	if deaths <= 0:
		return
	var before := tickets
	tickets = maxi(tickets - deaths * TICKETS_PER_ATTACKER_DEATH, 0)
	if tickets != before:
		_last_tickets = tickets
		out.append(RuleEvent.make(RuleEvent.TICKETS, {
			&"team": attack_team, &"tickets": tickets}))


func _tick_capture(snapshot: MatchSnapshot, dt: float, out: Array[RuleEvent]) -> void:
	var active := active_objective()
	if active.is_empty():
		return
	var id: StringName = active[&"id"]
	if bool(_locked[id]):
		return
	var state := snapshot.objective(id)
	var present: Array = state.get(&"present", [0, 0])
	var attackers := int(present[attack_team]) if attack_team < present.size() else 0
	var defenders := int(present[defender_team()]) if defender_team() < present.size() else 0
	var capture_time := maxf(float(active.get(&"capture_time", 1.0)), 0.01)
	var contested := attackers > 0 and defenders > 0
	if attackers > 0 and not contested:
		_progress[id] = minf(float(_progress[id]) + dt / capture_time, 1.0)
	elif defenders > 0 and not contested and float(_progress[id]) > 0.0:
		_progress[id] = maxf(
			float(_progress[id]) - dt * RECAPTURE_MULT / capture_time, 0.0)
	else:
		# Contested or empty: the bar holds where it is (hold-to-capture).
		pass
	# A lock this tick publishes 1.0 itself, and the lock must not depend on
	# float accumulation: `elapsed / capture_time` is exact at the boundary, so
	# a full bar locks on capture_time * 60 ticks instead of 60 + 1.
	var held := float(_progress[id])
	var reached := held >= 1.0 or _held_long_enough(id, dt, capture_time, attackers, contested)
	_emit_progress(id, out, contested)
	if reached:
		_progress[id] = 1.0
		_capture(id, active, out)


func _emit_progress(id: StringName, out: Array[RuleEvent], contested: bool) -> void:
	var progress := float(_progress[id])
	var last := float(_last_emitted_progress.get(id, -1.0))
	if absf(progress - last) < PROGRESS_EMIT_EPSILON and progress < 1.0:
		return
	_last_emitted_progress[id] = progress
	out.append(RuleEvent.make(RuleEvent.OBJECTIVE_PROGRESS, {
		&"id": id, &"team": attack_team, &"progress": progress,
		&"contested": contested,
	}))


func _capture(id: StringName, active: Dictionary, out: Array[RuleEvent]) -> void:
	_locked[id] = true
	_owner[id] = attack_team
	_progress[id] = 1.0
	tickets += CAPTURE_TICKETS
	_last_tickets = tickets
	_last_emitted_progress[id] = 1.0
	out.append(RuleEvent.make(RuleEvent.OBJECTIVE_PROGRESS, {
		&"id": id, &"team": attack_team, &"progress": 1.0, &"contested": false,
	}))
	out.append(RuleEvent.make(RuleEvent.OBJECTIVE_CAPTURED, {
		&"id": id, &"team": attack_team, &"order": int(active.get(&"order", 0)),
	}))
	out.append(RuleEvent.make(RuleEvent.TICKETS, {
		&"team": attack_team, &"tickets": tickets}))


## Capture accumulated over `capture_time` regardless of float rounding: the
## bar is kept as a fraction, and this counts the ticks actually held so a full
## hold can never be one tick short of a lock.
func _held_long_enough(id: StringName, dt: float, capture_time: float,
		attackers: int, contested: bool) -> bool:
	if attackers <= 0 or contested:
		_hold_ticks[id] = 0
		return false
	_hold_ticks[id] = int(_hold_ticks.get(id, 0)) + 1
	return float(_hold_ticks[id]) * dt >= capture_time - 1e-6


## Lowest-order objective that is not locked; {} when the chain is complete.
func active_objective() -> Dictionary:
	for def: Dictionary in _objectives:
		if not bool(_locked.get(def[&"id"], false)):
			return def
	return {}


## Order of the last captured objective (0 = none yet) — forward-spawn anchor.
func last_captured_order() -> int:
	var order := 0
	for def: Dictionary in _objectives:
		if bool(_locked.get(def[&"id"], false)):
			order = maxi(order, int(def.get(&"order", 0)))
	return order


func is_final_objective(id: StringName) -> bool:
	return not _objectives.is_empty() and _objectives[-1][&"id"] == id


# --- waves / phase ----------------------------------------------------------

func _tick_waves(_snapshot: MatchSnapshot, dt: float, out: Array[RuleEvent]) -> void:
	_attacker_wave += dt
	if _attacker_wave >= ATTACKER_WAVE_S:
		_attacker_wave = fmod(_attacker_wave, ATTACKER_WAVE_S)
		# Reinforcement wave only while the attack has manpower left.
		if tickets > 0:
			out.append(RuleEvent.make(RuleEvent.SPAWN, {
				&"team": attack_team, &"count": -1,
				&"forward_order": last_captured_order(),
			}))
	_defender_wave += dt
	if _defender_wave >= DEFENDER_WAVE_S:
		_defender_wave = fmod(_defender_wave, DEFENDER_WAVE_S)
		out.append(RuleEvent.make(RuleEvent.SPAWN, {
			&"team": defender_team(), &"count": -1, &"forward_order": 0,
		}))


func _tick_phase(snapshot: MatchSnapshot, out: Array[RuleEvent]) -> void:
	var active := active_objective()
	var id: StringName = active.get(&"id", &"") if not active.is_empty() else &""
	var contested := false
	if not active.is_empty():
		var state := snapshot.objective(id)
		var present: Array = state.get(&"present", [0, 0])
		contested = int(present[0]) > 0 and int(present[1]) > 0
	var key := "%s|%s" % [String(id), str(contested)]
	if key == _phase_key:
		return
	_phase_key = key
	out.append(RuleEvent.make(RuleEvent.PHASE, {
		&"obj_id": id,
		&"obj_pos": active.get(&"pos", Vector2.ZERO),
		&"obj_order": int(active.get(&"order", 0)),
		&"contested": contested,
		&"attacker_phase": &"push" if not active.is_empty() else &"hold",
		&"defender_phase": &"hold",
	}))


# --- end conditions ---------------------------------------------------------

func _check_end(snapshot: MatchSnapshot) -> Array[RuleEvent]:
	if _objectives.is_empty():
		return []
	if bool(_locked[_objectives[-1][&"id"]]):
		return [end_event(attack_team, REASON_OBJECTIVES)]
	if tickets <= 0 and snapshot.alive(attack_team) == 0:
		return [end_event(defender_team(), REASON_TICKETS)]
	if snapshot.elapsed >= time_limit_s:
		# Grace: a live contest at the horn plays out (design §10 / sim README).
		# The extension is granted once; after GRACE_S the horn is final even if
		# the zone is still contested.
		if not _overtime:
			_overtime = true
			if _any_contested(snapshot):
				return []
		elif snapshot.elapsed < time_limit_s + GRACE_S and _any_contested(snapshot):
			return []
		return [end_event(defender_team(), REASON_TIMEOUT)]
	return []


func _any_contested(snapshot: MatchSnapshot) -> bool:
	for def: Dictionary in _objectives:
		var state := snapshot.objective(def[&"id"])
		var present: Array = state.get(&"present", [0, 0])
		if int(present[0]) > 0 and int(present[1]) > 0:
			return true
	return false


# --- HUD --------------------------------------------------------------------

func objective_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var active := active_objective()
	var active_id: StringName = active.get(&"id", &"") if not active.is_empty() else &""
	for def: Dictionary in _objectives:
		var id: StringName = def[&"id"]
		var state := "locked"
		var team := -1
		if bool(_locked.get(id, false)):
			state = "owned"
			team = int(_owner.get(id, attack_team))
		elif id == active_id:
			state = "active"
			team = attack_team
		rows.append({
			"id": id, "letter": String(id).to_upper(), "state": state,
			"team": team, "progress": float(_progress.get(id, 0.0)),
			"contested": _last_contested(id), "pos": def.get(&"pos", Vector2.ZERO),
		})
	return rows


## Contested flags are only known from the last snapshot; the runner refreshes
## them through `objective_rows(contested_by_id)` when it has live zones.
var _contested: Dictionary[StringName, bool] = {}

func mark_contested(id: StringName, contested: bool) -> void:
	_contested[id] = contested

func _last_contested(id: StringName) -> bool:
	return bool(_contested.get(id, false))