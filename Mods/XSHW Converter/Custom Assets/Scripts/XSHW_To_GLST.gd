# xshw_to_rr.gd
# Convert .xshw showtape -> RR-Engine save (single GL_Record node)
# Usage:
#   var conv = XSHWConverter.new()
#   conv.load_bit_charts("My Mod Name")         # loads all JSON charts from that mod
#   conv.convert_file("res://path/to/file.xshw", "chart_basename")  # chart_basename = filename without .json
#
# Output written to: user://My Precious Save Files/<workspace_id>/

extends Node
class_name XSHWConverter

# Path to your Record scene used in saves (adjust to your project's path)
const RECORD_SCENE_PATH := "res://Mods/Standard Nodes/Mod Directory/Nodes/Record.tscn"

# Frame rate used by the showtape format
const FRAME_RATE := 60.0

# Loaded charts: chart_name (basename) -> Dictionary[int id -> String name]
var BIT_CHARTS: Dictionary = {}

# keep track of unknown ids seen during conversion to avoid repeated warnings
var _unknown_id_cache: Dictionary = {}
var audio_data
var footer
var signal_data

# ------------ Public API ------------

# Load all JSON files in: res://Mods/<mod_name>/Mod Directory/Bit Charts/
# Each JSON should be a dictionary mapping bit ID (string or number) -> output name (string).
# The keys in BIT_CHARTS will be the json file basenames (without .json).
# Returns true on success (found at least one JSON), false on failure.
func load_bit_charts() -> bool:
	BIT_CHARTS.clear()
	_unknown_id_cache.clear()

	var mods_path = "res://Mods"
	if not DirAccess.dir_exists_absolute(mods_path):
		push_error("Mods directory not found: " + mods_path)
		return false

	var mods_dir = DirAccess.open(mods_path)
	if mods_dir == null:
		push_error("Failed to open Mods directory: " + mods_path)
		return false

	mods_dir.list_dir_begin()
	var mod_folder = mods_dir.get_next()
	var found_any := false

	while mod_folder != "":
		if mod_folder.begins_with("."):
			# skip hidden/system folders
			mod_folder = mods_dir.get_next()
			continue
		var mod_path = mods_path + "/" + mod_folder
		if DirAccess.dir_exists_absolute(mod_path):
			var charts_path = mod_path + "/Mod Directory/Bit Charts"
			if DirAccess.dir_exists_absolute(charts_path):
				var charts_dir = DirAccess.open(charts_path)
				if charts_dir != null:
					charts_dir.list_dir_begin()
					var fname = charts_dir.get_next()
					while fname != "":
						if not charts_dir.current_is_dir() and fname.to_lower().ends_with(".json"):
							var file_path = charts_path + "/" + fname
							var file = FileAccess.open(file_path, FileAccess.READ)
							if file:
								var text = file.get_as_text()
								file.close()
								var json = JSON.new()
								var parsed = json.parse_string(text)
								if typeof(parsed) == TYPE_DICTIONARY:
									var map := {}
									for k in parsed.keys():
										var key_int := 0
										var ok := true
										if typeof(k) == TYPE_INT:
											key_int = int(k)
										else:
											var s = String(k)
											# Check if s is a valid integer string by comparing to its int conversion string
											if s == str(s.to_int()):
												key_int = s.to_int()
											else:
												ok = false
										if ok:
											map[key_int] = String(parsed[k])
										else:
											push_warning("Skipping non-integer key in %s: %s" % [file_path, str(k)])									
									var base = fname.get_basename()
									BIT_CHARTS[base] = map
									found_any = true
								else:
									push_warning("Failed to parse JSON (expect dictionary) in: " + file_path)
							else:
								push_warning("Failed to open file: " + file_path)
						fname = charts_dir.get_next()
					charts_dir.list_dir_end()
		mod_folder = mods_dir.get_next()
	mods_dir.list_dir_end()

	if not found_any:
		push_warning("No bit-chart JSON files found in any mod's Bit Charts directories.")
	return found_any



