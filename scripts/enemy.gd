extends CharacterBody2D

signal defeated(enemy_pos: Vector2)

var target: Node2D
var speed := 72.0
var health := 3
var damage := 1
var visual_scale := 0.55
var enemy_type := "slime"
var sprite: Sprite2D
var wave_timer := 0.0

func _ready() -> void:
	name = "Enemy"
	collision_layer = 2
	collision_mask = 1
	sprite = Sprite2D.new()
	sprite.texture = _load_png_texture(
		"res://assets/sprites/bat.png" if enemy_type == "bat" else "res://assets/sprites/slime.png"
	)
	sprite.scale = Vector2(visual_scale, visual_scale)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8 if enemy_type == "bat" else 10
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var direction := global_position.direction_to(target.global_position)
	if enemy_type == "bat":
		wave_timer += delta
		var perp := Vector2(-direction.y, direction.x)
		velocity = direction * speed + perp * sin(wave_timer * 3.5 * TAU) * 55.0
	else:
		velocity = direction * speed
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		if body != null and body.has_method("take_damage"):
			body.take_damage(damage)

func take_damage(amount: int) -> void:
	health -= amount
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(visual_scale * 1.14, visual_scale * 0.9), 0.05)
	tween.tween_property(sprite, "scale", Vector2(visual_scale, visual_scale), 0.08)
	if health <= 0:
		defeated.emit(global_position)
		queue_free()

func _load_png_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image)
