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

	if item_id == "stairs":
		_setup_portal()
	else:
		_setup_item()

# ── 普通道具（椭圆宝石图案，原样保留）────────────────────────────────
func _setup_item() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _make_icon(item_color)
	sprite.scale = Vector2(2.4, 2.4)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18
	shape.shape = circle
	add_child(shape)

# ── 传送门（完全不同的外观 + 动效）──────────────────────────────────
func _setup_portal() -> void:
	# 碰撞体（比道具更大，更容易踩到）
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30
	shape.shape = circle
	add_child(shape)

	# 外圈光晕（慢速旋转）
	var outer := Sprite2D.new()
	outer.texture = _make_portal_ring()
	outer.scale = Vector2(5.0, 5.0)
	add_child(outer)

	# 内部漩涡核心（呼吸缩放）
	var inner := Sprite2D.new()
	inner.texture = _make_portal_core()
	inner.scale = Vector2(3.2, 3.2)
	add_child(inner)

	# 文字标签（悬浮在传送门上方）
	var label := Label.new()
	label.text = "下一层"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#66ffee"))
	label.add_theme_color_override("font_outline_color", Color("#003322"))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-28, -54)
	add_child(label)

	# 外圈：持续顺时针旋转
	var rot_tween := create_tween().set_loops()
	rot_tween.tween_property(outer, "rotation", TAU, 4.0)

	# 内核：呼吸脉冲
	var pulse_tween := create_tween().set_loops()
	pulse_tween.tween_property(inner, "scale", Vector2(3.6, 3.6), 0.7)\
		.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(inner, "scale", Vector2(3.2, 3.2), 0.7)\
		.set_ease(Tween.EASE_IN_OUT)

	# 标签：亮度闪烁
	var blink_tween := create_tween().set_loops()
	blink_tween.tween_property(label, "modulate:a", 0.4, 0.55)
	blink_tween.tween_property(label, "modulate:a", 1.0, 0.55)

# 外圈：有方向感的非对称环（旋转时可见）
func _make_portal_ring() -> Texture2D:
	return _make_pixel_texture([
		"................",
		".....ooo.o......",
		"...oo.....oo....",
		"..o.........o...",
		".o...........o..",
		"o.............o.",
		"o.............o.",
		"o.............o.",
		".o...........o..",
		"..o.........o...",
		"...oo.....oo....",
		"......o.ooo.....",
		"................",
		"................",
		"................",
		"................"
	], {"o": Color("#1133dd")})

# 内核：同心圆辉光，白色中心
func _make_portal_core() -> Texture2D:
	return _make_pixel_texture([
		"................",
		"................",
		".....wwwwww.....",
		"...wwwHHHHwww...",
		"..wwHHHHHHHHww..",
		"..wHHHHHHHHHHw..",
		"..wHHHHHHHHHHw..",
		"..wwHHHHHHHHww..",
		"...wwwHHHHwww...",
		".....wwwwww.....",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................"
	], {
		"w": Color("#33ddbb"),   # 青绿辉光
		"H": Color("#ddfff8")    # 亮白核心
	})

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		picked.emit(item_id)
		queue_free()

func _make_icon(color: Color) -> Texture2D:
	return _make_pixel_texture([
		"................",
		".....oooooo.....",
		"...oooooooooo...",
		"..ooowwwwwwoo...",
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
