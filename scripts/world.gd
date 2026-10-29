extends Node2D
## Le monde de Brumeval : carte, joueur, créatures, PNJ, bâtiments, temps, sauvegarde.
## Rendu : carte en TileMapLayer (sol, détails, objets triés en profondeur), personnages et
## bâtiments en Sprite2D (voir Art). _draw_overlay() ne dessine que les barres de vie et les effets.

signal toast(text: String, kind: String)
signal dialog_requested(npc)
signal panel_requested(kind: String)

const TS := Defs.TS
const MW := Defs.MW
const MH := Defs.MH
const T := Defs.T
const PATHLIKE := [Defs.T.PATH, Defs.T.BRIDGE, Defs.T.GATE]
const WATERLIKE := [Defs.T.WATER, Defs.T.BRIDGE]
const FLASH := Color(3, 3, 3, 1)
## Au-delà de cette distance du joueur, les créatures « dorment » (pas d'IA) pour économiser le processeur.
const SLEEP_R2 := 420.0 * 420.0


class Ent:
	var kind := ""
	var name := ""
	var pos := Vector2.ZERO
	var home := Vector2.ZERO
	var dir := Vector2i(0, 1)
	var hp := 1.0
	var maxhp := 1.0
	var atk := 1
	var spd := 40.0
	var lvl := 1
	var zone := -1
	var cd := 0.0
	var anim := 0.0
	var hit_t := 0.0
	var prov := 0.0
	var wt := 0.0
	var mv := Vector2.ZERO
	var moving := false
	var ally := false
	var dead := false
	var seed := 0.0
	var tunic := Color.WHITE
	var hair := Color.BLACK
	var aff := 0
	var talks := 0
	var follow := false
	var spouse := false
	var vc := 0
	var spr: Sprite2D

	func is_mon() -> bool:
		return Defs.MON.has(kind)

	func is_npc() -> bool:
		return kind == "villager" or kind == "elder" or kind == "trader"


class Bld:
	var k := ""
	var tx := 0
	var ty := 0
	var w := 1
	var h := 1
	var cd := 0.0
	var light: PointLight2D
	var spr: Sprite2D

	func center() -> Vector2:
		return Vector2((tx + w / 2.0) * Defs.TS, (ty + h) * Defs.TS - 4)


var mode := "title"
var paused := false
var map := PackedByteArray()
var bgrid := PackedByteArray()
var thp := {}
var seed_val := 0
var day := 1
var time := 0.3
var quest := 0
var qbase := 0
var stats := {}
var flags := {}
var chest_open := false
var chest_pos := Vector2(65 * TS + 8, 4 * TS + 12)
var ents: Array[Ent] = []
var buildings: Array[Bld] = []
var projs: Array = []
var fx: Array = []
var placing := ""
var shake := 0.0
var spawn_t := 0.0
var clock := 0.0

# joueur
var p_pos := Vector2.ZERO
var p_dir := Vector2i(0, 1)
var p_hp := 60.0
var lvl := 1
var xp := 0
var gold := 15
var inv := {}
var mask := ""
var sword := false
var armor := false
var relic := false
var spouse := ""
var body := {}
var shell := {}
var atk_cd := 0.0
var swing := 0.0
var hurt_t := 0.0
var p_anim := 0.0
var p_moving := false
var dead_t := 0.0

@onready var cam: Camera2D = $Camera
@onready var night: CanvasModulate = $Night
var p_light: PointLight2D
var ground: TileMapLayer
var deco: TileMapLayer
var objs: TileMapLayer
var ysort: Node2D
var overlay: Node2D
var p_spr: Sprite2D
var p_mask: Sprite2D
var shell_spr: Sprite2D
var chest_spr: Sprite2D
var _gate_shown := false


func _ready() -> void:
	_setup_layers()
	p_light = _make_light(48)
	add_child(p_light)
	new_game(1234)


# ---------------------------------------------------------------- Monde

func _noise(r: RandomNumberGenerator, gw: int, gh: int) -> Callable:
	var g := PackedFloat32Array()
	for i in (gw + 1) * (gh + 1):
		g.append(r.randf())
	return func(u: float, v: float) -> float:
		var x := u * gw
		var y := v * gh
		var x0 := int(floor(x))
		var y0 := int(floor(y))
		var fx := smoothstep(0.0, 1.0, x - x0)
		var fy := smoothstep(0.0, 1.0, y - y0)
		var at := func(a: int, b: int) -> float: return g[mini(b, gh) * (gw + 1) + mini(a, gw)]
		var a: float = lerpf(at.call(x0, y0), at.call(x0 + 1, y0), fx)
		var b: float = lerpf(at.call(x0, y0 + 1), at.call(x0 + 1, y0 + 1), fx)
		return lerpf(a, b, fy)


func gen_map(s: int) -> PackedByteArray:
	var r := RandomNumberGenerator.new()
	r.seed = s
	var m := PackedByteArray()
	m.resize(MW * MH)
	var nz := _noise(r, 9, 7)
	var nz2 := _noise(r, 14, 11)
	for y in MH:
		for x in MW:
			var b := Defs.biome(x, y)
			var n: float = nz.call(float(x) / MW, float(y) / MH)
			var n2: float = nz2.call(float(x) / MW, float(y) / MH)
			var dv := Vector2(x - Defs.VX, y - Defs.VY).length()
			var tl: int = T.FLOWER if (b == "plain" and r.randf() < 0.07) else T.GRASS
			if b == "crypt":
				m[y * MW + x] = T.GRASS
				continue
			var wth := 0.57 if b == "marsh" else 0.7
			if dv > 9 and n > wth:
				tl = T.WATER
			elif dv > 8:
				var tp := 0.3 if b == "forest" else (0.06 if b == "marsh" else (0.2 if n2 > 0.62 else 0.035))
				var q := r.randf()
				if q < tp:
					tl = T.TREE
				elif q < tp + (0.03 if b == "forest" else 0.022):
					tl = T.ROCK
			if x < 2 or y < 2 or x >= MW - 2 or y >= MH - 2:
				tl = T.TREE
			m[y * MW + x] = tl
	for y in range(40, 49):
		for x in range(26, 35):
			if Vector2(x - 30, y - 44).length() < 4.5:
				m[y * MW + x] = T.GRASS
	for y in range(1, 11):
		for x in range(59, 71):
			m[y * MW + x] = T.WALL if (x == 59 or x == 70 or y == 1 or y == 10) else T.CRYPT
	m[10 * MW + 65] = T.GATE
	var paths := [[Defs.VX, Defs.VY, 62, Defs.VY], [Defs.VX, Defs.VY, Defs.VX, 4], [Defs.VX, Defs.VY, Defs.VX, MH - 4],
		[Defs.VX, Defs.VY + 8, 30, Defs.VY + 8], [30, Defs.VY + 8, 30, 40], [52, Defs.VY, 52, 46],
		[62, Defs.VY, 65, Defs.VY], [65, Defs.VY, 65, 11], [Defs.VX, 6, 44, 6]]
	for p in paths:
		_path(m, p[0], p[1], p[2], p[3])
	for y in range(Defs.VY - 3, Defs.VY + 4):
		for x in range(Defs.VX - 3, Defs.VX + 4):
			m[y * MW + x] = T.PATH
	return m


