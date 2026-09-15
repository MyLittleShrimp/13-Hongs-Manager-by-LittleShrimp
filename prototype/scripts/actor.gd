extends Node2D
## Replaceable whole-body avatar, anchored at the feet. Does not own any game rules.
var profile: Dictionary = {}
var body := Sprite2D.new()
var age := 0.0
var speaking := false
var walking := false
var base_scale := Vector2.ONE
var motion: Tween

static func resolve_texture(path: String) -> Texture2D:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var resource = load(path)
		return resource if resource is Texture2D else null
	if path.begins_with("user://") and FileAccess.file_exists(path):
		var picture := Image.load_from_file(path)
		if not picture.is_empty() and picture.get_width() <= 4096 and picture.get_height() <= 4096:
			return ImageTexture.create_from_image(picture)
	return null

func _ready() -> void:
	add_child(body)
	set_profile(profile)

func set_profile(value: Dictionary) -> void:
	profile = value.duplicate(true)
	var path := str(profile.get("body_texture", "res://assets/characters/player.png"))
	body.texture = resolve_texture(path)
	if body.texture == null:
		body.texture = load("res://assets/characters/player.png")
	if body.texture == null: return
	var h := clampf(float(profile.get("height", 610)), 250, 800)
	var foot: Array = profile.get("source_foot", [0.5, 0.96])
	var dimensions := body.texture.get_size()
	base_scale = Vector2.ONE * h / dimensions.y
	body.scale = base_scale
	body.offset = Vector2(dimensions.x * (0.5 - clampf(float(foot[0]), 0, 1)), dimensions.y * (0.5 - clampf(float(foot[1]), 0, 1)))
	body.modulate = Color(str(profile.get("tint", "ffffff")))
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if body.texture == null: return
	body.scale = base_scale * Vector2(1, 1 + sin(age * 2.3) * 0.004)
	body.position.y = -abs(sin(age * 12)) * 5 if walking else sin(age * 2.3) * 1.2
	body.rotation = sin(age * (12 if walking else 3)) * (0.012 if walking else (0.003 if speaking else 0.0))

func walk_to(destination: Vector2, seconds: float = 0.65) -> void:
	if motion: motion.kill()
	walking = true
	motion = create_tween()
	motion.tween_property(self, "position", destination, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_callback(func(): walking = false)

func _draw() -> void:
	draw_set_transform(Vector2(0, -4), 0, Vector2(1, 0.16))
	draw_circle(Vector2.ZERO, 85, Color(0.08, 0.06, 0.03, 0.22))
	draw_set_transform(Vector2.ZERO)
