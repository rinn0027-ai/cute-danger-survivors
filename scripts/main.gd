extends Node2D

const PlayerScene := preload("res://scripts/player.gd")
const EnemyScene := preload("res://scripts/enemy.gd")
const GemScene := preload("res://scripts/xp_gem.gd")
const BulletScene := preload("res://scripts/bullet.gd")
const ItemPickupScene := preload("res://scripts/item_pickup.gd")
const JoystickScene := preload("res://scripts/virtual_joystick.gd")
const MusicPlayer := preload("res://scripts/music_player.gd")
const SfxPlayer   := preload("res://scripts/sfx_player.gd")

var player: CharacterBody2D
var hud: CanvasLayer
var joystick_move: Control   # 手机：单摇杆控制移动
var joystick_aim: Control    # 桌面兼容保留；手机不再创建右摇杆
var _sfx: Node               # 音效管理器
var _is_touch_session := false
var level_panel: Control
var doors := {}
var rng := RandomNumberGenerator.new()
var game_time := 0.0
var shoot_timer := 0.0
var enemy_shoot_timer := 0.0
var xp := 0
var xp_to_next := 6
var level := 1
var kills := 0
var floor_number := 1
var room_number := 1
var room_cleared := false
var changing_room := false
var current_room := Vector2i.ZERO
var entry_direction := Vector2i.ZERO
var boss_room := Vector2i.ZERO
var dungeon := {}
var visited_rooms := {}
var cleared_rooms := {}
var paused_for_upgrade := false
var game_over := false
var boss_state := {
	"patterns": [], "index": 0, "spiral_angle": 0.0,
	"seed": 0, "archetype_id": 0, "concept_id": 0, "aspect_id": 0
}

# ── 地下城固定元素池：基础轮廓 + 元素变体 + 行为原型 ─────────────────────────
# 每个敌人由 family/concept 决定像素轮廓，aspect 决定配色和少量数值。
var _boss_concepts := [
	{
		"key": "lich",
		"outer": Color("#5c6f91"), "inner": Color("#d8e6ff"),
		"speed_mult": 0.95,       "hp_mult": 1.35
	},
	{
		"key": "dragon",
		"outer": Color("#9b2f20"), "inner": Color("#ffb45f"),
		"speed_mult": 1.2,        "hp_mult": 1.25
	},
	{
		"key": "demon",
		"outer": Color("#682351"), "inner": Color("#ff6fb0"),
		"speed_mult": 1.25,       "hp_mult": 1.2
	},
	{
		"key": "minotaur",
		"outer": Color("#7a4d2a"), "inner": Color("#e1b06d"),
		"speed_mult": 1.05,       "hp_mult": 1.65
	},
	{
		"key": "watcher",
		"outer": Color("#3e357f"), "inner": Color("#a995ff"),
		"speed_mult": 0.85,       "hp_mult": 1.5
	},
]

var _enemy_families := [
	{"key": "slime", "min_floor": 1, "scale": 0.72, "mode": "auto", "speed": 62.0, "hp": 2},
	{"key": "bat", "min_floor": 1, "scale": 0.7, "mode": "auto", "speed": 104.0, "hp": 1},
	{"key": "skeleton", "min_floor": 2, "scale": 2.45, "mode": "auto", "speed": 66.0, "hp": 3},
	{"key": "imp", "min_floor": 2, "scale": 2.25, "mode": "erratic", "speed": 108.0, "hp": 2},
	{"key": "cultist", "min_floor": 3, "scale": 2.55, "mode": "retreat", "speed": 58.0, "hp": 4},
	{"key": "spider", "min_floor": 3, "scale": 2.65, "mode": "orbit", "speed": 86.0, "hp": 3},
	{"key": "zombie", "min_floor": 4, "scale": 2.85, "mode": "auto", "speed": 50.0, "hp": 6},
	{"key": "mimic", "min_floor": 4, "scale": 3.05, "mode": "erratic", "speed": 78.0, "hp": 5},
]

var _dungeon_aspects := [
	{"key": "ember", "outer": Color("#a53b21"), "inner": Color("#ffb85f"), "speed_mult": 1.05, "hp_mult": 1.0},
	{"key": "frost", "outer": Color("#356c91"), "inner": Color("#b8ecff"), "speed_mult": 0.92, "hp_mult": 1.18},
	{"key": "shadow", "outer": Color("#3f325c"), "inner": Color("#b78cff"), "speed_mult": 1.18, "hp_mult": 0.9},
	{"key": "venom", "outer": Color("#2f7a45"), "inner": Color("#a9ff72"), "speed_mult": 1.0, "hp_mult": 1.08},
	{"key": "iron", "outer": Color("#5f6874"), "inner": Color("#d3dae2"), "speed_mult": 0.82, "hp_mult": 1.35},
]
var current_upgrade_keys: Array[String] = []
var room_rect := Rect2(Vector2(64, 64), Vector2(832, 416))
var stats := {
	"damage": 1,
	"shot_speed": 440.0,
	"fire_cooldown": 0.36,
	"bullet_count": 1,
	"spread": 0.0,
	"pierce": 0,
	"move_speed": 160.0,
	"max_health": 20
}
var item_effects := {
	"spark": false,
	"triple": false,
	"needle": false,
	"heart": false,
	"crown": false
}
var combo_effects := {
	"spark_triple": false,
	"needle_triple": false
}

