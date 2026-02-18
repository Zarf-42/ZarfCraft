extends Control

# Experiment to create a procedural reticle. I hope to have a central dot and a circle surrounding it,
# where the circle gets larger as you move to imply less precision. Or maybe larger as you look at
# more distant things.

@export var inner_circle_radius: float = 4 
@export var outer_circle_radius: float = 20
@export var outer_circle_width: float = 6
@export var color: Color = Color.WHITE
@export var border_color: Color = Color.BLACK
@onready var center_position = Vector2.ZERO

func _ready():
	queue_redraw()

func _draw():
	# Draw the outer circle
	draw_circle(center_position, outer_circle_radius, border_color, false, outer_circle_width+2, true) # Outer Circle Border
	draw_circle(center_position, outer_circle_radius, color, false, outer_circle_width, true) # Outer Circle
	
	# Draw the inner dot
	draw_circle(center_position, inner_circle_radius, border_color, true, 0, true) # Inner Dot Border
	draw_circle(center_position, inner_circle_radius-1.2, color, true, 0, true) # Inner Dot
