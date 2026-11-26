# Paperfjord → Godot 4.7.2 port

The web game (`../src/*.js`, three.js r187 WebGPU, ~20k lines, 90 modules) rebuilt in Godot 4.7.2 (Forward+), in
GDScript, as it is or better. The web version stays as it is: it is the reference for every step.

Run headless checks with:

    "C:/Users/User/Desktop/Godot_v4.7.2-stable_win64.exe" --headless --path godot --quit-after 300

Screenshots: `godot --path godot --script res://tools/shot.gd -- <scene> <out.png> [frames]` (renders a scene
for N frames, then saves the viewport; needs a window, not --headless).

## Decisions

- **Models:** `godot/assets/models` is a directory junction to `../assets/models` (props, folk, animals .glb; the
  2 GB `meshy` raw folder is hidden from import with a `.gdignore`). Nothing is copied.
- **Procedural textures:** the web version paints every card print on a 2D canvas (`textures.js`, `town.js card()`,
  `train.js sides()` ...). Godot has no canvas vector API, so these are **baked from the running web game** to PNGs
  (`godot/assets/cards/*.png`) by a browser-side dump script, keyed by call site and seed, then loaded in Godot.
  Anything that must stay dynamic (name boards, telegram text) is drawn with Godot `Label3D`/`SubViewport`.
- **Determinism:** `noise.js` (mulberry32, value/simplex noise) is ported bit-for-bit (32-bit integer maths with
  `& 0xffffffff`) so the world, lands, rivers, props and the town come out in the same places.
- **Shaders:** `materials.js` TSL nodes (paper tone, fibre, wrap light, ink edges, snow, ground with water/peaks)
  become Godot `.gdshader`s; the post stack (tilt-shift blur by depth, bloom, vignette, grade, Neutral tone map at
  exposure 1.4) becomes a `CompositorEffect` or a full-screen quad shader.
- **Audio:** `audio.js` synthesises every sound with WebAudio oscillators and noise bursts; ported to an
  `AudioStreamGenerator` synth with the same tone()/burst() voices.
- **UI:** the HTML/CSS cards (topbar, notes, journal, craft panel, almanac, map, toasts) become Godot `Control`
  scenes with a paper `Theme` and the Patrick Hand font.
- **Save:** the same JSON shape as the web `saveAll()`, in `user://save.json`.

## Steps

- [x] 1. Project skeleton: project.godot, main scene, models junction + .gdignore, headless import passes.
- [x] 2. Camera rig (30° FOV, pitch/zoom/free camera as player.js), sun + hemi + fill lights as sky.js, Neutral tone map.
- [x] 3. Port noise.js exactly (with a JS-vs-GD test vector check).
- [x] 4. Port world.js terrain: heights, lands/regions, water, ranges; chunk meshes around the player.
- [x] 5. Ground shader (groundMaterial: fields, paths, water, peaks, snow) and paper shader (paperMaterial/cardMaterial).
- [x] 6. Card-print bake: browser dump script → PNGs; Godot card mesh builder (cardGeometry: thick cut-out with back).
- [x] 7. Props and cuts: trees, bushes, rocks, flowers, grass (props.js, world.js CUTS) instanced per chunk.
- [x] 8. Player: avatar model, movement, stamina, input map (input.js), interaction/E prompts.
- [x] 9. Post stack: tilt-shift focus band, bloom, vignette, grade.
- [x] 10. Sky and time of day (sky.js): day cycle, key/fill/hemi lights, palette, dome, haze, paper clouds.
- [x] 10b. Night sky (nightsky.js) and weather (weather.js, storm.js): rain, snow lying, ice, storms, lightning.
- [x] 10c. mist.js, rainbow.js, puddles.js (+ rain rings), fallingstar.js.
- [x] 11. HUD and paper UI theme: topbar, NEXT note, toasts, prompts.
- [x] 12. Gathering: the swing, hits, wobble/fall, loot, chips, regrowth, tool wear, the E pick, hints.
- [x] 12b. The crafting panel (crafting.js: RECIPES, stations, the panel UI, requests/orders), eating (F), the
  grindstone, maple tapping and the other first-tier E actions.
- [x] 13. The homestead (homestead.js): farmhouse, barn, windmill, garden, fence, hay, lanterns, mailbox, smoke.
- [x] 13b. The building system (building.js): pieces, placement, B mode, build bar, stations, collisions, surfaces.
- [x] 13c. The piece interactions: grindstone, bed and sleep, skeps, feeders, saplings/apple trees, cider press,
  woodpile, giant-pumpkin patch, snowmen melting, the fallen star pickup.
- [x] 13d. The homestead extras (coop.js, cellar.js, porch.js, woodpile.js stacks, giantpumpkin.js, laundry.js,
  weathervane.js, bunkhouse.js), the skeps' bees, and the works' upkeep (with the settlers, step 15).
