extends Node3D

# Following this tutorial: https://www.youtube.com/watch?v=_uGtO7sk-_c

# This is used to determine the size of the world in meters, if Infinite World Generation isn't 
# turned on. If it is on, we need to ignore this.
@export var world_vector: int = 128
@export var world_size: Vector3 = Vector3(world_vector, world_vector, world_vector)
# Cutoff defines how dense the random cubes are. Higher numbers equate to less density.
@export_range(-1, 1) var cutoff: float = 0.1
@export var colors: Array[Color]

# This references a node that exists in the World scene; once we procedurally generate cubes, we should
# delete that node and this variable.
@onready var default_cube: CSGBox3D = $DefaultCube

# This is the primitive that we instance to create our terrain. I believe this supersedes the default_cube
# above, so we should be able to remove that soon.
@onready var chunk: Chunk = $Chunk

# I think this initializes the array that will later contain the coordinate of every cube in our terrain.
var terrain_data: Dictionary[Vector3, Color] = {}


func _ready():
	# Get Mouse Mode from the Settings Singleton
	Input.mouse_mode = Settings.mouse_mode
	generate_terrain_finite()

func _unhandled_input(event: InputEvent):
	# If the user presses Esc, quit immediately.
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func generate_terrain_finite():
	var random_generator = FastNoiseLite.new()
	random_generator.noise_type = FastNoiseLite.TYPE_SIMPLEX
	random_generator.frequency = 0.003
	
	#for x in range(world_size.x):
		#for z in range(world_size.z):
			#for y in range(world_size.y):
				## Generates a number between 0.0 and 1.0.
				#var random = random_generator.get_noise_3d(x, z, y)
				## If that random number is greater than cutoff (defined in the header), place a cube.
				#if random > cutoff:
					#terrain_data[Vector3(x, y, z)] = colors[y % colors.size()]
	#remove_child(default_cube)
	
	# I think this gets the number of cubes we are about to generate from above, and makes that
	# amount of memory free and available to use in our MultiMesh instancing thingy. I think the
	# GPU does this.
	chunk.generate_data(world_size.x, world_size.y, random_generator, colors)
	chunk.generate_mesh()
	#chunk.multimesh.instance_count = terrain_data.size()
	
	#for i in range(chunk.multimesh.instance_count):
		## This was not deeply explained in the tutorial. I think this actually sets the position of each
		## cube (terrain_primitive_cube) based on terrain_data[i].
		#chunk.multimesh.set_instance_transform(i, Transform3D(Basis(), terrain_data[i]))
