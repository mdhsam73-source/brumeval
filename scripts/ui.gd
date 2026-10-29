extends CanvasLayer
## Interface : écran titre, HUD, panneaux (sac, construction, dialogues, sauvegardes, paramètres), messages.
## Construite en code pour rester lisible sans l'éditeur ; on peut la refaire en scènes .tscn plus tard.

const C_WOOD := Color("#3a2616")
const C_BRASS := Color("#d29a45")
const C_BRASS_DK := Color("#6e4519")
const C_TEAL := Color("#1d4b52")
const C_TEAL_LT := Color("#2d6a72")
const C_INK := Color("#ece4cf")
const C_DIM := Color("#a89f8a")
const C_MIST := Color("#7cc4cf")

var world: Node2D
var theme_ui := Theme.new()
var title_root: Control
var hud_root: Control
var panel_root: Control
var panel_box: VBoxContainer
var panel_kind := ""
var toasts: VBoxContainer
var npc = null
var h_lv: Label
var h_hp: ProgressBar
var h_xp: ProgressBar
var h_gold: Label
var h_state: Label
var h_quest: Label
var h_hint: Label
var hud_t := 0.0
var touch_root: Control
var vignette: TextureRect


## Assombrit doucement les bords de l'écran : donne de la profondeur pour presque rien (une seule texture).
func _vignette() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.04, 0.03, 0.08, 0.0))
	g.set_color(1, Color(0.04, 0.03, 0.08, 0.5))
	g.add_point(0.62, Color(0.04, 0.03, 0.08, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 1.05)
	t.width = 128
	t.height = 72
	var r := TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _ready() -> void:
	_build_theme()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_ui
	add_child(root)
	vignette = _vignette()
	root.add_child(vignette)
	title_root = _build_title()
	root.add_child(title_root)
	hud_root = _build_hud()
	root.add_child(hud_root)
	touch_root = preload("res://scripts/touch_controls.gd").new()
	touch_root.visible = false
	root.add_child(touch_root)
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toasts.position = Vector2(-110, -22)
	toasts.custom_minimum_size = Vector2(220, 0)
	toasts.alignment = BoxContainer.ALIGNMENT_END
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)
	panel_root = _build_panel()
	root.add_child(panel_root)


func bind(w: Node2D) -> void:
	world = w
	world.toast.connect(show_toast)
	world.dialog_requested.connect(open_dialog)
	world.panel_requested.connect(_on_panel_requested)
	show_title()


# ---------------------------------------------------------------- Thème

