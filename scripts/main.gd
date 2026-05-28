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
var boss_panel: Control
var boss_bar: ProgressBar
var boss_name_label: Label
var floor_node: Node2D
var walls_node: Node2D
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
	"bullet_size": 1.0,
	"homing": 0.0,
	"split_shot": false,
	"ember_bullets": false,
	"void_bullets": false,
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
	floor_node = _make_floor()
	add_child(floor_node)
	walls_node = _make_room_walls()
	add_child(walls_node)
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
	get_viewport().size_changed.connect(_on_viewport_size_changed)
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
		var top_margin := 164.0
		var bottom_controls := 178.0
		room_rect = Rect2(
			Vector2(margin_x, top_margin),
			Vector2(vp_size.x - margin_x * 2.0, vp_size.y - top_margin - bottom_controls)
		)
	else:
		var room_width := maxf(832.0, vp_size.x - 128.0)
		var room_height := maxf(416.0, vp_size.y - 124.0)
		room_rect = Rect2(Vector2(64, 64), Vector2(room_width, room_height))

func _on_viewport_size_changed() -> void:
	var old_center := room_rect.get_center()
	_configure_room_rect()
	if floor_node != null:
		floor_node.queue_free()
	floor_node = _make_floor()
	add_child(floor_node)
	move_child(floor_node, 0)
	if walls_node != null:
		walls_node.queue_free()
	walls_node = _make_room_walls()
	add_child(walls_node)
	move_child(walls_node, 1)
	for direction in doors.keys():
		_position_door(doors[direction], direction)
	if player != null:
		var offset := player.position - old_center
		player.position = room_rect.get_center() + offset
		_keep_player_inside_room()
	if hud != null:
		_layout_hud()
	_set_doors_visible(room_cleared)

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
					shoot_interval = 0.52  # 狂暴：射击间隔更短
				elif hp_ratio < 0.7:
					shoot_interval = 0.82
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
		bullet.size_mult = stats["bullet_size"]
		bullet.homing_strength = stats["homing"]
		bullet.split_on_hit = stats["split_shot"]
		bullet.split_scene = BulletScene
		if stats["void_bullets"]:
			bullet.effect = "void"
		elif stats["ember_bullets"]:
			bullet.effect = "ember"
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

func _spawn_enemy_bullet_sized(origin: Vector2, direction: Vector2, bullet_speed: float, size_mult: float, lifetime := 3.0) -> void:
	var bullet := BulletScene.new()
	bullet.from_player = false
	bullet.direction = direction.normalized()
	bullet.speed = bullet_speed
	bullet.damage = 1
	bullet.lifetime = lifetime
	bullet.size_mult = size_mult
	bullet.global_position = origin + bullet.direction * 24.0
	bullets.add_child(bullet)

