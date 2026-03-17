extends Label

func _process(_delta: float):
	text = "FPS: %s" % [Engine.get_frames_per_second()]
