extends CharacterBody3D

const StateMachineScript = preload("res://src/core/state_machine/state_machine.gd")
const IdleStateScript = preload("res://src/entities/player/states/idle_state.gd")
const WalkStateScript = preload("res://src/entities/player/states/walk_state.gd")
const RunStateScript = preload("res://src/entities/player/states/run_state.gd")
const JumpStateScript = preload("res://src/entities/player/states/jump_state.gd")
const FallStateScript = preload("res://src/entities/player/states/fall_state.gd")
const InteractingStateScript = preload("res://src/entities/player/states/interacting_state.gd")
const HitStateScript = preload("res://src/entities/player/states/hit_state.gd")
const DeathStateScript = preload("res://src/entities/player/states/death_state.gd")

signal health_changed(current: int, max: int)
signal player_hit
signal player_died

@onready var camera_rig: Node3D = %CameraPivot
@onready var player_camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var animation_tree: AnimationTree = $AnimationTree

@export var max_health: int = 3
@export var invincibility_time: float = 1.0

var aiming_at: Node3D
var state_machine: StateMachine
var health: int
var invincibility_remaining: float = 0.0

func _ready() -> void:
	add_to_group("player")
	max_health = maxi(max_health, 1)
	health = max_health
	animation_tree.active = true
	animation_tree.set("parameters/DeathBlend/blend_amount", 0.0)
	health_changed.emit(health, max_health)

	state_machine = StateMachineScript.new()
	state_machine.add_state("idle", IdleStateScript.new(self))
	state_machine.add_state("walk", WalkStateScript.new(self))
	state_machine.add_state("run", RunStateScript.new(self))
	state_machine.add_state("jump", JumpStateScript.new(self))
	state_machine.add_state("fall", FallStateScript.new(self))
	state_machine.add_state("interacting", InteractingStateScript.new(self))
	state_machine.add_state("hit", HitStateScript.new(self))
	state_machine.add_state("death", DeathStateScript.new(self))
	state_machine.set_initial_state("idle")

	get_tree().node_added.connect(_connect_crystal)
	_connect_existing_crystals()
	call_deferred("_connect_existing_crystals")

func _physics_process(delta: float) -> void:
	invincibility_remaining = maxf(invincibility_remaining - delta, 0.0)
	if health <= 0:
		velocity = Vector3.ZERO
		return
	if aiming_at != null:
		velocity = Vector3.ZERO
		if state_machine.get_current_state_name() != "interacting":
			state_machine.change_state("interacting")
		state_machine.physics_update(delta)
		return
	if state_machine.get_current_state_name() == "hit":
		velocity = Vector3.ZERO
		state_machine.physics_update(delta)
		return
	state_machine.physics_update(delta)


func take_damage(amount: int = 1) -> void:
	if health <= 0 or invincibility_remaining > 0.0:
		return

	health = maxi(health - maxi(amount, 1), 0)
	invincibility_remaining = invincibility_time
	health_changed.emit(health, max_health)
	player_hit.emit()

	if health == 0:
		if aiming_at != null and aiming_at.has_method("_end_aim"):
			aiming_at._end_aim()
		state_machine.change_state("death")
		player_died.emit()
		# TODO: Game over/restart systems can connect to player_died.
	elif aiming_at == null:
		state_machine.change_state("hit")


func respawn() -> void:
	health = max_health
	invincibility_remaining = 0.0
	animation_tree.set("parameters/DeathBlend/blend_amount", 0.0)
	state_machine.change_state("idle")
	health_changed.emit(health, max_health)


func get_camera_relative_direction(movement_input: Vector2) -> Vector3:
	var camera_forward := -camera_rig.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_rig.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	return (camera_right * movement_input.x - camera_forward * movement_input.y).normalized()


func apply_camera_relative_movement(movement_input: Vector2, speed: float, delta: float, rotation_speed: float) -> void:
	var direction := get_camera_relative_direction(movement_input)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	var target_angle := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)


func _connect_existing_crystals() -> void:
	for crystal in get_tree().get_nodes_in_group("crystal_mirrors"):
		_connect_crystal(crystal)
	var root := get_tree().current_scene if get_tree().current_scene else get_parent()
	if root:
		for child in root.find_children("*", "Node3D", true, false):
			_connect_crystal(child)

func _connect_crystal(node: Node) -> void:
	if node.has_signal("aim_started") and not node.aim_started.is_connected(_on_aim_started):
		node.aim_started.connect(_on_aim_started)
		node.aim_ended.connect(_on_aim_ended)

func _on_aim_started(crystal: Node3D) -> void:
	if health <= 0 or crystal == null:
		return

	# The crystal owns its collision-aware camera; the player only locks movement.
	aiming_at = crystal
	velocity = Vector3.ZERO
	camera_rig.set_look_enabled(false)
	player_camera.current = false
	if state_machine.get_current_state_name() != "interacting":
		state_machine.change_state("interacting")

func _on_aim_ended(crystal: Node3D) -> void:
	if crystal != aiming_at:
		return

	aiming_at = null
	velocity = Vector3.ZERO
	player_camera.current = true
	camera_rig.set_look_enabled(true)
	if health > 0 and state_machine.get_current_state_name() == "interacting":
		state_machine.change_state("idle")
