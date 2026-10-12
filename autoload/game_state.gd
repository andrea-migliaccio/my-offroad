extends Node
## Season state: money, credits, upgrades, race order, hall of fame.

const LAPS := 4
const START_MONEY := 100_000
const START_CREDITS := 3
const CREDIT_VALUE := 200_000
const PRIZES := [150_000, 100_000, 50_000, 0]
## Finishing at this position (1-based) or worse costs a credit.
const LOSE_CREDIT_POSITION := 4
const HOF_PATH := "user://hall_of_fame.cfg"

const TEAMS := ["red", "yellow", "blue", "gray"]
const TEAM_COLORS := {
	"red": Color8(228, 56, 40),
	"yellow": Color8(250, 214, 32),
	"blue": Color8(56, 124, 240),
	"gray": Color8(184, 184, 192),
}
const CPU_NAMES := {"red": "SAM", "yellow": "JOHN", "blue": "EARL", "gray": "IVAN"}

## Speed shop items: id -> [label, price, max level]
const SHOP_ITEMS := [
	["nitro", "NITRO", 10_000, 99],
	["tires", "TIRES", 40_000, 6],
	["shocks", "SHOCKS", 60_000, 6],
	["accel", "ACCEL", 80_000, 6],
	["speed", "TOP SPEED", 100_000, 6],
]

var font: FontFile
var theme: Theme

var player_name := "YOU"
var player_team := "red"
var money := START_MONEY
var credits := START_CREDITS
var points := 0
var race_index := 0
var upgrades := {}
var nitro := 3
var cpu_upgrades := {}
var cpu_nitro := {}
var last_results: Array = []  # [{team, name, position, prize, is_player}]
var demo_mode := false


func _ready() -> void:
	_setup_input()
	_setup_theme()
	new_game()


func _setup_theme() -> void:
	font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 8
	get_tree().root.theme = theme


func _add_action(action: String, keys: Array, buttons: Array = [], axis := -1, axis_dir := 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = axis_dir
		InputMap.action_add_event(action, jm)


func _setup_input() -> void:
	_add_action("steer_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("steer_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("accelerate", [KEY_UP, KEY_Z, KEY_W], [JOY_BUTTON_A], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_action("reverse", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_add_action("nitro", [KEY_X, KEY_SPACE], [JOY_BUTTON_B, JOY_BUTTON_X])
	_add_action("start", [KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_START])
	_add_action("confirm", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_X], [JOY_BUTTON_A, JOY_BUTTON_START])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_BACK])
	_add_action("toggle_crt", [KEY_F2])
	_add_action("toggle_fullscreen", [KEY_F11])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func new_game() -> void:
	money = START_MONEY
	credits = START_CREDITS
	points = 0
	race_index = 0
	nitro = 3
	upgrades = {"tires": 0, "shocks": 0, "accel": 0, "speed": 0}
	cpu_upgrades.clear()
	cpu_nitro.clear()
	for t in TEAMS:
		cpu_upgrades[t] = {"tires": 0, "shocks": 0, "accel": 0, "speed": 0}
		cpu_nitro[t] = 2


## Track id and direction for the current race: 8 tracks forward, then reversed, repeat.
func current_track() -> Dictionary:
	var i := race_index % 16
	return {"id": i % 8, "reverse": i >= 8}


## 0.0 at the first race, grows every race (CPU skill).
func difficulty() -> float:
	return minf(1.0, race_index / 24.0)


func level_of(item: String) -> int:
	if item == "nitro":
		return nitro
	return upgrades.get(item, 0)


func item_info(item: String) -> Array:
	for it in SHOP_ITEMS:
		if it[0] == item:
			return it
	return []


## Tries to buy one level. Trades a credit for cash if needed (keeps the last one).
## Returns "ok", "max", "broke" or "credit" (bought by cashing in a credit).
func buy(item: String) -> String:
	var info := item_info(item)
	var price: int = info[2]
	if level_of(item) >= info[3]:
		return "max"
	var result := "ok"
	if money < price:
		if credits > 1:
			credits -= 1
			money += CREDIT_VALUE
			result = "credit"
		else:
			return "broke"
	money -= price
	if item == "nitro":
		nitro += 1
	else:
		upgrades[item] += 1
	return result


## Called by the race at the end. Returns whether the player lost a credit.
func apply_results(results: Array) -> bool:
	last_results = results
	var lost := false
	for r in results:
		if r.is_player:
			money += r.prize + r.bonus
			points += (r.prize + r.bonus) / 1000
			nitro = r.nitro_left
			if r.position >= LOSE_CREDIT_POSITION:
				credits -= 1
				lost = true
	_upgrade_cpus()
	race_index += 1
	return lost


func _upgrade_cpus() -> void:
	# CPU trucks improve over the season, Ivan a bit faster.
	for t in TEAMS:
		if t == player_team:
			continue
		var ups: Dictionary = cpu_upgrades[t]
		var steps := 2 if t == "gray" else 1
		for s in steps:
			var keys := ["tires", "shocks", "accel", "speed"]
			var k: String = keys[(race_index + s + TEAMS.find(t)) % 4]
			ups[k] = mini(6, ups[k] + 1)
		cpu_nitro[t] = mini(6, 2 + race_index / 3)


func continue_game() -> void:
	credits = START_CREDITS
	money = START_MONEY


# --- Hall of fame ------------------------------------------------------------

func load_hof() -> Array:
	var cfg := ConfigFile.new()
	var list: Array = []
	if cfg.load(HOF_PATH) == OK:
		list = cfg.get_value("hof", "entries", [])
	if list.is_empty():
		list = [
			{"name": "IVN", "points": 900, "races": 12},
			{"name": "SAM", "points": 700, "races": 10},
			{"name": "JHN", "points": 500, "races": 8},
			{"name": "EAR", "points": 350, "races": 6},
			{"name": "MIK", "points": 200, "races": 4},
		]
	return list


func add_hof(entry_name: String, entry_points: int, races: int) -> int:
	var list := load_hof()
	list.append({"name": entry_name, "points": entry_points, "races": races})
	list.sort_custom(func(a, b): return a.points > b.points)
	list = list.slice(0, 10)
	var cfg := ConfigFile.new()
	cfg.set_value("hof", "entries", list)
	cfg.save(HOF_PATH)
	for i in list.size():
		if list[i].name == entry_name and list[i].points == entry_points:
			return i
	return -1
