extends StateInterface
class_name GolemDeathState

var golem: Golem
var elapsed: float = 0.0
var duration: float = 0.0
var emitted: bool = false

func _init(p_golem: Golem) -> void:
	golem = p_golem

func enter_state(_prev_state: String = "") -> void:
	elapsed = 0.0
	emitted = false
	golem.stop_locomotion()
	golem.animation_tree.active = false
	if golem.core_hitbox:
		golem.core_hitbox.monitoring = false
		golem.core_hitbox.collision_layer = 0
	golem.animation_player.play("Death")
	duration = golem.animation_player.get_animation("Death").length

func update(delta: float) -> void:
	if emitted:
		return
	elapsed += delta
	if elapsed >= duration:
		golem.animation_player.seek(duration, true)
		golem.animation_player.pause()
		emitted = true
		golem.died.emit()

func physics_update(_delta: float) -> void:
	golem.stop_locomotion()