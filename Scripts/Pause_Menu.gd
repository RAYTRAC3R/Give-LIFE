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

var currentSettings := {
	"window_mode": 0,
	"boot_on_start": 0,
	"show_key_presses": false,
	"username": "Unknown Author",
	"master_volume": 100,
	"physics_bones": true,
	"msaa_3d": Viewport.MSAA_2X,
}

const settingsPath := "user://Settings/"
const settingsFilePath := settingsPath + "user_settings.cfg"

var editorInstance: Node = null
var keypressInstance: Node = null
var nodeMapScene: PackedScene
var simulatorScene: PackedScene
var keypresssScene: PackedScene
var simulatorInstance: Node = null

func _ready():
	nodeMapScene = load("res://Scenes/UI/Node Map.tscn")
	simulatorScene = load("res://Scenes/Levels/FDs.tscn")
	keypresssScene = load("res://Scenes/UI/Key Presses.tscn")

	editorInstance = nodeMapScene.instantiate()
	get_tree().root.add_child.call_deferred(editorInstance)
	keypressInstance = keypresssScene.instantiate()
	get_tree().root.add_child.call_deferred(keypressInstance)
	await editorInstance.ready
	await keypressInstance.ready
	versionNumber = get_node("MarginContainer/PanelContainer/Version Number")
	titleScreenMenu = get_node("MarginContainer/PanelContainer/Title Screen")
	settingsMenu = get_node("MarginContainer/PanelContainer/Settings")
	usernameLineEdit = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/General/VBoxContainer/Username/LineEdit")
	showPressedKeysButton = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/General/VBoxContainer/Show Pressed Keys/CheckButton")
	bootOnStartOptions = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/General/VBoxContainer/Boot on Start/OptionButton")
	windowModeOptions = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/Graphical/VBoxContainer/Window Mode/OptionButton")
	msaaOptions = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/Graphical/VBoxContainer/Anti-Aliasing/OptionButton")
	volumeSlider = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/Audio/VBoxContainer/Master Volume/HSlider")
	simulatorButton = get_node("MarginContainer/PanelContainer/Title Screen/Start Button")
	physicsbonesButton = get_node("MarginContainer/PanelContainer/Settings/Settings/TabContainer/Graphical/VBoxContainer/Physics Bones/CheckButton")
	versionNumber.text = "v" + ProjectSettings.get_setting("application/config/version")

	load_settings()
	apply_settings()

	# Apply boot on start options
	match currentSettings["boot_on_start"]:
		1:
			load_simulator()
		2:
			self.visible = false
			editorInstance.visible = true

	update_simulator_button_text()

func _unhandled_input(event):	
	if simulatorInstance == null:	
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
	
	match(menu):
		"title":
			titleScreenMenu.visible =  true
		"settings":
			settingsMenu.visible =  true

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

func load_simulator():
	if simulatorInstance == null:
		simulatorInstance = simulatorScene.instantiate()
		self.visible = false
		editorInstance.visible = false
		update_simulator_button_text()
		get_tree().root.add_child.call_deferred(simulatorInstance)
		await simulatorInstance.ready
		update_mouse_mode()
		apply_settings()

func unload_simulator():
	if simulatorInstance != null:
		simulatorInstance.queue_free()
		simulatorInstance = null

		self.visible = true
		update_mouse_mode()
		update_simulator_button_text()

func is_simulator_loaded() -> bool:
	return simulatorInstance != null

func update_simulator_button_text():
	if is_simulator_loaded():
		simulatorButton.text = "Unload Simulator"
	else:
		simulatorButton.text = "Boot Simulator"

func _on_simulator_button_pressed():
	if is_simulator_loaded():
		unload_simulator()
	else:
		load_simulator()

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
