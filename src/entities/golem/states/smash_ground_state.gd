extends StateInterface
class_name GolemSmashGroundState

var golem: Golem
var elapsed: float = 0.0
var impact_spawned: bool = false

func _init(p_golem: Golem) -> void:
	golem = p_golem

func enter_state(_prev_state: String = "") -> void:
	elapsed = 0.0
	impact_spawned = false
	golem.stop_locomotion()
	golem.animation_tree.set(Golem.ATTACK_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func update(delta: float) -> void:
	elapsed += delta
	if not impact_spawned and elapsed >= golem.smash_impact_delay:
		impact_spawned = true
		golem.spawn_wave()
		golem.ground_smashed.emit(golem.global_position)
	var active := bool(golem.animation_tree.get(Golem.ATTACK_ACTIVE_PATH))
	if (impact_spawned and not active and elapsed >= golem.smash_impact_delay + 0.1) or elapsed >= golem.smash_safety_timeout:
		golem.roll_attack_cooldown()
		state_machine.change_state("idle" if randf_range(0.0, 1.0) < 0.5 else "move")

func physics_update(delta: float) -> void:
	golem.face_player(delta, golem.smash_turn_speed_multiplier)
	golem.stop_locomotion()