extends Node3D

# Following this tutorial: https://www.youtube.com/watch?v=_uGtO7sk-_c

# This is used to determine the size of the world in meters, if Infinite World Generation isn't 
# turned on. If it is on, we need to ignore this.
@export var world_size: Vector3 = Vector3(16, 16, 16)
# Cutoff defines how dense the random cubes are. Higher numbers equate to less density.
@export var cutoff: float = 0.5

# This references a node that exists in the World scene; once we procedurally generate cubes, we should
# delete that node and this variable.
@onready var default_cube: CSGBox3D = $DefaultCube


func _ready():
	generate_terrain_finite()

func generate_terrain_finite():
	var random_generator = RandomNumberGenerator.new()
	
	for x in range(world_size.x):
		for y in range(world_size.y):
			for z in range(world_size.z):
				# Generates a number between 0.0 and 1.0.
				var random = random_generator.randf()
				# If that random number is greater than cutoff (defined in the header), place a cube.
				if random > cutoff:
					# Duplicate that default cube and get ready to move it to the position we just checked.
					var new_cube = default_cube.duplicate()
					new_cube.position = Vector3(x, y, z)
					add_child(new_cube)
	remove_child(default_cube)
