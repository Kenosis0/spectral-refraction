extends CanvasLayer

@export var heart_texture: Texture2D = preload("res://assets/Heart.png")
@export var heart_size: Vector2 = Vector2(48.0, 48.0)
@export var heart_separation: int = 8
@export var lost_heart_modulate: Color = Color(0.25, 0.25, 0.25, 0.6)
@export var full_heart_modulate: Color = Color.WHITE
@export var lost_heart_flash: Color = Color(1.0, 0.15, 0.15, 1.0)

@onready var heart_row: HBoxContainer = $MarginContainer/HBoxContainer

var hearts: Array[TextureRect] = []
var player: Node
var displayed_health: int = -1

func _ready() -> void:
	heart_row.add_theme_constant_override("separation", heart_separation)
	_connect_player(get_tree().get_first_node_in_group("player"))
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_find_player")

func _find_player() -> void:
	if player == null:
		_connect_player(get_tree().get_first_node_in_group("player"))

func _on_node_added(node: Node) -> void:
	if player == null and node.is_in_group("player"):
		_connect_player(node)

func _connect_player(player_node: Node) -> void:
	if player_node == null or not player_node.has_signal("health_changed"):
		return
	player = player_node
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player_node.get("health"), player_node.get("max_health"))

func _on_health_changed(current: int, maximum: int) -> void:
	var previous_health := displayed_health
	displayed_health = current
	while hearts.size() < maximum:
		hearts.append(_create_heart(hearts.size()))
	while hearts.size() > maximum:
		hearts.pop_back().queue_free()

	for index in hearts.size():
		if index < current:
			hearts[index].modulate = full_heart_modulate
		elif previous_health < 0 or index < previous_health:
			_animate_lost_heart(hearts[index])
		else:
			hearts[index].modulate = lost_heart_modulate

func _create_heart(index: int) -> TextureRect:
	var heart := TextureRect.new()
	heart.name = "Heart%d" % index
	heart.texture = heart_texture
	heart.custom_minimum_size = heart_size
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	heart.modulate = full_heart_modulate
	heart.pivot_offset = heart_size * 0.5
	heart_row.add_child(heart)
	return heart

func _animate_lost_heart(heart: TextureRect) -> void:
	var tween := create_tween()
	tween.tween_property(heart, "scale", Vector2(1.3, 1.3), 0.08)
	tween.parallel().tween_property(heart, "modulate", lost_heart_flash, 0.08)
	tween.tween_property(heart, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(heart, "modulate", lost_heart_modulate, 0.12)