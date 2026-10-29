extends Node2D
## Le monde de Brumeval : carte, joueur, créatures, PNJ, bâtiments, temps, sauvegarde.
## Tout est dessiné dans _draw() avec des rectangles et des textures générées (voir Art).

signal toast(text: String, kind: String)
signal dialog_requested(npc)
signal panel_requested(kind: String)

const TS := Defs.TS
const MW := Defs.MW
const MH := Defs.MH
const T := Defs.T


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


func _ready() -> void:
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
	var c: Array = Defs.VCOL.pick_random()
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
			map[i] = T.STUMP
			give("wood", 2)
			stats.wood += 2
		else:
			map[i] = T.GRASS


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
			map[i] = T.TREE
		elif map[i] == T.GRASS and Defs.biome(i % MW, i / MW) == "plain" and not bgrid[i] and randf() < 0.004:
			map[i] = T.FLOWER
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
			map[i] = T.GRASS
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
	l.texture_scale = radius / 64.0
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
			_update_ent(e, dt)
		ents = ents.filter(func(e): return not e.dead)
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
	night.color = Color.WHITE.lerp(Color(0.13, 0.17, 0.35), dk / 0.74)
	p_light.visible = mode == "play" and dk > 0.02
	p_light.position = p_pos + Vector2(0, -8)
	p_light.texture_scale = (80.0 if Settings.tier >= 3 else 48.0) / 64.0
	for b in buildings:
		if b.light:
			b.light.visible = dk > 0.02
	queue_redraw()


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


# ---------------------------------------------------------------- Dessin

func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(round(x), round(y), w, h), c)


func _draw() -> void:
	var half := get_viewport_rect().size * 0.5
	var view := Rect2(cam.position - half - Vector2(TS, TS), half * 2 + Vector2(TS * 2, TS * 3))
	var x0 := maxi(0, int(view.position.x / TS))
	var y0 := maxi(0, int(view.position.y / TS))
	var x1 := mini(MW - 1, int(view.end.x / TS))
	var y1 := mini(MH - 1, int(view.end.y / TS))
	var wf := int(clock * 1.5) % 2
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := map[y * MW + x]
			var v := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
			var b := Defs.biome(x, y)
			var f := wf if c == T.WATER else ((1 if gate_open() else 0) if c == T.GATE else 0)
			draw_texture(Art.tile(c, v % 6 if c != T.GATE else 0, b, f), Vector2(x * TS, y * TS))
			if c == T.ROCK:
				draw_texture(Art.rock(), Vector2(x * TS, y * TS))
			elif c == T.STUMP:
				draw_texture(Art.stump(), Vector2(x * TS, y * TS))
	# liste triée par profondeur (y)
	var list := []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if map[y * MW + x] == T.TREE:
				list.append([y * TS + 15, 0, Vector2i(x, y)])
	for b in buildings:
		if view.intersects(Rect2(b.tx * TS, b.ty * TS - 16, b.w * TS, b.h * TS + 16)):
			list.append([(b.ty + b.h) * TS - 1, 1, b])
	for e in ents:
		if not e.dead and view.has_point(e.pos):
			list.append([e.pos.y, 2, e])
	if view.has_point(chest_pos):
		list.append([chest_pos.y, 3, null])
	if not shell.is_empty():
		list.append([shell.pos.y, 4, null])
	if mode == "play" and dead_t <= 0:
		list.append([p_pos.y, 5, null])
	list.sort_custom(func(a, b): return a[0] < b[0])
	for it in list:
		match it[1]:
			0:
				var c: Vector2i = it[2]
				draw_texture(Art.tree(Defs.biome(c.x, c.y), ((c.x * 73856093) ^ (c.y * 19349663)) & 0x7fffffff), Vector2(c.x * TS, c.y * TS - 8))
			1:
				_draw_building(it[2])
			2:
				_draw_ent(it[2])
			3:
				_r(chest_pos.x - 6, chest_pos.y - 8, 12, 8, Color("#6e4a28"))
				_r(chest_pos.x - 6, chest_pos.y - 8, 12, 2, Color("#2a1a10") if chest_open else Color("#8a5a2b"))
				_r(chest_pos.x - 1, chest_pos.y - 6, 2, 2, Color("#e0b040"))
			4:
				_draw_human(shell.pos, {"tunic": Color("#3d5c8a"), "skin": Color("#e8b890"), "hair": Color("#2a1c14"), "dir": shell.dir, "alpha": 0.55})
			5:
				_draw_player()
	for pr in projs:
		_r(pr.pos.x - 1, pr.pos.y - 1, 3, 2, Color("#e8d0a0"))
	if placing != "" and mode == "play":
		var s := place_spot()
		var d: Dictionary = Defs.BLD[placing]
		var ok := can_place(placing, s.x, s.y)
		var rect := Rect2(s.x * TS, s.y * TS, d.w * TS, d.h * TS)
		draw_rect(rect, Color(0.55, 0.86, 0.47, 0.35) if ok else Color(0.9, 0.31, 0.27, 0.4))
		draw_rect(rect, Color("#9fe08a") if ok else Color("#e06050"), false, 1.0)
	var font := ThemeDB.fallback_font
	for f in fx:
		if f.k == "p":
			_r(f.pos.x, f.pos.y, 1, 1, f.c)
		else:
			var a := minf(1.0, f.t * 2)
			draw_string(font, f.pos + Vector2(-40, 1), f.s, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(0, 0, 0, a))
			draw_string(font, f.pos + Vector2(-41, 0), f.s, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(f.c, a))
	if Settings.tier >= 3 and mode == "play":
		var fp := p_pos + Vector2(cos(clock * 2) * 12, -20 + sin(clock * 3) * 4)
		draw_circle(fp, 5, Color(1, 0.94, 0.55, 0.35))
		_r(fp.x - 1, fp.y - 1, 2, 2, Color("#fff6c0"))


