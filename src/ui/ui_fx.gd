extends RefCounted
## UiFx — shared UI motion + sound helpers. No state, no nodes.
## Motion budget: art-direction §4 / make-interfaces-feel-better (120–180 ms).

const FADE_S := 0.14
const STAGGER_S := 0.03
const HOVER_DB := -14.0
const CLICK_DB := -8.0

const STREAMS: Dictionary[StringName, AudioStream] = {
	&"hover": preload("res://assets/audio/ui/hover.ogg"),
	&"click": preload("res://assets/audio/ui/click.ogg"),
	&"confirm": preload("res://assets/audio/ui/confirm.ogg"),
	&"back": preload("res://assets/audio/ui/back.ogg"),
	&"error": preload("res://assets/audio/ui/error.ogg"),
	&"deploy": preload("res://assets/audio/ui/deploy.ogg"),
	&"start": preload("res://assets/audio/ui/start.ogg"),
	&"notify": preload("res://assets/audio/ui/notify.ogg"),
	&"objective": preload("res://assets/audio/ui/objective_capture.ogg"),
	&"ticket_warning": preload("res://assets/audio/ui/ticket_warning.ogg"),
	&"victory": preload("res://assets/audio/ui/match_end_victory.ogg"),
	&"defeat": preload("res://assets/audio/ui/match_end_defeat.ogg"),
}

## Fade a control in after `delay`. Alpha only: containers own position, so
## nudging offsets would fight the layout pass.
static func fade_in(control: Control, delay: float = 0.0) -> void:
	if control == null or not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, FADE_S) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func stagger(controls: Array[Control], delay: float = 0.0) -> void:
	for i: int in controls.size():
		fade_in(controls[i], delay + i * STAGGER_S)

## One shared player on the tree root: overlapping UI blips may cut each other
## off, which is fine for sub-100 ms feedback and avoids a pool.
static func play_sound(key: StringName, volume_db: float = HOVER_DB) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = STREAMS.get(key)
	if stream == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player: AudioStreamPlayer = tree.root.get_node_or_null(^"__ui_audio")
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "__ui_audio"
		player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		tree.root.add_child(player)
	player.stream = stream
	player.volume_db = volume_db
	player.play()

static func click() -> void:
	play_sound(&"click", CLICK_DB)

static func back() -> void:
	play_sound(&"back", CLICK_DB)

## Pulse a control's modulate (damage flashes, ticket warnings).
static func flash(control: CanvasItem, color: Color, duration: float = 0.25) -> void:
	if control == null:
		return
	var base := control.modulate
	control.modulate = color
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", base, duration)