func _box(bg: Color, border: Color, bw: int = 1, pad: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	return s


const UI_TEX := preload("res://art/ui.png")
const FONT := preload("res://art/font/brume.fnt")
## Taille native de la police pixel : le texte s'affiche à 1×, les titres à 2× ou 3×, jamais flou.
const FS := 12


func _tex(name: String) -> AtlasTexture:
	var r: Array = UiAtlas.R[name]
	var t := AtlasTexture.new()
	t.atlas = UI_TEX
	t.region = Rect2(r[0], r[1], r[2], r[3])
	return t


## Cadre en 9 tranches découpé dans art/ui.png.
func _sbox(name: String, margin: int, pad: Array) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = _tex(name)
	s.set_texture_margin_all(margin)
	s.content_margin_left = pad[0]
	s.content_margin_top = pad[1]
	s.content_margin_right = pad[2]
	s.content_margin_bottom = pad[3]
	return s


func _build_theme() -> void:
	var font: FontFile = FONT
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	ThemeDB.fallback_font = FONT
	ThemeDB.fallback_font_size = FS
	theme_ui.default_font = FONT
	theme_ui.default_font_size = FS
	theme_ui.set_color("font_color", "Label", C_INK)
	theme_ui.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme_ui.set_constant("shadow_offset_x", "Label", 1)
	theme_ui.set_constant("shadow_offset_y", "Label", 1)
	theme_ui.set_constant("line_spacing", "Label", -1)
	for t in ["Button", "OptionButton", "CheckButton"]:
		theme_ui.set_color("font_color", t, C_INK)
		theme_ui.set_color("font_hover_color", t, Color.WHITE)
		theme_ui.set_color("font_focus_color", t, Color.WHITE)
		theme_ui.set_color("font_pressed_color", t, Color("#ffe08a"))
		theme_ui.set_color("font_disabled_color", t, Color(C_INK, 0.45))
		theme_ui.set_color("font_outline_color", t, Color("#102040"))
		theme_ui.set_constant("outline_size", t, 2)
	for t in ["Button", "OptionButton"]:
		theme_ui.set_stylebox("normal", t, _sbox("btn_normal", 4, [7, 2, 7, 3]))
		theme_ui.set_stylebox("hover", t, _sbox("btn_hover", 4, [7, 2, 7, 3]))
		theme_ui.set_stylebox("pressed", t, _sbox("btn_pressed", 4, [7, 3, 7, 2]))
		theme_ui.set_stylebox("disabled", t, _sbox("btn_disabled", 4, [7, 2, 7, 3]))
		theme_ui.set_stylebox("focus", t, _sbox("focus", 3, [0, 0, 0, 0]))
	theme_ui.set_icon("arrow", "OptionButton", _tex("arrow"))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		theme_ui.set_stylebox(st, "CheckButton", empty)
	theme_ui.set_stylebox("focus", "CheckButton", _sbox("focus", 3, [0, 0, 0, 0]))
	for ic in ["checked", "checked_disabled"]:
		theme_ui.set_icon(ic, "CheckButton", _tex("check_on"))
	for ic in ["unchecked", "unchecked_disabled"]:
		theme_ui.set_icon(ic, "CheckButton", _tex("check_off"))
	theme_ui.set_stylebox("panel", "PanelContainer", _sbox("panel", 8, [10, 9, 10, 9]))
	theme_ui.set_stylebox("background", "ProgressBar", _sbox("bar_bg", 2, [0, 0, 0, 0]))
	theme_ui.set_stylebox("fill", "ProgressBar", _sbox("bar_hp", 1, [0, 0, 0, 0]))
	theme_ui.set_stylebox("slider", "HSlider", _sbox("slider", 2, [0, 2, 0, 2]))
	theme_ui.set_icon("grabber", "HSlider", _tex("grabber"))
	theme_ui.set_icon("grabber_highlight", "HSlider", _tex("grabber"))
	var gf := StyleBoxFlat.new()
	gf.bg_color = Color("#e0a848")
	gf.content_margin_top = 2
	gf.content_margin_bottom = 2
	theme_ui.set_stylebox("grabber_area", "HSlider", gf)
	theme_ui.set_stylebox("grabber_area_highlight", "HSlider", gf)
	var pm := _sbox("panel", 8, [6, 6, 6, 6])
	theme_ui.set_stylebox("panel", "PopupMenu", pm)
	theme_ui.set_color("font_color", "PopupMenu", C_INK)
	theme_ui.set_color("font_hover_color", "PopupMenu", Color("#ffe08a"))
	var hv := StyleBoxFlat.new()
	hv.bg_color = Color("#2a52a8")
	theme_ui.set_stylebox("hover", "PopupMenu", hv)
	theme_ui.set_stylebox("panel", "TooltipPanel", _sbox("hud", 4, [4, 3, 4, 3]))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#e0a848")
	theme_ui.set_stylebox("grabber", "VScrollBar", sb)
	var sbh := StyleBoxFlat.new()
	sbh.bg_color = Color("#ffe08a")
	theme_ui.set_stylebox("grabber_highlight", "VScrollBar", sbh)
	theme_ui.set_stylebox("grabber_pressed", "VScrollBar", sbh)
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = Color(0, 0, 0, 0.35)
	sbs.content_margin_left = 3
	sbs.content_margin_right = 0
	theme_ui.set_stylebox("scroll", "VScrollBar", sbs)


## Les tailles demandées par le code (7 à 11) passent toutes à la taille native de la police pixel.
func _fs(size: int) -> int:
	return FS * 3 if size >= 24 else (FS * 2 if size >= 16 else FS)


func _label(text: String, size: int = 9, col: Color = C_INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _fs(size))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- Titre

func _build_title() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.07, 0.1, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(shade)
	return c


func show_title() -> void:
	for ch in title_root.get_children().slice(1):
		ch.queue_free()
	world.mode = "title"
	world.new_game(1234)
	title_root.visible = true
	hud_root.visible = false
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	col.offset_top = 4
	title_root.add_child(col)
	var demo := _label(Lang.t("demo_line"), 7, C_BRASS)
	demo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(demo)
	var logo := TextureRect.new()
	logo.texture = preload("res://art/logo.png")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	col.add_child(logo)
	var tag := _label(Lang.t("tagline"), 8, C_BRASS)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	# notes de version
	var notes := PanelContainer.new()
	notes.custom_minimum_size = Vector2(130, 0)
	notes.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var nv := VBoxContainer.new()
	notes.add_child(nv)
	nv.add_child(_label(Lang.t("notes_title"), 9, C_BRASS))
	for n in Lang.t("notes").slice(0, 4):
		nv.add_child(_label("• " + n, 7, C_INK, true))
	row.add_child(notes)
	# menu
	var menu := PanelContainer.new()
	menu.custom_minimum_size = Vector2(120, 0)
	menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	menu.add_child(mv)
	var any_save := ["auto", "1", "2", "3"].any(func(s): return not world.read_save(s).is_empty())
	var cont := _button(Lang.t("continue"), _continue, not any_save)
	mv.add_child(cont)
	mv.add_child(_button(Lang.t("new_game"), func(): world.new_game(randi()); start_play()))
	mv.add_child(_button(Lang.t("load"), func(): open_saves(false)))
	mv.add_child(_button(Lang.t("settings"), open_settings))
	mv.add_child(_button(Lang.t("controls"), open_controls))
	mv.add_child(_button(Lang.t("support"), open_patreon))
	mv.add_child(_button(Lang.t("credits"), func(): _simple(Lang.t("credits"), Lang.t("credits_txt"))))
	mv.add_child(_button(Lang.t("quit"), func(): get_tree().quit()))
	var lang_row := HBoxContainer.new()
	lang_row.add_child(_label(Lang.t("language"), 8))
	var opt := OptionButton.new()
	opt.add_item("Français")
	opt.add_item("English")
	opt.selected = 0 if Settings.lang == "fr" else 1
	opt.item_selected.connect(func(i): Settings.lang = "fr" if i == 0 else "en"; Settings.save_settings(); show_title())
	lang_row.add_child(opt)
	row.add_child(menu)
	# soutien
	var sup := PanelContainer.new()
	sup.custom_minimum_size = Vector2(130, 0)
	sup.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sv := VBoxContainer.new()
	sup.add_child(sv)
	sv.add_child(_label(Lang.t("support"), 9, C_BRASS))
	sv.add_child(_label(Lang.t("support_pitch"), 7, C_INK, true))
	sv.add_child(_label(Lang.t("tier_now", [Lang.t("tier_names")[Settings.tier]]), 7, C_DIM))
	sv.add_child(lang_row)
	row.add_child(sup)
	(cont if any_save else mv.get_child(1)).call_deferred("grab_focus")


func _continue() -> void:
	var best := ""
	var best_at := -1.0
	for s in ["auto", "1", "2", "3"]:
		var d: Dictionary = world.read_save(s)
		if not d.is_empty() and d.at > best_at:
			best_at = d.at
			best = s
	if best != "" and world.load_save(best):
		start_play()
		show_toast(Lang.t("loaded"), "good")


func start_play() -> void:
	world.mode = "play"
	close_panel()
	title_root.visible = false
	hud_root.visible = true
	_update_hud()


# ---------------------------------------------------------------- HUD

func _build_hud() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := PanelContainer.new()
	left.position = Vector2(6, 6)
	left.custom_minimum_size = Vector2(130, 0)
	left.add_theme_stylebox_override("panel", _sbox("hud", 4, [5, 4, 5, 4]))
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	left.add_child(lv)
	h_lv = _label("", 8, C_BRASS)
	lv.add_child(h_lv)
	h_hp = ProgressBar.new()
	h_hp.custom_minimum_size = Vector2(120, 8)
	h_hp.show_percentage = false
	lv.add_child(h_hp)
	h_xp = ProgressBar.new()
	h_xp.custom_minimum_size = Vector2(120, 6)
	h_xp.show_percentage = false
	h_xp.add_theme_stylebox_override("fill", _sbox("bar_xp", 1, [0, 0, 0, 0]))
	lv.add_child(h_xp)
	h_gold = _label("", 8)
	lv.add_child(h_gold)
	h_state = _label("", 7, C_MIST, true)
	lv.add_child(h_state)
	c.add_child(left)
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-156, 6)
	right.custom_minimum_size = Vector2(150, 0)
	right.add_theme_stylebox_override("panel", _sbox("hud", 4, [5, 4, 5, 4]))
	h_quest = _label("", 7, C_INK, true)
	h_quest.custom_minimum_size = Vector2(140, 0)
	right.add_child(h_quest)
	c.add_child(right)
	h_hint = _label("", 7, C_DIM)
	h_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	h_hint.position = Vector2(-200, -14)
	h_hint.custom_minimum_size = Vector2(400, 0)
	h_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(h_hint)
	return c


