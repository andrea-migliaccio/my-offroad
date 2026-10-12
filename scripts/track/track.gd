class_name Track
extends RefCounted
## A single-screen track built at runtime from assets/tracks.json.
##
## Ground coordinates are screen pixels (320x240). Every pixel stores the nearest
## centerline sample, height and surface, so physics and AI query plain arrays.
## The background is rendered as a heightfield seen from a 3/4 view: a pixel of
## height h is drawn h pixels higher, with darker front faces below raised areas.

enum Surface { NONE, DIRT, MUD, WATER, BANK, INFIELD, WALL, STANDS, TIRES }

const W := 320
const H := 240
const DS := 2.0
const HALF_WIDTH := 15.0
const BANK_WIDTH := 4.0
const BANK_HEIGHT := 4.0
const INFIELD_HEIGHT := 2.0
const OUTER_WALL_HEIGHT := 6.0
const STANDS_BOTTOM := 30
const FIELD_TOP := 34
const FIT_RECT := Rect2(24, 55, 272, 158)

const PAL := {
	Surface.DIRT: [Color8(120, 72, 36), Color8(168, 104, 52), Color8(194, 128, 68), Color8(220, 162, 98)],
	Surface.MUD: [Color8(44, 28, 14), Color8(66, 44, 24), Color8(86, 58, 32), Color8(108, 74, 42)],
	Surface.WATER: [Color8(24, 56, 120), Color8(40, 88, 168), Color8(72, 128, 208), Color8(150, 190, 240)],
	Surface.BANK: [Color8(146, 106, 36), Color8(206, 166, 66), Color8(232, 198, 98), Color8(250, 226, 140)],
	Surface.INFIELD: [Color8(54, 38, 24), Color8(78, 56, 34), Color8(98, 72, 44), Color8(120, 90, 56)],
	Surface.TIRES: [Color8(14, 14, 16), Color8(34, 34, 38), Color8(58, 58, 64), Color8(96, 96, 104)],
	Surface.WALL: [Color8(80, 80, 88), Color8(124, 124, 132), Color8(156, 156, 164), Color8(188, 188, 196)],
}

static var _json_cache: Array = []

var name := ""
var reverse := false
var samples := PackedVector2Array()
var tangents := PackedVector2Array()
var fwd_s := PackedFloat32Array()  # forward-direction arc length of each sample
var length := 0.0
var features: Array = []

var near_idx := PackedInt32Array()
var dist := PackedFloat32Array()
var lateral := PackedFloat32Array()
var height := PackedFloat32Array()
var surface := PackedByteArray()

var background: ImageTexture
var crowd_frames: Array[ImageTexture] = []


static func track_count() -> int:
	return _load_json().size()


static func _load_json() -> Array:
	if _json_cache.is_empty():
		var f := FileAccess.open("res://assets/tracks.json", FileAccess.READ)
		_json_cache = JSON.parse_string(f.get_as_text()).tracks
	return _json_cache


static func build(id: int, is_reverse: bool) -> Track:
	var t := Track.new()
	t._build(_load_json()[id], is_reverse)
	return t


func _build(def: Dictionary, is_reverse: bool) -> void:
	name = def.name
	reverse = is_reverse
	features = def.features
	_build_centerline(def)
	_build_fields()
	_render()


# --- centerline -------------------------------------------------------------

func _build_centerline(def: Dictionary) -> void:
	var ctrl := PackedVector2Array()
	for p in def.points:
		ctrl.append(Vector2(p[0], p[1]))
	# Catmull-Rom through control points.
	var dense := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for s in 24:
			var t := s / 24.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	var pts := _resample(dense, DS)
	# Soften the sharpest corners a little.
	for pass_i in 3:
		var sm := PackedVector2Array()
		sm.resize(pts.size())
		var m := pts.size()
		for i in m:
			var acc := Vector2.ZERO
			for k in range(-3, 4):
				acc += pts[(i + k + m) % m]
			sm[i] = acc / 7.0
		pts = sm
	pts = _fit(_resample(pts, DS))
	var m := pts.size()
	length = m * DS
	var fs := PackedFloat32Array()
	fs.resize(m)
	for i in m:
		fs[i] = i * DS
	# Start line: rotate so index 0 sits on the start line.
	var start := int(def.start_t * m) % m
	if is_reverse_needed():
		pts.reverse()
		fs.reverse()
		start = m - 1 - start
	samples.resize(m)
	fwd_s.resize(m)
	for i in m:
		samples[i] = pts[(i + start) % m]
		fwd_s[i] = fs[(i + start) % m]
	tangents.resize(m)
	for i in m:
		tangents[i] = (samples[(i + 1) % m] - samples[(i - 1 + m) % m]).normalized()


