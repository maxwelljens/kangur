extends Node
## Debrief screenshot fixture with a populated MatchResult (win, 12 rows,
## timeline). The real screen reads Game.last_result; with none it shows the
## explicit "contract void" state, which is correct but not what to inspect.
##   tools/godot.sh --path . --resolution 2560x1440 -- \
##     --shot=res://tools/shot_ui_debrief.tscn:25:reports/screenshots/ui_debrief.png

const Screen := preload("res://src/ui/menus/debrief_screen.tscn")

func _ready() -> void:
	Game.match_config = MatchConfig.new()
	Game.match_config.player_team = Enums.Team.BASTION
	Game.match_config.mode = Enums.Mode.BATTLE
	Game.match_config.map_id = &"terminal"
	Game.match_seed = 0x51cc0
	Game.last_result = _result()
	add_child(Screen.instantiate())

func _result() -> MatchResult:
	var result := MatchResult.new()
	result.winner = Enums.Team.BASTION
	result.reason = &"objectives"
	result.duration_s = 512.0
	result.mode = Enums.Mode.BATTLE
	result.map_id = &"terminal"
	result.player_index = 0
	result.characters = [
		_row("Kestrel", Enums.Team.BASTION, "vanguard", 14, 2, 2140.0, 168, 96, true),
		_row("Vuk", Enums.Team.BASTION, "bulwark", 9, 4, 1520.0, 210, 74, true),
		_row("Marta", Enums.Team.BASTION, "pathfinder", 7, 5, 980.0, 132, 51, false),
		_row("Dries", Enums.Team.BASTION, "longshot", 6, 3, 1340.0, 88, 44, true),
		_row("Sanne", Enums.Team.BASTION, "ram", 5, 6, 760.0, 190, 38, false),
		_row("Jens", Enums.Team.BASTION, "vanguard", 4, 5, 880.0, 150, 33, true),
		_row("Luca", Enums.Team.SIROCCO, "ram", 8, 7, 1210.0, 205, 59, false),
		_row("Elena", Enums.Team.SIROCCO, "vanguard", 7, 8, 1090.0, 184, 52, false),
		_row("Rui", Enums.Team.SIROCCO, "pathfinder", 6, 8, 940.0, 140, 41, false),
		_row("Tomas", Enums.Team.SIROCCO, "bulwark", 5, 9, 830.0, 178, 36, false),
		_row("Ines", Enums.Team.SIROCCO, "longshot", 4, 8, 720.0, 66, 29, false),
		_row("Bram", Enums.Team.SIROCCO, "vanguard", 3, 9, 610.0, 122, 24, false),
	]
	result.timeline = [
		{"t": 22.0, "kind": "kill", "team": Enums.Team.BASTION, "text": "Kestrel eliminated Bram"},
		{"t": 48.0, "kind": "objective", "team": Enums.Team.BASTION, "text": "A gatehouse captured"},
		{"t": 96.0, "kind": "kill", "team": Enums.Team.SIROCCO, "text": "Rui eliminated Sanne"},
		{"t": 154.0, "kind": "objective", "team": Enums.Team.SIROCCO, "text": "B warehouse contested"},
		{"t": 188.0, "kind": "kill", "team": Enums.Team.BASTION, "text": "Vuk eliminated Luca"},
		{"t": 244.0, "kind": "objective", "team": Enums.Team.BASTION, "text": "B warehouse captured"},
		{"t": 310.0, "kind": "kill", "team": Enums.Team.BASTION, "text": "Kestrel eliminated Elena"},
		{"t": 402.0, "kind": "objective", "team": Enums.Team.BASTION, "text": "C control tower captured"},
		{"t": 512.0, "kind": "result", "team": Enums.Team.BASTION, "text": "Contract secured"},
	]
	return result

func _row(callsign: String, team: int, class_id: StringName, kills: int,
		deaths: int, damage: float, fired: int, hit: int, survived: bool) -> Dictionary:
	var row := MatchResult.new_character_row(callsign, team, class_id)
	row["kills"] = kills
	row["deaths"] = deaths
	row["damage"] = damage
	row["shots_fired"] = fired
	row["shots_hit"] = hit
	row["survived"] = survived
	row["bandages_used"] = 2
	return row
