class_name DangerMap
extends RefCounted
## Team-shared memory of where teammates died. Pure grid: 64 px cells, heat
## decays over ~20 s. Two teammate deaths inside 6 s within 150 px is a
## KILLZONE: a spike nobody forgets quickly, plus a radio warning (design §9.5).

const CELL_PX := 64.0
## Heat added per teammate death at the death cell.
const DEATH_HEAT := 1.0
## Neighbour spill, so a killzone has width instead of one hot pixel.
const SPILL_HEAT := 0.4
const SPILL_RADIUS := 1
## Exponential decay half-life, seconds.
const HALF_LIFE_S := 20.0
## Killzone detection window / distance / count (design §9.5).
const KILLZONE_WINDOW_S := 6.0
const KILLZONE_RADIUS := 150.0
const KILLZONE_DEATHS := 2
## Once triggered, a zone stays hot this long and cannot re-trigger (anti-spam).
const KILLZONE_COOLDOWN_S := 20.0
const KILLZONE_HEAT := 1.0

var clock: float = 0.0

## cell: Vector2i -> heat
var _heat: Dictionary[Vector2i, float] = {}
## [{pos, time}] recent deaths, trimmed to the trigger window.
var _deaths: Array[Dictionary] = []
## [{pos, time}] active killzones for the overlay + radio dedupe.
var _killzones: Array[Dictionary] = []

## Record a teammate death. Returns the killzone position when this death
## completed one, `null` otherwise (caller radios the warning).
func add_death(pos: Vector2) -> Variant:
	_add_heat(pos, DEATH_HEAT)
	_deaths.append({&"pos": pos, &"time": clock})
	_trim_deaths()
	var zone := _zone_triggered(pos)
	if not zone.is_empty():
		_add_heat(zone[&"pos"], KILLZONE_HEAT)
		_killzones.append({&"pos": zone[&"pos"], &"time": clock})
		return zone[&"pos"]
	return null

func tick(dt: float) -> void:
	clock += dt
	var decay := pow(0.5, dt / HALF_LIFE_S)
	for cell: Vector2i in _heat.keys():
		var value := _heat[cell] * decay
		if value < 0.01:
			_heat.erase(cell)
		else:
			_heat[cell] = value
	_trim_deaths()
	for i: int in range(_killzones.size() - 1, -1, -1):
		if clock - float(_killzones[i][&"time"]) > KILLZONE_COOLDOWN_S:
			_killzones.remove_at(i)

## 0..~2+ heat at a world position (bilinear-free: the owning cell).
func danger_at(pos: Vector2) -> float:
	return _heat.get(cell_of(pos), 0.0)

func killzones() -> Array[Dictionary]:
	return _killzones

## Read-only heat snapshot for the F3 overlay (cells → heat).
func cells() -> Dictionary:
	return _heat.duplicate()

## 0..1 confidence that `pos` sits in a fresh killzone.
func killzone_at(pos: Vector2) -> float:
	var best := 0.0
	for zone: Dictionary in _killzones:
		var dist := pos.distance_to(zone[&"pos"])
		if dist > KILLZONE_RADIUS:
			continue
		var age := clock - float(zone[&"time"])
		best = maxf(best, 1.0 - age / KILLZONE_COOLDOWN_S)
	return best

static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_PX), floori(pos.y / CELL_PX))

func _add_heat(pos: Vector2, amount: float) -> void:
	var centre := cell_of(pos)
	for dy: int in range(-SPILL_RADIUS, SPILL_RADIUS + 1):
		for dx: int in range(-SPILL_RADIUS, SPILL_RADIUS + 1):
			var falloff := 1.0 if (dx == 0 and dy == 0) else SPILL_HEAT
			var cell := centre + Vector2i(dx, dy)
			_heat[cell] = _heat.get(cell, 0.0) + amount * falloff

func _trim_deaths() -> void:
	while not _deaths.is_empty() \
			and clock - float(_deaths[0][&"time"]) > KILLZONE_WINDOW_S:
		_deaths.pop_front()

## Fires when this death is at least the KILLZONE_DEATHS-th recent death in
## range, and no killzone is already cooling down there.
func _zone_triggered(pos: Vector2) -> Dictionary:
	var near: Array[Dictionary] = []
	for death: Dictionary in _deaths:
		if pos.distance_to(death[&"pos"]) <= KILLZONE_RADIUS:
			near.append(death)
	if near.size() < KILLZONE_DEATHS:
		return {}
	var zone_pos: Vector2 = near[-1][&"pos"]
	for existing: Dictionary in _killzones:
		if zone_pos.distance_to(existing[&"pos"]) <= KILLZONE_RADIUS:
			return {}
	return {&"pos": zone_pos}