extends SceneTree
## Checks prop placement against the web world.js (seed 20261120, farm flat at the spawn, no exclusions): per chunk
## the count by type, the first three props and the guarded sites, and the landmarks' chunks.

func _initialize() -> void:
	Terrain.set_seed(20261120, Vector2(130, 210))
	var c := Terrain.find_spawn()
	Terrain.set_flat_area(c.x, c.z, 24, 38)
	Terrain.set_range_center(c.x, c.z)
	var want := {
		"0,-1": {"n": 98, "cnt": {"goldtree": 6, "bush": 8, "mushroom": 6, "rock": 5, "pine": 12, "birch": 8, "grass": 12, "flowers": 5, "maple": 8, "sagetree": 2, "lilypad": 7, "cattail": 17, "log": 2}, "first": [["goldtree", 0.555, -29.4322, 1.228, 4.4783], ["bush", 5.2816, -30.5916, 0.8432, 5.6466], ["mushroom", 6.3051, -30.2975, 1.2883, 1.4956]], "sites": []},
		"5,-3": {"n": 46, "cnt": {"rock": 19, "grass": 6, "pine": 3, "quartz": 1, "bush": 2, "maple": 1, "cattail": 4, "lilypad": 5, "lilybloom": 2, "lodge": 1, "satchel": 1, "silver": 1}, "first": [["rock", 163.8009, -93.436, 1.2174, 5.9635], ["rock", 166.9011, -93.8344, 1.2437, 2.6797], ["rock", 172.3623, -94.3584, 1.092, 3.6032]], "sites": ["silver@170.16,-81.75"]},
		"-6,4": {"n": 73, "cnt": {"rock": 37, "grass": 14, "snag": 7, "flowers": 1, "pine": 4, "quartz": 2, "bush": 4, "log": 3, "satchel": 1}, "first": [["rock", -190.9851, 128.0182, 0.8914, 2.2325], ["grass", -176.4955, 129.9348, 0.6575, 0.4739], ["snag", -173.5864, 130.2814, 0.9967, 5.9124]], "sites": []},
		"2,2": {"n": 0, "cnt": {}, "first": [], "sites": []},
	}
	var want_uniq := ["arch@8,-4", "steamboat@-8,-1", "lookout@7,1", "schooner@4,5", "birch@-5,-9", "babe@2,-6", "hermit@-12,5"]
	var ok := true
	for k in want:
		var cc := (k as String).split(",")
		var t0 := Time.get_ticks_msec()
		Terrain.build_chunk_mesh(int(cc[0]), int(cc[1])) # (heights come from the chunk grid, as in the web's createChunk)
		var P := Props.place(int(cc[0]), int(cc[1]), [])
		var ms := Time.get_ticks_msec() - t0
		var cnt := {}
		for r in P.list: cnt[r.type] = cnt.get(r.type, 0) + 1
		var first := []
		for r in P.list.slice(0, 3): first.append([r.type, snappedf(r.x, 0.0001), snappedf(r.z, 0.0001), snappedf(r.scale, 0.0001), snappedf(r.rot, 0.0001)])
		var sites := []
		for s in P.sites: sites.append("%s@%.2f,%.2f" % [s.kind, s.x, s.z])
		var w: Dictionary = want[k]
		var good: bool = P.list.size() == w.n and cnt == w.cnt and sites == w.sites
		for i in first.size():
			for j in 5:
				if j == 0: good = good and first[i][0] == w.first[i][0]
				else: good = good and absf(first[i][j] - w.first[i][j]) < 0.0002
		print(k, " ", "ok" if good else "MISMATCH", " (", ms, " ms)")
		if not good:
			ok = false
			print("  want ", w); print("  got  ", {"n": P.list.size(), "cnt": cnt, "first": first, "sites": sites})
	var uq := []
	for u in Props.unique_encounters(): uq.append("%s@%d,%d" % [u.mark, u.cx, u.cz])
	if uq != want_uniq:
		ok = false; print("UNIQUES want ", want_uniq, " got ", uq)
	print("PROPS TEST ", "PASS" if ok else "FAIL")
	quit()
