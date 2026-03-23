@tool
extends Node3D

# Used to preview blocks in the editor.
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
			
@export var texture_size: int = 16
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
	print("preview_block called")
	if block == null or material == null:
		return


	var atlas: Texture2D = (material as StandardMaterial3D).albedo_texture
	var atlas_width = atlas.get_size().x
	var tiles_wide = int(atlas_width / texture_size)

	# Remove existing preview meshes
	for child in get_children():
		if child is MeshInstance3D:
			child.free()

	# Create three quads showing top, side, bottom
	var faces = [
		{"uv": block.uv_top, "pos": Vector3(0, .5, 0), "label": "Top", 
			"rot": Basis.from_euler(Vector3(deg_to_rad(-90), 0, 0))},
		{"uv": block.uv_bottom, "pos": Vector3(0, -.5, 0), "label": "Bottom", 
			"rot": Basis.from_euler(Vector3(deg_to_rad(90), 0, 0))},
		{"uv": block.uv_side, "pos": Vector3(0, 0, .5), "label": "Front", 
			"rot": Basis.IDENTITY},
		{"uv": block.uv_side, "pos": Vector3(0, 0, -.5), "label": "Back", 
			"rot": Basis.from_euler(Vector3(0, deg_to_rad(180), 0))},
		{"uv": block.uv_side, "pos": Vector3(-.5, 0, 0), "label": "Left", 
			"rot": Basis.from_euler(Vector3(0, deg_to_rad(-90), 0))},
		{"uv": block.uv_side, "pos": Vector3(.5, 0, 0), "label": "Right", 
			"rot": Basis.from_euler(Vector3(0, deg_to_rad(90), 0))},
	]

	for face_data in faces:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = face_data["label"]
		mesh_instance.position = face_data["pos"]
		mesh_instance.transform = Transform3D(face_data["rot"], face_data["pos"])
		add_child(mesh_instance)
		mesh_instance.owner = get_tree().edited_scene_root

		var quad = QuadMesh.new()
		quad.size = Vector2(1, 1)
		quad.add_uv2 = false
		mesh_instance.mesh = quad

		var preview_material = StandardMaterial3D.new()
		preview_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		preview_material.albedo_texture = atlas

		# Calculate UV offset and scale to show just this tile
		#var atlas_width = atlas.get_size().x
		var atlas_height = atlas.get_size().y
		var tile_u = float(texture_size) / float(atlas_width)   # fraction of atlas one tile takes up horizontally
		var tile_v = float(texture_size) / float(atlas_height)  # fraction of atlas one tile takes up vertically

		# uv_offset moves to the right tile, uv_scale sizes it to one tile
		preview_material.uv1_offset = Vector3(
			face_data["uv"].x * tile_u,
			face_data["uv"].y * tile_v,
			0)
		preview_material.uv1_scale = Vector3(tile_u, tile_v, 1)

		mesh_instance.material_override = preview_material

		#var preview_material = StandardMaterial3D.new()
		#preview_material.albedo_texture = atlas
		#preview_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
#
		#var atlas_tex = AtlasTexture.new()
		#atlas_tex.atlas = atlas
		#atlas_tex.filter_clip = true
		#atlas_tex.region = Rect2(
			#face_data["uv"].x * texture_size,
			#face_data["uv"].y * texture_size,
		#texture_size,
		#texture_size)
		#preview_material.albedo_texture = atlas_tex
		#
		#print("Face: ", face_data["label"], " uv: ", face_data["uv"], " region: ", Rect2(
			#face_data["uv"].x * texture_size,
			#face_data["uv"].y * texture_size,
			#texture_size,
			#texture_size))
		#mesh_instance.material_override = preview_material