func _generate_boss_patterns(floor: int, archetype: int) -> Array:
	var spd := 158.0 + floor * 11.0      # 基础子弹速度随层递增
	var result: Array = []

	match archetype:
		0:  # 炮台 Artillery：大量覆盖弹幕，环形+追踪组合
			result.append({"type": "gap_ring",
				"count": mini(16 + floor * 2, 30), "gap_index": rng.randi_range(0, 7), "gap_width": 2, "speed": spd * 0.92})
			result.append({"type": "ring_aimed",
				"ring_count": mini(12 + floor, 24),
				"aimed_count": mini(4 + floor / 2, 8),
				"speed": spd * 1.05})
			result.append({"type": "wall_sweep",
				"lanes": mini(5 + floor, 10), "speed": spd * 0.78})

		1:  # 追击 Chaser：精准散弹为主，配合螺旋
			result.append({"type": "aimed",
				"count": mini(5 + floor, 11),
				"spread_deg": 10.0, "speed": spd * 1.22})
			result.append({"type": "flower",
				"petals": mini(7 + floor, 13), "layers": 2, "speed": spd * 0.9})
			result.append({"type": "double_spiral",
				"count": mini(5 + floor, 10),
				"speed": spd * 1.0,
				"step_deg": maxf(13.0, 36.0 - floor * 2.0)})

		2:  # 舞者 Dancer：螺旋为主，十字穿插
			result.append({"type": "double_spiral",
				"count": mini(6 + floor, 12),
				"speed": spd * 1.15,
				"step_deg": maxf(10.0, 34.0 - floor * 2.4)})
			result.append({"type": "rotating_cross",
				"speed": spd, "offset_deg": 0.0})
			result.append({"type": "gap_ring",
				"count": mini(18 + floor * 2, 32), "gap_index": rng.randi_range(0, 9), "gap_width": 3, "speed": spd * 0.86})

		3:  # 狂战士 Berserker：全类型混搭，随机 3 个
			var pool: Array = [
				{"type": "gap_ring",
					"count": mini(18 + floor * 2, 32), "gap_index": rng.randi_range(0, 10), "gap_width": 2, "speed": spd},
				{"type": "aimed",
					"count": mini(6 + floor, 12),
					"spread_deg": 16.0, "speed": spd * 1.15},
				{"type": "double_spiral",
					"count": mini(6 + floor, 12),
					"speed": spd * 1.2,
					"step_deg": maxf(10.0, 30.0 - floor * 2.0)},
				{"type": "ring_aimed",
					"ring_count": mini(12 + floor, 24),
					"aimed_count": mini(4 + floor / 2, 8),
					"speed": spd},
				{"type": "flower",
					"petals": mini(8 + floor, 14), "layers": 2, "speed": spd * 0.92},
			]
			pool.append({"type": "rotating_cross",
				"speed": spd, "offset_deg": rng.randf_range(0.0, 44.9)})
			pool.shuffle()
			result = pool.slice(0, mini(4, pool.size()))

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

		"gap_ring":
			var n: int = pattern["count"]
			var gap_index: int = pattern.get("gap_index", 0)
			var gap_width: int = pattern.get("gap_width", 2)
			var offset: float = boss_state["spiral_angle"]
			for i in range(n):
				if abs(i - gap_index) <= gap_width:
					continue
				var size := 1.18 if i % 3 == 0 else 0.95
				_spawn_enemy_bullet_sized(origin, Vector2.RIGHT.rotated(offset + TAU * i / float(n)), spd, size, 3.3)
			boss_state["spiral_angle"] = offset + deg_to_rad(9.0)

		"spiral":
			var n: int = pattern["count"]
			var step: float = deg_to_rad(pattern["step_deg"])
			var base: float = boss_state["spiral_angle"]
			for i in range(n):
				_spawn_enemy_bullet(origin,
					Vector2.RIGHT.rotated(base + step * i), spd)
			boss_state["spiral_angle"] = base + step  # 每次发射整体旋转一步

		"double_spiral":
			var n: int = pattern["count"]
			var step: float = deg_to_rad(pattern["step_deg"])
			var base: float = boss_state["spiral_angle"]
			for i in range(n):
				var dir_a := Vector2.RIGHT.rotated(base + step * i)
				var dir_b := Vector2.RIGHT.rotated(base + PI + step * i)
				_spawn_enemy_bullet_sized(origin, dir_a, spd, 1.0, 3.1)
				_spawn_enemy_bullet_sized(origin, dir_b, spd * 0.92, 0.82, 3.3)
			boss_state["spiral_angle"] = base + step * 0.72

		"flower":
			var petals: int = pattern["petals"]
			var layers: int = pattern["layers"]
			var base: float = boss_state["spiral_angle"]
			for layer in range(layers):
				for i in range(petals):
					var dir := Vector2.RIGHT.rotated(base + TAU * i / float(petals) + layer * deg_to_rad(13.0))
					_spawn_enemy_bullet_sized(origin, dir, spd + layer * 32.0, 1.06 - layer * 0.18, 3.2)
			boss_state["spiral_angle"] = base + deg_to_rad(17.0)

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

		"rotating_cross":
			var off: float = boss_state["spiral_angle"] + deg_to_rad(pattern["offset_deg"])
			for i in range(8):
				_spawn_enemy_bullet_sized(origin, Vector2.RIGHT.rotated(off + TAU * i / 8.0), spd, 1.05, 3.0)
			for i in range(8):
				_spawn_enemy_bullet_sized(origin, Vector2.RIGHT.rotated(off + deg_to_rad(11.25) + TAU * i / 8.0), spd * 0.72, 0.82, 3.5)
			boss_state["spiral_angle"] = off + deg_to_rad(18.0)

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

		"wall_sweep":
			var lanes: int = pattern["lanes"]
			var left_to_right := rng.randf() < 0.5
			var y_step := room_rect.size.y / float(lanes + 1)
			var x := room_rect.position.x + 12.0 if left_to_right else room_rect.end.x - 12.0
			var dir := Vector2.RIGHT if left_to_right else Vector2.LEFT
			for i in range(lanes):
				var y := room_rect.position.y + y_step * float(i + 1)
				if i == lanes / 2:
					continue
				_spawn_enemy_bullet_sized(Vector2(x, y), dir, spd, 0.92, 3.4)

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
	_position_door(area, direction)
	area.collision_layer = 4
	area.collision_mask = 1
	area.monitoring = true
	area.visible = false
	area.body_entered.connect(_on_door_body_entered.bind(direction))
	var door_sprite := Sprite2D.new()
	door_sprite.name = "DoorSprite"
	door_sprite.texture = _load_png_texture("res://assets/sprites/door_topdown.png")
	if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
		door_sprite.rotation_degrees = 90
	area.add_child(door_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 84) if direction == Vector2i.RIGHT or direction == Vector2i.LEFT else Vector2(84, 36)
	shape.shape = rect
	area.add_child(shape)
	return area

