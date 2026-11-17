extends SceneTree
## Checks every id the director accepts (integration surface) against the files
## on disk. Run: tools/godot.sh --headless --path . -s tools/audio_asset_check.gd

const MUSIC: Array[String] = [&"title_theme", &"lobby_deploy", &"clutch", &"debrief_win", &"debrief_loss", &"match_calm", &"match_engaged"]
const AMBIENCE: Array[String] = [&"wind", &"industrial_hum", &"harbor_gulls", &"city_murmur", &"distant_traffic"]
const UI: Array[String] = [&"hover", &"hover_alt", &"click", &"click_soft", &"confirm", &"confirm_alt", &"back", &"back_alt", &"error", &"error_alt", &"notify", &"start", &"deploy", &"hud_hit", &"hud_hit_alt", &"ticket_warning", &"objective_capture", &"match_end_victory", &"match_end_defeat"]
const VOICE: Array[String] = [&"contact", &"warning", &"denied", &"affirmative", &"status"]

func _initialize() -> void:
	var missing: Array[String] = []
	for id: String in MUSIC:
		missing.append_array(_check("res://assets/audio/music", id))
	for id: String in AMBIENCE:
		missing.append_array(_check("res://assets/audio/ambience", id))
	for id: String in UI:
		missing.append_array(_check("res://assets/audio/ui", id))
	for id: String in VOICE:
		var dir := "res://assets/audio/voice/" + id
		var found := 0
		for name: String in DirAccess.get_files_at(dir):
			if name.get_extension() == "wav":
				found += 1
		if found == 0:
			missing.append(dir + "/ (no samples)")
	print("\n=== AUDIO ASSET CHECK ===")
	print("missing: ", "none" if missing.is_empty() else missing)
	quit()

func _check(dir: String, id: String) -> Array[String]:
	for ext: String in ["ogg", "mp3", "wav"]:
		if ResourceLoader.exists("%s/%s.%s" % [dir, id, ext]):
			return []
	return ["%s/%s" % [dir, id]]