@onready var enemies := Node2D.new()
@onready var gems := Node2D.new()
@onready var bullets := Node2D.new()
@onready var pickups := Node2D.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(MusicPlayer.new())
	_sfx = SfxPlayer.new()
	add_child(_sfx)
	rng.randomize()
	_configure_room_rect()
	_generate_dungeon()
	add_child(_make_floor())
	add_child(_make_room_walls())
	gems.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemies.process_mode = Node.PROCESS_MODE_PAUSABLE
	bullets.process_mode = Node.PROCESS_MODE_PAUSABLE
	pickups.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gems)
	add_child(enemies)
	add_child(bullets)
	add_child(pickups)
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var room_door := _make_door(direction)
		doors[direction] = room_door
		add_child(room_door)
	player = PlayerScene.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = room_rect.get_center()
	player.died.connect(_on_player_died)
	add_child(player)
	_apply_stats()
	hud = _make_hud()
	add_child(hud)
	var joy_layer := CanvasLayer.new()
	joy_layer.layer = 10
	joystick_move = JoystickScene.new()
	joystick_move.right_side = false
	joystick_move.capture_full_screen = true
	joy_layer.add_child(joystick_move)
	add_child(joy_layer)
	_load_room()

func _configure_room_rect() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.y > vp_size.x:
		var margin_x := 24.0
		var top_margin := 72.0
		var bottom_controls := 178.0
		room_rect = Rect2(
			Vector2(margin_x, top_margin),
			Vector2(vp_size.x - margin_x * 2.0, vp_size.y - top_margin - bottom_controls)
		)
	else:
		var room_width := maxf(832.0, vp_size.x - 128.0)
		var room_height := maxf(416.0, vp_size.y - 124.0)
		room_rect = Rect2(Vector2(64, 64), Vector2(room_width, room_height))

func _physics_process(delta: float) -> void:
	if paused_for_upgrade or game_over:
		return
	game_time += delta
	shoot_timer -= delta
	enemy_shoot_timer -= delta
	if joystick_move.touching or (joystick_aim != null and joystick_aim.touching):
		_is_touch_session = true
	player.joystick_direction = joystick_move.direction
	_keep_player_inside_room()
	_handle_shooting()
	if enemy_shoot_timer <= 0.0:
		_fire_enemy_bullets()
		var shoot_interval := 1.25
		if dungeon.get(current_room, "normal") == "boss" and enemies.get_child_count() > 0:
			var boss := enemies.get_child(0)
			if "max_health" in boss and boss.max_health > 0:
				var hp_ratio: float = float(boss.health) / float(boss.max_health)
				if hp_ratio < 0.4:
					shoot_interval = 0.62  # 狂暴：射击间隔减半
		enemy_shoot_timer = shoot_interval
	_update_hud()

func _handle_shooting() -> void:
	if shoot_timer > 0.0:
		return
	var direction: Vector2
	if joystick_aim != null and joystick_aim.direction != Vector2.ZERO:
		# 右摇杆主动推出：按摇杆方向射击
		direction = joystick_aim.direction
	elif _is_touch_session:
		direction = _nearest_enemy_direction()
		if direction == Vector2.ZERO:
			direction = joystick_move.direction
	else:
		# 桌面鼠标瞄准
		direction = player.global_position.direction_to(get_global_mouse_position())
	if direction == Vector2.ZERO:
		return
	_fire_player_bullets(direction.normalized())
	shoot_timer = stats["fire_cooldown"]

func _nearest_enemy_direction() -> Vector2:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in enemies.get_children():
		var dist := player.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	if nearest == null:
		return Vector2.ZERO
	return player.global_position.direction_to(nearest.global_position)

func _fire_player_bullets(direction: Vector2) -> void:
	var count: int = stats["bullet_count"]
	var spread: float = stats["spread"]
	var start_angle := -spread * float(count - 1) * 0.5
	for i in range(count):
		var bullet := BulletScene.new()
		bullet.from_player = true
		bullet.sfx = _sfx
		bullet.direction = direction.rotated(deg_to_rad(start_angle + spread * i))
		bullet.speed = stats["shot_speed"]
		bullet.damage = stats["damage"]
		bullet.pierce = stats["pierce"]
		bullet.global_position = player.global_position + bullet.direction * 18.0
		bullets.add_child(bullet)
	if _sfx != null:
		_sfx.play_shoot()

