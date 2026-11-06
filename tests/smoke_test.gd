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
		# Village qui grandit : hameau -> bourg -> ville, et bonus des bâtiments de ville.
		print("town ", w.town_lv(), " villagers ", w.villagers())
		for i in 5: w.add_villager(Vector2.INF)
		w._check_town()
		print("town after ", w.town_lv(), " seen ", w.town_seen)
		var base: int = w.sell_price("hide")
		var x := 6
		for k in ["tavern", "bakery", "market", "fountain", "chapel", "library", "well", "lamp", "bench", "rampart"]:
			w.add_building(k, x, 4)
			x += Defs.BLD[k].w + 1
		print("hide price ", base, " -> ", w.sell_price("hide"))
		var st: int = w.inv.get("stew", 0)
		var g: int = w.gold
		w._new_day()
		print("bakery stew +", w.inv.get("stew", 0) - st, " fountain gold +", w.gold - g)
		ui.open_build(); ui.open_inventory(); ui.close_panel()
		# Scènes cinématiques : chacune se lance, se passe, et rend la main au jeu.
		var v = null
		for e in w.ents:
			if e.kind == "villager": v = e; break
		var chef = null
		for e in w.ents:
			if e.kind == "chef": chef = e; break
		for sc in [["intro", null], ["chef", chef], ["chef_down", null], ["echo", "forest"], ["echo", "crypt"], ["festival", 1], ["date", v], ["wedding", v]]:
			ui.play_scene(sc[0], sc[1])
			var ok: bool = ui.cutscene.playing() and w.scene_on
			ui.cutscene.skip()
			print("scene ", sc[0], " ", ok, " -> ", not w.scene_on)
		print("echoes ", w.flags.get("echoes"), " date ", w.flags.get("date_" + v.name, false))
		ui.open_journal(); ui.close_panel()
		# Survie et monde cruel : faim, blessures, ruines, réfugiés, morts définitives.
		print("ruins ", w.buildings.filter(func(b): return b.k == "ruin").size())
		w.hunger = 50.0; w.inv["bread"] = 1; w.heal_item("bread")
		print("hunger after bread ", w.hunger)
		w.bleed_t = 10.0; w.inv["bandage"] = 1; w.heal_item("bandage")
		print("bleed after bandage ", w.bleed_t)
		w.hunger = 0.0; var hp0: float = w.p_hp; w._update_survival(1.0)
		print("starving hurts ", w.p_hp < hp0)
		w.hunger = 80.0
		for b in w.buildings:
			if b.k == "ruin": w.search_ruin(b); w.search_ruin(b); break
		print("ruins searched ", w.flags.get("ruins", {}).size())
		w.day = 5
		for t in 20:
			w._refugee_event()
			if w.ents.any(func(e): return e.kind == "refugee" and not e.dead): break
		var rf = null
		for e in w.ents:
			if e.kind == "refugee" and not e.dead: rf = e
		if rf:
			ui.open_dialog(rf); w.inv["bread"] = 2
			var n0: int = w.villagers()
			w.refugee_choice(rf, "help")
			print("refugee helped ", w.villagers() - n0)
		var vv = null
		for e in w.ents:
			if e.kind == "villager" and not e.dead: vv = e; break
		var m0: float = w.morale
		var graves0: int = w.buildings.filter(func(b): return b.k == "grave").size()
		w._villager_dies(vv, "died_villager")
		print("villager death morale ", w.morale < m0, " grave ", w.buildings.filter(func(b): return b.k == "grave").size() - graves0)
		ui.close_panel()
		quit()
