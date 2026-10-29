class_name Art
## Pixel art généré par le code, mis en cache en textures.
## Pour passer à de vrais sprites (Aseprite), remplacer ces fonctions par des preload("res://art/....png").

const BIOPAL := {
	"plain": ["#4f7a3a", "#5f8c44", "#41682f"],
	"forest": ["#2f4a2c", "#3a5a34", "#253d24"],
	"marsh": ["#3f4b36", "#4b5a3f", "#2f3b30"],
	"crypt": ["#2b2433", "#352c40", "#221c29"],
}

static var _cache := {}


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _p(img: Image, x: int, y: int, w: int, h: int, c: String) -> void:
	img.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), Color(c))


static func _base(img: Image, bio: String, v: int) -> void:
	var p: Array = BIOPAL[bio]
	var r := _rng(v * 31 + bio.length() * 7)
	img.fill(Color(p[0]))
	for i in 10:
		_p(img, r.randi_range(0, 15), r.randi_range(0, 15), 1, 1, p[1])
	for i in 6:
		_p(img, r.randi_range(0, 15), r.randi_range(0, 14), 1, 2, p[2])
	if bio == "marsh" and v % 3 == 0:
		_p(img, 4, 7, 7, 3, "#2b3c3a")
		_p(img, 5, 6, 5, 5, "#2b3c3a")


static func tile(type: int, v: int, bio: String, f: int = 0) -> ImageTexture:
	var key := "t%d_%d_%s_%d" % [type, v, bio, f]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var r := _rng(v * 17 + 3)
	match type:
		Defs.T.GRASS, Defs.T.TREE, Defs.T.STUMP, Defs.T.ROCK:
			_base(img, bio, v)
		Defs.T.FLOWER:
			_base(img, bio, v)
			for i in 3:
				var x := r.randi_range(2, 12)
				var y := r.randi_range(2, 12)
				var col: String = ["#e8d35a", "#e07a9a", "#f2efe6", "#b38ae0"][r.randi_range(0, 3)]
				_p(img, x, y - 1, 1, 1, col)
				_p(img, x - 1, y, 3, 1, col)
				_p(img, x, y + 1, 1, 1, col)
				_p(img, x, y, 1, 1, "#f5c542")
		Defs.T.PATH:
			img.fill(Color("#9c7f52"))
			for i in 8:
				_p(img, r.randi_range(0, 14), r.randi_range(0, 14), 2, 1, "#b4976a" if i % 2 else "#836844")
		Defs.T.WATER:
			img.fill(Color("#2a5878"))
			for i in 3:
				_p(img, (v * 3 + i * 5) % 12, (i * 5 + f * 2 + v) % 16, 4, 1, "#4f86a8")
			_p(img, (v * 5) % 14, (v * 7) % 14, 2, 1, "#23496a")
		Defs.T.BRIDGE:
			img.fill(Color("#2a5878"))
			for y in range(0, 16, 4):
				_p(img, 1, y, 14, 3, "#8a5a2b")
				_p(img, 1, y + 3, 14, 1, "#5e3b1a")
			_p(img, 1, 0, 1, 16, "#5e3b1a")
			_p(img, 14, 0, 1, 16, "#5e3b1a")
		Defs.T.WALL:
			img.fill(Color("#4a4552"))
			for y in range(0, 16, 4):
				_p(img, 0, y, 16, 1, "#36313e")
				var o := 0 if (y / 4) % 2 else 6
				_p(img, o, y, 1, 4, "#36313e")
				_p(img, o + 8, y, 1, 4, "#36313e")
			_p(img, 0, 1, 16, 1, "#5c5766")
		Defs.T.GATE:
			img.fill(Color("#221c29"))
			_p(img, 0, 0, 2, 16, "#4a4552")
			_p(img, 14, 0, 2, 16, "#4a4552")
			_p(img, 0, 0, 16, 2, "#4a4552")
			if f == 0:
				for x in range(3, 14, 3):
					_p(img, x, 2, 1, 14, "#8f8a99")
				_p(img, 2, 8, 12, 1, "#8f8a99")
				_p(img, 7, 7, 2, 3, "#b48ae6")
		Defs.T.CRYPT:
			_base(img, "crypt", v)
			_p(img, 0, 0, 16, 1, "#1b1622")
			_p(img, 0, 0, 1, 16, "#1b1622")
			if v % 5 == 0:
				_p(img, 6, 6, 3, 3, "#3e3450")
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func tree(bio: String, v: int) -> ImageTexture:
	var key := "tree_%s_%d" % [bio, v % 2]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	_p(img, 3, 21, 10, 3, "#00000040")
	if bio == "forest":
		_p(img, 7, 18, 2, 5, "#4a301a")
		for l in [[2, 14, 12, 4], [3, 10, 10, 4], [4, 6, 8, 4], [6, 2, 4, 4]]:
			_p(img, l[0], l[1], l[2], l[3], "#1f4a2b")
			_p(img, l[0], l[1] + l[3] - 1, l[2], 1, "#163a21")
			_p(img, l[0] + 1, l[1], 2, 1, "#2f6a3c")
	elif bio == "marsh":
		_p(img, 7, 8, 2, 15, "#5a4a3a")
		_p(img, 4, 9, 3, 1, "#5a4a3a")
		_p(img, 3, 7, 1, 2, "#5a4a3a")
		_p(img, 9, 12, 4, 1, "#5a4a3a")
		_p(img, 12, 10, 1, 2, "#5a4a3a")
		_p(img, 6, 6, 4, 2, "#4c5a3a")
	else:
		var c1 := "#3f7a34" if v % 2 else "#4a8438"
		_p(img, 7, 15, 3, 8, "#5a3b1f")
		_p(img, 8, 15, 1, 8, "#6e4a28")
		_p(img, 2, 6, 12, 10, c1)
		_p(img, 3, 4, 10, 2, c1)
		_p(img, 4, 3, 8, 1, c1)
		_p(img, 1, 8, 14, 6, c1)
		_p(img, 2, 14, 12, 2, "#2f6328")
		_p(img, 4, 5, 4, 2, "#5c9a44")
		_p(img, 3, 7, 2, 2, "#5c9a44")
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func rock() -> ImageTexture:
	if _cache.has("rock"):
		return _cache["rock"]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_p(img, 2, 12, 12, 3, "#00000040")
	_p(img, 3, 5, 10, 9, "#7a7a82")
	_p(img, 2, 7, 12, 6, "#7a7a82")
	_p(img, 4, 4, 7, 1, "#8e8e96")
	_p(img, 4, 5, 4, 2, "#a5a5ad")
	_p(img, 3, 12, 10, 1, "#5e5e66")
	_p(img, 9, 8, 1, 3, "#5e5e66")
	_cache["rock"] = ImageTexture.create_from_image(img)
	return _cache["rock"]


