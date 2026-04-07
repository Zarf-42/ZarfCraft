class_name ItemStack
extends Resource

# Represents a Slot in the player's Inventory.

@export var item_type: ItemType = null
@export var count: int = 0

func is_empty() -> bool:
	return item_type == null or count <= 0

func can_merge_with(other: ItemStack) -> bool:
	return not other.is_empty() and other.item_type == item_type

func add(amount: int) -> int:
	# Returns leftover that didn't fit
	var space: int = item_type.max_stack_size - count
	var added: int = min(amount, space)
	count += added
	return amount - added
