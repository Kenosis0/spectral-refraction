extends CanvasLayer

@export var fade_color: Color = Color(0.0, 0.0, 0.0, 0.86)
@export var fade_duration: float = 1.0

@onready var fade_screen: ColorRect = $FadeScreen
@onready var game_over_panel: Control = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/CenterContainer/VBoxContainer/RestartButton

var player: Node

func _ready() -> void:
	game_over_panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
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
	if player_node == null or not player_node.has_signal("player_died"):
		return
	player = player_node
	player.player_died.connect(_show_game_over)

func _show_game_over() -> void:
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_screen, "color", fade_color, fade_duration)
	tween.tween_property(game_over_panel, "modulate:a", 1.0, fade_duration)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()