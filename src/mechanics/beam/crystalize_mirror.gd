extends Node3D

signal aim_started(crystal: Node3D)
signal aim_ended(crystal: Node3D)
signal power_changed(is_powered: bool)
signal beams_changed(count: int, required: int)

enum State { IDLE, AIMING }

@export var rotation_speed: float = 1.5
@export var beam_length: float = 20.0
@export var beam_area_light_length_offset: float = 0.0
@export var required_beams: int = 1
@export var input_grace_time: float = 0.1
@export var propagate_power: bool = true
@export var standard_beam_color: Color = Color(0.0, 1.0, 1.0, 1.0)
@export var powered_beam_color: Color = Color(1.0, 0.85, 0.2, 1.0)
@export var camera_transition_time: float = 0.6
@export var min_angle: float = -180.0
@export var max_angle: float = 180.0
@export var core_snap_speed: float = 10.0
@export var debug_beam := true
@export var snap_assist_duration: float = 0.25

@onready var interactable_area: Area3D = $InteractableArea
@onready var core_area: Area3D = $CoreBody/CoreArea
@onready var snap_area: Area3D = $Snap/SnapArea
@onready var beam_ray: RayCast3D = $BeamOrigin/BeamRayCast3D
@onready var snap_ray: RayCast3D = $BeamOrigin/SnapRayCast3D
@onready var beam_mesh: MeshInstance3D = $BeamOrigin/BeamMesh
@onready var beam_area_light: AreaLight3D = $BeamOrigin/BeamLight
@onready var mirror_mesh: MeshInstance3D = $CrystalizeMirror/Small
@onready var aim_camera_pivot: Node3D = $AimCameraPivot
@onready var aim_camera: Camera3D = $AimCameraPivot/SpringArm3D/Camera3D

var state: State = State.IDLE
var player_in_range := false
var powered := false
var _incoming_beams: Dictionary = {}
var _output_powered := false
var _beam_material: StandardMaterial3D
var _mirror_material: StandardMaterial3D
var _last_beam_count := -1
var _last_beam_collider: Object = null
var _last_beam_receiver: Node = null
var _core_snap_target: Node3D = null
var _last_snap_collider: Object = null
var _snap_tween: Tween = null

func _enter_tree() -> void:
	add_to_group("crystal_mirrors")

func _ready() -> void:
	add_to_group("crystal_mirrors")
	interactable_area.body_entered.connect(_on_body_entered)
	interactable_area.body_exited.connect(_on_body_exited)
	beam_ray.add_exception(interactable_area)
	beam_ray.add_exception(core_area)
	beam_ray.add_exception(snap_area)
	snap_ray.add_exception(interactable_area)
	snap_ray.add_exception(core_area)
	snap_ray.add_exception(snap_area)
	aim_camera.current = false
	_beam_material = beam_mesh.get_active_material(0) as StandardMaterial3D
	if _beam_material:
		_beam_material = _beam_material.duplicate() as StandardMaterial3D
		beam_mesh.material_override = _beam_material
	_mirror_material = mirror_mesh.get_active_material(0) as StandardMaterial3D
	if _mirror_material:
		_mirror_material = _mirror_material.duplicate() as StandardMaterial3D
		mirror_mesh.material_override = _mirror_material
	beam_ray.target_position = Vector3(0.0, 0.0, -beam_length)
	snap_ray.target_position = Vector3(0.0, 0.0, -beam_length)
	_update_beam(0.0)

func _physics_process(delta: float) -> void:
	_update_power_state()
	if state == State.AIMING:
		var input := Input.get_axis("left", "right")
		if not is_zero_approx(input):
			rotate_y(input * rotation_speed * delta)
			rotation.y = clamp(rotation.y, deg_to_rad(min_angle), deg_to_rad(max_angle))

	_update_beam(delta)

func _unhandled_input(event: InputEvent) -> void:
	# The crystal owns interaction state; the player only responds to these signals.
	if state != State.AIMING and not player_in_range:
		return

	if event.is_action_pressed("interact", false):
		if state == State.IDLE:
			state = State.AIMING
			aim_camera.current = true
			aim_started.emit(self)
		else:
			_end_aim()
		get_viewport().set_input_as_handled()

func _end_aim() -> void:
	if state != State.AIMING:
		return
	state = State.IDLE
	_stop_snap_tween()
	aim_camera.current = false
	aim_ended.emit(self)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player"):
		player_in_range = false

