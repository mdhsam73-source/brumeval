extends Node
## Textes FR/EN. Lang.t("cle", [arg0, arg1]) remplace {0}, {1}...
## Pour ajouter une langue : copier le bloc "en" sous un nouveau code et traduire.

const L := {
	"fr": {
		"demo_line": "Prototype original : contenu et systèmes en cours de développement.",
		"tagline": "PORTE-ÂME DE LA VALLÉE",
		"continue": "Continuer", "new_game": "Nouvelle partie", "load": "Charger", "save": "Sauvegarder",
		"settings": "Paramètres", "controls": "Commandes", "support": "Soutenir (Patreon)", "credits": "Crédits",
		"quit": "Quitter", "language": "Langue",
		"notes_title": "Notes de version 0.3",
		"notes": ["Nouveaux sprites, version Android, écran tactile", "Masques : l'espèce ne t'attaque plus", "Transfert d'âme (R) dans une créature affaiblie", "7 bâtiments, cycle jour/nuit", "Social : parler, offrir, recruter, mariage", "Manette prise en charge"],
		"support_pitch": "Nouveaux bâtiments, créatures et mises à jour chaque semaine. Les soutiens Patreon débloquent des bonus.",
		"tier_now": "Palier actif : {0}",
		"resume": "Reprendre", "to_menu": "Menu principal", "back": "Retour", "close": "Fermer", "pause": "Pause",
		"slot": "Emplacement {0}", "auto": "Sauvegarde auto", "empty": "Vide", "saved": "Partie sauvegardée.", "loaded": "Partie chargée.",
		"lv": "Niv. {0}", "gold": "{0} or", "day": "Jour {0} · {1}",
		"hint": "ZQSD/WASD bouger · Espace attaquer · E interagir · R âme · B bâtir · I sac · M carte · H potion",
		"placing": "Placement : E pour poser · Échap pour annuler",
		"quest": "Quête", "quest_done": "Retourne voir la Doyenne Orme", "all_done": "Toutes les quêtes sont faites. La suite arrive avec les mises à jour !",
		"quest_complete": "Quête terminée : {0}",
		"masked": "Déguisé : {0}", "in_body": "Âme dans : {0} (R pour revenir)",
		"inv": "Sac", "equip": "Porter", "unequip": "Retirer", "use": "Utiliser", "craft": "Fabriquer", "crafting": "Fabrication",
		"crafted": "Fabriqué : {0}", "need_ws": "Approche-toi d'un atelier pour ces recettes.", "nothing": "Ton sac est vide.", "equipment": "Équipement",
		"build": "Construire", "build_help": "Choisis un bâtiment, puis pose-le devant toi.", "blocked": "Emplacement bloqué.",
		"built": "Construction terminée : {0}", "not_enough": "Ressources insuffisantes.",
		"talk": "Discuter", "gift": "Offrir un cadeau", "follow": "Viens avec moi", "stay": "Reste au village",
		"propose": "Demander en mariage", "bye": "Au revoir", "claim": "Rendre la quête", "buy": "Acheter", "sell": "Vendre",
		"tired_talk": "On a déjà beaucoup parlé aujourd'hui. Reviens demain !", "scared": "Aaah ! Un monstre ! Va-t'en !",
		"follow_yes": "D'accord, je te suis !", "follow_no": "Je ne te connais pas assez pour ça.", "stay_ok": "Je rentre au village.",
		"propose_need": "Il faut 80 d'affection et un Anneau d'union.", "propose_yes": "Oui ! Mille fois oui !", "married": "Lié à {0}",
		"gift_thanks": "Merci, c'est adorable !", "no_gift": "Tu n'as rien à offrir.",
		"trader": "Colporteur", "trader_hi": "Des affaires, voyageur ? J'achète ce que la vallée produit.", "elder": "Doyenne Orme",
		"level_up": "Niveau {0} ! PV et attaque augmentés.", "died": "Tu t'es évanoui... Tu perds un peu d'or.",
		"mask_broken": "Ton déguisement est percé !",
		"soul_in": "Ton âme entre dans le corps : {0}", "soul_out": "Ton âme regagne ton corps. La créature est apprivoisée.",
		"soul_forced": "Le corps hôte a cédé ! Ton âme revient brutalement.",
		"soul_need": "Affaiblis d'abord une créature (moins de 35 % de PV) et approche-toi.", "soul_boss": "Ce chef est trop puissant pour être possédé.",
		"cant_here": "Impossible sous cette forme.", "ally_full": "Trop de compagnons : la créature retourne à l'état sauvage.",
		"ally_down": "{0} est hors de combat.", "new_day": "Un nouveau jour se lève sur Brumeval.",
		"new_villager": "{0} s'installe dans ta nouvelle maison !", "harvest": "Récoltes : +{0} baies, +{1} or",
		"gate_locked": "La Crypte des Échos est scellée. Accès réservé au palier Gardien.", "gate_open": "Le sceau reconnaît ton soutien. La crypte s'ouvre.",
		"chest": "Tu trouves la Relique des Échos ! Attaque +5.", "chest_empty": "Le coffre est vide.", "forage": "+1 baie",
		"rest_done": "Tu te reposes jusqu'au matin.", "rest_day": "Il fait jour, inutile de dormir.",
		"vol": "Volume", "shake": "Tremblement d'écran", "diff": "Difficulté", "easy": "Facile", "normal": "Normal", "hard": "Difficile",
		"gold_skin": "Tenue dorée (Lanterne+)", "tier_sim": "Palier Patreon (simulation)",
		"lights": "Lumières dynamiques (nuit)", "eco": "Économie d'énergie (30 i/s)", "touch": "Commandes tactiles",
		"touch_modes": ["Auto", "Activées", "Désactivées"], "perf_sub": "Désactive les lumières sur les petits téléphones.",
		"keys": [["ZQSD / WASD / flèches", "Se déplacer"], ["Espace / J", "Attaquer, couper, casser"], ["E", "Parler, récolter, utiliser"], ["R", "Transfert d'âme / revenir"], ["B", "Construire"], ["I / Tab", "Sac et fabrication"], ["M", "Carte"], ["H", "Potion"], ["Échap", "Pause"], ["Manette", "A attaque · X interagir · Y âme"], ["Écran tactile", "Pouce gauche : bouger · boutons à droite"]],
		"credits_txt": "Brumeval est un prototype original. Pixel art dessiné par le code. Merci aux soutiens Patreon.",
		"pat_t": "Paliers Patreon",
		"pat_how": "Version finale : le joueur relie son compte Patreon (OAuth), le serveur lit son palier et le jeu débloque les bonus.",
		"tiers": [["Voyageur", "Gratuit", "Jeu de base complet"], ["Lanterne", "3 €/mois", "Tenue dorée, statue-lanterne, nom aux crédits"], ["Gardien", "7 €/mois", "Crypte des Échos, masque spectral, builds 1 semaine en avance"], ["Archimage", "15 €/mois", "Familier Luciole (+10 % XP), vote, builds 2 semaines en avance"]],
		"tier_names": ["Voyageur", "Lanterne", "Gardien", "Archimage"],
		"chef_down": "Le Chef gobelin est tombé ! Son camp est en déroute.",
		"map_t": "Carte de Brumeval",
		"map_legend": "Ouest : village · Sud : camp gobelin · Est : forêt · Sud-est : marais · Nord-est : crypte",
		"relic": "Relique des Échos", "affection": "Affection",
	},
	"en": {
		"demo_line": "Original prototype: content and systems are still in development.",
		"tagline": "SOULBEARER OF THE VALLEY",
		"continue": "Continue", "new_game": "New game", "load": "Load", "save": "Save",
		"settings": "Settings", "controls": "Controls", "support": "Support (Patreon)", "credits": "Credits",
		"quit": "Quit", "language": "Language",
		"notes_title": "Patch notes 0.3",
		"notes": ["New sprites, Android build, touch controls", "Masks: that species stops attacking you", "Soul transfer (R) into a weakened creature", "7 buildings, day/night cycle", "Social: chat, gifts, recruit, marriage", "Gamepad support"],
		"support_pitch": "New buildings, creatures and weekly updates. Patreon supporters unlock bonuses.",
		"tier_now": "Active tier: {0}",
		"resume": "Resume", "to_menu": "Main menu", "back": "Back", "close": "Close", "pause": "Paused",
		"slot": "Slot {0}", "auto": "Autosave", "empty": "Empty", "saved": "Game saved.", "loaded": "Game loaded.",
		"lv": "Lv. {0}", "gold": "{0} gold", "day": "Day {0} · {1}",
		"hint": "WASD move · Space attack · E interact · R soul · B build · I bag · M map · H potion",
		"placing": "Placing: E to build · Esc to cancel",
		"quest": "Quest", "quest_done": "Go back to Elder Orme", "all_done": "All quests done. More arrives with updates!",
		"quest_complete": "Quest complete: {0}",
		"masked": "Disguised: {0}", "in_body": "Soul in: {0} (R to return)",
		"inv": "Bag", "equip": "Wear", "unequip": "Remove", "use": "Use", "craft": "Craft", "crafting": "Crafting",
		"crafted": "Crafted: {0}", "need_ws": "Stand near a workshop for these recipes.", "nothing": "Your bag is empty.", "equipment": "Equipment",
		"build": "Build", "build_help": "Pick a building, then place it in front of you.", "blocked": "That spot is blocked.",
		"built": "{0} built!", "not_enough": "Not enough resources.",
		"talk": "Chat", "gift": "Give a gift", "follow": "Come with me", "stay": "Stay in the village",
		"propose": "Propose", "bye": "Goodbye", "claim": "Turn in quest", "buy": "Buy", "sell": "Sell",
		"tired_talk": "We've talked a lot today. Come back tomorrow!", "scared": "Aaah! A monster! Go away!",
		"follow_yes": "Alright, I'll follow you!", "follow_no": "I don't know you well enough for that.", "stay_ok": "I'll head back to the village.",
		"propose_need": "You need 80 affection and a Bond Ring.", "propose_yes": "Yes! A thousand times yes!", "married": "Bonded to {0}",
		"gift_thanks": "Thank you, that's lovely!", "no_gift": "You have nothing to give.",
		"trader": "Peddler", "trader_hi": "Business, traveller? I buy whatever the valley makes.", "elder": "Elder Orme",
		"level_up": "Level {0}! HP and attack increased.", "died": "You fainted... You lose some gold.",
		"mask_broken": "Your disguise is blown!",
		"soul_in": "Your soul enters the body: {0}", "soul_out": "Your soul returns to your body. The creature is tamed.",
		"soul_forced": "The host body gave out! Your soul snaps back.",
		"soul_need": "First weaken a creature (under 35% HP) and get close.", "soul_boss": "This chief is too strong to possess.",
		"cant_here": "Not possible in this form.", "ally_full": "Too many companions: the creature returns to the wild.",
		"ally_down": "{0} is knocked out.", "new_day": "A new day dawns over Brumeval.",
		"new_villager": "{0} moves into your new house!", "harvest": "Harvest: +{0} berries, +{1} gold",
		"gate_locked": "The Crypt of Echoes is sealed. Guardian tier only.", "gate_open": "The seal recognises your support. The crypt opens.",
		"chest": "You found the Relic of Echoes! Attack +5.", "chest_empty": "The chest is empty.", "forage": "+1 berry",
		"rest_done": "You rest until morning.", "rest_day": "It's daytime, no need to sleep.",
		"vol": "Volume", "shake": "Screen shake", "diff": "Difficulty", "easy": "Easy", "normal": "Normal", "hard": "Hard",
		"gold_skin": "Golden outfit (Lantern+)", "tier_sim": "Patreon tier (simulation)",
		"lights": "Dynamic lights (night)", "eco": "Power saving (30 fps)", "touch": "Touch controls",
		"touch_modes": ["Auto", "On", "Off"], "perf_sub": "Turn lights off on small phones.",
		"keys": [["WASD / arrows", "Move"], ["Space / J", "Attack, chop, break"], ["E", "Talk, gather, use"], ["R", "Soul transfer / return"], ["B", "Build"], ["I / Tab", "Bag and crafting"], ["M", "Map"], ["H", "Potion"], ["Esc", "Pause"], ["Gamepad", "A attack · X interact · Y soul"], ["Touch screen", "Left thumb: move · buttons on the right"]],
		"credits_txt": "Brumeval is an original prototype. Pixel art drawn by code. Thanks to our Patreon supporters.",
		"pat_t": "Patreon tiers",
		"pat_how": "Final version: players link their Patreon account (OAuth), the server reads their tier and the game unlocks bonuses.",
		"tiers": [["Traveller", "Free", "Full base game"], ["Lantern", "$3/month", "Golden outfit, lantern statue, name in credits"], ["Guardian", "$7/month", "Crypt of Echoes, spectral mask, builds 1 week early"], ["Archmage", "$15/month", "Firefly familiar (+10% XP), vote, builds 2 weeks early"]],
		"tier_names": ["Traveller", "Lantern", "Guardian", "Archmage"],
		"chef_down": "The Goblin Chief has fallen! The camp is routed.",
		"map_t": "Map of Brumeval",
		"map_legend": "West: village · South: goblin camp · East: forest · South-east: marsh · North-east: crypt",
		"relic": "Relic of Echoes", "affection": "Affection",
	},
}

