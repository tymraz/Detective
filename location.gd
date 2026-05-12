extends Node
class_name Location

var id: String
var position: Vector2i
var type: String  # "home", "forest", "mill", "tavern", "market", "church", "blacksmith"
var npcs_present: Array = []  # NPCs currently at this location

func _init(p_id: String, p_position: Vector2i, p_type: String) -> void:
	id = p_id
	position = p_position
	type = p_type

func add_npc(npc: NPC) -> void:
	if npc not in npcs_present:
		npcs_present.append(npc)

func remove_npc(npc: NPC) -> void:
	npcs_present.erase(npc)

func get_npcs() -> Array:
	return npcs_present.duplicate()
