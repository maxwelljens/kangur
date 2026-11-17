extends Node2D
## HUD screenshot fixture: fake BodyModel + WeaponModel state, arena backdrop and
## a populated HUD so the full layout is inspectable in one frame.
##   tools/godot.sh --path . -- --shot=res://tools/shot_ui_hud.tscn:30:reports/screenshots/ui_hud.png

const HudScene := preload("res://src/ui/hud/hud.tscn")
const KangurTheme := preload("res://src/ui/theme.gd")

## Wounded but alive: torso hurt, left arm crippled + bleeding, right leg bleeding.
const TORSO_HITS := 2
const HEAD_HITS := 0
const ARM_HITS := 2
const LEG_HITS := 1

class FakeCharacter extends Node2D:
	var team: int = Enums.Team.BASTION
	var callsign: String = "Kestrel"
	var is_player: bool = true
	var body_model: BodyModel = null
	var weapon_model: WeaponModel = null
	var bandages: int = 2

	func get_body_model() -> BodyModel:
		return body_model

	func get_weapon_model() -> WeaponModel:
		return weapon_model

	func get_bandages() -> int:
		return bandages

	func get_equipment_counts() -> Array[Dictionary]:
		return [
			{"kind": Enums.EquipKind.FRAG, "count": 2},
			{"kind": Enums.EquipKind.FLASH, "count": 1},
		]

var _hud: CanvasLayer = null
var _fake: FakeCharacter = null
var _blip_phase := 0.0

func _ready() -> void:
	_build_arena()
	_fake = FakeCharacter.new()
	_fake.body_model = _wounded_body()
	_fake.weapon_model = _kestrel_state()
	add_child(_fake)

	var config := MatchConfig.new()
	config.mode = Enums.Mode.BATTLE
	config.map_id = &"terminal"
	config.player_team = Enums.Team.BASTION
	config.time_limit_s = 431.0
	config.attacker_tickets = 36
	Game.match_config = config

	_hud = HudScene.instantiate()
	add_child(_hud)
	_hud.bind_character(_fake)
	_seed_hud()

func _wounded_body() -> BodyModel:
	var body := BodyModel.new(true, true)
	# Vest/helmet damage so the armour pips read as partly spent.
	body.vest_durability = BodyModel.VEST_MAX_DURABILITY * 0.45
	body.helmet_durability = BodyModel.HELMET_MAX_DURABILITY * 0.7
	for _i: int in TORSO_HITS:
		body.apply_hit(Enums.Part.TORSO, 22.0, 1.0)
	for _i: int in ARM_HITS:
		body.apply_hit(Enums.Part.ARM_L, 12.0, 1.0)
	for _i: int in LEG_HITS:
		body.apply_hit(Enums.Part.LEG_R, 10.0, 1.0)
	for _i: int in HEAD_HITS:
		body.apply_hit(Enums.Part.HEAD, 8.0, 1.0)
	body.start_bandage()
	body.tick(BodyModel.BANDAGE_TIME * 0.55)
	return body

func _kestrel_state() -> WeaponModel:
	var def := WeaponDef.new()
	def.id = &"kestrel"
	def.display_name = "Kestrel"
	def.category = &"ar"
	def.fire_modes = [Enums.FireMode.AUTO, Enums.FireMode.BURST, Enums.FireMode.SEMI]
	def.mag_size = 30
	def.reserve_mags = 5
	var weapon := WeaponModel.new(def)
	weapon.mag = 8
	weapon.reserve_rounds = 92
	weapon.bloom = 2.4
	weapon.tick(0.016, {"vel": 40.0, "vmax": 215.0, "stance": Enums.Stance.STAND,
		"focus": false})
	return weapon

