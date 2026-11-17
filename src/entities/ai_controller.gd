extends "res://src/ai/ai_controller.gd"
## Entity-side AI controller path. The AI wave moved the brain to
## `src/ai/ai_controller.gd`; this file stays as the composition-point alias so
## Character (and the entity tests) keep preloading one stable path. Same
## interface: setup(host), fill_intent(intent, dt), and the setter surface.