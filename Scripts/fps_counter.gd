extends Label

func _process(delta: float) -> void:
	set_text("FPS: " + str(roundi(Engine.get_frames_per_second())))