func _update_beam(delta: float) -> void:
	if not powered:
		_core_snap_target = null
		_last_snap_collider = null
		_stop_snap_tween()
		_debug_beam_result(null, null)
		beam_mesh.visible = false
		beam_area_light.visible = false
		_update_beam_visual(_power_ratio(), _output_powered)
		return

	beam_mesh.visible = true
	beam_area_light.visible = true
	# A unit-length cylinder is stretched along local -Z to the ray's hit distance.
	beam_ray.target_position = Vector3(0.0, 0.0, -beam_length)
	snap_ray.target_position = Vector3(0.0, 0.0, -beam_length)
	beam_ray.force_raycast_update()
	snap_ray.force_raycast_update()
	var distance := beam_length
	if beam_ray.is_colliding():
		distance = beam_ray.to_local(beam_ray.get_collision_point()).length()
	distance = clamp(distance, 0.05, beam_length)
	var beam_midpoint := beam_ray.position + Vector3(0.0, 0.0, -distance * 0.5)
	beam_mesh.position = beam_midpoint
	beam_mesh.scale = Vector3(1.0, distance, 1.0)
	beam_area_light.position = beam_midpoint
	beam_area_light.area_size.x = maxf(0.01, distance + beam_area_light_length_offset)
	_update_beam_visual(_power_ratio(), _output_powered)

	var snap_collider: Object = null
	if snap_ray.is_colliding():
		snap_collider = snap_ray.get_collider()
	if snap_collider != _last_snap_collider:
		if snap_collider:
			_core_snap_target = _find_core_area(snap_collider)
			_start_snap_assist()
		else:
			_core_snap_target = null
			_stop_snap_tween()
		_last_snap_collider = snap_collider

	if beam_ray.is_colliding():
		var collider := beam_ray.get_collider()
		var receiver := _find_beam_receiver(collider)
		_debug_beam_result(collider, receiver)
		if receiver and _is_core_area_hit(collider):
			receiver.receive_beam(_make_output_beam())
	else:
		_core_snap_target = null
		_debug_beam_result(null, null)


func receive_beam(beam_data: BeamData) -> void:
	if beam_data == null or beam_data.source == null:
		return
	if beam_data.has_passed(get_instance_id()):
		return
	_incoming_beams[beam_data.source.get_instance_id()] = {
		"last_seen": Time.get_ticks_msec() * 0.001,
		"is_powered": beam_data.is_powered,
		"chain": beam_data.chain,
	}


func _update_power_state() -> void:
	var now := Time.get_ticks_msec() * 0.001
	var expired_sources: Array[int] = []
	var incoming_powered := false
	for source_id: int in _incoming_beams:
		var entry: Dictionary = _incoming_beams[source_id]
		if now - float(entry["last_seen"]) > maxf(0.0, input_grace_time):
			expired_sources.append(source_id)
		else:
			incoming_powered = incoming_powered or bool(entry["is_powered"])
	for source_id: int in expired_sources:
		_incoming_beams.erase(source_id)

	var count := _incoming_beams.size()
	var next_powered := count >= maxi(1, required_beams)
	var next_output_powered := next_powered and (required_beams >= 2 or (propagate_power and incoming_powered))
	if next_powered != powered:
		powered = next_powered
		power_changed.emit(powered)
	if count != _last_beam_count:
		_last_beam_count = count
		beams_changed.emit(count, maxi(1, required_beams))
	_output_powered = next_output_powered


func _make_output_beam() -> BeamData:
	var passed_chain: Array[int] = []
	for entry: Dictionary in _incoming_beams.values():
		for instance_id: int in entry["chain"]:
			if instance_id not in passed_chain:
				passed_chain.append(instance_id)
	passed_chain.append(get_instance_id())
	return BeamData.new(self, _output_powered, passed_chain)


func _power_ratio() -> float:
	return clampf(float(_incoming_beams.size()) / float(maxi(1, required_beams)), 0.0, 1.0)


func _update_beam_visual(ratio: float, output_is_powered: bool) -> void:
	beam_area_light.light_energy = 16.0 * ratio
	beam_area_light.light_color = powered_beam_color if output_is_powered else standard_beam_color
	if _mirror_material:
		var mirror_color := powered_beam_color if powered else standard_beam_color
		_mirror_material.emission_enabled = ratio > 0.0
		_mirror_material.emission = mirror_color
		_mirror_material.emission_energy_multiplier = 5.0 * ratio
	if _beam_material:
		var color := powered_beam_color if output_is_powered else standard_beam_color
		_beam_material.albedo_color = color
		_beam_material.emission = color


func _debug_beam_result(collider: Object, receiver: Node) -> void:
	if not debug_beam:
		return
	if collider == _last_beam_collider and receiver == _last_beam_receiver:
		return
	_last_beam_collider = collider
	_last_beam_receiver = receiver
	if collider == null:
		print("[CrystalizeMirror] beam ray: no collision")
		return
	print("[CrystalizeMirror] beam ray hit: ", collider, " | receiver: ", receiver)


func _find_beam_receiver(collider: Object) -> Node:
	var node := collider as Node
	while node:
		if node != self and node.has_method("receive_beam"):
			return node
		node = node.get_parent()
	return null


func _find_core_area(collider: Object) -> Node3D:
	var node := collider as Node
	while node:
		if node is Area3D and node.name == "CoreArea":
			return node as Node3D
		if node is Area3D and node.name == "SnapArea":
			var crystal := node.get_parent()
			while crystal:
				var core_area := crystal.get_node_or_null("CoreBody/CoreArea") as Node3D
				if core_area:
					return core_area
				crystal = crystal.get_parent()
		node = node.get_parent()
	return null


func _is_core_area_hit(collider: Object) -> bool:
	var node := collider as Node
	while node:
		if node is Area3D and node.name == "CoreArea":
			return true
		node = node.get_parent()
	return false


func _start_snap_assist() -> void:
	if state != State.AIMING or _core_snap_target == null:
		return

	var direction := _core_snap_target.global_position - beam_ray.global_position
	if direction.length_squared() <= 0.0001:
		return

	var target_angle := atan2(-direction.x, -direction.z)
	_stop_snap_tween()
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(self, "rotation:y", target_angle, snap_assist_duration)


func _stop_snap_tween() -> void:
	if _snap_tween:
		_snap_tween.kill()
		_snap_tween = null