func _update_hud() -> void:
	var w = world
	var mh: float = w.body.maxhp if w.body else w.max_hp()
	var hp: float = w.body.hp if w.body else w.p_hp
	h_lv.text = Lang.t("lv", [w.lvl]) + "  ♥ %d/%d" % [ceili(w.body.hp if w.body else w.p_hp), int(w.body.maxhp if w.body else w.max_hp())] + (" · " + Lang.t("married", [w.spouse]) if w.spouse != "" else "")
	h_hp.max_value = mh
	h_hp.value = hp
	h_xp.max_value = w.xp_need(w.lvl)
	h_xp.value = w.xp
	var m := int(fmod(w.time * 24.0, 24.0) * 60)
	h_gold.text = Lang.t("gold", [w.gold]) + "   " + Lang.t("day", [w.day, "%02d:%02d" % [m / 60, m % 60]])
	h_state.text = Lang.t("in_body", [Lang.nm(w.body.kind)]) if w.body else (Lang.t("masked", [Lang.nm(w.mask)]) if w.mask != "" else "")
	var q: Dictionary = w.quest_progress()
	if q.is_empty():
		h_quest.text = Lang.t("all_done")
	else:
		var qt: Array = Lang.QTXT[Settings.lang][w.quest]
		h_quest.text = "%s %d/%d\n%s\n%s (%d/%d)" % [Lang.t("quest"), w.quest + 1, Defs.QUESTS.size(), qt[0], qt[1], q.v, q.goal]
		if q.done:
			h_quest.text += "\n" + Lang.t("quest_done")
	h_hint.text = Lang.t("placing") if w.placing != "" else ("" if touch_root.visible else Lang.t("hint"))