func _draw_human(p: Vector2, o: Dictionary) -> void:
	var sx := p.x
	var sy := p.y
	var a: float = o.get("alpha", 1.0)
	var flash: bool = o.get("flash", false)
	var dir: Vector2i = o.dir
	var b := int(o.get("anim", 0.0) * 8) % 2 if o.get("moving", false) else 0
	var tunic: Color = Color.WHITE if flash else o.tunic
	var skin: Color = Color.WHITE if flash else o.skin
	var hair: Color = o.hair
	var A := func(c: Color) -> Color: return Color(c, c.a * a)
	_r(sx - 5, sy - 1, 10, 2, Color(0, 0, 0, 0.3 * a))
	_r(sx - 3, sy - 4, 2, 3 if b else 4, A.call(Color("#2b2230")))
	_r(sx + 1, sy - 4, 2, 4 if b else 3, A.call(Color("#2b2230")))
	_r(sx - 4, sy - 10, 8, 6, A.call(tunic))
	var gold_trim: bool = o.get("gold", false)
	_r(sx - 4, sy - 6, 8, 1, A.call(Color("#f0c040") if gold_trim else Color("#3a2a1a")))
	if gold_trim:
		_r(sx - 4, sy - 10, 8, 1, A.call(Color("#f0c040")))
		_r(sx - 1, sy - 9, 2, 3, A.call(Color("#f0c040")))
	if o.has("cape"):
		_r(sx - 4, sy - 10, 1, 7, A.call(o.cape))
		_r(sx + 3, sy - 10, 1, 7, A.call(o.cape))
	_r(sx - 5, sy - 10 + b, 1, 4, A.call(skin))
	_r(sx + 4, sy - 10 + (1 - b), 1, 4, A.call(skin))
	_r(sx - 3, sy - 16, 6, 6, A.call(skin))
	_r(sx - 3, sy - 17, 6, 2, A.call(hair))
	_r(sx - 4, sy - 16, 1, 3, A.call(hair))
	_r(sx + 3, sy - 16, 1, 3, A.call(hair))
	if o.get("beard", false):
		_r(sx - 2, sy - 12, 4, 2, A.call(Color("#d8d0c0")))
	var eye: Color = A.call(Color("#1a1010"))
	if dir.y < 0:
		_r(sx - 3, sy - 16, 6, 4, A.call(hair))
	elif dir.x > 0:
		_r(sx + 1, sy - 14, 1, 1, eye)
	elif dir.x < 0:
		_r(sx - 2, sy - 14, 1, 1, eye)
	else:
		_r(sx - 2, sy - 14, 1, 1, eye)
		_r(sx + 1, sy - 14, 1, 1, eye)
	var m: String = o.get("mask", "")
	if m != "" and dir.y >= 0:
		var mc: Color = Defs.MASKC[m]
		_r(sx - 3, sy - 15, 6, 3, mc)
		_r(sx - 2, sy - 14, 1, 1, Color("#111"))
		_r(sx + 1, sy - 14, 1, 1, Color("#111"))
		if m == "mask_gob":
			_r(sx - 5, sy - 15, 2, 1, mc)
			_r(sx + 3, sy - 15, 2, 1, mc)
		elif m == "mask_wolf":
			_r(sx - 3, sy - 17, 1, 2, mc)
			_r(sx + 2, sy - 17, 1, 2, mc)
	if o.get("staff", false):
		_r(sx + 5, sy - 18, 1, 16, Color("#6e4a28"))
		_r(sx + 4, sy - 19, 3, 2, Color("#7cc4cf"))
	if o.get("pack", false):
		_r(sx - 5, sy - 11, 3, 6, Color("#7a5230"))


