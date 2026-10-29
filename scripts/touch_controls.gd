extends Control
## Commandes tactiles (Android, tablettes, PC tactiles) : joystick flottant à gauche, boutons à droite.
## Les boutons envoient les mêmes actions que le clavier, donc le jeu n'a rien de spécial à gérer.
## Gère plusieurs doigts à la fois : on peut marcher et attaquer en même temps.

const R := 22.0
## [icône, action, ancrage (0 = bas droite, 1 = haut centre), position]
const LAYOUT := [
	["attack", "attack", 0, Vector2(-46, -52)],
	["interact", "interact", 0, Vector2(-80, -38)],
	["soul", "soul", 0, Vector2(-40, -86)],
	["potion", "potion", 0, Vector2(-72, -70)],
	["bag", "inventory", 1, Vector2(-44, 4)],
	["build", "build", 1, Vector2(-22, 4)],
	["map", "map", 1, Vector2(0, 4)],
	["pause", "pause", 1, Vector2(22, 4)],
]

var idx := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var buttons := []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	for l in LAYOUT:
		buttons.append({"action": l[1], "anchor": l[2], "pos": l[3], "finger": -1,
			"tex": [Art.frame_texture("btn_" + l[0], 0), Art.frame_texture("btn_" + l[0], 1)]})


func _rect(b: Dictionary) -> Rect2:
	var base := Vector2(size.x, size.y) if b.anchor == 0 else Vector2(size.x / 2, 0)
	return Rect2(base + b.pos, b.tex[0].get_size())


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		idx = -1
		knob = Vector2.ZERO
		_apply()
		for b in buttons:
			if b.finger != -1:
				b.finger = -1
				_send(b.action, false)


func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if ev is InputEventScreenTouch:
		var p: Vector2 = ev.position - global_position
		if ev.pressed:
			for b in buttons:
				# Zone de toucher un peu plus grande que le dessin, plus facile au pouce.
				if b.finger == -1 and _rect(b).grow(3).has_point(p):
					b.finger = ev.index
					_send(b.action, true)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			if idx == -1 and p.x < size.x * 0.45 and p.y > 40:
				idx = ev.index
				origin = p
				knob = Vector2.ZERO
				queue_redraw()
				get_viewport().set_input_as_handled()
		else:
			for b in buttons:
				if b.finger == ev.index:
					b.finger = -1
					_send(b.action, false)
					queue_redraw()
			if ev.index == idx:
				idx = -1
				knob = Vector2.ZERO
				_apply()
				queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == idx:
		knob = (ev.position - global_position - origin).limit_length(R)
		_apply()
		queue_redraw()


func _apply() -> void:
	var v := knob / R
	for a in [["move_left", -v.x], ["move_right", v.x], ["move_up", -v.y], ["move_down", v.y]]:
		if a[1] > 0.2:
			Input.action_press(a[0], minf(1.0, a[1]))
		else:
			Input.action_release(a[0])


func _draw() -> void:
	var c := origin if idx != -1 else Vector2(46, size.y - 46)
	var a := 0.55 if idx != -1 else 0.25
	draw_circle(c, R + 6, Color(0.11, 0.29, 0.32, a * 0.7))
	draw_arc(c, R + 6, 0, TAU, 32, Color(0.82, 0.6, 0.27, a), 1.5)
	draw_circle(c + knob, 9, Color(0.93, 0.89, 0.81, a + 0.15))
	for b in buttons:
		draw_texture(b.tex[1 if b.finger != -1 else 0], _rect(b).position)
