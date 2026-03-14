class_name Chunk
extends StaticBody3D

# This Class defines the geometry of Voxels, how voxels are placed inside Chunks, and how Chunk
# meshes are optimized. We should probably split out Voxels into its own class.

# Following https://www.youtube.com/watch?v=Pfqfr3zFyKI

@export var benchmarking: bool = true

@export var material: Material

@onready var collision_shape = $TerrainCollision
@onready var mesh_instance: MeshInstance3D = $TerrainMesh

var voxels: Dictionary[Vector3i, BlockType] = {}
var number_of_textures_in_atlas: Vector2 = Vector2.ZERO

#var surface_array: Array = []
var vertices = PackedVector3Array()
var normals = PackedVector3Array()
var uvs = PackedVector2Array()

# For Benchmarking
#var total_chunks = 0
#var chunk_gen_time = 0
var face_time: int = 0

# These are implemented to make regenerating chunks multithreaded.
var is_rebuilding: bool = false
var regen_thread: Thread = Thread.new()
var regen_mutex: Mutex = Mutex.new()
var rebuild_count: int = 0
# This is for making commit_collision run when a batch of commits are ready to go, instead of once
# each time the user changes a block.
var commit_collision_timer: SceneTreeTimer = null

# For precomputing UVs. Look in _init for the precomp code.
var face_vertex_uvs: Dictionary = {}

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

func _init():
	# For precomputing UVs. This helps speed up add_face, thereby speeding up chunk generation.
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
	#surface_array.resize(Mesh.ARRAY_MAX)
	#mesh_instance.mesh = ArrayMesh.new()
	if voxels.is_empty(): return
	
	commit_mesh()
	#print("%s: _ready - voxels type = %s, size = %s" % [name, typeof(voxels), voxels.size() if voxels else "NULL"])
	#print("Finished a chunk")

# This function determines the position of each block in a given chunk. I believe this is where we
# need to record the location of each block, perhaps in a dictionary?
func generate_data(chunk_size: int, max_height: int, noise: Noise, block_types: Array[BlockType]):
	for x in range(chunk_size):
		for z in range(chunk_size):
			var global_pos = Vector3(transform.origin) + Vector3(x, 0, z)

			# This is the formula we use to generate the shape of our terrain. I believe the three
			# get_noise_2ds act as 3 different octaves; the first generates large hills and valleys,
			# the second adds medium details, and the third adds fine detail.
			# The stuff on the ends of the lines ( +0.5, +0.25, etc) determine the steepness of these details.
			var rand = ((
				noise.get_noise_2d(global_pos.x, global_pos.z) + 0.6 * 
				noise.get_noise_2d(global_pos.x * 2, global_pos.z * 2) + 0.25 * 
				noise.get_noise_2d(global_pos.x * 4, global_pos.z * 4)) / 1.75 + 1) / 2
			var rand_p = pow(rand, 2.1)
			var height = int(max_height * rand_p)

			if height < position.y: continue
			# This is the old color function replaced with BlockTypes to try to debug why the game
			# hangs on runtime.
			var color_array = block_types

			var local_height = int(height - position.y)
			for y in range(min(local_height, max_height)):
				voxels[Vector3i(x, y, z)] = color_array[y % color_array.size()]
 
func generate_mesh():
	if voxels.is_empty(): return
	var start_time = Time.get_ticks_msec()
	
	var atlas: Texture2D = self.material.albedo_texture
	var atlas_size: int = atlas.get_size()[0]
	number_of_textures_in_atlas = Vector2((atlas_size / Settings.texture_size), 1)
	
	var t2 = Time.get_ticks_msec()
	if benchmarking == true:
		if t2-start_time > 0:
			print("Atlas lookup: ", t2-start_time, "ms")
	
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
		
	var t3 = Time.get_ticks_msec()
	if benchmarking == true:
		print("Face gen: ", t3-t2, "ms, voxel count: ", voxels.size())
		print("Voxels per ms: ", voxels.size()/(t3-t2))
		print("Total face time: ", face_time, "ms")
		face_time = 0
			
# The "mesh" here is that of the chunk itself. This function places each face for every block in a chunk.
# Simultaneously, it avoids placing faces if they are covered by a neighboring block, speeding up render
# times a lot.
#func generate_mesh():
	##var start = Time.get_ticks_msec()
	##This skips generating the chunk if said chunk is totally empty. I think this is going to be rare,
	## but a good edge case to check against.
	#if voxels.is_empty(): return
	#
	#var t1 = Time.get_ticks_msec()
	#
	#var atlas: Texture2D = self.material.albedo_texture
	#var atlas_size: int = atlas.get_size()[0]
	#number_of_textures_in_atlas = Vector2((atlas_size / Settings.texture_size), 1)
	#
	#var t2 = Time.get_ticks_msec()
	#if benchmarking == true:
		#if t2-t1 > 0:
			#print("Atlas lookup: ", t2-t1, "ms")
		##print("Generated Mesh: %s ms" %(Time.get_ticks_msec() - start))
#
	#for pos in voxels:
		#var block_type = voxels[pos]
