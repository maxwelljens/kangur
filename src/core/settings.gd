extends Node
## Settings — autoload. ConfigFile at `user://settings.cfg`.
## Contract: docs/architecture.md §3.3, §8. Applies on change and announces
## the section on EventBus so HUD/camera/AudioDirector can react.

const CONFIG_PATH := "user://settings.cfg"

## Design defaults (design §3, §4, §11-§12). Keys are StringName for cheap
## lookup in gameplay code; ConfigFile accepts them as-is.
const DEFAULTS: Dictionary[StringName, Dictionary] = {
	&"video": {
		&"fullscreen": false,
		&"vsync": true,
		&"zoom": 1.6,
		&"screen_shake": true,
		&"hud_scale": 1.0,
	},
	&"audio": {
		&"master": 0.8,
		&"sfx": 0.8,
		&"music": 0.6,
		&"voice": 0.8,
		&"occlusion": true,
	},
	&"gameplay": {
		&"difficulty": &"operator",
		&"crosshair_style": 0,
		&"crosshair_color": Color(0.2, 1.0, 0.8, 0.9),
		&"camera_lean": 0.35,
		&"gore": true,
		&"crouch_toggle": true,
		&"focus_toggle": false,
		&"sprint_toggle": false,
		&"show_radio": true,
	},
	&"controls": {},
}

## section -> key -> value, defaults already merged in.
var _values: Dictionary[StringName, Dictionary] = {}

func _ready() -> void:
	_load()
	apply_all()  # installs InputMap defaults, then applies persisted rebinds

func get_value(section: StringName, key: StringName, default: Variant = null) -> Variant:
	var sec: Dictionary = _values.get(section, {})
	return sec.get(key, default)

func set_value(section: StringName, key: StringName, value: Variant) -> void:
	_ensure_section(section)
	(_values[section] as Dictionary)[key] = value
	_save()
	apply_section(section)

func apply_all() -> void:
	apply_section(&"video")
	apply_section(&"audio")
	apply_section(&"controls")

func apply_section(section: StringName) -> void:
	match section:
		&"video":
			_apply_video()
		&"audio":
			_apply_audio()
		&"controls":
			_apply_controls()
	if is_inside_tree():
		EventBus.settings_changed.emit(section)

## Bind `action` to a single descriptor (one key or one mouse button).
func rebind(action: StringName, binding: Dictionary) -> void:
	if binding.is_empty():
		push_error("Settings.rebind: empty binding for '%s'" % action)
		return
	InputDefaults.apply_binding(action, binding)
	var rebinds := _rebinds()
	rebinds[action] = [binding]
	_ensure_section(&"controls")
	(_values[&"controls"] as Dictionary)[&"rebinds"] = rebinds
	_save()
	EventBus.settings_changed.emit(&"controls")

func reset_controls() -> void:
	InputDefaults.install()
	(_values[&"controls"] as Dictionary).clear()
	_save()
	EventBus.settings_changed.emit(&"controls")

## action -> Array of binding descriptors currently persisted.
func rebinds() -> Dictionary[StringName, Array]:
	var copy: Dictionary[StringName, Array] = {}
	copy.assign(_rebinds().duplicate(true))
	return copy

func _rebinds() -> Dictionary[StringName, Array]:
	var sec: Dictionary = _values.get(&"controls", {})
	var stored: Variant = sec.get(&"rebinds", {})
	var out: Dictionary[StringName, Array] = {}
	if stored is Dictionary:
		for action: Variant in (stored as Dictionary):
			var list: Variant = (stored as Dictionary)[action]
			if list is Array:
				out[StringName(str(action))] = list
	return out

func _ensure_section(section: StringName) -> void:
	if not _values.has(section):
		_values[section] = DEFAULTS.get(section, {}).duplicate(true)

func _load() -> void:
	_values.clear()
	for section: StringName in DEFAULTS:
		_values[section] = (DEFAULTS[section] as Dictionary).duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for section: String in cfg.get_sections():
		var section_id := StringName(section)
		_ensure_section(section_id)
		for key: String in cfg.get_section_keys(section):
			(_values[section_id] as Dictionary)[StringName(key)] = cfg.get_value(section, key)

func _save() -> void:
	var cfg := ConfigFile.new()
	for section: StringName in _values:
		for key: StringName in _values[section]:
			cfg.set_value(String(section), String(key), _values[section][key])
	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_error("Settings: cannot write %s (error %d)" % [CONFIG_PATH, err])

func _apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen: bool = bool(get_value(&"video", &"fullscreen"))
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	var vsync: bool = bool(get_value(&"video", &"vsync"))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

## Buses arrive with AudioDirector; tolerate their absence (headless, early boot).
func _apply_audio() -> void:
	_set_bus_volume(&"Master", float(get_value(&"audio", &"master", 1.0)))
	_set_bus_volume(&"SFX", float(get_value(&"audio", &"sfx", 1.0)))
	_set_bus_volume(&"Music", float(get_value(&"audio", &"music", 1.0)))
	_set_bus_volume(&"Voice", float(get_value(&"audio", &"voice", 1.0)))

func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))

func _apply_controls() -> void:
	InputDefaults.install()
	var stored := _rebinds()
	for action: StringName in stored:
		var bindings: Array = stored[action]
		if not bindings.is_empty() and bindings[0] is Dictionary:
			InputDefaults.apply_binding(action, bindings[0])