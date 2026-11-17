# Kangur

Singleplayer topdown 2D tactical shooter. Near-future Europe: two corporate
mercenary outfits — **BASTION Security Group** and **SIROCCO Extraction Corps** —
fight proxy wars over ports, terminals, and old-town power seats.

CS2D's look and camera. Hotline Miami's lethality. Firearm handling that
rewards stopping, bracing, and bursting. Wounds that matter: legs slow you,
arms ruin your aim, bleeding kills you if you don't bandage. Vision cones
blocked by walls. Sound muffled through concrete. Up to 12v12 NPCs that
perceive exactly what you perceive — and play like people: camping, flanking,
checking their six, panicking out of kill zones, lingering at corners.

**Modes**: Elimination (one life, surviving team wins) · Battle (objective
chain, attacker tickets) · Training Range.

## Status

In active development. See `docs/design/game-design.md` (design bible) and
`docs/architecture.md` (technical contracts).

## Running

Requires Godot 4.7+ (standard, not .NET):

```bash
godot --path . -e     # editor
godot --path .        # play
tools/verify.sh       # tests + sims + screenshots gate
```

## For developers & modders

Start with **AGENTS.md**. Adding weapons, classes, or maps requires no code —
see `docs/adding-content.md`. Project skills for AI agents live in
`.opencode/skill/`.

## License

Code: **EUPL-1.2** (`LICENSE`). Third-party assets: their own licenses,
attributed in `docs/credits.md` and the in-game Credits screen.
