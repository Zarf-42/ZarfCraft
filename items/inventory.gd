class_name Inventory
extends Resource

# Inventory. Holds slots, defined in item_stack.

const HOTBAR_SIZE: int = 9
const STORAGE_SIZE: int = 27
const TOTAL_SIZE: int = HOTBAR_SIZE + STORAGE_SIZE  # 36

# Slots 0-8 are the hotbar, slots 9-35 are storage
var slots: Array[ItemStack] = []

func _init() -> void:
	slots.resize(TOTAL_SIZE)
	for i in range(TOTAL_SIZE):
		slots[i] = ItemStack.new()

func get_hotbar_slot(index: int) -> ItemStack:
	return slots[index]

func get_storage_slot(index: int) -> ItemStack:
	return slots[HOTBAR_SIZE + index]

# Tries to add items to the inventory, returns leftover count
func add_item(item_type: ItemType, count: int) -> int:
	var remaining: int = count

	# First pass — try to add to existing stacks of the same type
	for slot in slots:
		if remaining <= 0:
			break
		if not slot.is_empty() and slot.item_type == item_type:
			remaining = slot.add(remaining)

	# Second pass — fill empty slots
	for slot in slots:
		if remaining <= 0:
			break
		if slot.is_empty():
			slot.item_type = item_type
			remaining = slot.add(remaining)

	return remaining

func has_item(item_type: ItemType) -> bool:
	for slot in slots:
		if not slot.is_empty() and slot.item_type == item_type:
			return true
	return false
