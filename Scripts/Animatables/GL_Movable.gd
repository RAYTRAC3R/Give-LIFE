extends GL_Animatable

var initialPos: Vector3
var initialRot: Vector3
var initialScale: Vector3

func _ready():
	initialPos = position
	initialRot = rotation
	initialScale = scale

func _sent_signals(anim_name: String, value: float):

	match(anim_name):
		"Position X":
			position.x = initialPos.x + value
		"Position Y":
			position.y = initialPos.y + value
		"Position Z":
			position.z = initialPos.z + value
		"Rotation X":
			rotation.x = initialRot.x + value
		"Rotation Y":
			rotation.y = initialRot.y + value
		"Rotation Z":
			rotation.z = initialRot.z + value
		"Scale X":
			scale.x = initialScale.x + value
		"Scale Y":
			scale.y = initialScale.y + value
		"Scale Z":
			scale.z = initialScale.z + value
