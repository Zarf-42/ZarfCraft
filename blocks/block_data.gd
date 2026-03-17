class_name BlockType
extends Resource

# This is the Block Data resource prototype. Data that all block types need to have access to is
# defined here.
@export var block_name: String = ""
@export var index: int = 0
@export var breakable: bool = true # Blocks that players can't break in normal circumstances (like
# bedrock in Minecraft) should be set to False.
@export var hardness: int = 10 # This will determine how long it takes to break a block.

# This drop table defines what tools will let this block drop itself.
# We may need to modify this so that we can have a percentage chance of certain drops. I.E. a machine
# might have a chance of breaking and dropping a basic component instead of the machine, unless a
# special device is used. I.E. wrenches in Tekkit.
@export var drops: Dictionary = {
	"hand": [],
	"pickaxe": [],
	"axe": [],
	"hoe": [],
	"shovel": [],
}

# All block textures are combined into an atlas. We use the pixel coordinates to determine which
# texture this block uses.
#@export var uv_offset: Vector2 = Vector2.ZERO

# Enable multiple textures per block, I.E. grassy dirt
@export var uv_top: Vector2 = Vector2.ZERO
@export var uv_side: Vector2 = Vector2.ZERO
@export var uv_bottom: Vector2 = Vector2.ZERO

# Set to False for things like water, tall grass.
@export var is_solid: bool = true
