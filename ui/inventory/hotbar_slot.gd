class_name HotbarSlot
extends Panel

@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var mesh_instance: MeshInstance3D = $SubViewportContainer/SubViewport/MeshInstance3D
@onready var item_count_label: Label = $MarginContainer/ItemCount

var slot_index: int = 0
var is_selected: bool = false

# Style boxes for normal and selected states
var style_normal: StyleBoxFlat
var style_selected: StyleBoxFlat

func _ready() -> void:
	_build_styles()
	clear()

func _build_styles() -> void:
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.3, 0.3, 0.3, 1.0)

	style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_selected.border_width_left = 2
	style_selected.border_width_right = 2
	style_selected.border_width_top = 2
	style_selected.border_width_bottom = 2
	style_selected.border_color = Color(1.0, 1.0, 1.0, 1.0)

	add_theme_stylebox_override("panel", style_normal)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		add_theme_stylebox_override("panel", style_selected)
	else:
		add_theme_stylebox_override("panel", style_normal)

func update_slot(stack: ItemStack) -> void:
	if stack == null or stack.is_empty():
		clear()
		return

	# Update item count label
	if stack.count > 1:
		item_count_label.text = str(stack.count)
		item_count_label.visible = true
	else:
		item_count_label.visible = false

	# Build 3D preview mesh
	var block: BlockType = stack.item_type.get_placeable_block()
	if block == null:
		clear()
		return

	var num_tiles: Vector2 = EventBus.world_manager.atlas_tiles
	mesh_instance.mesh = Cube.build_block_mesh(block, 0.5, num_tiles)
	#mesh_instance.material_override = BlockRegistry.get_block_material(block)

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/item_preview.gdshader")
	mat.set_shader_parameter("texture_albedo", preload("res://blocks/textures/atlas.png"))
	mat.set_shader_parameter("roughness", 1.0)
	mat.set_shader_parameter("specular", 0.0)
	mesh_instance.material_override = mat

func clear() -> void:
	mesh_instance.mesh = null
	item_count_label.visible = false