func _draw_gob(p: Vector2, e, k: float) -> void:
	var b := int(e.anim * 8) % 2 if e.moving else 0
	var g := Color.WHITE if e.hit_t > 0 else (Color("#5a8a2e") if e.kind == "chef" else Color("#6c9a3a"))
	draw_set_transform(p, 0, Vector2(k, k))
	_r(-5, -1, 10, 2, Color(0, 0, 0, 0.3))
	_r(-3, -3, 2, 2 if b else 3, Color("#3a2a1a"))
	_r(1, -3, 2, 3 if b else 2, Color("#3a2a1a"))
	_r(-3, -8, 6, 5, Color("#5a3d22"))
	_r(-4, -14, 8, 6, g)
	_r(-6, -13, 2, 2, g)
	_r(4, -13, 2, 2, g)
	_r(-7, -14, 1, 1, g)
	_r(6, -14, 1, 1, g)
	_r(-2, -12, 1, 1, Color("#ff4030"))
	_r(1, -12, 1, 1, Color("#ff4030"))
	_r(-1, -10, 2, 1, Color("#2a3a1a"))
	var dx := -5 if e.dir.x < 0 else 4
	_r(dx, -9, 1, 5, Color("#cfcfd6"))
	_r(dx - 1, -6, 3, 1, Color("#6e4a28"))
	if e.kind == "chef":
		_r(-4, -17, 8, 2, Color("#e0b040"))
		_r(-4, -18, 1, 1, Color("#e0b040"))
		_r(-1, -19, 2, 2, Color("#e0b040"))
		_r(3, -18, 1, 1, Color("#e0b040"))
		_r(-1, -18, 1, 1, Color("#d44"))
	draw_set_transform(Vector2.ZERO)


func _draw_wolf(p: Vector2, e) -> void:
	var b := int(e.anim * 10) % 2 if e.moving else 0
	var c := Color.WHITE if e.hit_t > 0 else Color("#7d7f86")
	draw_set_transform(p, 0, Vector2(-1 if e.dir.x < 0 else 1, 1))
	_r(-7, -1, 14, 2, Color(0, 0, 0, 0.3))
	var leg := Color("#55575e")
	_r(-5, -3, 1, 3, leg)
	_r(-3 + b, -3, 1, 3, leg)
	_r(2, -3, 1, 3, leg)
	_r(4 - b, -3, 1, 3, leg)
	_r(-6, -8, 11, 5, c)
	_r(-5, -4, 9, 1, Color("#5e6067"))
	_r(-9, -9 + b, 3, 2, c)
	_r(-9, -10, 1, 1, c)
	_r(4, -11, 5, 5, c)
	_r(8, -9, 2, 2, c)
	_r(4, -13, 1, 2, c)
	_r(7, -13, 1, 2, c)
	_r(7, -10, 1, 1, Color("#ffd24a"))
	_r(9, -8, 1, 1, Color("#222"))
	draw_set_transform(Vector2.ZERO)


