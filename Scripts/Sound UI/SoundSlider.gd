extends Node

@export var hover_sound: AudioStream
@export var hover_random_pitch_enabled: bool = true

@export var press_sound: AudioStream
@export var press_random_pitch_enabled: bool = true
@export var press_min_pitch: float = 0.95
@export var press_max_pitch: float = 1.05
var pitch_variations: Array = [1.2, 0.8, 1.0, 1.0, 1.0, 0.8, 1.0]

@export var audio_player_path: NodePath


var player_ref: AudioStreamPlayer2D
var hover_index := 0
var press_index := 0

func _ready():
	if audio_player_path != NodePath():
		player_ref = get_node(audio_player_path)
	else:
		push_error("No audio player assigned for UISoundHelperSlider.")

	if has_signal("mouse_entered"):
		connect("mouse_entered", _on_hover)
	if has_signal("focus_entered"):
		connect("focus_entered", _on_hover)
	elif has_signal("item_focused"):
		connect("item_focused", _on_hover)
	if has_signal("value_changed"):
		connect("value_changed", _on_value_changed)

func _on_hover():
	if hover_sound and player_ref:
		player_ref.stop()
		player_ref.stream = hover_sound
		var pitch = 1.0
		if hover_random_pitch_enabled and pitch_variations.size() > 0:
			pitch = _get_next_hover_pitch()
		player_ref.pitch_scale = pitch
		player_ref.play()

func _on_value_changed(value):
	if press_sound and player_ref:
		player_ref.stop()
		player_ref.stream = press_sound
		var lerped_pitch = _lerp_pitch_from_value(value)
		if press_random_pitch_enabled and pitch_variations.size() > 0:
			var pitch_variation = pitch_variations[press_index]
			press_index = (press_index + 1) % pitch_variations.size()
			player_ref.pitch_scale = lerped_pitch * pitch_variation
		else:
			player_ref.pitch_scale = lerped_pitch
		player_ref.play()

func _lerp_pitch_from_value(value: float) -> float:
	var slider_min = 0.0
	var slider_max = 1.0
	if has_method("get_min") and has_method("get_max"):
		slider_min = call("get_min")
		slider_max = call("get_max")
	var clamped_value = clamp(value, slider_min, slider_max)
	var t = 0.0
	if slider_max != slider_min:
		t = (clamped_value - slider_min) / (slider_max - slider_min)
	return lerp(press_min_pitch, press_max_pitch, t)

func _get_next_hover_pitch() -> float:
	var pitch = pitch_variations[hover_index]
	hover_index = (hover_index + 1) % pitch_variations.size()
	return pitch
