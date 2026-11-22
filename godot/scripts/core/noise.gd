class_name PNoise
## noise.js, bit-for-bit: mulberry32, hash2, seeded 2D simplex, fbm, ridged and the small maths helpers.
## JS int32/uint32 maths is kept as uint32 bit patterns in GDScript's 64-bit ints (& 0xffffffff after every step).

const M32 := 0xffffffff
const GRAD := [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
static var F2 := 0.5 * (sqrt(3.0) - 1.0)
static var G2 := (3.0 - sqrt(3.0)) / 6.0

## Math.imul as uint32 bits (no 64-bit overflow: split the multiplier in 16-bit halves).
static func imul(a: int, b: int) -> int:
	a &= M32; b &= M32
	var lo := ((a & 0xffff) * b) & M32
	var hi := ((((a >> 16) & 0xffff) * b) & 0xffff) << 16
	return (lo + hi) & M32

## Stable integer hash of grid coordinates + seed (uint32).
static func hash2(x: int, z: int, seed: int = 0) -> int:
	var h := imul(x, 374761393) ^ imul(z, 668265263) ^ imul(seed, 2246822519)
	h = imul(h ^ (h >> 13), 1274126177)
	return (h ^ (h >> 16)) & M32

static func smoothstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func fbm(n: Simplex, x: float, y: float, octaves: int) -> float:
	var sum := 0.0; var amp := 1.0; var freq := 1.0; var norm := 0.0
	for o in octaves:
		sum += amp * n.at(x * freq, y * freq)
		norm += amp; amp *= 0.5; freq *= 2.0
	return sum / norm

## Ridged multifractal in 0..1: sharp crests for mountains.
static func ridged(n: Simplex, x: float, y: float, octaves: int) -> float:
	var sum := 0.0; var amp := 1.0; var freq := 1.0; var norm := 0.0
	for o in octaves:
		var v := 1.0 - absf(n.at(x * freq, y * freq))
		sum += amp * v * v
		norm += amp; amp *= 0.5; freq *= 2.1
	return sum / norm


## mulberry32: a tiny seeded RNG; next() returns 0..1 exactly as the JS closure does.
class Mulberry32:
	var a: int
	func _init(seed: int) -> void:
		a = seed & 0xffffffff
	func next() -> float:
		a = (a + 0x6d2b79f5) & 0xffffffff
		var t := a
		t = PNoise.imul(t ^ (t >> 15), t | 1)
		t = t ^ ((t + PNoise.imul(t ^ (t >> 7), t | 61)) & 0xffffffff)
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0


## makeNoise(seed): seeded 2D simplex, roughly -1..1.
class Simplex:
	var perm := PackedInt32Array()
	func _init(seed: int) -> void:
		var rng := Mulberry32.new(seed)
		var p := PackedInt32Array(); p.resize(256)
		for i in 256: p[i] = i
		for i in range(255, 0, -1):
			var j := floori(rng.next() * (i + 1))
			var t := p[i]; p[i] = p[j]; p[j] = t
		perm.resize(512)
		for i in 512: perm[i] = p[i & 255]
	# (the gradients as two int tables and the skew factors held here: the same arithmetic in the same order as before,
	# so every value is bit-for-bit what it was, ~30% cheaper. at_ref keeps the original for the check in tools/.)
	const GXI := [1, -1, 1, -1, 1, -1, 0, 0]
	const GYI := [1, 1, -1, -1, 0, 0, 1, -1]
	var f2 := 0.5 * (sqrt(3.0) - 1.0)
	var g2 := (3.0 - sqrt(3.0)) / 6.0
	var gx := PackedInt32Array(GXI)
	var gy := PackedInt32Array(GYI)
	func at(x: float, y: float) -> float:
		var s := (x + y) * f2
		var i := floori(x + s); var j := floori(y + s)
		var t := (i + j) * g2
		var x0 := x - (i - t); var y0 := y - (j - t)
		var i1 := 1 if x0 > y0 else 0; var j1 := 0 if x0 > y0 else 1
		var x1 := x0 - i1 + g2; var y1 := y0 - j1 + g2
		var x2 := x0 - 1.0 + 2.0 * g2; var y2 := y0 - 1.0 + 2.0 * g2
		var ii := i & 255; var jj := j & 255
		var n := 0.0
		var t0 := 0.5 - x0 * x0 - y0 * y0
		if t0 > 0.0:
			var k := perm[ii + perm[jj]] & 7; t0 *= t0; n += t0 * t0 * (gx[k] * x0 + gy[k] * y0)
		var t1 := 0.5 - x1 * x1 - y1 * y1
		if t1 > 0.0:
			var k := perm[ii + i1 + perm[jj + j1]] & 7; t1 *= t1; n += t1 * t1 * (gx[k] * x1 + gy[k] * y1)
		var t2 := 0.5 - x2 * x2 - y2 * y2
		if t2 > 0.0:
			var k := perm[ii + 1 + perm[jj + 1]] & 7; t2 *= t2; n += t2 * t2 * (gx[k] * x2 + gy[k] * y2)
		return 70.0 * n
	func at_ref(x: float, y: float) -> float:
		var f2 := PNoise.F2; var g2 := PNoise.G2
		var s := (x + y) * f2
		var i := floori(x + s); var j := floori(y + s)
		var t := (i + j) * g2
		var x0 := x - (i - t); var y0 := y - (j - t)
		var i1 := 1 if x0 > y0 else 0; var j1 := 0 if x0 > y0 else 1
		var x1 := x0 - i1 + g2; var y1 := y0 - j1 + g2
		var x2 := x0 - 1.0 + 2.0 * g2; var y2 := y0 - 1.0 + 2.0 * g2
		var ii := i & 255; var jj := j & 255
		var n := 0.0
		var t0 := 0.5 - x0 * x0 - y0 * y0
		if t0 > 0.0:
			var g: Vector2 = PNoise.GRAD[perm[ii + perm[jj]] & 7]; t0 *= t0; n += t0 * t0 * (g.x * x0 + g.y * y0)
		var t1 := 0.5 - x1 * x1 - y1 * y1
		if t1 > 0.0:
			var g: Vector2 = PNoise.GRAD[perm[ii + i1 + perm[jj + j1]] & 7]; t1 *= t1; n += t1 * t1 * (g.x * x1 + g.y * y1)
		var t2 := 0.5 - x2 * x2 - y2 * y2
		if t2 > 0.0:
			var g: Vector2 = PNoise.GRAD[perm[ii + 1 + perm[jj + 1]] & 7]; t2 *= t2; n += t2 * t2 * (g.x * x2 + g.y * y2)
		return 70.0 * n