- [x] 14. Critters (critters.js + puppets.js): hens and rooster, cows, sheep, rabbits, deer, bison, turkeys.
- [x] 14b. Old Blue the dog (dog.js, steer.js) and Marmalade the cat (cat.js).
- [x] 14b2. The lost calf (calf.js) and Biscuit the saddle horse (saddle.js and main.js's horse block). (The livery sale
  hooks in with the town, step 16, via main.make_horse; the dog's romp gets its tumbleweeds and ducks in 14c.)
- [x] 14c. Ambient life (ambient.js: falling leaves, fireflies) and butterflies (butterflies.js); firefly jar catching.
- [x] 14c2. Ducks (ducks.js), tumbleweeds (tumbleweed.js; Old Blue's romp), frogs (frogs.js), beaver (beaver.js), wade rings (wake.js).
- [x] 14c3. Songbirds (songbirds.js), crows and the scarecrow (crows.js), owl (owl.js), eagle (eagle.js), geese (geese.js).
- [x] 14c4. Dandelions (dandelions.js), wanderers (wanderer.js), the night coyote howl (howl.js).
- [x] 14d. Hunting (hunting.js: bow, guns, dressing) and fishing (fishing.js).
- [x] 15a. Guardians (enemies.js): coyotes, the bramble boar, hodag, wampus cat, sidehill gouger, hidebehind at
  their sites; fights, wind-up and lunge, knock-outs, peace offerings, pelts. (ModelFigure with hue re-dye was done
  with the player, step 8.)
- [x] 15b. Settlers (settlers.js): the Works, first-find discoveries, settlers moving in and working.
- [x] 15c. The native camps (natives.js): painted poles, warriors who warn and fight, gifts and peace, raids.
- [x] 15d. The wild lands' landmarks (landmarks.js).
- [x] 16a. The town (town.js, part one): the site, level ground, Main Street's buildings by tier, the church, tents,
  Squatters' Row, the assayer and his bench, signs, mending, the new streets, the street dressing, lamps, keepers.
- [x] 16b. The town's people: the Row's families and their wants, greetings, the can-can revue, the lamplighter's
  round, snowmen, the Sunday meeting.
- [x] 16c. The daily stage, the playbill and opera (queue, a $3 seat), the dance hall's couples and fiddler.
- [x] 16d. The barn dance (barndance.js), Saturday's fireworks (fireworks.js), chimney smoke (firesmoke.js), the raids
  on the town (natives.js Raid); the sheriff's WANTED poster comes with the bounty (step 18).
- [x] 17a. The town's trade doors: the assayer and panning (fortune), the shops' shelves, the sheriff's bounty and
  WANTED poster, barber, Grand Hotel, telegraph wire, dance hall, stage line, church, saloon and Miss Dolly, livery.
- [x] 17b. Railroad (railroad.js), train (train.js), trading posts and the freight depot, telegraph rush orders.
- [x] 17c. The gold claim (claim.js) and the opening glint of gold by the cabin.
- [x] 18. Remaining systems (tinker, fair, mail, journal, almanac, map, tales, rumour, landmarks, ...).
- [x] 18a. The tinker's wagon (tinker.js), the County Fair (fair.js), Grandma Pell in the window (grandma.js).
- [x] 18b. The mail (mail.js), tall tales by the fire (tales.js), the journal tally and the almanac (journal.js, H).
- [x] 18c. The county map (map.js, Tab) and its marks (bounty, saloon tip, stage passenger); rumour notes (rumour.js);
  the fingerpost (signpost.js).
- [x] 18d. The kite (kite.js, G), snow footprints, leaf piles, fairy rings, sun shafts, the will-o'-the-wisp, hoof dust.
- [x] 18e. HUD leftovers: the next-goal line, the fortune readout, tools in hand; anything else main.js still has.
- [x] 19. Audio synth and all sounds/music.
- [x] 19a. The engine (the web's synth rendered offline to WAVs), the beds (wind, water, rain), the land voices,
  birds, crickets, fire crackle, the four banjo tunes, footsteps, gathering, building, the creatures', train's and
  town's sounds (fiddle, hymn, bell, piano), thunder, fireworks, the howl, the tool bar, eating, crafting, panels, N.
- [x] 19b. The remaining one-off sound calls of main.js (the 31 beside a toast and the rest: E actions, settlers,
  town doors, guns, riding...), checked off against the list in the 19a log; and the ducks-vs-panning E clash.
- [x] 20. Save/load; side-by-side comparison screenshots with the web version; performance pass.
- [x] 20a. Save and load (main.js saveAll and its load; BuildSystem.save).
- [x] 20b. Side-by-side comparison screenshots with the web version (matching views), and fixing what they show.
- [x] 20c. Performance pass: frame times across the county, chunk layout off the main thread (the county map's faint
  iron, the wisp), anything else the profile shows.
- [x] 20d. Night grading near lamps: Godot's lantern-lit hay and ground read bluer and less saturated than the web's
  (see the 20b log's numbers); calibrate the night ambient against the lamps.
- 21. Polish found by the comparisons (each measured against the web, as 20d):
- [x] 21a. The sun, fill and moon colours: a daylight side-by-side (the farm and Main Street, by region averages)
  to decide whether they need the same linear conversion as the point lights.
- [x] 21b. At night the ground nearest the camera reads whiter than the web's (not the lamps): find out why.
- [x] 21c. The ~44 ms hitch when a herd's puppets are made: pool or pre-instance them.
- [x] 21d. The night farm's p95 of 19 ms against 9 by day: profile the lamps and fireflies.
- [x] 21e. The county map's faint unexplored iron: lay far chunks out on a worker thread (Terrain's caches made
  thread-safe first).
- [x] 21f. Uncached terrain lookups cost 80-110 us a call in GDScript (get_height, is_water away from built chunks),
  which makes a far chunk's prop layout 25-80 ms and a chunk's terrain heights ~47 ms: profile Terrain.elevation and
  region_height and make them cheaper without changing a single height (check against the web's own values).
- 22. What an audit of the web's keys and page against Godot found still missing (2026-11-22):
- [x] 22a. The title card (#overlay: the torn-paper vignette, the name and line, the controls list, "Click to begin",
  the New game button) and the pause card (#peek), shown as the web shows them; the crosshair (#crosshair).
- [x] 22b. K: snap a postcard (main.js makePostcard: the frame framed as a postcard, saved as a picture).
- [x] 22c. O: graphics quality (auto, high, medium, low; auto steps down on slow frames) and P: depth of field on/off.
- [x] 22d. F3: the dev badge (frame rate, the backend card, the time-of-day buttons #times), F4: the dev cash, and
  the "a little tear in the paper" card when a frame throws (#error).
- [x] 23a. The journal events the web records that Godot never did (an audit of every journal.record id): deer
  spotted, a dandelion clock, a landmark reached, the assay, the store and the smithy, a bounty paid, the church, a
  woodpile stack, a warm night by the stove, Johnny Appleseed, patting Old Blue and Marmalade.
- [x] 23b. The ponds' ice as main.js has it: the ice never melts under your boots, the toast "The ponds have frozen
  over!", the skate journal event (gliding > 2.2 m/s for a second), the blade scratches on the ice (an instanced pair
  every 0.42 m, cleared once the ice thaws below 0.3).
- [x] 23c. The toasts and moments the audit found missing: the first iron (charcoal pit hint), the rainbow note 2.5 s
  after a daytime shower, the jar's lightning bugs let go at first light, the newcomers at the mended boarding house,
  the barn dance starting, the falling star landing ("It came down off to the <dir>").
- [x] 23d. The comments that still say "comes with step N": check each against the web (tumbleweeds and the town,
  the warriors in hunting targets, the guardians' legs, the saloon tip on the map, the jar lantern) and close them.
- [x] 23e. A side-by-side pass against the web (the same views and saves, compare_views.gd) for anything else
  missing; add what it finds as new steps.
- [x] 24. The player's own requests for the Godot version (2026-11-22; the web version keeps its name and menus):
  the game and the town renamed Cold Glitter Creek; full screen at launch; an Options card (display, vertical sync,
  interface size, graphics, depth of field, sound); Save game and Quit on the title/pause card.
- [x] 25. The player's asks for the raids (Godot only): a war party only comes on the town while you're in it, and
  rides off if you leave; left at a mended building, it wrecks it back to run-down, to be mended again; a warrior's
  blow or arrow takes a quarter of the farmer's starting health.
- [x] 26. Next: another side-by-side pass for what the panels pass didn't cover (the county map card, the story and
  letter cards, the crafting panel's look, the toasts' placement while a panel is up).
- [x] 27. Performance at the player's full-screen size (4K: the game now opens full screen on a 3840x2160 screen).
- [ ] 28. The 12-18 ms "chunk finish" spikes walking into new country: spread the props' layout (Props.place,
  17-50 ms for a chunk not laid out before, 4-8 ms after) over frames as the terrain mesh already is.
- [x] 29. The player's notes from playing: the railroad ties lie across the rails; the cars tilt up and down the
  hills; a slower train; no raids on the town till you have a ranged weapon.

## Log

### 2026-11-22
- Steps 1-3 done. Project at godot/ (Forward+, 4096 shadow map). Models junction + meshy/.gdignore; the first headless
  `--import` of all props/folk/animals glbs takes ~10 min, later ones are quick. After adding a `class_name`, run
  `--headless --import` once so the global class cache knows it.
- scripts/core/noise.gd (class PNoise): mulberry32, hash2, Simplex, fbm, ridged, smoothstep. tools/test_noise.gd checks
  it against values printed by the web noise.js: PASS (bit-exact).
- scripts/core/camera_rig.gd (CameraRig): player.js camera as is (yaw 0.35, pitch 0.46 in -0.45..1.53, dist 15 in
  2.5..42, anchor/aim easing, hill lift). main.gd uses it with a placeholder focus node.
- tools/shot.gd renders a scene and saves a PNG (needs a window; works on this machine's RTX 4090).
- Lights/environment are placeholders (frame is over-bright, Filmic): the full sky.js port is step 10, the post stack
  and tone mapping step 9. Models need seating by their bounding box (min.y to 0) like the web `put()`: a helper in step 7.
- Next: step 4, world.js terrain.
- Step 4 done. scripts/world/terrain.gd (class Terrain, static): seed + 13 noises, land_at/land_tint, the range
  mask and folded lattice (mtn_node/full_node caches), region_height, elevation with level sheets (set_flat_area,
  add_flat_area), get_height on the per-chunk 65x65 grid caches, is_water/wadeable/wade_depth, moisture, path_field,
  field_mask, region_at, coarse_region, find_spawn, build_chunk_mesh (clockwise winding for Godot).
  tools/test_terrain.gd: spawn, heights, regions, range and land at 7 points match the web world.js exactly: PASS.
  A chunk builds in ~20 ms in GDScript (acceptable at one a frame; move to a WorkerThreadPool task if it hitches).
- scripts/world/world.gd (class World): chunk streaming (radius 3, nearest first, one a frame, dispose beyond 4.5),
  the 360 m backdrop page, region map + land map Images (RGBA8, wrapping 256 m) for the ground shader. Props later.
- main.gd: seed 20261120 / ring 130..210 for now (save/new-game seeding comes with step 20), find_spawn, farm flat
  24..38 m, range centre at the spawn. A plain banded height shader stands in for the ground shader.
- tools/shot.gd takes extra "node.prop=value" args (e.g. rig.dist=42.0 rig.pitch=0.75) for overview shots.
- GDScript gotchas met: use floorf/floori (floor() is Variant and breaks := inference); a script error makes a
  --script run hang, so wrap test runs in `timeout`.
- Next: step 5, the ground and paper shaders (materials.js).
- Step 5 done. Baked the four shared paper textures (fiber, wash, handmade, noise) from the running web game to
  assets/baked/paper/*.png via tools/bake_server.py (python, 127.0.0.1:5199, POST /save?path=...; the browser posts
  canvas.toBlob() PNGs). Their .import files set lossless compression (compress/mode=0) with mipmaps.
- shaders/paper_common.gdshaderinc: global uniforms (paper_fiber/wash/handmade/noise samplers, paper_key_dir,
  paper_snow, paper_ice, paper_cloud_shade; declared in project.godot [shader_globals]), ptex() samples the canvas
  textures at (u, -v) (three uploaded them with flipY), hexc() = three's color(hex) (sRGB -> linear), MaterialX
  cell/perlin noise (mx_cell_noise_float, mx_noise_float), bump_normal() (bumpMap).
- shaders/ground.gdshader: groundMaterial line for line (water, ripples, ice, bank, meadow/forest/field/highland/
  peak/path torn sheets with rims, hairs and shadows; field patchwork; ranges with snow line; grass marks and leaf
  drifts; handmade tint + wash; contour lips/shadows and rock strata; cloud blots; snow; land dyes). kind=3 for the
  backdrop page. shaders/paper.gdshader (paperMaterial) and shaders/card.gdshader (cardMaterial incl. tintClothes
  hue, snow/snow_cap, sway by INSTANCE_ID, self_fill emission for models, flip_map for canvas prints).
- scripts/core/paper_mats.gd (PaperMats): paper(), card(), ground(), paperize(model) (card material per source
  texture, paper_scale 6, pulp 0.08, self-fill 0.28), seated(scene, size, by_height) = the web put() helper.
- Bump strength: three's bumpMap reads ~6x softer than bump_normal at the same number; scales set to 0.06 (ground),
  0.02 (paper, card) by comparing with a web frame. The remaining difference (Godot frame cooler/greener, web warmer
  and golden) is the post grade and tone map: step 9. main.gd sets paper_key_dir from the sun's basis.
- Next: step 6, card-print bake + card mesh builder (props.js cardGeometry, textures.js prints).
- Step 6 done. Baked all 45 propKinds() entries (every kind and cut: trees, bushes, flowers, grass, the three rock
  cuts, ore/quartz/silver, log, lodge, treasures, crops, cattails, lily pads, signs, hill and peak sails) from the web
  game: assets/baked/props/<kind with ~ as _>.png (the print, read from the material's TextureNode) + .json (the
  non-indexed position/normal/uv arrays, flipY). Bake snippet: walk material.colorNode for the TextureNode whose
  value isn't one of sharedTextures(), canvas.toBlob -> POST to tools/bake_server.py.
- scripts/world/prop_kinds.gd (PropKinds.get_kind(kind) -> {mesh, material}): loads a bake, reverses each
  triangle's winding for Godot, and gives it the card material with props.js's sway/snow-cap options.
- scripts/core/card_mesh.gd (CardMesh.build(points, thickness, back_at)): cardGeometry for cards made at runtime
  (Geometry2D triangulation, front/back faces with frame() padding uvs, cut sides on EDGE_UV, plain back option).
- scenes/tests/props_gallery.tscn shows every kind + a runtime card: all render right way up with their prints.
- Still to bake later, with their systems: the cards other modules paint at runtime (town.js card() signs and
  boards, train sides, landmarks, homestead pieces, figures' paper parts...). Same bake route, or CardMesh plus a
  print baked per text.
- Next: step 7, prop placement (world.js placeProps, TABLES/LAND_TABLES, PROP_TINT, TALL, POOL_CAP, uniques, sites)
  as MultiMesh pools per kind, with the springy pop-up.
- Step 7 done. scripts/world/props.gd (Props): placeProps line for line (grid + region/land tables, PROP_TINT, the
  hills draws kept in the stream, pond life, logs, bales/stooks, orchards, satchels, kitchen garden, landmark
  clearing, guarded sites with their rings and warning signs), unique_encounters, field_kind_at (reads the baked
  noise.png G channel exactly as the web reads the canvas), spring_rise. tools/test_props.gd: four chunks' counts by
  type, first three props and sites, and the seven landmark chunks all match the web: PASS. ~35-65 ms a chunk
  (terrain + props) in GDScript.
- world.gd: one MultiMesh pool per kind and cut (POOL_CAP, CUTS by position, TALL trees, per-card tone/tint as
  instance colour, packed alloc/release, no shadows from grass/flowers/lily pads), the beaver lodge from its model
  (ROCK_MODELS), write_matrix (yaw x hinge fold x wobble/fall, scale) and the staggered spring pop-up per chunk.
  Chunks keep resources, colliders and sites for the later systems; `destroyed` is ready for gathering.
- Not yet: the homestead/town/railroad exclusions (their systems add them before chunks build: steps 13, 16, 17),
  regrowth and gathering (step 12), the occlusion ghosts that fade cards between camera and farmer (step 8, with the
  player), layoutFor/sitesFor/orchardFor/satchelsFor memo helpers (with the systems that call them).
- Exit-time "RID allocations leaked" errors from --script runs are harmless (the tree is torn down by quit()).
- Next: step 8, the player.
- Step 8 done. scripts/core/game_input.gd (GameInput node): input.js with web KeyboardEvent.code names from the
  physical key (KeyW, ShiftLeft, Space, Digit1...), down/hit/dx/dy/wheel/clicked/right_clicked, lock/unlock (mouse
  captured), end_frame. main.gd: click captures the pointer, Escape releases it; `force_active` lets tests play.
- scripts/folk/model_figure.gd (ModelFigure): loads assets/models/folk/<name>.glb, paperize (no snow, optional
  hue), loops every clip, idle at a per-figure rate from a random point, walk speed-scaled, swing plays work in
  0.55 s, POSE_CLIP; hand/head holders on BoneAttachment3D (LeftHand/RightHand/Head). The IDLE_FROM idle donors
  (retargeting another figure's idle) are not ported yet.
- scripts/player/avatar.gd (Avatar: folk_jim, swing/connect timing, footfall flag; tools in the fist, quiver,
  guns, astride later) and scripts/player/player.gd (Player): player.js update line for line (look, WASD, sprint,
  stamina, hunger, healing, wading speed, slopes, collisions, deep water and mountain sides turn you back, swimming,
  jump/land/splash events, facing), hurt, collide, find_target, ground_at (build/climbs hooks).
  scripts/world/resources.gd (Res): RESOURCE_TYPES, REGROW, WALK_THROUGH. world.resources_near().
- camera_rig.gd no longer reads the mouse: the player turns it (as player.js does).
- Occlusion ghosts: OCCLUDERS pools use MultiMesh custom data (fade) and card.gdshader's `ghosts` stipple discard
  (interleaved-gradient noise); world.update_occlusion() is the web's line for line. (Resources are Dictionaries:
  key the ducking set by res.key, never by the dictionary itself; it hashes recursively through res.chunk.)
- tools/test_player.gd: walk 2 s = 11.1 m, sprint 2 s = 21.3 m (6 and 11.5 m/s after the easing), stamina spent,
  grounded, never enters deep water heading straight for it: PASS. Screenshot: Jim in the woods, trees ghosted.
- The E prompts and interaction belong with the HUD and gathering (steps 11, 12).
- Next: step 9, the post stack (tilt-shift by depth, bloom, vignette, grade, Neutral tone map at exposure 1.4).
- Step 9 done. shaders/post.gdshader: post.js as a full-screen pass (a 1x1 QuadMesh child of the camera, POSITION
  stretched over the screen, reading hint_screen_texture + hint_depth_texture after the opaque pass): one bounce
  (screen mip 4.5 tinted by the surface hue, mostly in shade), the warm 1 px silhouette line from depth, tilt-shift
  (post.js's blurAmt formula exactly; SCREEN_UV.y flipped to three's up; blur from the screen texture's blurred mips
  at LOD 1.6 and 2.6), Khronos Neutral tone map at exposure 1.4 (three's NeutralToneMapping), then the grade in sRGB
  (saturation, warm shadows, white balance, shadow lift, contrast, night navy), vignette and grain, output back to
  linear. Environment: tone mapper Linear (the pass owns the curve), SSAO (radius 0.7) for contact occlusion, glow
  (threshold 0.85, intensity 0.22, additive) for the bloom on lit panes.
- main.gd _update_post(): focus_z eases to the camera-to-hero distance, depth_weight/near_gain from lensFar, k_d =
  max(0.25, tan(pitch)) / fov. Night, shadow warmth, AO strength and the auto exposure follow the sky (step 10).
- Screenshots: the close view is warm and golden like the web; the diorama view has the sharp band on the farmer
  and blur above and below.
- Differences left: Godot's SSAO is grey (the web tints its AO warm, 0.62/0.42/0.26); the lens doesn't yet walk a ray
  through the screen centre to focus on what it lands on (main.js centreDepth); light levels wait for the sky port.
- Next: step 10, sky and time of day (sky.js: sun/moon key placed relative to the camera, hemi + fill colours and
  intensities, palette, haze/fog, clouds, night sky), then weather.
- Step 10 (sky) done. scripts/world/sky.gd (class DaySky; `Sky` is a Godot class name): sky.js update line for
  line (DAY_LENGTH 720, night x3, the sun path, the key placed 55 degrees off the camera axis toward screen-left,
  26..50 degrees up by day / 45 for the moon, sun/moon colours and intensities, hemisphere colours and intensity rising
  to dusk and night, the frontal fill from behind the camera, haze colour/amount, the rain greying, clock_text()).
  The 20 die-cut paper clouds: same mulberry32(42) shapes (CardMesh) and placements, prints baked from the web
  (assets/baked/sky/cloud0..2.png), drifting and wrapping round the player, turned to the camera, no haze on them.
- shaders/sky.gdshader is the dome (watercolour wash blooms, sun disc and halo, moon glow, fibre stars) AND, in its
  cubemap pass, the HemisphereLight (sky colour above, ground colour below): Environment ambient from the sky
  (radiance 32, incremental) gives hemispheric ambient like three's.
- Light units: three's punctual and hemisphere lights reach a Lambert surface divided by pi, Godot's don't:
  SUN_K = FILL_K = HEMI_K = 1/pi (frames at 0.45, 0.72 and 0.95 match the web's mood: warm noon, golden hour, navy
  moonlit night with the cards readable).
- The haze (fog node in the web) is in paper_common.gdshaderinc: haze_factor/haze_color by ground distance from the
  hero (globals paper_focus, paper_haze, paper_horizon, paper_haze_amt; sRGB colours converted to linear before
  they're set), applied after lighting in ground/paper/card shaders (albedo * (1 - f) + haze as emission).
- main.gd: the post's night and shadow warmth and the auto exposure (1.4 x (1 + 0.25 night), eased) follow the sky.
- Next: step 10b (night sky and weather).
- Step 10b done. scripts/world/weather.gd (Weather): weather.js line for line (showers every few minutes, a third of
  them snow, one rain in four a storm that lingers 40 s more; rain eases at 0.35/s; snow lies over a minute and melts
  over 2.5; up to 420 crossed paper slivers / tumbling flakes in a 34 m box, none under a roof via covered(x, z)).
  scripts/world/storm.gd (Storm): the cut-paper bolt far off (110-230 m), two flickers, the flash (exposure +35 %),
  thunder after 0.6 + d/120 s at its volume (on_thunder for the audio step). scripts/world/night_sky.gd (NightSky):
  70 paper stars (mulberry32(919) placements, three's setHSL colours) and the crescent moon / harvest full moon,
  turning in on their creases at dusk with spring_rise, riding with the camera at 380 m; prints baked from the web
  (assets/baked/sky/star.png, moon.png, fullmoon.png). shaders/glow_card.gdshader: unlit print x glow x tint.
- main.gd wires them as main.js does: paper_snow = weather.snow, ice eases in on deep snow (paper_ice, player.ice_on),
  sky.rain (snow at 0.45), paper_cloud_shade on fair days, the storm's gloom (-22 % exposure) and flash, the harvest
  moon on the eve of every seventh day. Screenshots: rain slivers, a snowed-under woodland with snow-capped trees,
  a navy night with the window lit. tools/probe_night.gd: 70 stars up after dark, the moon out.
- To check against the web at night: Jim (self-fill emission 0.28) looked bright up close; compare a web night frame.
- Next: step 10c.
- Step 10c done. scripts/world/mist.gd (14 tissue sheets, mulberry32(61) layout, first-light thickening and lifting by
  09:30, most mornings and always after night rain, the fen's low grey-green mist), rainbow.gd (six paper half-ring
  bands via CardMesh, 42 m off away from the sun, slow spring rise, stands 70-100 s, folds), puddles.gd (18 torn
  puddles flush on gentle footpath ground with the web's slope/bend tests, fill/dry rates, 40 rain rings on ponds
  and puddles), falling_stars.gd (launch 22-40 m off on clear nights, the gold ribbon tail facing the camera, the
  landed star's spring rise, glow and warm omni light, direction words, take(), STAR_GIFTS for the E interaction in
  step 12). shaders/sheet.gdshader: a translucent lit print (mist, puddles). Prints baked: sky/mist.png,
  sky/puddle.png, sky/fallingstar.png. Omni light energy /pi like the sun.
- main.gd: night_rain flag (rain after 18:00 or before 05:00, cleared after 10:48), mist with the fen weight,
  rainbow on a daytime rain's end, puddles, falling stars.
- tools/shot_weather.gd: mist at first light (faint, as on the web), the rainbow (seen standing over the woods),
  puddles (none in frame: they need a footpath near the farm), a fallen star (landed, 55 m off, out of frame).
  Worth a second look once the homestead clears the farm and footpaths are in view.
- Next: step 11, HUD and the paper UI theme.
- Step 11 done. scripts/ui/hud.gd (Hud, a CanvasLayer): paper cards (StyleBoxFlat #f4ecd8, 1 px #d8c9a8 edge,
  2,3 px warm shadow, each tilted like the CSS), the font Patrick Hand with the web's own fallback Segoe Print
  (SystemFont; no font download), the top bar (name, clock), the NEXT note (red left border), the ledger top right
  (rows fade at zero), the bottom column (notes, the hint, health/stamina/fullness bars with the low/boosted/hungry
  colours and blinks, the calm fade after 3 s), the tool bar (8 slots, held slot raised and gold, locked ones faded,
  the web's tool names), the pack (I) with the pantry basket, the red-paper hurt flash, and the toast queue exactly as
  hud.js (two pinned, same note extends, short notes replace the last short one, long ones queue, 2.4 s + 50 ms a
  character, max 10 s, fading up and away).
- Icons: hud.js's ICONS/BASKET/TOOLBAR SVGs, ORDER/ALWAYS/LEDGER/DISHES lists pulled from the web (the module text
  evaluated up to the class in the browser) into assets/baked/hud/icons.json; Godot rasterises them with
  Image.load_svg_from_string, cached per size.
- main.gd: the web's inventory dict, tools (dict as a set), held, wear, owns(); _update_hud() each frame; I toggles
  the pack; the hint shows the name of what you face until step 12 brings the full E/click prompt text.
- tools/shot_hud.gd: screenshot with goods, notes, the pack open and some tools.
- Not yet (with their systems): homeward/fortune cards, journal, rumour, settlers card, the title/pause overlay and
  peek card, the sleep fade, the build bar, the time-of-day buttons, the craft/map/almanac/letter/story panels.
- Next: step 12, gathering, inventory, tools and the crafting panel.
- Step 12 (gathering) done. world.gd: hit() (wobble while it holds; else destroyed, regrow scheduled with the
  web's jitter and the crop-grow factor, loot rolled, trees fall away from you), _update_animations() (wobble, fall,
  grow), _regrow() once a second (rain speeds it; never under the farmer or a building: regrow_blocked hook),
  on_resource_gone hook; resources carry hp. scripts/core/gather_rules.gd (GatherRules): damageFor, toolFor, SOFT,
  WEAR_PER_HIT, wrongTool, E_PICK, SATCHELS, the hint verbs. scripts/world/confetti.gd: particles.js (500 paper
  chips). avatar.start_swing().
- main.gd: _gather() each frame (number keys pick tools with the web's "no X yet" notes, click or hold to swing,
  E picks soft things whole, the hit on the swing's connect frame, edge() and blow() with the dull warning, chips,
  satchel gifts, loot with the berry basket and harvest-moon bonuses, +N toasts), the two hint lines
  ("[E] ..." / "[LMB] Verb name  hp boxes  (needs ...)").
- tools/test_gather.gd: the farmer faces the nearest tree and holds the mouse: an oak falls, +3 wood, destroyed and
  set to regrow: PASS. (Hint seen: "[E] Pull an armful of tall grass / [LMB] Pick tall grass  ■".)
- Not yet: sounds (step 19), journal records and first-find notes (step 18), enemies/camps/built pieces as targets
  (their steps), e_free with the other E prompts.
- Next: step 12b, the crafting panel.
- Step 12b done. crafting.js's data pulled from the web (module text evaluated in the browser): all 130 RECIPES,
  the tinker's 7 REQUESTS, the 10 telegraph ORDERS, STATION_NAME, LAND_NAME -> assets/baked/data/crafting.json;
  building.js's PIECES list (name, cost, free) -> assets/baked/data/pieces_list.json.
- scripts/core/crafting.gd (Crafting): can_afford, cost_text, blocked() and craft() exactly as the web (requests,
  wires, fair entries, tools owned/made, "needs", stations, Need more), new_request/request_state,
  new_order/order_state/clear_order (the telegram text in BBCode).
- scripts/ui/crafting_panel.gd (CraftingPanel): the #craft card (520 px, scrolls): Crafting + close, "You have",
  the tiers in the web's order (the town/rail/camp/fair tiers via *_open callables their systems set), recipe rows
  (name + tick, note, cost with shortfalls in bold red and what you have, the gives), the web's button labels and
  disabled states, the build-pieces list (two columns, "near a workbench").
- main.gd: C opens/closes (the pointer freed while it's open, play paused), Esc closes; station_checks dict for
  the systems to answer stations (workbench/campfire/forge with building); the web's craft notes; F eats (the FOOD
  table: heal, boost, fullness 0.8 x heal, the notes); hungry/starving warnings; maple tapping (E, once a tree a
  day, +1 sap).
- tools/test_craft.gd: hammer craftable by hand, pickaxe "Needs a workbench", crafting spends 4 wood + 1 stone and
  marks it Made, F eats the pie (+40 fullness): PASS; screenshot of the panel matches the web's layout.
- Not yet: the grindstone (with the workbench/forge, step 13), first-find notes and journal (step 18), sounds.
- Next: step 13, the building system and the homestead.
- Step 13 (homestead) done. Its layout is fixed relative to the farm centre (mulberry32(1776), all on the farm's level
  sheet), so the paper model is BAKED from the web: a fresh Homestead built in the browser at the live farm centre
  (-5, -30) with a stand-in world, exported with three's GLTFExporter (each node material swapped for a standard
  one carrying its print or colour, named card / paper / glow_window / glow_lantern; the fan, mail flag, house and
  barn groups named), relative to the centre: assets/baked/homestead/homestead.glb (12.5 MB). Alongside it,
  homestead.json: the 7 exclusions, 59 colliders, roofs, barnBox, spawn, millAt, vaneAt, chimneyTop, frontDoor/
  Window, houseW/houseFront, the mailbox, the 5 lamp lights (matrix, max, colour, distance, decay) and the meshes that
  are models from the reference art (bldg_barn, prop_haybales, prop_haybale_round) as {model, mesh index, matrix}.
  Generic route for any seed-independent layout: build fresh in the browser, swap materials, export, re-skin.
- scripts/home/homestead.gd (Homestead): registers exclusions/colliders/garden before chunks build, re-skins the
  baked materials (card/paper; window panes and lantern glass glow at night via night_glow x global paper_glow),
  places the model meshes, the lights (glow x max / pi), the fan's spin, the nine chimney smoke puffs, set_fortune()
  (the farmhouse model per fortune, seated with the model's .json body width, the paper house hidden, the chimney
  top found from the model), covers() for the rain, update().
- main.gd: the homestead before the first chunks, the player spawns at its spawn, weather's covered() uses it.
- Screenshots at 10:50 and 21:40: the farm clear of trees, garden rows, barn and hay, farmhouse, windmill, fence,
  lantern posts glowing with warm pools of light after dark.
- Next: step 13b, the building system.
- Step 13b done. Baked every piece's mesh from the web (makeMesh(type) for all 39, exported per piece to
  assets/baked/pieces/<type>.glb with children named part0..n in order, materials named card/paper/glow_window/
  glow_lantern; the eight pieces that are reference-art models as placements in pieces.json, plus LAMP_AT) and the
  rules (PIECES, PIECE_HP, STONE_PIECES, PIECE_CHIPS, PIECE_GROUPS, PIECE_ORDER, FOOT) into data/building.json.
- scripts/build/build_system.gd (BuildSystem): make_mesh (re-skinned bake + models; the ghost in translucent
  green/red), surface_at, collide (walls, doorways), nearby, has_workbench_near, aim (the camera's centre ray against
  the pieces' footprint boxes, the stand-in for three's mesh raycast, and the terrain march), snap (cell/edge/free,
  reaching through wall sides, floors carried floor to floor, stair landings, upper storeys on wall tops, roofs on
  wall tops sloping toward the house's middle, ridges peaking a roof), validate (costs, workbench within 20 m, snow,
  works discovered, water, duplicates, crowding, reach, standing there), update (the ghost), place, remove_hovered
  (refund), find_target, damage, chips_for, add (folded flat, springing up), trim_legs, fold_away, animate (rise,
  shake, fold), update_lights (six nearest: fires flicker, lanterns and jacks glow after dusk), fire_distance,
  roof_at, station_near, near_fire, save_pieces/load_pieces. (to_local is a Node3D method: renamed piece_local.)
- Hud: set_buildbar (the shelves, the current shelf's pieces with costs, selected raised, unaffordable faded).
- main.gd: B toggles build mode (needs the hammer), 1-5 shelves, Q/E step, R turns (a roof by hand turns off the
  auto-slope), click places (holding repeats every 0.3 s), right-click takes down; the crafting panel's workbench/
  campfire/forge stations ask the build; regrowth blocked under pieces; the player walks on floors and stairs and
  is pushed out of walls (player.gd: pos = build.collide(pos), Vector3 is a value type).
- tools/test_build.gd: workbench, campfire, floor, wall placed at the web's costs (40 -> 25 wood), the pickaxe now
  only short of stuff (the workbench station answers), a probe inside the wall pushed out: PASS. Screenshot shows the
  workbench model, the campfire, the floor and wall rising.
- Not yet: build-mode tool swings hitting built pieces (gathering targets pieces too in the web), the hover
  highlight, sounds, the journal; the bed/skep/feeder/etc. interactions (13c).
- Next: step 13c.
- Step 13c done. BuildSystem: bed/skep/press/apple_tree/patch/woodpile/feeder_near, melt_snowmen, tend_skeps
  (a comb each morning, 3 at most), tend_feeders (a day's seed eaten each morning), tend_trees (a sapling grows into
  "Your apple tree" two mornings on; trees ripen two apples a morning, 6 at most). homeapple (not on the build menu)
  baked too.
- main.gd _yard(): the web's E actions and notes word for word (shake your apple tree, take honey, cider press with
  its two-minute stamina, tend/cut the giant pumpkin (5 stages), stack/take firewood (24 max, the 12-log note), fill
  the feeder, the grindstone at a workbench or forge (1 stone, every edge to 100), the fallen star and its gift,
  sleep in the bed after dark: the curtain, day + 1, 06:28, full health and stamina, 15 fullness gone, the stove
  bonus from a stacked woodpile within 30 m), and their prompts in the web's order; e_free from them. The tale by the
  fire is prompted (the telling comes with tales.js, step 18). Hud: the sleep curtain ("Zzz… the night passes
  under the quilt").
- tools/test_yard.gd: a comb by morning, the sapling grown two mornings on, four logs stacked, a night's sleep to
  0.27 with stamina 300 (the warm-stove bonus): PASS.
- Next: step 13d.
- Step 13d done. Baked at the farm centre from fresh web instances (a generic baker: each object's own fields name its
  parts, e.g. eggMeshes0..3, items0..5, turn, stake/group/fire, flame, panes0..; vectors and numbers saved to the
  JSON): assets/baked/homestead/coop, cellar, bunkhouse, laundry, vane, porch (.glb + .json with exclusions,
  colliders, models such as bldg_coop). GLTFExporter skips hidden objects unless {onlyVisible: false}: the first
  bake lost the cellar mound, the bunkhouse and an egg; re-baked with every object shown and onlyVisible false.
  (Earlier bakes had nothing hidden that mattered: homestead paper house and pieces were visible.)
- scripts/home/farm_extras.gd (FarmExtras): registers their exclusions/colliders before chunks, re-skins, places
  models; the coop (eggs each morning 2-4 up to 4, laying mash +2, collect), the cellar (stake -> mound, $20, food
  each day), the bunkhouse (stake -> house, $40, colliders, windows lit after dark, the supper fire 18:14-21:07), the
  laundry (swinging with gusts, heavy in the rain), the weathervane (west wind, swings east ahead of a shower, says
  so once), the porch rocker (sit: 24x time, the farmer seated and rocking), the woodpiles' logs (rows of six, nested)
  and the giant pumpkins (size by stage, a springy swell).
- main.gd _extras(): the web's E actions and notes word for word (rocker, cellar, bunkhouse, nesting box), their
  prompts, the vane's omen notes within 60 m, time drifting while seated.
- tools/test_extras.gd: three eggs, cellar dug and stocked, bunkhouse bought ($70 -> $10), seated with time running
  fast, up again: PASS. Screenshot: the nesting box and hen house, the washing line, the rocker.
- Approximations to revisit: the laundry's "heavy" garment picked by index (the web uses outline length), the logs
  printed plain bark (the web prints end grain on their ends), the skeps' bees not drawn yet, the farmer's hips not
  seated exactly in the rocker (the web aligns the Hips bone).
- Next: step 14 (critters, dog, cat, birds, ducks, frogs, wildlife; hunting and fishing).
- Step 14 (critters) done. Baked every puppet species from the web (new Puppet(kind) for 22 kinds incl. the calf
  and donkey variants): the six paper ones (hen, duck, duckling, turkey, rooster, gouger) as GLBs with their pivots
  named body/head/leg0../ear0../tail; for the 16 that wear a reference-art model, its fit (turn scale and rotation,
  the lift to its lowest toe) in assets/baked/puppets/puppets.json with the gait.
- scripts/folk/puppet.gd (Puppet): paper rig or the worn model; for models an AnimationTree (rest / walk / run,
  Blend2 by the web's mw and rw weights, time-scaled by speed); legs, head (graze, peck, lunge), ears, tail, bob,
  lean, the smooth heading toward the way it moved, set_fold for a struck beast.
- scripts/folk/critters.gd (Critters): critters.js line for line (mulberry32(4242); five hens incl. the rooster by
  the barn, two cows and four sheep in the pasture, the wild ones kept round the farmer with the web's counts and
  regions, flee/walk/idle, no stepping into water, LOD by camera distance, roosting in the hen house and the barn at
  nightfall and out of a downpour, the rooster's crow pose, fell() and dressing, livestock_near/hold/set_shorn).
- main.gd: critters set up at the web's yard and pasture; the barn door point from the baked barn; milking and
  shearing (the web's notes, once a day / fleece back in two days), the rooster crows at sunup, dressing a beast.
- tools/test_critters.gd: 5 hens, 2 cows, 4 sheep, wild rabbits and deer appear, a cow milked, six in for the night
  within 25 s: PASS. Screenshot: the cow and sheep models grazing, "[E] Shear the sheep".
- Next: step 14b.
- Step 14b done. scripts/folk/steer.gd (Steer: heading round collider circles, rescans twice a second, push_out),
  scripts/folk/dog.gd (Dog: dog.js line for line: pottering, loping after you past 14 m, catching up past 40 m, the
  daily dig errand and FINDS, the stick (offer, throw 11 m end over end, chase at 9 m/s, bring back), track and romp
  (hooks wired, fed null until the calf and tumbleweeds are ported), settling by the porch rocker, barking at danger,
  sitting, pat wriggle, tail wag), scripts/folk/cat.gd (Cat: the bale, porch, garden and washing-line spots, hops up
  and down, garden mousing at night, loaf, ear flicks, purr, gives the dog a berth). main.gd _pets(): the web's E
  prompts and toasts (scratch, stick, every-third fetch line, finds into the pack, dig confetti, cat purrs).
  puppet.gd: lifted paper parts are un-owned first (silences 41 owner warnings per run).
- tools/test_dogcat.gd: the dog follows to 5 m after a 25 m walk, scratch, stick thrown and fetched; the cat on her
  bale 1.15 m up walks off to another spot: PASS. test_critters still PASS.
- Next: 14b2 (calf, saddle horse).
- Step 14b2 done. scripts/folk/calf.gd (Calf: calf.js line for line: the lost day hash, wander 40-70 m into meadow or
  field with the compass word, grazing nose-down, bawl callback by distance, follow / run home through the rails,
  home by nightfall, save/load_state). Wired: the morning note, "[E] Lead the lost calf home", two pails of milk,
  and Old Blue's track now points at it (once a day toast, as the web).
- scripts/folk/horse.gd (Horse): the model mare at 1.7; her tack built as in saddle.js (open half-tube drapes for
  blanket, seat and skirts, cantle and pommel half-discs, horn, fenders, torus stirrups) with the web's canvases
  baked to assets/baked/saddle/{blanket,leather,wood}.png; placed each frame from the spine2/spine_04 skeleton bones;
  seat_rider puts the farmer's Hips bone a hand above the seat and turns her to his facing; whistle (gallop from afar,
  walk the last stretch, up over the rise past 140 m), the dusk walk into the barn stall and out in the morning.
  main.gd _horse(): X to get up / down / whistle, "[X] Get up on Biscuit", oats once a day (+25 %).
- tools/test_calfhorse.gd: calf lost on day 9, 63 m out, led home for +2 milk; mounted (rider 1.42 m up), dismounted,
  whistled from 29 m to 2.2 m: PASS. Screenshot: Jim astride Biscuit with her saddle and stirrup.
- Not yet: sounds (moo, whistle tones, lullaby: step 19), hoof dust (14c/18), the journal entry (18), the save (20).
- Next: 14c (the small wildlife).
- Step 14c done. Baked the leaf and butterfly-wing paintCard prints (assets/baked/wildlife/). scripts/wildlife/ambient.gd
  (Ambient: 70 leaf cards on a MultiMesh with the web's five colours, mulberry32(31337) flutter and respawn, fewer at
  night; 60 fireflies, unshaded HDR beads blinking after dusk; firefly_near / catch_firefly) and butterflies.gd (18,
  left and right wing MultiMeshes flapping on the body crease, the web's loops, out of the rain, gone at dusk).
  main.gd: both updated round the farmer; "[E] Catch the lightning bug in your jar (n/6)" with the web's toasts
  (jar_count; the glowing jar in the hand comes with step 18).
- tools/test_ambient.gd: 18 butterflies and 70 leaves by day, glow 1.0 at night, one bug caught, butterflies gone:
  PASS. Screenshot: leaves drifting over the yard.
- Next: 14c2.
- Step 14c2 done, all in scripts/wildlife/:
  - wake.gd (Wake): six cream rings round-robin; from the shins on every wading footfall (main consumes
    avatar.stepped, with the paper spray) and slowly while he stands in the water; the ducks' V; tossed corn.
  - ducks.gd (Ducks): ducks.js line for line: the family found on open water 12-40 m off, the hen's loop (quicker
    when you or Old Blue come near), ducklings on her trail at 0.55 m strides, bobbing, quacks callback, toss_spot /
    feed. "[E] Toss the ducks some corn" with the web's toast.
  - tumbleweeds.gd: the five slotted ragged discs (the web's LCG seeds 7/31/97), the gust, hop, roll, shoved round
    colliders, gone past 34 m; dry_at = the Breaks (the town joins in step 16).
  - frogs.gd: the bullfrog model baked to one MultiMesh mesh (0.3 m, x2.2), every other lily pad, rise on the spring,
    the leap and plop with ripple rings, croak puffs at dusk.
  - beaver.gd: flat cards laid on the water, loops round the nearest lodge in world.pools.lodge, slap and dive.
  - Old Blue's romp now has prey: a tumbleweed, else the ducks.
- tools/test_pond.gd: the family of 5 on the pond 33 m from the farm, corn tossed (she comes over), 5 frogs on pads
  and one leaps as he nears, a tumbleweed rolls: PASS. (No lodge near the farm, so the beaver wasn't exercised.)
  Screenshot: wading rings round Jim, the duck with her rings, a butterfly.
- Sounds (quack, croak, plop, slap) wait for step 19.
- Next: 14c3 (songbirds, crows and scarecrow, owl, eagle, geese).
- Step 14c3 done, in scripts/wildlife/:
  - model_bake.gd (ModelBake): a prop model baked into one mesh fitted to a length (frogs' recipe, now shared), a still
    seated model, a card laid flat, paper by hex.
  - songbirds.gd: cardinal, bluebird and chickadee models on three MultiMeshes, two of each for the two nearest
    stocked feeders: arrive, perch on the tray or the grass, peck-bob, flit, burst away inside 3.2 m, roost at night.
  - crows.gd: four crows (flat-card backs and beating wings in flight, the reference-art crow landed) into the corn
    and pumpkins every few minutes; a scarecrow within 16 m keeps them off; walk within 7 m and they scatter; left
    alone they carry off a crop each (world.hit). Old Blue barks while they peck. The web's toasts.
  - owl.gd: the three paintCard prints baked (owl_body/face/wing); the card owl glides in to the pen post after dusk,
    the barn owl model sits there, head turning to the farmer, hoot bob, off at dawn.
  - eagle.gd: circles 26 m over the nearest highland or peak, banked, three slow beats now and then.
  - geese.gd: the V of seven every few minutes by day, beating out of step; the first-sight toast.
- tools/test_birds.gd: 5 songbirds perched at a stocked feeder and flushed; crows came, pecked, scattered; geese
  flying; eagle found high ground; owl perched at night: PASS. Screenshot: crows between the corn rows.
- Sounds (caw, honk, hoot) wait for step 19; the kite's spooking of the crows comes with the kite (step 18).
- Next: 14c4 (dandelions, wanderers, the night howl).
- Step 14c4 done (the small wildlife, 14c, is now complete), in scripts/wildlife/:
  - dandelions.gd: the web's outline/art for the seeded clock, the bald nub and a seed baked (dandelion_*.png and
    dandelion.json with the outlines); clumps per 13 m cell within 3 cells (mulberry32 of the web's cell hash),
    meadow only, off the lanes; brushed by the farmer or Old Blue at a run they puff a dozen seeds downwind and go
    bald till morning; the count-the-puffs toast once in 90 s.
  - wanderer.gd: Johnny Appleseed (folk_johnny) on his days (the web's hash), walking the lane west to east round
    the colliders, stopping to face you; "[E] Pass the time of day..." gives 3 apples and plants a sapling by the
    lane (build.add, it grows like yours); the sayings and toasts as the web.
  - night_howl.gd: on a dark dry night out in the country, a coyote puppet trots up onto the highest dry ground
    26-42 m off, sits side-on, nose up, howls twice (callback for step 19), and lopes off over the rise.
- tools/test_meadow.gd: Johnny came on day 5, walked 3 m, gave apples and a sapling; 10 clocks near, one puffed
  (24 seeds aloft, 2 bald); the coyote went come, howl, go: PASS. Screenshots: Johnny by his sapling; seeds
  puffing off a clump beside Old Blue.
- Left for later: his journal entry and talked-day in the save (18, 20); the town's 90 m bound on the howl (16).
- Next: 14d (hunting and fishing).
- Step 14d done (step 14 is complete), in scripts/wildlife/:
  - hunting.gd (Hunting): hunting.js line for line. BOW / REVOLVER / RIFLE specs; aim() casts the camera ray through
    the reticle (NDC y 0.2), picks the game under it widened by the spread, checks the line for trunks, rocks and
    colliders (covered), finds where it meets the ground; loose() leads a runner and lofts the shot; arrows step
    in hand-widths, bury in bark or rock (quiver, then still), stick in the turf, strike game (fell, or wound a
    bison), bullets vanish on a hit; the torn-paper powder smoke (three lobed scraps with a brown rim, facing the
    lens). The reticle is a Control drawn like the web's SVG (cream ring, ink circles, ticks, red draw arc; gold on
    game, grey with a cross when blocked), sized from the web's CSS pixels.
  - fishing.gd (Fishing): fishing.js: cast from the bank or a dock (spot), bobber, the pole from hand to tip, a
    camera-facing twine ribbon on an ImmediateMesh, wait / bite / miss, rain and jumping-fish hurry the bite, Old
    Whiskers after dark, the catch leaping to your hands, ripples. The fish card print baked (fish.png).
  - main.gd _hunt_and_fish(): the web's click routing (fishing takes the click, the bow and guns draw on hold and
    loose on release, the axe swing otherwise; the pole hint), the guns' rounds and reloads (R, cartridges), the
    toasts. player.on_deck is now a member; avatar.start_cast().
- tools/test_hunt.gd: the reticle gold on a deer, the arrow loosed and the deer down, a miss stuck in the turf; the
  six-shooter fired (5 left) with three smoke puffs; cast from a bank, a bite, a fish landed: PASS. Screenshots:
  drawing on the deer (gold reticle); the line and bobber out on the pond with a ripple.
- Left for later: warriors / camp as targets (step 15), the settlers' first-fish note (15), sounds (19), the
  journal (18). Bows and guns are not drawn in Jim's hand yet (tools-in-hand comes with step 18's wear/kit pass).
- Next: 15 (folk, settlers, natives, enemies).
- Step 15a done. scripts/folk/enemies.gd (Enemies): enemies.js line for line (GUARDS, mulberry32(911), spawn per
  site key, lurkers flat on the page or unseen till you're within 3/4 aggro then springing up on the hinge with a
  roar, guard/chase/return/attack with leash, the 0.5 s wind-up with the quivering red "!" badge, the lunge hitting
  at its peak, the flinch, dying folded flat and remembered in world.destroyed, calm_by_site and the "z z" doze;
  the gouger wears the boar's model dyed rust). The "!" and "z z" prints baked. World gained on_site_load /
  on_site_unload; Puppet gained wear_of. main.gd: the keepers' first-meeting lore, being hurt (the coat softens it),
  knocked out and waking at the farmhouse after 3 s, the swing hits the guardian in front ("[LMB] Fight the ..."
  with its hp boxes), arrows and bullets strike guardians, the PEACE offerings in the E chain, Old Blue barks when
  one is near.
- tools/test_enemies.gd: the boar of the nearest grove spawned with its chunk, attacked (100 -> 84), dozed after 3
  apples, beaten with blows (folded, 3 pelts, remembered): PASS. Screenshot: the boar's red "!" over Jim.
- Not yet: the gouger's short uphill legs (bone scaling), sounds (growl), calm_by_site in the save (step 20).
- Next: 15b (settlers).
- Step 15b done. scripts/folk/settlers.gd (Settlers): settlers.js line for line: the 14 SETTLERS on their reference-art
  models (ModelFigure), camps (stone ring and flame) at the farm's edge once a storehouse stands, hiring each their
  own way (wage, help with a chore, arm-wrestle with the E-mashing bar, the tale contest by night, courting with the
  reel and a pie, the deed of a beaten guardian), walking to the nearest work of their trade by day, the trickle
  into a crate on their back (logs or lumps, LOAD 3), hauling it to the storehouse (CAP 30, 45 with casks), home
  at night and in a downpour, supper round the bunkhouse fire, the morning breakfast from the larder (half pace
  unfed), easing apart, hidden past 130 m, rows() for the card, save()/load_state(). FarmExtras gained bunk_face /
  home_for / fire_spot (bunkhouse.js). main.gd: arrivals notes, the join follow-up a beat later, the E chain for
  each way of hiring, the storehouse E/R, the J card, the first-find "Your first X! build a Y" notes (gathering,
  sap, fish, pelts), build.discovered shares settlers.discovered (the Works shelf unlocks).
- tools/test_settlers.gd: a storehouse brings 12 to camp; Silas hired (4 apples + 6 berries), walked to the woodlot,
  worked, hauled a crate (3 wood) to the storehouse, E took it, R stocked the larder; Big Jim beaten at
  arm-wrestling: PASS. Screenshot: the camps by the fields with the arrival note and Ada's prompt.
- Waiting on other steps: the town (16) gives them homes there (town.home_for, the boarding house's newcomers);
  tales_heard fills with tales.js (18); the barn dance sets settlers.danced (16); save (20).
- Next: 15c (the native camps).
- Step 15c done. scripts/folk/natives.gd (NativeCamps + inner Camp): natives.js line for line: three camps sited as the
  web does (seeds 5150/7331/9127, open valleys 240-760 m out, clear of mountains and water) with a 34 m clearing in
  world.exclusions before the chunks are built; 18 painted marker poles; the reference-art lodges (glowing from
  within after dark via their self_fill), cookfire, drying rack, travois, drum, bedroll; the horse picket with three
  horses; three warriors armed as in the art (bow, spear, stone club) and the five camp folk on their models. The
  mood (warn: a warrior comes out, waves you back, an arrow at your feet; fight after 7 s or pushing on; let go
  past the poles), bowmen running to their horses and shooting from the saddle (seat() on the horse's hips/chest
  bones, astride() swinging the thighs over her barrel by turning the leg bones), the club man closing in, arrows
  in flight, a struck warrior falling (back in 40 s), loose horses, the folk sitting by the fire or gathering out of
  the way in a fight, abed at night. main.gd: camp hooks and toasts, arrows/bullets and blows strike warriors, gifts
  at the poles (three days' peace, +2 rope), "[E] Sit at their fire and trade" opens the panel's camp tier.
- tools/test_camps.gd: 3 camps; crossing the poles drew the warning and the arrow at the feet, then the fight
  (bowmen mounted, the farmer hurt), a warrior fell, back over the poles let go, a honey gift bought peace, the fire
  offers trade: PASS (twice). Screenshots: the camp at peace from above; the warning and fight notes.
- Not yet: the Raid on the town (needs the town, step 16); astride() is untested by eye; sounds; camp peace in the
  save (20).
- Next: 15d (the wild lands' landmarks).
- Step 15d done (step 15 is complete). Baked the web's landmark builders in the browser (GLTFExporter; prints as
  "card", colours as "paper", the reference-art meshes recorded as placements): assets/baked/landmarks/{arch,
  steamboat, lookout, schooner, birch, hermit}.glb + .json (radius, colliders, model placements) and info.json
  (LANDMARK_INFO). scripts/world/landmarks.gd (Landmarks): spawn/despawn with their chunks (Babe the Blue Ox as a
  2.3x ox puppet, Old Asa on folk_asa by his lean-to), reached() with the web's radii, the lookout counting only
  from the top, Babe's apples and the minute-apart hint, save/load_state; the landmark colliders now feed Props.
  scripts/world/climbs.gd (Climbs): climb.js (decks flat or curved: the arch's crest, the Belle's listing decks;
  ladders with via points; surface_at, standing, keep_on for railed decks, ladder_at, path, along_path).
  player.gd: climbing along the path (hand over hand on the walk cycle), up on a deck the ground colliders don't
  apply and a railed deck keeps you on. Homestead.bake_materials is now static (shared with the landmarks).
  main.gd: site load/unload routed to landmarks or guardians, the windmill's ladder, "[E] Climb ..." / "[E] Climb
  down", the finds (gifts, Babe's blessing +1 wood a tree, the Grandmother Birch mending you).
- tools/test_landmarks.gd: all 7 uniques spawned and found; the lookout climbed by its ladder to 11.9 m (the find
  only up there); the windmill climbed: PASS. Screenshots: the arch, the Belle, the lookout, the schooner, the
  birch's toadstool ring, Babe, Asa's lean-to (scratchpad lm_*.png).
- Waiting on step 18: the county map (the lookout's view, the hermit's inking, the windmill view), the journal, rumours.
- tools/test_player.gd now picks a clear line to walk (the hen house from step 13 stands in its old straight line):
  walked 11.6 m / sprinted 21.5 m in 2 s: PASS.
- Next: 16 (the town).
- Step 16a done. scripts/town/town.gd (Town): town.js's layout and buildings, ported natively (every building is a
  reference-art model; only the printed cards were baked: the two street sheets, the town sign at every population
  0-19 mended, the street-name signs, the Squatters' Row sign, the assay placard: assets/baked/town/*.png, with
  town.js card()'s plain board back). The site search, flats and exclusions, the new streets' sides and lots;
  model_building (ruined/restored, or the one-state model faded and askew till mended: a new `faded` uniform in the
  card shader), the boardwalk planks, colliders, doors; the assayer (trades_7) with mine_scales and the placard; the
  church; prop_tent tents (lit from within after dark) and the Row's tents in the web's mulberry32(919) order;
  projects / project_at / mend / unmend / rebuild / open_street (sheet, sign, buildings); dress_up (the keepers from
  TOWNSFOLK on their models with hue and scale, company, the flower barrels); dress_street (the freight wagon or ore
  cart, water tower, oxen and the donkey, the stage at the stables, back-lot clutter seeded per building, stovepipe
  spots from the model's box, bunting on a finished street); door lanterns on the new streets; the hitched horses;
  six street lamps with pools of warm light, lit at dusk (the lamplighter's round is 16b); keepers looking up as you
  pass; save/load_state; home_for (settlers now live on Squatters' Row or at the boarding house), spot, near.
  main.gd: the town before the chunks, "[E] Mend the X: $N" with MEND_TEXT and confetti, the new-street toast.
- tools/test_town.gd: the town at (-70.11, 24.64) along (-0.766, 0.643), offsets [32, -32], exactly the web's; the
  store mended at its door ($25, its keeper out), all of Main Street mended opens Second Street; settlers' homes in
  town: PASS. Screenshots: Main Street run-down by day ("Pop. 11 (and falling)"); mended at dusk (lamps lit,
  bunting, barrels, the freight wagon and ox, a horse at the Golden Garter's rail, "Pop. 39 · Welcome, stranger!").
- Approximations: surface_at reads the boardwalk box (the web raycasts the model); stovepipes are spots, not pipes.
- Next: 16b.
- Step 16b done (town.gd part two). Baked the Row's "!" note, the green tick and the five greeting cards
  (assets/baked/town/note, ready, hello_0..4). grow_row(k) with each new street: four tents on the back rank in the
  web's mulberry32(4242) order, the ROW_FOLK on their models, the two-faced spinning note that turns to a tick
  while you carry what they want, want_at / fill (a dollar more when groomed). The families' days: a stroll to a
  neighbour on their own side, in at bedtime or out of a downpour by the tent flap, Sunday meeting rows before the
  church, the fireworks crowd (16c turns it on), easing apart. The greeting card that springs up on its hinge over
  a keeper the first time you pass each day. The lamplighter's round at dusk (prospectors_3 re-dyed), lamps lit one
  by one, or all at once when it's late or you're far. Snowmen (the build system's snowman card) rising on their
  hinges in deep snow. The can-can revue (saloon_2..4) on the Golden Garter's boardwalk after dark. main.gd: "[E]
  Widow Pruitt wants 2 fish ($5)...", the Sunday-morning toast.
- tools/test_town2.gd: 4 families with notes, the tick, paid on E, a keeper's hello, the lamplighter lighting lamps,
  the revue after dark, the Sunday meeting, the snowmen: PASS. Screenshot: Widow Pruitt at her tent on the Row.
- Not yet: the hymn and the bell (audio, 19).
- Next: 16c.
- Step 16c done (town.gd part three). The seven nightly playbills baked (playbill_0..6.png + playbill.json).
  set_playbill (on a post by the opera house, the day's tale), opera_queue (four theatre-goers re-dyed, in line by
  the doors from sundown), dance_hall (two couples swinging round in the street before the doors, the fiddler on
  the boardwalk, his notes through on_note for step 19), _stage (the Overland stage from the reference art with its
  pair, in mid-morning, waiting by the boarding house with its lady passenger out, then turning and away; the
  horn's toast). main.gd: the opera door's E (read the playbill, a $3 seat, an hour passes, rested and fed).
- tools/test_town3.gd: the stage waited with its passenger; the playbill; the queue at sundown; a seat bought;
  the dance hall's couples and fiddler: PASS. Screenshots: the stagecoach waiting on Main Street; the dance hall at
  night with the opera's toast.
- Next: 16d.
- Step 16d done (step 16, the town, is complete).
  - scripts/town/barn_dance.gd (BarnDance): barndance.js: dance nights (fair day and three days after), 17:30 to
    03:00, in the street before the livery barn (town.spot(-1, 1.2, -1, -8)); the floor folds up off the page on
    its hinge, three couples (farmhands and calico women) whirling, the fiddler sitting on his bale, two poles and
    15 paper lanterns glowing by night with a warm OmniLight; the reel's notes via on_note (step 19). main.gd:
    "[E] Join the barn dance" (5 s swinging round, rested; settlers.danced for Clementine).
  - scripts/world/fireworks.gd (Fireworks): fireworks.js, 240 cut-paper stars on a MultiMesh, rockets with sparks,
    bursts on a sphere, drag and drift, facing the lens; Saturday evening with every street mended, from the field
    behind the church; the Row's crowd turns out (town.fireworks_on).
  - scripts/world/fire_smoke.gd (FireSmoke): firesmoke.js, cream paper puffs over the nearest three fires (campfires,
    the forge's chimney, the camps' cookfires, the bunkhouse supper fire, the town's stovepipes by their hours),
    lit through by day, and sparks after dusk.
  - natives.gd Raid: the war party of three from the nearest camp not at peace, riding at a mended building,
    circling it loosing arrows (seated astride), two brought down and the last wheels away (+$10), 22 s of circling
    and the building is wrecked (town.unmend, half-cost mending); NativeCamps.start_raid; raiders as targets for
    arrows and blows. main.gd: _raid_tick every few days by day while you're within 220 m; the raid toasts.
- tools/test_town4.gd: the dance up on a dance night and joined; smoke over a campfire; a raid circled the store,
  was driven off (+$10); a second wrecked it; Saturday fireworks (40+ stars): PASS. Screenshots: the barn dance under
  its lanterns; a raider by the General Store; rockets bursting over the church with the town turned out.
- Not yet: the WANTED poster (with the bounty, step 18); all the town's sounds (19).
- Next: 17 (railroad, train, trading posts, telegraph, gold claim; and the town's trade doors).
- Step 17a done. main.gd _town_doors(): main.js's door-by-door E chain for the mended town: the assay office ($4 a
  pinch, $5 silver, a tenth more groomed; fortune feeds homestead.set_fortune), panning the shallows (the pan in his
  hand, 2.6 s swirl, richer in the Breaks and pines and when blessed, the first-gold note), the store / bakery / feed
  / dry goods / cooperage / smithy / bank opening the crafting panel (station_checks and the panel's *_open tiers at
  3.2 m), the sheriff's bounty (the nearest unbeaten den 60-320 m from town, pay by its guardians, paid once every
  guardian there is beaten; the WANTED poster printed in Georgia on an offscreen SubViewport laid on the card), the
  barber (groomedDay), the Grand Hotel ($4 room, wake fed), the telegraph's daily wire (MARKET), the dance hall's reel
  (stamina boost), the stage line to any found landmark and the coach home ($3, Q for the next stop), the church's
  blessing, Miss Dolly's word and the saloon's supper with the old-timer's tip, the livery's horse ($35).
- tools/test_doors.gd: every door (assay, store, bounty posted and paid, barber, wire, church, saloon, livery, stage
  out and home, hotel, panning): PASS. Screenshot: the WANTED poster by the jail, "Old bramble boar, $17 REWARD".
- Waiting on step 18: the county map marks (bounty den, the old-timer's tip, the stage passenger's news), the
  journal, the fortune card in the HUD.
- Next: 17b.
- Step 17b done.
  - The train's four cars baked from the web's builders with their printed flanks (assets/baked/rail/locomotive,
    tender, boxcar, coach.glb), the depot sign, each whistle-stop's name board and trading-post sign (rail/*.png).
  - scripts/rail/railroad.gd (Railroad): railroad.js natively (so a new game's own seed gets its own line): the
    whistle-stops searched ring by ring, the route stop to stop swinging wide of the town and the farm, sampled per
    tie, the right-of-way and each stop's post (and the Breaks' claim plot) cleared in world.exclusions before the
    chunks; build(): ties on a MultiMesh, trestle legs over water, the iron rails, telegraph poles with insulators
    and sagging wires, the depot (the telegraph model on its platform, the sign), each stop's platform and board,
    the trading post (the cottage model, barrel, crates, plank walk, sign) with its keeper re-dyed out front by day;
    post_at, freight crates on the platform (add_freight / take_freight), save.
  - scripts/rail/train.gd (Train): train.js's timetable (out at 0.33 and 0.6, dwell 18 s, out to the end and home),
    the cars coupled along the line, nudging you off the track, stack smoke, stopped_at, ride_point, next_stop_name,
    depart; chuff and whistle callbacks for step 19.
  - main.gd: the railroad laid the day every street is mended (with the web's note), the freight office and trading
    posts in the crafting panel (stations depot and post-<land>; a depot craft puts a crate out), boarding ($1,
    leaving at once from the depot), riding the back platform, stepping off at a stop, the daily rush order over the
    wire and its lapse, and the Miners' bank's morning interest.
- tools/test_rail.gd: the depot and the five stops exactly where the web lays them (700 ties); built when the town
  was mended; boarded at the depot with the freight taken, rode to the Redrock Breaks and stepped off; its trading
  post opened the panel; a rush order came in: PASS. Screenshots: the coach and boxcar at the depot; No. 7 at the
  Redrock Breaks stop beside its trading post.
- Next: 17c (the gold claim and the opening glint).

### 17c. The gold claim and the opening glint (2026-11-22)
- scripts/rail/claim.gd (Claim, claim.js): staked out at the Breaks stop's geo.claim (-132.66, 125.08, the same as
  the web) once the line is down and tools has "claim": the adit, windlass, ore cart and tool rack (props scaled by
  their larger footprint, the rack by height), the plank track, four corner stakes with red rags, the NOTICE card
  (baked from TW.card, seed 1900: assets/baked/rail/claim_notice.png) on its post. dig() once a day (2 + mill + iron
  pick + steel pick + 30% of 1; silver at 35%); hire() puts up the tent and the hand (prospectors_6, hue 0.8) who works
  by day near you and banks his takings in the cart each new day (cap 15, 25 with the mill); add_mill() puts up the
  stamp mill, which shudders on each thump (on_thump(dist) is ready for step 19's sound).
- main.gd: build/hire/mill from tools in _rail; E at the adit first in _rail_doors (empty the cart, else "You need a
  pickaxe", else dig or the worked-today toast), prompts as the web.
- The opening glint: three flat-shaded gold dodecahedra (built in _dodeca) a few steps from the porch, twinkling
  every 0.9-1.5 s, hopping clear of anything built over it, the opening toast, E within 2.3 m: +2 gold, discover
  gold, the GOLD! toast. opening_done will come from the save in step 20; the next-goal line waits for step 18's HUD.
- tools/test_claim.gd: glint picked up (+2), claim staked, no dig without a pick, dug once a day, hand and mill, the
  cart emptied next day (5 gold): PASS; test_rail, test_doors and test_dogcat still PASS.
- Next: 18 (remaining systems).

### 18a. The tinker, the County Fair, Grandma Pell (2026-11-22)
- Step 18 split into 18a-18e (see the plan above).
- scripts/town/tinker.gd (Tinker): the covered wagon (veh_covered_wagon, 5.2 m) at town.spot(-19, -3.4) with the
  TINKER & SUNDRIES board (baked panelArt: assets/baked/homestead/tinker_board.png) and folk_tinker beside it; every
  even day 07:00-18:00, hinging up with spring_rise and folding flat as he leaves; his arrival toast carries the day's
  request (crafting.new_request). E within 4.2 m opens the panel; station "tinker" is near().
- scripts/town/fair.gd (Fair): every seventh day 07:00-19:00 at town.spot(15, 0, 0, 0): trestle, gingham cloth
  (baked; triplanar), pie/jar/fleece/pumpkin, bunting in three colours, the COUNTY FAIR sign (baked), Mrs. Pruitt
  (townsfolk_1); the day's toast; E within 3.2 m opens the panel's County Fair tier; one entry per class per fair;
  every ribbon pins a rosette (baked paintCard, seed 193) under the porch awning, re-pinned by raycasting the
  house model's triangles near the porch (homestead.on_house_model).
- scripts/home/grandma.gd (Grandma): her cut-paper shadow (baked canvas) rocking in the front window 18:30-22:30;
  knock (E) for a pie once a night; her wish of the day (wish_for: the web's uint32 hash) bakes you something back;
  all the web's prompts and lines.
- Town.board(): a full-bleed print (sign, painted board) as a card, padded so CardMesh's 4% UV margin lands on the edge.
- Fixed: homestead.json's frontWindow, frontDoor and vaneAt had the farm centre subtracted twice (they come from
  the house's world matrix); now (3.74, 2.1, -3.60), (5.39, 1.15, -3.43), (-9.59, 7.19, -6.82), which puts the window,
  door and weathervane where the web has them (checked against the web game's world positions).
- tools/test_visitors.gd: the tinker on day 2 (prompt, panel), gone on day 7; the fair up, its panel, the pie entry
  (ribbon, rosette shown, once only), the fair toast; Grandma's pie, "one slice is plenty", her wish, her shadow: PASS.
  test_extras and test_doors still PASS. Not yet: the almanac lines for the tinker/fair/Grandma (18b), sounds (19),
  saving fair entries, ribbons, pie and wish days (20).
- Next: 18b (mail, tall tales, the journal tally and the almanac).

### 18b. The mail, tall tales, the journal and the almanac (2026-11-22)
- scripts/core/journal.gd (Journal): journal.js's 62 old goals (converted from the source; none are shown or
  rewarded, as the web), progress/done for saves, and the day's log every record() lands in; almanac_lines() is
  main.js's almanacLines word for word. journal.record() is wired at the web's events: chop/mine/pick and every
  gather, satchel, craft:<id>, build:<type>, request, ribbon, fair, tinker, letter, tale, sleep, shoo, fetch,
  legendfish, slay, skep, star, calf, dance, growtree, giant, cider, feeder, livestock, wish, grandma, night, the glint.
- scripts/home/mail.gd (Mail, letters and notes converted from mail.js): the carrier from Day 2 at 09:00, the flag
  (the homestead model's "mailflag" node) swinging up with spring_rise; E at the box reads the letter (its gift
  lands in the pack), the toast within 45 m.
- scripts/core/tales.gd (Tales, the six tales from tales.js): E at a campfire after dark tells one (unheard
  first), an hour passes, +20 health; Old Cyrus's tale contest now counts tales.heard.
- Hud: a centre story card (index.html #story/#letter/#almanac: 470 px, tilted -0.7°, 27 px heading over a rule,
  19 px text, a list, a 14 px footnote) and the almanac card (H, #calendar: a 7-day grid with Today tilted and
  tinted, the coloured doings, the notes). Waking from sleep shows "Day N, as the almanac tells it" for 12 s
  (E closes) and clears the day's log. _render_calendar() is renderCalendar's notes in order.
- tools/test_journal.gd: no mail on day 1, the flag up on day 2, the letter read (+2 rope), folded away; a tale at
  a campfire at 20:24 (an hour on, health mended, counted); the almanac's day; H opens and folds the almanac: PASS.
  test_extras, test_build, test_visitors, test_birds and test_enemies still PASS. Saving the mail, tales, journal
  and day log comes with step 20.
- Next: 18c (the county map and its marks, rumour notes, the fingerpost).

### 18c. The county map, rumour notes, the fingerpost (2026-11-22)
- scripts/ui/county_map.gd (CountyMap, in a Hud centre card "The County, as you know it", M or Tab): map.js drawn
  with Control._draw: 16 m explored cells (SEE 3) round you; the watercolour wash (140² samples of region_at and
  land_tint with the ragged hash jitter) drawn behind the ink through a small Gaussian blur shader plus a 35% sharp
  pass; fibre specks; the wild lands lettered; Paydirt Hollow's streets, false fronts and pinned name chit (pop.);
  the tinker, orchards, your camps and yard glyphs, the fair, a fallen star, veins (faint "Iron?" from the assayer),
  thickets, hives, landmarks (named once found), the wild lands' treasures, the camps' red-dashed lands; your arrow;
  the home-place inset; compass and scale; margin arrows to iron, their land and home; the home badge on top.
- Marks inked onto the map: the sheriff's bounty den, the saloon old-timer's tip, the stage passenger's landmark
  (her E and lines are now ported too), the lookout's view (reveal 150), the hermit's every landmark (mapAll), and
  the windmill platform's view of the home place (110 m, once a day).
- Props.site_cache / sites_for(): every place() call (the world's chunks included) caches the chunk's sites and its
  orchard's middle (main.js world.sitesFor/orchardFor). Laying a chunk out costs ~26 ms in GDScript (9 s for the
  sheet), so the map reads the cache, lays out only explored chunks it lacks, and adds faint unexplored iron once the
  rumour scan has reached it. Opening the map: ~200-300 ms.
- scripts/core/rumours.gd (Rumours): rumour.js; the goals are retired, so the talk is always of the nearest unseen
  landmark; the scan reads cached chunks up to 12 a frame and lays a fresh one out at most every third frame (it was
  slowing the first seconds). The note sits under NEXT (#rumour: 230 px, arrow turning to the on-screen direction).
- scripts/town/signpost.gd (Signpost): the fingerpost at (-25.06, -16.56) as the web, its six lettered boards
  (front and mirrored back) and their bearings baked from the web scene (assets/baked/town/fingerpost_*.png, .json).
- tools/test_map.gd: walking the lane explores the cells; the rumour (Babe the Blue Ox, 230 paces); the map opens
  and folds; the stage passenger sketches the Belle of the Fen onto it; the fingerpost: PASS. test_town3 (after the
  scan throttle), test_doors, test_journal and test_landmarks still PASS.
- Left for later: the land names' 3 px letter-spacing (Godot has no per-string tracking; drawn unspaced); saving the
  explored cells (step 20); a worker thread for chunk layout would make the scan free (step 20's performance pass).
- Next: 18d (the kite, snow footprints, leaf piles, fairy rings, sun shafts, the will-o'-the-wisp, hoof dust).

### 18d. The kite, footprints, leaf piles, fairy rings, sunbeams, the wisp, hoof dust (2026-11-22)
- scripts/wildlife/kite.gd (Kite, kite.js): the patchwork diamond and its six-bow tail (baked paintCards
  wildlife/kite.png, kite_bow.png; the bows tinted per instance), the sagging twine (ImmediateMesh line strip);
  G lets it up / reels it in (needs the kite tool), rain brings it down; the crows shy off the garden while it's up.
- scripts/wildlife/footprints.gd (Footprints): boot soles left and right a stride apart (hoofprints two by two
  riding), Old Blue's paw prints, blue-grey dents (not paper stock, so the snow doesn't whiten them), filling in
  over 35 s; nothing without snow.
- scripts/wildlife/leaf_piles.gd (LeafPiles): four raked heaps of 46 leaves round the farm (seed 243, baked leaf
  print, six autumn tints); run or let Old Blue barrel through and they burst, flutter down, lie, and skitter home.
- scripts/wildlife/fairy_ring.gd (FairyRing): rain in the night brings a ring of nine toadstools (crossed baked
  cards) 25-50 m off by morning, hinging up one by one; E in the middle gathers it (6 mushrooms; 35% honey + iron).
- scripts/wildlife/shafts.gd (Shafts): twelve tissue-paper sunbeams along the key light's direction, axial
  billboards in one MultiMesh, an additive shader with soft torn sides, paler threads and a fade near the lens;
  brightest in low gold light, nothing at night or in rain, more in forest.
- scripts/wildlife/wisp.gd (Wisp): by night it searches 9x9 chunks for an unopened lost satchel (two a frame, via
  Props.site_cache, which now also keeps each chunk's satchels and their world keys) and leads you to it.
- scripts/wildlife/hoof_dust.gd (HoofDust): tan paper puffs behind a loping horse on dry ground.
- tools/test_paper.gd: the kite up and down; a leaf pile kicked (46 leaves flying); snow footprints; a fairy ring
  sprouted and gathered; sunbeams in a wood at 07:12 (strength 0.107); hoof dust; the wisp leading to a real
  satchel (-147.6, 8.1): PASS. test_birds, test_dogcat, test_map and test_extras still PASS.
- Sounds (rustle, tear, lullaby) come with step 19.
- Next: 18e (HUD leftovers: the NEXT line, the fortune readout, tools in hand; anything else main.js still has).

### 18e. HUD leftovers and the tools in hand (2026-11-22); step 18 done
- NEXT (main.js updateNext, every 0.5 s): hunger first (urgent: the red-edged pink card with its nudge), the glint,
  the assayer, a root cellar, a bunkhouse, the cheapest affordable mend in town, then the gold road (workbench,
  pickaxe, iron ore, forge, iron, iron pickaxe) and today's doings (meeting, fair, fireworks, barn dance).
- The homeward chip by the clock (#homeward): past 90 m a red house and an arrow turning with your view, "Home, N
  paces"; carrying gold, a nugget and "Assay office (N pinches), N paces" once you're 20 m from his door. The poke
  (#fortune): "$N in your poke" once you've any money or fortune.
- avatar.gd: the tools in his closed fist, placed each frame from the right hand bone (avatar.js holdTools): the
  felling axe, pickaxe, claw hammer (in build mode), ash spear, willow pole and the hickory bow (a stave of 14 rods
  along the web's torus arc, with its string); the six-shooter and buffalo rifle at the hand in the body's frame,
  pointing ahead and down, level while aiming; the skin-tone fist round the haft; the quiver slung on the upper
  spine once he owns a bow (tube, bands, three fletched arrows). Not done: drawing the model's fingers in (the web
  scales the hand bone; the fist covers it).
- The lightning-bug jar hangs below his left hand once crafted, its core and OmniLight glowing with the catch (by
  night). Better than the web, where the jar is parented to a detached arm stub on the model figure and never shows.
- Performance: the rumour scan laid a chunk out every third frame, and near home a layout costs 30-90 ms, so frames
  averaged 36 ms (and test_player, test_hunt and test_calfhorse failed on timing). The talk is always of landmarks
  now (the goals are retired), and those come straight off Props.unique_encounters(): 7 ms a frame. The wisp guesses
  each chunk's satchel from its own seed (Props.satchel_guess, nine chunks a frame) and confirms its pick with one
  real layout. The county map's faint "Iron?" marks now come only from chunks already laid out (the world's), not
  the whole sheet; the full sheet waits for a threaded layout in step 20's performance pass.
- tools/test_hud.gd: NEXT (glint, urgent hunger, the road), the homeward chip and the assay variant, the poke; the
  axe, bow and quiver, six-shooter in his fist; the jar glowing at night: PASS. Rerun: test_hunt, test_player,
  test_calfhorse, test_map, test_paper, test_town3, test_build, test_doors PASS. (test_paper failed once from its
  own random placement and passed twice after.)
- Next: 19 (audio synth and all sounds and music).

### 19a. Sound: the engine, ambience, music and the core sounds (2026-11-22)
- How: the web synthesises everything live with WebAudio (no sample files). Rather than re-synthesise in GDScript,
  the web's own audio.js Sound runs on an OfflineAudioContext in the browser pane, with the same bus gains, 2.2 s
  convolution room, sfx reverb send and tanh limiter as Sound.start(), and every sound is rendered to a 44.1 kHz
  stereo WAV (silence trimmed): assets/baked/sound/*.wav, 175 files, 40 MB (tools/bake_server.py now takes .wav).
  Random sounds have 2-8 variants (mine, pick, steps per surface, tear, quack, thunder, birds...). Volume arguments
  (distance falloffs) scale the baked level linearly, as the web's gain does. The town's pitched notes are baked
  exactly: the reel's fiddle notes (and +5 for the dance hall), the hymn's 17 notes (hymn.json keeps the tune), the
  saloon piano's eight notes and their octave-down, the dawn bell's three partials.
- The four tunes are rendered whole (sunup 22.6 s, hayfield 19.7 s, porch 33.6 s, lullaby 27.5 s), chosen by the
  time of day, then a quiet spell of 12-26 s, as musicBox does.
- The beds that never stop are white noise through Godot filter buses (Wind band-pass by land and gust, Water
  low-pass with its swell, Rain band-pass, 900 Hz under a roof), steered with audio.js's time constants. Their levels
  were measured, not guessed: each bed recorded off Godot's master (AudioEffectRecord) against the same bed rendered
  by WebAudio offline: rain 0.0213 vs 0.0209 RMS, wind 0.0024 vs 0.0024, water 0.0138 vs 0.0136 (the lowpass's
  resonance set to 1.25 to match WebAudio's 1 dB Q bump).
- scripts/core/sound.gd (Sound): the bank (variants by name), a 32-voice pool, delayed one-shots, mute (N),
  update() = audio.js update (land voices every 5-14 s, birds, crickets, crackle by a fire, the music box).
- Wired: every creature hook (frogs, owl, calf, ducks, turkeys, beaver, geese, crows, cat, dog, guardians' growl),
  train whistle and chuff, the claim's stamps, storm thunder, fireworks, the coyote howl (now also only 90 m out of
  town, as the web), the fiddlers, Sunday's hymn, the dawn bell, the saloon piano, the rooster at sunup, footsteps
  (wood, wading, snow, grass), gathering (mine/pick/chop, tree fall), building (place, denied, tear on removal), the
  tool bar (click, denied), eating, crafting (craft; a fair ribbon plays the lullaby), the pack/map/almanac/settlers
  cards (tear), fishing (cast splash, bite), the hunting arrow's thunk. Also ported here: crossing into a wild land
  (its name and lore the first time, "Back in ..." after, the home county; journal "land").
- tools/test_sound.gd: 230 bank entries; footsteps while walking; a chop at a tree; the sunup tune; the rain bed
  rising; real audio on the master (RMS 0.0175); N mutes; walking into the pines names them: PASS. test_player,
  test_build, test_hunt, test_town3, test_extras PASS. test_pond FAILS on feeding the ducks: the panning prompt
  (step 17a) takes the E first; in the web both happen on the same press. Left for 19b.
- Left (19b): the one-off calls the web makes beside its toasts and E actions (lullaby for a fallen star, peace,
  Grandma's wish, the hotel; craft for mending, hiring, landmarks, the opera, the stage; pick for apples, cider, the
  ring, letters, panning colour; knock when hurt; place for ladders, the poster, mounting; bang/knock/tear for the
  guns; the horse call; the hunting hits; plop for maple sap...).

### 19b. The rest of the sound calls, and what turned up missing on the way (2026-11-22)
- Every sound.X() call site in main.js (152) was listed with its toast or journal anchor and matched to main.gd;
  the 19a ones were already in, the rest went in here (a script asserting each anchor, none missed): the guardians'
  ambush (growl + tear), blows (chop) and defeat (tear); being hurt (knock); warriors and raiders falling (knock);
  an arrow striking a warrior (land); dressing game, landing a fish (pick), Old Whiskers (craft); the dog's find
  (woof); the wisp (lullaby); guns (bang, the reload's knock, "Click. Out of cartridges" denied); panning (a slosh,
  then a pick for colour); the assayer, the bounty paid, the poster (place), the barber, the hotel (lullaby), the
  wire, the dance hall, the stage (craft; Q's click), the saloon, the livery horse, the opera, mending (craft), a
  townsfolk want (craft, or a click); the horse mounted and left (place), called (the two-note whistle); maple sap
  (plop); a satchel (craft); the wrong tool (denied); a warrior struck (chop); your apple tree, skeps, cider, the
  root cellar's food, eggs, milking (pick), shearing (tear), the giant pumpkin (chop to cut, pick to tend), the
  woodpile (chop), the feeder, the grindstone (mine), the cellar and bunkhouse built (craft); a tale, a fallen
  star, the calf home, Grandma, the bed, peace with a guardian (lullaby); the glint, the windmill view, the stage
  passenger, a camp's peace (craft); ladders (place); the ring, a letter, fireflies, the larder and storehouse,
  Johnny's apples (pick); settlers won over (craft), the arm-wrestle (knock, craft); Old Blue's stick, the kite
  (tear); leaves (rustle).
- Ported because they were missing: striking your own built pieces (the nearer of a resource and a piece is the
  target, as main.js; a knock or a stone chip each blow, "[LMB] Break ..." with its hp, broken: a tear, "Broke ...
  (+refund)"); the wild treasures' first-find lore (TREASURE_LORE: sang, silver, pearls, thunder eggs, amber); a
  resource used up bursting into paper chips (world.on_resource_gone; a rock tears); journal events that rode with
  the sounds (wire, stage, saloon, horse, opera, mend, tend, peace, firefly, eggs).
- The ducks-vs-panning clash: wading with corn by the ducks, E feeds them (panning steps aside), so test_pond PASSES
  again. (In the web one press does both; here the ducks' toss wins, which reads better.)
- Not ported (no web feature left behind it): the photo-postcard click and the time-of-day chips (web debug UI), the
  dev cash key, the journal goal-complete chime (the goals are retired).
- tools/test_sound2.gd: a workbench struck till it breaks (knocks, a tear, 8 wood back), a maple tapped (plop, +1
  sap), the kite (tear): PASS. test_pond PASS.

### 20a. Save and load (2026-11-22)
- One JSON in user://paperfjord.builds.v1.json, in the same shape as the web's localStorage "paperfjord.builds.v1"
  (pieces, inventory and every extraSave key: settlers, world, opening, fortune, horse, town, cellar, bunkhouse,
  tools, held, fullness, lands, landmarks, wear, journal, dayLog, beaten, explored, tales, mail, fair, grandmaPie,
  grandmaWish, johnnyTalked, calf, campPeace, railroad, wire, claimDay, claim, bounty, calm, dogDay, request,
  almanac, chores). Saved every 30 s (as the web), after a night's sleep, and when the window closes.
- New games roll a world seed of their own with the near ring (60, 115), as the web; a save keeps its world. Old
  web saves without "world" fall back to 20261120 / (130, 210) the same way.
- Loading follows main.js's order: what must be known before the world is built (seed, inventory, tools, held,
  fortune, horse, wear, lands) first; the rest once the systems exist: beaten guardians, found satchels and the
  road's felled trees stay gone (the strip 7 m either side of the farm-to-town line, as main.js's onRoad); the clock
  and the hens; the town's tiers and streets (quietly: the web hooks the street toast up after its load); the bounty
  poster; the cellar and bunkhouse; landmarks; the map; tales, letters, fair entries, the herd's chores, Grandma,
  Johnny, the calf, the journal and day log; dozing guardians; settlers; Old Blue's dig; the camps' peace; the
  railroad with its freight and any standing wire; the claim; fullness; your pieces; the ribbons; Biscuit.
- Not saved, as in the web: where you stand (a load wakes you at the farm).
- Test runs (--script) keep the original world and never touch the player's save unless a test sets save_path and
  saving (so every older test still sees the world it was written for).
- tools/test_save.gd: a game set up (17 wood, $41, a pickaxe in hand, fortune 33, a workbench, the town mended, Day
  5 noon, two letters read, a tale, explored cells, the fen found, a guardian beaten, Grandma's pie, the railroad
  with two crates) saved, thrown away and loaded fresh: everything back, the same seed, no glint: PASS.
- Next: 20b (side-by-side screenshots with the web version).

### 20b. Side by side with the web (2026-11-22)
- The web game's own save (the browser pane's localStorage, Day 28, the original world) is a fixture:
  assets/baked/compare/web_save.json. (The pane's save was backed up before and restored after each capture, and the
  tab reloaded, so the web game's progress is untouched.) tools/compare_views.gd loads it into Godot through the 20a
  loader and frames four views by player spot, camera yaw/pitch/distance and clock: the farm at 07:40, Main Street at
  noon, the Redrock Breaks stop at 13:10, the farm at 21:50; the web views are taken with the same numbers.
- Matching: framing (the web camera lands at (1.64, 8.80, -10.89) for view 1, Godot at (1.61, 8.72, -10.87)), the
  buildings, props, critters, the HUD's cards and readouts (Day 28, the assay chip, the rumour, the ledger), the
  occlusion ghosts (the same three trees fade, to the web's 0.82 stipple, once their chunk has risen).
- Not a difference: the web's big near trees look see-through in its captures; that's its noisier tilt-shift
  sampling, not occlusion (the web ducks the same three trees, not those).
- Found and fixed: the lightning-bug jar's light skipped the 1/pi every other light carries (18e), so it was ~3x
  too bright.
- Open (20d): near the yard lanterns at night the web's light is warmer. Same view, region averages: hay web
  (198,117,49) vs Godot (183,136,93); ground web (149,111,105) vs Godot (137,117,121). The lantern itself matches
  (one OmniLight each, 0xffb070, 4.5/pi, decay 1, range 11, the same as the web's PointLight), so it's the night
  ambient's balance against the lamps.

### 20c. Performance pass (2026-11-22)
- tools/perf_walk.gd walks the farmer at 6 m/s along six legs (the farm by morning, the lane, Main Street at noon,
  the woods north, out into the wilds, the farm at night) and reports per leg the average, 95th percentile and worst
  frame, draw calls and objects; main.gd's _process now carries section stamps (_pm, free unless a profiler sets
  main.prof) so it also reports which systems took the time, and frames over 40 ms are broken down.
- Steady state was already fine: ~7 ms a frame everywhere (RTX 4090), 270-460 draw calls. The trouble was hitches of
  50-160 ms walking into new country. Found and fixed, measured each time:
  - Building a chunk at once (~70 ms: the terrain heights 47 ms in GDScript noise, the region map 10 ms, the props'
    layout 16 ms): now a coroutine, Terrain.chunk_job/chunk_step and World._paint_row slicing the heights and the
    region map into ~4 ms a frame; the props and instancing finish it. (fill_around stays all-at-once for loads and
    screenshots.) world.update over the walk: 11.8 s -> 3.7 s.
  - The first prop of a kind building its MultiMesh and material on the spot (52-131 ms when a chunk brought several
    new kinds): World.prewarm() builds every pool after startup, one a frame.
  - A guarded site's guardians or a landmark loading their GLB from disk the first time (93-117 ms): every model the
    county can bring on (folk, animals, props, landmarks, the train) is requested on background threads at startup
    (ResourceLoader.load_threaded_request) and kept, as the web loads its models up front.
- After: worst frames 27-50 ms on every leg (was 51-161), averages unchanged (7.0-8.8 ms).
- Left: a ~44 ms hitch when a herd's puppets are made (instantiation and animation set-up; could be pooled); the farm
  at night has a p95 of 19 ms against 9 by day (the lamps and fireflies: worth a look with the GPU profiler); the
  county map's faint unexplored iron still waits on chunks the world has laid out (laying out off-sheet chunks costs
  ~16 ms each in GDScript; a worker thread would need Terrain's caches made thread-safe).

### 20d. Night grading near the lamps (2026-11-22)
- Measured, not eyeballed: the same night views captured from both at 1600x900 (the web's save backed up and
  restored around each capture), region averages compared (tools/probe_dark.gd, tools/probe_lamp.gd).
- The night itself matches: Godot's sky at 22:05 gives hemisphere 1.43, moon 0.51 (= the web's 1.6 / pi), fill 0.26
  (= 0.83 / pi), exposure 1.75 (the web's eases to the same 1.4 x 1.25); open ground far from any lamp reads navy in
  both, and the unlit ground beside the yard lantern is web (112,94,106) vs Godot (97,78,98).
- The lamps' light was whiter in Godot: by the lantern's foot web (170,116,96) vs Godot (189,137,113), green and
  blue too high. Scaling the energy only dimmed it grey (k 0.5: (147,113,109)); giving the light its colour as
  linear (srgb_to_linear, i.e. three's own conversion of 0xffb070) brought the warm cast across: (188,106,104), the
  hay behind it (169,109,69) against the web's (199,111,47). Godot plainly uses an omni light's colour as linear
  here, so every point light now takes its colour converted: the yard lanterns, built lanterns, campfires and the
  forge, the jar, the barn dance's lantern, the fallen star.
- Left: the patch of ground nearest the camera reads whiter in Godot (web (146,105,98) vs Godot (177,140,143)) and
  doesn't follow the lamp's energy, so it isn't the lamp; the sun, fill and moon colours (PAL) are still passed as
  sRGB and could carry the same conversion, which a daylight side-by-side should decide before changing.

### 21a. The key and fill colours in daylight (2026-11-22)
- Main Street at noon, region averages web vs Godot as it is vs Godot with the sun and fill colours linearised (as
  20d did for the point lights): street (232,132,30) / (225,129,32) / (226,110,13), the lit street (220,144,56) /
  (213,131,45) / (217,112,25), the boardwalk (205,131,53) / (176,113,44) / (181,97,21). Total error 188 as it is
  against 304 linearised (and 318 vs 470 on the farm view), so the key and fill keep their colours as they are.
- The sky's numbers agree at 07:43 (sun 3.8 ffdaaf / 3.8 ffdaad, fill 0.38 f2dcc2, hemisphere 0.88, exposure 1.4;
  Godot's energies carry the 1/pi). The morning farm view reading ~15% darker is the web capture's camera not yet
  turned to the asked yaw (20b), not the light.
- So in Godot 4.7 a directional light's colour behaves as sRGB here and an omni light's as linear; each kind now
  takes the colour that matches the web (sky.gd and PORT.md 20d note why).
- (20c follow-up) A hang the regression run caught: test_paper froze ~13 s in (exit 124, no output). The model preload
  had every GLB requested at once with sub-threads, and a main-thread load() of a model still in that pile could
  stall for good. Now at most four requests are in flight, without sub-threads, skipping anything already cached.
  test_paper PASSES twice in a row, and the walk is unchanged (worst frames 29-38 ms, averages 7.0-8.7 ms).
- Regression run after 20c/20d: player, build, gather, hunt, calfhorse, map, sound, save, town3, landmarks, enemies,
  doors, pond, rail and (after the fix) paper all PASS.

### 21b. The whiter near ground at night (2026-11-22)
- A measuring error, not the game: the "front" patch (480-600, 300-340 of an 800x450 frame) sat under Godot's toast
  card (the opening's "You came west..." note, cream paper), while the web's toast stood lower that night. On clear
  ground the near field matches: right web (120,97,103) vs Godot (122,91,112); left, nearer the lamp, web
  (141,109,106) vs Godot (160,104,117); mid ground web (114,95,105) vs Godot (106,84,105). Nothing to change.
- Lesson kept for later comparisons: sample regions clear of every HUD card on both sides.

### 21c. The herd hitch (2026-11-22)
- A bison herd (4-5) or turkey flock (3-4) was made in one frame, each Puppet (model, rig, animations) ~10 ms: the
  44 ms _livestock spike. Critters now queue a herd's members and make them one a frame (critters.pending; manage()
  counts queued kinds as present so no second herd starts), and a critter that wanders out of range or is dressed
  goes back into a pool by kind (up to six, hidden) to be reused with its fold, scale, heading and gait reset, so a
  herd met again costs nothing to make.
- perf_walk after: no frame over 40 ms on any leg; Main Street's worst 50 -> 20 ms; averages unchanged.
- test_hunt, test_calfhorse, test_dogcat PASS. test_meadow had been failing since 19a brought the coyote howl's
  condition in line with the web (90 m out of town as well as 45 m from the middle); its spot is now picked away from
  town too: PASS.

### 21d. The night farm's frame times (2026-11-22)
- tools/probe_nightperf.gd stands at the farm at a given hour after settling, walks the morning leg's path, then
  measures with each night suspect switched off in turn (the five lit OmniLights, the fireflies, the night sky,
  bloom, SSAO, the moon's shadows). At 22:48 and at 08:10 alike: standing avg 6.9 ms, p95 7.0; walking avg 7.0,
  p95 7.2, worst ~22; switching any suspect off changes nothing measurable. Night costs nothing extra.
- The walk's night leg (p95 19.6) was the route, not the night: it starts with a jump from the wilds back to the farm,
  so the farm's ~16 dropped chunks rebuild during it (world.update 1.05 ms a frame against 0.24 on the morning leg;
  perf_walk now prints each leg's top sections per frame). Riding the train or the stage home does the same for a
  few seconds: each chunk's prop layout and instancing (~16-25 ms) finish in one frame. Slicing those too would need
  Props.place made resumable: left as a possible refinement under 21e.

### 21e. The county map's faint unexplored iron (2026-11-22)
- A worker thread was ruled out: Terrain.land_at writes shared statics (L_id, L_wild, L_w, _last_range) that the main
  thread reads all the time, so a layout running beside the game would corrupt both.
- Instead, while the map is open it lays out the unexplored chunks round you (the web's r = 9) that aren't yet,
  nearest first, within ~20 ms of work a frame, and redraws only the ink every half second (CountyMap.paint(c,
  false) keeps the wash) as their faint "Iron?" comes in. Only chunks that can hold a vein are laid out: a site
  falls 8-24 m into its chunk and is a vein only on highland or peak ground, so a 5x5 region sample of that square
  with neither is skipped (it can't add a faint mark). The results stay in Props.site_cache, so each stretch of
  country is done once.
- tools/test_map2.gd, a fresh game: 37 chunks known at first, 0 faint veins; with the map open 97 more laid out in
  8.4 s and 5 faint veins inked in; frames meanwhile median 85 ms, worst 121 ms (one far layout a frame: uncached
  terrain lookups are 80-110 us each, see 21f); folding the map stops the fill. PASS. test_map still PASSES.
- The cost: the first time you open the map in a new stretch of country it runs at ~12 fps for a few seconds while
  the faint iron fills in (the web shows it at once). 21f would cut that.

### 21f. Cheaper terrain lookups, not a height changed (2026-11-22)
- Three exact changes:
  - PNoise.Simplex.at: gradients from two int tables and the skew factors held on the instance, the same arithmetic in
    the same order: 0.51 -> 0.42 us a sample (at_ref keeps the original for the check).
  - region_height no longer works out the range mask on every call: world.js does (_lastRange), but nothing in
    regionHeight or elevation reads it (checked in the web source: elevation's `m` is dead there too). It's now
    Terrain.last_range(), worked out only where props.gd asks for it right after a region_at; the chunk builder's M
    grid (fed only to that dead `m`) is zeros. region_height ~16 -> 11 us.
  - Terrain._gh memoises each grid vertex's elevation away from built chunks (e_memo, bounded, cleared whenever the
    seed, the range centre or a flattened area changes), so a layout's is_water and get_height at one spot, and
    neighbouring spots' shared corners, are worked out once: a repeat lookup 2.3 us.
- Checked exact: Simplex.at vs the original over 210 000 points and three seeds, 0 differ; memoised vs fresh heights,
  0 of 3000 differ; and against the web itself (world.js's getHeight, regionAt and rangeAt at 600 points of the same
  world, assets/baked/compare/web_heights.json): heights within 0.000002 (float32), regions and range masks all equal
  (tools/test_terrain_exact.gd PASS). test_noise (the JS vectors), landmarks, rail, town, camps, player, save, gather
  PASS.
- Effect: a far get_height 140 -> 114 us, a far layout 23 -> 19 ms; the map's faint-iron fill 8.4 -> 5.0 s with frames
  meanwhile median 85 -> 49 ms; the walk's worst frames 10-35 ms, the farm-after-a-jump p95 19 -> 13 ms.
- What remains in an uncached elevation is real work: the noise octaves (~25 of them) and, in the mountains, the
  lattice nodes (each a full elevation, cached once made). Going further would mean native code (a GDExtension), a
  bigger step than this port has taken; left as a note.

### 22a. The title card, the pause note, the crosshair (2026-11-22)
- `Hud._build_overlay` (scripts/ui/hud.gd): index.html #overlay. The dim wash (rgba 40,52,60,.28), the card tilted
  -1 deg with its 4 px faint paper halo, and the vignette baked from the page's own SVG with its torn filter
  (assets/baked/hud/vignette.png, 1800x390, drawn by the browser so the wobble is exact). Then "Paydirt Hollow" (52),
  the line, the 21 controls in the page's two columns (WASD-K | F-Esc, the keys bold and right-aligned in 74 px),
  "Click to begin" in a dashed frame breathing 1.05 every 1.6 s, and New game. The card is placed by hand and scaled
  to fit the window (the page scrolls a taller card; Segoe Print, the stand-in for Patrick Hand, runs ~20 % larger,
  so the list is set at 14 px and the card at 1600x900 is scaled ~0.98).
- Flow as main.js: a click on the card takes the mouse; `input.on_lock_change` hides the card while playing (or the
  crafting panel is open), brings it back when the mouse is let go, and turns the call to "Click to resume". Escape
  while playing lets go (the card shows); Escape again (400 ms on) folds it into #peek "Paused · click to carry on ·
  Esc for the controls" at the top, and back. A click on the farm while paused carries on (not with the panel open).
  The card fades .3 s. Tests: `force_active` folds it away at once.
- New game: a paper confirm card in place of the browser's confirm() ("Start over" / "Keep my farm"); on yes
  `saving` is turned off, the save file deleted, and the game restarted (OS.set_restart_on_exit + quit), as the page
  reloads.
- #crosshair: an 8 px paper dot ringed in ink at the centre while build mode is on.
- Test: tools/test_title.gd (the card at the start, Click to resume, Esc to the pause note and back, the confirm card,
  force_active, the crosshair): PASS; test_hud, test_build, test_player, test_save still PASS.
- Left: K postcards (22b), O quality and P depth of field (22c), F3/F4 and the #error card (22d).

### 22b. K: a postcard (2026-11-22)
- scripts/ui/postcard.gd (`Postcard.snap(main, dir)`): main.js makePostcard. The frame is grabbed with the HUD hidden
  for it (the page's canvas never had the HTML HUD on it), then the card is laid out in a one-shot SubViewport at the
  page's sizes (pad 6 % of the short side, foot 2.2 pads): cream #efe3c4 stock with a deckled edge (jitter 5 px every
  14 px, drawn as small quads round an inner rectangle because one jagged polygon defeats the canvas triangulator),
  W*H/900 fibre flecks, the picture pasted on with a warm shadow (blur 8, offset 3,4) and a fine ink frame,
  "Greetings from Paydirt Hollow" in Georgia italic, the day and hour below, the red 2¢ stamp with its dashed frame.
- Saved as paperfjord-day<N>.png in the Downloads folder (OS.SYSTEM_DIR_DOWNLOADS, where the page's download lands;
  user:// if there is none); the toast "Snap! A postcard of the farm is in your Downloads folder." and the click.
  K is read where the web reads it (in play, not with the crafting panel open); one snap at a time.
- Test: tools/test_postcard.gd (K, the file named and sized as the page makes it, the HUD back after): PASS; looked
  at the card: the caption, the stamp, the deckle and the shadow as on the page.
- Left: O quality and P depth of field (22c), F3/F4 and the #error card (22d).

### 22c. O: graphics quality, P: depth of field (2026-11-22)
- scripts/core/quality.gd (`Quality`, made on main's first frame): main.js QUALITY / applyQuality / the O and P keys /
  the auto step-down. O cycles auto → high → medium → low → auto ("Graphics: <x>"); auto starts high and, after a 6 s
  warm-up, three seconds in a row under 50 fps step it down one level, never up ("Graphics lowered to medium for
  smoother play (O to change)"; not while minimised, as the page skips a hidden tab). P toggles the lens blur ("Depth
  of field on/off"), kept across level changes. Kept in user://paperfjord.quality.json ({mode, level}, the page's
  localStorage 'paperfjord.quality'); test runs (--script) neither read nor write it, nor step down.
- The levels on Godot's renderer: the pixel-ratio cap 2/1.5/1 → the 3D render scale against the screen's own scale
  (no change on a 1x screen, as on the page); the shadow map 2048/1024/1024 → the directional shadow atlas
  4096/2048/2048 (two splits); the penumbra 5/4/3 → the sun's shadow_blur 1/0.8/0.6 and the soft-shadow filter
  high/medium/low; post: medium drops bloom (glow), low drops SSAO, bloom, the lens blur and the cut line, as
  post.js is built for each. Left out: shadowEvery (the shadow map redrawn every 2nd/3rd frame while still); Godot
  has no switch for that. The fps count is kept (`quality.fps_rate`) for the F3 badge.
- Test: tools/test_quality.gd (O round the four, each level's switches, P off and on, auto stepping down after three
  slow seconds): PASS; looked at high, low and depth of field off. test_paper, test_save, test_title still PASS.
- Left: F3/F4 and the #error card (22d).

### 22d. F3 dev badge and time chips, F4 / +$500, the tear toast and #error (2026-11-22)
- Hud._build_dev: #backend top right ("Vulkan · 144 fps · auto high": the renderer, `quality.fps_rate`, the
  graphics setting, refreshed every frame from main) and #times under it (Afternoon 0.58, Golden 0.715, Blue hour
  0.775, Night 0.9; tilted ±1 deg alternately, the picked one warm #e9c98a; a click sets the clock and clicks). Both
  hidden unless F3; F3 is remembered in user://paperfjord.dev (the page's localStorage 'paperfjord.dev').
- #devcash: the +$500 button bottom right (Georgia 600, 14 px, 2 px brown border, offset 12/84 from the corner),
  shown always as on the page; it and F4 add $500, toast "Dev: +$500 in your poke.", the pick sound, and save.
- The frame guard: scripts/core/tear_logger.gd, a `Logger` added with OS.add_logger. GDScript can't try/catch, and a
  script error already only ends the function it hits, so the logger hears script errors and main shows the page's
  "A little tear in the paper: something went wrong, but the game carries on." once; before the first frame the red
  #error card ("Could not start: <message>", #fde2df with a #c8323c border, along the bottom) instead.
- Tests (--script) don't read or write the F3 or quality settings (`main.keep_prefs`).
- Test: tools/test_dev.gd (F3 on and off, the badge text, the Night chip, F4 and the button, two script errors: one
  toast, no error card): PASS; looked at the frame. test_title, test_hud, test_quality still PASS.
- Step 22 is done. Left: nothing unchecked in the plan; next rounds should add the next steps (a full side-by-side
  pass against the web for anything still missing).

### 23a. The journal events Godot never recorded (2026-11-22)
- With step 22 done, an audit of web against port: every web module has its counterpart, so the audit went a level
  down, to every journal.record id, every toast line and every "comes with step N" comment. It found 14 journal events
  never recorded in Godot, so their almanac goals could never be met. Now recorded where main.js records them: deer
  (critters.on_spotted, never wired), dandelion (each puff, with the rustle), landmark (with the craft chime and a
  save, both also missing), assay, store and smithy (at their doors, on E), bounty, church (the parson), stack (logs
  onto a woodpile, by the count), warmnight (the stove's night), johnny, pat (Old Blue), cat (Marmalade). The goal
  events are now all recorded somewhere except skate, which comes with the ice in 23b.
- Also from main.js: patting Old Blue shows the stick line only when he really offers one (half the time), else one
  of the three pat lines ("thumps his tail", "leans into it", "his dog grin"); Godot showed the stick line every time.
- The audit's other finds are steps 23b-23e (the ice, the missing toasts, the stale comments, a side-by-side pass).
- Test: tools/test_journal_events.gd (three deer spotted, Old Blue and Marmalade patted): PASS; test_journal,
  test_landmarks, test_town3, test_visitors, test_dogcat still PASS.

### 23b. The ponds' ice (2026-11-22)
- main.gd `_pond_ice` (was a few lines that only followed the snow): main.js's rule in full. The ice eases toward 1
  while snow lies over 0.6 (rate 0.06/s) and back toward 0 after (0.02/s), but holds while you stand on a frozen pond
  (`player.ice_on and on_pond`), and `ice_on` stays true under your boots till you step off. The first freeze toasts
  "The ponds have frozen over! Step out onto the ice and glide."; a second's glide over 2.2 m/s records skate (the
  last goal event with no recorder: every almanac goal can now be met).
- The blade scratches: a MultiMesh ring of 240 strips 0.035 x 0.55 m, unshaded #f3f6f4 at 0.7, no depth write,
  drawn after the ice; a pair (0.11 m either side, along the glide) every 0.42 m on the ice; cleared and hidden when
  the ice falls under 0.3.
- Test: tools/test_ice.gd (snow freezes the pond with the toast, a glide records skate and lays 60 scratches, the ice
  holds underfoot once the snow has gone, thawed off the pond the scratches clear): PASS; looked at the frame (the
  two pale lines behind the farmer on the frozen pond). test_pond, test_player still PASS.
- Left: 23c (the missing toasts), 23d (the stale "comes with step N" comments), 23e (a side-by-side pass).

### 23c. The missing toasts (2026-11-22)
- From main.js, where it says them: the rainbow's note 2.5 s after a daytime shower ends (a scene-tree timer); "Your
  first iron!" with the charcoal-pit hint (crafting.on_craft, iron discovered); the newcomers at the mended boarding
  house, one note for them all, only after you mend it (settlers.on_newcomer was never wired; `newcomer_news` set at
  the mend, the note given in _announce_arrivals); the barn dance starting, once a dance night
  (BarnDance.dance_night_of); a falling star landing ("It came down off to the <dir>", falling_stars.update's return,
  which was dropped); the jar's lightning bugs let go at first light (checked every frame at the top of _pets, as the
  page does, not only when nothing else is prompting).
- Test: tools/test_toasts23c.gd (rainbow, first iron, newcomers, jar at dawn, the dance): PASS. The falling-star line is
  the one not run in a test (it needs a star to come down at night); its path is the update's own return value.
  test_town3, test_settlers, test_craft still PASS.
- Left: 23d (the stale "comes with step N" comments), 23e (a side-by-side pass).

### 23d. The gaps behind the old "comes with step N" notes (2026-11-22)
- Each note checked against the web. Three were real gaps, now ported:
  - The sidehill gouger's uphill (left) legs drawn short (enemies.js gougerize, puppets.js lop): the upper front leg
    and the rear leg's first bone at 0.66 of their rest scale, after the walk clip, through a SkeletonModifier3D
    (scripts/folk/lop_legs.gd; Godot applies modifiers after the AnimationTree, as the page scales after
    mixer.update), and the body rolled -0.6 rad and dropped 0.1 (Puppet.lop). The glb's bones are "frontUpr.L" and
    "rearLeg.L_01" (three.js drops the dot; both spellings are looked up).
  - Tumbleweeds also roll down Main Street (within 75 m of the town), not only in the dry country.
  - Songbirds come to the mended bakery's doorstep for crumbs (a ground spot, not in a downpour nor with the town
    asleep), beside the feeders.
- The rest were already done (the raids, the warriors as hunting targets, the step sounds, the saloon's tips and the
  landmarks on the county map, the assay weighing gold, the jar lantern, the settlers in town); their notes now say
  what is there.
- Test: tools/test_23d.gd (the gouger's modifier running and its list; a tumbleweed on Main Street): PASS; looked at
  the gouger beside the farmer with the short legs on and off (it lists, near legs drawn up; off, it stands level).
  The modifier's result isn't readable from the bone pose afterwards (Godot restores the animated pose), so the legs
  are checked by eye. test_enemies, test_birds still PASS.
- Left: 23e (a side-by-side pass against the web for anything else missing).

### 23e, begun: the panels side by side (2026-11-22; paused for step 24)
- The web's panels captured from its own save (Day 32, saved as assets/baked/compare/web_save_day32.json; the pane's
  save backed up, restored and the tab reloaded): the pack (I), crafting (C), the almanac (H), settlers & works (J),
  with their text. Still to do: the same panels in Godot from that save, and compare. One thing seen already: the web
  hides the ledger while the crafting panel is open (body.panel-open #ledger); check Godot does.

### 24. Cold Glitter Creek, full screen, options, save and quit (2026-11-22)
- Asked for by the player, for the Godot version only (the web version is untouched and keeps "Paydirt Hollow").
- The name: every "Paydirt Hollow" in the scripts and the crafting data is now "Cold Glitter Creek" (the title card,
  the top bar, toasts, prompts, the almanac, the county map's chit, the train's home stop, the store and smithy
  headings, the postcard's "Greetings from", now saved as cold-glitter-creek-day<N>.png); the project's name too (the
  window title; user:// is now app_userdata/Cold Glitter Creek). The three printed signs that carry the name were
  rebaked in the browser with the web's own town.js card() painter and the new name, the same seeds and sizes: the
  town sign at every population (town/sign_0..19.png; "COLD GLITTER CREEK" set to fit at 26 px where the old name
  took 30), the depot sign (rail/depot_sign.png) and the fingerpost's town board front and back
  (town/fingerpost_0.png, _0b.png, "80 paces" as before).
- Full screen: main.gd `_load_display` applies user://display.json at startup ({fullscreen, vsync, ui}; full screen,
  vsync on and 100 % by default). The HUD now scales with the window (project stretch mode canvas_items, aspect
  expand, from the 1600x900 it's laid out at), so a 1080p or 4K screen shows the same layout, not a smaller one;
  "Interface size" (100/125/80 %) sets content_scale_factor on top. Tests (--script) leave the window alone.
- The title/pause card's row: Save game (save_all, the button reads "Saved ✓" for a moment), Options, New game,
  Quit (saves, then quits). The Options card (Hud._build_options): Display full screen / in a window (a 1600x900
  window centred), Vertical sync on/off, Interface size, Graphics auto/high/medium/low (the O key's Quality), Depth of
  field (P), Sound (N); each a button that cycles its value.
- Tests: tools/test_menu.gd (the name in the window title, Save game, every option cycling, the interface at 125 %):
  PASS; looked at the card and the options card. test_hud's jar check now sets night a frame before filling the jar
  (23c's "let go at first light" emptied it when both changed at once); test_title, test_hud, test_postcard,
  test_map, test_dev, test_town3 PASS. A real launch (--quit-after 400) goes full screen with no script errors.

### 23e. The panels side by side (2026-11-22)
- tools/compare_panels.gd loads the web's Day 32 save (assets/baked/compare/web_save_day32.json) and opens the pack,
  crafting, the almanac and settlers & works in turn, printing their text and saving a frame each; set beside the
  web's own (captured from the browser pane from the same save, its save restored and the tab reloaded after).
- The text matched panel for panel (crafting's tiers, costs and buttons; the almanac's week and lines; the settlers'
  rows). The almanac's weathervane line is there too (it shows only when the next weather is under 45 s off).
- Found and fixed (all hud.gd):
  - One centre panel at a time (main.js's PANELS observer): whichever opened last shows, the others wait hidden;
    while one is up the ledger steps aside and only the newest toast shows. Godot showed them all at once, ledger
    and all. `Hud.panels` / `register_panel` (the crafting panel registers itself) / `_panels_tick`.
  - Every centre panel where index.html puts them: centred a little above the middle (50vh - 84px), tilted -0.5.
  - The pack: a centre panel (was a strip at the bottom); the slots 60x54, 6 px apart once there are more than nine
    (76x64 and 10 px below that), wrapping at ~800 px as the page's half-width card does (11 a row), each with the
    item's name small in its top-left corner (.slot .k), which Godot left out.
  - Settlers & works: was a stand-in plain label outside the HUD's theme (a system font, an all-caps heading, pinned
    top left). Now the page's card: "Settlers & works" over a dashed rule, the storehouse and larder in a tinted box
    with a gold left edge, each settler's name bold and trade in italics with the status indented under it, the
    footnote, its height held to the page's 100vh - 320px.
- Left for a later pass (step 26): the county map card, the story and letter cards, the crafting panel's look.

### 25. The raids as the player asked (2026-11-22)
- main.gd `_raid_tick`: a war party only starts while you're within 60 m of the town's heart (RAID_IN_TOWN; the page
  raids whenever you're within 220 m). NativeCamps.Raid: if you go off past 150 m (LEAVE) before they've sacked it,
  they wheel off into the hills and the building is spared ("With nobody left in town to stand against them...",
  hook on_off).
- Left at it (22 s circling), a raid wrecks its building back to run-down, folk gone, to be mended again (half the
  cost): this was already so (Town.unmend), now covered by a test.
- NativeCamps.HIT = 25: every warrior's club blow and arrow, at a camp or in a raid, takes a quarter of the farmer's
  starting health (100) at once (the page: 8 to 12). The sheepskin coat still turns a third of it.
- Test: tools/test_raids.gd (no raid 100 m out, one in town, it rides off when you leave with the store still mended,
  left at it the store is wrecked, a blow takes 25 of 100): PASS. test_town4, test_camps, test_hud, test_craft PASS.

### 26, begun: the map, story, letter and crafting cards (2026-11-22; stopped here so the player can play)
- tools/compare_cards.gd frames them from the web's Day 32 save beside the web's own (captured from the pane, its
  save restored). Web rects at 1600x900 (x y w h): map 525 74 550 585 (canvas 504, scrolling past 580 tall), tale
  564 247 472 238, letter 564 241 472 249, crafting 537 74 525 585 (scrolls past 580).
- Fixed: the story card's heading now wraps like the page's h2, so a long title ("A letter from Aunt Ida, over in
  Clay County") no longer widens the card (letter 656 -> 470 wide, as the web). Taller than the web's for the larger
  stand-in font (Segoe Print for Patrick Hand).
- Left (the rest of 26): the county map card is 610 wide (its sheet 560; the page draws it 504 at 900 tall); the
  crafting panel is 840 tall where the page holds it to 580 and scrolls; the headings are regular weight where the
  page's h2 is bold, and their rule is solid where the page's is dashed.
- The player has said the web version is done: from here on only the Godot version changes.

### 26. The map, story, letter and crafting cards (2026-11-22)
- Finished from the round before (the heading wrap). Now, beside the web's rects (tools/compare_cards.gd):
  - The county map: the 560 px sheet drawn at the page's min(540, 100vw - 60, 100vh - 400) = 500 px (scaled in a
    holder), and clipped at its edge: the land names drawn near the rim used to run past the sheet onto the card
    (they'd always done so in Godot); the page's canvas cuts them, and now so does Godot. Card 560 x 611 (web 550 x 585).
  - The crafting panel: centred where the other centre panels sit and held to the page's 100vh - 320px (580 tall),
    its list scrolling; was 840 tall at the screen's middle. 554 x 580 (web 525 x 585).
  - Headings on the story/letter/almanac cards bold, over a dashed rule, as the page's h2.
- Tests: test_map, test_map2, test_craft, test_hud PASS; looked at the map and the crafting panel.
- Left: nothing unchecked. Cards run a little taller than the web's for the stand-in font (Segoe Print for Patrick
  Hand); shipping Patrick Hand (OFL) with the game would close that, if wanted.

### 27. Full screen at 4K (2026-11-22)
- The player's screen is 3840x2160 and the game opens full screen, so it renders the world at 4K where every
  measurement so far was at 1600x900. tools/probe_size.gd confirms a --resolution 3840x2160 run renders a 3840x2130
  frame (the HUD laid out at 1622x900 and scaled up by the canvas_items stretch; 3D at full size, scale 1.0).
- tools/perf_walk.gd at 3840x2160 (RTX 4090): farm morning avg 7.2 / p95 8.7 / worst 22.9 ms; the lane 7.2 / 8.8 /
  28.5; Main Street 6.9 / 7.1 / 12.1; the woods 7.3 / 9.6 / 28.1; the wilds 7.7 / 10.7 / 32.1; the farm at night 8.1 /
  13.6 / 23.3: the same as at 1600x900, so the game is CPU-bound (GDScript) at either size and 4K costs nothing to
  speak of on this card. No change needed; on a weaker card the auto graphics setting steps down as before.
- Left: nothing unchecked.

### 28, begun: the chunk-finish spikes (2026-11-22)
- perf_walk with spike reporting (SPIKE_MS=18 env var now sets the threshold): the worst frames (26-33 ms) are all
  World._create_chunk_sliced's finish, 12-18 ms in one frame. tools/probe_chunk.gd splits it: Props.place is 17-50 ms
  the first time a chunk is laid out (4-8 ms again; only its sites are cached), the instancing 4-9 ms.
- Tried: an optional time budget inside Props._place that awaits a frame between rows. Reverted: GDScript makes any
  function containing `await` a coroutine that every caller must await, and Props.place has synchronous callers
  (the map, the rumours, the satchels); the build briefly failed to load (a test window showed the "Could not start"
  card). Props._place is back as it was; Props.place is now _finish(_place(...)), the same result.
- Next: a separate sliced copy of the layout (a job object stepped row by row, like Terrain.chunk_job), leaving
  Props.place synchronous; or cache the whole placed list per chunk so a second layout costs nothing.
- Paused here at the player's word (they're playing). State: Props._place_co / Props.place_sliced added (a
  line-for-line copy of the layout with frame waits; tools/test_place_sliced.gd: 40 of 40 chunks laid out the same:
  PASS), not yet used: World still calls Props.place (the edit to _create_chunk_sliced didn't apply). To finish 28:
  have _create_chunk_sliced await Props.place_sliced and pass the result to create_chunk (a pre_placed argument),
  then re-run perf_walk with SPIKE_MS=20 while nothing else is using the machine.

### 29. From the player's first play (2026-11-22; Godot only)
- The ties: Railroad turned each tie by the track's yaw + 90 deg (as the web does), which with a 1.7 m-long box laid
  every tie along the track. Now by the yaw alone: square across the rails.
- The cars: each car's basis is now Basis.looking_at along the line from 0.8 of its half-length behind its middle to
  as far ahead (both on the track's height), so the engine, tender and cars tilt up and down the grades (up to ~6 deg
  on the line) where the web keeps every car level. Train.ride_point follows the coach's tilt.
- The speed: Train.SPEED 6.5 -> 3.5 m/s at full steam (the easing into stops unchanged).
- Raids: no war party comes down on the town till you own a bow, a six-shooter or a rifle (NativeCamps.player_armed,
  set by main each frame; _raid_tick waits for it). The camps defend their land as before, armed or not. (A first
  pass also kept the camps from fighting an unarmed farmer; the player meant the raids only, so that was taken out.)
- Tests, run --headless while the player played: tools/test_raids.gd (no raid unarmed in town; then as before):
  PASS; tools/test_rail_ties.gd (the ties' turn square to the track; the cars tilting with the ground's grade to
  within 2.5 deg, steepest 6.3; SPEED 3.5): PASS. Not yet looked at on screen (the player is playing): look at the
  track and a train on a hill next time a window is free.
- Step 28 (the chunk-finish spikes) is still half done: Props.place_sliced is in and tested, not yet used by World.

### Windows build (2026-11-22)
- godot/export_presets.cfg ("Windows Desktop", x86_64, release, the pack beside the exe, tools/* left out, *.json
  included for the data the game reads itself). Built with
  `Godot --headless --path godot --export-release "Windows Desktop" ../build/ColdGlitterCreek.exe` into
  SpaceThing/build/ (ColdGlitterCreek.exe 109 MB + ColdGlitterCreek.pck 1.4 GB; build/ is git-ignored). A shortcut
  "Cold Glitter Creek" on the Desktop runs it. The export templates were already installed (4.7.2.stable).
- The build's first run logged "Target and up vectors are colinear" every frame: step 29's tilted cars, where the
  line ends and a car's front and back points close up. Now a car keeps its last heading there, and one that has
  never moved stands level along the track. Rebuilt; a headless run of the exe logs nothing.
- Rebuild after changes with the same command (a few minutes).

### New game, fixed (2026-11-22; the player found it closed the game)
- Was: delete the save, OS.set_restart_on_exit and quit. Run from the editor, Godot can't relaunch, so the game just
  closed; from the exe it relaunched but showed nothing for the ~9 s a new county takes, which looked like a crash.
- Now in place: the save is deleted, a paper card "Laying out a new county…" goes up over everything (a CanvasLayer
  on the root, group newgame_card, outliving the scene), the old county is forgotten (main.reset_world: Terrain's
  flat, extra flats (which only ever grew), range centre and caches; Props' site cache, garden and unique
  encounters), and the scene reloads. The new main finds no save, rolls a random seed (ring 60-115) and lays the
  farm and town out ~85 m apart as before; on its first frame it takes the card away (~6 s on this machine).
- The old scene's unfinished work (the world's sliced chunk builder and pool prewarm, the model preloader, the map's
  faint-iron fill, a settler's delayed note) now stops when its node leaves the tree instead of asking a freed tree
  for the next frame (that raised a script error, which the tear logger would have shown as "a little tear").
- Tests can now name a throwaway save with the CGC_SAVE_PATH environment variable (main.gd), never the player's.
  tools/test_newgame.gd (the game started as it really starts, a county played and saved, New game: the save gone, a
  new seed, the card while it builds and gone after, farm and town 85 m apart, running at ~145 fps headless, no
  script errors): PASS for each run. The exe rebuilt; a headless run of it logs nothing.

### The crafting crash (2026-11-22; the player crafting their first things)
- The game's log (user://logs/godot.log) showed "Object ... was freed or unreferenced while a signal is being emitted
  from it" once per Craft press, then the crash. CraftingPanel.render(), called from inside the pressed Craft
  button's own signal, cleared the list with free(), freeing that very button mid-signal. Now remove_child +
  queue_free (Hud's build bar had the same pattern: changed too; the other free() calls in the scripts are on
  temporary model copies never in the tree).
- tools/test_craft_press.gd (the panel open, Craft pressed on four recipes a frame apart): no errors; with the old
  line put back it logs the same error four times, so it catches this. The exe rebuilt; a headless run logs nothing.

### A smoke test of standard play, and what it found (2026-11-22)
- tools/smoke_actions.gd (headless, on a throwaway save via CGC_SAVE_PATH): a Logger catches every engine and script
  error while it plays: walking, sprinting, jumping; every key on the controls card; panels stacked and shut;
  crafting presses; eating; build mode (each shelf, rotate, place, remove); every tool swung and fired; E on a 3 m grid
  round the farm by day and by night and at the dog, cat, mailbox and rocker; E at every town door with money;
  the title card's buttons and options; a save; Biscuit whistled, mounted, ridden, got down; fishing at a pond; days,
  nights, rain, snow and a storm in fast time; the whole town mended, the railroad laid, a train ride; a fight with
  guardians with each weapon; struck down and coming to; a raid met with the rifle; into a camp's land and out; and
  the well-played save loaded back and played on. (Its own self-check, SMOKE_SELFTEST=1, proves it sees an error.)
- Found and fixed:
  - Saving failed once you owned Biscuit: save_all read horse.group (the web's name); the Godot Horse is the node
    itself, so every save after buying her stopped at a script error. Now horse.pos.
  - Panning failed (a script error every frame, no "[E] Pan the shallows") whenever you waded with corn in your pack
    and no duck family was on the pond: ducks.fam was read without a null check.
- Left: "Parameter material is null" (an engine error, material_get_instance_shader_parameters) logs once at the
  first dusk of a session and once at the first downpour; nothing visible, no crash. Bisecting by pausing main's
  children was flaky (it depends on frame timing); probe_material4.gd is kept for another look.
- Not covered headless: K (the postcard needs a rendered frame; tested windowed in 22b).
- The exe rebuilt; a headless run of it logs nothing.

### The interface a size down (2026-11-22; the player's ask)
- The crafting panel zoomed out: laid out 1/0.78 larger and drawn at 0.78 (CraftingPanel.ZOOM), so it fills the same
  box on screen with smaller type: seven recipes showing where four did.
- The whole interface 5% smaller: main.UI_BASE 0.95 multiplies the root's content scale; the Options card's
  "Interface size" (100/125/80 %) now scales from that. (Test runs keep 1.0; tools/compare_cards.gd takes UI_SCALE to
  show the game's.) The exe rebuilt.

### The farmer up close: the rocker, his grip, a run; the crafting panel, the interface, the far blur (2026-11-22)
- The rocker: porch.js seats the model's hips on the cushion, a little back in the chair, after his sit clip has
  posed him; the port only set the root 0.32 down, so he sat off the seat. Now FarmExtras.porch_update moves the
  root so the Hips bone lands at the chair's group + (back 0.08, up 0.6), as the web and as Horse.seat_rider does.
- Tools in his hand: the model's hand is one bone with no fingers, so the grip point decides it. It sat 0.06 down the
  hand bone and on the back of the hand, so every handle lay past his fingertips; now 0.035 down and 0.035 toward the
  palm (Avatar.grip_along/grip_palm), and the paper fist wraps the handle. The guns' grips pulled back into the palm
  too (0.075 -> 0.045 ahead of the wrist). Looked at every tool from the front (tools/shot_hands.gd).
- A run: his model (folk_jim) has walk but no run; the warriors' models have a run on the same 24-bone skeleton.
  ModelFigure.borrow_clip copies it in, re-pointed at his skeleton, and update() plays run above RUN_AT (8 m/s: he
  walks at 6, sprints at 11.5). tools/test_run_clip.gd: walk at a walk, run at a sprint: PASS; looked at the stride.
- The crafting panel further out (ZOOM 0.66: nine recipes showing); the whole interface 10% smaller (UI_BASE 0.90).
- The far blur: the tilt-shift blurred what lies beyond the focus as hard as the foreground; post.gdshader's new
  far_gain (0.35) softens only the far side, so the distance reads crisper and the miniature foreground stays.
- smoke_actions: clean but the known first-dusk engine line; test_craft_press PASS. The exe rebuilt.

### Quitting while the models load; the exe's exit (2026-11-22)
- Checking the rebuilt exe, it segfaulted when it quit within its first seconds: the background model preload
  (ResourceLoader threaded requests, four in flight) was still loading GLBs on worker threads. Now _finish_loads()
  waits out the loads in flight and starts no more, and runs before every way out: the Quit button, closing the
  window (auto_accept_quit is off; NOTIFICATION_WM_CLOSE_REQUEST goes through _quit_game, which saves first), and
  New game's reload. The exe quit at 1, 2, 3, 4.5 and 6 s (CGC_QUIT_AT_MS, a check hook, on a throwaway save): no
  more segfaults.
- Open: the exported release exe still ends with a Windows heap-corruption code (0xC0000374) as it exits, every time,
  after the save; the bash shell showed it as 127. Not the tear logger (same with it off, CGC_NO_TEAR=1); the same
  project run through the editor binary exits 0, and a debug export exits 0 listing leaks at exit (88 ObjectDB
  instances, render RIDs). Clearing the scripts' static caches before quitting only turned it into an access
  violation (0xC0000005), so that was taken back out. It happens only at shutdown, after saving; nothing in play.
  Next to try: free the static caches' owners in order before the scene goes, or report it upstream with a minimal
  export.
- (Two quit checks ran the game on the player's real save before CGC_SAVE_PATH was set for them: each loaded it and
  saved it back a few seconds of game time later; nothing lost.)

### Claim jumpers, a camp's warriors doubled, pickups, a shorter crafting list (2026-11-22; the player's asks)
- The interface another 5% smaller (UI_BASE 0.855). The rain bed quieter: 0.13 -> 0.08 in the open, 0.09 -> 0.055
  under a roof (Sound.update).
- The crafting panel shows By hand always, and otherwise only what you can make or buy where you stand: the
  workbench, campfire, forge, the tinker, each shop, the depot, a trading post, a camp's fire, the fair, each only
  when its station_near says you're at it. The long build-piece list gave way to one line ("Build pieces: B, once you
  have a hammer"), with a pointer to go and stand at a place when nothing's here.
- Pickups (main.drops / add_drop / _drops_tick): a thing left lying where someone fell, bobbing; E beside it takes
  what's inside; gone by the next morning. A fallen warrior (a camp's or a raider) leaves his painted parfleche
  (prop_parfleche: pelts, leather and rope, venison, amber, cartridges, honey and berries); a claim jumper his poke.
- The native camps' warriors doubled: six a camp (the three kinds twice, at 9 and 13 m round the fire).
- Claim jumpers (scripts/folk/jumpers.gd, ClaimJumpers): five ragged camps placed by the world's seed 150-650 m
  out, clear of water, the mountains, the town and the lodges (a small clearing kept round each fire), each a tent,
  cookfire, handcart, bedroll and barrel, built only within 170 m. Three or four men a camp on the prospectors',
  farmhands' and tradesmen's models, clothes re-dyed (ModelFigure hue; skin never), with the warriors' borrowed run.
  Violent and quick: no warning, within 30 m the camp comes for you at 6.4 m/s (you can just outrun them at a
  sprint); brawlers swing pick handles, gunmen keep 10 m off and fire every ~2 s (45% hit); a hit is 25 (a
  quarter of your starting health; the coat turns a third). They give up 90 m from their fire. Struck (blows, arrows,
  bullets: they're hunting targets and melee targets), one falls and drops his poke (dollars, gold, silver,
  cartridges); a camp beaten to the last man stays empty three days (saved: "jumpers").
- tools/test_jumpers.gd (five camps; built near; all three came, 100 -> 25 health in 4 s; beaten, three pokes, one
  picked up; the camp saved as cleared; six warriors a camp and a parfleche from one): PASS. smoke_actions: clean but
  the known first-dusk line; test_craft_press PASS. The exe rebuilt.

### The saloon freeze, the title card, the railroad off the mountains, the passes (2026-11-22; the player's notes)
- The saloon's supper froze the game: the old-timer's tip laid out every chunk within 8 (289 chunks, 17-50 ms each
  the first time: up to ~14 s); the sheriff's bounty did the same over 441. Both now use main._sites_near: the
  sites of chunks already laid out (Props.site_cache, kept as you explore and open the map) and at most three more,
  nearest first. tools/test_saloon.gd: each E answered in one ~260 ms frame (before the budget cut to three): PASS.
- The title card drawn a size down (Hud.TITLE_SCALE 0.82), on top of the interface's own scale.
- The railroad on the mountains: on a new county (the mountain ring 60-115 m out) the line ran straight from stop to
  stop, up and over the ranges, with the whistle-stops' trading posts (the cottages) and their keepers up on the
  slopes; seen from afar the track floated where the mountain under it wasn't drawn. Now each stop is picked on open
  ground (no range within 18 m), and each leg is found round the mountains on a 12 m AStarGrid2D (range ground solid,
  water three times dearer, the town and the farm walled off), smoothed with Chaikin's corners twice; the old straight
  line stays as the fallback. tools/probe_mountains.gd over five new counties: before, up to 113 of the line's points
  on mountain and 28 m up; after, 0-3 points just brushing a foot (range <= 0.07, ~1.6 m). The route costs ~85 ms at
  startup.
- Low passes: Terrain.impassable stopped you wherever the range mask passed 0.24 (only ~3.4 m into a mountain's
  rise), which shut low gentle saddles. Now a range's ground stops you only where it's steep (slope over 0.6, ~31
  deg); the county's outer wall stays a wall.
- smoke_actions: clean but the known first-dusk line; test_saloon, test_jumpers, test_raids, test_title PASS. The
  exe rebuilt.

### "Built" on the Works shelf (2026-11-22; the player's ask)
- Build mode's fifth shelf, Works (the storehouse and each settler's work: woodlot, quarry, weir, clay pit, diggings,
  sluice, bee yard, mill, kiln, sugar shack, tannery, charcoal pit): one of each is all you need, so a work already
  standing is marked "✓ built" in green under its cost and set back (Hud.set_buildbar takes main's count of the
  pieces standing, by type). You can still place another. Looked at it (tools/shot_works.gd); smoke_actions clean.

### The county map: no lag, pan and zoom, the claim jumpers, "Natives" (2026-11-22; the player's asks)
- The lag: opening laid out every seen chunk not yet laid out, at once (~250 ms), and the faint-iron fill laid out a
  whole chunk a time (17-50 ms) up to 20 ms a frame (p95 60 ms, worst 190 ms). Now the opening takes only what's
  laid out already; the fill also takes the seen chunks, each through Props.place_sliced at 5 ms a frame; the wash is
  sampled 96 a side (was 140; it's blurred soft). tools/probe_map_lag.gd: p95 60 -> 11.5 ms while open;
  tools/probe_map_open.gd: an opening ~20 ms (the session's first ~110 ms: the engine's first use of the fonts and
  the blur shader).
- Pan and zoom (CountyMap.view/span/pan/zoom/recenter): while the map is open the mouse drags the sheet and the
  wheel zooms it (120-1400 m across; the camera and its zoom held), right-click or R puts it back on you; it opens
  on you. The wash slides and scales with the view (_place_wash) and is washed afresh, its marks gathered round the
  new centre (cache only, more filled in behind), 0.3 s after it comes to rest. The scale bar picks 25-400 yards to
  suit; the wild lands' names are placed in the world, biggest first, never over one another, home or the town.
- Claim jumpers' camps on the map: a dark tent in a red ring, "Claim Jumpers" ("(cleared)" while it's empty), all
  five, as the natives' camps are always shown. The natives' land reads "Natives" (was "Their land"), on the sheet and
  on the margin arrow.
- test_map, test_map2 PASS; smoke_actions: no errors at all. Looked at it opened, zoomed out and dragged
  (tools/shot_mappan.gd). The exe rebuilt.

### Claim jumpers' camps grown, men who fight, women who don't (2026-11-22; the player's asks)
- Each camp is now three tents and a lean-to shack (bldg_leanto) round a cookfire, with a sluice, an ore cart, a
  handcart, crates, barrels, bedrolls and boulders, the lay-out turned its own way per camp, every piece kept off
  water and slopes; the site needs dry ground 22 m all round (16 directions) and a 20 m clearing.
- Only men fight: three to five a camp, from the men's models (ClaimJumpers.MEN: prospectors_1/4/6, the three
  farmhands, folk_asa, trades_1). A line-up (tools/shot_lineup.gd) showed trades_2 and trades_5, in the old list, are
  women. The camp's one or two women (ClaimJumpers.WOMEN: trades_2, trades_5, the calico girls, clothes re-dyed) go
  about the fire, and in a fight hurry to the shack and wait; they're never targets and can't be hurt, as the
  natives' camp folk.
- tools/test_jumpers.gd now also checks: 3+ men, all men's models; the women not targets and at the shack in the
  fight; 10+ camp pieces: PASS. Looked at a camp from above (tools/shot_jumpers.gd). smoke_actions: no errors. The
  exe rebuilt.
- Note: the lean-to model has "Old Asa's Hermit Lean-to" painted on its sign.

### Notes kept to one short line (2026-11-22; the player's ask: too many, too long)
- Hud.toast: one note up at a time (was two), at most three waiting (the oldest dropped), 15 px on a slimmer card,
  never wrapping, gone in 2-6 s. Hud.brief cuts each to its gist: brackets and quote marks dropped, the first
  sentence (with the next if the first is under 18 characters: "Snap!"), or the first with a number in it if the first
  has none (the paces, the dollars), the part after a colon when that's where the number is (the saloon's tip), at
  most 58 characters ("…" past that). Hud.heard keeps the last 40 in full; the tests read those.
- tools/test_brief.gd prints samples. test_raids, test_toasts23c, test_dev PASS against heard; smoke_actions clean.
  The exe rebuilt.

### More to build: a Homestead shelf and a palisade (2026-11-25; the player's ask)
- BuildSystem.EXTRA (the port's own, merged into the build data on load): a sixth shelf, Homestead, of buildings made
  from the reference art's models, each with a use, and a Palisade on the Yard shelf.
  - Chicken coop (bldg_coop; 10 wood, 4 fibre): 3 eggs a morning, up to 3 mornings waiting; E gathers.
  - Hay barn (bldg_barn, 8 m; 24 wood, 6 stone, 2 rope): 5 fibre (straw) a morning.
  - Prospect shaft (mine_entrance; 10 wood, 6 stone, 2 rope): 2 ore and 3 stone a morning.
  - Well (mine_windlass; 8 stone, 4 wood, 2 rope): E for a drink: full stamina, +10 health.
  - Lean-to (bldg_leanto; 12 wood, 6 fibre): a bed away from home (E after dark sleeps till morning).
  - Palisade (4 wood): a 2 m run of pointed stakes on two rails, edge-snapped like a wall, solid and tough (9 hp).
- The model pieces are seated from their GLBs, and their solid boxes and footprints measured from the model the first
  time one's made (the ghost); they want dry ground (none of their footprint in water) and not steep (validate).
  Daily stock: tend_producers each morning, as the skeps; extra_near finds the one you stand at; the prompts and E in
  main's yard code. Claim jumpers are now stopped by what you build (ClaimJumpers.blocker -> build.collide): a
  palisade keeps them out.
- tools/test_homestead_build.gd (the shelf; each placed; two mornings gathered from coop, barn and shaft; the well's
  drink; a night in the lean-to; the palisade pushing a body out): PASS. Looked at them built in a row
  (tools/shot_newbuilds.gd). test_jumpers, test_craft_press PASS; smoke_actions clean but the known first-dusk line.

### Iron near the farm; something on the prowl at night (2026-11-25; the player's asks)
- Props.starter_ore: one small outcrop a county, 45-75 m from the farm on dry ground, clear of the farm's level sheet
  and the town, picked by the seed: five ore rocks and two plain ones, added (Props._finish, shared by place and
  place_sliced) to whichever chunk holds each. Reset with a new game. test: 5 ore within 80 m (nearest 65 m).
- Night prowlers (main._night_prowlers): after dark, 45 m+ from the farm and 70 m+ from town, every 70-130 s (the
  first ~40 s after nightfall) a pair of night coyotes settles 22-30 m ahead, on land; the coyote guardian with its
  teeth pulled (4 health, 6 a bite, aggro 12, leash 25, one pelt). At dawn any left go, and none are kept in the
  save's beaten list. A first toast warns of them. test: two came; six seconds standing among them cost 42 of 100;
  beaten and gone; none left at dawn.
- tools/test_night_iron.gd PASS; test_place_sliced (40 of 40 the same) PASS; smoke_actions: no errors. The exe rebuilt.

### Boss battles: Mad Jebediah and the stolen deed (2026-11-25; the player's ask)
- Town.grow (the street-opening loop out of Town.mend) asks a gate first: Second Street waits till the townsite deed
  is back at the assay office (main: town.gate, n != 0 or boss.delivered); on_gate tells you once, and NEXT then
  says to beat Mad Jebediah (see M). Grown again on the hand-in. Streets already open in a save stay open.
- Boss (scripts/folk/boss.gd): Mad Jebediah, prospectors_6 (the white-bearded one with the bedroll pack) at 2.4x,
  at his diggings 300-450 m from town on dry, level ground clear of home, the lodges and the jumpers' camps (seeded);
  a mine mouth, windlass, tool rack, ore cart, tent, fire, boulders and a heap of picks. Built within 170 m.
  54 health. From 4.6-32 m he lobs a pickaxe every 2.5-3.1 s at where you're headed (a dark mark where it lands;
  within 1.5 m: 20); up close a 0.9 s wind-up (a red ring spreading) and a slam (within 4.2 m: 25). Below half health
  two picks at a time, quicker. Lead him 85 m from his fire and he goes home and gets his wind back. Blows, arrows
  and bullets all reach him. A boss bar (name and red strip) shows at top centre while he fights.
- Beaten, he drops the deed (a parchment roll with a red ribbon), a drop that never spoils; E picks it up; E at the
  assay office hands it in: Second Street goes up and the assayer pays $40. The homeward chip points to the assay
  office while you carry it. Saved: beaten, delivered (a beaten boss's deed not yet picked up lies at his diggings
  again on load). On the county map: crossed red picks in a double ring, "Mad Jebediah" ("beaten" after).
- tools/test_boss.gd PASS (lair 405 m out; Second Street held then opened; picks thrown and landing hurt; a slam;
  the deed dropped, kept past two days, picked up, handed in; flags saved). Looked at mid-fight (tools/shot_boss.gd).
