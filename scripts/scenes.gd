class_name Scenes
## Contenu des scènes cinématiques : l'histoire de la brume, la romance, les fêtes du village.
## Chaque fonction renvoie une liste d'étapes jouée par cutscene.gd :
##   {"cam": pos, "t": s}  {"say": nom, "text": txt}  {"fade": 0..1, "t": s}  {"wait": s}
##   {"walk": ent ou null (joueur), "to": pos, "t": s}  {"title": txt, "t": s}
##   {"fn": callable}  {"shake": s}  {"burst": pos, "c": couleur, "n": nombre}

const TS := 16
const HEART := Color("#ff8aa0")


static func tr2(fr: String, en: String) -> String:
	return fr if Settings.lang == "fr" else en


static func elder_name() -> String:
	return Lang.t("elder")


static func village_center() -> Vector2:
	return Vector2((Defs.VX + 0.5) * TS, (Defs.VY + 1) * TS)


static func _find(w, kind: String):
	for e in w.ents:
		if e.kind == kind:
			return e
	return null


# ---------------------------------------------------------------- Histoire

static func intro(w) -> Array:
	var c := village_center()
	var el = _find(w, "elder")
	var me: Vector2 = w.p_pos + Vector2(0, -8)
	return [
		{"fade": 1.0, "t": 0.01},
		{"fn": func(): w.scene_cam = c + Vector2(0, -40)},
		{"fade": 0.0, "t": 1.4},
		{"title": tr2("Chapitre I — La brume", "Chapter I — The Mist"), "t": 2.6},
		{"cam": el.pos + Vector2(0, -10) if el else c, "t": 1.6},
		{"say": elder_name(), "text": tr2("Il y a trois nuits, la brume est descendue des collines. Elle ne mouille pas. Elle efface.", "Three nights ago the mist came down from the hills. It isn't wet. It erases.")},
		{"say": elder_name(), "text": tr2("Ceux qu'elle touche oublient d'abord leur nom, puis leur visage. Il ne reste qu'une petite lueur bleue qui erre dans le marais.", "Those it touches forget their name first, then their face. All that's left is a small blue light wandering the marsh.")},
		{"say": elder_name(), "text": tr2("Toi, tu t'es réveillé au milieu d'elle, et tu te souviens encore. Les anciens appelaient ça un Porte-Âme.", "You woke up inside it, and you still remember. The old ones called that a Soulbearer.")},
		{"cam": me, "t": 1.2},
		{"say": elder_name(), "text": tr2("Rebâtis le village. Un feu, des murs, des gens. La brume recule devant ce qui est aimé.", "Rebuild the village. A fire, walls, people. The mist retreats from what is loved.")},
	]


static func chef(w, boss) -> Array:
	var me: Vector2 = w.p_pos + Vector2(0, -8)
	return [
		{"cam": boss.pos + Vector2(0, -16), "t": 1.0},
		{"shake": 0.5},
		{"burst": boss.pos + Vector2(0, -14), "c": Color("#c84a3a"), "n": 18},
		{"title": tr2("Mâchefer, chef des gobelins", "Clinker, the goblin chief"), "t": 2.0},
		{"say": tr2("Mâchefer", "Clinker"), "text": tr2("GRRAAH ! Encore un humain qui sent le feu de camp ! Mon camp, mes os, ma vallée !", "GRRAAH! Another human stinking of campfire! My camp, my bones, my valley!")},
		{"say": tr2("Mâchefer", "Clinker"), "text": tr2("Tu crois que c'est nous qu'il faut craindre ? Va voir ce qui chuchote dans la crypte… si tu survis à moi.", "You think we're the ones to fear? Go see what whispers in the crypt… if you survive me.")},
		{"cam": me, "t": 0.8},
	]


