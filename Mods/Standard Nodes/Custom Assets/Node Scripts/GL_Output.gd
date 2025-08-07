extends GL_Node
class_name GL_Output
@export var className:String

func _ready():
	super._ready()
	load_custom_rows_from_mods(className)
	_set_title("Output")
	special_condition = "Animatable"
	_update_visuals()
