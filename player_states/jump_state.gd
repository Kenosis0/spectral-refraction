extends StateInterface

const BLEND_AMOUNT := 0.0
const BLEND_TIME := 0.2
const JUMP_VELOCITY := 4.5
const WALK_SPEED := 5.0
const RUN_SPEED := 8.0
const ROTATION_SPEED := 12.0

var player: CharacterBody3D
var entered_this_frame := false


func _init(player_node: CharacterBody3D) -> void:
	player = player_node


func enter_state(_prev_state: String = "") -> void:
	var animation_tree: AnimationTree = player.get_node("AnimationTree")
	var blend_tween := player.create_tween()
	blend_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	blend_tween.tween_property(animation_tree, "parameters/ActionBlend/blend_amount", BLEND_AMOUNT, BLEND_TIME)
	player.velocity.y = JUMP_VELOCITY
	entered_this_frame = true


func physics_update(delta: float) -> void:
	if entered_this_frame:
		entered_this_frame = false
	elif player.is_on_floor():
		state_machine.change_state("idle")
		return

	player.velocity += player.get_gravity() * delta
	_apply_air_movement(delta)
	player.move_and_slide()
	if player.velocity.y <= 0.0:
		state_machine.change_state("fall")


func _apply_air_movement(delta: float) -> void:
	var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if movement_input.length_squared() == 0.0:
		return

	var movement_speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	player.apply_camera_relative_movement(movement_input, movement_speed, delta, ROTATION_SPEED)