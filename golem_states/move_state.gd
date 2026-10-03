extends StateInterface
class_name GolemMoveState

enum Mode { APPROACH, STRAFE_LEFT, STRAFE_RIGHT, BACKWARD }

var golem: Golem
var mode: Mode = Mode.APPROACH
var elapsed: float = 0.0
var mode_elapsed: float = 0.0
var mode_duration: float = 0.0
var next_mode_time: float = 0.0
var recentering: bool = false
var previous_modes: Array[Mode] = []

func _init(p_golem: Golem) -> void:
	golem = p_golem

func enter_state(_prev_state: String = "") -> void:
	elapsed = 0.0
	mode_elapsed = 0.0
	next_mode_time = randf_range(golem.mode_interval_min, golem.mode_interval_max)
	mode_duration = randf_range(golem.move_duration_min, golem.move_duration_max)
	recentering = false
	_pick_mode()

func physics_update(delta: float) -> void:
	golem.face_player(delta)
	if golem.attack_cooldown <= 0.0:
		golem.stop_locomotion()
		state_machine.change_state("smash_ground")
		return
	if golem.movement_area != null and (recentering or not golem.is_inside_movement_area()):
		recentering = true
	if recentering:
		var to_center := golem.movement_area_center() - golem.global_position
		to_center.y = 0.0
		if golem.is_inside_movement_area() and to_center.length() <= golem.recenter_stop_distance:
			recentering = false
			_pick_mode()
		else:
			golem.set_locomotion(to_center, golem.forward_speed)
		return
	golem.set_locomotion(_direction_for_mode(), _speed_for_mode())
	elapsed += delta
	mode_elapsed += delta
	if mode_elapsed >= next_mode_time:
		mode_elapsed = 0.0
		next_mode_time = randf_range(golem.mode_interval_min, golem.mode_interval_max)
		_pick_mode()
	if elapsed >= mode_duration:
		state_machine.change_state("idle")

func _pick_mode() -> void:
	var candidates: Array[Mode] = [Mode.APPROACH, Mode.STRAFE_LEFT, Mode.STRAFE_RIGHT, Mode.BACKWARD]
	var selected := candidates[randi_range(0, candidates.size() - 1)]
	for _attempt in range(8):
		if previous_modes.size() < 2 or not previous_modes.has(selected):
			break
		selected = candidates[randi_range(0, candidates.size() - 1)]
	mode = selected
	previous_modes.append(mode)
	if previous_modes.size() > 2:
		previous_modes.pop_front()

func _direction_for_mode() -> Vector3:
	if golem.player == null:
		return Vector3.ZERO
	var to_player := golem.player.global_position - golem.global_position
	to_player.y = 0.0
	if to_player.length_squared() <= 0.0001:
		return Vector3.ZERO
	var toward := to_player.normalized()
	var right := Vector3(-toward.z, 0.0, toward.x)
	if mode == Mode.APPROACH and to_player.length() <= golem.min_distance_to_player:
		return right
	match mode:
		Mode.APPROACH:
			return toward
		Mode.STRAFE_LEFT:
			return -right
		Mode.STRAFE_RIGHT:
			return right
		Mode.BACKWARD:
			return -toward
	return Vector3.ZERO

func _speed_for_mode() -> float:
	if mode == Mode.BACKWARD:
		return golem.forward_speed * golem.backward_speed_multiplier
	if mode == Mode.STRAFE_LEFT or mode == Mode.STRAFE_RIGHT:
		return golem.forward_speed * golem.strafe_speed_multiplier
	return golem.forward_speed