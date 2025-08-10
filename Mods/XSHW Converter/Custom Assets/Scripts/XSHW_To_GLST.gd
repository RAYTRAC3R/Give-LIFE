# xshw_to_rr.gd
# Convert .xshw showtape -> RR-Engine save (single GL_Record node)
# Usage: instantiate XSHWConverter and call convert_file("res://path/to/file.shw")
# Output written to: user://My Precious Save Files/<workspace_id>/

extends Node
class_name XSHWConverter

# --- USER: fill this mapping with numeric IDs -> row names ---
const ID_TO_NAME := {
	# 1: "Light1",
	# 2: "Light2",
}

# Path to your Record scene used in saves (adjust to your project's path)
const RECORD_SCENE_PATH := "res://Mods/Standard Nodes/Custom Assets/Node Scripts/GL_Record.gd"

# Frame rate used by the showtape format
const FRAME_RATE := 60.0

# ------------ Public API ------------
# Convert a .shw file. Returns workspace_id (string) on success, empty string on failure.
func convert_file(in_path: String) -> String:
	if not in_path.to_lower().ends_with(".shw"):
		push_error("Only .shw files supported. Input must end with .shw")
		return ""

	# reset fields
	self.audio_data = null
	self.signal_data = []
	self.footer = null

	if not _read_shw(in_path):
		push_error("Failed to read .shw file: " + in_path)
		return ""

	# ensure we have data
	if self.audio_data == null or self.signal_data.size() == 0:
		push_error("No audio or signal data found in file.")
		return ""

	# create workspace
	var workspace_id = _generate_workspace_id()
	var workspace_folder = "user://My Precious Save Files/%s/" % workspace_id
	DirAccess.make_dir_recursive_absolute(workspace_folder)

	# save audio raw under /<id>/Audio/audio.wav
	var audio_dir = workspace_folder + "Audio/"
	DirAccess.make_dir_recursive_absolute(audio_dir)
	var audio_path = audio_dir + "audio.wav"
	var f_audio = FileAccess.open(audio_path, FileAccess.WRITE)
	if f_audio == null:
		push_error("Failed to create audio output file: " + audio_path)
		return ""
	f_audio.store_buffer(self.audio_data)
	f_audio.close()
	print("Saved audio to:", audio_path)

	# Build rows dictionary for GL_Record node
	var rows : Dictionary = {}
	rows["Recording"] = {"input": false, "output": false, "connections": [], "picker": true, "pickValue": false, "backConnected": false, "pickFloatMax": 0}
	rows["Current Time"] = {"input": 0.0, "output": 0.0, "connections": [], "picker": false, "pickValue": 0.0, "backConnected": false, "pickFloatMax": 0.0}

	for id_key in ID_TO_NAME.keys():
		var name = ID_TO_NAME[id_key]
		rows[name] = {"input": false, "output": false, "connections": [], "picker": false, "pickValue": false, "backConnected": false, "pickFloatMax": 0}

	# Build recording structure in GL_Record format
	var recording : Dictionary = {}
	for id_key in ID_TO_NAME.keys():
		var name = ID_TO_NAME[id_key]
		recording[name] = {"start": null, "end": null, "current": null, "list": {}, "lastUsed": null}
	recording["Recording"] = {"start": null, "end": null, "current": null, "list": {}, "lastUsed": null}
	recording["Current Time"] = {"start": null, "end": null, "current": null, "list": {}, "lastUsed": null}

	# Fill recording from signal_data (Single-ID mode)
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()

	var last_active_id := 0
	var total_samples := int(self.signal_data.size())
	for i in range(total_samples):
		var v = int(self.signal_data[i])
		# only act on changes (including from 0 -> id or id -> 0 or id1 -> id2)
		if v == last_active_id:
			continue

		var t = float(i) / FRAME_RATE

		# close previous active ID (append false event)
		if last_active_id != 0 and ID_TO_NAME.has(last_active_id):
			var name_close = ID_TO_NAME[last_active_id]
			var close_id = "ID_%d" % rng.randi()
			recording[name_close]["list"][close_id] = {
				"value": false,
				"time": t,
				"back": recording[name_close]["end"],
				"forward": null
			}
			# link previous end forward -> this
			if recording[name_close]["end"] != null:
				recording[name_close]["list"][recording[name_close]["end"]]["forward"] = close_id
			if recording[name_close]["start"] == null:
				recording[name_close]["start"] = close_id
			recording[name_close]["end"] = close_id

		# open new active ID (append true event)
		if v != 0 and ID_TO_NAME.has(v):
			var name_open = ID_TO_NAME[v]
			var open_id = "ID_%d" % rng.randi()
			recording[name_open]["list"][open_id] = {
				"value": true,
				"time": t,
				"back": recording[name_open]["end"],
				"forward": null
			}
			if recording[name_open]["end"] != null:
				recording[name_open]["list"][recording[name_open]["end"]]["forward"] = open_id
			if recording[name_open]["start"] == null:
				recording[name_open]["start"] = open_id
			recording[name_open]["end"] = open_id

		last_active_id = v

	# close final active ID at end of file (if any)
	var duration = float(total_samples) / FRAME_RATE
	if last_active_id != 0 and ID_TO_NAME.has(last_active_id):
		var name_last = ID_TO_NAME[last_active_id]
		var end_id = "ID_%d" % rng.randi()
		recording[name_last]["list"][end_id] = {
			"value": false,
			"time": duration,
			"back": recording[name_last]["end"],
			"forward": null
		}
		if recording[name_last]["end"] != null:
			recording[name_last]["list"][recording[name_last]["end"]]["forward"] = end_id
		if recording[name_last]["start"] == null:
			recording[name_last]["start"] = end_id
		recording[name_last]["end"] = end_id

	# Build saveDict with a single node entry
	var saveDict : Dictionary = {}
	var save_key = "SAVE_%d" % rng.randi()
	var node_uuid = str(rng.randi())
	var node_name = in_path.get_file().get_basename()
	var node_data = {
		"path": RECORD_SCENE_PATH,
		"name": node_name,
		"uuid": node_uuid,
		"special_saved_values": {},
		"rows": rows,
		"position": Vector2.ZERO
	}
	saveDict[save_key] = node_data

	# Write node_workspace.tres (ConfigFile)
	var cfg = ConfigFile.new()
	var time_created = Time.get_datetime_string_from_system(true)
	cfg.set_value("meta", "save_name", node_name)
	cfg.set_value("meta", "author", "Converted")
	cfg.set_value("meta", "version", ProjectSettings.get_setting("application/config/version"))
	cfg.set_value("meta", "game_title", ProjectSettings.get_setting("application/config/name"))
	cfg.set_value("meta", "time_created", time_created)
	cfg.set_value("meta", "last_updated", time_created)
	cfg.set_value("workspace", "data", saveDict)

	var file_path = workspace_folder + "node_workspace.tres"
	var save_err = cfg.save(file_path)
	if save_err != OK:
		push_error("Failed to save node_workspace.tres: %s (err %d)" % [file_path, save_err])
		return ""
	print("Saved node_workspace.tres ->", file_path)

	# Save recording file for the node
	var recording_cfg = ConfigFile.new()
	recording_cfg.set_value("recording", "data", recording)
	var rec_path = workspace_folder + node_uuid + "_recording.tres"
	var rec_err = recording_cfg.save(rec_path)
	if rec_err != OK:
		push_error("Failed to save recording file: %s (err %d)" % [rec_path, rec_err])
		return ""
	print("Saved recording ->", rec_path)

	print("Conversion complete. Workspace ID:", workspace_id)
	return workspace_id