func _process(dt: float) -> void:
	# Le vignettage suit le réglage « lumières » : coupé d'office sur téléphone pour garder les FPS.
	vignette.visible = Settings.lights
	if world:
		touch_root.visible = world.mode == "play" and not is_open() and Settings.touch_on()
	if world and world.mode == "play":
		hud_t -= dt
		if hud_t <= 0:
			hud_t = 0.1
			_update_hud()


# ---------------------------------------------------------------- Panneaux

func _build_panel() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(280, 0)
	center.add_child(pc)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(scroll)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation", 3)
	scroll.add_child(panel_box)
	return c


func is_open() -> bool:
	return panel_root.visible


func _open(kind: String, title: String) -> void:
	panel_kind = kind
	for ch in panel_box.get_children():
		ch.queue_free()
	panel_box.add_child(_label(title, 11, C_BRASS))
	panel_root.visible = true
	world.paused = true
	call_deferred("_fit_and_focus")


func _fit_and_focus() -> void:
	var scroll: ScrollContainer = panel_box.get_parent()
	scroll.custom_minimum_size.y = minf(panel_box.get_combined_minimum_size().y, get_viewport().get_visible_rect().size.y - 40)
	for ch in panel_box.get_children():
		var b := _first_button(ch)
		if b:
			b.grab_focus()
			return


