class_name Chunk
extends StaticBody3D

# This Class defines the geometry of Voxels, how voxels are placed inside Chunks, and how Chunk
# meshes are optimized. We should probably split out Voxels into its own class.

# Following https://www.youtube.com/watch?v=Pfqfr3zFyKI


@export var material: Material

@onready var collision_shape = $TerrainCollision
@onready var mesh_instance: MeshInstance3D = $TerrainMesh

var voxels: Dictionary[Vector3i, BlockType] = {}
# Dirty Voxels are voxels the player added or removed, that differ from natural terrain generation.
# We are keeping track of these and only saving them, so we don't have to save every voxel in a chunk.
# If we implement quarries, those chunks are going to have large save files, but everything else
# should be way smaller. Also, we might be able to use some compression to shrink mostly empty chunks.
var dirty_voxels: Dictionary = {}
var number_of_textures_in_atlas: Vector2 = Vector2.ZERO

#var surface_array: Array = []
var vertices = PackedVector3Array()
var normals = PackedVector3Array()
var uvs = PackedVector2Array()

# Adding keys to each chunk so it can be referenced by filename
var chunks_key: Vector3i = Vector3i.ZERO

# For tuning cave generation
@export var cave_frequency: float = 0.04			# lower = bigger caves
@export var big_caves_threshold: float = 0.0001		# higher = rarer caves
@export var long_caves_threshold: float = 0.02		# higher = rarer caves
@export var cave_surface_margin: int = 10			# how many blocks from surface caves are suppressed
@export var cave_surface_reduction: float = 0.15	# how much rarer caves are near surface

# For Benchmarking
@export var benchmarking: bool = false
var face_time: int = 0

# For debug rendering
@export var debug_transparent: bool = false

# These are implemented to make regenerating chunks multithreaded.
var is_rebuilding: bool = false
var regen_thread: Thread = Thread.new()
var regen_mutex: Mutex = Mutex.new()
var rebuild_count: int = 0

# This is to help address lag when adding or removing a block.
var needs_rebuild: bool = false
var player_initiated_rebuild: bool = false

# This is for making commit_collision run when a batch of commits are ready to go, instead of once
# each time the user changes a block.
var commit_collision_timer: SceneTreeTimer = null

# For precomputing UVs. Look in _init for the precomp code.
var face_vertex_uvs: Dictionary = {}

# For fixing freeze caused by all chunks being generated on the main thread
var was_generated_by_thread: bool = false

signal collision_ready

# These are the vertice coordinates. The cube's center is at 0,0,0. The cube is 1 unit long, 
# so each vertice is 0.5 units out from the center. X is left/right, Y is vertical, Z is depth.
const cube_vertices: Array[Vector3] = [
	Vector3(0, 0, 1), # 0, Bottom Left Front
	Vector3(1, 0, 1), # 1, Bottom Right Front
	Vector3(1, 0, 0), # 2, Bottom Right Back
	Vector3(0, 0, 0), # 3, Bottom Left Back
	Vector3(0, 1, 1), # 4,  Top Left Front
	Vector3(1, 1, 1), # 5, Top Right Front
	Vector3(1, 1, 0), # 6, Top Right Back
	Vector3(0, 1, 0) # 7, Top Left Back
]

# Allows us to add data "per face" according to the video. This is so we don't
# have to say "Face.1" and stuff; we refer to Face.BOTTOM and the others in face_indices, _normals,
# and the _colors dictionaries. We also refer to them in the generate_mesh() function.
enum Face{BOTTOM, FRONT, RIGHT, TOP, LEFT, BACK}

