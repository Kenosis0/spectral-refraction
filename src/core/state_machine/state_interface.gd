extends RefCounted
class_name StateInterface


var state_machine: StateMachine


func enter_state(prev_state: String = "") -> void:
	pass


func exit_state() -> void:
	pass


func update(delta: float) -> void:
	pass


func physics_update(delta: float) -> void:
	pass


func handle_input(event: InputEvent) -> void:
	pass