func _position_door(area: Area2D, direction: Vector2i) -> void:
	if direction == Vector2i.RIGHT:
		area.position = Vector2(room_rect.end.x - 10, room_rect.get_center().y)
	elif direction == Vector2i.LEFT:
		area.position = Vector2(room_rect.position.x + 10, room_rect.get_center().y)
	elif direction == Vector2i.UP:
		area.position = Vector2(room_rect.get_center().x, room_rect.position.y + 10)
	elif direction == Vector2i.DOWN:
		area.position = Vector2(room_rect.get_center().x, room_rect.end.y - 10)

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

func _random_spawn_position(boss := false) -> Vector2:
	var margin := 90.0 if boss else 58.0
	var safe_from_player := minf(room_rect.size.length() * 0.42, 300.0) if boss else minf(room_rect.size.length() * 0.28, 190.0)
	var min_enemy_gap := 150.0 if boss else 62.0
	var fallback := room_rect.get_center()
	var best := fallback
	var best_score := -1.0
	for attempt in range(36):
		var candidate := Vector2(
			rng.randf_range(room_rect.position.x + margin, room_rect.end.x - margin),
			rng.randf_range(room_rect.position.y + margin, room_rect.end.y - margin)
		)
		var player_dist := candidate.distance_to(player.global_position)
		var nearest_enemy := 9999.0
		for existing in enemies.get_children():
			nearest_enemy = minf(nearest_enemy, candidate.distance_to(existing.global_position))
		var score := player_dist + nearest_enemy * 0.55
		if score > best_score:
			best_score = score
			best = candidate
		if player_dist >= safe_from_player and nearest_enemy >= min_enemy_gap:
			return candidate
	return best

func _player_power_scale(for_boss := false) -> float:
	var bullet_count: int = stats["bullet_count"]
	var effective_bullets := 1.0 + float(maxi(0, bullet_count - 1)) * 0.72
	var fire_rate: float = 0.36 / maxf(0.12, float(stats["fire_cooldown"]))
	var damage_power: float = float(stats["damage"]) * effective_bullets * fire_rate
	var utility := 1.0
	utility += float(stats["pierce"]) * 0.10
	utility += clampf(float(stats["homing"]) / 4.5, 0.0, 1.0) * 0.16
	utility += maxf(0.0, float(stats["bullet_size"]) - 1.0) * 0.22
	utility += maxf(0.0, float(stats["shot_speed"]) - 440.0) / 440.0 * 0.08
	if stats["split_shot"]:
		utility += 0.34
	if stats["ember_bullets"]:
		utility += 0.08
	if stats["void_bullets"]:
		utility += 0.08
	var power := damage_power * utility
	var upgrade_pressure := maxf(0.0, power - 1.0)
	var floor_pressure := maxf(0.0, float(floor_number - 1)) * 0.10
	if for_boss:
		return minf(5.0 + floor_number * 0.22, 1.0 + floor_pressure + upgrade_pressure * 0.58)
	return minf(3.6 + floor_number * 0.16, 1.0 + floor_pressure * 0.7 + upgrade_pressure * 0.34)