static func stump() -> ImageTexture:
	if _cache.has("stump"):
		return _cache["stump"]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_p(img, 4, 9, 8, 5, "#6b4a2a")
	_p(img, 4, 8, 8, 2, "#a07a4a")
	_p(img, 6, 8, 4, 1, "#c39a62")
	_cache["stump"] = ImageTexture.create_from_image(img)
	return _cache["stump"]


static func light_texture() -> GradientTexture2D:
	if _cache.has("light"):
		return _cache["light"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.85, 1))
	g.set_color(1, Color(1, 0.95, 0.85, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_cache["light"] = t
	return t


static func minimap(map: PackedByteArray, buildings: Array, player: Vector2) -> ImageTexture:
	var cols := {0: "#4f7a3a", 1: "#a08458", 2: "#2a5878", 3: "#24502f", 4: "#8a8a90", 5: "#6a9a4a", 6: "#5a6a3a", 7: "#8a5a2b", 8: "#4a4552", 9: "#b48ae6", 10: "#2b2433"}
	var img := Image.create(Defs.MW * 3, Defs.MH * 3, false, Image.FORMAT_RGBA8)
	for y in Defs.MH:
		for x in Defs.MW:
			var c: int = map[y * Defs.MW + x]
			var col: String = cols[c]
			if c == Defs.T.GRASS and Defs.biome(x, y) == "forest":
				col = "#2f4a2c"
			elif c == Defs.T.GRASS and Defs.biome(x, y) == "marsh":
				col = "#3f4b36"
			img.fill_rect(Rect2i(x * 3, y * 3, 3, 3), Color(col))
	for b in buildings:
		img.fill_rect(Rect2i(b.tx * 3, b.ty * 3, b.w * 3, b.h * 3), Color("#e0b040"))
	var pp := Vector2i(player / Defs.TS * 3)
	img.fill_rect(Rect2i(pp.x - 2, pp.y - 2, 5, 5).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), Color.WHITE)
	return ImageTexture.create_from_image(img)