# Using the Vertice Numbers in cube_vertices, decide which face consists of which vertices.
# The order each vertice is listed in matters. Godot uses Clockwise Winding, so whatever
# vertice we start on, we need to go clockwise to get to the next one.
const face_indices: Dictionary[Face, Array] = {
	Face.FRONT: [[0, 4, 5],[0, 5, 1]], #Checked 12/27/25
	Face.BACK: [[2, 7, 3],[2, 6, 7]], #Checked 12/27/25
	Face.LEFT: [[3, 7, 4],[3, 4, 0]], #Checked 12/27/25
	Face.RIGHT: [[1, 5, 6],[1, 6, 2]], #Checked 12/27/25
	Face.BOTTOM: [[0, 1, 2],[0, 2, 3]], #Checked 12/27/25
	Face.TOP: [[4, 7, 6],[4, 6, 5]] #Checked 12/27/25
}

# Normals determine what direction each face is pointing. Faces pointing away from you
# don't get drawn.
const face_normals: Dictionary[Face, Vector3] = {
	Face.FRONT: Vector3(0, 0, 1),
	Face.BACK: Vector3(0, 0, -1),
	Face.LEFT: Vector3(-1, 0, 0),
	Face.RIGHT: Vector3(1, 0, 0),
	Face.BOTTOM: Vector3(0, -1, 0),
	Face.TOP: Vector3(0, 1, 0)
}

func _process(_delta: float) -> void:
	if needs_rebuild and not is_rebuilding:
		needs_rebuild = false
		threaded_rebuild()

func _init() -> void:
	# Precompute UVs. This helps speed up add_face, thereby speeding up chunk generation.
	for face in Face.values():
		face_vertex_uvs[face] = []
		for i in range(8): # since we have 8 faces
			var v = cube_vertices[i]
			var uv: Vector2
			match face:
				Face.FRONT: uv = Vector2(v.x, 1.0 - v.y)
				Face.BACK: uv = Vector2(1.0 - v.x, 1.0 - v.y)
				Face.LEFT: uv = Vector2(v.z, 1.0 - v.y)
				Face.RIGHT: uv = Vector2(1.0 - v.z, 1.0 - v.y)
				Face.TOP: uv = Vector2(v.x, v.z)
				Face.BOTTOM: uv = Vector2(v.x, 1.0 - v.z)
			face_vertex_uvs[face].append(uv)
			
func _ready() -> void:
	# Skip this chunk if it's empty or was generated by worldgen already
	if voxels.is_empty():
		return
	if was_generated_by_thread:
		return
	
	commit_mesh()