func _spawn_enemy_in_room(boss := false) -> void:
	var enemy := EnemyScene.new()
	enemy.position = _random_spawn_position(boss)
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
		var base_hp    := 24 + floor_number * 9
		enemy.visual_scale        = 7.2
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
		enemy.health = maxi(1, int(ceil(float(enemy.health) * _player_power_scale(true))))
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
		enemy.health = maxi(1, int(ceil(float(enemy.health) * _player_power_scale(false))))
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
	if direction == Vector2i.ZERO:
		return
	_enter_door(direction)

func _enter_door(direction: Vector2i) -> void:
	if changing_room or not room_cleared or not dungeon.has(current_room + direction):
		return
	changing_room = true
	current_room += direction
	entry_direction = -direction
	if not visited_rooms.has(current_room):
		room_number += 1
	call_deferred("_load_room")

func _keep_player_inside_room() -> void:
	player.position.x = clamp(player.position.x, room_rect.position.x + 16.0, room_rect.end.x - 16.0)
	player.position.y = clamp(player.position.y, room_rect.position.y + 16.0, room_rect.end.y - 16.0)

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
	var choices_box: BoxContainer = level_panel.get_node("Panel/Content/Choices")
	for child in choices_box.get_children():
		child.queue_free()
	var choices := [
		{"label": "Ember Core", "desc": "Damage +1, fiery shots", "key": "damage"},
		{"label": "Quick Boots", "desc": "Move speed +18", "key": "move_speed"},
		{"label": "Trigger Charm", "desc": "Shoot faster", "key": "fire_cooldown"},
		{"label": "Tiny Heart", "desc": "Max HP +3", "key": "max_health"},
		{"label": "Falcon Rune", "desc": "Bullet speed +60", "key": "shot_speed"},
		{"label": "Triple Sigil", "desc": "+1 shot, wider arc", "key": "multishot"},
		{"label": "Glass Needle", "desc": "Pierce +1", "key": "pierce"},
		{"label": "Moon Magnet", "desc": "Shots bend toward enemies", "key": "homing"},
		{"label": "Giant Tear", "desc": "Bigger bullets", "key": "bullet_size"},
		{"label": "Void Splinter", "desc": "Hits split into shards", "key": "split_shot"},
		{"label": "Royal Focus", "desc": "Damage +1, tighter spread", "key": "focus"}
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
		button.custom_minimum_size = Vector2(0, 112)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("normal", _make_card_style(Color("#252134"), Color("#8b6f3a"), 3))
		button.add_theme_stylebox_override("hover", _make_card_style(Color("#302a42"), Color("#ffd464"), 3))
		button.add_theme_stylebox_override("pressed", _make_card_style(Color("#17131f"), Color("#78ffe1"), 3))
		button.pressed.connect(_choose_upgrade.bind(choice["key"]))
		choices_box.add_child(button)

func _choose_upgrade(key: String) -> void:
	if key == "damage":
		stats["damage"] += 1
		stats["ember_bullets"] = true
	elif key == "move_speed":
		stats["move_speed"] += 18.0
	elif key == "fire_cooldown":
		stats["fire_cooldown"] = max(0.18, stats["fire_cooldown"] - 0.06)
	elif key == "max_health":
		stats["max_health"] += 3
		player.health += 3
	elif key == "shot_speed":
		stats["shot_speed"] += 60.0
	elif key == "multishot":
		stats["bullet_count"] = mini(7, stats["bullet_count"] + 1)
		stats["spread"] = maxf(10.0, stats["spread"] + 5.0)
	elif key == "pierce":
		stats["pierce"] += 1
	elif key == "homing":
		stats["homing"] = minf(4.5, stats["homing"] + 1.4)
	elif key == "bullet_size":
		stats["bullet_size"] = minf(1.75, stats["bullet_size"] + 0.18)
	elif key == "split_shot":
		stats["split_shot"] = true
		stats["void_bullets"] = true
	elif key == "focus":
		stats["damage"] += 1
		stats["spread"] = maxf(0.0, stats["spread"] - 4.0)
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
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.position = Vector2(10, 10)
	stats_panel.size = Vector2(get_viewport_rect().size.x - 20, 94)
	stats_panel.add_theme_stylebox_override("panel", _make_card_style(Color("#17131f"), Color("#d8c48a"), 3))
	root.add_child(stats_panel)
	var hud_box := VBoxContainer.new()
	hud_box.name = "HudBox"
	hud_box.size = stats_panel.size - Vector2(24, 16)
	hud_box.add_theme_constant_override("separation", 6)
	stats_panel.add_child(hud_box)
	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 8)
	hud_box.add_child(top_row)
	var hearts := HBoxContainer.new()
	hearts.name = "Hearts"
	hearts.custom_minimum_size = Vector2(150, 28)
	hearts.add_theme_constant_override("separation", 2)
	hearts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(hearts)
	var room_label := Label.new()
	room_label.name = "RoomInfo"
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.add_theme_font_size_override("font_size", 15)
	room_label.add_theme_color_override("font_color", Color("#ffd464"))
	room_label.add_theme_color_override("font_outline_color", Color("#10131f"))
	room_label.add_theme_constant_override("outline_size", 3)
	room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(room_label)
	var level_label := Label.new()
	level_label.name = "LevelInfo"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_font_size_override("font_size", 15)
	level_label.add_theme_color_override("font_color", Color("#78ffe1"))
	level_label.add_theme_color_override("font_outline_color", Color("#10131f"))
	level_label.add_theme_constant_override("outline_size", 3)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(level_label)
	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.add_theme_constant_override("separation", 8)
	hud_box.add_child(bottom_row)
	var xp_bar := ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.min_value = 0
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(170, 18)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.add_theme_stylebox_override("background", _make_card_style(Color("#242a3a"), Color("#10131f"), 2))
	xp_bar.add_theme_stylebox_override("fill", _make_card_style(Color("#5fc7e8"), Color("#5fc7e8"), 0))
	bottom_row.add_child(xp_bar)
	var xp_label := Label.new()
	xp_label.name = "XPInfo"
	xp_label.add_theme_font_size_override("font_size", 13)
	xp_label.add_theme_color_override("font_color", Color("#cfefff"))
	xp_label.add_theme_color_override("font_outline_color", Color("#10131f"))
	xp_label.add_theme_constant_override("outline_size", 2)
	xp_label.custom_minimum_size = Vector2(74, 18)
	bottom_row.add_child(xp_label)
	var state_label := Label.new()
	state_label.name = "StateInfo"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", Color("#f7f0d8"))
	state_label.add_theme_color_override("font_outline_color", Color("#10131f"))
	state_label.add_theme_constant_override("outline_size", 2)
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(state_label)
	boss_panel = PanelContainer.new()
	boss_panel.name = "BossPanel"
	boss_panel.position = Vector2(18, 112)
	boss_panel.size = Vector2(get_viewport_rect().size.x - 36, 58)
	boss_panel.visible = false
	boss_panel.add_theme_stylebox_override("panel", _make_card_style(Color("#241521"), Color("#ff6f7d"), 3))
	root.add_child(boss_panel)
	var boss_box := VBoxContainer.new()
	boss_box.name = "BossBox"
	boss_box.size = boss_panel.size - Vector2(24, 16)
	boss_box.add_theme_constant_override("separation", 4)
	boss_panel.add_child(boss_box)
	boss_name_label = Label.new()
	boss_name_label.name = "BossName"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 15)
	boss_name_label.add_theme_color_override("font_color", Color("#ffd1dc"))
	boss_name_label.add_theme_color_override("font_outline_color", Color("#10131f"))
	boss_name_label.add_theme_constant_override("outline_size", 3)
	boss_box.add_child(boss_name_label)
	boss_bar = ProgressBar.new()
	boss_bar.name = "BossBar"
	boss_bar.min_value = 0
	boss_bar.max_value = 100
	boss_bar.value = 100
	boss_bar.custom_minimum_size = Vector2(0, 16)
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("background", _make_card_style(Color("#3a2030"), Color("#10131f"), 2))
	boss_bar.add_theme_stylebox_override("fill", _make_card_style(Color("#ff4d6d"), Color("#ff4d6d"), 0))
	boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(boss_bar)
	level_panel = _make_level_panel()
	root.add_child(level_panel)
	_layout_hud()
	return layer

