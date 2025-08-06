extends Node

var versionNumber: Label

var usernameLineEdit: LineEdit
var showPressedKeysButton: CheckButton
var bootOnStartOptions: OptionButton
var windowModeOptions: OptionButton
var msaaOptions: OptionButton
var volumeSlider: Slider
var physicsbonesButton: CheckButton

var simulatorButton: Button

var titleScreenMenu: VBoxContainer
var settingsMenu: MarginContainer
var modMenu: MarginContainer
var mapMenu: MarginContainer

var sideTitle       : Label
var sideAuthor      : Label
var sideDescription : Label
var sideThumbnail   : TextureRect
var sideExportBtn   : Button
var sideDeleteBtn   : Button
var sideBackBtn     : Button

var mapListContainer: VBoxContainer
var mapEntryScene: PackedScene
var availableMaps := {}  # mapName -> scene path
var currentMapInstance: Node = null


var currentSettings := {
	"window_mode": 0,
	"boot_on_start": 0,
	"show_key_presses": false,
	"username": "Unknown Author",
	"master_volume": 100,
	"physics_bones": true,
	"msaa_3d": Viewport.MSAA_2X,
	"recent_map": "",
}

var modListContainer: VBoxContainer
var modEntryScene: PackedScene
var importModDialog: FileDialog
var exportModDialog: FileDialog
var modData := {}
var exportFile:String

const settingsPath := "user://Settings/"
const settingsFilePath := settingsPath + "user_settings.cfg"

var editorInstance: Node = null
var keypressInstance: Node = null
var nodeMapScene: PackedScene
var keypresssScene: PackedScene

func _ready():
	
	# Setup mod‐menu
	modListContainer = get_node("MarginContainer/PanelContainer/Mod Menu/Mods/PanelContainer/HBoxContainer/VBoxContainer/ScrollContainer/Mod Holder")
	modEntryScene    = load("res://Scenes/UI/Mod Box.tscn")
	importModDialog  = get_node("ImportDialog")
	exportModDialog  = get_node("ExportDialog")

	# Ensure user mods folder exists
	DirAccess.make_dir_recursive_absolute("user://mods")

	# 1) Load any .pck in user://mods into res://Mods
	_load_user_pcks()
	# 2) Scan all Mods/… and populate menu
	_load_mods()
	_populate_mod_list()

	nodeMapScene = load("res://Scenes/UI/Node Map.tscn")
	keypresssScene = load("res://Scenes/UI/Key Presses.tscn")

	mapListContainer = get_node("MarginContainer/PanelContainer/Map Menu/Mods/PanelContainer/VBoxContainer/ScrollContainer/Map Holder") 
	mapEntryScene = load("res://Scenes/UI/Map Box.tscn")
	load_maps()

	editorInstance = nodeMapScene.instantiate()
	get_tree().root.add_child.call_deferred(editorInstance)
	keypressInstance = keypresssScene.instantiate()
	get_tree().root.add_child.call_deferred(keypressInstance)
	await editorInstance.ready
	await keypressInstance.ready
	versionNumber = get_node("MarginContainer/PanelContainer/Version Number")
	titleScreenMenu = get_node("MarginContainer/PanelContainer/Title Screen")
	settingsMenu = get_node("MarginContainer/PanelContainer/Settings")
	modMenu = get_node("MarginContainer/PanelContainer/Mod Menu")
	mapMenu = get_node("MarginContainer/PanelContainer/Map Menu")
	usernameLineEdit = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/General/VBoxContainer/Username/LineEdit")
	showPressedKeysButton = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/General/VBoxContainer/Show Pressed Keys/CheckButton")
	bootOnStartOptions = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/General/VBoxContainer/Boot on Start/OptionButton")
	windowModeOptions = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/Graphical/VBoxContainer/Window Mode/OptionButton")
	msaaOptions = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/Graphical/VBoxContainer/Anti-Aliasing/OptionButton")
	volumeSlider = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/Audio/VBoxContainer/Master Volume/HSlider")
	simulatorButton = get_node("MarginContainer/PanelContainer/Title Screen/Start Button")
	physicsbonesButton = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/Graphical/VBoxContainer/Physics Bones/CheckButton")
	versionNumber.text = "v" + ProjectSettings.get_setting("application/config/version")
	sideTitle       = get_node("MarginContainer/PanelContainer/Mod Menu/Mods/PanelContainer/HBoxContainer/MarginContainer/Mod Desc/MarginContainer/VBoxContainer/Mod Title")
	sideAuthor      = get_node("MarginContainer/PanelContainer/Mod Menu/Mods/PanelContainer/HBoxContainer/MarginContainer/Mod Desc/MarginContainer/VBoxContainer/Mod Author")
	sideDescription = get_node("MarginContainer/PanelContainer/Mod Menu/Mods/PanelContainer/HBoxContainer/MarginContainer/Mod Desc/MarginContainer/VBoxContainer/ScrollContainer/Mod Author2")
	sideThumbnail   = get_node("MarginContainer/PanelContainer/Mod Menu/Mods/PanelContainer/HBoxContainer/MarginContainer/Mod Desc/MarginContainer/VBoxContainer/TextureRect")
	sideExportBtn   = get_node("MarginContainer/PanelContainer/Mod Menu/Mods/PanelContainer/HBoxContainer/MarginContainer/Mod Desc/MarginContainer/VBoxContainer/HBoxContainer/Export")
	sideDeleteBtn   = get_node("MarginContainer/PanelContainer/Mod Menu/Mods/PanelContainer/HBoxContainer/MarginContainer/Mod Desc/MarginContainer/VBoxContainer/HBoxContainer/Delete")
	sideBackBtn     = get_node("MarginContainer/PanelContainer/Mod Menu/Mods/Back Button")
	hide_sidebar()
	
	load_settings()
	apply_settings()

	# Apply boot on start options
	match currentSettings["boot_on_start"]:
		1:
			var map_name = currentSettings.get("recent_map", "")
			if map_name != "" and availableMaps.has(map_name):
				load_map_scene(map_name)
			else:
				print("No recent map to load or map not found.")
		2:
			self.visible = false
			editorInstance.visible = true