func _fire_enemy_bullets() -> void:
	if enemies.get_child_count() == 0:
		return
	var room_type: String = dungeon.get(current_room, "normal")
	if room_type == "boss":
		_execute_boss_pattern(enemies.get_child(0).global_position)
	else:
		for enemy in enemies.get_children():
			if enemy.global_position.distance_to(player.global_position) < 280.0 and rng.randf() < 0.35:
				_spawn_enemy_bullet(enemy.global_position, enemy.global_position.direction_to(player.global_position), 160.0)

func _spawn_enemy_bullet(origin: Vector2, direction: Vector2, bullet_speed: float) -> void:
	var bullet := BulletScene.new()
	bullet.from_player = false
	bullet.direction = direction.normalized()
	bullet.speed = bullet_speed
	bullet.damage = 1
	bullet.lifetime = 3.0
	bullet.global_position = origin + bullet.direction * 20.0
	bullets.add_child(bullet)

func _generate_boss_patterns(floor: int, archetype: int) -> Array:
	# 第 1 层：固定 8 方向，还没解锁随机原型
	if floor == 1:
		return [{"type": "radial", "count": 8, "speed": 185.0}]

	var spd := 175.0 + floor * 12.0      # 基础子弹速度随层递增
	var result: Array = []

	match archetype:
		0:  # 炮台 Artillery：大量覆盖弹幕，环形+追踪组合
			result.append({"type": "radial",
				"count": mini(10 + floor * 2, 22), "speed": spd})
			result.append({"type": "ring_aimed",
				"ring_count": mini(8 + floor, 18),
				"aimed_count": mini(3 + floor / 2, 7),
				"speed": spd * 1.05})
			if floor >= 3:
				result.append({"type": "cross",
					"speed": spd * 0.88, "offset_deg": 22.5})

		1:  # 追击 Chaser：精准散弹为主，配合螺旋
			result.append({"type": "aimed",
				"count": mini(3 + floor, 9),
				"spread_deg": 14.0, "speed": spd * 1.25})
			result.append({"type": "spiral",
				"count": mini(4 + floor, 9),
				"speed": spd * 1.1,
				"step_deg": maxf(18.0, 42.0 - floor * 3.0)})
			if floor >= 4:
				result.append({"type": "aimed",
					"count": mini(6 + floor, 10),
					"spread_deg": 7.0, "speed": spd * 1.4})

		2:  # 舞者 Dancer：螺旋为主，十字穿插
			result.append({"type": "spiral",
				"count": mini(5 + floor, 11),
				"speed": spd * 1.15,
				"step_deg": maxf(12.0, 40.0 - floor * 3.5)})
			result.append({"type": "cross",
				"speed": spd, "offset_deg": 0.0})
			if floor >= 3:
				result.append({"type": "spiral",
					"count": mini(3 + floor, 8),
					"speed": spd * 0.9,
					"step_deg": maxf(20.0, 65.0 - floor * 4.5)})

		3:  # 狂战士 Berserker：全类型混搭，随机 3 个
			var pool: Array = [
				{"type": "radial",
					"count": mini(8 + floor * 2, 20), "speed": spd},
				{"type": "aimed",
					"count": mini(4 + floor, 10),
					"spread_deg": 20.0, "speed": spd * 1.15},
				{"type": "spiral",
					"count": mini(5 + floor, 10),
					"speed": spd * 1.2,
					"step_deg": maxf(12.0, 35.0 - floor * 3.0)},
				{"type": "ring_aimed",
					"ring_count": mini(8 + floor, 16),
					"aimed_count": mini(3 + floor / 2, 6),
					"speed": spd},
			]
			if floor >= 3:
				pool.append({"type": "cross",
					"speed": spd, "offset_deg": rng.randf_range(0.0, 44.9)})
			pool.shuffle()
			result = pool.slice(0, mini(3, pool.size()))

	return result

func _execute_boss_pattern(origin: Vector2) -> void:
	if boss_state["patterns"].is_empty():
		return
	_fire_pattern(origin, boss_state["patterns"][boss_state["index"]])
	boss_state["index"] = (boss_state["index"] + 1) % boss_state["patterns"].size()

