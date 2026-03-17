extends Node

var theme: Theme = preload("res://ui/zarfcraft_ui_theme.tres")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Any time the window size changes, this signal fires and calls _on_viewport_size_changed.
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	var viewport = get_tree().root.get_visible_rect().size
	
	# This makes it work better for screens of differing aspect ratios, including tall ones
	var scale_base = min(viewport.x, viewport.y)
	
	# Button styling
	theme.set_font_size("font_size", "Button", int(scale_base * 0.03))
	
	# Vertical Distance between buttons
	theme.set_constant("separation", "VBoxContainer", int(viewport.y * 0.01))
	
	# Title
	theme.set_font_size("font_size", "HeaderLarge", int(scale_base * .07))
	
	# All other Labels
	theme.set_font_size("font_size", "Label", int(scale_base * 0.025))
	
	# Default font size for everything else
	theme.default_font_size = int(scale_base * 0.025)

func resize_button_container(container: VBoxContainer) -> void:
	var viewport = get_tree().root.get_visible_rect().size
	container.custom_minimum_size.x = viewport.x *.20
	for button in container.get_children():
		if button is Button: # Do this to ensure you're only matching buttons, and not something else
			# you might put inside the container later when you forget
			button.custom_minimum_size.y = viewport.y *.03
