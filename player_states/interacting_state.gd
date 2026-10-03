extends StateInterface

var player: CharacterBody3D
var entered_this_frame := false

func _init(player_node: CharacterBody3D) -> void:
	player = player_node

func enter_state(_prev_state: String = "") -> void:
	print("Entering Interacting State")
	player.velocity = Vector3.ZERO
	entered_this_frame = true

func physics_update(_delta: float) -> void:
	player.velocity = Vector3.ZERO
	if entered_this_frame:
		entered_this_frame = false
		return

	if Input.is_action_just_pressed("interact"):
		state_machine.change_state("idle")

func handle_input(event: InputEvent) -> void:
	pass