const NAMES := {
	"fr": {"wood": "Bois", "stone": "Pierre", "berry": "Baies", "meat": "Viande", "crystal": "Cristal", "ear": "Oreille de gobelin", "fang": "Croc", "hide": "Cuir", "ecto": "Ectoplasme", "potion": "Potion", "stew": "Ragoût", "mask_gob": "Masque de gobelin", "mask_wolf": "Masque de loup", "mask_wisp": "Masque de feu-follet", "mask_spectre": "Masque spectral", "ring": "Anneau d'union", "sword": "Épée de fer", "armor": "Armure de cuir", "gold": "or",
		"campfire": "Feu de camp", "farm": "Ferme à baies", "house": "Maison", "workshop": "Atelier", "mill": "Moulin", "tower": "Tour de garde", "statue": "Statue-lanterne",
		"gobelin": "Gobelin", "chef": "Chef gobelin", "loup": "Loup des brumes", "feufollet": "Feu-follet", "spectre": "Spectre"},
	"en": {"wood": "Wood", "stone": "Stone", "berry": "Berries", "meat": "Meat", "crystal": "Crystal", "ear": "Goblin ear", "fang": "Fang", "hide": "Hide", "ecto": "Ectoplasm", "potion": "Potion", "stew": "Stew", "mask_gob": "Goblin mask", "mask_wolf": "Wolf mask", "mask_wisp": "Wisp mask", "mask_spectre": "Spectral mask", "ring": "Bond Ring", "sword": "Iron sword", "armor": "Leather armour", "gold": "gold",
		"campfire": "Campfire", "farm": "Berry farm", "house": "House", "workshop": "Workshop", "mill": "Mill", "tower": "Watchtower", "statue": "Lantern statue",
		"gobelin": "Goblin", "chef": "Goblin chief", "loup": "Mist wolf", "feufollet": "Wisp", "spectre": "Spectre"},
}

