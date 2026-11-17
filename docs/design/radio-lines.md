# Kangur — Radio Chatter Lines

Radio makes NPCs feel human. Tone: dry, professional, corporate-mercenary.
BASTION = defensive contractor (calm, procedural, grid refs, "holding").
SIROCCO = extraction corps (terse, momentum, "pushing"). Never cartoonish,
never quippy-marvel. Short lines (≤ 8 words typical).

Placeholders: `{callsign}` speaker, `{grid}` map grid ref (8×8, A–H × 1–8),
`{weapon}` weapon display name, `{count}` number, `{obj}` objective letter.
Lines live in `FactionDef.radio: Dictionary[StringName, Array[String]]`
(authored as `data/factions/*.tres`). Runtime: `EventBus.radio_message`,
rate-limited (≤1 line/1.5 s per NPC, priority queue: urgent bypasses),
displayed as 4 fading lines near minimap + optional processed voice bark.

Priority: 0 casual · 1 contact/combat · 2 urgent (killzone, objective, last man).

## BASTION (defensive, procedural)

```
contact            "Contact, {grid}." / "Eyes on, {grid}." / "Logging contact, {grid}."
contact_multiple   "Multiple contacts, {grid}." / "{count} hostiles, {grid}, logging."
kill               "Target down." / "Confirmed, {grid}." / "One less contract."
kill_streak        "Site's clearing. Hold." / "Good effect on target."
death              "{callsign} is down." / "Lost {callsign}, {grid}." / "Man down, {grid}."
reload             "Reloading, cover." / "Mag change." / "Dry, covering."
bandage_start      "Patching up, hold." / "Bleeding out, need a second."
bandage_done       "Patched. Back in." / "Stable."
killzone           "Lost {count} at {grid} — kill zone, avoid." / "{grid} is a meat grinder. Hold angles." / "Two down {grid}, nobody crosses."
retreat            "Falling back, {grid}." / "Disengaging. Cover."
regroup            "Regroup on me." / "Consolidate, {grid}."
hold               "Holding {grid}." / "Anchor set." / "Static here."
check_six          "Checking rear." / "Rear's clear." / "Watching our six."
flank              "Rotating {grid}." / "Taking the long way."
suppress           "Suppressing {grid}." / "Keeping heads down."
objective_start    "Moving on {obj}." / "Contract says {obj}. Move."
objective_contested "{obj} is contested." / "They're on {obj}, push."
objective_captured "{obj} secured. Logging." / "{obj} is ours. Next."
objective_lost     "Lost {obj}. Recover." / "{obj} is theirs, rotate."
tickets_low        "We're burning replacements. Careful." / "Few lives left. Make them count."
last_man           "I'm the last one. Contract's on me." / "Solo now. Holding."
flash_out          "Flash out." / "Blinding {grid}."
smoke_out          "Smoke deployed." / "Screening {grid}."
frag_out           "Frag out." / "Ordnance, {grid}."
enemy_flash        "Flash! Turn away." / "Blinded, cover."
enemy_smoke        "Smoke screen, {grid}." / "Can't see through it. Hold."
spot_sniper        "Sniper, {grid}. Keep cover." / "Long gun watching {grid}."
spot_lmg           "Machine gun, {grid}. Don't peek." 
low_hp             "I'm hit bad." / "Bleeding, need cover."
armor_broken       "Plate's cracked." / "Armor's done."
win                "Contract complete. Good work." / "Site held. Logging victory."
lose               "Contract failed. Fall out." / "We're done here. Withdraw."
spawn              "Back on site." / "Replacement deployed."
```

## SIROCCO (aggressive, terse)

```
contact            "Contact {grid}." / "On me, {grid}." / "Found them, {grid}."
contact_multiple   "{count} of them, {grid}." / "Crowd at {grid}, pushing."
kill               "Dropped." / "One down." / "Extracted."
kill_streak        "They're breaking. Push." / "Keep the momentum."
death              "{callsign}'s down!" / "Lost {callsign}!" / "Man down {grid}!"
reload             "Reloading!" / "Cover, dry." / "Mag!"
bandage_start      "Patching, cover me." / "Bleeding — give me a sec."
bandage_done       "Good. Moving." / "Back in it."
killzone           "{grid} ate {count} of us — go around!" / "Don't cross {grid}, it's a blender." / "Kill zone {grid}, flank it."
retreat            "Back! Back!" / "Disengage, {grid}."
regroup            "On me, now." / "Stack up {grid}."
hold               "Holding {grid}." / "Pinned here, watching."
check_six          "Six's clear." / "Watching back." / "Rear check."
flank              "Flanking {grid}." / "Going wide." / "Around the side."
suppress           "Suppressing!" / "Heads down {grid}!"
objective_start    "Push {obj}, go." / "{obj} is the job. Move."
objective_contested "{obj}'s contested, push!" / "They're on {obj}!"
objective_captured "{obj} ours. Next." / "Taken. Keep moving."
objective_lost     "Lost {obj}, retake!" / "{obj} gone — rotate!"
tickets_low        "We're almost out of lives. Commit." / "Last replacements. Make it count."
last_man           "Just me. Fine." / "Solo. I'll finish it."
flash_out          "Flash!" / "Blinding!"
smoke_out          "Smoke out." / "Screening."
frag_out           "Frag!" / "Grenade out."
enemy_flash        "Flash, turn!" / "Blinded!"
enemy_smoke        "Smoke {grid}." / "Screened, wait it out."
spot_sniper        "Sniper {grid}!" / "Long gun, keep down."
spot_lmg           "MG {grid}, don't peek!"
low_hp             "Hit bad!" / "Bleeding here!"
armor_broken       "Plate's gone!" / "Armor cracked."
win                "Extraction complete. Paid in full." / "Job's done. Move out."
lose               "Contract's blown. Fall back." / "Cut losses. Out."
spawn              "Back in." / "Reinserted."
```

## Usage rules
- Killzone lines fire ONLY on the danger-map trigger (2+ deaths/6 s/150 px),
  priority 2, once per zone per 20 s (no spam).
- `check_six` lines accompany the actual check-six behavior sometimes (30%)
  — audible flavor, not a tell of exact timing.
- Death lines from teammates who WITNESSED it (cone or radio), not omniscient.
- `last_man` fires when team alive count hits 1 (Elimination) — tension beat.
- Voice barks (CC0 ship voices, bandpass-processed): map categories
  contact→"Hostiles Detected", kill→"Target Neutralized" (if present),
  warning→killzone/low_hp, etc. Text is canonical; voice is optional flavor.
- Grid ref computed from world pos: `col = floor(x / (map_w/8))` → A–H,
  `row = floor(y / (map_h/8))` → 1–8. Shown on minimap grid overlay (toggle).
