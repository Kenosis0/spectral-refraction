extends RefCounted
class_name StateMachine

var states: Dictionary = {}
var current_state: StateInterface
var current_state_name: String = ""
var _owner


func add_state(state_name: String, state: StateInterface) -> void:
	states[state_name.to_lower()] = state
	state.state_machine = self


func set_initial_state(state_name: String) -> void:
	change_state(state_name)


func change_state(new_state_name: String) -> void:
	var prev_state_name = current_state_name
	if current_state:
		current_state.exit_state()
	
	current_state_name = new_state_name.to_lower()
	current_state = states.get(current_state_name)
	
	if current_state:
		current_state.enter_state(prev_state_name)
	else:
		push_error("State not found: " + new_state_name)


func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func get_current_state_name() -> String:
	return current_state_name

	
