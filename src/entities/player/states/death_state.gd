extends StateInterface

var player: CharacterBody3D

func _init(player_node: CharacterBody3D) -> void:
	player = player_node

func enter_state(_prev_state: String = "") -> void:
	player.velocity = Vector3.ZERO
	var animation_tree: AnimationTree = player.get_node("AnimationTree")
	animation_tree.set("parameters/DeathBlend/blend_amount", 1.0)

func physics_update(_delta: float) -> void:
	player.velocity = Vector3.ZERO

func handle_input(_event: InputEvent) -> void:
	pass