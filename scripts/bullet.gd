extends Area2D

var direction := Vector2.RIGHT
var speed := 420.0
var damage := 1
var lifetime := 1.6
var pierce := 0
var from_player := true
var sfx: Node = null   # set by main._fire_player_bullets() for hit sounds
var size_mult := 1.0
var effect := ""
var homing_strength := 0.0
var split_on_hit := false
var split_scene: Script = null

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
		if effect == "void":
			outer_color = Color("#6d5dfc")
			inner_color = Color("#d2c7ff")
			bullet_scale = 1.55
			hit_radius = 8.0
		elif effect == "ember":
			outer_color = Color("#ff5d35")
			inner_color = Color("#ffd166")
			bullet_scale = 1.55
			hit_radius = 8.0
		elif damage >= 3:
			outer_color = Color("#ff5500")   # 深橙红
			inner_color = Color("#ffcc44")
			bullet_scale = 1.7
			hit_radius   = 8.5
		elif damage >= 2:
			outer_color = Color("#ffaa00")   # 橙黄
			inner_color = Color("#ffee99")
			bullet_scale = 1.45
			hit_radius   = 7.5
		else:
			outer_color = Color("#ffd166")   # 默认黄
			inner_color = Color("#fff7c2")
			bullet_scale = 1.18
			hit_radius   = 6.5
	else:
		outer_color = Color("#ff4d6d")
		inner_color = Color("#ffd1dc")
		bullet_scale = 1.35
		hit_radius   = 7.0

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
	sprite.scale = Vector2(bullet_scale * size_mult, bullet_scale * size_mult)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = hit_radius * size_mult
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if from_player and homing_strength > 0.0:
		var nearest := _nearest_enemy()
		if nearest != null:
			var wanted := global_position.direction_to(nearest.global_position)
			direction = direction.normalized().lerp(wanted, homing_strength * delta).normalized()
	global_position += direction.normalized() * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if from_player and body.has_method("take_damage"):
		body.take_damage(damage)
		if sfx != null:
			sfx.play_hit()
		if split_on_hit and split_scene != null:
			_spawn_split_shards()
		if pierce > 0:
			pierce -= 1
		else:
			queue_free()
	elif not from_player and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := 999999.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _spawn_split_shards() -> void:
	for angle in [-0.72, 0.72]:
		var shard: Area2D = split_scene.new()
		shard.from_player = true
		shard.direction = direction.rotated(angle)
		shard.speed = speed * 0.82
		shard.damage = max(1, int(ceil(float(damage) * 0.55)))
		shard.pierce = 0
		shard.lifetime = 0.55
		shard.size_mult = maxf(0.75, size_mult * 0.72)
		shard.effect = "void"
		shard.global_position = global_position + shard.direction * 8.0
		get_parent().add_child(shard)

func _make_pixel_texture(rows: Array, palette: Dictionary) -> Texture2D:
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row.substr(x, 1)
			image.set_pixel(x, y, palette.get(key, Color.TRANSPARENT))
	return ImageTexture.create_from_image(image)
