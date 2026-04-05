# cube.gd
# Autoload singleton. Add it to Project -> Project Settings -> Autoload as "Cube".
# Contains all geometry constants and precomputed tables describing a single voxel cube.
# Shared across Chunk, GreedyMesher, and any other system that needs cube geometry.
@tool
extends Node

# Allows us to add data "per face" according to the video. This is so we don't
# have to say "Face.1" and stuff; we refer to Face.BOTTOM and the others in face_indices, _normals,
# and the _colors dictionaries. We also refer to them in the generate_mesh() function.
enum Face {BOTTOM, FRONT, RIGHT, TOP, LEFT, BACK}

# These are the vertice coordinates. The cube's center is at 0,0,0. The cube is 1 unit long, 
# so each vertice is 0.5 units out from the center. X is left/right, Y is vertical, Z is depth.
const VERTICES: Array[Vector3] = [
	Vector3(0, 0, 1), # 0, Bottom Left Front
	Vector3(1, 0, 1), # 1, Bottom Right Front
	Vector3(1, 0, 0), # 2, Bottom Right Back
	Vector3(0, 0, 0), # 3, Bottom Left Back
	Vector3(0, 1, 1), # 4, Top Left Front
	Vector3(1, 1, 1), # 5, Top Right Front
	Vector3(1, 1, 0), # 6, Top Right Back
	Vector3(0, 1, 0)  # 7, Top Left Back
]

# Using the Vertice Numbers in cube_vertices, decide which face consists of which vertices.
# The order each vertice is listed in matters. Godot uses Clockwise Winding, so whatever
# vertice we start on, we need to go clockwise to get to the next one.
const FACE_INDICES: Dictionary = {
	Face.FRONT:  [[0, 4, 5], [0, 5, 1]],
	#Face.BACK:   [[2, 6, 7], [2, 7, 3]],
	Face.BACK:   [[2, 7, 3], [2, 6, 7]],
	Face.LEFT:   [[3, 7, 4], [3, 4, 0]],
	Face.RIGHT:  [[1, 5, 6], [1, 6, 2]],
	Face.BOTTOM: [[0, 1, 2], [0, 2, 3]],
	Face.TOP:    [[4, 7, 6], [4, 6, 5]]
}

# Normals determine what direction each face is pointing. Faces pointing away from you
# don't get drawn.
const FACE_NORMALS: Dictionary = {
	Face.FRONT:  Vector3(0,  0,  1),
	Face.BACK:   Vector3(0,  0, -1),
	Face.LEFT:   Vector3(-1, 0,  0),
	Face.RIGHT:  Vector3(1,  0,  0),
	Face.BOTTOM: Vector3(0, -1,  0),
	Face.TOP:    Vector3(0,  1,  0)
}

# Precomputed per-face packed arrays. Built once in _ready().
# precomp_vertices[face] -> PackedVector3Array of 6 verts at unit-cube origin
# precomp_normals[face]  -> PackedVector3Array of 6 identical normals
# precomp_indices[face]  -> Array[int] of 6 vertex indices, flattened from FACE_INDICES
# face_vertex_uvs[face]  -> Array of 8 Vector2, one per cube vertex, for UV mapping
var precomp_vertices: Dictionary = {}
var precomp_normals:  Dictionary = {}
var precomp_indices:  Dictionary = {}
var face_vertex_uvs:  Dictionary = {}

func _ready() -> void:
	var all_faces: Array = [Face.BOTTOM, Face.FRONT, Face.RIGHT, Face.TOP, Face.LEFT, Face.BACK]

	for face in all_faces:
		var verts: PackedVector3Array = PackedVector3Array()
		var norms: PackedVector3Array = PackedVector3Array()
		var flat:  Array[int] = []
		var normal: Vector3 = FACE_NORMALS[face]
		for triangle in FACE_INDICES[face]:
			for index: int in triangle:
				verts.append(VERTICES[index])
				norms.append(normal)
				flat.append(index)
		precomp_vertices[face] = verts
		precomp_normals[face]  = norms
		precomp_indices[face]  = flat

	for face in all_faces:
		face_vertex_uvs[face] = []
		for i in range(8):
			face_vertex_uvs[face].append(compute_uv_for_vertex(face, i))
		#if face == Cube.Face.BACK or face == Cube.Face.RIGHT:
			#print("face_vertex_uvs[", face, "]: ", face_vertex_uvs[face])
			
static func compute_uv_for_vertex(face: int, vertex_index: int) -> Vector2:
	var v: Vector3 = VERTICES[vertex_index]
	match face:
		Face.FRONT:  return Vector2(v.x, 		1.0 - v.y)
		Face.BACK:   return Vector2(1.0 - v.x, 	1.0 - v.y)
		Face.LEFT:   return Vector2(v.z,			1.0 - v.y)
		Face.RIGHT:  return Vector2(1.0 - v.z,	1.0 - v.y)
		Face.TOP:    return Vector2(v.x,			v.z)
		Face.BOTTOM: return Vector2(v.x,			1.0 - v.z)
	return Vector2.ZERO