func _layout_hud() -> void:
	var vp_size := get_viewport_rect().size
	var root := hud.get_node_or_null("HUDRoot") if hud != null else null
	if root == null:
		return
	var stats_panel := root.get_node_or_null("StatsPanel") as PanelContainer
	if stats_panel != null:
		stats_panel.position = Vector2(10, 10)
		stats_panel.size = Vector2(vp_size.x - 20, 94)
		var hud_box := stats_panel.get_node_or_null("HudBox") as VBoxContainer
		if hud_box != null:
			hud_box.size = stats_panel.size - Vector2(24, 16)
	if boss_panel != null:
		boss_panel.position = Vector2(18, 112)
		boss_panel.size = Vector2(vp_size.x - 36, 58)
		var boss_box := boss_panel.get_node_or_null("BossBox") as VBoxContainer
		if boss_box != null:
			boss_box.size = boss_panel.size - Vector2(24, 16)

func _make_card_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

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
	var vp_size := get_viewport_rect().size
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.size = Vector2(minf(500.0, vp_size.x - 28.0), minf(620.0, vp_size.y - 170.0))
	panel.position = (vp_size - panel.size) * 0.5
	panel.custom_minimum_size = panel.size
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", _make_card_style(Color("#1b1827"), Color("#d8c48a"), 4))
	shade.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.size = panel.size - Vector2(24, 22)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "LEVEL UP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffd464"))
	title.add_theme_color_override("font_outline_color", Color("#10131f"))
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Choose one card"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#cfc6a0"))
	box.add_child(hint)
	var choices := VBoxContainer.new()
	choices.name = "Choices"
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 10)
	box.add_child(choices)
	return shade