func _draw_wisp(p: Vector2, e) -> void:
	var y := p.y - 10 + sin(e.anim * 4 + e.seed) * 2
	draw_circle(Vector2(p.x, y), 10, Color(0.47, 0.82, 1, 0.18))
	draw_circle(Vector2(p.x, y), 6, Color(0.47, 0.82, 1, 0.25))
	_r(p.x - 3, p.y - 1, 6, 2, Color(0, 0, 0, 0.25))
	_r(p.x - 3, y - 1, 6, 4, Color("#5cc0f0"))
	_r(p.x - 2, y - 4, 4, 4, Color.WHITE if e.hit_t > 0 else Color("#9fe6ff"))
	_r(p.x - 1, y - 6, 2, 2, Color("#dff8ff"))
	_r(p.x - 1 + int(e.anim * 6) % 2, y - 7, 1, 1, Color.WHITE)
	_r(p.x - 2, y, 1, 1, Color("#14324a"))
	_r(p.x + 1, y, 1, 1, Color("#14324a"))


func _draw_spectre(p: Vector2, e) -> void:
	var y := p.y + sin(e.anim * 3 + e.seed) * 2
	var c := Color(1, 1, 1, 0.9) if e.hit_t > 0 else Color(0.69, 0.51, 0.91, 0.82)
	_r(p.x - 4, p.y - 1, 8, 2, Color(0, 0, 0, 0.3))
	_r(p.x - 4, y - 16, 8, 10, c)
	_r(p.x - 5, y - 12, 10, 5, c)
	for i in 4:
		_r(p.x - 4 + i * 2, y - 6 + (i + int(e.anim * 4)) % 2, 2, 2, c)
	_r(p.x - 2, y - 13, 1, 2, Color("#1a0f2a"))
	_r(p.x + 1, y - 13, 1, 2, Color("#1a0f2a"))
	_r(p.x - 1, y - 10, 2, 1, Color("#1a0f2a"))


## e peut être un Ent ou un dictionnaire léger (corps du joueur) avec les mêmes champs.
func _draw_creature(p: Vector2, e) -> void:
	match e.kind:
		"gobelin":
			_draw_gob(p, e, 1.0)
		"chef":
			_draw_gob(p, e, 1.6)
		"loup":
			_draw_wolf(p, e)
		"feufollet":
			_draw_wisp(p, e)
		"spectre":
			_draw_spectre(p, e)


func _draw_tent(p: Vector2) -> void:
	_r(p.x - 9, p.y - 1, 18, 2, Color(0, 0, 0, 0.3))
	for i in 10:
		_r(p.x - i, p.y - 10 + i, i * 2, 1, Color("#8a6a3a") if i % 3 else Color("#6e5230"))
	_r(p.x - 1, p.y - 5, 2, 5, Color("#2a1a10"))
	_r(p.x, p.y - 13, 1, 4, Color("#5a3b1f"))
	_r(p.x + 1, p.y - 13, 3, 2, Color("#b5423b"))