func _first_button(n: Node) -> Button:
	if n is Button and not n.disabled:
		return n
	for ch in n.get_children():
		var b := _first_button(ch)
		if b:
			return b
	return null


func close_panel() -> void:
	panel_root.visible = false
	panel_kind = ""
	npc = null
	if world:
		world.paused = false


func _back_button() -> Button:
	if world.mode == "play":
		return _button(Lang.t("back"), open_pause)
	return _button(Lang.t("close"), close_panel)


func _row(text: String, sub: String, btn: Button) -> Control:
	var h := HBoxContainer.new()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label(text, 8, C_INK, true))
	if sub != "":
		v.add_child(_label(sub, 7, C_DIM, true))
	h.add_child(v)
	if btn:
		h.add_child(btn)
	return h


func _cost(need: Dictionary) -> String:
	var parts := []
	for k in need:
		parts.append("%d %s" % [need[k], Lang.nm(k)])
	return " · ".join(parts)


func _simple(title: String, text: String) -> void:
	_open("simple", title)
	panel_box.add_child(_label(text, 8, C_INK, true))
	panel_box.add_child(_back_button())


func _unhandled_input(ev: InputEvent) -> void:
	if not is_open():
		return
	var toggles := {"inv": "inventory", "build": "build", "map": "map"}
	if ev.is_action_pressed("pause") or (toggles.has(panel_kind) and ev.is_action_pressed(toggles[panel_kind])):
		if world.mode == "play" and panel_kind in ["settings", "controls", "saves", "patreon", "simple"]:
			open_pause()
		else:
			close_panel()
		get_viewport().set_input_as_handled()


## Bouton « retour » d'Android : ouvre la pause en jeu, sinon referme le panneau ouvert.
func go_back() -> void:
	if is_open():
		if world.mode == "play" and panel_kind in ["settings", "controls", "saves", "patreon", "simple"]:
			open_pause()
		else:
			close_panel()
	elif world.mode == "play":
		open_pause()
	else:
		get_tree().quit()


func _on_panel_requested(kind: String) -> void:
	match kind:
		"inv":
			open_inventory()
		"build":
			open_build()
		"map":
			open_map()
		"pause":
			open_pause()


func open_pause() -> void:
	_open("pause", Lang.t("pause"))
	panel_box.add_child(_button(Lang.t("resume"), close_panel))
	panel_box.add_child(_button(Lang.t("save"), func(): open_saves(true)))
	panel_box.add_child(_button(Lang.t("load"), func(): open_saves(false)))
	panel_box.add_child(_button(Lang.t("settings"), open_settings))
	panel_box.add_child(_button(Lang.t("controls"), open_controls))
	panel_box.add_child(_button(Lang.t("support"), open_patreon))
	panel_box.add_child(_button(Lang.t("to_menu"), func(): close_panel(); show_title()))


func open_saves(saving: bool) -> void:
	_open("saves", Lang.t("save") if saving else Lang.t("load"))
	for s in (["1", "2", "3"] if saving else ["auto", "1", "2", "3"]):
		var d: Dictionary = world.read_save(s)
		var lab: String = Lang.t("auto") if s == "auto" else Lang.t("slot", [s])
		var info: String = Lang.t("empty")
		if not d.is_empty():
			info = "%s · %s · %s" % [Lang.t("lv", [int(d.player.lvl)]), Lang.t("day", [int(d.day), ""]), Time.get_datetime_string_from_unix_time(int(d.at), true)]
		var btn: Button
		if saving:
			btn = _button(Lang.t("save"), func(): world.write_save(s); show_toast(Lang.t("saved"), "good"); open_saves(true))
		else:
			btn = _button(Lang.t("load"), func():
				if world.load_save(s):
					start_play()
					show_toast(Lang.t("loaded"), "good"), d.is_empty())
		panel_box.add_child(_row(lab, info, btn))
	panel_box.add_child(_back_button())