static func chef_down(w) -> Array:
	var el = _find(w, "elder")
	var me: Vector2 = w.p_pos + Vector2(0, -8)
	return [
		{"wait": 0.6},
		{"title": tr2("Mâchefer est tombé", "Clinker has fallen"), "t": 2.0},
		{"say": tr2("Voix dans la brume", "Voice in the mist"), "text": tr2("…un de plus… ils tombent tous… et tous viennent à moi…", "…one more… they all fall… and they all come to me…")},
		{"say": elder_name(), "text": tr2("(Plus tard, au village) Les gobelins fuyaient quelque chose, Porte-Âme. Pas toi. Quelque chose au nord-est.", "(Later, at the village) The goblins were running from something, Soulbearer. Not you. Something to the north-east.")},
		{"say": elder_name(), "text": tr2("Il y a une crypte là-bas, scellée par le Veilleur, le gardien de la vallée. S'il a ouvert la porte… que les feux nous protègent.", "There's a crypt there, sealed by the Watcher, the valley's guardian. If he has opened the door… may the fires protect us.")},
		{"fn": func(): w.add_echo("veilleur")},
		{"cam": me, "t": 0.6},
	]


## Échos : fragments de l'histoire de la brume, découverts en entrant dans chaque région.
static func echo(w, id: String) -> Array:
	var voice := tr2("Voix dans la brume", "Voice in the mist")
	var me: Vector2 = w.p_pos + Vector2(0, -8)
	var lines: Array = ECHO_LINES[id][Settings.lang]
	var out := [{"cam": me, "t": 0.01}, {"title": ECHO_TITLES[id][Settings.lang], "t": 2.2}]
	if id == "crypt":
		out.append({"shake": 0.6})
		out.append({"fade": 0.45, "t": 0.8})
	for l in lines:
		out.append({"say": voice, "text": l})
	if id == "crypt":
		out.append({"fade": 0.0, "t": 0.8})
	out.append({"fn": func(): w.add_echo(id)})
	out.append({"cam": me, "t": 0.3})
	return out


const ECHO_TITLES := {
	"forest": {"fr": "Écho I — Les arbres qui se souviennent", "en": "Echo I — The trees that remember"},
	"marsh": {"fr": "Écho II — Les lueurs", "en": "Echo II — The lights"},
	"crypt": {"fr": "Écho III — Le Veilleur", "en": "Echo III — The Watcher"},
	"veilleur": {"fr": "Écho IV — Ce que fuyaient les gobelins", "en": "Echo IV — What the goblins fled"},
}

const ECHO_LINES := {
	"forest": {
		"fr": ["Les loups n'étaient pas des loups. C'étaient des chiens de berger, avant la brume.", "Ils gardent encore leur troupeau… mais le troupeau, ce sont les arbres maintenant. Ils ne savent plus pourquoi."],
		"en": ["The wolves weren't wolves. They were sheepdogs, before the mist.", "They still guard their flock… but the flock is the trees now. They no longer know why."],
	},
	"marsh": {
		"fr": ["Chaque lueur est quelqu'un. Une boulangère. Un enfant qui comptait les grenouilles.", "Elles s'approchent de toi parce que tu brilles comme elles. Elles veulent rentrer. Elles ont oublié où."],
		"en": ["Every light is someone. A baker. A child who counted frogs.", "They come close because you shine like them. They want to go home. They've forgotten where."],
	},
	"crypt": {
		"fr": ["Porte-Âme. Je t'attendais. C'est moi qui ai fait la brume.", "J'ai gardé les morts de cette vallée pendant mille ans. Je suis fatigué. La brume, c'est moi qui lâche prise.", "Quand je disparaîtrai, elle disparaîtra… avec tout ce dont elle se souvient. Choisis bien ce que tu veux garder."],
		"en": ["Soulbearer. I was waiting for you. I made the mist.", "I have kept this valley's dead for a thousand years. I am tired. The mist is me letting go.", "When I fade, it fades… along with everything it remembers. Choose well what you want to keep."],
	},
	"veilleur": {
		"fr": ["Les spectres de la crypte sont ceux qui ont oublié jusqu'à leur peur.", "Le Veilleur ne les retient plus. Bientôt, ils sortiront la nuit."],
		"en": ["The crypt's spectres are those who forgot even their fear.", "The Watcher no longer holds them. Soon they will walk at night."],
	},
}


# ---------------------------------------------------------------- Village

