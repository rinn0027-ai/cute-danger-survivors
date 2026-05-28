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

# ── 普通道具：每种道具都有独立轮廓，避免掉在地上只像一个点。 ─────────────
func _setup_item() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _make_icon(item_id, item_color)
	sprite.scale = Vector2(2.9, 2.9)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22
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
	outer.scale = Vector2(5.3, 5.3)
	add_child(outer)

	# 内部漩涡核心（反向旋转 + 呼吸缩放）
	var inner := Sprite2D.new()
	inner.texture = _make_portal_core()
	inner.scale = Vector2(3.2, 3.2)
	add_child(inner)

	# 外圈：持续顺时针旋转
	var rot_tween := create_tween().set_loops()
	rot_tween.tween_property(outer, "rotation", TAU, 3.2)

	# 内核：反向旋转
	var inner_rot_tween := create_tween().set_loops()
	inner_rot_tween.tween_property(inner, "rotation", -TAU, 2.1)

	# 内核：呼吸脉冲
	var pulse_tween := create_tween().set_loops()
	pulse_tween.tween_property(inner, "scale", Vector2(3.6, 3.6), 0.7)\
		.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(inner, "scale", Vector2(3.2, 3.2), 0.7)\
		.set_ease(Tween.EASE_IN_OUT)

# 外圈：有方向感的非对称环（旋转时可见）
func _make_portal_ring() -> Texture2D:
	return _make_pixel_texture([
		"................",
		"......ooo.......",
		"....oo...oo.....",
		"...o.......oo...",
		"..o...ww....o...",
		".o...w..w...o...",
		".o..w....w..o...",
		"..o..w....w.o...",
		"...o..w..w.o....",
		"....oo.ww.o.....",
		"......ooo.......",
		"....oo..........",
		"................",
		"................",
		"................",
		"................"
	], {
		"o": Color("#2348ff"),
		"w": Color("#75fff0")
	})

# 内核：同心圆辉光，白色中心
func _make_portal_core() -> Texture2D:
	return _make_pixel_texture([
		"................",
		"................",
		".......HH.......",
		".....HHwwH......",
		"....Hw..wwH.....",
		"...Hw....wH.....",
		"...Hww....H.....",
		"....Hww..H......",
		".....HwwHH......",
		".......HH.......",
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

func _make_icon(id: String, color: Color) -> Texture2D:
	var outer := color.darkened(0.34)
	var glow := color.lightened(0.2)
	var white := Color("#fff7d6")
	var rows: Array
	match id:
		"spark":
			rows = [
				"................",
				".......w........",
				"......www.......",
				"....wwooww......",
				"...wooooww......",
				"..wwooowwww.....",
				"....woooow......",
				"...wwooooww.....",
				"..wwooowwww.....",
				".....wwow.......",
				"......www.......",
				".......w........",
				"................",
				"................",
				"................",
				"................"
			]
		"triple":
			rows = [
				"................",
				"....oo..oo......",
				"...oww..wwo.....",
				"...oww..wwo.....",
				"....oo..oo......",
				".......oo.......",
				"......owwo......",
				"......owwo......",
				".......oo.......",
				"....oo....oo....",
				"...oww....wwo...",
				"...oww....wwo...",
				"....oo....oo....",
				"................",
				"................",
				"................"
			]
		"needle":
			rows = [
				"................",
				".......w........",
				"......wow.......",
				"......wow.......",
				".....woow.......",
				".....woow.......",
				"....wooow.......",
				"...wooow........",
				"..wooow.........",
				".wooow..........",
				".oooo...........",
				"..oo............",
				"................",
				"................",
				"................",
				"................"
			]
		"heart":
			rows = [
				"................",
				"....oo....oo....",
				"...owwo..owwo...",
				"..owwwwoowwwwo..",
				"..owwwwwwwwwwo..",
				"...owwwwwwwwo...",
				"....owwwwwwo....",
				".....owwwwo.....",
				"......owwo......",
				".......oo.......",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................"
			]
		"crown":
			rows = [
				"................",
				"...w...w...w....",
				"...ow.owo.wo....",
				"...owwowoowo....",
				"....ooooooo.....",
				"....owwwwwo.....",
				"....ooooooo.....",
				".....o...o......",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................"
			]
		_:
			rows = [
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
			]
	return _make_pixel_texture(rows, {"o": outer, "w": glow, "H": white})

func _make_pixel_texture(rows: Array, palette: Dictionary) -> Texture2D:
	var width := 1
	for row in rows:
		width = maxi(width, row.length())
	var image := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(width):
			var key := row.substr(x, 1) if x < row.length() else "."
			image.set_pixel(x, y, palette.get(key, Color.TRANSPARENT))
	return ImageTexture.create_from_image(image)