func _draw_ent(e: Ent) -> void:
	var p := e.pos.round()
	match e.kind:
		"tent":
			_draw_tent(p)
			return
		"villager":
			_draw_human(p, {"tunic": e.tunic, "skin": Color("#d9a882"), "hair": e.hair, "dir": e.dir, "moving": e.moving, "anim": e.anim, "flash": e.hit_t > 0})
		"elder":
			_draw_human(p, {"tunic": Color("#6a4a8a"), "skin": Color("#d9b090"), "hair": Color("#d8d0c0"), "dir": e.dir, "beard": true, "staff": true})
		"trader":
			_draw_human(p, {"tunic": Color("#8a6a2a"), "skin": Color("#c99a72"), "hair": Color("#4a2a1a"), "dir": e.dir, "pack": true})
		_:
			_draw_creature(p, e)
	if e.is_mon() and not e.ally and e.hp < e.maxhp:
		var boss: bool = Defs.MON[e.kind].get("boss", false)
		var w := 20.0 if boss else 12.0
		var yb := p.y - (32 if e.kind == "chef" else 20)
		_r(p.x - w / 2, yb, w, 2, Color("#300"))
		_r(p.x - w / 2, yb, maxf(1, w * e.hp / e.maxhp), 2, Color("#7cd0f0") if (e.hp / e.maxhp <= 0.35 and not boss) else Color("#d4483b"))
	if e.ally or e.follow:
		_r(p.x - 1, p.y - 21, 2, 2, Color("#8fc25a"))
	if e.is_mon() and not e.ally and friendly(e):
		_r(p.x - 1, p.y - 22, 2, 1, Color("#7cc4cf"))
	if e.kind == "elder":
		var q := quest_progress()
		if not q.is_empty() and q.done:
			var bob := int(clock / 0.3) % 2
			_r(p.x - 1, p.y - 26 - bob, 2, 4, Color("#ffd76a"))
			_r(p.x - 1, p.y - 21 - bob, 2, 1, Color("#ffd76a"))


func _draw_player() -> void:
	if hurt_t > 0 and int(hurt_t * 20) % 2:
		return
	var p := p_pos.round()
	if body:
		_draw_creature(p, {"kind": body.kind, "dir": p_dir, "moving": p_moving, "anim": p_anim, "hit_t": 0.0, "seed": 1.0})
		_r(p.x - 1, p.y - 24, 2, 2, Color("#9fe6ff"))
	else:
		var o := {"tunic": Color("#3d5c8a"), "skin": Color("#e8b890"), "hair": Color("#2a1c14"), "dir": p_dir, "moving": p_moving, "anim": p_anim, "mask": mask, "gold": Settings.tier >= 1 and Settings.gold_skin, "flash": hurt_t > 0.3}
		if armor:
			o["cape"] = Color("#7a5230")
		_draw_human(p, o)
	if swing > 0:
		var c := Color(1, 1, 1, 0.75)
		var a := p + Vector2(p_dir) * 10 + Vector2(0, -7)
		if p_dir.x != 0:
			var side := -1 if p_dir.x < 0 else 1
			_r(a.x - (6 if side < 0 else 0), a.y - 6, 6, 1, c)
			_r(a.x + (-7 if side < 0 else 6), a.y - 5, 1, 10, c)
			_r(a.x - (6 if side < 0 else 0), a.y + 5, 6, 1, c)
		else:
			_r(a.x - 6, a.y, 12, 1, c)
			_r(a.x - 5, a.y + (-2 if p_dir.y < 0 else 2), 10, 1, c)


