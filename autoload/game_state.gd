extends Node
## Season state (money, lives, upgrades, race order), settings, career save and
## hall of fame.

const START_MONEY := 100_000
const START_LIVES := 3
const LIFE_VALUE := 200_000
const PRIZES := [150_000, 100_000, 50_000, 0]
## Finishing at this position (1-based) or worse costs a life.
const LOSE_LIFE_POSITION := 4
const HOF_PATH := "user://hall_of_fame.cfg"
const CAREER_PATH := "user://career.cfg"
const SETTINGS_PATH := "user://settings.cfg"
const BASE_SIZE := Vector2i(960, 540)

const TEAMS := ["red", "yellow", "blue", "gray"]
const TEAM_COLORS := {
	"red": Color8(228, 56, 40),
	"yellow": Color8(250, 214, 32),
	"blue": Color8(56, 124, 240),
	"gray": Color8(184, 184, 192),
}
const CPU_NAMES := {"red": "SAM", "yellow": "JOHN", "blue": "EARL", "gray": "IVAN"}
const DIFFICULTIES := ["EASY", "NORMAL", "HARD"]

## Speed shop items: [id, label, price, max level, description]
const SHOP_ITEMS := [
	["nitro", "NITRO", 10_000, 99, "One burst of extra speed"],
	["tires", "TIRES", 40_000, 6, "More grip, less sliding"],
	["shocks", "SHOCKS", 60_000, 6, "Softer landings and bumps"],
	["accel", "ACCELERATION", 80_000, 6, "Faster off the line"],
	["speed", "TOP SPEED", 100_000, 6, "Higher maximum speed"],
]

## Remappable driving actions with their default keyboard keys.
const BINDABLE := {
	"steer_left": [KEY_LEFT, KEY_A],
	"steer_right": [KEY_RIGHT, KEY_D],
	"accelerate": [KEY_UP, KEY_W],
	"reverse": [KEY_DOWN, KEY_S],
	"nitro": [KEY_SPACE, KEY_X],
}
const BINDABLE_LABELS := {
	"steer_left": "STEER LEFT", "steer_right": "STEER RIGHT", "accelerate": "ACCELERATE",
	"reverse": "REVERSE", "nitro": "NITRO",
}

var font: FontFile
var theme: Theme

# Settings.
var difficulty := 1
var laps := 4
var music_volume := 0.7
var sfx_volume := 0.9
var fullscreen := false
var key_binds := {}  # action -> physical keycode (primary key)

# Career.
var player_name := "DRIVER"
var player_team := "red"
var money := START_MONEY
var lives := START_LIVES
var points := 0
var race_index := 0
var upgrades := {}
var nitro := 3
var cpu_upgrades := {}
var cpu_nitro := {}
var last_results: Array = []  # [{team, name, position, prize, bonus, is_player, nitro_left}]
var demo_mode := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	theme = UITheme.build(font)
	get_tree().root.theme = theme
	# Controls under plain Nodes don't inherit the window theme: set fallbacks too.
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 16
	load_settings()
	_setup_input()
	apply_settings()
	new_game()


