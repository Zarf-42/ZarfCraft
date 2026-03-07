class_name Chunk
extends StaticBody3D

# This Class defines the geometry of Voxels, how voxels are placed inside Chunks, and how Chunk
# meshes are optimized. We should probably split out Voxels into its own class.

# Following https://www.youtube.com/watch?v=Pfqfr3zFyKI

@export var material: Material

@onready var collision_shape = $TerrainCollision
@onready var mesh_instance: MeshInstance3D = $TerrainMesh

var voxels: Dictionary[Vector3i, Color] = {}

var surface_array: Array = []
var vertices = PackedVector3Array()
var normals = PackedVector3Array()
var colors = PackedColorArray()

var total_chunks = 0
var chunk_gen_time = 0

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

func _ready() -> void:
	#surface_array.resize(Mesh.ARRAY_MAX)
	#mesh_instance.mesh = ArrayMesh.new()
	
	if voxels.is_empty(): return
	
	commit_mesh()
	#print("%s: _ready - voxels type = %s, size = %s" % [name, typeof(voxels), voxels.size() if voxels else "NULL"])
	#print("Finished a chunk")

# This function determines the position of each block in a given chunk. I believe this is where we
# need to record the location of each block, perhaps in a dictionary?
func generate_data(chunk_size: int, max_height: int, noise: Noise, color_array: Array[Color]):
	for x in range(chunk_size):
		for z in range(chunk_size):
			# New Position, I think, is supposed to be where the next cube generates.
			# I.E. new_position = 1, 0, 2 is West 1, Up 0, North 2. Y = 0 here because
			# we start at the bottom of each chunk and generate upwards? Maybe?
			# 2/17/26: I think we actually start from the top and generate down. 
			# 2/24/26: Convert transform.origin to vector3i. All block coords should be integers.
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

			var local_height = int(height - position.y)
			for y in range(min(local_height, max_height)):
				voxels[Vector3i(x, y, z)] = color_array[y % color_array.size()]
 
# The "mesh" here is that of the chunk itself. This function places each face for every block in a chunk.
# Simultaneously, it avoids placing faces if they are covered by a neighboring block, speeding up render
# times a lot.
func generate_mesh():
	#This skips generating the chunk if said chunk is totally empty. I think this is going to be rare,
	# but a good edge case to check against.
	if voxels.is_empty(): return

	for pos in voxels:
		var color = voxels[pos]
		# I attempted to replace all of the If statements below with this nice For loop. Unfortunately,
		# this adds ~9ms to an already expensive operation.
		#for faces in Face.keys():
			#if not has_neighbor(voxels, Face[faces], pos):
				#add_face(Face[faces], adjusted_pos, color)

		## These If statements help optimize our terrain's meshes. If a cube has a neighbor, we don't
		## render the face that touches that neighbor. This prevents invisible faces from being computed.
		if not has_neighbor(voxels, Face.FRONT, pos):
			add_face(Face.FRONT, pos, color)
		if not has_neighbor(voxels, Face.BACK, pos):
			add_face(Face.BACK, pos, color)
		if not has_neighbor(voxels, Face.LEFT, pos):
			add_face(Face.LEFT, pos, color)
		if not has_neighbor(voxels, Face.RIGHT, pos):
			add_face(Face.RIGHT, pos, color)
		if not has_neighbor(voxels, Face.TOP, pos):
			add_face(Face.TOP, pos, color)
		if not has_neighbor(voxels, Face.BOTTOM, pos):
			add_face(Face.BOTTOM, pos, color)

func has_neighbor(data: Dictionary[Vector3i, Color], face: Face, position: Vector3):
	# This checks all adjacent positions for neighbors. If one exists, we skip generating that face.
	var neighbor_position = position + face_normals[face]
	if data.has(neighbor_position):
		return true
	else:
		return false

func add_face(face: Face, vertice_position: Vector3, color: Color) -> void:
	var indices = face_indices[face]
	for triangle in indices:
		for index in triangle:
			vertices.append(cube_vertices[index] + vertice_position)
			normals.append(face_normals[face])
			colors.append(color)

func commit_mesh():
	var new_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_mesh.surface_set_material(0, material)
	mesh_instance.mesh = new_mesh
	collision_shape.shape = new_mesh.create_trimesh_shape()
	
	if mesh_instance.global_position == Vector3(0.0, 0.0, 0.0) && Settings.player_is_spawned == false:
		#print(Settings.player_is_spawned)
		EventBus.spawn_chunk_is_ready.emit()
	else: return
		
func regenerate_mesh():
	var start_time = Time.get_ticks_msec()
	
	vertices.clear()
	var vertice_time = Time.get_ticks_msec() - start_time
	
	normals.clear()
	var normals_time = Time.get_ticks_msec() - start_time
	
	colors.clear()
	var colors_time = Time.get_ticks_msec() - start_time
	
	generate_mesh()
	var generate_time = Time.get_ticks_msec() - start_time
	
	commit_mesh()
	var commit_time = Time.get_ticks_msec() - start_time - generate_time
	
	#print(
	#"Cleared vertices: %s\nNormals: %s \nColors: %s \nGenerated Mesh: %s \nCommit: %s" % [
	#vertice_time, normals_time, colors_time, generate_time, commit_time])
