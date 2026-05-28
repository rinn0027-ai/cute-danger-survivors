extends CharacterBody2D

signal defeated(enemy_pos: Vector2)

var target: Node2D
var speed := 72.0
var health := 3
var max_health := 3
var damage := 1
var visual_scale := 0.55
var enemy_type := "slime"       # 普通敌人类型
var movement_mode := "auto"     # boss 移动模式: auto / orbit / retreat / erratic
var archetype_color := Color.WHITE
var orbit_radius := 220.0
var animal_concept    := ""          # 概念精灵：skeleton/imp/cultist/spider/zombie/mimic/boss...
var concept_inner_color := Color.WHITE  # 高光/内部颜色

var sprite: Sprite2D
var _rng := RandomNumberGenerator.new()
var _wave_timer := 0.0          # bat 波浪计时
var _boss_angle := 0.0          # orbit / retreat 侧移角
var _erratic_dir := Vector2.ZERO
var _erratic_timer := 0.0
var _charge_timer := 0.0
var _charging := false
var _charge_dir := Vector2.ZERO

func _ready() -> void:
	_rng.randomize()
	max_health = health
	name = "Enemy"
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	if _is_boss_concept():
		_add_boss_presence_layers()
	sprite = Sprite2D.new()
	if animal_concept != "":
		# 所有有概念的敌人（boss 或新普通敌人）：内联像素画
		sprite.texture = _make_concept_texture()
		sprite.modulate = Color.WHITE    # 颜色已烘焙进纹理
	elif enemy_type == "bat":
		sprite.texture = _load_png_texture("res://assets/sprites/bat.png")
		sprite.modulate = archetype_color
	else:
		sprite.texture = _load_png_texture("res://assets/sprites/slime.png")
		sprite.modulate = archetype_color
	sprite.scale = Vector2(visual_scale, visual_scale)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	if animal_concept != "":
		circle.radius = maxf(10.0, 8.5 * visual_scale)
	elif visual_scale >= 2.5:
		circle.radius = 20
	elif enemy_type == "bat" or enemy_type == "imp":
		circle.radius = 8    # 小型/快速敌人
	else:
		circle.radius = 12   # 骷髅/僵尸/史莱姆
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	if target == null:
		return

	match movement_mode:
		"auto":
			_move_auto(delta)
		"orbit":
			_move_orbit(delta)
		"retreat":
			_move_retreat(delta)
		"erratic":
			_move_erratic(delta)

	move_and_slide()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider()
		if body != null and body.has_method("take_damage"):
			body.take_damage(damage)

# ── 普通追击 / bat 波浪 ──────────────────────────────────────────────
func _move_auto(delta: float) -> void:
	var dir := global_position.direction_to(target.global_position)
	if enemy_type == "bat":
		_wave_timer += delta
		var perp := Vector2(-dir.y, dir.x)
		velocity = dir * speed + perp * sin(_wave_timer * 3.5 * TAU) * 55.0
	else:
		velocity = dir * speed

# ── 环绕型：保持 orbit_radius 距离绕圈 ──────────────────────────────
func _move_orbit(delta: float) -> void:
	_boss_angle += speed / orbit_radius * delta
	var want_pos := target.global_position + Vector2.RIGHT.rotated(_boss_angle) * orbit_radius
	velocity = global_position.direction_to(want_pos) * speed * 1.6

# ── 保距型：维持距离，偶尔冲锋 ──────────────────────────────────────
func _move_retreat(delta: float) -> void:
	_charge_timer -= delta
	if _charging:
		velocity = _charge_dir * speed * 1.9
		if _charge_timer <= 0.0:
			_charging = false
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < 190.0:
		# 太近：后退
		velocity = global_position.direction_to(target.global_position) * -speed * 0.85
		if _charge_timer <= 0.0:
			# 蓄力冲锋
			_charging = true
			_charge_timer = 0.45
			_charge_dir = global_position.direction_to(target.global_position)
	elif dist > 320.0:
		velocity = global_position.direction_to(target.global_position) * speed * 0.65
	else:
		# 舒适区：横向游走
		_boss_angle += delta * 1.4
		velocity = Vector2.RIGHT.rotated(_boss_angle) * speed * 0.55