func _seed_hud() -> void:
	_hud.set_alive_counts(4, 3)
	_hud.set_tickets(21, 36)
	var objectives: Array[Dictionary] = [
		{"id": &"a", "letter": "A", "state": "owned", "team": Enums.Team.BASTION,
			"progress": 1.0, "contested": false, "pos": Vector2(0.24, 0.30)},
		{"id": &"b", "letter": "B", "state": "active", "team": Enums.Team.BASTION,
			"progress": 0.62, "contested": true, "pos": Vector2(0.52, 0.56)},
		{"id": &"c", "letter": "C", "state": "locked", "team": -1,
			"progress": 0.0, "contested": false, "pos": Vector2(0.78, 0.24)},
	]
	_hud.set_objectives(objectives)
	var blips: Array[Dictionary] = [
		{"pos": Vector2(0.46, 0.62), "kind": &"player", "color": KangurTheme.HOLO,
			"dir": Vector2(0.6, -0.8)},
		{"pos": Vector2(0.38, 0.44), "kind": &"ally", "color": KangurTheme.BASTION.lightened(0.4)},
		{"pos": Vector2(0.62, 0.38), "kind": &"ally", "color": KangurTheme.BASTION.lightened(0.4)},
		{"pos": Vector2(0.72, 0.66), "kind": &"enemy", "color": KangurTheme.SIROCCO.lightened(0.25)},
		{"pos": Vector2(0.30, 0.20), "kind": &"sound", "color": KangurTheme.AMBER},
	]
	_hud.set_minimap_blips(blips)
	_hud.set_minimap_cone({"pos": Vector2(0.46, 0.62), "dir": Vector2(0.6, -0.8),
		"half_deg": 46.0, "dist": 0.34})
	_hud.add_killfeed("VUK", "LUCA", Enums.Team.BASTION, Enums.Team.SIROCCO, false)
	_hud.add_killfeed("KESTREL", "ELENA", Enums.Team.BASTION, Enums.Team.SIROCCO, true)
	_hud.add_killfeed("RUI", "DRIES", Enums.Team.SIROCCO, Enums.Team.BASTION, false)
	_hud.add_killfeed("SANNE", "TOMAS", Enums.Team.BASTION, Enums.Team.SIROCCO, false)
	_hud.add_radio("MARTA", "B is contested. Push.", 2)
	_hud.add_radio("JENS", "Holding grid C-4.", 0)
	_hud.add_radio("VUK", "Contact, north catwalk.", 1)
	_hud.show_damage_angle(-1.9)
	_hud.show_damage_angle(0.55)
	var roster: Array[Dictionary] = [
		{"callsign": "Kestrel", "team": Enums.Team.BASTION, "class_id": "vanguard",
			"kills": 3, "deaths": 0, "damage": 412.0, "alive": true},
		{"callsign": "Vuk", "team": Enums.Team.BASTION, "class_id": "bulwark",
			"kills": 2, "deaths": 1, "damage": 260.0, "alive": true},
		{"callsign": "Marta", "team": Enums.Team.BASTION, "class_id": "pathfinder",
			"kills": 1, "deaths": 1, "damage": 120.0, "alive": false},
		{"callsign": "Dries", "team": Enums.Team.BASTION, "class_id": "longshot",
			"kills": 0, "deaths": 1, "damage": 88.0, "alive": true},
		{"callsign": "Luca", "team": Enums.Team.SIROCCO, "class_id": "ram",
			"kills": 2, "deaths": 1, "damage": 310.0, "alive": true},
		{"callsign": "Elena", "team": Enums.Team.SIROCCO, "class_id": "vanguard",
			"kills": 1, "deaths": 2, "damage": 205.0, "alive": false},
	]
	_hud.set_roster(roster)
	_hud.flash_hitmarker(true)
	# Crosshair colour/style come from Settings via the HUD's settings hook.
	Settings.set_value(&"gameplay", &"crosshair_style", 0)
	Settings.set_value(&"gameplay", &"crosshair_color", KangurTheme.HOLO)

func _build_arena() -> void:
	# Dark concrete plate with a faint grid: the HUD's contrast has to be judged
	# against gameplay-ish values, not an empty viewport.
	var bg := ColorRect.new()
	bg.color = Color("141a20")
	bg.z_index = -10
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := PortGrid.new()
	add_child(grid)

class PortGrid extends Node2D:
	func _draw() -> void:
		var vp := get_viewport_rect().size
		for i: int in 18:
			var x := vp.x * float(i) / 18.0
			draw_line(Vector2(x, 0.0), Vector2(x, vp.y), Color(0.35, 0.55, 0.55, 0.06), 1.0)
		for i: int in 11:
			var y := vp.y * float(i) / 11.0
			draw_line(Vector2(0.0, y), Vector2(vp.x, y), Color(0.35, 0.55, 0.55, 0.06), 1.0)
		# A couple of container blocks for spatial reference.
		draw_rect(Rect2(vp * 0.32, Vector2(220.0, 120.0)), Color("2a3640"))
		draw_rect(Rect2(vp * 0.56, Vector2(160.0, 90.0)), Color("3a2e28"))