#
	### These If statements help optimize our terrain's meshes. If a cube has a neighbor, we don't
	### render the face that touches that neighbor. This prevents invisible faces from being computed.
		#if not has_neighbor(voxels, Face.FRONT, pos):
			#add_face(Face.FRONT, pos, block_type)
		#if not has_neighbor(voxels, Face.BACK, pos):
			#add_face(Face.BACK, pos, block_type)
		#if not has_neighbor(voxels, Face.LEFT, pos):
			#add_face(Face.LEFT, pos, block_type)
		#if not has_neighbor(voxels, Face.RIGHT, pos):
			#add_face(Face.RIGHT, pos, block_type)
		#if not has_neighbor(voxels, Face.TOP, pos):
			#add_face(Face.TOP, pos, block_type)
		#if not has_neighbor(voxels, Face.BOTTOM, pos):
			#add_face(Face.BOTTOM, pos, block_type)
	#var t3 = Time.get_ticks_msec()
	#if benchmarking == true:
		#print("Face gen: ", t3-t2, "ms, voxel count: ", voxels.size())
		#print("Voxels per ms: ", voxels.size()/(t3-t2))
		#print("Total face time: ", face_time, "ms")
		#face_time = 0

func has_neighbor(data: Dictionary[Vector3i, BlockType], face: Face, position: Vector3) -> bool:
	# This checks all adjacent positions for neighbors. If one exists, we skip generating that face.
	return data.has(position + face_normals[face])

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
			
			## Determine which corner of the voxel we're working with
			#var uv: Vector2
			#match face:
				#Face.FRONT:		uv = Vector2(vertex.x, 1.0 - vertex.y)
				#Face.BACK:		uv = Vector2(1.0 - vertex.x, 1.0 - vertex.y)
				#Face.LEFT:		uv = Vector2(vertex.z, 1.0 - vertex.y)
				#Face.RIGHT:		uv = Vector2(1.0 - vertex.z, 1.0 - vertex.y)
				#Face.TOP:		uv = Vector2(vertex.x, vertex.z)
				#Face.BOTTOM:	uv = Vector2(vertex.x, 1.0 - vertex.z)
			#
			## Apply textures, allowing for multiple textures on one voxel (like with grassy dirt)
			#var uv_offset: Vector2
			#match face:
				#Face.TOP:		uv_offset = block.uv_top
				#Face.BOTTOM:		uv_offset = block.uv_bottom
				#_:				uv_offset = block.uv_side
	#
			#uv = (uv + uv_offset) / number_of_textures_in_atlas
			#uvs.append(uv)
	face_time += Time.get_ticks_msec() - start_time

func commit_mesh():
	# This used to be the main function that generated chunks. Now it generates the initial chunks
	# and fires a signal when the spawn point is ready.
	commit_visuals()
	commit_collision()
	
	if mesh_instance.global_position == Vector3(0.0, 0.0, 0.0) && Settings.player_is_spawned == false:
		#print(Settings.player_is_spawned)
		EventBus.spawn_chunk_is_ready.emit()
	else: return
	
func commit_visuals():
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
		pass
		#print("Commit Visuals: %s ms" % (Time.get_ticks_msec() - start))

func commit_collision():
	collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()

func threaded_rebuild():
	rebuild_count += 1
	if is_rebuilding:
		return
	is_rebuilding = true
	if regen_thread.is_started():
		regen_thread.wait_to_finish()
	regen_thread = Thread.new()
	regen_thread.start(func():
		if benchmarking == true:
			pass
			#print("Running on thread: ", OS.get_thread_caller_id())
		regen_mutex.lock()
		var start_time = Time.get_ticks_msec()
		vertices.clear()
		var vertice_time = Time.get_ticks_msec() - start_time
		normals.clear()
		var normals_time = Time.get_ticks_msec() - start_time - vertice_time
		uvs.clear()
		var uvs_time = Time.get_ticks_msec() - start_time - normals_time
		generate_mesh() # Generate_mesh has its own timer and print funciton.
		regen_mutex.unlock()
		commit_visuals.call_deferred() # Same here.
		schedule_collision_rebuild.call_deferred()
		#commit_collision.call_deferred()
		var commit_collision_time = Time.get_ticks_msec() - start_time
		finish_rebuild.call_deferred()
		if benchmarking == true:
			pass
			#print(
			#"Cleared vertices: %s ms\nNormals: %s ms\nUVs: %s ms" % 
			#[vertice_time, normals_time, uvs_time])
			)

func schedule_collision_rebuild():
	var start = Time.get_ticks_msec()
	if commit_collision_timer != null:
		# Reset the clock if it's already running
		commit_collision_timer = null
	commit_collision_timer = get_tree().create_timer(0.1) # I started this with a value of 0.5, that's
	# almost certainly too long. But let's see how tight we can make it.
	commit_collision_timer.timeout.connect(func():
		commit_collision()
		commit_collision_timer = null
	)
	if benchmarking == true:
		pass
		#print("Commit Collision: %s ms" % (Time.get_ticks_msec() - start))

func finish_rebuild():
	regen_thread.wait_to_finish()
	is_rebuilding = false

func _exit_tree():
	if regen_thread.is_started():
		regen_thread.wait_to_finish()