func _fire_pattern(origin: Vector2, pattern: Dictionary) -> void:
	var spd: float = pattern["speed"]
	match pattern["type"]:
		"radial":
			var n: int = pattern["count"]
			for i in range(n):
				_spawn_enemy_bullet(origin,
					Vector2.RIGHT.rotated(TAU * i / float(n)), spd)

		"spiral":
			var n: int = pattern["count"]
			var step: float = deg_to_rad(pattern["step_deg"])
			var base: float = boss_state["spiral_angle"]
			for i in range(n):
				_spawn_enemy_bullet(origin,
					Vector2.RIGHT.rotated(base + step * i), spd)
			boss_state["spiral_angle"] = base + step  # 每次发射整体旋转一步

		"aimed":
			if player == null:
				return
			var n: int = pattern["count"]
			var spread: float = deg_to_rad(pattern["spread_deg"])
			var to_pl: Vector2 = origin.direction_to(player.global_position)
			var start: float = -spread * (n - 1) * 0.5
			for i in range(n):
				_spawn_enemy_bullet(origin, to_pl.rotated(start + spread * i), spd)

		"cross":
			var off: float = deg_to_rad(pattern["offset_deg"])
			for i in range(4):
				_spawn_enemy_bullet(origin,
					Vector2.RIGHT.rotated(off + PI * 0.5 * i), spd)
			for i in range(4):
				_spawn_enemy_bullet(origin,
					Vector2.RIGHT.rotated(off + PI * 0.25 + PI * 0.5 * i), spd * 0.82)

		"ring_aimed":
			var rn: int = pattern["ring_count"]
			for i in range(rn):
				_spawn_enemy_bullet(origin,
					Vector2.RIGHT.rotated(TAU * i / float(rn)), spd * 0.8)
			if player != null:
				var an: int = pattern["aimed_count"]
				var spread: float = deg_to_rad(20.0)
				var to_pl: Vector2 = origin.direction_to(player.global_position)
				var start: float = -spread * (an - 1) * 0.5
				for i in range(an):
					_spawn_enemy_bullet(origin, to_pl.rotated(start + spread * i), spd * 1.2)

func _input(event: InputEvent) -> void:
	if not paused_for_upgrade or not event.is_pressed():
		return
	if event is InputEventKey:
		if event.keycode == KEY_1 and current_upgrade_keys.size() > 0:
			_choose_upgrade(current_upgrade_keys[0])
		elif event.keycode == KEY_2 and current_upgrade_keys.size() > 1:
			_choose_upgrade(current_upgrade_keys[1])
		elif event.keycode == KEY_3 and current_upgrade_keys.size() > 2:
			_choose_upgrade(current_upgrade_keys[2])

func _make_floor() -> Node2D:
	var floor := Node2D.new()
	floor.name = "PixelFloor"
	var tile_texture := _load_png_texture("res://assets/sprites/floor.png")
	var x_start := int(floor(room_rect.position.x / 32.0))
	var x_end := int(ceil(room_rect.end.x / 32.0))
	var y_start := int(floor(room_rect.position.y / 32.0))
	var y_end := int(ceil(room_rect.end.y / 32.0))
	for x in range(x_start, x_end):
		for y in range(y_start, y_end):
			var tile := Sprite2D.new()
			tile.texture = tile_texture
			tile.position = Vector2(x * 32, y * 32)
			floor.add_child(tile)
	return floor

func _make_room_walls() -> Node2D:
	var walls := Node2D.new()
	walls.name = "RoomWalls"
	var vp_size := get_viewport_rect().size
	var color := Color("#151827")
	var top := ColorRect.new()
	top.color = color
	top.position = Vector2(0, 0)
	top.size = Vector2(vp_size.x, room_rect.position.y)
	walls.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = color
	bottom.position = Vector2(0, room_rect.end.y)
	bottom.size = Vector2(vp_size.x, maxf(0.0, vp_size.y - room_rect.end.y))
	walls.add_child(bottom)
	var left := ColorRect.new()
	left.color = color
	left.position = Vector2(0, room_rect.position.y)
	left.size = Vector2(room_rect.position.x, room_rect.size.y)
	walls.add_child(left)
	var right := ColorRect.new()
	right.color = color
	right.position = Vector2(room_rect.end.x, room_rect.position.y)
	right.size = Vector2(maxf(0.0, vp_size.x - room_rect.end.x), room_rect.size.y)
	walls.add_child(right)
	return walls

func _generate_dungeon() -> void:
	dungeon.clear()
	visited_rooms.clear()
	cleared_rooms.clear()
	current_room = Vector2i.ZERO
	entry_direction = Vector2i.ZERO
	dungeon[current_room] = "start"
	var cursor := current_room
	var directions := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	while dungeon.size() < 7:
		cursor += directions[rng.randi_range(0, directions.size() - 1)]
		if abs(cursor.x) + abs(cursor.y) > 5:
			cursor = Vector2i.ZERO
			continue
		if not dungeon.has(cursor):
			dungeon[cursor] = "normal"
	var farthest := Vector2i.ZERO
	var farthest_dist := -1
	for room_pos in dungeon.keys():
		var dist: int = abs(room_pos.x) + abs(room_pos.y)
		if dist > farthest_dist:
			farthest_dist = dist
			farthest = room_pos
	dungeon[farthest] = "boss"
	boss_room = farthest
	var candidates: Array = dungeon.keys().filter(func(room_pos: Vector2i) -> bool:
		return room_pos != Vector2i.ZERO and dungeon[room_pos] == "normal"
	)
	candidates.shuffle()
	if candidates.size() > 0:
		dungeon[candidates.pop_back()] = "treasure"
	if candidates.size() > 0:
		dungeon[candidates.pop_back()] = "shop"

