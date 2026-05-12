extends Node
class_name NPC

# Identity
var name: String
var id: int
var family_name: String
var age: int
var family_id: int

# Location
var current_position: Vector2i
var current_location: Location
var target_position: Vector2i
var path: Array = []  # Path to target (array of Vector2i)

# State
var stress: float = 0.0
var hunger: float = 0.0
var fatigue: float = 0.0
var is_alive: bool = true

# Work
var job_type: String  # "logger", "miller", "tavern_keeper", "blacksmith", "none"
var assigned_home: Location
var assigned_workplace: Location

# Relationships
var relationships: Dictionary = {}  # {npc_id: relationship_value}

# History (imperfect memory)
var event_memory: Array = []
var crossing_memory: Array = []  # Specific memory of crossing paths
var max_memory_size: int = 500

# Traits (affect behavior)
var traits: Dictionary = {
	"aggression": randf_range(0.0, 1.0),
	"sociability": randf_range(0.0, 1.0),
	"stability": randf_range(0.0, 1.0),
}

# Current state
var current_action: String = ""
var action_target: int = -1

func _init(p_id: int, p_name: String, p_family_name: String, p_age: int, p_family_id: int) -> void:
	id = p_id
	name = p_name
	family_name = p_family_name
	age = p_age
	family_id = p_family_id
	current_position = Vector2i.ZERO
	target_position = Vector2i.ZERO

func tick(current_tick: int, all_npcs: Array, world: World) -> void:
	if not is_alive:
		return
	
	# Modify stats based on age
	apply_age_effects()
	
	# Decay/change state over time
	stress = clamp(stress - 0.01, 0.0, 100.0)
	hunger = clamp(hunger + 0.05, 0.0, 100.0)
	fatigue = clamp(fatigue + 0.02, 0.0, 100.0)
	
	# Decide what to do this tick
	decide_action(current_tick, all_npcs)
	
	# Execute movement/action
	execute_action(current_tick, all_npcs, world)
	
	# Check for crossing paths with other NPCs
	check_crossing_paths(current_tick, all_npcs)

func apply_age_effects() -> void:
	"""Modify stats based on age"""
	if age < 18:
		# Children are more resilient to stress but tire easier
		fatigue += 0.01
		stress = clamp(stress - 0.02, 0.0, 100.0)
	elif age > 65:
		# Elderly tire more easily and are more stressed
		fatigue += 0.03
		stress += 0.02
		hunger += 0.01

func decide_action(current_tick: int, all_npcs: Array) -> void:
	"""Decide where to go and what to do"""
	
	var hour = (current_tick % 24)
	var is_work_hours = hour >= 6 and hour < 18
	
	# If not of working age, different behavior
	if age < 14:
		# Children stay home or play
		if randf() > 0.7:
			current_action = "wander_home"
		else:
			current_action = "idle_home"
		return
	
	# Priority-based decision making
	if hunger > 70:
		current_action = "go_eat"
		return
	
	if fatigue > 80:
		current_action = "go_sleep"
		return
	
	if stress > 75:
		if traits["aggression"] > 0.7:
			current_action = "seek_confrontation"
		else:
			current_action = "isolate"
		return
	
	# Normal day/night cycle
	if is_work_hours and age >= 14:
		current_action = "go_to_work"
	else:
		# Evening: socialize or rest
		if randf() > 0.6:
			current_action = "socialize"
		else:
			current_action = "go_home"

func execute_action(current_tick: int, all_npcs: Array, world: World) -> void:
	"""Execute the decided action"""
	
	match current_action:
		"go_sleep":
			target_position = assigned_home.position
			move_towards_target(world)
			if current_position == target_position:
				fatigue = clamp(fatigue - 40, 0.0, 100.0)
				current_location = assigned_home
				add_memory(current_tick, "slept", "Slept at home")
		
		"go_eat":
			target_position = assigned_home.position
			move_towards_target(world)
			if current_position == target_position:
				hunger = clamp(hunger - 30, 0.0, 100.0)
				current_location = assigned_home
				add_memory(current_tick, "ate", "Ate at home")
		
		"go_to_work":
			if assigned_workplace:
				target_position = assigned_workplace.position
				move_towards_target(world)
				if current_position == target_position:
					stress += 0.5
					current_location = assigned_workplace
					add_memory(current_tick, "worked", "Worked at %s" % assigned_workplace.id)
		
		"go_home":
			target_position = assigned_home.position
			move_towards_target(world)
			if current_position == target_position:
				current_location = assigned_home
				add_memory(current_tick, "returned_home", "Returned home")
		
		"socialize":
			# Pick a random social location
			var social_spots = ["tavern", "market", "church"]
			var random_spot = social_spots[randi() % social_spots.size()]
			var location = world.get_location_by_id(random_spot)
			if location:
				target_position = location.position
				move_towards_target(world)
				if current_position == target_position:
					stress = clamp(stress - 5, 0.0, 100.0)
					current_location = location
					add_memory(current_tick, "socialized", "Socialized at %s" % location.id)
		
		"isolate":
			target_position = assigned_home.position
			move_towards_target(world)
			if current_position == target_position:
				stress = clamp(stress - 3, 0.0, 100.0)
				current_location = assigned_home
		
		"seek_confrontation":
			# Move randomly (seeking conflict)
			var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
			var random_dir = directions[randi() % directions.size()]
			var next_pos = current_position + random_dir
			if world.is_passable(next_pos):
				current_position = next_pos
				current_location = world.get_location_at_position(next_pos)
		
		"wander_home", "idle_home":
			# Children stay near home
			target_position = assigned_home.position
			move_towards_target(world)
			current_location = world.get_location_at_position(current_position)

