extends Control

var nodePaths: Dictionary = {}  # name (from filename) -> full scene path
var searching: bool

func _ready():
	_set_State(false)
	_scan_mod_nodes()
	_set_rows()

func toggleSearch():
	_set_State(!searching)

func _set_State(state: bool):
	searching = state
	visible = searching

func _scan_mod_nodes():
	nodePaths.clear()
	var mods_dir = DirAccess.open("res://Mods")
	if not mods_dir:
		push_error("Mods folder not found.")
		return

	mods_dir.list_dir_begin()
	var mod_name = mods_dir.get_next()
	while mod_name != "":
		if mods_dir.current_is_dir() and mod_name != "." and mod_name != "..":
			var node_path = "res://Mods/%s/Mod Directory/Nodes" % mod_name
			if DirAccess.dir_exists_absolute(node_path):
				var nodes_dir = DirAccess.open(node_path)
				nodes_dir.list_dir_begin()
				var file_name = nodes_dir.get_next()
				while file_name != "":
					if file_name.ends_with(".tscn"):
						var name = file_name.get_basename()  # Strip extension
						var full_path = "%s/%s" % [node_path, file_name]
						nodePaths[name] = full_path
					file_name = nodes_dir.get_next()
		mod_name = mods_dir.get_next()

func _set_rows():
	var container = get_node("Panel/ScrollContainer/Container")
	for child in container.get_children():
		child.queue_free()

	var sorted_keys = nodePaths.keys()
	sorted_keys.sort() 

	for name in sorted_keys:
		var row = load("res://Scenes/UI/Search Row.tscn").instantiate()
		var button = row.get_node("Button") as Button
		button.text = name
		button.pressed.connect(func():
			_create_node(name)
		)
		button.pressed.connect(func():
			_set_State(false)
		)
		container.call_deferred("add_child", row)


func _create_node(name: String):
	if not nodePaths.has(name):
		push_error("Node type not found: " + name)
		return
	var path = nodePaths[name]
	var node = load(path).instantiate()
	var holder = get_parent().get_node("Holder")
	holder.add_child(node)
	node = (node as Control).get_child(0) as GL_Node
	node.nodePath = path
	node.global_position = (get_viewport().size / 2.0) - (node.get_child(0).size / 2.0)
	node._create_uuid()
