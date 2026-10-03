extends StateInterface
class_name GolemIdleState

var golem: Golem
var elapsed: float = 0.0
var duration: float = 0.0

func _init(p_golem: Golem) -> void:
	golem = p_golem

func enter_state(_prev_state: String = "") -> void:
	elapsed = 0.0
	duration = randf_range(golem.idle_duration_min, golem.idle_duration_max)
	golem.stop_locomotion()

func physics_update(delta: float) -> void:
	golem.face_player(delta)
	golem.stop_locomotion()
	if golem.attack_cooldown <= 0.0:
		state_machine.change_state("smash_ground")
		return
	elapsed += delta
	if elapsed >= duration:
		state_machine.change_state("move")