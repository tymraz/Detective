extends Node
class_name SimulationManager

var world: World
var families: Array = []
var npcs: Array = []
var current_tick: int = 0
var max_ticks: int = 100000

var murderer_id: int = -1
var victim_id: int = -1
var murder_tick: int = -1

# Simulation control
var is_running: bool = false
var is_paused: bool = false
var simulation_speed: int = 1  # Ticks per frame (1, 10, 100, 1000)
var simulation_started: bool = false

# UI References
@onready var ui: SimulationUI = $UI

func _ready() -> void:
	world = World.new()
	world.generate_logging_village()
	generate_families_and_npcs()
	
	# Connect UI signals
	if ui:
		ui.start_pressed.connect(_on_start_pressed)
		ui.pause_pressed.connect(_on_pause_pressed)
		ui.resume_pressed.connect(_on_resume_pressed)
		ui.speed_changed.connect(_on_speed_changed)
		ui.update_info.connect(get_simulation_state)

func _process(delta: float) -> void:
	if not is_running or is_paused:
		return
	
	# Run simulation_speed ticks per frame
	for _i in range(simulation_speed):
		if current_tick >= max_ticks:
			end_simulation()
			return
		
		# All NPCs take their turn
		for npc in npcs:
			npc.tick(current_tick, npcs, world)
		
		# Update location membership
		update_location_members()
		
		# Check for murder conditions (every 24 ticks = 1 day)
		if current_tick % 24 == 0:
			check_murder_conditions()
		
		# Check for body discovery
		if murderer_id != -1 and victim_id == -1:
			check_body_discovery()
		
		# End if body discovered
		if victim_id != -1:
			end_simulation()
			return
		
		current_tick += 1

func generate_families_and_npcs() -> void:
	"""Generate 3 families with 1-6 members each"""
	var family_names = ["Smith", "Johnson", "Williams"]
	var home_locations = ["home_1", "home_2", "home_3"]
	
	var npc_id_counter = 0
	
	for f_idx in range(3):
		var family_name = family_names[f_idx]
		var home_location = world.get_location_by_id(home_locations[f_idx])
		var family = Family.new(f_idx, family_name, home_location)
		
		# Generate family size (1-6 members)
		var family_size = randi_range(3, 6)  # At least parent(s), prefer 3-6
		
		# Create parents (age 35-55)
		var parent_count = 2 if randf() > 0.3 else 1
		for p in range(parent_count):
			var parent_age = randi_range(35, 55)
			var parent = NPC.new(npc_id_counter, "%s %s" % [family_name, ["Senior", "Junior"][p]], family_name, parent_age, f_idx)
			assign_job(parent)
			npcs.append(parent)
			family.add_member(parent)
			npc_id_counter += 1
		
		# Create children (age 5-30)
		var children_to_create = family_size - parent_count
		for c in range(children_to_create):
			var child_age = randi_range(5, 30)
			var child = NPC.new(npc_id_counter, "%s %s" % [family_name, "Child%d" % c], family_name, child_age, f_idx)
			assign_job(child)
			npcs.append(child)
			family.add_member(child)
			npc_id_counter += 1
		
		families.append(family)
		
		# Initialize relationships within family (positive)
		for member_a in family.get_members():
			for member_b in family.get_members():
				if member_a.id != member_b.id:
					member_a.initialize_relationship(member_b.id, randf_range(10, 30))
	
	# Initialize relationships between families (neutral to slightly negative)
	for npc_a in npcs:
		for npc_b in npcs:
			if npc_a.id != npc_b.id and npc_a.family_id != npc_b.family_id:
				if not npc_a.relationships.has(npc_b.id):
					npc_a.initialize_relationship(npc_b.id, randf_range(-10, 10))
	
	# Place NPCs at home
	for npc in npcs:
		npc.current_position = npc.assigned_home.position
		npc.current_location = npc.assigned_home
	
	print("Generated %d NPCs across 3 families" % npcs.size())

