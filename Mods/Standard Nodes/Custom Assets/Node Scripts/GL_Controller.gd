extends GL_Node

# Map display name -> input action
var button_map := {
	"A": "controller_a",
	"B": "controller_b",
	"X": "controller_x",
	"Y": "controller_y",
	"LB": "controller_lb",
	"RB": "controller_rb",
	"Back": "controller_back",
	"Left Stick Press": "controller_ls",
	"Right Stick Press": "controller_rs",
	"DPad Up": "controller_dpad_up",
	"DPad Down": "controller_dpad_down",
	"DPad Left": "controller_dpad_left",
	"DPad Right": "controller_dpad_right"
}

func _ready():
	super._ready()
	_set_title("Controller")

	# Left stick separated axes
	_create_row("Left Stick Left", null, 0.0, false, 0.0, 0)
	_create_row("Left Stick Right", null, 0.0, false, 0.0, 0)
	_create_row("Left Stick Up", null, 0.0, false, 0.0, 0)
	_create_row("Left Stick Down", null, 0.0, false, 0.0, 0)

	# Right stick separated axes
	_create_row("Right Stick Left", null, 0.0, false, 0.0, 0)
	_create_row("Right Stick Right", null, 0.0, false, 0.0, 0)
	_create_row("Right Stick Up", null, 0.0, false, 0.0, 0)
	_create_row("Right Stick Down", null, 0.0, false, 0.0, 0)

	# Triggers (float, 0.0 to 1.0)
	_create_row("Trigger Left", null, 0.0, false, 0.0, 0)
	_create_row("Trigger Right", null, 0.0, false, 0.0, 0)

	# Buttons (bool)
	for label in button_map.keys():
		_create_row(label, null, false, false, false, 0)

	_update_visuals()

func _process(delta):
	super._process(delta)

	# ==== LEFT STICK ====
	var lx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ly := -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y) # invert Y so up is positive

	rows["Left Stick Left"]["output"] = max(-lx, 0.0)
	rows["Left Stick Right"]["output"] = max(lx, 0.0)
	rows["Left Stick Up"]["output"] = max(ly, 0.0)
	rows["Left Stick Down"]["output"] = max(-ly, 0.0)

	# ==== RIGHT STICK ====
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := -Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)

	rows["Right Stick Left"]["output"] = max(-rx, 0.0)
	rows["Right Stick Right"]["output"] = max(rx, 0.0)
	rows["Right Stick Up"]["output"] = max(ry, 0.0)
	rows["Right Stick Down"]["output"] = max(-ry, 0.0)

	# ==== TRIGGERS ====
	var tl_raw := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	var tr_raw := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	rows["Trigger Left"]["output"] = clamp(tl_raw, 0.0, 1.0)
	rows["Trigger Right"]["output"] = clamp(tr_raw, 0.0, 1.0)

	# ==== BUTTONS ====
	for label in button_map.keys():
		rows[label]["output"] = Input.is_action_pressed(button_map[label])

	# ==== Send outputs ====
	for key in rows.keys():
		_send_input(key)
