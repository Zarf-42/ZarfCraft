class_name ChunkManagher extends Node

# This determines if we use infinite word generation size or finite.
@export var finite_world: bool = true
# This is used to determine the size of the world in meters, if Infinite World Generation isn't 
# turned on.
@export var world_vector: int = 128
@export var chunk_size: int = 32
@export var world_size: Vector3 = Vector3(world_vector, world_vector, world_vector)

# Cutoff defines how dense the random cubes are. Higher numbers equate to less density.
@export_range(-1, 1) var cutoff: float = 0.1
@export var colors: Array[Color]
# We will get the random seed in the _ready() function.
@export var noise_seed: int = 0

var random_generator = FastNoiseLite.new()
var number_of_chunks: Vector3

var chunk_class = preload("res://chunk.tscn")

func _ready():
	#random_generator.seed = seed
	if finite_world == true:
		generate_terrain_finite()
	else:
		pass
		#generate_terrain_infinite()


func generate_terrain_finite():
	#var random_generator = FastNoiseLite.new()
	random_generator.noise_type = FastNoiseLite.TYPE_SIMPLEX
	random_generator.frequency = 0.003
	number_of_chunks = world_size / chunk_size
	
	generate_chunks()

func generate_chunks():
	for x in range(number_of_chunks.x):
		for z in range(number_of_chunks.z):
			for y in range(number_of_chunks.y):
				var new_chunk = chunk_class.instantiate()
				new_chunk.position = Vector3(x, y, z) * chunk_size
				add_child(new_chunk)
				new_chunk.generate_data(chunk_size, world_size.y, random_generator, colors)
				new_chunk.generate_mesh()
				if new_chunk.position == Vector3(0.0, 0.0, 0.0):
					pass
					# print("Spawn point ready.")
					# Send a signal when the chunk at 0,0 has been generated.
					# This signal should tell the player what altitude to spawn at.
