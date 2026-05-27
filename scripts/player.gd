extends CharacterBody2D

signal died

var speed := 160.0
var max_health := 20
var health := 20
var hurt_cooldown := 0.0
var joystick_direction := Vector2.ZERO
var sprite: Sprite2D

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	sprite = Sprite2D.new()
	sprite.texture = _load_png_texture("res://assets/sprites/player.png")
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	hurt_cooldown = max(0.0, hurt_cooldown - delta)
	var direction: Vector2
	if joystick_direction != Vector2.ZERO:
		direction = joystick_direction
	else:
		direction = Vector2.ZERO
		if Input.is_action_pressed("move_left"):
			direction.x -= 1.0
		if Input.is_action_pressed("move_right"):
			direction.x += 1.0
		if Input.is_action_pressed("move_up"):
			direction.y -= 1.0
		if Input.is_action_pressed("move_down"):
			direction.y += 1.0
		direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()
	if direction.x != 0:
		sprite.flip_h = direction.x < 0

func take_damage(amount: int) -> void:
	if hurt_cooldown > 0.0:
		return
	health -= amount
	hurt_cooldown = 1.0
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color("#ff7a90"), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if health <= 0:
		died.emit()

func _load_png_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image)
