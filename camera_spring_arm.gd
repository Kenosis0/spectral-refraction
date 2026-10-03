extends Node3D

@export var mouse_sensitivity: float = 0.005
@export var min_pitch: float = -PI / 2.0
@export var max_pitch: float = PI / 4.0

@onready var spring_arm: SpringArm3D = get_node_or_null("SpringArm3D") as SpringArm3D

var look_enabled := true

func _ready() -> void:
	top_level = true
	global_position = get_parent().global_position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(_delta: float) -> void:
	global_position = get_parent().global_position


func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled:
		return
	if event is InputEventMouseMotion:
		rotation.y = wrapf(rotation.y - event.relative.x * mouse_sensitivity, 0.0, TAU)
		if spring_arm == null:
			return
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x - event.relative.y * mouse_sensitivity,
			min_pitch,
			max_pitch
		)

func set_look_enabled(enabled: bool) -> void:
	look_enabled = enabled
