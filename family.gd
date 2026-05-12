extends Node
class_name Family

var family_id: int
var family_name: String
var members: Array = []
var home_location: Location

func _init(p_id: int, p_name: String, p_home: Location) -> void:
	family_id = p_id
	family_name = p_name
	home_location = p_home

func add_member(npc: NPC) -> void:
	members.append(npc)
	npc.assigned_home = home_location
	npc.family_id = family_id

func get_members() -> Array:
	return members.duplicate()

func get_adult_members() -> Array:
	var adults = []
	for member in members:
		if member.age >= 18:
			adults.append(member)
	return adults

func get_working_members() -> Array:
	var workers = []
	for member in members:
		if member.age >= 14 and member.age < 75:
			workers.append(member)
	return workers