func _draw_building(b: Bld) -> void:
	var x := float(b.tx * TS)
	var y := float(b.ty * TS)
	var w := float(b.w * TS)
	var h := float(b.h * TS)
	var nt := is_night()
	match b.k:
		"campfire":
			_r(x + 2, y + 11, 12, 3, Color(0, 0, 0, 0.3))
			_r(x + 3, y + 10, 10, 3, Color("#5a3b1f"))
			_r(x + 5, y + 9, 6, 2, Color("#6e4a28"))
			var f := int(clock / 0.12) % 3
			_r(x + 5, y + 4 + f % 2, 6, 6, Color("#e8742a"))
			_r(x + 6, y + 2 + f, 4, 5, Color("#f5b23a"))
			_r(x + 7, y + 1 + (1 if f == 1 else 0), 2, 3, Color("#fff0a0"))
		"house":
			_r(x + 2, y + h - 14, w - 4, 14, Color("#b98b5a"))
			_r(x + 2, y + h - 14, w - 4, 1, Color("#8a6440"))
			for i in 9:
				_r(x + i * 1.5, y + h - 15 - i * 2, w - i * 3, 2, Color("#8e3b2e") if i % 2 else Color("#a4473a"))
			_r(x + 13, y + h - 9, 6, 9, Color("#5a3b1f"))
			var win := Color("#ffd76a") if nt else Color("#2a3a4a")
			_r(x + 5, y + h - 10, 5, 4, win)
			_r(x + 22, y + h - 10, 5, 4, win)
		"workshop":
			_r(x + 1, y + h - 16, w - 2, 16, Color("#7a6a5a"))
			_r(x + 1, y + h - 16, w - 2, 2, Color("#5a4a3a"))
			_r(x, y + h - 24, w, 8, Color("#4a3a2e"))
			_r(x + 2, y + h - 26, w - 4, 2, Color("#3a2a20"))
			_r(x + 4, y + h - 10, 10, 10, Color("#3a2a20"))
			_r(x + 18, y + h - 12, 9, 3, Color("#9a9aa6"))
			_r(x + 20, y + h - 9, 5, 4, Color("#6a6a76"))
			_r(x + 26, y + h - 30, 3, 6, Color("#555"))
		"farm":
			_r(x, y + 4, w, h - 4, Color("#6b4a2b"))
			for r in 3:
				_r(x + 1, y + 8 + r * 8, w - 2, 1, Color("#54381f"))
				for c in 4:
					_r(x + 2 + c * 8, y + 5 + r * 8, 5, 4, Color("#3f7a34"))
					_r(x + 3 + c * 8, y + 6 + r * 8, 1, 1, Color("#d4384a"))
					_r(x + 5 + c * 8, y + 7 + r * 8, 1, 1, Color("#d4384a"))
			_r(x, y + 4, w, 1, Color("#8a6a3a"))
		"mill":
			_r(x + 8, y + h - 20, 16, 20, Color("#9a8e7e"))
			_r(x + 8, y + h - 20, 16, 2, Color("#7a6e5e"))
			_r(x + 13, y + h - 8, 6, 8, Color("#5a3b1f"))
			_r(x + 6, y + h - 24, 20, 5, Color("#8e3b2e"))
			var cpos := Vector2(x + 16, y + h - 22)
			for i in 4:
				draw_set_transform(cpos, clock / 0.9 + i * PI / 2)
				draw_rect(Rect2(-1, 0, 2, 13), Color("#d9c8a0"))
				draw_rect(Rect2(1, 3, 4, 9), Color("#f0e4c4"))
			draw_set_transform(Vector2.ZERO)
			_r(cpos.x - 1, cpos.y - 1, 3, 3, Color("#3a2a20"))
		"tower":
			_r(x + 2, y + 6, 12, h - 6, Color("#7a7a84"))
			for i in range(0, int(h) - 6, 4):
				_r(x + 2, y + 6 + i, 12, 1, Color("#5e5e68"))
			_r(x + 1, y + 2, 14, 5, Color("#8a8a94"))
			for cx in [1, 7, 12]:
				_r(x + cx, y, 3, 3, Color("#8a8a94"))
			_r(x + 6, y + 12, 4, 5, Color("#2a2a34"))
			_r(x + 14, y - 8, 1, 9, Color("#5a3b1f"))
			_r(x + 15, y - 8, 5, 3, Color("#7cc4cf"))
		"statue":
			_r(x + 3, y + h - 5, 10, 5, Color("#8a8a94"))
			_r(x + 5, y + 8, 6, h - 13, Color("#c9a24a"))
			_r(x + 4, y + 4, 8, 5, Color("#e0b850"))
			_r(x + 6, y + 5, 4, 3, Color("#fff3b0") if nt else Color("#f5d36a"))
			_r(x + 7, y + 1, 2, 3, Color("#c9a24a"))


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
