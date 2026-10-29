class_name Defs
## Données de jeu : créatures, bâtiments, recettes, zones. Équilibrage ici, sans toucher au code.

const TS := 16
const MW := 72
const MH := 54
const DAYLEN := 240.0
const VX := 18
const VY := 27

enum T { GRASS, PATH, WATER, TREE, ROCK, FLOWER, STUMP, BRIDGE, WALL, GATE, CRYPT }

const MON := {
	"gobelin": {"hp": 18, "atk": 3, "spd": 38, "xp": 8, "gold": [1, 4], "aggro": 70, "drops": [["ear", 0.6], ["mask_gob", 0.05]]},
	"chef": {"hp": 150, "atk": 8, "spd": 34, "xp": 140, "gold": [60, 80], "aggro": 95, "boss": true, "drops": [["mask_gob", 1.0], ["crystal", 1.0]]},
	"loup": {"hp": 30, "atk": 5, "spd": 60, "xp": 16, "gold": [0, 2], "aggro": 90, "drops": [["fang", 0.5], ["hide", 0.55], ["meat", 0.6], ["mask_wolf", 0.04]]},
	"feufollet": {"hp": 26, "atk": 7, "spd": 42, "xp": 26, "gold": [2, 6], "aggro": 80, "fly": true, "drops": [["ecto", 0.6], ["crystal", 0.2], ["mask_wisp", 0.04]]},
	"spectre": {"hp": 60, "atk": 11, "spd": 40, "xp": 50, "gold": [8, 15], "aggro": 90, "fly": true, "drops": [["crystal", 0.5], ["mask_spectre", 0.1]]},
}
const FACTION := {"gobelin": "gobelin", "chef": "gobelin", "loup": "loup", "feufollet": "feufollet", "spectre": "spectre"}
const MASKF := {"mask_gob": "gobelin", "mask_wolf": "loup", "mask_wisp": "feufollet", "mask_spectre": "spectre"}
const MASKC := {"mask_gob": Color("#6c9a3a"), "mask_wolf": Color("#8a8c94"), "mask_wisp": Color("#7cd0f0"), "mask_spectre": Color("#b48ae6")}

const BLD := {
	"campfire": {"w": 1, "h": 1, "cost": {"wood": 5}},
	"farm": {"w": 2, "h": 2, "cost": {"wood": 8}},
	"house": {"w": 2, "h": 2, "cost": {"wood": 20, "stone": 10}},
	"workshop": {"w": 2, "h": 2, "cost": {"wood": 10, "stone": 10}},
	"mill": {"w": 2, "h": 2, "cost": {"wood": 15, "stone": 5}},
	"tower": {"w": 1, "h": 2, "cost": {"wood": 10, "stone": 15}},
	"statue": {"w": 1, "h": 2, "cost": {"stone": 8}, "tier": 1},
}

const RECIPES := [
	{"id": "potion", "need": {"berry": 3}},
	{"id": "stew", "need": {"meat": 1, "berry": 2}},
	{"id": "sword", "need": {"stone": 6, "wood": 4}, "ws": true, "once": true},
	{"id": "armor", "need": {"hide": 4}, "ws": true, "once": true},
	{"id": "mask_gob", "need": {"ear": 3}, "ws": true},
	{"id": "mask_wolf", "need": {"fang": 3, "hide": 1}, "ws": true},
	{"id": "mask_wisp", "need": {"ecto": 3}, "ws": true},
	{"id": "ring", "need": {"crystal": 2, "gold": 30}, "ws": true},
]

const GIFTS := {"berry": 4, "meat": 6, "crystal": 15, "ecto": 8, "stew": 12, "fang": 3}
const SELL := {"wood": 1, "stone": 1, "hide": 4, "fang": 3, "ecto": 5, "ear": 2, "meat": 2, "crystal": 12}
const VNAMES := ["Aubin", "Clémence", "Yaël", "Noor", "Basile", "Inès", "Tiago", "Maëlle", "Odon", "Sacha", "Lou", "Elio"]
const VCOL := [["#b5523b", "#3b2a1e"], ["#3b74b5", "#c9a24a"], ["#6a9a4a", "#1e1a17"], ["#9a4aa0", "#d8d0c0"], ["#c08a3a", "#5a2e1a"], ["#3a9a94", "#2a2a3a"]]

## a = rectangle de tuiles [x0, y0, x1, y1]
const ZONES := [
	{"kind": "gobelin", "cap": 7, "lv": [1, 3], "a": [4, 4, 36, 51]},
	{"kind": "gobelin", "cap": 4, "lv": [3, 4], "a": [26, 40, 34, 48]},
	{"kind": "loup", "cap": 8, "lv": [3, 6], "a": [42, 13, 70, 32]},
	{"kind": "feufollet", "cap": 7, "lv": [6, 9], "a": [40, 34, 70, 51]},
	{"kind": "spectre", "cap": 5, "lv": [9, 12], "a": [60, 2, 69, 8]},
]

## d = progression comptée depuis le début de la quête
const QUESTS := [
	{"stat": "wood", "d": true, "goal": 10, "rw": {"gold": 20, "xp": 30}},
	{"stat": "b_campfire", "goal": 1, "rw": {"gold": 10, "xp": 30, "potion": 1}},
	{"stat": "k_gobelin", "d": true, "goal": 5, "rw": {"gold": 30, "xp": 50}},
	{"stat": "b_workshop", "goal": 1, "rw": {"gold": 20, "xp": 60}},
	{"stat": "masks", "goal": 1, "rw": {"gold": 25, "xp": 60}},
	{"stat": "souls", "d": true, "goal": 1, "rw": {"gold": 30, "xp": 80}},
	{"stat": "b_house", "goal": 1, "rw": {"gold": 30, "xp": 80}},
	{"stat": "k_chef", "d": true, "goal": 1, "rw": {"gold": 80, "xp": 150, "crystal": 2}},
	{"stat": "best_aff", "goal": 60, "rw": {"gold": 40, "xp": 120}},
	{"stat": "lvl", "goal": 10, "rw": {"gold": 100, "crystal": 3}},
]


static func biome(x: int, y: int) -> String:
	if x >= 58 and y <= 11:
		return "crypt"
	if x > 40 and y < 33:
		return "forest"
	if x > 38 and y >= 33:
		return "marsh"
	return "plain"
