extends GL_Node

var last_input := false

func _ready():
	super._ready()
	_set_title("Toggle")
	_create_row("Value", false, false, false, 0, 0)  # Bool input
	_update_visuals()

func _process(delta):
	super._process(delta)
	apply_pick_values()

	var current_input = rows["Value"]["input"]

	if current_input and not last_input:
		rows["Value"]["output"] = !rows["Value"]["output"]

	last_input = current_input

	_send_input("Value")