func open_settings() -> void:
	_open("settings", Lang.t("settings"))
	var vol := HSlider.new()
	vol.min_value = 0
	vol.max_value = 1
	vol.step = 0.1
	vol.value = Settings.vol
	vol.custom_minimum_size = Vector2(100, 10)
	vol.value_changed.connect(func(v): Settings.vol = v; Settings.save_settings())
	panel_box.add_child(_row(Lang.t("vol"), "", null))
	panel_box.add_child(vol)
	var sh := CheckButton.new()
	sh.text = Lang.t("shake")
	sh.button_pressed = Settings.shake
	sh.toggled.connect(func(on): Settings.shake = on; Settings.save_settings())
	panel_box.add_child(sh)
	var diff := OptionButton.new()
	for k in ["easy", "normal", "hard"]:
		diff.add_item(Lang.t(k))
	diff.selected = ["easy", "normal", "hard"].find(Settings.diff)
	diff.item_selected.connect(func(i): Settings.diff = ["easy", "normal", "hard"][i]; Settings.save_settings())
	panel_box.add_child(_row(Lang.t("diff"), "", null))
	panel_box.add_child(diff)
	var tier := OptionButton.new()
	for n in Lang.t("tier_names"):
		tier.add_item(n)
	tier.selected = Settings.tier
	tier.item_selected.connect(func(i): Settings.tier = i; Settings.save_settings(); open_settings())
	panel_box.add_child(_row(Lang.t("tier_sim"), "", null))
	panel_box.add_child(tier)
	var gold := CheckButton.new()
	gold.text = Lang.t("gold_skin")
	gold.button_pressed = Settings.gold_skin
	gold.disabled = Settings.tier < 1
	gold.toggled.connect(func(on): Settings.gold_skin = on; Settings.save_settings())
	panel_box.add_child(gold)
	var lights := CheckButton.new()
	lights.text = Lang.t("lights")
	lights.button_pressed = Settings.lights
	lights.toggled.connect(func(on): Settings.lights = on; Settings.save_settings())
	panel_box.add_child(lights)
	panel_box.add_child(_label(Lang.t("perf_sub"), 7, C_DIM, true))
	var eco := CheckButton.new()
	eco.text = Lang.t("eco")
	eco.button_pressed = Settings.eco
	eco.toggled.connect(func(on): Settings.eco = on; Settings.apply(); Settings.save_settings())
	panel_box.add_child(eco)
	var touch := OptionButton.new()
	for n in Lang.t("touch_modes"):
		touch.add_item(n)
	touch.selected = ["auto", "on", "off"].find(Settings.touch)
	touch.item_selected.connect(func(i): Settings.touch = ["auto", "on", "off"][i]; Settings.save_settings())
	panel_box.add_child(_row(Lang.t("touch"), "", null))
	panel_box.add_child(touch)
	panel_box.add_child(_back_button())


func open_controls() -> void:
	_open("controls", Lang.t("controls"))
	for k in Lang.t("keys"):
		panel_box.add_child(_row(k[0], k[1], null))
	panel_box.add_child(_back_button())


func open_patreon() -> void:
	_open("patreon", Lang.t("pat_t"))
	var names: Array = Lang.t("tiers")
	for i in names.size():
		var t: Array = names[i]
		var l := _row("%s · %s%s" % [t[0], t[1], "  ◀" if i == Settings.tier else ""], t[2], null)
		panel_box.add_child(l)
	panel_box.add_child(_label(Lang.t("pat_how"), 7, C_DIM, true))
	panel_box.add_child(_button(Lang.t("tier_sim"), open_settings))
	panel_box.add_child(_back_button())