func assign_job(npc: NPC) -> void:
	"""Assign a job to an NPC based on age"""
	if npc.age < 14:
		npc.job_type = "none"
		return
	
	var jobs = ["logger", "logger", "logger", "miller", "tavern_keeper", "blacksmith"]
	var job = jobs[randi() % jobs.size()]
	npc.job_type = job
	
	# Assign workplace
	match job:
		"logger":
			npc.assigned_workplace = world.get_location_by_id("forest")
		"miller":
			npc.assigned_workplace = world.get_location_by_id("mill")
		"tavern_keeper":
			npc.assigned_workplace = world.get_location_by_id("tavern")
		"blacksmith":
			npc.assigned_workplace = world.get_location_by_id("blacksmith")

func update_location_members() -> void:
	"""Update which NPCs are at each location"""
	for location in world.locations:
		location.npcs_present.clear()
	
	for npc in npcs:
		if npc.current_location:
			npc.current_location.add_npc(npc)

func check_murder_conditions() -> void:
	if murderer_id != -1:
		return
	
	for killer in npcs:
		if not killer.is_alive or killer.age < 14:
			continue
		
		for potential_victim in npcs:
			if potential_victim.id == killer.id or not potential_victim.is_alive:
				continue
			
			var motive = killer.calculate_murder_motive(potential_victim.id)
			
			if motive > 60 and randf() < (motive / 100.0) * 0.01:
				commit_murder(killer.id, potential_victim.id)
				return

func commit_murder(killer_id: int, victim_id_param: int) -> void:
	murderer_id = killer_id
	victim_id = victim_id_param
	murder_tick = current_tick
	
	var killer = npcs[killer_id]
	var victim = npcs[victim_id_param]
	
	victim.is_alive = false
	killer.add_memory(current_tick, "murder", "Murdered %s" % victim.name, victim_id_param)
	
	print("\n[TICK %d] MURDER: %s killed %s!" % [current_tick, killer.name, victim.name])
	if ui:
		ui.log_event("MURDER: %s killed %s!" % [killer.name, victim.name])

func check_body_discovery() -> void:
	if current_tick % 24 != 0:
		return
	
	for npc in npcs:
		if npc.id == murderer_id or not npc.is_alive:
			continue
		
		var discovery_chance = npc.traits["sociability"] * 0.15
		if randf() < discovery_chance:
			print("[TICK %d] %s discovered the body of %s!" % [current_tick, npc.name, npcs[victim_id].name])
			if ui:
				ui.log_event("BODY FOUND: %s discovered %s's body!" % [npc.name, npcs[victim_id].name])
			npc.add_memory(current_tick, "discovered_body", "Found the body of %s" % npcs[victim_id].name)
			victim_id = -2
			return

func end_simulation() -> void:
	is_running = false
	
	print("\n=== SIMULATION END ===")
	print("Duration: %d ticks (~%.1f days)" % [current_tick, current_tick / 24.0])
	
	if murderer_id != -1:
		print("\nMurderer: %s (ID: %d)" % [npcs[murderer_id].name, murderer_id])
		print("Victim: %s (ID: %d)" % [npcs[victim_id].name, victim_id])
	
	if ui:
		ui.simulation_ended(npcs, murderer_id, victim_id)

func get_simulation_state() -> Dictionary:
	"""Return current simulation state for UI display"""
	var day = current_tick / 24
	var hour = current_tick % 24
	
	return {
		"tick": current_tick,
		"day": day,
		"hour": hour,
		"npcs_alive": npcs.filter(func(npc): return npc.is_alive).size(),
		"total_npcs": npcs.size(),
		"murderer_id": murderer_id,
		"victim_id": victim_id,
		"murder_occurred": murderer_id != -1,
		"body_discovered": victim_id != -1
	}

# UI Signal Handlers
func _on_start_pressed() -> void:
	if not simulation_started:
		is_running = true
		is_paused = false
		simulation_started = true
		print("=== SIMULATION STARTED ===")

func _on_pause_pressed() -> void:
	is_paused = true
	print("Simulation paused at tick %d" % current_tick)

func _on_resume_pressed() -> void:
	is_paused = false
	print("Simulation resumed")

func _on_speed_changed(speed: int) -> void:
	simulation_speed = speed
	print("Simulation speed changed to %d ticks per frame" % speed)