func _update_hud() -> void:
	var root := hud.get_node("HUDRoot/StatsPanel/HudBox")
	_update_hearts(root.get_node("TopRow/Hearts"))
	var room_label: Label = root.get_node("TopRow/RoomInfo")
	room_label.text = "F%d  R%d  %s" % [
		floor_number, room_number, _room_type_name(dungeon.get(current_room, "normal"))
	]
	var level_label: Label = root.get_node("TopRow/LevelInfo")
	level_label.text = "LV %d" % level
	var xp_bar: ProgressBar = root.get_node("BottomRow/XPBar")
	xp_bar.max_value = xp_to_next
	xp_bar.value = xp
	var xp_label: Label = root.get_node("BottomRow/XPInfo")
	xp_label.text = "XP %d/%d" % [xp, xp_to_next]
	var state_label: Label = root.get_node("BottomRow/StateInfo")
	var door_text := "OPEN" if room_cleared else "LOCKED"
	state_label.text = "%s  K %d" % [door_text, kills]
	_update_boss_bar()

func _update_hearts(hearts: HBoxContainer) -> void:
	for child in hearts.get_children():
		child.queue_free()
	var max_units := int(ceil(float(player.max_health) / 2.0))
	var full_units := int(player.health / 2)
	var has_half: bool = player.health % 2 == 1
	var shown_units := mini(max_units, 10)
	for i in range(shown_units):
		var heart := TextureRect.new()
		heart.texture = _make_heart_texture("full" if i < full_units else "half" if i == full_units and has_half else "empty")
		heart.custom_minimum_size = Vector2(22, 22)
		heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts.add_child(heart)
	if max_units > shown_units:
		var extra := Label.new()
		extra.text = "+%d" % (max_units - shown_units)
		extra.add_theme_font_size_override("font_size", 12)
		extra.add_theme_color_override("font_color", Color("#ffd1dc"))
		extra.add_theme_color_override("font_outline_color", Color("#10131f"))
		extra.add_theme_constant_override("outline_size", 2)
		hearts.add_child(extra)