func move_towards_target(world: World) -> void:
	"""Move one step towards target using pathfinding"""
	if current_position == target_position:
		return
	
	# Generate path if we don't have one
	if path.size() == 0 or path[path.size() - 1] != target_position:
		path = a_star_pathfind(world, current_position, target_position)
	
	# Move along path
	if path.size() > 0:
		current_position = path.pop_front()

func a_star_pathfind(world: World, start: Vector2i, goal: Vector2i) -> Array:
	"""Simple A* pathfinding"""
	var open_set = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: heuristic(start, goal)}
	
	while open_set.size() > 0:
		# Find node with lowest f_score
		var current_idx = 0
		var current = open_set[0]
		for i in range(open_set.size()):
			if f_score.get(open_set[i], 999999) < f_score.get(current, 999999):
				current = open_set[i]
				current_idx = i
		
		if current == goal:
			# Reconstruct path
			var path_result = [current]
			while came_from.has(current):
				current = came_from[current]
				path_result.push_front(current)
			return path_result
		
		open_set.pop_at(current_idx)
		
		for neighbor in world.get_neighbors(current):
			var tentative_g = g_score.get(current, 999999) + 1
			
			if tentative_g < g_score.get(neighbor, 999999):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + heuristic(neighbor, goal)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	# No path found, return empty
	return []

func heuristic(pos: Vector2i, goal: Vector2i) -> int:
	"""Manhattan distance heuristic for A*"""
	return abs(pos.x - goal.x) + abs(pos.y - goal.y)

func check_crossing_paths(current_tick: int, all_npcs: Array) -> void:
	"""Check if we're crossing paths with other NPCs"""
	var directions = [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for other_npc in all_npcs:
		if other_npc.id == self.id or not other_npc.is_alive:
			continue
		
		# Check if adjacent or at same location
		var distance = current_position.distance_to(other_npc.current_position)
		if distance <= 1.0:  # Adjacent or same tile
			# Record crossing
			var crossing = {
				"tick": current_tick,
				"other_npc_id": other_npc.id,
				"other_npc_name": other_npc.name,
				"location": current_location.id if current_location else "unknown",
				"position": current_position
			}
			crossing_memory.append(crossing)
			
			# Update memory
			add_memory(current_tick, "crossed_paths", "Crossed paths with %s at %s" % [other_npc.name, current_location.id if current_location else "unknown"], other_npc.id)
			
			# Keep memory bounded
			if crossing_memory.size() > max_memory_size:
				crossing_memory.pop_front()

func add_memory(tick: int, event_type: String, description: String, other_npc_id: int = -1) -> void:
	var memory_entry = {
		"tick": tick,
		"event_type": event_type,
		"description": description,
		"other_npc_id": other_npc_id
	}
	
	event_memory.append(memory_entry)
	
	if event_memory.size() > max_memory_size:
		event_memory.pop_front()

func get_memory_history() -> Array:
	return event_memory.duplicate()

func initialize_relationship(other_id: int, initial_value: float = 0.0) -> void:
	relationships[other_id] = initial_value

func calculate_murder_motive(target_id: int) -> float:
	if not relationships.has(target_id):
		return 0.0
	
	var motive = 0.0
	
	# High stress is a major factor
	motive += stress * 0.5
	
	# Bad relationship is a major factor
	motive += max(0, -relationships[target_id])
	
	# Low stability increases motive
	motive += (1.0 - traits["stability"]) * 20
	
	# High aggression increases motive
	motive += traits["aggression"] * 15
	
	return clamp(motive, 0.0, 100.0)
