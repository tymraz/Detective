extends CanvasLayer
class_name SimulationUI

# Signals
signal start_pressed
signal pause_pressed
signal resume_pressed
signal speed_changed(speed: int)
signal update_info

# UI Elements
var panel: Panel
var info_label: Label
var event_log: TextEdit
var button_container: VBoxContainer
var speed_container: VBoxContainer

var is_paused: bool = false
var event_log_entries: Array = []
var max_log_entries: int = 50

func _ready() -> void:
	create_ui()
	set_anchors_and_offsets(Control.ANCHOR_BEGIN, Control.ANCHOR_BEGIN, 0, 0, 1280, 720)

func create_ui() -> void:
	"""Create the entire UI from code"""
	
	# Main panel
	panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets(Control.ANCHOR_BEGIN, Control.ANCHOR_BEGIN, 10, 10, 1260, 710)
	panel.modulate = Color(0.1, 0.1, 0.1, 0.95)
	
	# Main container
	var main_container = VBoxContainer.new()
	panel.add_child(main_container)
	main_container.set_anchors_and_offsets(Control.ANCHOR_FILL, Control.ANCHOR_FILL, 10, 10, -10, -10)
	main_container.add_theme_constant_override("separation", 10)
	
	# Title
	var title = Label.new()
	main_container.add_child(title)
	title.text = "DETECTIVE - SIMULATION ENGINE"
	title.add_theme_font_size_override("font_size", 24)
	var title_font = preload("res://assets/fonts/default_font.tres") if ResourceLoader.exists("res://assets/fonts/default_font.tres") else null
	
	# Info panel (time, status)
	info_label = Label.new()
	main_container.add_child(info_label)
	info_label.text = "Day: 0 | Hour: 0 | NPCs: 0/0 | Status: STOPPED"
	info_label.add_theme_font_size_override("font_size", 14)
	
	# Horizontal container for controls and log
	var h_container = HBoxContainer.new()
	main_container.add_child(h_container)
	h_container.set_custom_minimum_size(Vector2(0, 400))
	h_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h_container.add_theme_constant_override("separation", 10)
	
	# Left side - Controls
	var control_panel = VBoxContainer.new()
	h_container.add_child(control_panel)
	control_panel.set_custom_minimum_size(Vector2(200, 0))
	control_panel.add_theme_constant_override("separation", 8)
	
	# Control label
	var control_label = Label.new()
	control_panel.add_child(control_label)
	control_label.text = "CONTROLS"
	control_label.add_theme_font_size_override("font_size", 12)
	
	# Start button
	var start_button = Button.new()
	control_panel.add_child(start_button)
	start_button.text = "START"
	start_button.pressed.connect(func(): start_pressed.emit())
	
	# Pause/Resume button
	var pause_button = Button.new()
	control_panel.add_child(pause_button)
	pause_button.text = "PAUSE"
	pause_button.pressed.connect(func(): 
		if not is_paused:
			is_paused = true
			pause_button.text = "RESUME"
			pause_pressed.emit()
		else:
			is_paused = false
			pause_button.text = "PAUSE"
			resume_pressed.emit()
	)
	
	# Speed label
	var speed_label = Label.new()
	control_panel.add_child(speed_label)
	speed_label.text = "SPEED"
	speed_label.add_theme_font_size_override("font_size", 12)
	
	# Speed buttons
	speed_container = VBoxContainer.new()
	control_panel.add_child(speed_container)
	speed_container.add_theme_constant_override("separation", 4)
	
	var speeds = [
		{"label": "1x (1 tick/frame)", "value": 1},
		{"label": "10x (10 ticks/frame)", "value": 10},
		{"label": "100x (100 ticks/frame)", "value": 100},
		{"label": "1000x (1000 ticks/frame)", "value": 1000}
	]
	
	for speed_option in speeds:
		var speed_button = Button.new()
		speed_container.add_child(speed_button)
		speed_button.text = speed_option["label"]
		var speed_val = speed_option["value"]
		speed_button.pressed.connect(func(): speed_changed.emit(speed_val))
	
	# Right side - Event log
	var log_panel = VBoxContainer.new()
	h_container.add_child(log_panel)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.add_theme_constant_override("separation", 5)
	
	var log_label = Label.new()
	log_panel.add_child(log_label)
	log_label.text = "EVENT LOG"
	log_label.add_theme_font_size_override("font_size", 12)
	
	event_log = TextEdit.new()
	log_panel.add_child(event_log)
	event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_log.read_only = true
	event_log.text = "Simulation ready. Press START to begin.\n"
	event_log.custom_minimum_size = Vector2(0, 300)
	
	# Footer
	var footer = Label.new()
	main_container.add_child(footer)
	footer.text = "Press START to begin the simulation. The game will run until a murder occurs and the body is discovered."
	footer.add_theme_font_size_override("font_size", 11)
	
	# Update info every frame
	set_process(true)

func _process(delta: float) -> void:
	"""Update UI every frame"""
	update_info.emit()
	
	# Get current state (will be provided by SimulationManager)
	var state = get_tree().root.get_child(0).get_simulation_state() if get_tree().root.get_child(0).has_method("get_simulation_state") else null
	
	if state:
		var status = "RUNNING"
		if not get_tree().root.get_child(0).is_running:
			status = "STOPPED"
		elif is_paused:
			status = "PAUSED"
		
		var murder_status = ""
		if state["murder_occurred"]:
			murder_status = " | MURDER!"
		if state["body_discovered"]:
			murder_status = " | BODY FOUND!"
		
		info_label.text = "Day: %d | Hour: %02d | NPCs: %d/%d | Status: %s%s" % [
			state["day"],
			state["hour"],
			state["npcs_alive"],
			state["total_npcs"],
			status,
			murder_status
		]

func log_event(event: String) -> void:
	"""Add an event to the log"""
	event_log_entries.append(event)
	
	# Keep log size reasonable
	if event_log_entries.size() > max_log_entries:
		event_log_entries.pop_front()
	
	# Update text
	event_log.text = "\n".join(event_log_entries)
	
	# Scroll to bottom
	event_log.scroll_vertical = INT_MAX

func simulation_ended(npcs: Array, murderer_id: int, victim_id: int) -> void:
	"""Called when simulation ends"""
	var end_text = "\n=== SIMULATION ENDED ===\n"
	
	if murderer_id != -1:
		end_text += "Murderer: %s\n" % npcs[murderer_id].name
		end_text += "Victim: %s\n" % npcs[victim_id].name
		end_text += "\nDetective Phase: Ready to investigate!"
	else:
		end_text += "No murder occurred."
	
	log_event(end_text)