func is_reverse_needed() -> bool:
	return reverse


## Shrinks the loop (per axis) if it does not fit inside FIT_RECT.
static func _fit(pts: PackedVector2Array) -> PackedVector2Array:
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var out := PackedVector2Array()
	for p in pts:
		var q := p
		if lo.x < FIT_RECT.position.x or hi.x > FIT_RECT.end.x:
			q.x = remap(p.x, lo.x, hi.x, maxf(lo.x, FIT_RECT.position.x), minf(hi.x, FIT_RECT.end.x))
		if lo.y < FIT_RECT.position.y or hi.y > FIT_RECT.end.y:
			q.y = remap(p.y, lo.y, hi.y, maxf(lo.y, FIT_RECT.position.y), minf(hi.y, FIT_RECT.end.y))
		out.append(q)
	return out


static func _resample(poly: PackedVector2Array, ds: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var total := 0.0
	var n := poly.size()
	for i in n:
		total += poly[i].distance_to(poly[(i + 1) % n])
	var count := int(round(total / ds))
	var step := total / count
	var seg := 0
	var seg_start := 0.0
	var seg_len := poly[0].distance_to(poly[1 % n])
	for k in count:
		var target := k * step
		while seg_start + seg_len < target and seg < n - 1:
			seg_start += seg_len
			seg += 1
			seg_len = poly[seg].distance_to(poly[(seg + 1) % n])
		var u := 0.0 if seg_len <= 0.0 else (target - seg_start) / seg_len
		out.append(poly[seg].lerp(poly[(seg + 1) % n], u))
	return out


# --- fields -----------------------------------------------------------------

func _build_fields() -> void:
	var size := W * H
	near_idx.resize(size)
	near_idx.fill(-1)
	dist.resize(size)
	dist.fill(1e9)
	lateral.resize(size)
	lateral.fill(0.0)
	var r := HALF_WIDTH + BANK_WIDTH + 2.0
	var ri := int(ceil(r))
	var m := samples.size()
	for i in m:
		var p := samples[i]
		var nrm := Vector2(-tangents[i].y, tangents[i].x)
		var cx := int(p.x)
		var cy := int(p.y)
		for y in range(maxi(0, cy - ri), mini(H, cy + ri + 1)):
			var row := y * W
			for x in range(maxi(0, cx - ri), mini(W, cx + ri + 1)):
				var d := Vector2(x + 0.5, y + 0.5) - p
				var dl := d.length()
				if dl < r and dl < dist[row + x]:
					dist[row + x] = dl
					near_idx[row + x] = i
					lateral[row + x] = d.dot(nrm)

	height.resize(size)
	surface.resize(size)
	for y in H:
		for x in W:
			var k := y * W + x
			var s := Surface.INFIELD
			var h := INFIELD_HEIGHT
			if y < STANDS_BOTTOM:
				s = Surface.STANDS
				h = 0.0
			elif y < FIELD_TOP:
				s = Surface.WALL
				h = 0.0
			elif x < 4 or x >= W - 4 or y >= H - 4:
				s = Surface.WALL
				h = OUTER_WALL_HEIGHT
			elif near_idx[k] >= 0:
				var i := near_idx[k]
				var d := dist[k]
				if d <= HALF_WIDTH:
					s = Surface.DIRT
					h = 0.0
					for f in features:
						var res := _feature(f, fwd_s[i], lateral[k])
						h += res.x
						if res.y > 0.0:
							s = Surface.MUD if f.type == "mud" else Surface.WATER
				elif d <= HALF_WIDTH + BANK_WIDTH:
					s = Surface.BANK
					var base := 0.0
					for f in features:
						if f.type == "jump" or f.type == "hill":
							base += _feature(f, fwd_s[i], 0.0).x
					h = BANK_HEIGHT + base * 0.6
			if s == Surface.INFIELD and near_idx[k] < 0:
				var stack := _tire_stack(x, y)
				if stack > 0.0:
					s = Surface.TIRES
					h += stack
			height[k] = h
			surface[k] = s


## Decorative stacks of tyres scattered over the infield (height, 0 if none).
func _tire_stack(x: int, y: int) -> float:
	const CELL := 26
	var cx := x / CELL
	var cy := y / CELL
	var hsh := _hash(cx + 101, cy + 37)
	if hsh % 3 != 0:
		return 0.0
	var c := Vector2(cx * CELL + 6 + hsh % (CELL - 12), cy * CELL + 6 + (hsh >> 8) % (CELL - 12))
	var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
	if d > 3.6:
		return 0.0
	# Whole stack must sit well away from the track.
	for o in [Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)]:
		var q: Vector2 = c + o
		if q.x < 6 or q.y < FIELD_TOP + 4 or q.x > W - 6 or q.y > H - 8 or near_idx[int(q.y) * W + int(q.x)] >= 0:
			return 0.0
	return 4.0 + 1.5 * sqrt(maxf(0.0, 1.0 - d * d / 13.0))


