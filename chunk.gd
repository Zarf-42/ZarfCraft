class_name Chunk
extends StaticBody3D

# Following https://www.youtube.com/watch?v=Pfqfr3zFyKI

@export var material: Material

@onready var collision_shape = $TerrainCollision
@onready var mesh_instance: MeshInstance3D = $TerrainMesh

var voxels: Dictionary[Vector3, Color] = {}

var surface_array: Array = []
var vertices = PackedVector3Array()
var normals = PackedVector3Array()
var colors = PackedColorArray()

# These are the vertice coordinates. The cube's center is at 0,0,0. The cube is 1 unit long, 
# so each vertice is 0.5 units out from the center. X is left/right, Y is vertical, Z is depth.
var cube_vertices: Array[Vector3] = [
	Vector3(-0.5, -0.5, 0.5), # 0, Bottom Left Front
	Vector3(0.5, -0.5, 0.5), # 1, Bottom Right Front
	Vector3(0.5, -0.5, -0.5), # 2, Bottom Right Back
	Vector3(-0.5, -0.5, -0.5), # 3, Bottom Left Back
	Vector3(-0.5, 0.5, 0.5), # 4,  Top Left Front
	Vector3(0.5, 0.5, 0.5), # 5, Top Right Front
	Vector3(0.5, 0.5, -0.5), # 6, Top Right Back
	Vector3(-0.5, 0.5, -0.5) # 7, Top Left Back
]

# Allows us to add data "per face" according to the video. This is so we don't
# have to say "Face.1" and stuff; we refer to Face.BOTTOM and the others in face_indices, _normals,
# and the _colors dictionaries. We also refer to them in the generate_mesh() function.
enum Face{BOTTOM, FRONT, RIGHT, TOP, LEFT, BACK}

# Using the Vertice Numbers in cube_vertices, decide which face consists of which vertices.
# The order each vertice is listed in matters. Godot uses Clockwise Winding, so whatever
# vertice we start on, we need to go clockwise to get to the next one.
var face_indices: Dictionary[Face, Array] = {
	Face.FRONT: [[0, 4, 5],[0, 5, 1]], #Checked 12/27/25
	Face.BACK: [[2, 7, 3],[2, 6, 7]], #Checked 12/27/25
	Face.LEFT: [[3, 7, 4],[3, 4, 0]], #Checked 12/27/25
	Face.RIGHT: [[1, 5, 6],[1, 6, 2]], #Checked 12/27/25
	Face.BOTTOM: [[0, 1, 2],[0, 2, 3]], #Checked 12/27/25
	Face.TOP: [[4, 7, 6],[4, 6, 5]] #Checked 12/27/25
}

# Normals determine what direction each face is pointing. Faces pointing away from you
# don't get drawn.
var face_normals: Dictionary[Face, Vector3] = {
	Face.FRONT: Vector3(0, 0, 1),
	Face.BACK: Vector3(0, 0, -1),
	Face.LEFT: Vector3(-1, 0, 0),
	Face.RIGHT: Vector3(1, 0, 0),
	Face.BOTTOM: Vector3(0, -1, 0),
	Face.TOP: Vector3(0, 1, 0)
}

#var face_colors: Dictionary[Face, Color] = {
	#Face.BOTTOM: Color.RED,
	#Face.FRONT: Color.ORANGE,
	#Face.RIGHT: Color.YELLOW,
	#Face.TOP: Color.GREEN,
	#Face.LEFT: Color.BLUE,
	#Face.BACK: Color.PURPLE
#}

func _ready() -> void:
	surface_array.resize(Mesh.ARRAY_MAX)
	mesh_instance.mesh = ArrayMesh.new()
	
	if voxels.is_empty(): return
	
	commit_mesh()

# I think this is where we determine the order in which chunks get generated. We might be able to
# define the pattern/shape by which chunks are generated here.
func generate_data(chunk_size: int, max_height: int, noise: Noise, color_array:Array[Color]):
	for x in range(chunk_size):
		for z in range(chunk_size):
			# New Position, I think, is supposed to be where the next chunk generates.
			# Also I think we generated chunks from the bottom up.
			# I.E. new_position = 1, 0, 2 is West 1, Up 0, North 2. Y = 0 here because
			# we start at the bottom of each chunk and generate upwards? Maybe?
			var new_position = global_position + Vector3(x, 0, z)

			var rand = ((
				noise.get_noise_2d(new_position.x, new_position.z) + 0.5 * 
				noise.get_noise_2d(new_position.x * 2, new_position.z * 2) + 0.25 * 
				noise.get_noise_2d(new_position.x * 4, new_position.z * 4)) / 1.75 + 1) / 2

			var rand_p = pow(rand, 2.1)
			var height = max_height * rand_p

			if height < position.y: continue

			var local_height = height - position.y
			for y in range(min(local_height, chunk_size)):
				voxels[Vector3(x, y, z)] = color_array[y % color_array.size()]

func generate_mesh():
	if voxels.is_empty(): return
	for position in voxels:
		var color = voxels[position]
		# These If statements help optimize our terrain's meshes. If a cube has a neighbor, we don't
		# render the face that touches that neighbor. This prevents invisible faces from being computed.
		if not has_neighbor(voxels, Face.FRONT, position):
			add_face(Face.FRONT, position, color)
		if not has_neighbor(voxels, Face.BACK, position):
			add_face(Face.BACK, position, color)
		if not has_neighbor(voxels, Face.LEFT, position):
			add_face(Face.LEFT, position, color)
		if not has_neighbor(voxels, Face.RIGHT, position):
			add_face(Face.RIGHT, position, color)
		if not has_neighbor(voxels, Face.TOP, position):
			add_face(Face.TOP, position, color)
		if not has_neighbor(voxels, Face.BOTTOM, position):
			add_face(Face.BOTTOM, position, color)

func has_neighbor(data: Dictionary[Vector3, Color], face: Face, position: Vector3):
	# Somehow this is supposed to see if there's a block next to this face, so we can skip rendering
	# I think it gets the position of the face that was just added in generate_mesh above.
	# Then it detects if that position + 1 has a block in it (or minus 1; it uses the Face Normal to determine this)
	var neighbor_position = position + face_normals[face]
	if data.has(neighbor_position):
		return true
	else:
		return false
		
		#return true
	#return false
	# The above is a shortcut; the Return True inside the if statement gets us out of this 
	# function early, meaning we skip the Return False line. No Else needed. Not sure if I like that.

func add_face(face: Face, vertice_position: Vector3, color: Color) -> void:
	var indices = face_indices[face]
	#print(indices)
	for triangle in indices:
		for index in triangle:
			vertices.append(cube_vertices[index] + vertice_position)
			normals.append(face_normals[face])
			colors.append(color)

# Takes the data that we generated and puts it in an array; I.E. the vertices, normals, and colors
# we generated previously.
func commit_mesh():
	# I believe this takes the values assigned to Vertices, Normals, and Colors, and writes
	# them out into the Surface Array. Essentially, it assigns those properties (which we
	# generate elsewhere) to the terrain.
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors
	
	#Take the data in Surface Array and run it through the add_surface_from_arrays method?
	mesh_instance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	mesh_instance.mesh.surface_set_material(0, material)
	
	collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()
	
	if mesh_instance.global_position == Vector3(0.0, 32.0, 0.0):
		print(mesh_instance.global_position)
		# Send a signal saying that the spawn point is ready. This signal is defined
		# in the EventBus singleton. We will use it to tell the player what altitude
		# to spawn at.
		print("Spawn chunk is ready.")
		EventBus.spawn_chunk_is_ready.emit()
