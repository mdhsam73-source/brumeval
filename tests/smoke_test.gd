extends SceneTree
## Test rapide sans écran : nouvelle partie, constructions, panneaux, transfert d'âme,
## sauvegarde et chargement, passage au jour suivant.
## godot --headless --script res://tests/smoke_test.gd
var frames := 0
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(dt):
	frames += 1
	var w = main.get_node("World")
	var ui = main.get_node("UI")
	if frames == 5:
		w.new_game(42); ui.start_play()
		w.inv["wood"]=100; w.inv["stone"]=100; w.inv["ear"]=5; w.inv["crystal"]=5; w.gold=100; w.inv["berry"]=10
		w.placing="campfire"; w.p_dir=Vector2i(0,1); w.place_building()
		w.placing="workshop"; w.p_dir=Vector2i(1,0); w.place_building()
		w.placing="house"; w.p_dir=Vector2i(-1,0); w.place_building()
		w.placing="mill"; w.p_dir=Vector2i(0,-1); w.place_building()
		print("buildings ", w.buildings.size(), " ents ", w.ents.size())
		ui.open_inventory(); ui.open_build(); ui.open_map(); ui.open_pause(); ui.open_settings(); ui.open_patreon(); ui.open_controls(); ui.open_saves(true)
		var v = null
		for e in w.ents:
			if e.kind=="villager": v=e; break
		v.aff = 90
		ui.open_dialog(v)
		for e in w.ents:
			if e.kind=="elder": ui.open_dialog(e)
			if e.kind=="trader": ui.open_dialog(e)
		ui.close_panel()
	if frames == 10:
		var wolf = null
		for e in w.ents:
			if e.kind=="loup": wolf=e; break
		wolf.hp = 2; w.p_pos = wolf.pos + Vector2(0,4); w.soul_action()
		print("in body ", w.body)
	if frames == 30:
		w.soul_return(false)
		print("allies ", w.ents.filter(func(e): return e.ally).size())
		w.p_pos = Vector2(10*16, 10*16)
		for i in 20: w.player_attack(); w.atk_cd = 0
		w.time = 0.9
	if frames == 40:
		print("write ", w.write_save("1"))
		ui.show_title()
	if frames == 45:
		print("load ", w.load_save("1")); ui.start_play()
		print("after load buildings ", w.buildings.size(), " lvl ", w.lvl, " stats ", w.stats)
		w.time = 0.999
	if frames == 400:
		print("day ", w.day, " quest ", w.quest_progress())
		quit()
