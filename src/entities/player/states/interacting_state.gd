extends StateInterface

const BLEND_AMOUNT := 0.0
const BLEND_TIME := 0.2

var player: CharacterBody3D

func _init(player_node: CharacterBody3D) -> void:
	player = player_node

func enter_state(_prev_state: String = "") -> void:
	print("Entering Interacting State")
	player.velocity = Vector3.ZERO
	var animation_tree: AnimationTree = player.get_node_or_null("AnimationTree")
	if animation_tree:
		var blend_tween := player.create_tween()
		blend_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		blend_tween.tween_property(animation_tree, "parameters/ActionBlend/blend_amount", BLEND_AMOUNT, BLEND_TIME)

func physics_update(_delta: float) -> void:
	player.velocity = Vector3.ZERO
	if player.get("aiming_at") == null:
		state_machine.change_state("idle")

func handle_input(_event: InputEvent) -> void:
	pass
