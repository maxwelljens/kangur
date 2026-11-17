class_name Layers
extends RefCounted
## Collision layer/mask constants. Contract: docs/architecture.md §2.
## Layer 1 WORLD (high walls), 2 CHARACTER, 3 INTERACT (doors/objectives),
## 4 EQUIPMENT, 5 LOW_COVER (crates/cars — stance-conditional vision),
## 6 GLASS (see-through, shoot-through, 1-wall sound, shatters).

const WORLD := 1
const CHARACTER := 2
const INTERACT := 3
const EQUIPMENT := 4
const LOW_COVER := 5
const GLASS := 6

const WORLD_BIT := 1 << (WORLD - 1)
const CHARACTER_BIT := 1 << (CHARACTER - 1)
const INTERACT_BIT := 1 << (INTERACT - 1)
const EQUIPMENT_BIT := 1 << (EQUIPMENT - 1)
const LOW_COVER_BIT := 1 << (LOW_COVER - 1)
const GLASS_BIT := 1 << (GLASS - 1)

## Characters collide with walls, characters, interactables, cover, glass.
const CHARACTER_MASK := WORLD_BIT | CHARACTER_BIT | INTERACT_BIT | LOW_COVER_BIT | GLASS_BIT
## Bullet sweeps hit walls, characters, low cover, glass (penetration logic
## consults tile custom data at the hit point).
const BULLET_MASK := WORLD_BIT | CHARACTER_BIT | LOW_COVER_BIT | GLASS_BIT
## Vision rays (entity gating): everything that can block sight. The
## VisionSystem filters hits: glass passes, low cover applies stance rules
## (crouched target hidden; crouched observer blocked), walls/doors block.
const VISION_MASK := WORLD_BIT | INTERACT_BIT | LOW_COVER_BIT | GLASS_BIT
## Player fog cone polygon mask, STANDING: sees over low cover, through glass.
const CONE_MASK_STAND := WORLD_BIT | INTERACT_BIT
## Player fog cone polygon mask, CROUCHED: low cover blocks the view too.
const CONE_MASK_CROUCH := WORLD_BIT | INTERACT_BIT | LOW_COVER_BIT
## Sound occlusion rays: high walls only (glass counted as 1 wall via tile
## data when the ray hits it on the WORLD-adjacent query; see OcclusionMath).
const SOUND_MASK := WORLD_BIT | GLASS_BIT
## Equipment bounces off walls, characters, other equipment, cover, glass.
const EQUIPMENT_MASK := WORLD_BIT | CHARACTER_BIT | EQUIPMENT_BIT | LOW_COVER_BIT | GLASS_BIT