# ── 狂乱型：随机冲刺，偏向玩家 ─────────────────────────────────────
func _move_erratic(delta: float) -> void:
	_erratic_timer -= delta
	if _erratic_timer <= 0.0:
		_erratic_timer = _rng.randf_range(0.22, 0.65)
		if _rng.randf() < 0.62:
			var to_target := global_position.direction_to(target.global_position)
			_erratic_dir = to_target.rotated(_rng.randf_range(-PI / 2.2, PI / 2.2))
		else:
			_erratic_dir = Vector2.RIGHT.rotated(_rng.randf() * TAU)
	velocity = _erratic_dir * speed

func take_damage(amount: int) -> void:
	health -= amount
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(visual_scale * 1.14, visual_scale * 0.9), 0.05)
	tween.tween_property(sprite, "scale", Vector2(visual_scale, visual_scale), 0.08)
	if health <= 0:
		defeated.emit(global_position)
		queue_free()

func _is_boss_concept() -> bool:
	return animal_concept in ["watcher", "lich", "dragon", "demon", "minotaur"]

func _add_boss_presence_layers() -> void:
	var shadow := Sprite2D.new()
	shadow.name = "BossShadow"
	shadow.texture = _make_pixel_texture([
		"........................",
		"........................",
		"........................",
		"......oooooooooooo......",
		"....oooooooooooooooo....",
		"...oooo..........oooo...",
		"..ooo..............ooo..",
		"..oo................oo..",
		"..oo................oo..",
		"..ooo..............ooo..",
		"...oooo..........oooo...",
		"....oooooooooooooooo....",
		"......oooooooooooo......",
		"........................",
		"........................",
		"........................",
	], {"o": Color(0.0, 0.0, 0.0, 0.35)})
	shadow.position = Vector2(0, 18)
	shadow.scale = Vector2(visual_scale * 0.75, visual_scale * 0.45)
	shadow.z_index = -2
	add_child(shadow)
	var sigil := Sprite2D.new()
	sigil.name = "BossSigil"
	sigil.texture = _make_pixel_texture([
		"........................",
		"...........ww...........",
		".........w....w.........",
		".......w........w.......",
		".....w....oooo....w.....",
		"....w...oo....oo...w....",
		"...w...oo..ii..oo...w...",
		"...w...oo..ii..oo...w...",
		"....w...oo....oo...w....",
		".....w....oooo....w.....",
		".......w........w.......",
		".........w....w.........",
		"...........ww...........",
		"........................",
		"........................",
		"........................",
	], {"o": archetype_color.darkened(0.25), "i": concept_inner_color, "w": archetype_color.lightened(0.35)})
	sigil.scale = Vector2(visual_scale * 0.62, visual_scale * 0.62)
	sigil.z_index = -1
	add_child(sigil)

