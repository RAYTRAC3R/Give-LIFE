extends Control

@export var toggle_button: Button   # Assign in the editor
var actions: Dictionary = {}  # displayname -> dictionary of action data
var searching: bool

func _ready():
	_set_state(false)
	_scan_mod_actions()
	_set_rows()

func toggle_search():
	_set_state(!searching)

func _set_state(state: bool):
	searching = state
	visible = searching

func _scan_mod_actions():
	actions.clear()
	var mods_dir = DirAccess.open("res://Mods")
	if not mods_dir:
		push_error("Mods folder not found.")
		return

	mods_dir.list_dir_begin()
	var mod_name = mods_dir.get_next()
	while mod_name != "":
		if mods_dir.current_is_dir() and mod_name != "." and mod_name != "..":
			var actions_path = "res://Mods/%s/Mod Directory/Actions.json" % mod_name
			if FileAccess.file_exists(actions_path):
				var file = FileAccess.open(actions_path, FileAccess.READ)
				if file:
					var json_text = file.get_as_text()
					file.close()
					var result = JSON.parse_string(json_text)
					if typeof(result) == TYPE_ARRAY:
						for action_dict in result:
							if typeof(action_dict) == TYPE_DICTIONARY and action_dict.has("displayname"):
								var displayname = str(action_dict["displayname"])
								actions[displayname] = action_dict
		mod_name = mods_dir.get_next()

	# Hide button if no actions found
	if toggle_button:
		toggle_button.visible = actions.size() > 0

func _set_rows():
	var container = get_node("Panel/MarginContainer/ScrollContainer/Container")
	for child in container.get_children():
		child.queue_free()

	var sorted_keys = actions.keys()
	sorted_keys.sort()

	for displayname in sorted_keys:
		var row = load("res://Scenes/UI/Search Row.tscn").instantiate()
		var button = row.get_node("Button") as Button
		button.text = displayname
		button.pressed.connect(func():
			_run_action(displayname)
		)
		button.pressed.connect(func():
			_set_state(false)
		)
		container.call_deferred("add_child", row)
func _run_action(displayname: String):
	if not actions.has(displayname):
		push_error("Action not found: " + displayname)
		return

	var action_data = actions[displayname]
	if not action_data.has("script") or not action_data.has("function"):
		push_warning("Invalid action data for: " + displayname)
		return

	var script_path: String = str(action_data["script"])
	var func_name: String = str(action_data["function"])
	var parameter = action_data.get("parameter", null)

	if not ResourceLoader.exists(script_path):
		push_error("Script not found: " + script_path)
		return

	var script_resource = ResourceLoader.load(script_path)
	if not script_resource:
		push_error("Failed to load script: " + script_path)
		return

	# Create a Node and attach the script
	var temp_node := Node.new()
	temp_node.set_script(script_resource)
	add_child(temp_node)  # Needed if the script expects to be in the tree

	# Call the action function if it exists
	if temp_node.has_method(func_name):
		temp_node.call(func_name, parameter)
	else:
		push_warning("Function '%s' not found in script %s" % [func_name, script_path])
	
