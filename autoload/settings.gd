extends Node
## Paramètres du joueur + table des commandes (clavier physique : ZQSD et WASD marchent tous les deux).

const PATH := "user://settings.cfg"

var lang := "fr"
var vol := 0.5
var shake := true
var diff := "normal"
## Palier Patreon. 0 = Voyageur, 1 = Lanterne, 2 = Gardien, 3 = Archimage.
## En démo il se règle dans les Paramètres ; en version finale il vient du serveur de liaison Patreon.
var tier := 0
var gold_skin := true
## Lumières dynamiques la nuit : jolies mais coûteuses sur les petits téléphones.
var lights := not OS.has_feature("mobile")
## Économie d'énergie : limite à 30 images par seconde (batterie, vieux PC).
var eco := false
## Commandes tactiles : "auto" (si écran tactile), "on" ou "off".
var touch := "auto"


func _ready() -> void:
	_setup_input()
	apply()
	load_settings()


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	lang = c.get_value("s", "lang", lang)
	vol = c.get_value("s", "vol", vol)
	shake = c.get_value("s", "shake", shake)
	diff = c.get_value("s", "diff", diff)
	tier = c.get_value("s", "tier", tier)
	gold_skin = c.get_value("s", "gold_skin", gold_skin)
	lights = c.get_value("s", "lights", lights)
	eco = c.get_value("s", "eco", eco)
	touch = c.get_value("s", "touch", touch)
	apply()


func apply() -> void:
	Engine.max_fps = 30 if eco else 60


func touch_on() -> bool:
	if touch == "auto":
		return DisplayServer.is_touchscreen_available()
	return touch == "on"


func save_settings() -> void:
	var c := ConfigFile.new()
	for k in ["lang", "vol", "shake", "diff", "tier", "gold_skin", "lights", "eco", "touch"]:
		c.set_value("s", k, get(k))
	c.save(PATH)


func diff_mul() -> float:
	if diff == "easy":
		return 0.6
	if diff == "hard":
		return 1.4
	return 1.0


func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"attack": [KEY_SPACE, KEY_J], "interact": [KEY_E], "soul": [KEY_R],
		"build": [KEY_B], "inventory": [KEY_I, KEY_TAB], "map": [KEY_M],
		"potion": [KEY_H], "pause": [KEY_ESCAPE],
	}
	var pads := {
		"attack": JOY_BUTTON_A, "interact": JOY_BUTTON_X, "soul": JOY_BUTTON_Y,
		"build": JOY_BUTTON_LEFT_SHOULDER, "inventory": JOY_BUTTON_RIGHT_SHOULDER,
		"map": JOY_BUTTON_BACK, "pause": JOY_BUTTON_START, "potion": JOY_BUTTON_B,
	}
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	for a in pads:
		var ev := InputEventJoypadButton.new()
		ev.button_index = pads[a]
		InputMap.action_add_event(a, ev)
	for a in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axes[a][0]
		ev.axis_value = axes[a][1]
		InputMap.action_add_event(a, ev)
