extends Area2D

var direction := Vector2.RIGHT
var speed := 420.0
var damage := 1
var lifetime := 1.6
var pierce := 0
var from_player := true
var velocity := Vector2.ZERO

func _ready() -> void:
	name = "Bullet"
	collision_layer = 8
	collision_mask = 2 if from_player else 1
	body_entered.connect(_on_body_entered)
	var sprite := Sprite2D.new()
	sprite.texture = _make_pixel_texture([
		"................",
		"................",
		"......yyyy......",
		".....ywwwwy.....",
		"....ywwwwwwy....",
		"....ywwwwwwy....",
		".....ywwwwy.....",
		"......yyyy......",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................"
	], {
		"y": Color("#ffd166") if from_player else Color("#ff4d6d"),
		"w": Color("#fff7c2") if from_player else Color("#ffd1dc")
	})
	sprite.scale = Vector2(1.35, 1.35)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	global_position += direction.normalized() * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if from_player and body.has_method("take_damage"):
		body.take_damage(damage)
		if pierce > 0:
			pierce -= 1
		else:
			queue_free()
	elif not from_player and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

func _make_pixel_texture(rows: Array, palette: Dictionary) -> Texture2D:
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row.substr(x, 1)
			image.set_pixel(x, y, palette.get(key, Color.TRANSPARENT))
	return ImageTexture.create_from_image(image)
