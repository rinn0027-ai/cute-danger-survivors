extends Area2D

var direction := Vector2.RIGHT
var speed := 420.0
var damage := 1
var lifetime := 1.6
var pierce := 0
var from_player := true
var sfx: Node = null   # set by main._fire_player_bullets() for hit sounds

func _ready() -> void:
	name = "Bullet"
	collision_layer = 8
	collision_mask = 2 if from_player else 1
	body_entered.connect(_on_body_entered)
	# 根据伤害等级决定颜色和大小
	var outer_color: Color
	var inner_color: Color
	var bullet_scale: float
	var hit_radius: float
	if from_player:
		if damage >= 3:
			outer_color = Color("#ff5500")   # 深橙红
			inner_color = Color("#ffcc44")
			bullet_scale = 1.25
			hit_radius   = 6.5
		elif damage >= 2:
			outer_color = Color("#ffaa00")   # 橙黄
			inner_color = Color("#ffee99")
			bullet_scale = 1.05
			hit_radius   = 5.5
		else:
			outer_color = Color("#ffd166")   # 默认黄
			inner_color = Color("#fff7c2")
			bullet_scale = 0.85
			hit_radius   = 4.5
	else:
		outer_color = Color("#ff4d6d")
		inner_color = Color("#ffd1dc")
		bullet_scale = 0.9
		hit_radius   = 5.0

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
	], {"y": outer_color, "w": inner_color})
	sprite.scale = Vector2(bullet_scale, bullet_scale)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = hit_radius
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
		if sfx != null:
			sfx.play_hit()
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