func _make_door(direction: Vector2i) -> Area2D:
	var area := Area2D.new()
	area.name = "NextRoomDoor"
	area.set_meta("direction", direction)
	if direction == Vector2i.RIGHT:
		area.position = Vector2(room_rect.end.x + 1, room_rect.get_center().y)
	elif direction == Vector2i.LEFT:
		area.position = Vector2(room_rect.position.x - 1, room_rect.get_center().y)
	elif direction == Vector2i.UP:
		area.position = Vector2(room_rect.get_center().x, room_rect.position.y - 1)
	else:
		area.position = Vector2(room_rect.get_center().x, room_rect.end.y + 1)
	area.monitoring = true
	area.visible = false
	area.body_entered.connect(_on_door_body_entered.bind(direction))
	var door_sprite := Sprite2D.new()
	door_sprite.texture = _load_png_texture("res://assets/sprites/door.png")
	if direction == Vector2i.UP or direction == Vector2i.DOWN:
		door_sprite.rotation_degrees = 90
	area.add_child(door_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 84) if direction == Vector2i.RIGHT or direction == Vector2i.LEFT else Vector2(84, 36)
	shape.shape = rect
	area.add_child(shape)
	return area

func _load_room() -> void:
	changing_room = false
	room_cleared = false
	enemy_shoot_timer = 1.0
	_set_doors_visible(false)
	for enemy in enemies.get_children():
		enemy.queue_free()
	for gem in gems.get_children():
		gem.queue_free()
	for bullet in bullets.get_children():
		bullet.queue_free()
	for pickup in pickups.get_children():
		pickup.queue_free()
	player.position = _entry_position()
	var room_type: String = dungeon.get(current_room, "normal")
	visited_rooms[current_room] = true
	if cleared_rooms.has(current_room):
		if dungeon.get(current_room, "normal") == "normal" and room_number >= 8:
			_spawn_enemy_count(1)
		elif dungeon.get(current_room, "normal") == "boss":
			_ensure_next_floor_portal()
		_open_door()
	elif room_type == "start":
		_open_door()
	elif room_type == "normal":
		_spawn_enemy_count(mini(4, 2 + int(room_number / 2)))
	elif room_type == "boss":
		var boss_seed: int = rng.randi()
		boss_state["seed"] = boss_seed
		# concept / aspect / archetype 独立随机，产生 5×5×4 种 Boss 组合。
		boss_state["concept_id"]   = boss_seed % _boss_concepts.size()
		boss_state["aspect_id"] = (boss_seed / _boss_concepts.size()) % _dungeon_aspects.size()
		boss_state["archetype_id"] = (boss_seed / (_boss_concepts.size() * _dungeon_aspects.size())) % 4
		boss_state["index"] = 0
		boss_state["spiral_angle"] = 0.0
		boss_state["patterns"] = _generate_boss_patterns(floor_number, boss_state["archetype_id"])
		_spawn_enemy_count(1, true)
	elif room_type == "treasure":
		_spawn_room_item("treasure")
		_open_door()
	elif room_type == "shop":
		_spawn_room_item("shop")
		_open_door()

func _entry_position() -> Vector2:
	if entry_direction == Vector2i.LEFT:
		return Vector2(room_rect.position.x + 92, room_rect.get_center().y)
	if entry_direction == Vector2i.RIGHT:
		return Vector2(room_rect.end.x - 92, room_rect.get_center().y)
	if entry_direction == Vector2i.UP:
		return Vector2(room_rect.get_center().x, room_rect.position.y + 92)
	if entry_direction == Vector2i.DOWN:
		return Vector2(room_rect.get_center().x, room_rect.end.y - 92)
	return Vector2(room_rect.position.x + 92, room_rect.get_center().y)

func _spawn_enemy_count(count: int, boss := false) -> void:
	for i in range(count):
		_spawn_enemy_in_room(boss)