func _unhandled_input(event):	
	if currentMapInstance == null:
		if event.is_action_pressed("Pause") or event.is_action_pressed("Editor"):
			editorInstance.visible = !editorInstance.visible
			self.visible = !editorInstance.visible
	else:
		if event.is_action_pressed("Pause"):
			toggle_pause_menu()
		elif event.is_action_pressed("Editor"):
			toggle_editor()

func switchMenu(menu:String):
	titleScreenMenu.visible = false
	settingsMenu.visible = false
	mapMenu.visible = false
	modMenu.visible = false
	hide_sidebar()

	match(menu):
		"title":
			titleScreenMenu.visible =  true
		"settings":
			settingsMenu.visible =  true
		"mods":
			modMenu.visible =  true
		"maps":
			mapMenu.visible =  true

func _on_slider_changed(value:float, name:String):
	currentSettings[name] = value
	save_settings()
	apply_settings()

func _on_button_changed(value:bool, name:String):
	currentSettings[name] = value
	save_settings()
	apply_settings()

func _on_option_changed(value:int, name:String):
	currentSettings[name] = value
	save_settings()
	apply_settings()
	
func _on_line_edit_changed(value:String, name:String):
	currentSettings[name] = value
	save_settings()
	apply_settings()

func save_settings():
	DirAccess.make_dir_recursive_absolute(settingsPath)
	var config := ConfigFile.new()

	for key in currentSettings.keys():
		config.set_value("settings", key, currentSettings[key])

	var err = config.save(settingsFilePath)
	if err != OK:
		push_error("Failed to save settings: " + str(err))
	else:
		print("Settings saved to: ", settingsFilePath)

func load_settings():
	var config := ConfigFile.new()
	var err := config.load(settingsFilePath)

	if err != OK:
		print("No existing settings file found, using defaults.")
		return

	for key in currentSettings.keys():
		if config.has_section_key("settings", key):
			currentSettings[key] = config.get_value("settings", key)

	print("Settings loaded: ", currentSettings)

func apply_settings():
	#Window Mode
	if currentSettings["window_mode"] == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	if usernameLineEdit.text != currentSettings["username"]:
		usernameLineEdit.text = currentSettings["username"]
	bootOnStartOptions.selected = currentSettings["boot_on_start"]
	windowModeOptions.selected = currentSettings["window_mode"]
	msaaOptions.selected = currentSettings["msaa_3d"]
	volumeSlider.set_value_no_signal(currentSettings["master_volume"])
	showPressedKeysButton.set_pressed_no_signal(currentSettings["show_key_presses"])
	physicsbonesButton.set_pressed_no_signal(currentSettings["physics_bones"])
	var vp = get_tree().root
	vp.msaa_3d = currentSettings["msaa_3d"]
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(currentSettings["master_volume"]))
	
	get_tree().call_group("SettingsReceivers", "on_settings_applied", currentSettings)

func update_simulator_button_text():
	if currentMapInstance:
		simulatorButton.text = "Unload Map"
	else:
		simulatorButton.text = "Map List"

func _on_simulator_button_pressed():
	if currentMapInstance:
		unload_current_map()
	else:
		switchMenu("maps")

