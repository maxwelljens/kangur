extends Node
## Entry scene. Godot refuses to boot a project without a main scene, and the
## title screen lands with the UI wave — so core owns this tiny forwarder.
## Contract: docs/architecture.md §3.5 (Game owns app flow).

func _ready() -> void:
	if Dev.harness_active:
		# `--sim` owns the run: boot only hosts the harness (src/modes/sim_runner).
		if Dev.sim_request != null:
			var runner := SimRunner.new()
			runner.name = "SimRunner"
			add_child(runner)
		return
	if ResourceLoader.exists(Game.TITLE_SCENE):
		Game.to_title()