func _spawn_enemy_in_room(boss := false) -> void:
	var enemy := EnemyScene.new()
	var spawn_margin_x := minf(180.0, room_rect.size.x * 0.32)
	var spawn_margin_right := minf(80.0, room_rect.size.x * 0.18)
	enemy.position = Vector2(
		rng.randf_range(room_rect.position.x + spawn_margin_x, room_rect.end.x - spawn_margin_right),
		rng.randf_range(room_rect.position.y + 70, room_rect.end.y - 70)
	)
	enemy.target = player
	if boss:
		var archetype: int = boss_state.get("archetype_id", 0)
		var concept: Dictionary = _boss_concepts[boss_state.get("concept_id", 0)]
		var aspect: Dictionary = _dungeon_aspects[boss_state.get("aspect_id", 0)]
		var concept_outer: Color = concept["outer"]
		var concept_inner: Color = concept["inner"]
		var aspect_outer: Color = aspect["outer"]
		var aspect_inner: Color = aspect["inner"]
		var base_speed := 42.0 + floor_number * 3.0
		var base_hp    := 12 + floor_number * 8
		enemy.visual_scale        = 6.0
		enemy.animal_concept      = concept["key"]
		enemy.archetype_color     = concept_outer.lerp(aspect_outer, 0.45)
		enemy.concept_inner_color = concept_inner.lerp(aspect_inner, 0.55)
		enemy.speed  = base_speed * concept["speed_mult"] * aspect["speed_mult"]
		enemy.health = int(base_hp * concept["hp_mult"] * aspect["hp_mult"])
		# 应用 archetype 行为（移动方式 + 数值叠加）
		match archetype:
			0:  # 炮台 Artillery — 保距，高血量
				enemy.movement_mode = "retreat"
				enemy.orbit_radius  = 260.0
				enemy.speed  *= 0.72
				enemy.health  = int(enemy.health * 1.4)
			1:  # 追击 Chaser — 直线冲锋 + 波动，高速
				enemy.movement_mode = "auto"
				enemy.enemy_type    = "bat"   # 保留波浪移动效果
				enemy.speed  *= 1.5
			2:  # 舞者 Dancer — 环绕，难以攻击
				enemy.movement_mode = "orbit"
				enemy.orbit_radius  = 200.0
				enemy.speed  *= 1.1
				enemy.health  = int(enemy.health * 1.1)
			3:  # 狂战士 Berserker — 狂乱冲刺，超高血量
				enemy.movement_mode = "erratic"
				enemy.speed  *= 1.3
				enemy.health  = int(enemy.health * 1.6)
	else:
		var pool: Array = []
		for candidate in _enemy_families:
			if floor_number >= int(candidate["min_floor"]):
				pool.append(candidate)
		var family: Dictionary = pool[rng.randi() % pool.size()]
		var aspect: Dictionary = _dungeon_aspects[rng.randi() % _dungeon_aspects.size()]
		enemy.enemy_type = family["key"]
		enemy.animal_concept = "" if family["key"] == "slime" or family["key"] == "bat" else family["key"]
		enemy.movement_mode = family["mode"]
		enemy.visual_scale = family["scale"]
		enemy.archetype_color = aspect["outer"]
		enemy.concept_inner_color = aspect["inner"]
		enemy.speed = (float(family["speed"]) + minf(room_number * 3.0 + floor_number * 2.0, 48.0)) * aspect["speed_mult"]
		enemy.health = maxi(1, int((int(family["hp"]) + int(room_number / 2) + int(floor_number / 2)) * aspect["hp_mult"]))
		if family["key"] == "spider":
			enemy.orbit_radius = 95.0
		elif family["key"] == "cultist":
			enemy.orbit_radius = 245.0
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.add_child(enemy)

func _on_enemy_defeated(enemy_pos: Vector2) -> void:
	kills += 1
	var gem := GemScene.new()
	gem.position = enemy_pos
	gem.collected.connect(_on_gem_collected)
	gems.add_child(gem)
	await get_tree().process_frame
	if enemies.get_child_count() == 0:
		if dungeon.get(current_room, "normal") == "boss":
			_spawn_room_item("boss")
			_spawn_room_item("stairs")
		_open_door()

func _spawn_room_item(source: String) -> void:
	if source == "stairs":
		var stairs := ItemPickupScene.new()
		stairs.item_id = "stairs"
		stairs.item_name = "Next Floor"
		stairs.item_color = Color("#ffffff")
		stairs.position = room_rect.get_center() + Vector2(0, 90)
		stairs.picked.connect(_on_item_picked)
		pickups.add_child(stairs)
		return
	var pool := ["spark", "triple", "needle", "heart"]
	if source == "boss":
		pool.append("crown")
	var item_id: String = pool[rng.randi_range(0, pool.size() - 1)]
	var item := ItemPickupScene.new()
	item.item_id = item_id
	item.item_name = _item_name(item_id)
	item.item_color = _item_color(item_id)
	item.position = room_rect.get_center()
	item.picked.connect(_on_item_picked)
	pickups.add_child(item)

func _ensure_next_floor_portal() -> void:
	for pickup in pickups.get_children():
		if "item_id" in pickup and pickup.item_id == "stairs":
			return
	_spawn_room_item("stairs")