func _path(m: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> void:
	var x := x0
	var y := y0
	var cells := []
	while x != x1:
		cells.append(Vector2i(x, y))
		x += signi(x1 - x)
	while y != y1:
		cells.append(Vector2i(x, y))
		y += signi(y1 - y)
	cells.append(Vector2i(x, y))
	for c in cells:
		var i: int = c.y * MW + c.x
		if m[i] == T.WALL or m[i] == T.GATE:
			continue
		m[i] = T.BRIDGE if m[i] == T.WATER else T.PATH


func _reset(s: int, m: PackedByteArray) -> void:
	for b in buildings:
		if b.light:
			b.light.queue_free()
		b.spr.queue_free()
	for e in ents:
		if e.spr:
			e.spr.queue_free()
	seed_val = s
	map = m
	bgrid = PackedByteArray()
	bgrid.resize(MW * MH)
	thp = {}
	day = 1
	time = 0.3
	quest = 0
	qbase = 0
	stats = {"wood": 0, "kills": {}, "masks": 0, "souls": 0}
	flags = {}
	chest_open = false
	ents.clear()
	buildings.clear()
	projs.clear()
	fx.clear()
	placing = ""
	p_pos = Vector2((Defs.VX + 0.5) * TS, (Defs.VY + 3) * TS)
	p_dir = Vector2i(0, 1)
	p_hp = 60.0
	lvl = 1
	xp = 0
	gold = 15
	inv = {"potion": 2}
	mask = ""
	sword = false
	armor = false
	relic = false
	spouse = ""
	body = {}
	shell = {}
	dead_t = 0.0
	hurt_t = 0.0
	rebuild_tiles()


func new_game(s: int) -> void:
	_reset(s, gen_map(s))
	add_npc("elder", "elder", Vector2((Defs.VX - 1) * TS, (Defs.VY - 1) * TS))
	add_npc("trader", "trader", Vector2((Defs.VX + 3) * TS, (Defs.VY - 2) * TS))
	for i in 3:
		add_villager(Vector2.INF)
	ents.append(mk_mon("chef", 6, Vector2(30 * TS + 8, 44 * TS + 8), 1))
	_add_tents()
	fill_spawns(true)
	qbase = quest_value(0)


func _add_tents() -> void:
	for p in [Vector2(28 * TS, 43 * TS), Vector2(32 * TS + 8, 42 * TS + 8), Vector2(31 * TS, 46 * TS + 6)]:
		var e := Ent.new()
		e.kind = "tent"
		e.pos = p
		ents.append(e)


func add_npc(kind: String, n: String, p: Vector2) -> Ent:
	var e := Ent.new()
	e.kind = kind
	e.name = n
	e.pos = p
	e.home = p
	e.hp = 40
	e.maxhp = 40
	e.atk = 4
	e.seed = randf() * 9
	ents.append(e)
	return e


func add_villager(at: Vector2) -> Ent:
	var used := []
	for e in ents:
		if e.kind == "villager":
			used.append(e.name)
	var free := Defs.VNAMES.filter(func(n): return not used.has(n))
	if free.is_empty():
		return null
	var p := at if at != Vector2.INF else Vector2((Defs.VX + randf_range(-4, 4)) * TS, (Defs.VY + randf_range(-4, 4)) * TS)
	var e := add_npc("villager", free.pick_random(), p)
	e.vc = randi() % Defs.VCOL.size()
	var c: Array = Defs.VCOL[e.vc]
	e.tunic = Color(c[0])
	e.hair = Color(c[1])
	return e


func mk_mon(kind: String, l: int, p: Vector2, zone: int) -> Ent:
	var d: Dictionary = Defs.MON[kind]
	var k := 1.0 + 0.25 * (l - 1)
	var e := Ent.new()
	e.kind = kind
	e.lvl = l
	e.pos = p
	e.home = p
	e.zone = zone
	e.hp = round(d.hp * k)
	e.maxhp = e.hp
	e.atk = int(round(d.atk * (1.0 + 0.18 * (l - 1))))
	e.spd = d.spd
	e.anim = randf() * 5
	e.dir = Vector2i(1, 0)
	e.seed = randf() * 9
	return e


func count_b(k: String) -> int:
	return buildings.filter(func(b): return b.k == k).size()


# ---------------------------------------------------------------- Collisions

func gate_open() -> bool:
	return Settings.tier >= 2


func solid_t(tx: int, ty: int, fly: bool) -> bool:
	if tx < 0 or ty < 0 or tx >= MW or ty >= MH:
		return true
	var i := ty * MW + tx
	if bgrid[i]:
		return true
	var c := map[i]
	if c == T.WATER:
		return not fly
	if c == T.GATE:
		return not gate_open()
	return c == T.TREE or c == T.ROCK or c == T.WALL


func can_at(p: Vector2, fly: bool) -> bool:
	for a in [p.x - 4, p.x + 3]:
		for b in [p.y - 3, p.y]:
			if solid_t(int(floor(a / TS)), int(floor(b / TS)), fly):
				return false
	return true


func move_pos(p: Vector2, d: Vector2, fly: bool) -> Vector2:
	if can_at(p + Vector2(d.x, 0), fly):
		p.x += d.x
	if can_at(p + Vector2(0, d.y), fly):
		p.y += d.y
	return p


# ---------------------------------------------------------------- Joueur

func max_hp() -> int:
	return 60 + 12 * (lvl - 1)


func atk_p() -> int:
	if body:
		return body.atk
	return 4 + 2 * (lvl - 1) + (4 if sword else 0) + (5 if relic else 0)


func def_p() -> int:
	if body:
		return 0
	return (2 if armor else 0) + (1 if spouse != "" else 0)


func spd_p() -> float:
	if body:
		return minf(95.0, Defs.MON[body.kind].spd * 1.5)
	return 62.0


func body_fly() -> bool:
	return not body.is_empty() and Defs.MON[body.kind].get("fly", false)


func xp_need(l: int) -> int:
	return int(round(20 * pow(l, 1.5)))


func darkness() -> float:
	var v := clampf((cos(time * TAU) + 0.25) * 0.62, 0.0, 0.74)
	if mode == "play" and Defs.biome(int(p_pos.x / TS), int(p_pos.y / TS)) == "crypt":
		v = maxf(v, 0.62)
	return v


func is_night() -> bool:
	return darkness() > 0.3


func friendly(e: Ent) -> bool:
	if e.prov > 0:
		return false
	var f: String = Defs.FACTION[e.kind]
	if body and Defs.FACTION[body.kind] == f:
		return true
	if mask != "" and Defs.MASKF[mask] == f:
		return true
	return false


func add_xp(n: int) -> void:
	if Settings.tier >= 3:
		n = int(round(n * 1.1))
	xp += n
	while xp >= xp_need(lvl):
		xp -= xp_need(lvl)
		lvl += 1
		p_hp = max_hp()
		toast.emit(Lang.t("level_up", [lvl]), "good")
		burst(p_pos + Vector2(0, -8), Color("#ffe27a"), 14)


func give(k: String, n: int = 1) -> void:
	if k == "gold":
		gold += n
		return
	inv[k] = inv.get(k, 0) + n
	if Defs.MASKF.has(k):
		stats.masks += 1


func has(need: Dictionary) -> bool:
	for k in need:
		var h: int = gold if k == "gold" else inv.get(k, 0)
		if h < need[k]:
			return false
	return true


func take(need: Dictionary) -> void:
	for k in need:
		if k == "gold":
			gold -= need[k]
		else:
			inv[k] -= need[k]
			if inv[k] <= 0:
				inv.erase(k)


func heal_item(k: String) -> void:
	if not inv.get(k, 0) or body:
		return
	take({k: 1})
	var h := 60 if k == "stew" else 35
	p_hp = minf(max_hp(), p_hp + h)
	float_t(p_pos + Vector2(0, -18), "+%d" % h, Color("#8fe08a"))


func _update_player(dt: float) -> void:
	atk_cd -= dt
	swing -= dt
	hurt_t -= dt
	if dead_t > 0:
		dead_t -= dt
		if dead_t <= 0:
			_respawn()
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	p_moving = v.length() > 0.15
	if p_moving:
		p_pos = move_pos(p_pos, v * spd_p() * dt, body_fly())
		p_anim += dt
		if absf(v.x) > absf(v.y):
			p_dir = Vector2i(signi(int(signf(v.x))), 0)
		else:
			p_dir = Vector2i(0, int(signf(v.y)))
	if Input.is_action_pressed("attack") and placing == "":
		player_attack()
	if body.is_empty():
		for b in buildings:
			if b.k == "campfire" and b.center().distance_to(p_pos) < 40:
				p_hp = minf(max_hp(), p_hp + 4 * dt)
		if spouse != "":
			p_hp = minf(max_hp(), p_hp + 0.5 * dt)


func player_attack() -> void:
	if atk_cd > 0 or dead_t > 0:
		return
	atk_cd = 0.36
	swing = 0.14
	var hit_p := p_pos + Vector2(p_dir) * 12 + Vector2(0, -5)
	var hit := false
	for e in ents:
		if not e.is_mon() or e.ally or e.dead:
			continue
		if (e.pos + Vector2(0, -6)).distance_to(hit_p) < 14:
			hit = true
			if friendly(e):
				var f: String = Defs.FACTION[e.kind]
				for o in ents:
					if o.is_mon() and not o.ally and Defs.FACTION[o.kind] == f and o.pos.distance_to(e.pos) < 110:
						o.prov = 10
				toast.emit(Lang.t("mask_broken"), "bad")
			damage_e(e, maxi(1, int(round(atk_p() * randf_range(0.85, 1.15)))), p_pos)
	if not hit:
		_hit_tile(int(floor(hit_p.x / TS)), int(floor((hit_p.y + 3) / TS)))


func _hit_tile(tx: int, ty: int) -> void:
	if tx < 0 or ty < 0 or tx >= MW or ty >= MH:
		return
	var i := ty * MW + tx
	var c := map[i]
	if c != T.TREE and c != T.ROCK:
		return
	if body:
		toast.emit(Lang.t("cant_here"), "")
		return
	var hp: int = thp.get(i, 3 if c == T.TREE else 4) - 1
	thp[i] = hp
	shake = 0.06
	var cp := Vector2(tx * TS + 8, ty * TS + 8)
	burst(cp, Color("#7a5a2a") if c == T.TREE else Color("#9a9aa2"), 5)
	if c == T.TREE:
		give("wood")
		stats.wood += 1
		float_t(cp + Vector2(0, -6), "+1 " + Lang.nm("wood"), Color("#e8d0a0"))
	else:
		give("stone")
		float_t(cp + Vector2(0, -6), "+1 " + Lang.nm("stone"), Color("#d0d0d8"))
		if Defs.biome(tx, ty) != "plain" and randf() < 0.12:
			give("crystal")
			float_t(cp + Vector2(0, -14), "+1 " + Lang.nm("crystal"), Color("#b9a0ff"))
	if hp <= 0:
		thp.erase(i)
		if c == T.TREE:
			set_tile(i, T.STUMP)
			give("wood", 2)
			stats.wood += 2
		else:
			set_tile(i, T.GRASS)


func damage_p(amt: int, src: Vector2) -> void:
	if dead_t > 0 or hurt_t > 0:
		return
	var mul := (1.25 if is_night() else 1.0) * Settings.diff_mul() * randf_range(0.85, 1.15)
	var d := maxi(1, int(round(amt * mul)) - def_p())
	hurt_t = 0.45
	if Settings.shake:
		shake = 0.15
	float_t(p_pos + Vector2(0, -18), "-%d" % d, Color("#ff7a6a"))
	p_pos = move_pos(p_pos, (p_pos - src).normalized() * 6, body_fly())
	if body:
		body.hp -= d
		if body.hp <= 0:
			soul_return(true)
		return
	p_hp -= d
	if p_hp <= 0:
		p_hp = 0
		dead_t = 1.6
		toast.emit(Lang.t("died"), "bad")


func _respawn() -> void:
	var fire: Bld = null
	for b in buildings:
		if b.k == "campfire":
			fire = b
			break
	p_pos = fire.center() + Vector2(0, 18) if fire else Vector2((Defs.VX + 0.5) * TS, (Defs.VY + 3) * TS)
	p_hp = max_hp()
	gold = int(gold * 0.8)
	hurt_t = 1.5


# ---------------------------------------------------------------- Âme

func soul_action() -> void:
	if dead_t > 0:
		return
	if body:
		soul_return(false)
		return
	var best: Ent = null
	var bd := 26.0
	for e in ents:
		if e.is_mon() and not e.ally and not e.dead and e.pos.distance_to(p_pos) < bd:
			bd = e.pos.distance_to(p_pos)
			best = e
	if best == null or best.hp / best.maxhp > 0.35:
		toast.emit(Lang.t("soul_need"), "")
		return
	if Defs.MON[best.kind].get("boss", false):
		toast.emit(Lang.t("soul_boss"), "bad")
		return
	shell = {"pos": p_pos, "dir": p_dir}
	body = {"kind": best.kind, "lvl": best.lvl, "hp": round(best.maxhp * 0.7), "maxhp": best.maxhp, "atk": best.atk + 2}
	p_pos = best.pos
	best.dead = true
	stats.souls += 1
	burst(p_pos + Vector2(0, -8), Color("#9fe6ff"), 18)
	toast.emit(Lang.t("soul_in", [Lang.nm(best.kind)]), "good")


func soul_return(forced: bool) -> void:
	if body.is_empty():
		return
	if not forced:
		var allies := ents.filter(func(e): return e.ally and e.is_mon() and not e.dead).size()
		if allies >= 4:
			toast.emit(Lang.t("ally_full"), "")
		else:
			var e := mk_mon(body.kind, body.lvl, p_pos, -1)
			e.ally = true
			e.hp = maxf(1, body.hp)
			ents.append(e)
		toast.emit(Lang.t("soul_out"), "good")
	else:
		toast.emit(Lang.t("soul_forced"), "bad")
		p_hp = maxf(1, p_hp - round(max_hp() * 0.2))
	burst(p_pos + Vector2(0, -8), Color("#9fe6ff"), 14)
	body = {}
	p_pos = shell.pos
	p_dir = shell.dir
	shell = {}
	hurt_t = 0.8


# ---------------------------------------------------------------- Créatures et PNJ

func damage_e(e: Ent, amt: int, src: Vector2) -> void:
	e.hp -= amt
	e.hit_t = 0.15
	float_t(e.pos + Vector2(0, -16), "-%d" % amt, Color.WHITE)
	burst(e.pos + Vector2(0, -6), Color("#ffd0a0"), 4)
	var boss: bool = e.is_mon() and Defs.MON[e.kind].get("boss", false)
	var fly: bool = e.is_mon() and Defs.MON[e.kind].get("fly", false)
	e.pos = move_pos(e.pos, (e.pos - src).normalized() * (2.0 if boss else 7.0), fly)
	if e.hp > 0:
		return
	if e.kind == "villager":
		e.hp = e.maxhp
		e.follow = false
		e.pos = e.home
		toast.emit(Lang.t("ally_down", [e.name]), "bad")
	elif e.ally:
		e.dead = true
		toast.emit(Lang.t("ally_down", [Lang.nm(e.kind)]), "bad")
	else:
		_kill(e)


func _kill(e: Ent) -> void:
	e.dead = true
	var d: Dictionary = Defs.MON[e.kind]
	stats.kills[e.kind] = stats.kills.get(e.kind, 0) + 1
	add_xp(int(round(d.xp * (1 + 0.15 * (e.lvl - 1)))))
	var gd := randi_range(d.gold[0], d.gold[1])
	if gd:
		give("gold", gd)
		float_t(e.pos + Vector2(0, -22), "+%d %s" % [gd, Lang.nm("gold")], Color("#ffd76a"))
	var yo := -30
	for dr in d.drops:
		if randf() < dr[1]:
			give(dr[0])
			float_t(e.pos + Vector2(0, yo), "+" + Lang.nm(dr[0]), Color("#bfe0ff"))
			yo -= 8
	burst(e.pos + Vector2(0, -6), Color("#dcdcdc"), 10)
	if e.kind == "chef":
		toast.emit(Lang.t("chef_down"), "good")
		flags["chef_day"] = day


func nearest_hostile(p: Vector2, r: float) -> Ent:
	var best: Ent = null
	var bd := r
	for e in ents:
		if e.is_mon() and not e.ally and not e.dead and e.pos.distance_to(p) < bd:
			bd = e.pos.distance_to(p)
			best = e
	return best


func _face(e: Ent, v: Vector2) -> void:
	e.dir = Vector2i(int(signf(v.x)), 0) if absf(v.x) > absf(v.y) else Vector2i(0, int(signf(v.y)))


func _step_to(e: Ent, target: Vector2, sp: float, dt: float, fly: bool) -> void:
	var v := (target - e.pos).normalized()
	e.pos = move_pos(e.pos, v * sp * dt, fly)
	_face(e, v)
	e.moving = true


func _wander(e: Ent, dt: float, sp: float, leash: float, fly: bool) -> void:
	e.wt -= dt
	if e.wt <= 0:
		e.wt = randf_range(1, 3)
		e.mv = Vector2.ZERO if randf() < 0.4 else Vector2.from_angle(randf() * TAU)
		if e.pos.distance_to(e.home) > leash:
			e.mv = (e.home - e.pos).normalized()
	e.moving = e.mv != Vector2.ZERO
	if e.moving:
		e.pos = move_pos(e.pos, e.mv * sp * dt, fly)
		_face(e, e.mv)


func _update_ent(e: Ent, dt: float) -> void:
	if e.kind == "tent" or e.dead:
		return
	e.anim += dt
	e.hit_t = maxf(0, e.hit_t - dt)
	e.cd -= dt
	e.prov -= dt
	e.moving = false
	if e.kind == "elder" or e.kind == "trader":
		e.dir = Vector2i(0, 1)
		return
	if e.kind == "villager":
		if e.follow:
			_ally_ai(e, dt, 55, false)
		else:
			_wander(e, dt, 22, 16 if is_night() else 56, false)
		return
	var d: Dictionary = Defs.MON[e.kind]
	var fly: bool = d.get("fly", false)
	if e.ally:
		_ally_ai(e, dt, maxf(55, e.spd), fly)
		return
	var tgt_pos := Vector2.INF
	var tgt: Ent = null
	var night_mul := 1.2 if is_night() else 1.0
	if dead_t <= 0 and not friendly(e) and e.pos.distance_to(p_pos) < d.aggro * night_mul:
		if d.get("boss", false) or e.pos.distance_to(e.home) < 260:
			tgt_pos = p_pos
	if tgt_pos == Vector2.INF:
		for o in ents:
			if (o.ally or (o.kind == "villager" and o.follow)) and not o.dead and o.pos.distance_to(e.pos) < 55:
				tgt = o
				tgt_pos = o.pos
				break
	if tgt_pos != Vector2.INF:
		var dd := e.pos.distance_to(tgt_pos)
		if dd > 11:
			_step_to(e, tgt_pos, e.spd * (1.15 if e.prov > 0 else 1.0), dt, fly)
		if dd < 14 and e.cd <= 0:
			e.cd = 1.3 if d.get("boss", false) else 1.0
			if tgt == null:
				damage_p(e.atk, e.pos)
			else:
				damage_e(tgt, maxi(1, int(round(e.atk * 0.8))), e.pos)
	else:
		_wander(e, dt, e.spd * 0.45, 40 if d.get("boss", false) else 90, fly)


func _ally_ai(e: Ent, dt: float, sp: float, fly: bool) -> void:
	var tg := nearest_hostile(e.pos, 70)
	if tg and (not friendly(tg) or tg.prov > 0):
		var dd := e.pos.distance_to(tg.pos)
		if dd > 11:
			_step_to(e, tg.pos, sp, dt, fly)
		if dd < 15 and e.cd <= 0:
			e.cd = 1.0
			damage_e(tg, maxi(1, int(round(e.atk * randf_range(0.8, 1.2)))), e.pos)
		return
	var dp := e.pos.distance_to(p_pos)
	if dp > 200:
		e.pos = p_pos + Vector2(-10, 0)
	elif dp > 26:
		_step_to(e, p_pos, sp * (1.5 if dp > 80 else 1.0), dt, fly)


func fill_spawns(initial: bool) -> void:
	for zi in Defs.ZONES.size():
		var z: Dictionary = Defs.ZONES[zi]
		var n := ents.filter(func(e): return e.zone == zi and not e.dead and not e.ally).size()
		for i in range(n, z.cap):
			var fly: bool = Defs.MON[z.kind].get("fly", false)
			for tries in 30:
				var tx := randi_range(z.a[0], z.a[2])
				var ty := randi_range(z.a[1], z.a[3])
				if zi == 0 and Vector2(tx - Defs.VX, ty - Defs.VY).length() < 12:
					continue
				var p := Vector2(tx * TS + 8, ty * TS + 12)
				if not can_at(p, fly) or map[ty * MW + tx] == T.WATER:
					continue
				if not initial and p.distance_to(p_pos) < 150:
					continue
				ents.append(mk_mon(z.kind, randi_range(z.lv[0], z.lv[1]), p, zi))
				break
			if not initial:
				break


# ---------------------------------------------------------------- Bâtiments

func can_place(k: String, tx: int, ty: int) -> bool:
	var b: Dictionary = Defs.BLD[k]
	for y in range(ty, ty + b.h):
		for x in range(tx, tx + b.w):
			if x < 1 or y < 1 or x >= MW - 1 or y >= MH - 1:
				return false
			var c := map[y * MW + x]
			if c != T.GRASS and c != T.FLOWER and c != T.PATH and c != T.STUMP:
				return false
			if bgrid[y * MW + x]:
				return false
			if Rect2(x * TS, y * TS, TS, TS).intersects(Rect2(p_pos.x - 4, p_pos.y - 3, 8, 3)):
				return false
	return true


func place_spot() -> Vector2i:
	var b: Dictionary = Defs.BLD[placing]
	var tx := int(floor((p_pos.x + p_dir.x * 14) / TS))
	var ty := int(floor((p_pos.y - 2 + p_dir.y * 14) / TS))
	if p_dir.x < 0:
		tx -= b.w - 1
	if p_dir.y < 0 or p_dir.x != 0:
		ty -= b.h - 1
	return Vector2i(tx, ty)


func add_building(k: String, tx: int, ty: int) -> Bld:
	var d: Dictionary = Defs.BLD[k]
	var o := Bld.new()
	o.k = k
	o.tx = tx
	o.ty = ty
	o.w = d.w
	o.h = d.h
	buildings.append(o)
	o.spr = Art.sprite(k)
	o.spr.position = Vector2(tx * TS, (ty + o.h) * TS)
	ysort.add_child(o.spr)
	if k == "mill":
		var bl := Art.sprite("mill_blades")
		bl.position = Vector2(16, -36)
		o.spr.add_child(bl)
	for y in range(ty, ty + o.h):
		for x in range(tx, tx + o.w):
			bgrid[y * MW + x] = 1
	var radius := {"campfire": 62, "statue": 70, "house": 26, "tower": 30}
	if radius.has(k):
		o.light = _make_light(radius[k])
		o.light.position = o.center() + Vector2(0, -8)
		add_child(o.light)
	return o


func place_building() -> void:
	var k := placing
	var s := place_spot()
	placing = ""
	if not can_place(k, s.x, s.y):
		toast.emit(Lang.t("blocked"), "bad")
		return
	if not has(Defs.BLD[k].cost):
		toast.emit(Lang.t("not_enough"), "bad")
		return
	take(Defs.BLD[k].cost)
	var o := add_building(k, s.x, s.y)
	burst(o.center() + Vector2(0, -8), Color("#e8d0a0"), 14)
	toast.emit(Lang.t("built", [Lang.nm(k)]), "good")
	if k == "house":
		var v := add_villager(o.center() + Vector2(0, 12))
		if v:
			toast.emit(Lang.t("new_villager", [v.name]), "good")


func _update_buildings(dt: float) -> void:
	for b in buildings:
		if b.k != "tower":
			continue
		b.cd -= dt
		if b.cd > 0:
			continue
		var src := b.center() + Vector2(0, -24)
		var tg := nearest_hostile(src, 95)
		if tg and not friendly(tg):
			b.cd = 1.2
			var v := (tg.pos + Vector2(0, -6) - src).normalized() * 180
			projs.append({"pos": src, "v": v, "t": 0.8, "dmg": 6 + lvl / 2})
	for pr in projs:
		pr.pos += pr.v * dt
		pr.t -= dt
		for e in ents:
			if e.is_mon() and not e.ally and not e.dead and (e.pos + Vector2(0, -6)).distance_to(pr.pos) < 7:
				damage_e(e, pr.dmg, pr.pos)
				pr.t = 0
				break
	projs = projs.filter(func(p): return p.t > 0)


# ---------------------------------------------------------------- Temps et quêtes

func _new_day() -> void:
	day += 1
	toast.emit(Lang.t("new_day"), "")
	var farms := count_b("farm")
	var mills := count_b("mill")
	if farms or mills:
		give("berry", farms * 3)
		give("gold", mills * 8)
		toast.emit(Lang.t("harvest", [farms * 3, mills * 8]), "good")
	if spouse != "":
		give("potion")
	for e in ents:
		if e.kind == "villager":
			e.talks = 0
	for i in MW * MH:
		if map[i] == T.STUMP and randf() < 0.35:
			set_tile(i, T.TREE)
		elif map[i] == T.GRASS and Defs.biome(i % MW, i / MW) == "plain" and not bgrid[i] and randf() < 0.004:
			set_tile(i, T.FLOWER)
	if flags.get("chef_day", 0) and day >= flags.chef_day + 3 and not ents.any(func(e): return e.kind == "chef" and not e.dead):
		ents.append(mk_mon("chef", 6 + day / 5, Vector2(30 * TS + 8, 44 * TS + 8), 1))
		flags.chef_day = 0
	for i in 4:
		fill_spawns(false)
	write_save("auto")


func quest_value(i: int) -> int:
	var s: String = Defs.QUESTS[i].stat
	if s.begins_with("b_"):
		return count_b(s.substr(2))
	if s.begins_with("k_"):
		return stats.kills.get(s.substr(2), 0)
	if s == "best_aff":
		var m := 0
		for e in ents:
			if e.kind == "villager":
				m = maxi(m, e.aff)
		return m
	if s == "lvl":
		return lvl
	return stats.get(s, 0)


## Retourne {} quand toutes les quêtes sont faites.
func quest_progress() -> Dictionary:
	if quest >= Defs.QUESTS.size():
		return {}
	var q: Dictionary = Defs.QUESTS[quest]
	var v := quest_value(quest) - (qbase if q.get("d", false) else 0)
	return {"v": mini(v, q.goal), "goal": q.goal, "done": v >= q.goal}


func claim_quest() -> void:
	var pr := quest_progress()
	if pr.is_empty() or not pr.done:
		return
	var rw: Dictionary = Defs.QUESTS[quest].rw
	for k in rw:
		if k == "xp":
			add_xp(rw[k])
		else:
			give(k, rw[k])
	toast.emit(Lang.t("quest_complete", [Lang.QTXT[Settings.lang][quest][0]]), "good")
	quest += 1
	if quest < Defs.QUESTS.size():
		qbase = quest_value(quest)


# ---------------------------------------------------------------- Interaction

func interact() -> void:
	if dead_t > 0:
		return
	var best: Ent = null
	var bd := 22.0
	for e in ents:
		if e.is_npc() and e.pos.distance_to(p_pos) < bd:
			bd = e.pos.distance_to(p_pos)
			best = e
	if best:
		dialog_requested.emit(best)
		return
	if chest_pos.distance_to(p_pos) < 22:
		if chest_open:
			toast.emit(Lang.t("chest_empty"), "")
		else:
			chest_open = true
			relic = true
			toast.emit(Lang.t("chest"), "good")
		return
	for b in buildings:
		if b.center().distance_to(p_pos) < 30:
			if b.k == "workshop":
				panel_requested.emit("inv")
				return
			if b.k == "campfire":
				if is_night():
					time = 0.27
					p_hp = max_hp()
					toast.emit(Lang.t("rest_done"), "good")
				else:
					toast.emit(Lang.t("rest_day"), "")
				return
	var front := Vector2i(int(floor((p_pos.x + p_dir.x * 12) / TS)), int(floor((p_pos.y - 4 + p_dir.y * 12) / TS)))
	var here := Vector2i(int(floor(p_pos.x / TS)), int(floor((p_pos.y - 2) / TS)))
	for c in [front, here]:
		var i: int = c.y * MW + c.x
		if i < 0 or i >= map.size():
			continue
		if map[i] == T.FLOWER:
			if body:
				toast.emit(Lang.t("cant_here"), "")
				return
			set_tile(i, T.GRASS)
			give("berry")
			float_t(Vector2(c.x * TS + 8, c.y * TS), Lang.t("forage"), Color("#ffb0c0"))
			return
		if map[i] == T.GATE or (i + MW < map.size() and map[i + MW] == T.GATE):
			toast.emit(Lang.t("gate_open") if gate_open() else Lang.t("gate_locked"), "good" if gate_open() else "bad")
			return


func near_workshop() -> bool:
	return buildings.any(func(b): return b.k == "workshop" and b.center().distance_to(p_pos) < 56)


# ---------------------------------------------------------------- Effets

func float_t(p: Vector2, s: String, c: Color) -> void:
	fx.append({"k": "t", "pos": p, "s": s, "c": c, "t": 1.0})


func burst(p: Vector2, c: Color, n: int) -> void:
	for i in n:
		fx.append({"k": "p", "pos": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(15, 50) + Vector2(0, -20), "c": c, "t": randf_range(0.3, 0.6)})


func _update_fx(dt: float) -> void:
	for f in fx:
		f.t -= dt
		if f.k == "t":
			f.pos.y -= 14 * dt
		else:
			f.pos += f.v * dt
			f.v.y += 90 * dt
	fx = fx.filter(func(f): return f.t > 0)


func _make_light(radius: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = Art.light_texture()
	l.texture_scale = radius / 32.0
	l.energy = 0.9
	l.color = Color(1, 0.85, 0.6)
	return l


# ---------------------------------------------------------------- Boucle

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	clock += dt
	if mode == "play" and not paused:
		time += dt / Defs.DAYLEN
		if time >= 1.0:
			time -= 1.0
			_new_day()
		_update_player(dt)
		for e in ents:
			if e.zone >= 0 and not e.ally and e.pos.distance_squared_to(p_pos) > SLEEP_R2:
				continue
			_update_ent(e, dt)
		_remove_dead()
		_update_buildings(dt)
		spawn_t -= dt
		if spawn_t <= 0:
			spawn_t = 25
			fill_spawns(false)
		shake = maxf(0, shake - dt)
	elif mode == "title":
		time = 0.62
		for e in ents:
			if e.is_mon():
				e.anim += dt
				_wander(e, dt, e.spd * 0.4, 90, Defs.MON[e.kind].get("fly", false))
	_update_fx(dt)
	_update_camera()
	var dk := darkness()
	# Sans lumières dynamiques (réglage conseillé sur téléphone), la nuit reste plus claire pour rester jouable.
	var lit := Settings.lights
	night.color = Color.WHITE.lerp(Color(0.13, 0.17, 0.35), dk / 0.74 * (1.0 if lit else 0.7))
	p_light.visible = lit and mode == "play" and dk > 0.02
	p_light.position = p_pos + Vector2(0, -8)
	p_light.texture_scale = (80.0 if Settings.tier >= 3 else 48.0) / 32.0
	for b in buildings:
		if b.light:
			b.light.visible = lit and dk > 0.02
	if gate_open() != _gate_shown:
		_gate_shown = gate_open()
		_refresh_cell(65, 10)
	_sync_sprites()
	overlay.queue_redraw()


func _update_camera() -> void:
	var half := get_viewport_rect().size * 0.5
	var target := p_pos + Vector2(0, -8)
	if mode == "title":
		target = Vector2((sin(clock * 0.05) * 0.5 + 0.5) * (MW * TS - half.x * 2) + half.x, (cos(clock * 0.04) * 0.5 + 0.5) * (MH * TS - half.y * 2) + half.y)
	cam.position = Vector2(clampf(target.x, half.x, MW * TS - half.x), clampf(target.y, half.y, MH * TS - half.y)).round()
	cam.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2)) if shake > 0 and Settings.shake else Vector2.ZERO


