extends StateInterface
class_name GolemActivateState

var golem: Golem
var elapsed: float = 0.0
var duration: float = 0.0
var started: bool = false

func _init(p_golem: Golem) -> void:
	golem = p_golem

func enter_state(_prev_state: String = "") -> void:
	started = golem.activation_requested
	elapsed = 0.0
	golem.stop_locomotion()
	if not started:
		golem.animation_player.play("StandUp")
		golem.animation_player.pause()
		return
	golem.activation_requested = false
	golem.animation_player.play("StandUp")
	duration = golem.animation_player.get_animation("StandUp").length

func physics_update(delta: float) -> void:
	golem.face_player(delta)
	golem.stop_locomotion()
	if not started:
		return
	elapsed += delta
	if elapsed >= duration:
		golem.animation_player.seek(duration, true)
		golem.animation_player.pause()
		golem.animation_tree.active = true
		golem.roll_attack_cooldown()
		state_machine.change_state("idle")