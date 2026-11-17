extends Node
## Defs — autoload. Scans `res://data/**/*.tres` at boot and indexes every
## typed Def resource by its `id`. Contract: docs/architecture.md §3.2, §6.
## Missing or empty data directories are a valid boot state (zero content).

const DATA_ROOT := "res://data"

var _weapons: Dictionary[StringName, WeaponDef] = {}
var _classes: Dictionary[StringName, ClassDef] = {}
var _equipment: Dictionary[StringName, EquipmentDef] = {}
var _factions: Dictionary[StringName, FactionDef] = {}
var _maps: Dictionary[StringName, MapDef] = {}
var _difficulties: Dictionary[StringName, DifficultyDef] = {}
var _sound_sets: Dictionary[StringName, SoundSetDef] = {}

func _ready() -> void:
	refresh()

## Re-scan everything; used by the editor hot-reload tooling and content tests.
func refresh() -> void:
	_weapons.clear()
	_classes.clear()
	_equipment.clear()
	_factions.clear()
	_maps.clear()
	_difficulties.clear()
	_sound_sets.clear()
	_scan(DATA_ROOT)

func weapon(id: StringName) -> WeaponDef:
	var def: WeaponDef = _weapons.get(id)
	if def == null:
		push_error("Defs: unknown weapon id '%s'" % id)
	return def

func cls(id: StringName) -> ClassDef:
	var def: ClassDef = _classes.get(id)
	if def == null:
		push_error("Defs: unknown class id '%s'" % id)
	return def

func equipment(id: StringName) -> EquipmentDef:
	var def: EquipmentDef = _equipment.get(id)
	if def == null:
		push_error("Defs: unknown equipment id '%s'" % id)
	return def

func faction(id: StringName) -> FactionDef:
	var def: FactionDef = _factions.get(id)
	if def == null:
		push_error("Defs: unknown faction id '%s'" % id)
	return def

func map(id: StringName) -> MapDef:
	var def: MapDef = _maps.get(id)
	if def == null:
		push_error("Defs: unknown map id '%s'" % id)
	return def

func difficulty(id: StringName) -> DifficultyDef:
	var def: DifficultyDef = _difficulties.get(id)
	if def == null:
		push_error("Defs: unknown difficulty id '%s'" % id)
	return def

func sound_set(id: StringName) -> SoundSetDef:
	var def: SoundSetDef = _sound_sets.get(id)
	if def == null:
		push_error("Defs: unknown sound set id '%s'" % id)
	return def

func all_weapons() -> Array[WeaponDef]:
	var list: Array[WeaponDef] = []
	list.assign(_weapons.values())
	list.sort_custom(func(a: WeaponDef, b: WeaponDef) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return list

func all_classes() -> Array[ClassDef]:
	var list: Array[ClassDef] = []
	list.assign(_classes.values())
	list.sort_custom(func(a: ClassDef, b: ClassDef) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return list

func all_equipment() -> Array[EquipmentDef]:
	var list: Array[EquipmentDef] = []
	list.assign(_equipment.values())
	list.sort_custom(func(a: EquipmentDef, b: EquipmentDef) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return list

func all_factions() -> Array[FactionDef]:
	var list: Array[FactionDef] = []
	list.assign(_factions.values())
	list.sort_custom(func(a: FactionDef, b: FactionDef) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return list

func all_maps() -> Array[MapDef]:
	var list: Array[MapDef] = []
	list.assign(_maps.values())
	list.sort_custom(func(a: MapDef, b: MapDef) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return list

func all_difficulties() -> Array[DifficultyDef]:
	var list: Array[DifficultyDef] = []
	list.assign(_difficulties.values())
	list.sort_custom(func(a: DifficultyDef, b: DifficultyDef) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return list

func maps_for_mode(mode: int) -> Array[MapDef]:
	var list: Array[MapDef] = []
	for def: MapDef in all_maps():
		if def.supported_modes.has(mode):
			list.append(def)
	return list

func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(dir_path.path_join(entry))
		elif entry.ends_with(".tres") or entry.ends_with(".tres.remap"):
			# Exported PCKs list text resources as `x.tres.remap`; load by the
			# original path and ResourceLoader resolves the remap itself.
			_index(ResourceLoader.load(dir_path.path_join(entry.trim_suffix(".remap"))))
		entry = dir.get_next()
	dir.list_dir_end()

func _index(res: Resource) -> void:
	if res == null:
		return
	if res is WeaponDef:
		_put(_weapons, res)
	elif res is ClassDef:
		_put(_classes, res)
	elif res is EquipmentDef:
		_put(_equipment, res)
	elif res is FactionDef:
		_put(_factions, res)
	elif res is MapDef:
		_put(_maps, res)
	elif res is DifficultyDef:
		_put(_difficulties, res)
	elif res is SoundSetDef:
		_put(_sound_sets, res)
	# Other resource types legitimately live under data/ (palettes, tilesets);
	# they are not content defs, so they are silently skipped.

func _put(bucket: Dictionary, def: Resource) -> void:
	var def_id: StringName = def.get(&"id")
	if def_id == &"":
		push_error("Defs: %s has an empty id" % def.resource_path)
		return
	if bucket.has(def_id):
		push_error("Defs: duplicate id '%s' in %s" % [def_id, def.resource_path])
		return
	bucket[def_id] = def