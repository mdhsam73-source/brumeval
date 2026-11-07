extends SceneTree
## Prend des captures d'écran du jeu (titre, village, survie, sac, dialogue, scène, nuit).
## Utilisé par GitHub à chaque PR pour voir le résultat sans rien télécharger.
## godot --rendering-driver opengl3 --path . --script res://tests/captures.gd
## Les images vont dans le dossier donné par la variable SHOT_DIR (sinon « captures/ »).
var f := 0
var main
var dir := ""
func _initialize():
	dir = OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func shot(n):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir + "/" + n + ".png")
	print("capture ", n)
func clear(ui):
	for c in ui.toasts.get_children(): c.queue_free()
func _process(dt):
	f += 1
	var w = main.get_node("World")
	var ui = main.get_node("UI")
	var cs = ui.cutscene
	if f == 40: shot("1_titre")
	if f == 45:
		w.new_game(42); ui.start_play(); cs.skip()
		w.flags["seen_chef"] = true; w.flags["echoes"] = ["veilleur", "forest", "marsh", "crypt"]
		w.time = 0.35
	if f == 90: clear(ui); shot("2_village")
	if f == 95:
		for k in ["wood", "stone", "berry", "meat", "hide", "fang", "crystal", "potion", "bread", "bandage", "mask_gob"]:
			w.inv[k] = 1 + (k.length() % 7)
		w.hunger = 30.0; w.bleed_t = 10.0; w.p_hp = 22.0
		ui.open_inventory()
	if f == 130: clear(ui); shot("3_sac")
	if f == 135:
		ui.close_panel(); w.bleed_t = 0.0; w.p_hp = 50.0; w.hunger = 80.0
		for e in w.ents:
			if e.kind == "villager": w.p_pos = e.pos + Vector2(0, 20); e.aff = 70; ui.open_dialog(e); break
	if f == 170: clear(ui); shot("4_dialogue")
	if f == 175:
		ui.close_panel(); ui.play_scene("intro")
	if f == 250:
		while cs.i < cs.steps.size() and not cs.steps[cs.i].has("say"): cs._next()
	if f == 310: shot("5_scene")
	if f == 315:
		cs.skip(); w.time = 0.95
	if f == 370: clear(ui); shot("6_nuit")
	if f == 375: quit()