func toggle_pause_menu():
	var will_show = not self.visible
	self.visible = will_show
	if will_show:
		editorInstance.visible = false
	update_mouse_mode()

func toggle_editor():
	var will_show = not editorInstance.visible
	editorInstance.visible = will_show
	if will_show:
		self.visible = false
	update_mouse_mode()

func update_mouse_mode():
	if not self.visible and not editorInstance.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_quit_button_pressed():
	get_tree().quit()

func load_maps():
	availableMaps.clear()
	for child in mapListContainer.get_children():
		child.queuefree()

	var mods_dir := DirAccess.open("res://Mods")
	if mods_dir == null:
		push_error("Mods directory not found!")
		return

	mods_dir.list_dir_begin()
	var mod_name = mods_dir.get_next()
	while mod_name != "":
		if mods_dir.current_is_dir() and mod_name != "." and mod_name != "..":
			var map_dir_path = "res://Mods/%s/Mod Directory/Maps" % mod_name
			var maps_dir := DirAccess.open(map_dir_path)
			if maps_dir:
				maps_dir.list_dir_begin()
				var map_folder = maps_dir.get_next()
				while map_folder != "":
					if maps_dir.current_is_dir() and map_folder != "." and map_folder != "..":
						var full_map_path = "%s/%s" % [map_dir_path, map_folder]
						var map_info_path = full_map_path + "/Map Info.cfg"
						var icon_path = full_map_path + "/Map Icon.png"
						
						var config := ConfigFile.new()
						if config.load(map_info_path) == OK and ResourceLoader.exists(icon_path):
							var map_name = config.get_value("map", "maptitle", map_folder)

							# Find first .tscn file
							var inner_dir := DirAccess.open(full_map_path)
							var scene_path := ""
							if inner_dir:
								inner_dir.list_dir_begin()
								var f = inner_dir.get_next()
								while f != "":
									if f.ends_with(".tscn"):
										scene_path = "%s/%s" % [full_map_path, f]
										break
									f = inner_dir.get_next()
							
							if scene_path != "":
								availableMaps[map_name] = scene_path

								# Create and setup prefab
								var entry = mapEntryScene.instantiate()
								entry.get_node("PanelContainer/HBoxContainer/Name").text = map_name
								entry.get_node("PanelContainer/HBoxContainer/PanelContainer/Icon").texture = load(icon_path)

								var load_button = entry.get_node("PanelContainer/Button")
								load_button.pressed.connect(load_map_scene.bind(map_name))

								mapListContainer.add_child(entry)
					map_folder = maps_dir.get_next()
		mod_name = mods_dir.get_next()

func load_map_scene(map_name: String):
	if availableMaps.has(map_name):
		var path = availableMaps[map_name]
		var scene = load(path)
		if scene:
			if currentMapInstance:
				currentMapInstance.queue_free()
			currentMapInstance = scene.instantiate()
			get_tree().root.add_child(currentMapInstance)

			self.visible = false
			editorInstance.visible = false
			update_mouse_mode()
			update_simulator_button_text()
			switchMenu("title")
			currentSettings["recent_map"] = map_name
			save_settings()
			apply_settings()
	else:
		push_error("Map not found or not available: " + map_name)

func unload_current_map():
	if currentMapInstance:
		currentMapInstance.queue_free()
		currentMapInstance = null
		self.visible = true
		update_mouse_mode()
		update_simulator_button_text()

func _load_user_pcks():
	var user_dir = DirAccess.open("user://mods")
	user_dir.list_dir_begin()
	var fname = user_dir.get_next()
	while fname != "":
		if not user_dir.current_is_dir() and fname.to_lower().ends_with(".pck"):
			var src = "user://mods/" + fname
			var err = ProjectSettings.load_resource_pack(src)
			if err != OK:
				push_error("Failed to load PCK: " + src)
			else:
				print("Loaded PCK mod:", fname)
		fname = user_dir.get_next()
	user_dir.list_dir_end()

func _load_mods():
	modData.clear()
	var mods_dir = DirAccess.open("res://Mods")
	if not mods_dir:
		push_error("Mods directory not found!")
		return

	mods_dir.list_dir_begin()
	var mod_name = mods_dir.get_next()
	while mod_name != "":
		if mods_dir.current_is_dir() and mod_name not in [".",".."]:
			var base = "res://Mods/%s" % mod_name
			var info_cfg = base + "/Mod Info.cfg"
			var thumb    = base + "/Mod Thumbnail.png"
			var icon     = base + "/Mod Icon.png"
			print(info_cfg)
			if FileAccess.file_exists(info_cfg):
				var cfg = ConfigFile.new()
				if cfg.load(info_cfg) == OK:
					var title = cfg.get_value("mods","modtitle",mod_name)
					var author = cfg.get_value("mods","modauthor","Unknown")
					var desc = cfg.get_value("mods","moddescription","")
					# detect if this mod came from a .pck we imported
					var pck_src = ""
					var user_dir = DirAccess.open("user://mods")
					user_dir.list_dir_begin()
					var f = user_dir.get_next()
					while f != "":
						if f.basename() == mod_name and f.to_lower().ends_with(".pck"):
							pck_src = "user://mods/" + f
							break
						f = user_dir.get_next()
					user_dir.list_dir_end()
					
					modData[mod_name] = {
						"path": base,
						"pck_source": pck_src,
						"title": title,
						"author": author,
						"description": desc,
						"thumb": thumb,
						"icon": icon,
					}
			# else: silent skip
		mod_name = mods_dir.get_next()
	mods_dir.list_dir_end()