func open_inventory() -> void:
	var w = world
	if w.body:
		show_toast(Lang.t("cant_here"), "")
		return
	_open("inv", Lang.t("inv"))
	if w.inv.is_empty():
		panel_box.add_child(_label(Lang.t("nothing"), 8, C_DIM))
	for k in w.inv.keys():
		var btn: Button = null
		if k == "potion" or k == "stew":
			btn = _button(Lang.t("use"), func(): w.heal_item(k); open_inventory())
		elif Defs.MASKF.has(k):
			if w.mask == k:
				btn = _button(Lang.t("unequip"), func(): w.mask = ""; open_inventory())
			else:
				btn = _button(Lang.t("equip"), func(): w.mask = k; open_inventory())
		panel_box.add_child(_row("%s ×%d" % [Lang.nm(k), w.inv[k]], "", btn))
	var eq := []
	if w.sword:
		eq.append(Lang.nm("sword"))
	if w.armor:
		eq.append(Lang.nm("armor"))
	if w.relic:
		eq.append(Lang.t("relic"))
	if w.mask != "":
		eq.append(Lang.nm(w.mask))
	panel_box.add_child(_label(Lang.t("equipment"), 9, C_MIST))
	panel_box.add_child(_label("%s · ATQ %d · DEF %d" % [" · ".join(eq) if eq else "—", w.atk_p(), w.def_p()], 7, C_DIM, true))
	panel_box.add_child(_label(Lang.t("crafting"), 9, C_MIST))
	var ws: bool = w.near_workshop()
	if not ws:
		panel_box.add_child(_label(Lang.t("need_ws"), 7, C_DIM, true))
	for r in Defs.RECIPES:
		var done: bool = r.get("once", false) and w.get(r.id)
		var dis: bool = done or (r.get("ws", false) and not ws) or not w.has(r.need)
		var id: String = r.id
		var btn := _button("✓" if done else Lang.t("craft"), func():
			if w.has(r.need):
				w.take(r.need)
				if r.get("once", false):
					w.set(id, true)
				else:
					w.give(id)
				show_toast(Lang.t("crafted", [Lang.nm(id)]), "good")
			open_inventory(), dis)
		panel_box.add_child(_row(Lang.nm(id), _cost(r.need), btn))
	panel_box.add_child(_button(Lang.t("close"), close_panel))


func open_build() -> void:
	var w = world
	if w.body:
		show_toast(Lang.t("cant_here"), "")
		return
	_open("build", Lang.t("build"))
	panel_box.add_child(_label(Lang.t("build_help"), 7, C_DIM, true))
	for k in Defs.BLD:
		var b: Dictionary = Defs.BLD[k]
		var lock: bool = b.has("tier") and Settings.tier < b.tier
		var title: String = Lang.nm(k) + ("  [%s]" % Lang.t("tier_names")[b.tier] if b.has("tier") else "")
		var btn := _button(Lang.t("build"), func(): close_panel(); w.placing = k, lock or not w.has(b.cost))
		panel_box.add_child(_row(title, _cost(b.cost) + " — " + Lang.DESC[Settings.lang][k], btn))
	panel_box.add_child(_button(Lang.t("close"), close_panel))


func open_map() -> void:
	_open("map", Lang.t("map_t"))
	var tr := TextureRect.new()
	tr.texture = Art.minimap(world.map, world.buildings, world.p_pos)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(216, 162)
	panel_box.add_child(tr)
	panel_box.add_child(_label(Lang.t("map_legend"), 7, C_DIM, true))
	panel_box.add_child(_button(Lang.t("close"), close_panel))


# ---------------------------------------------------------------- Dialogues

func _hearts(a: int) -> String:
	var n := int(round(a / 20.0))
	return "♥".repeat(n) + "♡".repeat(5 - n)


