class_name EliminationRules
extends MatchRules
## One life each, no respawns (design §10 "Elimination").
## Win: the other team is wiped. Timeout: more survivors win, then summed
## torso HP, then a draw (-1). Reasons: &"elimination" / &"timeout".

const REASON_ELIMINATION := &"elimination"
const REASON_TIMEOUT := &"timeout"

func tick(snapshot: MatchSnapshot, _dt: float) -> Array[RuleEvent]:
	var out: Array[RuleEvent] = []
	var bastion := snapshot.alive(Enums.Team.BASTION)
	var sirocco := snapshot.alive(Enums.Team.SIROCCO)
	if bastion == 0 or sirocco == 0:
		var winner := -1
		if bastion == 0 and sirocco > 0:
			winner = Enums.Team.SIROCCO
		elif sirocco == 0 and bastion > 0:
			winner = Enums.Team.BASTION
		out.append(end_event(winner, REASON_ELIMINATION))
		return out
	if snapshot.elapsed < time_limit_s:
		return out
	# Timeout ladder (design §10): survivors → summed torso HP → draw.
	var hp_bastion := snapshot.total_hp(Enums.Team.BASTION)
	var hp_sirocco := snapshot.total_hp(Enums.Team.SIROCCO)
	var winner := -1
	if bastion != sirocco:
		winner = Enums.Team.BASTION if bastion > sirocco else Enums.Team.SIROCCO
	elif not is_equal_approx(hp_bastion, hp_sirocco):
		winner = Enums.Team.BASTION if hp_bastion > hp_sirocco else Enums.Team.SIROCCO
	out.append(end_event(winner, REASON_TIMEOUT))
	return out

## Tell both squads the mode explicitly (defaults are free hunt anyway).
func phase_event() -> RuleEvent:
	return RuleEvent.make(RuleEvent.PHASE, {
		&"obj_id": &"", &"obj_pos": Vector2.ZERO, &"obj_order": 0,
		&"contested": false, &"attacker_phase": &"hunt",
		&"defender_phase": &"hunt",
	})