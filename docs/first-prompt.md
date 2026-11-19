# Kangur, topdown 2D tactical shooter

We're building a production-grade, intricate and deep video game in Godot,
working title Kangur. It is to be a singleplayer topdown 2D shooter resembling
[CS2D](https://www.cs2d.com/). Not proof-of-concept software, no hacks, no
shortcuts, but a game that is competently designed and fun to play.

## Development Workflow

- Ask questions only when absolutely necessary. Work autonomously.
- Testing is important. Use lots of unit tests where relevant, particularly as
  means to simulate battles to check correctness, game balance and expected
  behaviour.
- Take screenshots to ensure that basic things are correct, like UI layout and
  whatever else can be captured this way.
- Do things properly, this is production-grade and not a hack project.
- Create AGENTS.md and relevant skills to support development, and contain
  concrete development guidelines. This will help with scaling the software or
  fixing bugs.
- Be wildly ambitious. This project outline should not be limiting, only serve
  as a guideline. Freely and liberally expand scope where it adds richness to
  end-product.
- Be wildly creative. Experimentation and novel ideas are expected, rather than
  creating a topdown Call of Duty or Battlefield clone.
- Set up the project such that it is easy to pick it up by a developer not
  familiar with the project and start modifying the game's UI, aesthetics, or
  add more gameplay content like maps.
- Do not assume that the "final result" will be correct. Expect user feedback
  with many corrections, but develop extensively until highly confident that
  the end-product is far above a mere minimum viable product.
- Create git repository on `master` branch.
- Licensed under European Union Public Licence 1.2.

## Essential Tech & Mechanical stack

- Godot game engine.
- [godot-vision-cone](https://github.com/d-bucur/godot-vision-cone) plugin for
  the vision faculties.
- [at-icons](https://github.com/Voxybuns/at-icons) for developer-facing node
  icons in the engine. Very helpful for people.

## High-Level Description of the Game

Kangur is to be a game resembling the aesthetics and feel of CS2D
("Counter-Strike 2D"), but be distinctly more tactical and geared exclusively
as a singleplayer experience. At the same time, it should simulate the feel of
a multiplayer game through the use of many and complex NPCs. With elements of
Battlefield and Call of Duty too, but not feeling like a carbon-copy of either
of those.

NPCs are the beam upon which the entire game is built. If the NPCs are dull,
the entire game is dull and boring. Key effort needs to go towards making
exciting, unpredictable and organic NPCs.

### Core

- Topdown shooter where cursor moves the crosshairs. Camera partially moves
  with the crosshair, allowing the player (and NPCs) to see far.
- Limited version to a cone, obstructed by obstacles.
- Tile-based maps. *Tip: A recreation of de_dust2 would be a good test map.*
- Characters comprised of animated head, arms, and firearms (as seen from
  above). Think Hotline Miami here.
- Several weapons, including shotguns, and classes to choose from.
- Medium-paced and tactical movement, feeling like something between Source
  Engine movement and realistic person movement.
- High lethality of weapons, low time to kill.
- Hefty recoil, considerable spread on automatic fire, highly impractical to
  fire while moving quickly. As in real world firearms handling, semi-automatic
  and burst fire is needed for proper accuracy.
- Realistic firearm ballistics; no slow arcade bullets, but also not hitscan.
- Full video game flow, from title menu to settings menu, match lobby, credits,
  etc..
- Rich HUD complete with illustrations and aesthetics reflecting the game
  aesthetic.
- Minimap showing objectives, map outline, team mate positions and enemy
  positions if enemy is seen by at least one team mate.
- Simulation of obstructed audio, both completely and partially, for a proper
  spatial 2D audio experience. Include footsteps and other relevant sounds to
  add to the atmosphere.

### Game Modes

- Up to 12 vs 12 combatants.
- Team Deathmatch, standard shooter mode
  * No respawns
  * Surviving team wins
  * Time limit
- Battle
  * Respawns
  * Attacker team has limited respawn tickets
  * Attacker team needs to complete the entire series of map objectives before
    they run out of tickets
  * Defender team wins if attacker objectives have not been achieved and the
    attacker team runs out of tickets
- At least two maps for each game mode

### Health & Wounds

- Health system, simulating torso and limbs, with various effects depending on
  which part was hit.
- Bandaging.
- Recovery over time.

### NPCs & Behaviour

- NPC behaviour that is stimulating and challenging the player at all times,
  but without resorting to cheap tricks and unfair advantage (e.g. "wallhacks"
  or "aimbot"). As such, NPCs need to
  * face hotspots where enemies frequently are seen,
  * cover team mates' flanks,
  * take cover,
  * camp,
  * check their own six,
  * sporadically adjust position,
  * sporadically linger,
  * react logically to team mates dying in rapid succession in a kill zone,
  * immediately take cover when facing impossible odds,
  * act cautiously in face of unlikely odds,
  * ... and so on.
- NPCs should behave like players, in the sense that they go their own ways,
  but cooperate broadly on the objectives. They do not need to behave like
  a disciplined e-sports team, but should organically work towards a match
  objective.
- Never behave like cheap robots where they bunch up in one spot or perform the
  exact same sequence of events every match. Every match in this respect must
  be fresh and unpredictable.

## Aesthetics

- Near-future feel with a hint of sci-fi.
- Story based on corporate mercenaries facing each other off in brutal combat.
- Based in Europe.

## Tips

- Located in `/home/mjensen/Obrazy/Assets` are various UI, 2D and SFX assets,
  including firearm sounds and UI sounds.
- Look up the Internet liberally for useful information.
- Research how other games of the topdown shooter and general shooter genre
  work instead of reinventing everything, but also seek inspiration to enrich
  the end-product.
- If Godot API starts causing problems, look up the
  [documentation](https://docs.godotengine.org/en/latest/tutorials/) instead of
  fruitlessly guessing arguments or fuzzing the game engine.
