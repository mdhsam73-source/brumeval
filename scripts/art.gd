class_name Art
## Sprites dessinés (art/tiles.png et art/sprites.png, générés par tools/make_art.py).
## La carte passe par des TileMapLayer, les personnages et bâtiments par des Sprite2D :
## le moteur regroupe tout en quelques appels de dessin au lieu de milliers de rectangles.

const TILES_TEX := preload("res://art/tiles.png")
const SHEET := preload("res://art/sprites.png")
const SRC := 0

static var _cache := {}


static func tile(name: String) -> Vector2i:
	var c: Array = AtlasData.TILES[name]
	return Vector2i(c[0], c[1])


## TileSet construit en code à partir de l'atlas : eau animée, arbres hauts de deux cases.
static func tileset() -> TileSet:
	if _cache.has("ts"):
		return _cache["ts"]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(Defs.TS, Defs.TS)
	var src := TileSetAtlasSource.new()
	src.texture = TILES_TEX
	src.texture_region_size = Vector2i(Defs.TS, Defs.TS)
	ts.add_source(src, SRC)
	for n in AtlasData.TILES:
		var c := tile(n)
		if n.begins_with("tree_"):
			# 32×48 : le feuillage déborde sur les cases voisines, le pied du tronc reste sur sa case.
			src.create_tile(c, Vector2i(2, 3))
			var td := src.get_tile_data(c, 0)
			td.texture_origin = Vector2i(0, 16)
			td.y_sort_origin = 7
		else:
			src.create_tile(c)
			if n == "rock_0" or n == "rock_1" or n == "stump":
				src.get_tile_data(c, 0).y_sort_origin = 6
		if n.begins_with("water_"):
			src.set_tile_animation_frames_count(c, 2)
			src.set_tile_animation_frame_duration(c, 0, 0.6)
			src.set_tile_animation_frame_duration(c, 1, 0.6)
	_cache["ts"] = ts
	return ts


static func anim(name: String) -> Dictionary:
	return AtlasData.SPRITES[name]


## Crée un Sprite2D dont le point d'ancrage (pieds, ou bas du bâtiment) est à sa position.
static func sprite(name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SHEET
	s.centered = false
	s.region_enabled = true
	set_frame(s, name, 0)
	return s


static func set_frame(s: Sprite2D, name: String, i: int) -> void:
	var a: Dictionary = AtlasData.SPRITES[name]
	var r := Rect2(a.x + (i % int(a.n)) * a.w, a.y, a.w, a.h)
	if s.region_rect != r:
		s.region_rect = r
	s.offset = Vector2(-a.ox, -a.oy)


static func frame_texture(name: String, i: int) -> AtlasTexture:
	var a: Dictionary = AtlasData.SPRITES[name]
	var t := AtlasTexture.new()
	t.atlas = SHEET
	t.region = Rect2(a.x + i * a.w, a.y, a.w, a.h)
	return t


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
	t.width = 64
	t.height = 64
	_cache["light"] = t
	return t


static func minimap(map: PackedByteArray, buildings: Array, player: Vector2) -> ImageTexture:
	var cols := {0: "#5a8a3f", 1: "#a2865a", 2: "#2f6a8e", 3: "#2f5f2a", 4: "#8a8792", 5: "#7aa04a", 6: "#6b4a2a", 7: "#9a6a3a", 8: "#57516a", 9: "#b48ae6", 10: "#3a3346"}
	var img := Image.create(Defs.MW * 3, Defs.MH * 3, false, Image.FORMAT_RGBA8)
	for y in Defs.MH:
		for x in Defs.MW:
			var c: int = map[y * Defs.MW + x]
			var col: String = cols[c]
			if c == Defs.T.GRASS and Defs.biome(x, y) == "forest":
				col = "#34573a"
			elif c == Defs.T.GRASS and Defs.biome(x, y) == "marsh":
				col = "#4a5a3c"
			elif c == Defs.T.TREE and Defs.biome(x, y) == "forest":
				col = "#1f4030"
			img.fill_rect(Rect2i(x * 3, y * 3, 3, 3), Color(col))
	for b in buildings:
		img.fill_rect(Rect2i(b.tx * 3, b.ty * 3, b.w * 3, b.h * 3), Color("#e0b040"))
	var pp := Vector2i(player / Defs.TS * 3)
	img.fill_rect(Rect2i(pp.x - 2, pp.y - 2, 5, 5).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), Color.WHITE)
	return ImageTexture.create_from_image(img)
