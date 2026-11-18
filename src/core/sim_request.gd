class_name SimRequest
extends RefCounted
## Parsed `--sim=<map>:<mode>:<seed>:<count>` CLI request. Dev emits it on
## `Dev.sim_requested`; the simulation module (tests/simulation) owns the run.
## Contract: docs/architecture.md §11.

var map_id: StringName = &""
var mode: Enums.Mode = Enums.Mode.ELIMINATION
var seed: int = 0
var bot_count: int = 12
## Optional match time limit (5th CLI field); 0 = mode default. The per-commit
## gate uses short matches so it finishes fast; balance runs use full length.
var time_limit_s: float = 0.0

## Loose parse: mode accepts `elimination|battle|training` or the enum int.
static func parse(spec: String) -> SimRequest:
	var parts := spec.rsplit(":", true, 4)
	if parts.size() < 4:
		return null
	var request := SimRequest.new()
	request.map_id = StringName(parts[0])
	request.mode = _parse_mode(parts[1])
	request.seed = int(parts[2])
	request.bot_count = maxi(int(parts[3]), 0)
	if parts.size() >= 5:
		request.time_limit_s = maxf(float(parts[4]), 0.0)
	return request

static func _parse_mode(raw: String) -> int:
	var lowered := raw.to_lower()
	var names := Enums.Mode.keys()
	for index: int in names.size():
		if String(names[index]).to_lower() == lowered:
			return int(Enums.Mode[names[index]])
	return int(raw)