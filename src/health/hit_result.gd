class_name HitResult
extends RefCounted
## Outcome of one BodyModel.apply_hit(). The node translates this into events.

var died: bool = false
## Enums.Part that killed (only meaningful when `died`).
var fatal_part: int = -1
## Bleed rate added by this hit, HP/s (0 when the wound did not cross a threshold).
var bleed_added: float = 0.0
## Enums.Part that just crossed the cripple threshold, -1 if none.
var crippled: int = -1
## Damage soaked by vest/helmet, HP.
var absorbed: float = 0.0