func _on_item_picked(item_id: String) -> void:
	if item_id == "stairs":
		_next_floor()
		return
	item_effects[item_id] = true
	if item_id == "spark":
		stats["damage"] += 1
	elif item_id == "triple":
		stats["bullet_count"] = maxi(stats["bullet_count"], 3)
		stats["spread"] = maxf(stats["spread"], 12.0)
	elif item_id == "needle":
		stats["pierce"] += 1
		stats["shot_speed"] += 70.0
	elif item_id == "heart":
		stats["max_health"] += 6
		player.health += 6
	elif item_id == "crown":
		stats["damage"] += 1
		stats["fire_cooldown"] = max(0.18, stats["fire_cooldown"] - 0.07)
	if item_effects["spark"] and item_effects["triple"] and not combo_effects["spark_triple"]:
		combo_effects["spark_triple"] = true
		stats["damage"] += 1
		stats["spread"] = maxf(stats["spread"], 18.0)
	if item_effects["needle"] and item_effects["triple"] and not combo_effects["needle_triple"]:
		combo_effects["needle_triple"] = true
		stats["pierce"] = maxi(stats["pierce"], 2)
	_apply_stats()

func _next_floor() -> void:
	floor_number += 1
	room_number = 1
	_generate_dungeon()
	player.health = mini(player.max_health, player.health + 4)
	call_deferred("_load_room")

func _item_name(item_id: String) -> String:
	if item_id == "spark":
		return "Spark Core"
	if item_id == "triple":
		return "Triple Tears"
	if item_id == "needle":
		return "Piercing Needle"
	if item_id == "heart":
		return "Big Heart"
	return "Crown Shard"

func _item_color(item_id: String) -> Color:
	if item_id == "spark":
		return Color("#ffd166")
	if item_id == "triple":
		return Color("#7ad7f0")
	if item_id == "needle":
		return Color("#c084fc")
	if item_id == "heart":
		return Color("#ff4d6d")
	return Color("#f8d66d")

func _open_door() -> void:
	room_cleared = true
	cleared_rooms[current_room] = true
	_set_doors_visible(true)

func _set_doors_visible(open: bool) -> void:
	for direction in doors.keys():
		var door_area: Area2D = doors[direction]
		var can_enter: bool = open and dungeon.has(current_room + direction)
		door_area.visible = can_enter
		door_area.monitoring = can_enter

func _on_door_body_entered(body: Node2D, direction: Vector2i) -> void:
	if body != player or not room_cleared or changing_room:
		return
	changing_room = true
	if direction == Vector2i.ZERO:
		return
	current_room += direction
	entry_direction = -direction
	if not visited_rooms.has(current_room):
		room_number += 1
	call_deferred("_load_room")

func _keep_player_inside_room() -> void:
	if room_cleared:
		player.position.x = clamp(player.position.x, room_rect.position.x - 32, room_rect.end.x + 32)
		player.position.y = clamp(player.position.y, room_rect.position.y - 32, room_rect.end.y + 32)
	else:
		player.position.x = clamp(player.position.x, room_rect.position.x + 16, room_rect.end.x - 16)
		player.position.y = clamp(player.position.y, room_rect.position.y + 16, room_rect.end.y - 16)

func _on_gem_collected(value: int) -> void:
	xp += value
	if xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.35) + 3
		_show_upgrade_choices()

func _show_upgrade_choices() -> void:
	paused_for_upgrade = true
	get_tree().paused = true
	joystick_move.set_active(false)
	if joystick_aim != null:
		joystick_aim.set_active(false)
	level_panel.visible = true
	current_upgrade_keys.clear()
	var choices_box: HBoxContainer = level_panel.get_node("Panel/Content/Choices")
	for child in choices_box.get_children():
		child.queue_free()
	var choices := [
		{"label": "Bigger Spark", "desc": "Damage +1", "key": "damage"},
		{"label": "Quick Boots", "desc": "Move speed +18", "key": "move_speed"},
		{"label": "Rapid Fire", "desc": "Shoot faster", "key": "fire_cooldown"},
		{"label": "Tiny Heart", "desc": "Max HP +3", "key": "max_health"},
		{"label": "Fast Shot", "desc": "Bullet speed +60", "key": "shot_speed"}
	]
	choices.shuffle()
	var picked: Array = choices.slice(0, 3)
	for index in range(picked.size()):
		var choice: Dictionary = picked[index]
		current_upgrade_keys.append(choice["key"])
		var button := Button.new()
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.text = "%d\n%s\n%s" % [index + 1, choice["label"], choice["desc"]]
		button.icon = _make_upgrade_icon_texture(choice["key"])
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size = Vector2(220, 132)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_upgrade.bind(choice["key"]))
		choices_box.add_child(button)