func open_dialog(e, line: String = "") -> void:
	var w = world
	npc = e
	var name_txt: String = Lang.t("elder") if e.kind == "elder" else (Lang.t("trader") if e.kind == "trader" else e.name)
	_open("dialog", name_txt)
	if e.kind == "villager":
		panel_box.add_child(_label("%s  %d/100%s" % [_hearts(e.aff), e.aff, "  ♥" if e.spouse else ""], 8, Color("#d4483b")))
	if w.body and e.kind != "elder":
		line = Lang.t("scared")
	var say := line
	var acts := []
	if e.kind == "elder":
		var lines: Array = Lang.ELDER[Settings.lang]
		if say == "":
			say = lines[mini(w.quest, lines.size() - 1)]
		var q: Dictionary = w.quest_progress()
		if not q.is_empty() and q.done:
			acts.append(_button(Lang.t("claim"), func(): w.claim_quest(); open_dialog(e)))
	elif e.kind == "trader":
		if say == "":
			say = Lang.t("trader_hi")
		acts.append(_button("%s : %s (15 %s)" % [Lang.t("buy"), Lang.nm("potion"), Lang.nm("gold")], func():
			if w.gold >= 15:
				w.gold -= 15
				w.give("potion")
			open_dialog(e), w.gold < 15))
		for k in Defs.SELL:
			var n: int = w.inv.get(k, 0)
			if n:
				acts.append(_button("%s %d %s (+%d)" % [Lang.t("sell"), n, Lang.nm(k), n * Defs.SELL[k]], func():
					w.take({k: n})
					w.gold += n * Defs.SELL[k]
					open_dialog(e)))
	elif not w.body:
		if say == "":
			var tier := "high" if e.aff >= 60 else ("mid" if e.aff >= 25 else "low")
			say = Lang.CHAT[Settings.lang][tier][int(e.seed + e.aff) % 3]
		acts.append(_button(Lang.t("talk"), func():
			e.talks += 1
			e.aff = mini(100, e.aff + 6)
			open_dialog(e), e.talks >= 3))
		acts.append(_button(Lang.t("gift"), func(): _open_gift(e)))
		if e.follow:
			acts.append(_button(Lang.t("stay"), func(): e.follow = false; e.pos = e.home; open_dialog(e, Lang.t("stay_ok"))))
		else:
			acts.append(_button(Lang.t("follow"), func():
				var n: int = w.ents.filter(func(x): return x.follow).size()
				if e.aff >= 40 and n < 2:
					e.follow = true
					open_dialog(e, Lang.t("follow_yes"))
				else:
					open_dialog(e, Lang.t("follow_no"))))
		if not e.spouse and w.spouse == "":
			acts.append(_button(Lang.t("propose"), func():
				if e.aff >= 80 and w.inv.get("ring", 0):
					w.take({"ring": 1})
					e.spouse = true
					e.aff = 100
					w.spouse = e.name
					w.burst(e.pos + Vector2(0, -16), Color("#ff8aa0"), 20)
					open_dialog(e, Lang.t("propose_yes"))
				else:
					open_dialog(e, Lang.t("propose_need"))))
		if e.talks >= 3 and line == "":
			say = Lang.t("tired_talk")
	var sayl := _label(say, 8, C_INK, true)
	sayl.custom_minimum_size = Vector2(260, 0)
	panel_box.add_child(sayl)
	for b in acts:
		panel_box.add_child(b)
	panel_box.add_child(_button(Lang.t("bye"), close_panel))


func _open_gift(e) -> void:
	var w = world
	var any := false
	_open("dialog", Lang.t("gift") + " : " + e.name)
	for k in Defs.GIFTS:
		if w.inv.get(k, 0):
			any = true
			panel_box.add_child(_button("%s ×%d (+%d)" % [Lang.nm(k), w.inv[k], Defs.GIFTS[k]], func():
				w.take({k: 1})
				e.aff = mini(100, e.aff + Defs.GIFTS[k])
				open_dialog(e, Lang.t("gift_thanks"))))
	if not any:
		open_dialog(e, Lang.t("no_gift"))
		return
	panel_box.add_child(_button(Lang.t("back"), func(): open_dialog(e)))


# ---------------------------------------------------------------- Messages

func show_toast(text: String, kind: String) -> void:
	var p := PanelContainer.new()
	var border := C_BRASS
	if kind == "good":
		border = Color("#8fc25a")
	elif kind == "bad":
		border = Color("#e0604f")
	var st := _sbox("hud", 4, [6, 3, 6, 4])
	st.modulate_color = border.lerp(Color.WHITE, 0.3)
	p.add_theme_stylebox_override("panel", st)
	var l := _label(text, 8, C_INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	toasts.add_child(p)
	while toasts.get_child_count() > 4:
		toasts.get_child(0).free()
	# Connexion directe : elle disparaît toute seule si le message a déjà été retiré.
	get_tree().create_timer(3.2).timeout.connect(p.queue_free)
