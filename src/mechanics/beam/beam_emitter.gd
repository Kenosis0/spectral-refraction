extends Node3D

const BeamDataScript = preload("res://src/mechanics/beam/beam_data.gd")

@export var beam_length: float = 20.0
@export var core_depth_offset: float = 0.0
@export var debug_beam := true

@onready var beam_ray: RayCast3D = $BeamOrigin/BeamRayCast3D
@onready var beam_mesh: MeshInstance3D = $BeamOrigin/BeamMesh
var _last_beam_collider: Object = null
var _last_beam_receiver: Node = null


func _ready() -> void:
	beam_ray.target_position = Vector3(0.0, 0.0, -beam_length)


func _process(_delta: float) -> void:
	_update_beam()


func _update_beam() -> void:
	beam_ray.target_position = Vector3(0.0, 0.0, -beam_length)
	beam_ray.force_raycast_update()

	var distance := beam_length
	if beam_ray.is_colliding():
		distance = beam_ray.to_local(beam_ray.get_collision_point()).length()
		var collider := beam_ray.get_collider()
		var receiver := _find_beam_receiver(collider)
		var beam_data := BeamDataScript.new(self)
		var core_area := _find_core_area(collider)
		if core_area:
			distance += core_depth_offset
		_debug_beam_result(collider, receiver)
		if receiver:
			receiver.receive_beam(beam_data)
	else:
		_debug_beam_result(null, null)

	distance = clamp(distance, 0.05, beam_length)
	beam_mesh.position = Vector3(0.0, 0.0, -distance * 0.5)
	beam_mesh.scale = Vector3(1.0, distance, 1.0)


func _find_beam_receiver(collider: Object) -> Node:
	var node := collider as Node
	while node:
		if node.has_method("receive_beam"):
			return node
		node = node.get_parent()
	return null


func _find_core_area(collider: Object) -> Node3D:
	var node := collider as Node
	while node:
		if node is Area3D and node.name == "CoreArea":
			return node as Node3D
		node = node.get_parent()
	return null


func _debug_beam_result(collider: Object, receiver: Node) -> void:
	if not debug_beam:
		return
	if collider == _last_beam_collider and receiver == _last_beam_receiver:
		return
	_last_beam_collider = collider
	_last_beam_receiver = receiver
	if collider == null:
		print("[BeamEmitter] beam ray: no collision")
		return
	print("[BeamEmitter] beam ray hit: ", collider, " | receiver: ", receiver)
