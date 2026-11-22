extends SceneTree
## Checks the noise port against values printed by the web version's noise.js.

func _initialize() -> void:
	var want := {
		"m": [0.6011037519201636, 0.44829055899754167, 0.8524657934904099],
		"h": [3708437179, 1811897616],
		"s": [0.4168563619165922, 0.7341340199823307, -0.004374825002624983],
		"f": -0.25755025958537076, "rd": 0.14338831818433426,
	}
	var r := PNoise.Mulberry32.new(42)
	var n := PNoise.Simplex.new(1234)
	var got := {
		"m": [r.next(), r.next(), r.next()],
		"h": [PNoise.hash2(-5, 7, 3), PNoise.hash2(123456, -98765, 77)],
		"s": [n.at(1.3, -2.7), n.at(-50.25, 13.5), n.at(0.001, 0.002)],
		"f": PNoise.fbm(n, 3.3, 4.4, 5), "rd": PNoise.ridged(n, -7.1, 2.2, 4),
	}
	var ok := true
	for k in want:
		var a = want[k]; var b = got[k]
		var aa: Array = a if a is Array else [a]
		var bb: Array = b if b is Array else [b]
		for i in aa.size():
			if absf(float(aa[i]) - float(bb[i])) > 1e-12:
				ok = false; print("MISMATCH ", k, "[", i, "] want ", aa[i], " got ", bb[i])
	print("NOISE TEST ", "PASS" if ok else "FAIL")
	quit()