func _unhandled_input(ev: InputEvent) -> void:
	if mode != "play" or paused:
		return
	if placing != "":
		if ev.is_action_pressed("pause"):
			placing = ""
			get_viewport().set_input_as_handled()
		elif ev.is_action_pressed("interact") or ev.is_action_pressed("attack"):
			place_building()
			get_viewport().set_input_as_handled()
		return
	if ev.is_action_pressed("interact"):
		interact()
	elif ev.is_action_pressed("soul"):
		soul_action()
	elif ev.is_action_pressed("potion"):
		heal_item("potion" if inv.get("potion", 0) else "stew")
	elif ev.is_action_pressed("build"):
		panel_requested.emit("build")
	elif ev.is_action_pressed("inventory"):
		panel_requested.emit("inv")
	elif ev.is_action_pressed("map"):
		panel_requested.emit("map")
	elif ev.is_action_pressed("pause"):
		panel_requested.emit("pause")


# ---------------------------------------------------------------- Rendu

func _setup_layers() -> void:
	var ts := Art.tileset()
	ground = TileMapLayer.new()
	ground.tile_set = ts
	ground.z_index = -2
	add_child(ground)
	deco = TileMapLayer.new()
	deco.tile_set = ts
	deco.z_index = -1
	add_child(deco)
	# Arbres, rochers, personnages et bâtiments sont triés ensemble selon leur y.
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	objs = TileMapLayer.new()
	objs.tile_set = ts
	objs.y_sort_enabled = true
	ysort.add_child(objs)
	chest_spr = Art.sprite("chest")
	chest_spr.position = chest_pos
	ysort.add_child(chest_spr)
	shell_spr = Art.sprite("hero")
	shell_spr.modulate = Color(1, 1, 1, 0.55)
	ysort.add_child(shell_spr)
	p_spr = Art.sprite("hero")
	ysort.add_child(p_spr)
	p_mask = Art.sprite("mask_gob")
	p_spr.add_child(p_mask)
	overlay = Node2D.new()
	overlay.z_index = 5
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)


