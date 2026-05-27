extends Area2D

signal picked(item_id: String)

var item_id := "damage"
var item_name := "Item"
var item_color := Color("#ffd166")

func _ready() -> void:
	name = "ItemPickup"
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	var sprite := Sprite2D.new()
	sprite.texture = _make_icon(item_color)
	sprite.scale = Vector2(2.4, 2.4)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18
	shape.shape = circle
	add_child(shape)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		picked.emit(item_id)
		queue_free()

func _make_icon(color: Color) -> Texture2D:
	return _make_pixel_texture([
		"................",
		".....oooooo.....",
		"...oooooooooo...",
		"..ooowwwwwwoo..",
		"..oowwwwwwwwoo..",
		".oowwwwwwwwwwoo.",
		".oowwwwwwwwwwoo.",
		".oowwwwwwwwwwoo.",
		".oowwwwwwwwwwoo.",
		"..oowwwwwwwwoo..",
		"..ooowwwwwwoo...",
		"...oooooooooo...",
		".....oooooo.....",
		"................",
		"................",
		"................"
	], {"o": color.darkened(0.25), "w": color})

func _make_pixel_texture(rows: Array, palette: Dictionary) -> Texture2D:
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row.substr(x, 1)
			image.set_pixel(x, y, palette.get(key, Color.TRANSPARENT))
	return ImageTexture.create_from_image(image)
