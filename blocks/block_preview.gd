@tool
extends Node3D

# Used to preview blocks in the editor. Not yet a 1-to-1 preview - UVs are slightly different in-game
# and I haven't figured out why.

# Drag a block Resource file into this to preview that block.
@export var block: BlockType:
	set(value):
		block = value
		print("Block set to: ", block)
		if Engine.is_editor_hint() and block != null and material != null:
			preview_block()
			
@export var material: Material:
	set(value):
		material = value
		if Engine.is_editor_hint() and block != null and material != null:
			preview_block()
			
@export var texture_size: int = Settings.texture_size

@export var refresh: bool = false:
	set(value):
		refresh = value
		if Engine.is_editor_hint() and value == true and block != null and material != null:
			preview_block()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	if block == null or material == null:
		return
	preview_block()

func preview_block() -> void:
	if block == null or material == null:
		return

	var atlas: Texture2D = (material as StandardMaterial3D).albedo_texture
	var atlas_width = atlas.get_size().x
	var number_of_textures = Vector2(atlas_width / float(texture_size), 1)

	# Remove existing preview meshes
	var existing = get_node_or_null("CubePreview")
	if existing:
		existing.free()

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "CubePreview"
	add_child(mesh_instance)
	mesh_instance.owner = get_tree().edited_scene_root

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()

	for face in Cube.Face.values():
		var uv_offset: Vector2
		match face:
			Cube.Face.TOP:    uv_offset = block.uv_top
			Cube.Face.BOTTOM: uv_offset = block.uv_bottom
			_:                uv_offset = block.uv_side

		for triangle in Cube.FACE_INDICES[face]:
			for index in triangle:
				vertices.append(Cube.VERTICES[index])
				normals.append(Cube.FACE_NORMALS[face])
				var uv = (Cube.compute_uv_for_vertex(face, index) + uv_offset) / number_of_textures
				uvs.append(uv)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_mesh.surface_set_material(0, material)
	mesh_instance.mesh = new_mesh
