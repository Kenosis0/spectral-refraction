extends StateInterface

var player: CharacterBody3D
var previous_state: String = "idle"
var hit_timer: SceneTreeTimer

func _init(player_node: CharacterBody3D) -> void:
	player = player_node

func enter_state(prev_state: String = "") -> void:
	previous_state = prev_state if prev_state not in ["hit", "death", ""] else "idle"
	player.velocity = Vector3.ZERO
	var animation_tree: AnimationTree = player.get_node("AnimationTree")
	animation_tree.set("parameters/GotHit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	var animation_player := player.get_node("Body/AnimationPlayer") as AnimationPlayer
	var hit_animation := animation_player.get_animation("Hit")
	if hit_animation:
		hit_timer = player.get_tree().create_timer(hit_animation.length)
		hit_timer.timeout.connect(_on_hit_finished)
	else:
		_on_hit_finished()

func exit_state() -> void:
	hit_timer = null

func physics_update(_delta: float) -> void:
	player.velocity = Vector3.ZERO

func handle_input(_event: InputEvent) -> void:
	pass

func _on_hit_finished() -> void:
	if state_machine.get_current_state_name() != "hit" or player.get("health") <= 0:
		return
	state_machine.change_state(previous_state)