# This function determines the position of each block in a given chunk. I believe this is where we
# need to record the location of each block, perhaps in a dictionary?
func generate_data(chunk_size: int, max_height: int, heightmap_noise: Noise, big_cave_noise: Noise, long_cave_noise: Noise, block_types: Array[BlockType])  -> void:
	# Define block types you'll need to refer to by name. Set them to 0 just in case something gets
	# messed up, then look for them by value.
	var default_block: BlockType = block_types[0]
	var bedrock: BlockType = block_types[0]
	var grass: BlockType = block_types[0]
	var dirt: BlockType = block_types[0]
	
	# Establish which layer we're working in
	var vertical_layer = int(round(position.y / max_height))
	
	# Instead of 0, we want these blocks to refer to their actual block type. Define them here.
	for block in block_types:
		if block.block_name == Settings.default_block:
			default_block = block
		if block.block_name == "Bedrock":
			bedrock = block
		if block.block_name == "Grass":
			grass = block
		if block.block_name == "Dirt":
			dirt = block
	
	# Layer Behavior: Layer 2 is always air right now. When we implement mountains, we might change this.
	if vertical_layer == 2:
		return
		
	# Layer 0 is underground. It uses heightmap noise for bedrock generation, but nothing else.
	if vertical_layer == 0:
		for x in range(chunk_size):
			for z in range(chunk_size):
				var global_pos = Vector3(transform.origin) + Vector3(x, 0, z)
				for y in range(max_height):
					if y == max_height - 1:  # Compare noise at the top of layer 0
						print("Layer 0 top - sampling cave noise at Y: ", (y + position.y) * cave_frequency, " position.y: ", position.y)
					var block_to_place: BlockType
					if y == 0: block_to_place = bedrock
					elif y <= 4:
						var bedrock_noise = heightmap_noise.get_noise_2d(
							global_pos.x * 0.5,
							global_pos.z * 0.5
							)
						var bedrock_altitude = int((bedrock_noise + 1) / 2 * 3) + 1
						if y <= bedrock_altitude:
							block_to_place = bedrock
						else: block_to_place = default_block
					else:
						block_to_place = default_block
						
					# Layer 0's caves
					if block_to_place != bedrock:
						# Generating caves is done by multiplying two noise samples (A and B) together.
						var big_caves_a = big_cave_noise.get_noise_3d(
							global_pos.x * cave_frequency,
							(y + position.y) * cave_frequency,
							global_pos.z * cave_frequency)
						var big_caves_b = big_cave_noise.get_noise_3d(
							global_pos.x * cave_frequency + 100.0,
							(y + position.y) * cave_frequency,
							global_pos.z * cave_frequency + 100.0)
						var long_caves_a = long_cave_noise.get_noise_3d(
							global_pos.x * cave_frequency,
							(y + position.y) * cave_frequency,
							global_pos.z * cave_frequency)
						var long_caves_b = long_cave_noise.get_noise_3d(
							global_pos.x * cave_frequency + 100.0,
							(y + position.y) * cave_frequency,
							global_pos.z * cave_frequency + 100.0)
							
						if abs(big_caves_a) < big_caves_threshold and abs(big_caves_b) < big_caves_threshold:
							print("Carving at y: ", y)
							continue
						if abs(long_caves_a) < long_caves_threshold and abs(long_caves_b) < long_caves_threshold:
							continue
					voxels[Vector3i(x, y, z)] = block_to_place
	
	# Layer 1 is the surface, and needs a heightmap as well as the cave generator. This cave generator
	# also has a Surface Factor, which makes caves less common closer to the surface.
	if vertical_layer == 1:
		for x in range(chunk_size):
			for z in range(chunk_size):
				var global_pos = Vector3(transform.origin) + Vector3(x, 0, z)

				# This is the formula we use to generate the shape of our terrain. The three
				# get_noise_2ds act as 3 different octaves; the first generates large hills and valleys,
				# the second adds medium details, and the third adds fine detail.
				# The stuff on the ends of the lines ( +0.5, +0.25, etc) determine the steepness of these details.
				var rand = ((
					heightmap_noise.get_noise_2d(global_pos.x, global_pos.z) + 0.6 * 
					heightmap_noise.get_noise_2d(global_pos.x * 2, global_pos.z * 2) + 0.25 * 
					heightmap_noise.get_noise_2d(global_pos.x * 4, global_pos.z * 4)) / 1.75 + 1) / 2
				var rand_p = pow(rand, 2.1)
				# We need to offset byt position.y so terrain is generated within the current layer.
				var height = int(max_height * rand_p) + int(position.y)

				if height < position.y: continue

				var local_height = int(height - position.y)
				
				# Dirt layer is 3-6 blocks below the surface
				var dirt_depth = int(heightmap_noise.get_noise_2d(global_pos.x * 0.3, global_pos.z * 0.3) * 1.5) + 4
				
				for y in range(min(local_height, max_height)):
					var block_to_place: BlockType
					if y == 0:  # Compare noise at the bottom of layer 1
						print("Layer 1 bottom - sampling cave noise at Y: ", (y + position.y) * cave_frequency, " position.y: ", position.y)
						
					# Surface layer, always grass
					if y == local_height - 1: # This gets the top of the current XZ "column"
						block_to_place = grass
					
					# Subsurface dirt layer, thickness varies
					elif y >= local_height - dirt_depth:
						block_to_place = dirt
					else:
						block_to_place = default_block
					
					# Cave generation
					if block_to_place != bedrock:
						# Caves can reach the surface, but they should be less common there
						# Clamps between 0.0 and 1.0. Anything more than 10 blocks below the surface is
						# considered "fully underground" and is clamped to 1.0. Anything above can have
						# a factor inbetween 0.0 and 1.0. At the surface, factor = 0, at 5 blocks down,
						# factor = 0.5, 10 blocks down or below = 1.0.
						var surface_factor = clamp(float(local_height - y) / cave_surface_margin, 0.9, 1.0)
						
						# Generating caves is done by multiplying two noise samples (A and B) together.
						var big_caves_a = big_cave_noise.get_noise_3d(
							global_pos.x * cave_frequency,
							y * cave_frequency,
							global_pos.z * cave_frequency)
						var big_caves_b = big_cave_noise.get_noise_3d(
							global_pos.x * cave_frequency + 100.0,
							y * cave_frequency,
							global_pos.z * cave_frequency + 100.0)
						
						# Same for the long thin caves
						var long_caves_a = long_cave_noise.get_noise_3d(
							global_pos.x * cave_frequency,
							y * cave_frequency,
							global_pos.z * cave_frequency)
						var long_caves_b = long_cave_noise.get_noise_3d(
							global_pos.x * cave_frequency + 100.0,
							y * cave_frequency,
							global_pos.z * cave_frequency + 100.0)
						
						# This increases resistance to cave formation closer to the surface (I.E. 10+
						# blocks below the surface)
						var calculated_big_caves_threshold = big_caves_threshold * surface_factor
						var calculated_long_caves_threshold = max(long_caves_threshold * surface_factor, long_caves_threshold * 0.1)

						if abs(big_caves_a) < calculated_big_caves_threshold and abs(big_caves_b) < calculated_big_caves_threshold:
							continue
						if abs(long_caves_a) < calculated_long_caves_threshold and abs(long_caves_b) < calculated_long_caves_threshold:
							continue
					
					voxels[Vector3i(x, y, z)] = block_to_place
 
