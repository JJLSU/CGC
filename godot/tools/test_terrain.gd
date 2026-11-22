extends SceneTree
## Checks the terrain port against the web world.js (seed 20261120, ring 130..210, farm flat and range centre at
## the spawn), with no chunks built (heights straight from elevation, as the web's getHeight without a chunk).

func _initialize() -> void:
	Terrain.set_seed(20261120, Vector2(130, 210))
	var c := Terrain.find_spawn()
	Terrain.set_flat_area(c.x, c.z, 24, 38)
	Terrain.set_range_center(c.x, c.z)
	var pts := [[0, 0], [c.x + 10, c.z - 7], [150.3, -80.7], [-300, 420], [512.5, 13.25], [-90, -260], [700, 700]]
	var want_c := Vector2(-5, -30)
	var want_h := [0.9146104297151433, 0.8999999999999999, 0, 13.506589422660541, 0.10627149489420791, 19.273800376378354, 23.59163947853817]
	var want_reg := ["meadow", "forest", "water", "water", "forest", "forest", "meadow"]
	var want_rng := [0, 0, 0, 0.8594417930220971, 0, 0.8948584047274347, 1]
	var want_land := ["home:0.000000", "home:0.000000", "hollows:0.511151", "hollows:1.000000", "fen:1.000000", "hollows:1.000000", "breaks:1.000000"]
	var ok := Vector2(c.x, c.z) == want_c
	if not ok: print("SPAWN want ", want_c, " got ", c)
	for i in pts.size():
		var x: float = pts[i][0]; var z: float = pts[i][1]
		var h := Terrain.get_height(x, z)
		var reg := Terrain.region_at(x, z)
		var rg := Terrain.range_at(x, z)
		Terrain.land_at(x, z)
		var land := "%s:%.6f" % [Terrain.L_id, Terrain.L_wild]
		if absf(h - want_h[i]) > 1e-9 or reg != want_reg[i] or absf(rg - want_rng[i]) > 1e-9 or land != want_land[i]:
			ok = false; print("POINT ", i, " want ", [want_h[i], want_reg[i], want_rng[i], want_land[i]], " got ", [h, reg, rg, land])
	var t0 := Time.get_ticks_msec()
	Terrain.build_chunk_mesh(0, 0)
	print("chunk build ms: ", Time.get_ticks_msec() - t0)
	print("TERRAIN TEST ", "PASS" if ok else "FAIL")
	quit()