static func festival(w, lv: int) -> Array:
	var c := village_center() + Vector2(0, 40)
	var el = _find(w, "elder")
	var name: String = Lang.t("town_names")[lv]
	var old := {}
	var vs: Array = w.ents.filter(func(e): return e.kind == "villager" or e.kind == "elder" or e.kind == "trader")
	var gather := func():
		w.time = 0.82
		for k in vs.size():
			var e = vs[k]
			old[e] = e.pos
			var a := TAU * k / vs.size()
			e.pos = c + Vector2(cos(a) * 34, sin(a) * 20)
			e.dir = Vector2i(int(signf(c.x - e.pos.x)), 0)
		w.p_pos = c + Vector2(0, 30)
		w.p_dir = Vector2i(0, -1)
		w.scene_cam = c + Vector2(0, -10)
	var out := [
		{"fade": 1.0, "t": 0.7},
		{"fn": gather},
		{"fade": 0.0, "t": 0.9},
		{"title": tr2("Fête au village !", "Village festival!"), "t": 2.0},
	]
	var cols := [Color("#ffd76a"), Color("#ff8aa0"), Color("#7cd0f0"), Color("#9fe08a"), Color("#c8a0ff")]
	for k in 6:
		out.append({"burst": c + Vector2(randf_range(-70, 70), randf_range(-90, -50)), "c": cols[k % cols.size()], "n": 22})
		out.append({"wait": 0.25})
	out.append({"say": elder_name(), "text": tr2("Regardez-nous. Il y a peu, nous n'étions qu'une poignée autour d'un feu. Aujourd'hui, Brumeval est un %s !" % name, "Look at us. Not long ago we were a handful around a fire. Today Brumeval is a %s!" % name)})
	var v = vs.filter(func(e): return e.kind == "villager").front() if vs.any(func(e): return e.kind == "villager") else null
	if v:
		out.append({"say": v.name, "text": tr2("La brume recule un peu plus chaque soir. Merci, Porte-Âme !", "The mist pulls back a little more every evening. Thank you, Soulbearer!")})
	for k in 4:
		out.append({"burst": c + Vector2(randf_range(-80, 80), randf_range(-100, -50)), "c": cols[(k + 2) % cols.size()], "n": 26})
		out.append({"wait": 0.2})
	out.append({"say": elder_name(), "text": tr2("De nouveaux bâtiments sont possibles. Continue, et la vallée entière se souviendra de toi.", "New buildings are possible. Keep going, and the whole valley will remember you.")})
	out.append({"fade": 1.0, "t": 0.6})
	out.append({"fn": func():
		for e in old:
			e.pos = old[e]})
	out.append({"fade": 0.0, "t": 0.6})
	return out


# ---------------------------------------------------------------- Romance

## Rendez-vous au coucher du soleil, au bord de l'eau.
static func date(w, e) -> Array:
	var spot: Vector2 = w.scenic_spot()
	var back_p: Vector2 = w.p_pos
	var back_e: Vector2 = e.pos
	var lines: Array = DATE_LINES[e.vc % DATE_LINES.size()][Settings.lang]
	return [
		{"fade": 1.0, "t": 0.7},
		{"fn": func():
			w.time = 0.74
			w.p_pos = spot + Vector2(-40, 6)
			e.pos = spot + Vector2(-56, 6)
			w.scene_cam = spot + Vector2(-10, -10)},
		{"fade": 0.0, "t": 0.9},
		{"title": tr2("Un soir, avec %s" % e.name, "An evening with %s" % e.name), "t": 2.0},
		{"walk": null, "to": spot + Vector2(-4, 6), "t": 1.6},
		{"walk": e, "to": spot + Vector2(-18, 6), "t": 1.0},
		{"fn": func():
			w.p_dir = Vector2i(-1, 0)
			e.dir = Vector2i(1, 0)},
		{"say": e.name, "text": lines[0]},
		{"say": e.name, "text": lines[1]},
		{"burst": spot + Vector2(-11, -20), "c": HEART, "n": 14},
		{"say": e.name, "text": lines[2]},
		{"fn": func():
			e.aff = mini(100, e.aff + 10)
			w.flags["date_" + e.name] = true},
		{"fade": 1.0, "t": 0.8},
		{"fn": func():
			w.p_pos = back_p
			e.pos = back_e
			w.time = 0.86},
		{"fade": 0.0, "t": 0.6},
	]