func generate_mesh() -> void:
	if voxels.is_empty(): return
	var start_time = Time.get_ticks_msec()
	
	var atlas: Texture2D = self.material.albedo_texture
	var atlas_size: float = atlas.get_size()[0]
	number_of_textures_in_atlas = Vector2((atlas_size / Settings.texture_size), 1)
	
	var t2 = Time.get_ticks_msec()
	if benchmarking == true:
		if t2-start_time > 0:
			print("Atlas lookup: ", t2-start_time, "ms")
		pass
	
	var t3 = Time.get_ticks_msec()
	for pos in voxels:
		var block_type = voxels[pos]
		if not voxels.has(Vector3i(pos.x, pos.y, pos.z + 1)):
			add_face(Face.FRONT, pos, block_type)
		if not voxels.has(Vector3i(pos.x, pos.y, pos.z - 1)):
			add_face(Face.BACK, pos, block_type)
		if not voxels.has(Vector3i(pos.x - 1, pos.y, pos.z)):
			add_face(Face.LEFT, pos, block_type)
		if not voxels.has(Vector3i(pos.x + 1, pos.y, pos.z)):
			add_face(Face.RIGHT, pos, block_type)
		if not voxels.has(Vector3i(pos.x, pos.y + 1, pos.z)):
			add_face(Face.TOP, pos, block_type)
		if not voxels.has(Vector3i(pos.x, pos.y - 1, pos.z)):
			add_face(Face.BOTTOM, pos, block_type)
		
	var t4 = Time.get_ticks_msec()
	if benchmarking == true:
		print("Voxel face creation: ", t4-t3, "ms")
		face_time = 0

func has_neighbor(data: Dictionary[Vector3i, BlockType], face: Face, pos: Vector3) -> bool:
	# This checks all adjacent positions for neighbors. If one exists, we skip generating that face.
	return data.has(pos + face_normals[face])

