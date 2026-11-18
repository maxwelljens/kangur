class_name MatchConfig
extends RefCounted
## Everything needed to start one match. Built by the lobby, consumed by
## `Match.start(config)`. Contract: docs/architecture.md §3.5, §10.

var mode: Enums.Mode = Enums.Mode.ELIMINATION
var map_id: StringName = &""
var player_team: int = Enums.Team.BASTION
var player_class_id: StringName = &"vanguard"
var primary_id: StringName = &""
var sidearm_id: StringName = &"adder"
var equipment_ids: Array[StringName] = []
var bot_count_bastion: int = 5
var bot_count_sirocco: int = 6
## DifficultyDef id; empty falls back to Settings' gameplay/difficulty.
var difficulty_id: StringName = &"operator"
## 0 = roll a fresh seed in `Game.to_match()` (every match fresh, AGENTS §7).
var seed: int = 0
## Elimination default 8 min, Battle 15 min (design §10).
var time_limit_s: float = 480.0
var attacker_tickets: int = 48
var player_callsign: String = "Kestrel"

func bot_count(team: int) -> int:
	return bot_count_bastion if team == Enums.Team.BASTION else bot_count_sirocco

## Bots plus the local player when they play on `team`.
func total_team(team: int) -> int:
	return bot_count(team) + (1 if team == player_team else 0)

func total_characters() -> int:
	return total_team(Enums.Team.BASTION) + total_team(Enums.Team.SIROCCO)

## Enemies of the local player, i.e. the opposing team.
func enemy_team() -> int:
	return Enums.other_team(player_team)