## Returns Vector2(height, is_inside_area) of a feature at forward arc length fs.
func _feature(f: Dictionary, fs: float, lat: float) -> Vector2:
	var center: float = f.t * length
	var delta := fposmod(fs - center + length * 0.5, length) - length * 0.5
	var half: float = f.get("len", 30.0) * 0.5
	var u := delta / half
	if absf(u) >= 1.0:
		return Vector2.ZERO
	match f.type:
		"jump":
			return Vector2(f.h * (1.0 - absf(u)), 0.0)
		"hill":
			return Vector2(f.h * 0.5 * (1.0 + cos(PI * u)), 0.0)
		"bumps":
			var edge := clampf((1.0 - absf(u)) * 4.0, 0.0, 1.0)
			return Vector2(f.h * 0.5 * (1.0 - cos(TAU * delta / 10.0)) * edge, 0.0)
		"mud", "water":
			var e := u * u + pow(lat / (HALF_WIDTH * 0.85), 2.0)
			if e < 1.0:
				var depth := -1.5 if f.type == "water" else -0.6
				return Vector2(depth * (1.0 - e), 1.0)
	return Vector2.ZERO


# --- queries ----------------------------------------------------------------

static func _idx(p: Vector2) -> int:
	var x := clampi(int(p.x), 0, W - 1)
	var y := clampi(int(p.y), 0, H - 1)
	return y * W + x


func surface_at(p: Vector2) -> int:
	return surface[_idx(p)]


func nearest_sample(p: Vector2) -> int:
	return near_idx[_idx(p)]


func height_at(p: Vector2) -> float:
	var fx := clampf(p.x - 0.5, 0.0, W - 1.001)
	var fy := clampf(p.y - 0.5, 0.0, H - 1.001)
	var x0 := int(fx)
	var y0 := int(fy)
	var tx := fx - x0
	var ty := fy - y0
	var k := y0 * W + x0
	var a := lerpf(height[k], height[k + 1], tx)
	var b := lerpf(height[k + W], height[k + W + 1], tx)
	return lerpf(a, b, ty)


## Arc length from the start line of the nearest centerline sample, or -1 off track.
func progress_at(p: Vector2) -> float:
	var i := nearest_sample(p)
	return -1.0 if i < 0 else i * DS


func sample_at_s(s: float) -> Vector2:
	var m := samples.size()
	var f := fposmod(s, length) / DS
	var i := int(f) % m
	return samples[i].lerp(samples[(i + 1) % m], f - int(f))


func tangent_at_s(s: float) -> Vector2:
	var m := samples.size()
	return tangents[int(fposmod(s, length) / DS) % m]


## Pushes a point of radius r back inside the track. Returns the wall normal
## (pointing back into the track) or Vector2.ZERO when no correction was needed.
func constrain(p: Vector2, r: float, hint_idx: int) -> Array:
	var i := nearest_sample(p)
	if i < 0:
		i = hint_idx
	if i < 0:
		return [p, Vector2.ZERO]
	# Refine nearest sample locally (handles positions outside the stamped band).
	var m := samples.size()
	var best := i
	var best_d := p.distance_squared_to(samples[i])
	for k in range(-6, 7):
		var j := (i + k + m) % m
		var dd := p.distance_squared_to(samples[j])
		if dd < best_d:
			best_d = dd
			best = j
	var c := samples[best]
	var d := sqrt(best_d)
	var limit := HALF_WIDTH - r
	if d <= limit:
		return [p, Vector2.ZERO]
	var n := (p - c) / maxf(d, 0.001)
	return [c + n * limit, -n]


# --- rendering --------------------------------------------------------------

static func _hash(x: int, y: int) -> int:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


func _tone(k: int, x: int, y: int) -> int:
	var hx := height[k + 1] - height[k - 1] if x > 0 and x < W - 1 else 0.0
	var hy := height[k + W] - height[k - W] if y > 0 and y < H - 1 else 0.0
	var shade := (hx + hy) * 0.9
	var t := 1
	if shade > 0.35:
		t = 2
	if shade > 1.4:
		t = 3
	if shade < -0.35:
		t = 0
	return t