const DATE_LINES := [
	{"fr": ["Je ne savais pas que l'eau pouvait être aussi belle le soir. Avant, je ne levais jamais la tête.", "Tu sais ce qui me fait peur, avec la brume ? Oublier ce genre de moment.", "Alors on va s'en faire beaucoup. Comme ça, elle aura du travail."],
		"en": ["I didn't know the water could look this lovely at dusk. I never used to look up.", "You know what scares me about the mist? Forgetting moments like this.", "So let's make lots of them. That'll keep it busy."]},
	{"fr": ["Tu marches toujours devant tout le monde. Ce soir, marche à côté de moi.", "Quand tu reviens de la forêt, je compte les pas jusqu'à ce que je te voie.", "Ne le répète à personne, d'accord ? Surtout pas à l'Ancien."],
		"en": ["You always walk ahead of everyone. Tonight, walk next to me.", "When you come back from the forest, I count the steps until I can see you.", "Don't tell anyone, all right? Especially not the Elder."]},
	{"fr": ["J'ai apporté du pain. Il est un peu brûlé. J'étais distrait… à cause de toi.", "Les lueurs du marais ressemblent à des étoiles tombées. Tu crois qu'elles nous regardent ?", "Si elles nous regardent, alors elles voient quelqu'un d'heureux."],
		"en": ["I brought bread. It's a little burnt. I was distracted… because of you.", "The marsh lights look like fallen stars. Do you think they're watching us?", "If they are, they're looking at someone happy."]},
]


## Mariage : tout le village se rassemble, l'Ancien les unit, un baiser, puis fondu au noir.
static func wedding(w, e) -> Array:
	var c := village_center() + Vector2(0, 30)
	var el = _find(w, "elder")
	var old := {}
	var vs: Array = w.ents.filter(func(x): return x.kind == "villager" and x != e)
	var gather := func():
		w.time = 0.62
		for k in vs.size():
			var v = vs[k]
			old[v] = v.pos
			var side := -1 if k % 2 == 0 else 1
			v.pos = c + Vector2(side * (30 + (k / 2) * 14), 26 + (k / 2) * 4)
			v.dir = Vector2i(0, -1)
		if el:
			old[el] = el.pos
			el.pos = c + Vector2(0, -22)
			el.dir = Vector2i(0, 1)
		w.p_pos = c + Vector2(-9, 4)
		w.p_dir = Vector2i(1, 0)
		e.pos = c + Vector2(9, 4)
		e.dir = Vector2i(-1, 0)
		w.scene_cam = c + Vector2(0, -8)
	return [
		{"fade": 1.0, "t": 0.8},
		{"fn": gather},
		{"fade": 0.0, "t": 1.0},
		{"title": tr2("Le mariage de %s" % e.name, "%s's wedding" % e.name), "t": 2.4},
		{"say": elder_name(), "text": tr2("Nous sommes réunis parce que deux personnes ont décidé de se souvenir l'une de l'autre, quoi qu'il arrive.", "We are gathered because two people decided to remember each other, whatever happens.")},
		{"say": elder_name(), "text": tr2("%s, Porte-Âme : que vos feux brûlent ensemble, et que la brume ne trouve jamais le chemin de votre maison." % e.name, "%s, Soulbearer: may your fires burn together, and may the mist never find the way to your house." % e.name)},
		{"say": e.name, "text": tr2("Oui. Mille fois oui.", "Yes. A thousand times yes.")},
		{"say": elder_name(), "text": tr2("Vous pouvez vous embrasser.", "You may kiss.")},
		{"walk": null, "to": c + Vector2(-5, 4), "t": 0.5},
		{"burst": c + Vector2(0, -22), "c": HEART, "n": 30},
		{"wait": 0.4},
		{"burst": c + Vector2(-20, -40), "c": Color("#ffd76a"), "n": 20},
		{"burst": c + Vector2(20, -40), "c": HEART, "n": 20},
		{"wait": 0.8},
		{"fade": 1.0, "t": 1.2},
		{"title": tr2("Le lendemain matin…", "The next morning…"), "t": 2.2},
		{"fn": func():
			for v in old:
				v.pos = old[v]
			w.time = 0.27
			w.p_pos = c + Vector2(0, 10)
			e.pos = c + Vector2(14, 10)
			w.p_dir = Vector2i(1, 0)
			e.dir = Vector2i(-1, 0)
			w.scene_cam = c},
		{"fade": 0.0, "t": 1.0},
		{"say": e.name, "text": tr2("Bonjour, toi. J'ai fait du thé. Et je me souviens de tout.", "Morning, you. I made tea. And I remember everything.")},
	]
