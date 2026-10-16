extends CharacterBody3D
class_name Golem

const StateMachineScript = preload("res://src/core/state_machine/state_machine.gd")
const WaveScene = preload("res://src/entities/golem/shockwave/wave.tscn")

const FORWARD_BLEND_PATH := "parameters/ForwardsWalkBlend/blend_amount"
const BACKWARD_BLEND_PATH := "parameters/BackwardBlend/blend_amount"
const ATTACK_REQUEST_PATH := "parameters/Attack/request"
const ATTACK_ACTIVE_PATH := "parameters/Attack/active"
const IDLE_MOVE_BLEND_PATH := "parameters/IdleMoveBlend/blend_amount"

signal ground_smashed(position: Vector3)
signal died

@export var player: Node3D
@export var movement_area: Area3D
@export var feet_marker: Marker3D
@export var activate_on_ready: bool = false
@export var turn_speed: float = 4.0
@export var smash_turn_speed_multiplier: float = 0.35
@export var facing_yaw_offset_degrees: float = 0.0
@export var forward_speed: float = 2.5
@export var strafe_speed_multiplier: float = 0.7
@export var backward_speed_multiplier: float = 0.55
@export var min_distance_to_player: float = 4.0
@export var recenter_stop_distance: float = 1.5
@export var idle_duration_min: float = 1.0
@export var idle_duration_max: float = 2.5
@export var move_duration_min: float = 2.0
@export var move_duration_max: float = 5.0
@export var mode_interval_min: float = 1.0
@export var mode_interval_max: float = 2.5
@export var attack_cooldown_min: float = 2.0
@export var attack_cooldown_max: float = 3.0
@export var smash_impact_delay: float = 0.65
@export var smash_safety_timeout: float = 3.0
@export var core_collision_layer: int = 4
@export var gravity_scale: float = 1.0

@onready var core_hitbox: Area3D = $CoreArea
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $Antagonist/AnimationPlayer

var state_machine: StateMachine
var attack_cooldown: float = 0.0
var desired_locomotion := Vector3.ZERO
var activation_requested: bool = false
var dead: bool = false
var active_waves: Array[Node3D] = []

func _ready() -> void:
	if player == null:
		player = get_parent().get_node_or_null("Player") as Node3D
	if movement_area == null:
		movement_area = get_parent().get_node_or_null("GolemMovementRange") as Area3D
	if core_hitbox == null:
		core_hitbox = get_node_or_null("CoreArea") as Area3D
	if movement_area:
		movement_area.monitoring = true
		movement_area.collision_mask |= collision_layer
	if core_hitbox:
		core_hitbox.collision_layer = core_collision_layer
		core_hitbox.monitoring = true
	animation_tree.active = false
	animation_player.play("StandUp")
	animation_player.pause()
	_set_locomotion_blends(0.0, 0.0, 0.0)

	var idle_state_script: Script = load("res://src/entities/golem/states/idle_state.gd")
	var move_state_script: Script = load("res://src/entities/golem/states/move_state.gd")
	var smash_state_script: Script = load("res://src/entities/golem/states/smash_ground_state.gd")
	var activate_state_script: Script = load("res://src/entities/golem/states/activate_state.gd")
	var death_state_script: Script = load("res://src/entities/golem/states/death_state.gd")
	state_machine = StateMachineScript.new()
	state_machine.add_state("idle", idle_state_script.new(self))
	state_machine.add_state("move", move_state_script.new(self))
	state_machine.add_state("smash_ground", smash_state_script.new(self))
	state_machine.add_state("activate", activate_state_script.new(self))
	state_machine.add_state("death", death_state_script.new(self))
	state_machine.set_initial_state("activate")
	if activate_on_ready:
		activate()

func _process(delta: float) -> void:
	if state_machine == null:
		return
	if state_machine.get_current_state_name() != "smash_ground" and not dead:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	state_machine.update(delta)
	_update_locomotion_blends(delta)

func _physics_process(delta: float) -> void:
	if state_machine == null:
		return
	if not is_on_floor() and not dead:
		velocity += get_gravity() * gravity_scale * delta
	state_machine.physics_update(delta)
	move_and_slide()

func activate() -> void:
	if dead:
		return
	activation_requested = true
	state_machine.change_state("activate")

func receive_beam(beam_data: BeamData) -> void:
	take_beam_hit(beam_data.is_powered)

func take_beam_hit(powered: bool) -> void:
	if powered:
		die()

func die() -> void:
	if dead:
		return
	dead = true
	state_machine.change_state("death")

func spawn_wave() -> void:
	if dead:
		return
	var wave := WaveScene.instantiate() as Shockwave
	if wave == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		wave.queue_free()
		return
	scene.add_child(wave)
	active_waves.append(wave)
	wave.start(feet_marker.global_position if feet_marker else global_position)

func cancel_waves() -> void:
	for wave in active_waves:
		if is_instance_valid(wave):
			wave.queue_free()
	active_waves.clear()

func face_player(delta: float, speed_multiplier: float = 1.0) -> void:
	if player == null:
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-offset.x, -offset.z) + deg_to_rad(facing_yaw_offset_degrees)
	rotation.y = rotate_toward(rotation.y, target_yaw, turn_speed * speed_multiplier * delta)

func set_locomotion(world_dir: Vector3, speed: float) -> void:
	world_dir.y = 0.0
	if world_dir.length_squared() <= 0.0001 or speed <= 0.0:
		desired_locomotion = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
		return
	desired_locomotion = world_dir.normalized()
	velocity.x = desired_locomotion.x * speed
	velocity.z = desired_locomotion.z * speed

func stop_locomotion() -> void:
	set_locomotion(Vector3.ZERO, 0.0)

func roll_attack_cooldown() -> void:
	attack_cooldown = randf_range(attack_cooldown_min, attack_cooldown_max)

func is_inside_movement_area() -> bool:
	return movement_area != null and movement_area.overlaps_body(self)

func movement_area_center() -> Vector3:
	return movement_area.global_position if movement_area else global_position

func _update_locomotion_blends(delta: float) -> void:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var forward_component := desired_locomotion.dot(forward)
	var right_component := desired_locomotion.dot(right)
	_set_locomotion_blends(right_component, -forward_component, 1.0 if desired_locomotion.length_squared() > 0.0001 else 0.0, delta)

func _set_locomotion_blends(right_target: float, backward_target: float, idle_move_target: float, delta: float = 0.0) -> void:
	if delta <= 0.0:
		animation_tree.set(FORWARD_BLEND_PATH, right_target)
		animation_tree.set(BACKWARD_BLEND_PATH, clampf(backward_target, 0.0, 1.0))
		animation_tree.set(IDLE_MOVE_BLEND_PATH, idle_move_target)
		return
	animation_tree.set(FORWARD_BLEND_PATH, move_toward(float(animation_tree.get(FORWARD_BLEND_PATH)), clampf(right_target, -1.0, 1.0), delta * 5.0))
	animation_tree.set(BACKWARD_BLEND_PATH, move_toward(float(animation_tree.get(BACKWARD_BLEND_PATH)), clampf(backward_target, 0.0, 1.0), delta * 5.0))
	animation_tree.set(IDLE_MOVE_BLEND_PATH, move_toward(float(animation_tree.get(IDLE_MOVE_BLEND_PATH)), idle_move_target, delta * 5.0))
