extends Area2D

signal collected(value: int)

var value := 1
var pull_speed := 220.0
var player: Node2D

func _ready() -> void:
	name = "XPGem"
	collision_layer = 4
	collision_mask = 1
	var sprite := Sprite2D.new()
	sprite.texture = _load_png_texture("res://assets/sprites/gem.png")
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return
	if global_position.distance_to(player.global_position) < 110:
		global_position = global_position.move_toward(player.global_position, pull_speed * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		collected.emit(value)
		queue_free()

func _load_png_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image)
