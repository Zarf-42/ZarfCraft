# greedy_mesh.gd

# Autoload or plain class — does NOT need to extend Node since all functions are static.
# Call GreedyMesh.mesh() from generate_mesh() in chunk.gd.

class_name GreedyMesh

# Each direction entry defines how to slice the chunk for one face direction.
# normal     - which way the face points, also the axis we step layers along
# u_axis     - chunk axis that maps to the horizontal sweep of the greedy pass
# v_axis     - chunk axis that maps to the vertical sweep of the greedy pass
const DIRECTIONS: Array = [
	{ "face": Cube.Face.TOP,    "normal": Vector3i( 0,  1,  0), "u": Vector3i(1,0,0), "v": Vector3i(0,0,1) },
	{ "face": Cube.Face.BOTTOM, "normal": Vector3i( 0, -1,  0), "u": Vector3i(1,0,0), "v": Vector3i(0,0,1) },
	{ "face": Cube.Face.RIGHT,  "normal": Vector3i( 1,  0,  0), "u": Vector3i(0,0,1), "v": Vector3i(0,1,0) },
	{ "face": Cube.Face.LEFT,   "normal": Vector3i(-1,  0,  0), "u": Vector3i(0,0,1), "v": Vector3i(0,1,0) },
	{ "face": Cube.Face.FRONT,  "normal": Vector3i( 0,  0,  1), "u": Vector3i(0,1,0), "v": Vector3i(1,0,0) },
	{ "face": Cube.Face.BACK,   "normal": Vector3i( 0,  0, -1), "u": Vector3i(0,1,0), "v": Vector3i(1,0,0) },
]

static func mesh(
		voxels: Dictionary,
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		uv2s: PackedVector2Array,
		number_of_textures_in_atlas: Vector2) -> void:

	var chunk_size: int = Settings.chunk_size
	var chunk_height: int = Settings.chunk_height

	for dir in DIRECTIONS:
		var face: Cube.Face         = dir["face"]
		var normal: Vector3i        = dir["normal"]
		var u_axis: Vector3i        = dir["u"]
		var v_axis: Vector3i        = dir["v"]

		var u_size: int = _axis_size(u_axis, chunk_size, chunk_height)
		var v_size: int = _axis_size(v_axis, chunk_size, chunk_height)
		var layer_size: int = _axis_size(normal, chunk_size, chunk_height)

		for layer in range(layer_size):
			var grid: Array = []
			grid.resize(u_size * v_size)

			for u in range(u_size):
				for v in range(v_size):
					var pos: Vector3i = _make_pos(normal, u_axis, v_axis, layer, u, v)
					var block: BlockType = voxels.get(pos, null)
					if block == null or block.is_transparent:
						grid[u + v * u_size] = null
						continue
					var neighbor: Vector3i = pos + normal
					var nb: BlockType = voxels.get(neighbor, null)
					grid[u + v * u_size] = block if (nb == null or nb.is_transparent) else null

			var visited: Array = []
			visited.resize(u_size * v_size)
			visited.fill(false)

			for v in range(v_size):
				for u in range(u_size):
					var idx: int = u + v * u_size
					if visited[idx] or grid[idx] == null:
						continue

					var block: BlockType = grid[idx]

					var width: int = 1
					while u + width < u_size:
						var next_idx: int = (u + width) + v * u_size
						if visited[next_idx] or grid[next_idx] != block:
							break
						width += 1

					var height: int = 1
					var can_expand: bool = true
					while v + height < v_size and can_expand:
						for du in range(width):
							var check_idx: int = (u + du) + (v + height) * u_size
							if visited[check_idx] or grid[check_idx] != block:
								can_expand = false
								break
						if can_expand:
							height += 1

					for dv in range(height):
						for du in range(width):
							visited[(u + du) + (v + dv) * u_size] = true

					var origin: Vector3i = _make_pos(normal, u_axis, v_axis, layer, u, v)
					_add_greedy_face(
						face, origin, u_axis, v_axis, normal,
						width, height, block,
						vertices, normals, uvs, uv2s,
						number_of_textures_in_atlas)

# Returns how many steps exist along a given axis vector
static func _axis_size(axis: Vector3i, chunk_size: int, chunk_height: int) -> int:
	if axis.y != 0:
		return chunk_height
	return chunk_size

