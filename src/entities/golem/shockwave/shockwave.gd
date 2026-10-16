extends Node3D
class_name Shockwave

signal player_hit(body: Node3D)
signal finished

@export var knockback_strength: float = 0.0
@export var max_radius: float = 50.0
@export var hit_height: float = 1.0
@export var ring_only: bool = true
@export var ring_thickness: float = 1.25
@export var debug_draw: bool = false
@export var cleanup_margin: float = 0.1
@export var hitbox_delay: float = 1.0

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var damage_area: Area3D = $DamageArea
@onready var collision_shape: CollisionShape3D = $DamageArea/CollisionShape3D
@onready var debug_mesh: MeshInstance3D = $DebugCylinder

var elapsed: float = 0.0
var started: bool = false
var hit_bodies: Dictionary[Node3D, bool] = {}
var cylinder: CylinderShape3D
var duration: float = 0.0

func _ready() -> void:
	cylinder = collision_shape.shape.duplicate() as CylinderShape3D
	collision_shape.shape = cylinder
	damage_area.collision_layer = 0
	damage_area.collision_mask = 1
	damage_area.monitoring = true
	debug_mesh.visible = debug_draw
	duration = particles.lifetime / maxf(particles.speed_scale, 0.001)
	var computed_radius := _compute_visual_max_radius()
	if computed_radius > 0.0:
		max_radius = computed_radius
	_update_hitbox(0.0)

func start(world_position: Vector3) -> void:
	global_position = world_position
	elapsed = 0.0
	started = true
	particles.emitting = true
	_update_hitbox(0.0)

func _physics_process(delta: float) -> void:
	if not started:
		return

	elapsed += delta
	var hitbox_elapsed := elapsed - hitbox_delay
	var hitbox_progress := clampf(hitbox_elapsed / duration, 0.0, 1.0)
	var hitbox_radius := max_radius * hitbox_progress
	_update_hitbox(hitbox_radius)
	_damage_overlaps(hitbox_radius)
	if elapsed > duration + cleanup_margin:
		damage_area.monitoring = false
		finished.emit()
		queue_free()

func _compute_visual_max_radius() -> float:
	var plane_mesh := particles.draw_pass_1 as PlaneMesh
	var process_material := particles.process_material as ParticleProcessMaterial
	if plane_mesh == null or process_material == null:
		return 0.0
	var scale_curve := process_material.scale_curve
	if scale_curve == null or scale_curve.curve == null:
		return 0.0
	var end_scale = scale_curve.curve.sample_baked(1.0)
	var node_scale := maxf(absf(scale.x), absf(scale.z))
	var particle_scale := maxf(absf(particles.scale.x), absf(particles.scale.z))
	return plane_mesh.size.x * 0.5 * end_scale * node_scale * particle_scale

func _update_hitbox(radius: float) -> void:
	cylinder.radius = maxf(radius, 0.001)
	cylinder.height = hit_height
	collision_shape.position.y = hit_height * 0.5
	debug_mesh.position.y = hit_height * 0.5
	var debug_cylinder := debug_mesh.mesh as CylinderMesh
	if debug_cylinder:
		debug_cylinder.top_radius = cylinder.radius
		debug_cylinder.bottom_radius = cylinder.radius
		debug_cylinder.height = hit_height

func _damage_overlaps(radius: float) -> void:
	for body_variant in damage_area.get_overlapping_bodies():
		var body := body_variant as Node3D
		if body == null or hit_bodies.has(body):
			continue
		if ring_only and not _is_in_ring(body, radius):
			continue
		var player_body := body as CharacterBody3D
		if player_body == null or not player_body.is_on_floor():
			continue
		hit_bodies[body] = true
		var offset := body.global_position - global_position
		offset.y = 0.0
		print("Shockwave hit player: %s | radius: %.2f | distance: %.2f | elapsed: %.2f" % [body.name, radius, offset.length(), elapsed])
		_apply_damage(body)
		player_hit.emit(body)

func _is_in_ring(body: Node3D, radius: float) -> bool:
	if radius < ring_thickness:
		return false
	var offset := body.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= 0.001:
		return false
	return distance >= radius - ring_thickness and distance <= radius

func _apply_damage(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.call("take_damage", 1)
	if knockback_strength <= 0.0 or not body.has_method("apply_knockback"):
		return
	var direction := body.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		body.call("apply_knockback", direction.normalized() * knockback_strength)