func set_tile(i: int, t: int) -> void:
	map[i] = t
	var x := i % MW
	var y := i / MW
	_refresh_cell(x, y)
	_refresh_cell(x + 1, y)
	_refresh_cell(x - 1, y)
	_refresh_cell(x, y + 1)
	_refresh_cell(x, y - 1)


func rebuild_tiles() -> void:
	if ground == null:
		return
	ground.clear()
	deco.clear()
	objs.clear()
	_gate_shown = gate_open()
	for y in MH:
		for x in MW:
			_refresh_cell(x, y)


func _hv(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff


func _conn(x: int, y: int, kinds: Array) -> bool:
	if x < 0 or y < 0 or x >= MW or y >= MH:
		return true
	return kinds.has(map[y * MW + x])


## Bits : 1 = nord, 2 = est, 4 = sud, 8 = ouest, mis quand la case voisine est du même genre.
func _mask(x: int, y: int, kinds: Array) -> int:
	return (1 if _conn(x, y - 1, kinds) else 0) | (2 if _conn(x + 1, y, kinds) else 0) \
		| (4 if _conn(x, y + 1, kinds) else 0) | (8 if _conn(x - 1, y, kinds) else 0)


func _refresh_cell(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= MW or y >= MH:
		return
	var c := Vector2i(x, y)
	var t := map[y * MW + x]
	var v := _hv(x, y)
	var b := Defs.biome(x, y)
	var gv := v % 10
	ground.set_cell(c, Art.SRC, Art.tile("grass_%s_%d" % [b, 0 if gv < 5 else (1 if gv < 7 else (2 if gv < 9 else 3))]))
	var d := ""
	match t:
		T.PATH:
			d = "path_%d" % _mask(x, y, PATHLIKE)
		T.WATER:
			d = "water_%d" % _mask(x, y, WATERLIKE)
		T.BRIDGE:
			var across := _conn(x - 1, y, PATHLIKE) or _conn(x + 1, y, PATHLIKE)
			var along := _conn(x, y - 1, PATHLIKE) or _conn(x, y + 1, PATHLIKE)
			d = "bridge_h" if across and not along else "bridge_v"
		T.FLOWER:
			d = "flower_%d" % (v % 3)
		T.WALL:
			d = "wall_1" if v % 5 == 0 else "wall_0"
		T.GATE:
			d = "gate_1" if gate_open() else "gate_0"
		T.CRYPT:
			d = "crypt_%d" % [0, 0, 0, 1, 2][v % 5]
	if d == "":
		deco.erase_cell(c)
	else:
		deco.set_cell(c, Art.SRC, Art.tile(d))
	var o := ""
	match t:
		T.TREE:
			o = "tree_crypt_0" if b == "crypt" else "tree_%s_%d" % [b, v % 2]
		T.ROCK:
			o = "rock_1" if b == "forest" or v % 4 == 0 else "rock_0"
		T.STUMP:
			o = "stump"
	if o == "":
		objs.erase_cell(c)
	else:
		objs.set_cell(c, Art.SRC, Art.tile(o))


func _remove_dead() -> void:
	for i in range(ents.size() - 1, -1, -1):
		if ents[i].dead:
			if ents[i].spr:
				ents[i].spr.queue_free()
			ents.remove_at(i)


func _ent_sprite(e: Ent) -> String:
	if e.kind == "villager":
		return "villager_%d" % e.vc
	return e.kind


func _pose(s: Sprite2D, nm: String, dir: Vector2i, moving: bool, anim: float, sd: float) -> void:
	var f := 0
	match nm:
		"loup":
			f = int(anim * 10) % 4 if moving else 0
		"feufollet":
			f = int(anim * 6) % 4
		"spectre":
			f = int(anim * 4) % 4
		"tent":
			f = 0
		_:
			var di := 2 if dir.x != 0 else (1 if dir.y < 0 else 0)
			f = di * 3 + ([1, 0, 2, 0][int(anim * 8) % 4] if moving else 0)
	Art.set_frame(s, nm, f)
	s.flip_h = dir.x < 0
	if nm == "feufollet" or nm == "spectre":
		s.offset.y += round(sin(anim * (4.0 if nm == "feufollet" else 3.0) + sd) * 2)


func _view() -> Rect2:
	var half := get_viewport_rect().size * 0.5
	return Rect2(cam.position - half - Vector2(32, 32), half * 2 + Vector2(64, 80))


func _sync_sprites() -> void:
	var view := _view()
	for e in ents:
		if not view.has_point(e.pos):
			if e.spr:
				e.spr.visible = false
			continue
		var nm := _ent_sprite(e)
		if e.spr == null:
			e.spr = Art.sprite(nm)
			ysort.add_child(e.spr)
		e.spr.visible = true
		e.spr.position = e.pos.round()
		_pose(e.spr, nm, e.dir, e.moving, e.anim, e.seed)
		e.spr.modulate = FLASH if e.hit_t > 0 else Color.WHITE
	var nt := is_night()
	for b in buildings:
		match b.k:
			"campfire":
				Art.set_frame(b.spr, "campfire", int(clock / 0.12) % 3)
			"house", "statue":
				Art.set_frame(b.spr, b.k, 1 if nt else 0)
			"mill":
				b.spr.get_child(0).rotation = clock / 0.9
	Art.set_frame(chest_spr, "chest", 1 if chest_open else 0)
	shell_spr.visible = not shell.is_empty()
	if shell_spr.visible:
		shell_spr.position = shell.pos.round()
		_pose(shell_spr, "hero", shell.dir, false, 0.0, 0.0)
	var blink := hurt_t > 0 and int(hurt_t * 20) % 2 == 1
	p_spr.visible = mode == "play" and dead_t <= 0 and not blink
	if not p_spr.visible:
		return
	var nm := ""
	if body:
		nm = body.kind
	else:
		nm = "hero" + ("_gold" if Settings.tier >= 1 and Settings.gold_skin else "") + ("_cape" if armor else "")
	p_spr.position = p_pos.round()
	_pose(p_spr, nm, p_dir, p_moving, p_anim, 1.0)
	p_spr.modulate = FLASH if body.is_empty() and hurt_t > 0.3 else Color.WHITE
	p_mask.visible = body.is_empty() and mask != "" and p_dir.y >= 0
	if p_mask.visible:
		Art.set_frame(p_mask, mask, 0 if p_dir.x == 0 else 1)
		p_mask.flip_h = p_dir.x < 0


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	overlay.draw_rect(Rect2(round(x), round(y), w, h), c)


## Ce qui n'est pas un sprite : barres de vie, repères, projectiles, particules, textes flottants.
func _draw_overlay() -> void:
	var view := _view()
	for e in ents:
		if not e.dead and view.has_point(e.pos):
			_draw_marks(e)
	if mode == "play" and dead_t <= 0 and body:
		_r(p_pos.x - 1, p_pos.y - (36 if body.kind == "chef" else 24), 2, 2, Color("#9fe6ff"))
	for pr in projs:
		_r(pr.pos.x - 1, pr.pos.y - 1, 3, 2, Color("#e8d0a0"))
	if placing != "" and mode == "play":
		var s := place_spot()
		var d: Dictionary = Defs.BLD[placing]
		var ok := can_place(placing, s.x, s.y)
		var rect := Rect2(s.x * TS, s.y * TS, d.w * TS, d.h * TS)
		overlay.draw_rect(rect, Color(0.55, 0.86, 0.47, 0.35) if ok else Color(0.9, 0.31, 0.27, 0.4))
		overlay.draw_rect(rect, Color("#9fe08a") if ok else Color("#e06050"), false, 1.0)
	if swing > 0 and mode == "play" and dead_t <= 0:
		_draw_swing()
	var font := ThemeDB.fallback_font
	for f in fx:
		if f.k == "p":
			_r(f.pos.x, f.pos.y, 1, 1, f.c)
		else:
			var a := minf(1.0, f.t * 2)
			overlay.draw_string(font, f.pos + Vector2(-40, 1), f.s, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(0, 0, 0, a))
			overlay.draw_string(font, f.pos + Vector2(-41, 0), f.s, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(f.c, a))
	if Settings.tier >= 3 and mode == "play":
		var fp := p_pos + Vector2(cos(clock * 2) * 12, -20 + sin(clock * 3) * 4)
		overlay.draw_circle(fp, 5, Color(1, 0.94, 0.55, 0.35))
		_r(fp.x - 1, fp.y - 1, 2, 2, Color("#fff6c0"))


func _draw_marks(e: Ent) -> void:
	var p := e.pos.round()
	var top: float = p.y - {"chef": 34, "loup": 16, "gobelin": 20}.get(e.kind, 23)
	if e.is_mon() and not e.ally and e.hp < e.maxhp:
		var boss: bool = Defs.MON[e.kind].get("boss", false)
		var w := 20.0 if boss else 12.0
		_r(p.x - w / 2, top, w, 2, Color("#300"))
		_r(p.x - w / 2, top, maxf(1, w * e.hp / e.maxhp), 2, Color("#7cd0f0") if (e.hp / e.maxhp <= 0.35 and not boss) else Color("#d4483b"))
	if e.ally or e.follow:
		_r(p.x - 1, top - 2, 2, 2, Color("#8fc25a"))
	if e.is_mon() and not e.ally and friendly(e):
		_r(p.x - 1, top - 2, 2, 1, Color("#7cc4cf"))
	if e.kind == "elder":
		var q := quest_progress()
		if not q.is_empty() and q.done:
			var bob := int(clock / 0.3) % 2
			_r(p.x - 1, top - 7 - bob, 2, 4, Color("#ffd76a"))
			_r(p.x - 1, top - 2 - bob, 2, 1, Color("#ffd76a"))


func _draw_swing() -> void:
	var c := Color(1, 1, 1, 0.75)
	var a := p_pos.round() + Vector2(p_dir) * 10 + Vector2(0, -7)
	if p_dir.x != 0:
		var side := -1 if p_dir.x < 0 else 1
		_r(a.x - (6 if side < 0 else 0), a.y - 6, 6, 1, c)
		_r(a.x + (-7 if side < 0 else 6), a.y - 5, 1, 10, c)
		_r(a.x - (6 if side < 0 else 0), a.y + 5, 6, 1, c)
	else:
		_r(a.x - 6, a.y, 12, 1, c)
		_r(a.x - 5, a.y + (-2 if p_dir.y < 0 else 2), 10, 1, c)


# ---------------------------------------------------------------- Sauvegarde

func save_path(slot: String) -> String:
	return "user://save_%s.json" % slot


func serialize() -> Dictionary:
	var npcs := []
	var allies := []
	for e in ents:
		if e.is_npc():
			npcs.append({"kind": e.kind, "name": e.name, "tunic": e.tunic.to_html(), "hair": e.hair.to_html(), "x": e.pos.x, "y": e.pos.y, "hx": e.home.x, "hy": e.home.y, "aff": e.aff, "talks": e.talks, "follow": e.follow, "spouse": e.spouse})
		elif e.ally and e.is_mon():
			allies.append([e.kind, e.lvl, e.hp])
	var pp: Vector2 = shell.pos if shell else p_pos
	return {
		"v": 1, "at": Time.get_unix_time_from_system(), "seed": seed_val, "map": Marshalls.raw_to_base64(map),
		"day": day, "time": time, "quest": quest, "qbase": qbase, "stats": stats, "flags": flags, "chest": chest_open,
		"player": {"x": pp.x, "y": pp.y, "hp": p_hp, "lvl": lvl, "xp": xp, "gold": gold, "inv": inv, "mask": mask, "sword": sword, "armor": armor, "relic": relic, "spouse": spouse},
		"buildings": buildings.map(func(b): return [b.k, b.tx, b.ty]),
		"npcs": npcs, "allies": allies,
		"chef_alive": ents.any(func(e): return e.kind == "chef" and not e.dead),
	}


func write_save(slot: String) -> bool:
	if mode != "play":
		return false
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(serialize()))
	return true


func read_save(slot: String) -> Dictionary:
	if not FileAccess.file_exists(save_path(slot)):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	return d if d is Dictionary else {}


func load_save(slot: String) -> bool:
	var d := read_save(slot)
	if d.is_empty():
		return false
	_reset(int(d.seed), Marshalls.base64_to_raw(d.map))
	day = int(d.day)
	time = d.time
	quest = int(d.quest)
	qbase = int(d.qbase)
	stats = d.stats
	flags = d.flags
	chest_open = d.chest
	var p: Dictionary = d.player
	p_pos = Vector2(p.x, p.y)
	p_hp = p.hp
	lvl = int(p.lvl)
	xp = int(p.xp)
	gold = int(p.gold)
	inv = {}
	for k in p.inv:
		inv[k] = int(p.inv[k])
	mask = p.mask
	sword = p.sword
	armor = p.armor
	relic = p.relic
	spouse = p.spouse
	for b in d.buildings:
		add_building(b[0], int(b[1]), int(b[2]))
	for n in d.npcs:
		var e := add_npc(n.kind, n.name, Vector2(n.x, n.y))
		e.home = Vector2(n.hx, n.hy)
		e.tunic = Color(n.tunic)
		for i in Defs.VCOL.size():
			if Color(Defs.VCOL[i][0]).is_equal_approx(e.tunic):
				e.vc = i
		e.hair = Color(n.hair)
		e.aff = int(n.aff)
		e.talks = int(n.talks)
		e.follow = n.follow
		e.spouse = n.spouse
	for a in d.allies:
		var e := mk_mon(a[0], int(a[1]), p_pos + Vector2(randf_range(-12, 12), 8), -1)
		e.ally = true
		e.hp = a[2]
		ents.append(e)
	if d.chef_alive:
		ents.append(mk_mon("chef", 6, Vector2(30 * TS + 8, 44 * TS + 8), 1))
	_add_tents()
	fill_spawns(true)
	return true
