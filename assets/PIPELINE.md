# Paydirt Hollow folk: from the reference sheets to animated 3D models

Goal: the exact figures from the four reference sheets, walking and working in the game.

## 1. Reference crops (done)

`assets/refs/` holds one image per figure, cut from the sheets (21 in all):

| File | Who |
|---|---|
| `saloon_1..4.png` | the four saloon girls (red ruffles, sage bustle, gold corset, rose bustle) |
| `townsfolk_1..4.png` | the lady with the shawl and purse, the lady with the fan, the old storekeeper, the girl with the slate |
| `trades_1..7.png` | the doctor, the schoolteacher, the carpenter, the boy with the paper horse, the grandmother, the seamstress, the newspaperman |
| `prospectors_1..6.png` | the prospector with the gold pan, the widow in the bonnet, the girl with the shawl, the gambler, the lady in blue, the old hermit with the bedroll |

## Meshy, scripted (the chosen route)

The Meshy API needs a paid plan; on the free plan it answers 402. Each figure costs one image-to-3D task, one
rigging task and one animation task with 6 clips (Meshy charges per clip). The docs' examples show about 30, 5
and 3 credits per task, but check your plan's pricing.

```powershell
$env:MESHY_API_KEY = "<your key>"          # you set this; the script only reads it
python tools/meshy_batch.py --library wave # optional: check the animation ids (free)
python tools/meshy_batch.py saloon_1 townsfolk_3 prospectors_1
```

For each figure, the script:

1. sends the crop for an A-posed, textured model (about 20k triangles);
2. rigs it, 1.75 m tall (the two children shorter);
3. adds the clips idle, walk, wave, work (hammer swing), dance and sit;
4. downloads everything to `assets/models/meshy/<name>/`.

Re-running resumes from `state.json`. Then tell Claude, who runs:

```powershell
& "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python tools/blender_folk.py -- --all
```

That writes the lean game models to `assets/models/folk/` and wires them into the game. If you'd rather use
Meshy's website, download each animated figure as GLB to `assets/models/meshy/<name>/anims.glb` and the rest is
the same.

## 2. Image to 3D (other services)

Upload each crop to an image-to-3D service and download the textured model as **GLB**. Any of these will do:

- **Tripo** (tripo3d.ai): strong on stylized figures, and has built-in auto-rigging and animations.
- **Meshy** (meshy.ai): image-to-3D, plus auto-rigging and an animation library.
- **Hunyuan3D 2** (free and open source): image-to-3D only, so rigging is done in step 3.

Settings: one figure per image, textured, PBR off (or albedo only), about 10–30k faces. Save the files as
`assets/models/raw/<same name as the crop>.glb`. Start with 2 or 3 figures so the pipeline can be tested
before doing all 21.

If you'd rather have it scripted, the Tripo and Meshy APIs can do it. Set your key as an environment variable
(for example `TRIPO_API_KEY`) yourself, and Claude will write the script that reads it. Claude never types the
key into anything.

## 3. Rigging and animation

Either:

- **In the service:** auto-rig there and export each figure with the clips **walk, idle, work (chopping), wave,
  dance, sit**.
- **Mixamo** (free, needs an Adobe login): upload each raw model, auto-rig it, and download those clips as FBX
  "with skin" into `assets/models/rigged/<name>/`.

## 4. Blender (Claude's part, headless scripts)

For each figure:

1. Import it, scale it to about 1.85 m, and stand it on the origin facing +Z.
2. Decimate it to about 4–6k triangles for Firefox, and bake the texture down to 1024².
3. Merge the clips onto one skeleton and name them `walk`, `idle`, `work`, `wave`, `dance`, `sit`.
4. Find the right-hand bone, where tools will be attached.
5. Export a compressed GLB to `assets/models/folk/<name>.glb`.

## 5. In the game (Claude's part)

1. A model-backed `Figure` replaces the procedural one with the same interface: `root`, `update(dt, speed,
   pose)`, `hands`, head-look.
2. An `AnimationMixer` crossfades between the clips.
3. The paper grain is kept by running the models' textures through the game's card material.
4. Each settler and townsperson is mapped to the figure that suits them best.