func _base_color(k: int, x: int, y: int) -> Color:
	var s := surface[k]
	var t := _tone(k, x, y)
	var noise := _hash(x, y) % 16
	match s:
		Surface.DIRT:
			if noise == 0 and t > 0:
				t -= 1
			elif noise == 1 and t < 3:
				t += 1
			var i := near_idx[k]
			if i <= 1 or i >= samples.size() - 1:
				var checker := (int((lateral[k] + 16.0) / 3.0) + (1 if i <= 0 else 0)) % 2
				return Color8(240, 240, 240) if checker == 0 else Color8(24, 24, 24)
			return PAL[s][t]
		Surface.MUD:
			if noise < 2:
				return PAL[s][mini(3, t + 1)]
			return PAL[s][t]
		Surface.WATER:
			var ripple := (int(fwd_s[near_idx[k]] / 3.0) + int(lateral[k] / 2.0)) % 5 == 0
			return PAL[s][3] if ripple and noise < 6 else PAL[s][mini(t + 1, 2)]
		Surface.BANK:
			# Hay bales: dark seam every 7px along the track and on the outer edge.
			var along := int(fwd_s[near_idx[k]] / 7.0)
			var seam := fmod(fwd_s[near_idx[k]], 7.0) < 1.0 or dist[k] > HALF_WIDTH + BANK_WIDTH - 0.8
			if seam:
				return PAL[s][0]
			return PAL[s][clampi(t + (along % 2), 0, 3)]
		Surface.INFIELD:
			if noise < 2:
				t = maxi(0, t - 1)
			elif noise == 2:
				t = mini(3, t + 1)
			return PAL[s][t]
		Surface.TIRES:
			# Concentric rings read as stacked tyres.
			return PAL[s][clampi(t + (1 if int(height[k] * 2.0) % 2 == 0 else 0), 0, 3)]
		Surface.WALL:
			if y >= STANDS_BOTTOM and y < FIELD_TOP:
				# Advertising boards along the back wall.
				var board := (x / 40) % 4
				var cols := [Color8(200, 30, 30), Color8(240, 240, 240), Color8(30, 60, 200), Color8(240, 200, 20)]
				if y == STANDS_BOTTOM or y == FIELD_TOP - 1 or x % 40 == 0:
					return Color8(30, 30, 34)
				var c: Color = cols[board]
				return c if (x + y) % 7 != 0 else c.darkened(0.3)
			return PAL[s][t]
	return Color.BLACK


func _render() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color8(16, 12, 10))
	_render_stands(img, 0)
	for y in range(STANDS_BOTTOM, H):
		for x in W:
			var k := y * W + x
			var h := height[k]
			var sy := y - int(round(h))
			var top := _base_color(k, x, y)
			if sy >= STANDS_BOTTOM - 6:
				img.set_pixel(x, clampi(sy, 0, H - 1), top)
			# Front face down to where the next row (nearer to the viewer) starts.
			var next_h := height[k + W] if y < H - 1 else 0.0
			var face_bottom := (y + 1) - int(round(next_h))
			var face_col := top.darkened(0.45)
			for fy in range(sy + 1, mini(face_bottom, H)):
				if fy >= STANDS_BOTTOM:
					img.set_pixel(x, fy, face_col)
	background = ImageTexture.create_from_image(img)
	for f in 2:
		var crowd := Image.create(W, STANDS_BOTTOM, false, Image.FORMAT_RGBA8)
		_render_stands(crowd, f)
		crowd_frames.append(ImageTexture.create_from_image(crowd))


func _render_stands(img: Image, frame: int) -> void:
	var people := [Color8(230, 60, 50), Color8(240, 220, 60), Color8(60, 120, 230), Color8(240, 240, 240),
		Color8(80, 200, 90), Color8(240, 150, 60), Color8(200, 120, 200)]
	var skin := [Color8(232, 176, 128), Color8(176, 116, 72), Color8(120, 76, 48)]
	for y in STANDS_BOTTOM:
		for x in W:
			var row := y / 5
			var in_row := y % 5
			var c := Color8(70, 70, 80) if in_row < 4 else Color8(40, 40, 48)
			if y >= 20:
				var seat := (x + row * 2) / 3
				var hsh := _hash(seat, row)
				if hsh % 7 != 0:
					var bob := 1 if (hsh % 3 == 0 and frame == 1) else 0
					var py := in_row + bob
					if py <= 1:
						c = skin[hsh % 3]
					elif py <= 3:
						c = people[(hsh >> 4) % people.size()]
					if frame == 1 and hsh % 11 == 0 and in_row == 0:
						c = skin[hsh % 3]  # arms up
			else:
				c = Color8(30, 30, 40) if y % 2 == 0 else Color8(36, 36, 46)
			img.set_pixel(x, y, c)
