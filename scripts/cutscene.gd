extends Control
## Scènes cinématiques : bandes noires, caméra qui se déplace, dialogues lettre par lettre, fondus.
## Une scène est une liste d'étapes (voir Scenes) jouées l'une après l'autre.
## Interagir / attaquer / toucher l'écran fait avancer, Échap passe la scène.

const FONT := preload("res://art/font/brume.fnt")
const BAR := 26.0
const CPS := 45.0

var world: Node2D
var steps := []
var i := 0
var t := 0.0
var bars := 0.0
var fade := 0.0
var fade_from := 0.0
var cam_from := Vector2.ZERO
var walk_from := Vector2.ZERO
var speaker := ""
var text := ""
var shown := 0.0
var title := ""
var title_a := 0.0
var on_end := Callable()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func playing() -> bool:
	return visible


func play(list: Array, done := Callable()) -> void:
	steps = list
	on_end = done
	i = -1
	world.scene_on = true
	world.scene_cam = world.cam.position
	speaker = ""
	text = ""
	title = ""
	visible = true
	_next()


func _next() -> void:
	i += 1
	t = 0.0
	if i >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[i]
	if s.has("say"):
		speaker = s.say
		text = s.text
		shown = 0.0
	elif s.has("cam"):
		cam_from = world.scene_cam
	elif s.has("fade"):
		fade_from = fade
	elif s.has("walk"):
		walk_from = s.walk.pos if s.walk is Object else world.p_pos
	elif s.has("title"):
		title = s.title
		title_a = 0.0
	elif s.has("fn"):
		s.fn.call()
		_next()
	elif s.has("shake"):
		world.shake = s.shake
		_next()
	elif s.has("burst"):
		world.burst(s.burst, s.get("c", Color.WHITE), s.get("n", 16))
		_next()


func _finish() -> void:
	steps = []
	speaker = ""
	text = ""
	title = ""
	world.scene_on = false
	world.scene_cam = Vector2.INF
	fade = 0.0
	visible = false
	if on_end.is_valid():
		on_end.call()


func skip() -> void:
	# On exécute quand même les effets de jeu (fonctions) restants pour ne rien perdre.
	for k in range(i + 1, steps.size()):
		if steps[k].has("fn"):
			steps[k].fn.call()
		elif steps[k].has("walk"):
			var w = steps[k]
			if w.walk is Object:
				w.walk.pos = w.to
			else:
				world.p_pos = w.to
	i = steps.size()
	_finish()


func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	bars = minf(1.0, bars + dt * 3.0)
	queue_redraw()
	if i >= steps.size():
		return
	var s: Dictionary = steps[i]
	if s.has("say"):
		shown = minf(text.length(), shown + dt * CPS)
	elif s.has("cam"):
		var k := _ease(t / s.get("t", 1.0))
		world.scene_cam = cam_from.lerp(s.cam, k)
		if k >= 1.0:
			_next()
	elif s.has("fade"):
		var k := clampf(t / s.get("t", 0.6), 0, 1)
		fade = lerpf(fade_from, s.fade, k)
		if k >= 1.0:
			_next()
	elif s.has("wait"):
		if t >= s.wait:
			_next()
	elif s.has("walk"):
		var k := clampf(t / s.get("t", 1.0), 0, 1)
		var p := walk_from.lerp(s.to, k)
		var d: Vector2 = s.to - walk_from
		var dirv := Vector2i(int(signf(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, int(signf(d.y)))
		if s.walk is Object:
			s.walk.pos = p
			s.walk.dir = dirv
			s.walk.moving = k < 1.0
			s.walk.anim += dt
		else:
			world.p_pos = p
			world.p_dir = dirv
			world.p_moving = k < 1.0
			world.p_anim += dt
		if k >= 1.0:
			_next()
	elif s.has("title"):
		var dur: float = s.get("t", 2.4)
		title_a = clampf(minf(t / 0.5, (dur - t) / 0.5), 0, 1)
		if t >= dur:
			title = ""
			_next()


func _ease(x: float) -> float:
	x = clampf(x, 0, 1)
	return x * x * (3 - 2 * x)


func _advance() -> void:
	if i >= steps.size():
		return
	var s: Dictionary = steps[i]
	if s.has("say"):
		if shown < text.length():
			shown = text.length()
		else:
			_next()
	elif s.has("title"):
		t = maxf(t, s.get("t", 2.4) - 0.5)


func _input(ev: InputEvent) -> void:
	if not visible:
		return
	var adv := ev.is_action_pressed("interact") or ev.is_action_pressed("attack")
	adv = adv or (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
	if ev.is_action_pressed("pause"):
		skip()
		get_viewport().set_input_as_handled()
	elif adv:
		_advance()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if fade > 0:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, fade))
	var b := BAR * _ease(bars)
	draw_rect(Rect2(0, 0, w, b), Color.BLACK)
	draw_rect(Rect2(0, h - b, w, b), Color.BLACK)
	if title != "":
		var c := Color(0.93, 0.89, 0.81, title_a)
		draw_string(FONT, Vector2(1, h * 0.3 + 1), title, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(0, 0, 0, title_a * 0.8))
		draw_string(FONT, Vector2(0, h * 0.3), title, HORIZONTAL_ALIGNMENT_CENTER, w, 24, c)
	if text != "":
		var bw := minf(w - 24, 380.0)
		var r := Rect2((w - bw) / 2, h - 74, bw, 62)
		draw_rect(r, Color(0.09, 0.06, 0.07, 0.94))
		draw_rect(r, Color("#e0a848"), false, 1.0)
		draw_rect(r.grow(-2), Color("#8a5a20"), false, 1.0)
		if speaker != "":
			draw_string(FONT, r.position + Vector2(8, 14), speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffd76a"))
		var vis := text.substr(0, int(shown))
		draw_multiline_string(FONT, r.position + Vector2(8, 28 if speaker != "" else 16), vis, HORIZONTAL_ALIGNMENT_LEFT, bw - 16, 12, 3, Color("#efe4cc"))
		if shown >= text.length() and int(t * 2.5) % 2 == 0:
			var tip := r.end - Vector2(10, 7)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, -3), tip + Vector2(4, -3), tip + Vector2(0, 2)]), Color("#e0a848"))