func _populate_mod_list():
	for child in modListContainer.get_children():
		child.queue_free()
	for name in modData.keys():
		var data = modData[name]
		var entry = modEntryScene.instantiate()
		entry.get_node("PanelContainer/HBoxContainer/Title").text  = data.title
		entry.get_node("PanelContainer/HBoxContainer/PanelContainer/Icon").texture = load(data.icon)
		
		# assume the prefab has a Button named “SelectBtn”
		var select_btn = entry.get_node("Button") as Button
		select_btn.pressed.connect(func(n=name):
			_select_mod(n)
		)
		modListContainer.add_child(entry)

func _select_mod(mod_name: String):
	if not modData.has(mod_name):
		return
	var d = modData[mod_name]

	# Populate UI
	sideTitle.text       = d.title
	sideTitle.visible = true
	sideAuthor.text      = "By: " + d.author
	sideAuthor.visible = true
	sideDescription.text = d.description
	sideDescription.visible = true
	sideThumbnail.texture = load(d.thumb)
	sideThumbnail.visible = true
	
	var has_pck = d.has("pck_source") and d["pck_source"] != ""
	sideDeleteBtn.visible = has_pck
	sideExportBtn.visible = has_pck
	
	# Clear any previous signals on those buttons
	for conn in sideExportBtn.get_signal_connection_list("pressed"):
		sideExportBtn.disconnect("pressed", conn["callable"])
	for conn in sideDeleteBtn.get_signal_connection_list("pressed"):
		sideDeleteBtn.disconnect("pressed", conn["callable"])

	# Hook export
	sideExportBtn.pressed.connect(func():
		exportFile = mod_name
		exportModDialog.current_file = d.title + ".pck"
		exportModDialog.popup_centered()
	)
	# Hook delete
	sideDeleteBtn.pressed.connect(func():
		_delete_mod(mod_name)
		# repurpose back button
		sideBackBtn.text = "Restart"
		for conn in sideBackBtn.get_signal_connection_list("pressed"):
			sideBackBtn.disconnect("pressed", conn["callable"])
		sideBackBtn.pressed.connect(_restart_game)
	)

func _restart_game():
	get_tree().reload_current_scene()


func _on_import_mod_selected(path: String):
	var fn = path.get_file()
	var dest = "user://mods/" + fn
	if copy_file(path, dest) != OK:
		push_error("Failed to import mod PCK.")
		return
	_load_user_pcks()
	_load_mods()
	_populate_mod_list()


func _on_export_mod_selected(path: String):
	var mod_name = exportFile
	var src = modData[mod_name].pck_source
	if src == "":
		push_error("No PCK source recorded for mod: " + mod_name)
		return
	if copy_file(src, path) != OK:
		push_error("Failed to export PCK.")
	else:
		print("Exported", mod_name, "to", path)

func import_mod():
	importModDialog.popup_centered()

func _delete_mod(mod_name):
	var pck = modData[mod_name].pck_source
	if pck != "" and DirAccess.remove_absolute(pck) == OK:
		print("Deleted PCK for", mod_name)
	else:
		push_error("Failed to delete PCK for " + mod_name)
	_load_user_pcks()
	_load_mods()
	_populate_mod_list()

func copy_file(src: String, dest: String) -> int:
	var src_file := FileAccess.open(src, FileAccess.READ)
	if src_file == null:
		return ERR_CANT_OPEN
	var data := src_file.get_buffer(src_file.get_length())
	src_file.close()

	var dest_file := FileAccess.open(dest, FileAccess.WRITE)
	if dest_file == null:
		return ERR_CANT_CREATE
	dest_file.store_buffer(data)
	dest_file.close()

	return OK

func hide_sidebar():
	sideTitle.visible = false
	sideAuthor.visible = false
	sideDescription.visible = false
	sideThumbnail.visible = false
	sideExportBtn.visible = false
	sideDeleteBtn.visible = false
