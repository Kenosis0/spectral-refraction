extends StateInterface

const BLEND_AMOUNT := 0.0
const BLEND_TIME := 0.2

var player: CharacterBody3D


func _init(player_node: CharacterBody3D) -> void:
	player = player_node


func enter_state(_prev_state: String = "") -> void:
	var animation_tree: AnimationTree = player.get_node("AnimationTree")
	var blend_tween := player.create_tween()
	blend_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	blend_tween.tween_property(animation_tree, "parameters/ActionBlend/blend_amount", BLEND_AMOUNT, BLEND_TIME)


func physics_update(_delta: float) -> void:
	if not player.is_on_floor():
		state_machine.change_state("fall")
		return
	if Input.is_action_just_pressed("jump"):
		state_machine.change_state("jump")
		return

	var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if movement_input.length_squared() > 0.0:
		if Input.is_action_pressed("run"):
			state_machine.change_state("run")
		else:
			state_machine.change_state("walk")