func add_face(face: Face, vertice_position: Vector3, block: BlockType) -> void:
	var start_time = Time.get_ticks_msec()
	
	var uv_offset: Vector2
	match face:
		Face.TOP: uv_offset = block.uv_top
		Face.BOTTOM: uv_offset = block.uv_bottom
		_: uv_offset = block.uv_side
	
	
	# Add UVs so we can see textures	
	var indices = face_indices[face]
	for triangle in indices:
		for index in triangle:
			var vertex = cube_vertices[index]
			vertices.append(vertex + vertice_position)
			normals.append(face_normals[face])
			var uv: Vector2
			uv = (face_vertex_uvs[face][index] + uv_offset) / number_of_textures_in_atlas
			uvs.append(uv)

	face_time += Time.get_ticks_msec() - start_time

func commit_mesh() -> void:
	# This used to be the main function that generated chunks. Now it generates the initial chunks
	# and fires a signal when the spawn point is ready.
	commit_visuals()
	commit_collision()
	var chunk_height = Settings.chunk_height
	
	# This makes sure that the player's spawn point is ready, but doesn't send the signal unless the
	# Surface chunk in that XZ coordinate is the one that's ready.
	if mesh_instance.global_position == Vector3(0.0, chunk_height, 0.0) && Settings.player_is_spawned == false:
		EventBus.spawn_chunk_is_ready.emit()
	else: return
	
func commit_visuals() -> void:
	# This will return empty chunks, like for sky.
	if vertices.is_empty():
		return
	var start = Time.get_ticks_msec()
	# Commit Visuals seperately so we can do this relatively inexpensive operation more often than
	# the expensive operating of committing Collision.
	var new_mesh = ArrayMesh.new()
	var arrays = []
	
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_mesh.surface_set_material(0, material)
	mesh_instance.mesh = new_mesh
	if benchmarking == true:
		print("Commit Visuals: %s ms" % (Time.get_ticks_msec() - start))
	if debug_transparent:
		(material as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(material as StandardMaterial3D).albedo_color = Color(1, 1, 1, 0.5)
	else:
		(material as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		(material as StandardMaterial3D).albedo_color = Color(1, 1, 1, 1)

func commit_collision() -> void:
	# This will return empty chunks, like for sky.
	if mesh_instance.mesh == null:
		return
	collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()
	#print("Collision committed for: ", name, " shape: ", collision_shape.shape)
	collision_ready.emit()

# This is to address lag when adding or removing blocks.
func request_rebuild() -> void:
	needs_rebuild = true

# Rebuilds a chunk's mesh in a multithreaded fashion.
func threaded_rebuild() -> void:
	if regen_thread.is_started(): # Old threads that this routine starts might hang around. This
		# cleans them up.
		regen_thread.wait_to_finish()
	regen_thread = Thread.new()
	regen_thread.start(func():
		regen_mutex.lock() # Lock this mutex, then clear vertices, normals, and uvs
		vertices.clear()
		normals.clear()
		uvs.clear()
		generate_mesh() # Generate_mesh has its own timer and print funciton.
		regen_mutex.unlock()
		commit_visuals.call_deferred()
		# If the player initiates a rebuild (adds or removes a block), commit collision immediately.
		# Otherwise, schedule it. This is an expensive operation and it needs to be staggered.
		if player_initiated_rebuild:
			commit_collision.call_deferred() # Right away
			player_initiated_rebuild = false
		else:
			schedule_collision_rebuild.call_deferred() # Scheduled
		finish_rebuild.call_deferred()
		)
		
func schedule_collision_rebuild() -> void:
	#var start = Time.get_ticks_msec()
	if commit_collision_timer != null:
		# Reset the clock if it's already running
		commit_collision_timer = null
	commit_collision_timer = get_tree().create_timer(0.1) # I started this with a value of 0.5, that's
	# almost certainly too long. But let's see how tight we can make it.
	commit_collision_timer.timeout.connect(func():
		commit_collision()
		commit_collision_timer = null
	)

func finish_rebuild() -> void:
	regen_thread.wait_to_finish()
	is_rebuilding = false

func _exit_tree() -> void:
	if regen_thread.is_started():
		regen_thread.wait_to_finish()
