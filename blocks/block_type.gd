class_name BlockType
extends Resource

# This is the Block Data resource prototype. Data that all block types need to have access to is
# defined here.
@export var block_name: String = ""
@export var index: int = 0
@export var breakable: bool = true # Blocks that players can't break in normal circumstances (like
# bedrock in Minecraft) should be set to False.
@export var hardness: int = 10 # This will determine how long it takes to break a block by hand.
	# Maybe use division to determine how long it takes to break a block with the appropriate tool,
	# and another division to determine how much faster a higher-tier tool will operate?
@export var is_transparent: bool = false

# This drop table defines what tools will let this block drop itself or a modified version (I.E.
# a stone block dropping cobblestone).
# We may need to modify this so that we can have a percentage chance of certain drops. I.E. a machine
# might have a chance of breaking and dropping a basic component instead of the machine, unless a
# special device is used. I.E. wrenches in Tekkit.
@export var drops_hand: Array[DropTableEntry] = []
@export var drops_pickaxe: Array[DropTableEntry] = []
@export var drops_axe: Array[DropTableEntry] = []
@export var drops_hoe: Array[DropTableEntry] = []
@export var drops_shovel: Array[DropTableEntry] = []
#@export var drops: Dictionary = {
	#"hand": [] as Array[DropTableEntry],
	#"pickaxe": [] as Array[DropTableEntry],
	#"axe": [] as Array[DropTableEntry],
	#"hoe": [] as Array[DropTableEntry],
	#"shovel": [] as Array[DropTableEntry],
#}

# Enable multiple textures per block, I.E. grassy dirt
@export var uv_top: Vector2 = Vector2.ZERO
@export var uv_side: Vector2 = Vector2.ZERO
@export var uv_bottom: Vector2 = Vector2.ZERO

# Set to False for things like water, tall grass.
@export var is_solid: bool = true

var baked_uvs: Dictionary = {}

# This is called by BlockRegistry once per block type (Once for bedrock, once for stone, etc.). It
# Applies the appropriate texture from the Atlas onto the correct cube face, correctly handling
# cubes with multiple textures (again, like grassy dirt).
func precompute_uvs(atlas_size: Vector2) -> void:
	for face in Cube.precomp_indices.keys():
		var uv_offset: Vector2
		if face == Cube.Face.TOP:      uv_offset = uv_top
		elif face == Cube.Face.BOTTOM: uv_offset = uv_bottom
		else:                           uv_offset = uv_side
		var array_of_uvs: PackedVector2Array = PackedVector2Array()
		for vertice_index: int in Cube.precomp_indices[face]:
			array_of_uvs.append((Cube.face_vertex_uvs[face][vertice_index] + uv_offset) / atlas_size)
		baked_uvs[face] = array_of_uvs

# Drop Table
func get_drops(tool: String) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	var tool_drops: Array[DropTableEntry]
	match tool:
		"hand":    tool_drops = drops_hand
		"pickaxe": tool_drops = drops_pickaxe
		"axe":     tool_drops = drops_axe
		"hoe":     tool_drops = drops_hoe
		"shovel":  tool_drops = drops_shovel
		_:         return result

	for entry in tool_drops:
		if randf() > entry.chance:
			continue
		var stack := ItemStack.new()
		stack.item_type = entry.item_type
		stack.count = randi_range(entry.count_min, entry.count_max)
		result.append(stack)

	return result