# Builds a Vector3i position from layer/u/v coordinates for a given direction
static func _make_pos(normal: Vector3i, u_axis: Vector3i, v_axis: Vector3i,
		layer: int, u: int, v: int) -> Vector3i:
	# The layer position sits along the normal's axis (using abs so negative normals still index correctly)
	var layer_vec: Vector3i = Vector3i(
		absi(normal.x) * layer,
		absi(normal.y) * layer,
		absi(normal.z) * layer)
	return layer_vec + u_axis * u + v_axis * v

static func _add_greedy_face(
		face: Cube.Face,
		origin: Vector3i,
		u_axis: Vector3i,
		v_axis: Vector3i,
		normal: Vector3i,
		width: int,
		height: int,
		block: BlockType,
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		uv2s: PackedVector2Array,
		number_of_textures_in_atlas: Vector2) -> void:

	var face_offset: Vector3 = Vector3.ZERO
	if normal.x > 0 or normal.y > 0 or normal.z > 0:
		face_offset = Vector3(normal)

	var o: Vector3 = Vector3(origin) + face_offset
	var u: Vector3 = Vector3(u_axis) * width
	var v: Vector3 = Vector3(v_axis) * height
	var n: Vector3 = Vector3(normal)

	var v0: Vector3 = o
	var v1: Vector3 = o + u
	var v2: Vector3 = o + u + v
	var v3: Vector3 = o + v

	## UV — raw tiling coords, 0→width and 0→height
	## The shader will fract() these to tile within one block
	#var uv0: Vector2 = Vector2(0,     0)
	#var uv1: Vector2 = Vector2(width, 0)
	#var uv2: Vector2 = Vector2(width, height)
	#var uv3: Vector2 = Vector2(0,     height)
	#
	# UV — raw tiling coords
	var uv0: Vector2
	var uv1: Vector2
	var uv2: Vector2
	var uv3: Vector2

	if face == Cube.Face.FRONT or face == Cube.Face.BACK:
		uv0 = Vector2(0,      width)
		uv1 = Vector2(0,      0)
		uv2 = Vector2(height,  0)
		uv3 = Vector2(height,  width)
	elif face == Cube.Face.LEFT or face == Cube.Face.RIGHT:
		uv0 = Vector2(0,     height)
		uv1 = Vector2(width, height)
		uv2 = Vector2(width, 0)
		uv3 = Vector2(0,     0)
	else:
		uv0 = Vector2(0,     0)
		uv1 = Vector2(width, 0)
		uv2 = Vector2(width, height)
		uv3 = Vector2(0,     height)

	# UV2 — atlas tile info packed per vertex
	# x = tile's left edge in 0-1 UV space
	# y = tile's width in 0-1 UV space
	var uv_offset: Vector2
	match face:
		Cube.Face.TOP:    uv_offset = block.uv_top
		Cube.Face.BOTTOM: uv_offset = block.uv_bottom
		_:                uv_offset = block.uv_side

	#print("block: ", block.block_name,
			  #" face: ", face,
			  #" uv_offset: ", uv_offset,
			  #" atlas: ", number_of_textures_in_atlas,
			  #" width: ", width,
			  #" height: ", height)

	var tile_x: float = uv_offset.x / number_of_textures_in_atlas.x
	var tile_w: float = 1.0 / number_of_textures_in_atlas.x
	var tile_uv2: Vector2 = Vector2(tile_x, tile_w)

	if normal.x > 0 or normal.y > 0 or normal.z > 0:
		vertices.append(v0); vertices.append(v1); vertices.append(v2)
		vertices.append(v0); vertices.append(v2); vertices.append(v3)
		uvs.append(uv0); uvs.append(uv1); uvs.append(uv2)
		uvs.append(uv0); uvs.append(uv2); uvs.append(uv3)
	else:
		vertices.append(v0); vertices.append(v2); vertices.append(v1)
		vertices.append(v0); vertices.append(v3); vertices.append(v2)
		uvs.append(uv0); uvs.append(uv2); uvs.append(uv1)
		uvs.append(uv0); uvs.append(uv3); uvs.append(uv2)

	# Same tile info for all 6 vertices
	for i in 6:
		normals.append(n)
		uv2s.append(tile_uv2)