func _make_heart_texture(state: String) -> Texture2D:
	var red := Color("#ff4d6d")
	var dark := Color("#4a2530")
	var shine := Color("#fff0f0")
	var empty := Color("#2d2631")
	var fill := red if state == "full" else dark if state == "half" else empty
	var right := red if state == "full" else empty
	return _make_pixel_texture([
		"................",
		"...oo....oo.....",
		"..oAAo..oBBo....",
		".oAAAAooBBBBo...",
		".oAAAAAABBBBo...",
		"..oAAAABBBBo....",
		"...oAABBBBo.....",
		"....oABBBo......",
		".....oBBo.......",
		"......oo........",
		"................",
		"................"
	], {"o": Color("#10131f"), "A": fill, "B": right, "s": shine})

func _update_boss_bar() -> void:
	if boss_panel == null:
		return
	var in_boss_room: bool = dungeon.get(current_room, "normal") == "boss"
	if not in_boss_room or enemies.get_child_count() == 0:
		boss_panel.visible = false
		return
	var boss := enemies.get_child(0)
	if not ("max_health" in boss) or boss.max_health <= 0:
		boss_panel.visible = false
		return
	boss_panel.visible = true
	var hp_ratio: float = clampf(float(boss.health) / float(boss.max_health), 0.0, 1.0)
	boss_bar.value = hp_ratio * 100.0
	boss_name_label.text = "%s  %d/%d" % [_boss_display_name(), boss.health, boss.max_health]
	if hp_ratio < 0.35:
		boss_bar.add_theme_stylebox_override("fill", _make_card_style(Color("#ff2f4f"), Color("#ff2f4f"), 0))
	elif hp_ratio < 0.7:
		boss_bar.add_theme_stylebox_override("fill", _make_card_style(Color("#ff9b35"), Color("#ff9b35"), 0))
	else:
		boss_bar.add_theme_stylebox_override("fill", _make_card_style(Color("#ff4d6d"), Color("#ff4d6d"), 0))

func _boss_display_name() -> String:
	if boss_state.is_empty():
		return "Dungeon Lord"
	var concept: Dictionary = _boss_concepts[boss_state.get("concept_id", 0)]
	var aspect: Dictionary = _dungeon_aspects[boss_state.get("aspect_id", 0)]
	return "%s %s" % [String(aspect["key"]).capitalize(), String(concept["key"]).capitalize()]

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
	var vp_size := get_viewport_rect().size
	var panel := PanelContainer.new()
	panel.size = Vector2(minf(460.0, vp_size.x - 36.0), 270)
	panel.position = (vp_size - panel.size) * 0.5
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", _make_card_style(Color("#1b1827"), Color("#d8c48a"), 4))
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.size = panel.size - Vector2(24, 22)
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#ff6f7d"))
	title.add_theme_color_override("font_outline_color", Color("#10131f"))
	title.add_theme_constant_override("outline_size", 4)
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
	restart.add_theme_stylebox_override("normal", _make_card_style(Color("#252134"), Color("#8b6f3a"), 3))
	restart.add_theme_stylebox_override("hover", _make_card_style(Color("#302a42"), Color("#ffd464"), 3))
	restart.add_theme_stylebox_override("pressed", _make_card_style(Color("#17131f"), Color("#78ffe1"), 3))
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
	if key == "fire_cooldown":
		return _load_png_texture("res://assets/sprites/icon_trigger.png")
	if key == "shot_speed":
		return _load_png_texture("res://assets/sprites/icon_falcon.png")
	if key == "pierce":
		return _load_png_texture("res://assets/sprites/icon_pierce.png")
	if key == "max_health":
		return _load_png_texture("res://assets/sprites/icon_heart.png")
	if key == "multishot":
		return _load_png_texture("res://assets/sprites/icon_triple.png")
	if key == "homing":
		return _load_png_texture("res://assets/sprites/icon_magnet.png")
	if key == "bullet_size":
		return _load_png_texture("res://assets/sprites/icon_giant.png")
	if key == "split_shot":
		return _load_png_texture("res://assets/sprites/icon_void.png")
	if key == "focus":
		return _load_png_texture("res://assets/sprites/icon_focus.png")
	return _load_png_texture("res://assets/sprites/icon_crown.png")