# -------------------------
# Helper: read .shw file (binary format)
# -------------------------
func _read_shw(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open file: " + path)
		return false

	# Ensure file is reasonably large
	var file_len = f.get_length()
	if file_len < 0xDD:
		push_error("File too small/invalid .shw: " + path)
		f.close()
		return false

	# Skip header (0xDD bytes)
	f.seek(0)
	var _header_bytes = f.get_buffer(0xDD)

	# Next: 4-byte wav length (little-endian) and 1-byte marker
	var wav_length := int(f.get_32())
	var marker := int(f.get_8())
	# read audioData
	var audio_buf := f.get_buffer(wav_length)
	# skip next 5 bytes (pattern)
	var _skip = f.get_buffer(5)
	# next: signalfilesamples (4 bytes) and 1-byte marker
	var signalfilesamples := int(f.get_32())
	var _marker2 := int(f.get_8())
	# read signalfilesamples integers (4 bytes each)
	var signal_list = []
	for i in range(signalfilesamples):
		signal_list.append(int(f.get_32()))
	# read terminating byte if present and remainder as footer
	var footer_buf: PackedByteArray = PackedByteArray()
	if f.get_position() < f.get_length():
		var _term = f.get_8()
		var footer_size = int(f.get_length() - f.get_position())
		if footer_size > 0:
			footer_buf = f.get_buffer(footer_size)
	f.close()

	self.audio_data = audio_buf
	self.signal_data = signal_list
	self.footer = footer_buf
	return true


# -------------------------
# Utility: workspace id generation
# -------------------------
func _generate_workspace_id() -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	return str(rng.randi())