# Convert a .xshw file using the chart named chart_name (basename of a JSON file loaded into BIT_CHARTS).
# Returns workspace_id (string) on success, empty string on failure.
func convert_file(in_path: String, chart_name: String) -> String:
	if not in_path.to_lower().ends_with("shw"):
		push_error("Only .xshw/.shw files supported. Input must end with .shw")
		return ""

	if not BIT_CHARTS.has(chart_name):
		push_error("Chart not loaded: %s. Call load_bit_charts() and ensure '%s.json' exists." % [chart_name, chart_name])
		return ""

	var id_to_name: Dictionary = BIT_CHARTS[chart_name]
	_unknown_id_cache.clear()

	# read .shw
	self.audio_data = null
	self.signal_data = []
	self.footer = null
	if not _read_shw(in_path):
		push_error("Failed to read .shw file: " + in_path)
		return ""

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

	# Build rows dictionary for GL_Record node (booleans)
	var rows : Dictionary = {}
	rows["Recording"] = {"input": false, "output": false, "connections": [], "picker": true, "pickValue": false, "backConnected": false, "pickFloatMax": 0}
	rows["Current Time"] = {"input": 0.0, "output": 0.0, "connections": [], "picker": false, "pickValue": 0.0, "backConnected": false, "pickFloatMax": 0.0}

	for id_key in id_to_name.keys():
		var name = id_to_name[id_key]
		rows[name] = {"input": false, "output": false, "connections": [], "picker": false, "pickValue": false, "backConnected": false, "pickFloatMax": 0}

	# Build recording structure in GL_Record format
	var recording : Dictionary = {}
	for id_key in id_to_name.keys():
		var name = id_to_name[id_key]
		recording[name] = {"start": null, "end": null, "current": null, "list": {}, "lastUsed": null}
	recording["Recording"] = {"start": null, "end": null, "current": null, "list": {}, "lastUsed": null}
	recording["Current Time"] = {"start": null, "end": null, "current": null, "list": {}, "lastUsed": null}

	# Process signal_data per-frame. 0 marks end of a frame.
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()

	var frame_index := 0                 # how many frames we've processed (time = frame_index / FRAME_RATE)
	var current_frame_ids := []          # temporary list of non-zero ids seen in this frame
	var prev_state := {}                 # name -> bool (previous frame)
	for id_key in id_to_name.keys():
		prev_state[id_to_name[id_key]] = false

	var total_samples := int(self.signal_data.size())
	for i in range(total_samples):
		var v := int(self.signal_data[i])

		if v == 0:
			# FRAME BOUNDARY: determine new_state for this frame from current_frame_ids
			var new_state := {}
			# initialize all as false
			for id_key in id_to_name.keys():
				new_state[id_to_name[id_key]] = false
			# mark seen ids true (ignore unknown ids)
			for seen_id in current_frame_ids:
				if id_to_name.has(seen_id):
					new_state[id_to_name[seen_id]] = true
				else:
					if not _unknown_id_cache.has(seen_id):
						_unknown_id_cache[seen_id] = true
						push_warning("Unknown ID in signal_data (frame %d): %d — no mapping in chart '%s' — ignoring." % [frame_index, seen_id, chart_name])

			# time in seconds for this frame
			var t := float(frame_index) / FRAME_RATE

			# Compare new_state to prev_state and only add events where the boolean changed
			for name_key in new_state.keys():
				var prev_val = prev_state.get(name_key, false)
				var new_val = new_state[name_key]
				if prev_val == new_val:
					continue # no change — nothing to record

				# create event id
				var ev_id := "ID_%d" % rng.randi()
				recording[name_key]["list"][ev_id] = {
					"value": new_val,
					"time": t,
					"back": recording[name_key]["end"],
					"forward": null
				}
				# link prev end -> this
				if recording[name_key]["end"] != null:
					recording[name_key]["list"][recording[name_key]["end"]]["forward"] = ev_id
				# set start if first event
				if recording[name_key]["start"] == null:
					recording[name_key]["start"] = ev_id
				# always set end to newest
				recording[name_key]["end"] = ev_id

			# move to next frame
			prev_state = new_state.duplicate(true)
			current_frame_ids.clear()
			frame_index += 1
		else:
			# accumulate non-zero IDs seen during the frame
			# avoid duplicates inside same frame
			if not current_frame_ids.has(v):
				current_frame_ids.append(v)

	# Finished scanning samples — if there's leftover data in current_frame_ids, process it as a final frame
	if current_frame_ids.size() > 0:
		var new_state := {}
		for id_key in id_to_name.keys():
			new_state[id_to_name[id_key]] = false
		for seen_id in current_frame_ids:
			if id_to_name.has(seen_id):
				new_state[id_to_name[seen_id]] = true
			else:
				if not _unknown_id_cache.has(seen_id):
					_unknown_id_cache[seen_id] = true
					push_warning("Unknown ID in signal_data (final frame): %d — no mapping in chart '%s' — ignoring." % [seen_id, chart_name])

		var t := float(frame_index) / FRAME_RATE
		for name_key in new_state.keys():
			var prev_val = prev_state.get(name_key, false)
			var new_val = new_state[name_key]
			if prev_val == new_val:
				continue
			var ev_id := "ID_%d" % rng.randi()
			recording[name_key]["list"][ev_id] = {
				"value": new_val,
				"time": t,
				"back": recording[name_key]["end"],
				"forward": null
			}
			if recording[name_key]["end"] != null:
				recording[name_key]["list"][recording[name_key]["end"]]["forward"] = ev_id
			if recording[name_key]["start"] == null:
				recording[name_key]["start"] = ev_id
			recording[name_key]["end"] = ev_id
		# no increment of frame_index needed here (end of data)

	# Ensure every active signal is closed at EOF by writing a false event at EOF time if needed
	var eof_time := float(frame_index) / FRAME_RATE
	for name_key in recording.keys():
		# skip meta rows
		if name_key == "Recording" or name_key == "Current Time":
			continue
		var last_end = recording[name_key]["end"]
		if last_end != null:
			# find last event's value — if it's true we must append a false event at EOF
			var last_ev = recording[name_key]["list"][last_end]
			if last_ev and last_ev.has("value") and last_ev["value"] == true:
				var end_id := "ID_%d" % rng.randi()
				recording[name_key]["list"][end_id] = {
					"value": false,
					"time": eof_time,
					"back": recording[name_key]["end"],
					"forward": null
				}
				# link previous end forward -> this
				recording[name_key]["list"][recording[name_key]["end"]]["forward"] = end_id
				if recording[name_key]["start"] == null:
					recording[name_key]["start"] = end_id
				recording[name_key]["end"] = end_id

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
	var name_array = in_path.get_file().split('.')
	cfg.set_value("meta", "save_name", name_array[0])
	cfg.set_value("meta", "author", "Converted in Give Life")
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
# Helper: read .xshw file (binary format)
# -------------------------
func _read_shw(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open file: " + path)
		return false

	# Ensure file is reasonably large
	var file_len = f.get_length()
	if file_len < 0xDD:
		push_error("File too small/invalid .xshw: " + path)
		f.close()
		return false

	# Skip header (0xDD bytes)
	f.seek(0)
	var _header_bytes: PackedByteArray = f.get_buffer(0xDD)

	# Next: 4-byte wav length (little-endian) and 1-byte marker
	var wav_length := int(f.get_32())
	var marker := int(f.get_8())
	# read audioData
	var audio_buf: PackedByteArray = f.get_buffer(wav_length)
	# skip next 5 bytes (pattern)
	var _skip: PackedByteArray = f.get_buffer(5)
	# next: signalfilesamples (4 bytes) and 1-byte marker
	var signalfilesamples := int(f.get_32())
	var _marker2 := int(f.get_8())
	# read signalfilesamples integers (4 bytes each)
	var signal_list := PackedInt32Array()
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
	
func convert_file_with_prompt(chart_name: String) -> void:
	if BIT_CHARTS == {}:
		load_bit_charts()
	
	if not BIT_CHARTS.has(chart_name):
		push_error("Chart not loaded: %s. Call load_bit_charts(mod_name) first." % chart_name)
		return
	
	var file_dialog := FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.* ; All Files"]  # all files
	file_dialog.title = "Select a .shw file"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE

	# Handle file selected
	file_dialog.file_selected.connect(func(path: String):
		file_dialog.queue_free()
		var workspace_id = convert_file(path, chart_name)
		if workspace_id != "":
			print("Conversion finished with workspace ID:", workspace_id)
		else:
			print("Conversion failed.")
		get_tree().call_group("Node Map", "populate_workspace_options")
		self.queue_free()
	)

	# Handle cancel
	file_dialog.canceled.connect(func():
		self.queue_free()
	)

	add_child(file_dialog)
	file_dialog.popup_centered_ratio()
