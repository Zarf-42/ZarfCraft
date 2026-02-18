extends Label

func _process(delta: float):
	text = "FPS: %s" % [Engine.get_frames_per_second()]