func _choose_upgrade(key: String) -> void:
	if key == "damage":
		stats["damage"] += 1
	elif key == "move_speed":
		stats["move_speed"] += 18.0
	elif key == "fire_cooldown":
		stats["fire_cooldown"] = max(0.18, stats["fire_cooldown"] - 0.06)
	elif key == "max_health":
		stats["max_health"] += 3
		player.health += 3
	elif key == "shot_speed":
		stats["shot_speed"] += 60.0
	_apply_stats()
	current_upgrade_keys.clear()
	level_panel.visible = false
	get_tree().paused = false
	paused_for_upgrade = false
	joystick_move.set_active(true)
	if joystick_aim != null:
		joystick_aim.set_active(true)

func _apply_stats() -> void:
	if player == null:
		return
	player.speed = stats["move_speed"]
	player.max_health = stats["max_health"]
	player.health = min(player.health, player.max_health)

func _make_hud() -> CanvasLayer:
	var layer := CanvasLayer.new()
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var stats_label := Label.new()
	stats_label.name = "Stats"
	stats_label.position = Vector2(16, 12)
	stats_label.add_theme_font_size_override("font_size", 18)
	root.add_child(stats_label)
	level_panel = _make_level_panel()
	root.add_child(level_panel)
	return layer

func _make_level_panel() -> Control:
	var shade := Control.new()
	shade.name = "LevelPanel"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	shade.process_mode = Node.PROCESS_MODE_ALWAYS
	shade.z_index = 100
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(90, 118)
	panel.size = Vector2(780, 300)
	panel.custom_minimum_size = Vector2(780, 300)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	shade.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.size = Vector2(760, 280)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Level Up! Choose 1 upgrade"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Tap a button, or press 1 / 2 / 3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	box.add_child(hint)
	var choices := HBoxContainer.new()
	choices.name = "Choices"
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 14)
	box.add_child(choices)
	return shade

func _update_hud() -> void:
	var stats_label: Label = hud.get_node("HUDRoot/Stats")
	var door_text := "Door Open" if room_cleared else "Clear Room"
	stats_label.text = "Floor %d  Room %d  %s  %s  HP %d/%d  LV %d  XP %d/%d  Kills %d  Items %s  Map %s" % [
		floor_number,
		room_number,
		_room_type_name(dungeon.get(current_room, "normal")),
		door_text,
		player.health,
		player.max_health,
		level,
		xp,
		xp_to_next,
		kills,
		_item_summary(),
		_minimap_summary()
	]

func _room_type_name(room_type: String) -> String:
	if room_type == "start":
		return "Start"
	if room_type == "shop":
		return "Shop"
	if room_type == "treasure":
		return "Treasure"
	if room_type == "boss":
		return "Boss"
	return "Normal"

func _item_summary() -> String:
	var owned := []
	for item_id in item_effects.keys():
		if item_effects[item_id]:
			owned.append(_item_name(item_id))
	return "None" if owned.is_empty() else ",".join(owned)

func _minimap_summary() -> String:
	var exits := []
	if dungeon.has(current_room + Vector2i.UP):
		exits.append("Up")
	if dungeon.has(current_room + Vector2i.DOWN):
		exits.append("Down")
	if dungeon.has(current_room + Vector2i.LEFT):
		exits.append("Left")
	if dungeon.has(current_room + Vector2i.RIGHT):
		exits.append("Right")
	return "Exits:" + "/".join(exits)

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	get_tree().paused = true
	joystick_move.set_active(false)
	if joystick_aim != null:
		joystick_aim.set_active(false)
	var overlay := Control.new()
	overlay.name = "GameOverPanel"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = 120
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.02, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(250, 145)
	panel.size = Vector2(460, 250)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.size = Vector2(440, 230)
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	box.add_child(title)
	var detail := Label.new()
	detail.text = "You touched enemies too long\nRoom: %d   Kills: %d" % [room_number, kills]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 20)
	box.add_child(detail)
	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(240, 58)
	restart.process_mode = Node.PROCESS_MODE_ALWAYS
	restart.pressed.connect(_restart_game)
	box.add_child(restart)
	hud.get_node("HUDRoot").add_child(overlay)

func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _make_pixel_texture(rows: Array, palette: Dictionary) -> Texture2D:
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row.substr(x, 1)
			var color: Color = palette.get(key, Color.TRANSPARENT)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _load_png_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image)

func _make_upgrade_icon_texture(key: String) -> Texture2D:
	if key == "damage":
		return _load_png_texture("res://assets/sprites/icon_damage.png")
	if key == "move_speed":
		return _load_png_texture("res://assets/sprites/icon_speed.png")
	if key == "fire_cooldown" or key == "shot_speed":
		return _load_png_texture("res://assets/sprites/icon_pierce.png")
	if key == "max_health":
		return _load_png_texture("res://assets/sprites/icon_heart.png")
	return _load_png_texture("res://assets/sprites/icon_crown.png")