const DESC := {
	"fr": {"campfire": "Soigne, point de réveil, repos la nuit.", "farm": "+3 baies chaque matin.", "house": "Un nouvel habitant s'installe.", "workshop": "Masques, armes et anneau.", "mill": "+8 or chaque matin.", "tower": "Tire sur les ennemis proches.", "statue": "Éclaire la nuit. Bonus Lanterne."},
	"en": {"campfire": "Heals, respawn point, rest at night.", "farm": "+3 berries every morning.", "house": "A new villager moves in.", "workshop": "Masks, weapons and the ring.", "mill": "+8 gold every morning.", "tower": "Shoots nearby enemies.", "statue": "Lights the night. Lantern bonus."},
}

const CHAT := {
	"fr": {"low": ["Bonjour, étranger.", "On dit que la brume rend les gens un peu bizarres.", "Fais attention aux gobelins près des tentes, au sud."], "mid": ["Content de te revoir !", "Les loups évitent ceux qui portent leur visage...", "Un atelier changerait la vie du village."], "high": ["Tu illumines mes journées, vraiment.", "Avec toi, la brume me fait moins peur.", "Je te garde toujours un peu de soupe au chaud."]},
	"en": {"low": ["Hello, stranger.", "They say the mist makes people a little odd.", "Watch out for the goblins near the tents, down south."], "mid": ["Good to see you again!", "Wolves avoid those who wear their face...", "A workshop would change village life."], "high": ["You brighten my days, truly.", "With you around, the mist feels less scary.", "I always keep some soup warm for you."]},
}

