extends Node
## EventBus — autoload. Signals only, no state. Contract: architecture §5.
## Loose parameter types avoid class_name cycles; concrete types documented
## per signal. Emitters never assume listeners; listeners must be cheap.

# --- combat -----------------------------------------------------------------
## shooter: Character. pellets: 1 for bullets, N for shotguns.
signal shot_fired(shooter: Node, weapon_id: StringName, origin: Vector2, dir: Vector2, pellets: int)
## surface: Enums.Surface. penetrated: bullet passed through this surface.
signal bullet_impact(pos: Vector2, normal: Vector2, surface: int, penetrated: bool)
## victim/attacker: Character. part: Enums.Part. fatal: this hit killed.
signal character_hit(victim: Node, attacker: Node, part: int, damage: float, fatal: bool, pos: Vector2)
## attacker may be null (bleed-out, fall, etc.). distance: px.
signal character_died(victim: Node, attacker: Node, weapon_id: StringName, pos: Vector2, distance: float)
signal weapon_reloaded(who: Node, weapon_id: StringName)
signal weapon_switched(who: Node, weapon_id: StringName)
signal fire_mode_changed(who: Node, mode: int)
signal bandage_started(who: Node)
signal bandage_finished(who: Node, part: int)
signal equipment_thrown(who: Node, kind: StringName, pos: Vector2)
signal equipment_detonated(kind: StringName, pos: Vector2, radius: float)
## Applied by Characters in LOS of a flash detonation. strength 0..1.
signal flash_effect(who: Node, strength: float)

# --- perception / world ------------------------------------------------------
## The ONLY audio gameplay path. loudness: px audible radius (design §12).
## kind: &"gunshot", &"footstep", &"reload", &"explosion", &"bodyfall", …
## source: Character or null. surface: Enums.Surface (footsteps).
signal sound_emitted(pos: Vector2, loudness: float, kind: StringName, source: Node, surface: int)
## Immediate local sighting (spotter's own cone). Team radio sharing is
## handled separately by TeamIntel with delay+noise — do not bypass it.
signal enemy_spotted(spotter: Node, enemy: Node, pos: Vector2)
## priority: 0 casual, 1 contact, 2 urgent (killzone, objective).
signal radio_message(team: int, from_callsign: String, text: String, priority: int)
signal objective_progress(obj_id: StringName, team: int, progress: float, contested: bool)
signal objective_captured(obj_id: StringName, team: int)
signal tickets_changed(team: int, tickets: int)
## winner: Enums.Team or -1 draw. reason: &"elimination", &"timeout",
## &"objectives", &"tickets", &"surrender".
signal match_ended(winner: int, reason: StringName)
signal spawn_requested(team: int, pos: Vector2)

# --- meta --------------------------------------------------------------------
signal settings_changed(section: StringName)
signal match_state_changed()