# --- input ------------------------------------------------------------------

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
	_add_action("steer_left", [], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("steer_right", [], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("accelerate", [], [JOY_BUTTON_A], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_action("reverse", [], [JOY_BUTTON_DPAD_DOWN])
	_add_action("nitro", [], [JOY_BUTTON_B, JOY_BUTTON_X])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_add_action("toggle_fullscreen", [KEY_F11])
	for action in BINDABLE:
		_apply_keys(action)


## Keyboard events for a driving action: the user's key (if remapped) or the defaults.
func _apply_keys(action: String) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var keys: Array = [key_binds[action]] if key_binds.has(action) else BINDABLE[action]
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func bind_key(action: String, keycode: int) -> void:
	key_binds[action] = keycode
	_apply_keys(action)
	save_settings()


func reset_keys() -> void:
	key_binds.clear()
	for action in BINDABLE:
		_apply_keys(action)
	save_settings()


func key_label(action: String) -> String:
	var keys: Array = [key_binds[action]] if key_binds.has(action) else BINDABLE[action]
	return " / ".join(keys.map(func(k): return OS.get_keycode_string(k).to_upper()))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		fullscreen = not fullscreen
		apply_settings()
		save_settings()


# --- settings -----------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	difficulty = cfg.get_value("game", "difficulty", difficulty)
	laps = cfg.get_value("game", "laps", laps)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	key_binds = cfg.get_value("input", "keys", {})


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "laps", laps)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("input", "keys", key_binds)
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	Audio.set_volumes(music_volume, sfx_volume)
	if DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("web"):
		# The browser owns the canvas size; only fullscreen can be toggled.
		get_window().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		return
	var w := get_window()
	if fullscreen:
		w.mode = Window.MODE_FULLSCREEN
	else:
		w.mode = Window.MODE_WINDOWED
		# Largest whole-number scale that fits on screen keeps pixels square.
		var usable := DisplayServer.screen_get_usable_rect(w.current_screen).size
		var k := maxi(1, mini((usable.x - 16) / BASE_SIZE.x, (usable.y - 48) / BASE_SIZE.y))
		w.size = BASE_SIZE * k
		w.move_to_center()


## CPU skill offset and rubber-band strength for the chosen difficulty.
func ai_skill_offset() -> float:
	return [-0.06, 0.0, 0.05][difficulty]


func rubber_band_scale() -> float:
	return [0.5, 1.0, 1.3][difficulty]


# --- season -----------------------------------------------------------------

func new_game() -> void:
	money = START_MONEY
	lives = START_LIVES
	points = 0
	race_index = 0
	nitro = 3
	upgrades = {"tires": 0, "shocks": 0, "accel": 0, "speed": 0}
	cpu_upgrades.clear()
	cpu_nitro.clear()
	for t in TEAMS:
		cpu_upgrades[t] = {"tires": 0, "shocks": 0, "accel": 0, "speed": 0}
		cpu_nitro[t] = 2


## Track id and direction for the current race: all tracks forward, then reversed.
func current_track() -> Dictionary:
	var n := Track.track_count()
	var i := race_index % (n * 2)
	return {"id": i % n, "reverse": i >= n}


## 0.0 at the first race, grows every race (CPU skill).
func difficulty_ramp() -> float:
	return minf(1.0, race_index / 32.0)


func level_of(item: String) -> int:
	if item == "nitro":
		return nitro
	return upgrades.get(item, 0)


func item_info(item: String) -> Array:
	for it in SHOP_ITEMS:
		if it[0] == item:
			return it
	return []


## Tries to buy one level. Trades a life for cash if needed (keeps the last one).
## Returns "ok", "max", "broke" or "life" (bought by cashing in a life).
func buy(item: String) -> String:
	var info := item_info(item)
	var price: int = info[2]
	if level_of(item) >= info[3]:
		return "max"
	var result := "ok"
	if money < price:
		if lives > 1:
			lives -= 1
			money += LIFE_VALUE
			result = "life"
		else:
			return "broke"
	money -= price
	if item == "nitro":
		nitro += 1
	else:
		upgrades[item] += 1
	return result


## Called at the end of a race. Returns whether the player lost a life.
func apply_results(results: Array) -> bool:
	last_results = results
	var lost := false
	for r in results:
		if r.is_player:
			money += r.prize + r.bonus
			points += (r.prize + r.bonus) / 1000
			nitro = r.nitro_left
			if r.position >= LOSE_LIFE_POSITION:
				lives -= 1
				lost = true
	_upgrade_cpus()
	race_index += 1
	if lives > 0:
		save_career()
	else:
		delete_career()
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


# --- career save ------------------------------------------------------------

func has_career() -> bool:
	return FileAccess.file_exists(CAREER_PATH)


func save_career() -> void:
	var cfg := ConfigFile.new()
	for key in ["player_name", "money", "lives", "points", "race_index", "upgrades", "nitro", "cpu_upgrades", "cpu_nitro"]:
		cfg.set_value("career", key, get(key))
	cfg.save(CAREER_PATH)


func load_career() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CAREER_PATH) != OK:
		return false
	new_game()
	for key in cfg.get_section_keys("career"):
		set(key, cfg.get_value("career", key))
	return true


func delete_career() -> void:
	if has_career():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAREER_PATH))


# --- hall of fame -------------------------------------------------------------

func load_hof() -> Array:
	var cfg := ConfigFile.new()
	var list: Array = []
	if cfg.load(HOF_PATH) == OK:
		list = cfg.get_value("hof", "entries", [])
	if list.is_empty():
		list = [
			{"name": "IVAN", "points": 900, "races": 12},
			{"name": "SAM", "points": 700, "races": 10},
			{"name": "JOHN", "points": 500, "races": 8},
			{"name": "EARL", "points": 350, "races": 6},
			{"name": "MICKEY", "points": 200, "races": 4},
		]
	return list


## Adds an entry, returns its rank (0-based) or -1 if it didn't make the top 10.
func add_hof(entry_name: String, entry_points: int, races: int) -> int:
	var list := load_hof()
	var entry := {"name": entry_name, "points": entry_points, "races": races}
	list.append(entry)
	list.sort_custom(func(a, b): return a.points > b.points)
	list = list.slice(0, 10)
	var cfg := ConfigFile.new()
	cfg.set_value("hof", "entries", list)
	cfg.save(HOF_PATH)
	return list.find(entry)