const QTXT := {
	"fr": [["Du bois pour l'hiver", "Coupe 10 bois."], ["Un foyer", "Construis un Feu de camp (B)."], ["Les pillards", "Vaincs 5 gobelins."], ["Les mains habiles", "Construis un Atelier."], ["Changer de visage", "Obtiens un masque."], ["L'art du Porte-Âme", "Transfère ton âme (R)."], ["Bienvenue", "Construis une Maison."], ["Le chef du camp", "Vaincs le Chef gobelin au sud."], ["Des liens", "Atteins 60 d'affection avec un habitant."], ["Gardien de la vallée", "Atteins le niveau 10."]],
	"en": [["Wood for winter", "Chop 10 wood."], ["A hearth", "Build a Campfire (B)."], ["Raiders", "Defeat 5 goblins."], ["Skilled hands", "Build a Workshop."], ["A new face", "Get a mask."], ["The Soulbearer's art", "Transfer your soul (R)."], ["Welcome", "Build a House."], ["The camp chief", "Defeat the Goblin Chief down south."], ["Bonds", "Reach 60 affection with a villager."], ["Valley guardian", "Reach level 10."]],
}

const ELDER := {
	"fr": ["Te voilà réveillé, Porte-Âme. La brume a emporté la moitié du village. Commence par couper du bois.", "Un feu tient la brume à distance. Construis-en un.", "Les gobelins pillent nos réserves. Chasse-les.", "Avec un atelier, tu pourras fabriquer des masques.", "Trouve ou fabrique un masque. Porte-le et observe.", "Quand une créature faiblit, ton âme peut prendre sa place. Essaie.", "Une maison attirera de nouveaux habitants.", "Leur chef se cache au camp du sud. Abats-le.", "Une vallée, ce sont surtout des gens. Prends le temps de les connaître.", "Deviens assez fort pour protéger Brumeval.", "Tu as fait plus que je n'espérais. Reviens après les prochaines mises à jour !"],
	"en": ["You're awake, Soulbearer. The mist took half the village. Start by chopping some wood.", "A fire keeps the mist at bay. Build one.", "Goblins raid our stores. Drive them off.", "With a workshop you can craft masks.", "Find or craft a mask. Wear it and see what happens.", "When a creature weakens, your soul can take its place. Try it.", "A house will draw new villagers.", "Their chief hides at the southern camp. Bring them down.", "A valley is mostly its people. Take time to know them.", "Grow strong enough to protect Brumeval.", "You've done more than I hoped. Come back after the next updates!"],
}


func t(key: String, args: Array = []) -> Variant:
	var v: Variant = L[Settings.lang].get(key, L["fr"].get(key, key))
	if v is String:
		var s: String = v
		for i in args.size():
			s = s.replace("{%d}" % i, str(args[i]))
		return s
	return v


func nm(key: String) -> String:
	return NAMES[Settings.lang].get(key, key)
