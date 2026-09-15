extends SceneTree
func _initialize() -> void:
	var count := 0
	for folder in ["backgrounds", "characters", "props"]:
		for name in DirAccess.get_files_at("res://assets/" + folder):
			if not name.ends_with(".png"): continue
			var path: String = "res://assets/" + folder + "/" + name
			var texture: Texture2D = load(path)
			assert(texture != null, "Load asset " + path)
			var picture := texture.get_image()
			assert(picture.get_width() >= 1000, "Image resolution")
			if folder != "backgrounds":
				assert(picture.detect_alpha() != Image.ALPHA_NONE, "Real transparency " + path)
				assert(picture.get_pixel(0,0).a < 0.01, "Transparent corner " + path)
			print("ASSET ", path, " ", picture.get_size(), " alpha=", picture.detect_alpha())
			count += 1
	assert(count == 16, "Seven scenes, six actors, two crates, one six-item tool atlas")
	print("V5_ASSET_PASS ", count)
	quit(0)
