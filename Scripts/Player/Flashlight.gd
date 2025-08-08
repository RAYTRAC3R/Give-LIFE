extends SpotLight3D

var size: float = 45
var targetSize: float = 45
const maxSize = 60
const minSize = 5
const minLight = 3
const maxLight = 80

const HOLD_THRESHOLD := 0.2

var flashlight_held_time := 0.0
var is_adjusting := false
var was_flashlight_pressed := false

func _process(delta):
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	# Handle flashlight toggle / adjust mode
	if Input.is_action_pressed("Flashlight"):
		flashlight_held_time += delta
		if flashlight_held_time >= HOLD_THRESHOLD:
			is_adjusting = true
			if not visible:
				visible = true
	else:
		if was_flashlight_pressed:
			if flashlight_held_time < HOLD_THRESHOLD:
				visible = !visible
		flashlight_held_time = 0.0
		is_adjusting = false

	was_flashlight_pressed = Input.is_action_pressed("Flashlight")

	# Adjust size if in adjust mode
	if is_adjusting:
		if Input.is_action_pressed("Scroll Up") or Input.is_action_just_pressed("Scroll Up (Mouse)"):
			targetSize = clamp(targetSize + 5, minSize, maxSize)
		elif Input.is_action_pressed("Scroll Down") or Input.is_action_just_pressed("Scroll Down (Mouse)"):
			targetSize = clamp(targetSize - 5, minSize, maxSize)

	# Smoothly interpolate size and update light properties
	size = lerp(size, targetSize, delta * 2)
	spot_angle = size
	light_energy = clamp(maxSize - size, minLight, maxLight)