# ── 怪物像素精灵（16×16，o=外圈色，i=内部亮色，w=白色高光，.=透明）────
func _make_concept_texture() -> Texture2D:
	var o := archetype_color
	var i := concept_inner_color
	var w := Color.WHITE

	match animal_concept:

		# ════════ 普通怪物 ════════

		"skeleton":  # 骷髅：骷髅头+肋骨，直接追击
			return _make_pixel_texture([
				"......oooo......",
				".....oiiioo.....",
				"....oiiiiioo....",
				"....oi....io....",
				"....oiiiiioo....",
				"....oioiiio.....",
				"....oioooooo....",
				"....o.o..o.o....",
				"................",
				"....oooooooo....",
				"....o.oooo.o....",
				"....o.o..o.o....",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"imp":       # 小恶魔：翅膀+尖尾，狂乱冲刺
			return _make_pixel_texture([
				"o..............o",
				".o....oooo....o.",
				"..o..oiiiio..o..",
				"...oooiiiiooo...",
				"....oiwiiwio....",
				"....oiiiiioo....",
				".....oooooo.....",
				"......oooo......",
				".......oo.......",
				"......oooo......",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"zombie":    # 僵尸：双臂伸展，缓慢逼近
			return _make_pixel_texture([
				"o.....oooo.....o",
				"oo...oiiiio...oo",
				".oo..oiiiio..oo.",
				"..oo.oiwwio.oo..",
				"..oo.oiiiio.oo..",
				".....oooooo.....",
				"....oooooooo....",
				"....o.oooo.o....",
				"....oo....oo....",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"cultist":   # 地下邪教徒：兜帽、法袍、符文眼
			return _make_pixel_texture([
				"......oooo......",
				".....oiiiio.....",
				"....oiwiiwio....",
				"...oiiiiiiiio...",
				"...oioiiiioio...",
				"....oooiioo.....",
				"...ooiiiiioo....",
				"..ooiiiiiiiio...",
				"..ooiiooiiioo...",
				"...oo..oo..oo...",
				"....o......o....",
				"................",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"spider":    # 洞穴蛛形怪：大腹部、八足轮廓
			return _make_pixel_texture([
				"................",
				"..o..........o..",
				".o..oooooooo..o.",
				"o..oiiiiiiiio..o",
				"..oiiwiiwiiio...",
				".ooiiiiiiiiioo..",
				"o..oooooooo..o..",
				".o..o.oo.o..o...",
				"..o.o....o.o....",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"mimic":     # 宝箱怪：箱盖、牙齿、短腿
			return _make_pixel_texture([
				"................",
				"...oooooooooo...",
				"..oiiiiiiiiioo..",
				".oiiioooooiiio..",
				".oiiowwwwoiio...",
				".oiioiiiiioiio..",
				"..oooooooooooo..",
				"..ooiiiiiiiioo..",
				"..ooiiwwwwiioo..",
				"...oooooooooo...",
				"....o......o....",
				"................",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		# ════════ Boss 怪物 ════════

		"watcher":   # 眼球法师：中央眼、眼柄、漂浮触须
			return _make_pixel_texture([
				"..o..owoo..o....",
				"..o..ooo...o....",
				".ooooooiiooooo..",
				"oiiiiiwwiiiiioo.",
				"oiiiiiwwiiiiioo.",
				"oiiiiiiiiiiiioo.",
				".ooooooiiooooo..",
				"...o.........o..",
				"...ow.......wo..",
				"....o.......o...",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"lich":      # 巫妖：头戴王冠的骷髅巫师，飘动长袍
			return _make_pixel_texture([
				"...wowowo.......",
				"...oooooo.......",
				"...oiiiio.......",
				"..oii....iio....",
				"..oiiiiiiiio....",
				"..oioiiiiooo....",
				"...oooooooo.....",
				"..oooooooooo....",
				".oiiiiiiiiioo...",
				"oiiiiiiiiiiioo..",
				".oiiiiiiiiioo...",
				"..oooooooooo....",
				"...o..o.o..o....",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"dragon":    # 龙：双翼展翅，口吐烈焰
			return _make_pixel_texture([
				"o..............o",
				"oo....oooo....oo",
				".oo..ooiiooo.oo.",
				"..oooooiiooooo..",
				"...ooiiwwiioo...",
				"....oiiiiioo....",
				"....ooooooo.....",
				".....oiiio......",
				"....iiiwiii.....",
				"...iiwwwwwii....",
				"....iiiwiii.....",
				"......iii.......",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"demon":     # 恶魔领主：双角+蝙蝠翅膀，狂暴冲刺
			return _make_pixel_texture([
				"o....oooooo....o",
				".o...oooooo...o.",
				"..o..oooooo..o..",
				"..ooiiiiiiioo...",
				"..ooiiwwwwiioo..",
				"..oiiiiiiiiioo..",
				"..oiioiiiooiio..",
				"...oooooooooo...",
				"..oooooooooooo..",
				".oo..oooooo..oo.",
				"oo...oooooo...oo",
				"................",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

		"minotaur":  # 牛头人：牛角+宽肩，保距冲锋
			return _make_pixel_texture([
				"o....oooooo....o",
				".o...oooooo...o.",
				"..o..oooooo..o..",
				"..oooiiiiiiooo..",
				"...oiiwwwwiio...",
				"...oiiiiiiioo...",
				"...oioooooioo...",
				"....oooooooo....",
				".....oooooo.....",
				"....oooooooo....",
				"..o..oooooo..o..",
				".o...oooooo...o.",
				"................",
				"................",
				"................",
				"................"
			], {"o": o, "i": i, "w": w})

	# 默认回退（不应出现）
	return _make_pixel_texture([
		".....oooooo.....",
		"....oiiiiioo....",
		"....oiwwwioo....",
		"....oiiiiioo....",
		".....oooooo.....",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................"
	], {"o": o, "i": i, "w": w})

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

func _load_png_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image)
