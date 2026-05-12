extends Node
class_name World

const GRID_WIDTH = 100
const GRID_HEIGHT = 100

var locations: Array = []
var grid: Array = []  # 2D grid to track which location is at each tile

func _init() -> void:
	# Initialize empty grid
	grid = []
	for x in range(GRID_WIDTH):
		var row = []
		for y in range(GRID_HEIGHT):
			row.append(null)
		grid.append(row)

func generate_logging_village() -> void:
	"""Generate a logging village with homes, forest, mill, and other amenities"""
	
	# Home locations (spread across map)
	create_location("home_1", Vector2i(10, 10), "home")
	create_location("home_2", Vector2i(85, 15), "home")
	create_location("home_3", Vector2i(20, 80), "home")
	
	# Central forest (main logging area)
	create_location("forest", Vector2i(70, 50), "forest")
	
	# Mill (processes logs)
	create_location("mill", Vector2i(65, 45), "mill")
	
	# Tavern (social hub)
	create_location("tavern", Vector2i(50, 50), "tavern")
	
	# Market (supplies)
	create_location("market", Vector2i(45, 40), "market")
	
	# Church (neutral social)
	create_location("church", Vector2i(30, 30), "church")
	
	# Blacksmith (tools/repairs)
	create_location("blacksmith", Vector2i(40, 60), "blacksmith")
	
	print("Village generated with %d locations" % locations.size())

func create_location(loc_id: String, position: Vector2i, loc_type: String) -> void:
	"""Create a location at a specific position"""
	var location = Location.new(loc_id, position, loc_type)
	locations.append(location)
	
	# Mark grid
	if position.x >= 0 and position.x < GRID_WIDTH and position.y >= 0 and position.y < GRID_HEIGHT:
		grid[position.x][position.y] = location

func get_location_by_id(loc_id: String) -> Location:
	"""Find a location by its ID"""
	for location in locations:
		if location.id == loc_id:
			return location
	return null

func get_location_at_position(pos: Vector2i) -> Location:
	"""Get the location at a specific grid position"""
	if pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT:
		return grid[pos.x][pos.y]
	return null

func is_passable(pos: Vector2i) -> bool:
	"""Check if a position is passable (not out of bounds)"""
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT

func get_distance(from: Vector2i, to: Vector2i) -> int:
	"""Manhattan distance between two positions"""
	return abs(from.x - to.x) + abs(from.y - to.y)

func get_neighbors(pos: Vector2i) -> Array:
	"""Get all valid neighboring tiles (4-directional)"""
	var neighbors = []
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for direction in directions:
		var neighbor_pos = pos + direction
		if is_passable(neighbor_pos):
			neighbors.append(neighbor_pos)
	
	return neighbors
