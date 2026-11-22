# Replacing Meshy with local tools (TRELLIS.2 and friends)

Status: research plan, written 2026-11-21. Nothing has been installed or downloaded yet. Items marked
**(unverified)** could not be confirmed from official sources and need a check on the first test asset.

## 0. Where the project stands

- All 159 crops in `assets/refs/` already have a Meshy `raw.glb`; 41 figures have `anims.glb` (6 clips), 39 have
  their own `idle.glb`, and all 17 quadrupeds have `walk.glb` + `run.glb`. So this plan is for **new** assets and
  re-dos, not a backlog.
- That existing Meshy output is itself a resource: the humanoid rig is a fixed 24-bone skeleton (`Hips, Spine,
  Spine01, Spine02, neck, Head, head_end, headfront, Left/RightShoulder, Arm, ForeArm, Hand, Left/RightUpLeg, Leg,
  Foot, ToeBase`), and its clips (`Idle, Casual_Walk, Wave_One_Hand, Heavy_Hammer_Swing, FunnyDancing_01,
  Chair_Sit_Idle_F` plus 15 alternative idles) can be lifted out of the GLBs on disk and replayed on any new rig
  that uses the same bone names. This is the cheapest animation source and needs no account. (Check Meshy's terms
  for reusing your generated animations on other models; on a paid plan the output is normally yours.)
- Meshy `raw.glb` conventions the Blender scripts rely on: Y-up glTF, centred on the origin, largest extent about
  1.9 units (roughly −0.95..0.95), front facing +Z, one baseColor JPEG texture, metallic/roughness as factors.
  TRELLIS.2 exports into a −0.5..0.5 box with full PBR maps, so the new script must normalise to Meshy's frame.

## 1. Image-to-3D: which model

### TRELLIS.2 (recommended)

| Item | Finding |
|---|---|
| Repo / weights | https://github.com/microsoft/TRELLIS.2 , weights `microsoft/TRELLIS.2-4B` (https://huggingface.co/microsoft/TRELLIS.2-4B). 4B parameters, O-Voxel sparse representation. |
| Licence | MIT for code and weights (commercial use allowed). Dependencies nvdiffrast / nvdiffrec have their own (NVIDIA, non-commercial-ish) licences. |
| Hidden dependencies | The official `pipeline.json` loads **`facebook/dinov3-vitl16-pretrain-lvd1689m`** (gated on Hugging Face, custom DINOv3 licence that Meta says permits commercial use: https://ai.meta.com/resources/models-and-libraries/dinov3-license) and **`briaai/RMBG-2.0`** for background removal (gated, **CC BY-NC 4.0, non-commercial**: https://huggingface.co/briaai/RMBG-2.0). The ComfyUI route below swaps RMBG-2.0 for BiRefNet (MIT) and ships its own DINOv3 file. |
| VRAM | Official: "at least 24GB", verified on A100/H100. A 4090 meets the figure. 512 and 1024_cascade should fit; **1536_cascade on 24 GB is unverified** (no public 4090 report found). Community forks claim much less (the StableProjectorz fork says 8 GB at 1024³; ComfyUI native uses int8 weights). |
| Settings | `pipeline.run(image, seed=42, pipeline_type=...)` with `'512' / '1024' / '1024_cascade'` (default) `/ '1536_cascade'`, `max_num_tokens=49152`, three sampler-param dicts (12 steps each by default). Source: `trellis2/pipelines/trellis2_image_to_3d.py`. |
| Output | Textured mesh with base colour, roughness, metallic, opacity; `o_voxel.postprocess.to_glb(..., decimation_target=..., texture_size=..., remesh=True, remesh_band=1, remesh_project=0)` then `glb.export(path, extension_webp=True)`. So it **can decimate and remesh itself** (CuMesh does remesh + QEM decimation + UV unwrap + bake), i.e. ask for 8k–20k triangles and a 2048 texture directly. GLB is opaque by default (alpha stored, not wired). Raw meshes "may occasionally contain small holes". |
| Speed | H100: 512³ ≈ 3 s, 1024³ ≈ 17 s, 1536³ ≈ 60 s (shape + material). A 4090 is slower; expect roughly **30–90 s at 1024_cascade plus 20–60 s of GLB post-processing** (estimate, unverified). |
| Windows | Upstream: "currently tested only on Linux"; setup is a conda `setup.sh` that compiles flash-attn, nvdiffrast, nvdiffrec, CuMesh, O-Voxel, FlexGEMM. CUDA 12.4, PyTorch 2.6.0 recommended. Open issues/PRs for Windows builds (#4, #100, #107, #185). |
| Windows routes that exist | (a) **ComfyUI native** (from ComfyUI 0.34.0, Aug 2026): TRELLIS.2 and Pixal3D as core nodes, "no custom nodes, compiled CUDA extensions, or PyTorch downgrade", plus native Remesh / Decimate / Fill Holes / UV-unwrap nodes and Save 3D: https://blog.comfy.org/p/trellis2-and-pixal3d-are-now-native , workflow + model list: https://docs.comfy.org/tutorials/3d/trellis2 . (b) visualbruno/ComfyUI-Trellis2 custom node with prebuilt Windows wheels (tested Win 11, Python 3.11, Torch 2.7.0+cu128; needs gated DINOv3 access): https://github.com/visualbruno/ComfyUI-Trellis2 . (c) IgorAherne/TRELLIS.2-stableprojectorz, a one-click Windows installer (Python 3.11, CUDA 12.8, Torch 2.8): https://github.com/IgorAherne/TRELLIS.2-stableprojectorz . (d) WSL2 + the official repo. Do **not** use the PixWizardry Blackwell (sm120) wheels on a 4090. |
| Stylised / papercraft input | No published evaluation on papercraft art. The model "has not been aligned with human preferences", reproduces what it sees, and has **no A-pose option** (Meshy's `pose_mode: a-pose` has no equivalent). Faceted paper planes should come out well geometrically; painted fine detail (lace, faces) depends on texture resolution. Test on 3–4 crops before committing. |

### Brief comparison

| Model | Licence | 4090 fit | Notes |
|---|---|---|---|
| **TRELLIS.2** | MIT | Yes at 1024_cascade (1536 unverified) | Best fully-open quality/speed balance; own remesh/decimate/PBR bake. |
| **Pixal3D** (Tsinghua + Tencent ARC, SIGGRAPH 2026) | Reported MIT since Jul 2026 (earlier custom licence; check https://github.com/TencentARC/Pixal3D LICENSE) | Built on TRELLIS.2, ships in the same ComfyUI template | Pixel-aligned: mesh follows the input view more strictly. Worth an A/B on the same crops for free, since it is one switch in the same workflow. |
| TRELLIS (v1) | MIT | Yes (~16 GB) | Superseded; lower texture quality. No reason to pick it now. |
| Hunyuan3D-2.1 | Tencent Hunyuan Community Licence; **excludes the EU, UK and South Korea**, extra conditions | Shape ~10 GB, texture ~21 GB, both together ~29 GB, so run in stages | Windows supported, strong PBR texturing (https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1). Licence is the blocker if the user is in the EU/UK. |
| Others (Hi3DGen, Stable Fast 3D, TripoSR, SAM 3D Objects) | various | yes | Not evaluated in depth; either weaker textures or geometry-only. |

**Decision: TRELLIS.2 through ComfyUI native nodes, driven headless over ComfyUI's HTTP API.** Reasons: no
CUDA-extension compilation on Windows (the main failure point upstream), no gated RMBG-2.0, BiRefNet background
removal included, remesh/decimate/bake nodes built in, Pixal3D available for A/B, and ComfyUI can be scripted
(`POST /prompt`, `GET /history/{id}`, `GET /view`, `POST /upload/image`, `POST /free`:
https://docs.comfy.org/development/comfyui-server/comms_routes). Fallback if ComfyUI misbehaves: the
StableProjectorz Windows fork, called from Python directly; last resort WSL2 + official repo.

### The pose problem (biggest quality risk for folk)

The crops are illustrations, often with hands clasped or touching the body (e.g. `saloon_1`). Meshy re-posed them to
an A-pose; TRELLIS.2 will not, so arms fuse to the torso, auto-rigging fails and wave/work clips tear the mesh.
Options, in order:

1. Pre-pass: re-draw each folk crop in A-pose with a local image-edit model (e.g. Qwen-Image-Edit, Apache-2.0,
   also native in ComfyUI) in the same workflow, and keep the original crop for colour reference. Quality on
   papercraft art **unverified**; review each edit by eye.
2. Accept the pose for figures whose arms are already free, and limit clips (no wave/work) for the rest.
3. Meshy fallback for the hard ones (`pose_mode: a-pose`).

Props, buildings, plants, rocks and static animals have no pose problem.

## 2. Rigging humanoids without Meshy

| Option | Local / free | Skeleton | Fit for this project |
|---|---|---|---|
| **Make-It-Animatable** (CVPR 2025), https://github.com/jasongzy/Make-It-Animatable | MIT code, weights on HF `jasongzy/Make-It-Animatable`; local `app.py` / v2 `app_v2.py` | Trained on Mixamo; predicts joints, skin weights and pose for a **Mixamo-template humanoid** in under a second | **Recommended** joint + weight predictor. Windows, output format and batch CLI are **unverified** (README is Linux/conda, links a Linux FBX2glTF; Python 3.11). A third-party ComfyUI wrapper exists (ComfyUI-BrainDead "auto rig MIA"). |
| Blender bone-heat (`parent_set(type='ARMATURE_AUTO')`) | Built in, headless | Whatever armature we build | Good weights once joints are placed; fails ("Bone Heat Weighting: failed") on non-manifold meshes, so weight a voxel-remeshed proxy and Data-Transfer the weights back. |
| Rigify | Built in | Rigify metarig (`DEF-` bones) | Needs joint placement first and adds ~hundreds of control bones; no gain over a plain 24-bone deform skeleton for a web game. Skip. |
| UniRig, https://github.com/VAST-AI-Research/UniRig / successor SkinTokens, https://github.com/VAST-AI-Research/SkinTokens | MIT, local, ≥8 GB VRAM, bash/conda (Windows unverified) | Arbitrary, generic bone names | Good for odd shapes and animals, but the bone names/topology vary per model, so the humanoid clip library would need per-model mapping. Use for quadrupeds (section 3), not folk. |
| Mixamo | Free with an Adobe ID (user must sign in; Claude never types the password). Still online in 2026 but in maintenance mode, and had a login breakage in June 2025 (https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) | `mixamorig:` 65-bone humanoid | Reliable manual fallback: user uploads, places chin/wrist/elbow/knee/groin markers, downloads FBX "with skin". Web-only, one figure at a time. |
| AccuRIG 2 (Reallusion/ActorCore) | Free Windows app, **free ActorCore account required to export** (https://www.cgchannel.com/2025/07/rig-and-animate-3d-characters-for-free-with-accurig-2-0/) | CC/ActorCore humanoid | GUI only, Blender-import problems reported in the past. Manual fallback only. |
| Auto-Rig Pro | Paid Blender add-on | | Best remap tool in Blender, but paid; not needed. |
| RigAnything / Puppeteer / MagicArticulate | Research code | Generic | Not worth it here. |

**Plan:** build every new humanoid on **Meshy's own 24-bone skeleton** (same names, same hierarchy, same rest
orientations, copied from an existing `rigged.glb`). Then every clip the project already owns plays by bone
name, `blender_folk.py`'s RightHand finder and `modelfolk.js` keep working, and no retargeting maths is needed
for the stock library.

- Joints: Make-It-Animatable's Mixamo joints, mapped Mixamo → Meshy (`Hips→Hips, Spine→Spine, Spine1→Spine01,
  Spine2→Spine02, Neck→neck, Head→Head, HeadTop_End→head_end, *Shoulder/Arm/ForeArm/Hand, *UpLeg/Leg/Foot/ToeBase`
  by the same names; finger joints dropped and their weights merged into the hand).
- Fallback joint source: a heuristic fitter on the A-posed mesh (height fractions + silhouette: hips at the widest
  low section, shoulders at the top of the arm gap, wrists at the arm tips), good enough for a 24-bone game rig
  and fully local. Or Mixamo by hand.
- Weights: MIA's weights when available, else bone heat on a voxel-remeshed proxy + Data Transfer.

### Animation clips

| Source | Account | Clips | Use |
|---|---|---|---|
| **Existing Meshy clips on disk** (41 `anims.glb`, 39 `idle.glb`) | none | idle, walk, wave, work (hammer swing), dance, sit + 15 alternative idles | Primary. Already on the target skeleton. |
| Mixamo | Adobe ID (user signs in, downloads FBX "Without Skin" for the clips they pick) | everything, incl. other work and dance clips | For new clip types. Retarget by name map `mixamorig:X → X` plus rest-pose correction. |
| Quaternius Universal Animation Library (https://quaternius.com/packs/universalanimationlibrary.html) | none, **CC0** | 120+ (locomotion, sitting, emotes, combat); exact list unverified | Free extra clips, needs a one-time bone map. |
| CMU mocap (BVH) | none | huge, raw | Only if something is missing; needs cleanup. |
| Rokoko Blender add-on | Rokoko account; custom-character retargeting appears to be a paid tier (unverified) | | Not needed. |

Blender 4.5 has no built-in retargeting operator (unverified for very recent builds), so retargeting is our own
headless script: for each target bone, a world-space Copy Rotation from the source bone with a rest-pose offset,
Hips location scaled by the height ratio, then `bpy.ops.nla.bake(visual_keying=True, clear_constraints=True)` per
clip. For Meshy→Meshy-named rigs the offset is near identity, so the script can be validated on existing figures
(re-apply `saloon_2`'s clips to `saloon_1` and compare with Meshy's own).

## 3. Quadrupeds

The existing Meshy quadruped rigs are per-animal (47 bones on the dog, 50 on the horse, Rigify-style names like
`rearHorselink.L`), so there is no single template to reuse. Options:

1. **Default fallback: static model + procedural motion in the game.** The game is paper pop-up style, so a card
   animal that bobs, tilts and shuffles (sinusoidal body bob, small yaw sway, optionally a two-part split at the
   waist hinged like a paper toy) reads fine. Zero tooling risk. `blender_static.py` already handles it.
2. **Template transfer from the closest existing animal**: for a new animal close to one of the 17 (goat→sheep,
   mule→donkey, wolf→coyote), align the existing rigged mesh to the new mesh by bounding box and Data-Transfer the
   weights (nearest face interpolated), keep the armature, scale bones to fit, and reuse its `walk`/`run`
   clips. Works when proportions are similar; needs a visual check.
3. **UniRig / SkinTokens** for skeleton + weights (works on animals; MIT), then a scripted procedural gait in
   Blender (find the four leg chains as the lowest end bones, drive them with a phase-offset sine trot, bake to
   `walk` and a faster `run`). Most work, generic bone names; Windows install unverified (WSL2 likely).
4. Meshy quadruped rig for the important ones while credits last.

Recommendation: (1) now, (2) when an animal has a close relative, Meshy only for a hero animal.

## 4. Step-by-step plan for this project

### 4.1 Install (outside the project, one folder per tool)

```
C:\AI\ComfyUI\          ComfyUI >= 0.34.0 (git clone), its own venv: C:\AI\ComfyUI\venv  (Python 3.12 is fine)
                        torch with CUDA 12.8 wheels (4090 = sm89; driver 610.60 supports CUDA 12.x/13.x)
  models\diffusion_models\trellis_2_int8_convrot.safetensors, pixal3d_int8_convrot.safetensors
  models\vae\trellis_2_shape_vae_bf16.safetensors, trellis_2_texture_vae_bf16.safetensors
  models\clip_vision\dino_v3_L_naf_fp32.safetensors
  models\background_removal\birefnet.safetensors          (all from Comfy-Org/* on Hugging Face, per the docs page)
C:\AI\MIA\               Make-It-Animatable, its own venv (needs Python 3.11: get it with `uv python install 3.11`, no conda)
C:\AI\ComfyUI\custom_workflows\trellis_api.json   the template workflow, exported once in "API format"
```

Alternative to the manual ComfyUI install: ComfyUI Desktop or the portable NVIDIA build (own embedded Python).
Disk: tens of GB for weights (exact total unverified); 2.7 TB free is plenty. Whether the Comfy-Org DINOv3 file
needs a Hugging Face login is unverified; if it does, the user signs in and accepts the licence.

### 4.2 `tools/trellis_batch.py` (mirrors `meshy_batch.py`)

Standard library only, talks to a running ComfyUI at `http://127.0.0.1:8188`.

```
python tools/trellis_batch.py saloon_1 prop_barrel        # these
python tools/trellis_batch.py --all                       # every crop without a raw.glb
python tools/trellis_batch.py --redo prop_barrel          # ignore state, regenerate
options: --model trellis2|pixal3d   --res 1024_cascade|1536_cascade|512   --seed N   --tex 2048
```

Per name:

1. `kind` exactly as in `meshy_batch.py` (`QUADRUPEDS`, static prefixes, else `folk`); import those sets from
   `meshy_batch` so the lists stay in one place.
2. `target_tris`: same table as Meshy (`bldg_` 20k, `veh_/mine_/furn_` 15k, folk 20k, quadruped 15k, else 8k).
3. Input: `assets/refs/<name>.png`; for folk, `assets/refs_apose/<name>.png` if it exists (output of the optional
   A-pose pre-pass).
4. Skip if `assets/models/meshy/<name>/raw.glb` exists and `state.json` has `"source": "trellis"` or `"meshy"`
   (never overwrite a paid Meshy model unless `--redo`).
5. `POST /upload/image`, load `trellis_api.json`, set image name, seed, resolution switch, model switch,
   decimate target, texture size, output prefix `trellis/<name>`; `POST /prompt`; save `prompt_id` in
   `state.json` (resume: if a prompt id is stored, poll `/history/{id}` instead of resubmitting).
6. Poll `/history/{id}` every 5 s; fetch the GLB via `/view?filename=...&subfolder=...&type=output`.
7. Normalise to Meshy's frame (a small Blender pass or pure-Python GLB edit of the root node): centre on origin,
   uniform scale so the largest extent is 1.9, rotate so the front faces +Z (TRELLIS.2's front axis is
   **unverified**; check on the first asset and hard-code the fix). Keep only baseColor if metal/rough maps
   look noisy (the game runs textures through its card material anyway).
8. Write `raw.glb`, `state.json` = `{"source": "trellis", "model": ..., "res": ..., "seed": ..., "prompt_id": ...}`,
   and a `preview.png` (ComfyUI's preview render or `tools/blender_preview.py`) for a quick look.
9. On failure: print and continue with the next name (like the Meshy loop); on ComfyUI unreachable: stop.
10. `POST /free` after the batch to release VRAM.

Then the existing chain carries on unchanged for statics: `blender_static.py -- <name>`.

### 4.3 Rigging + animation step (new headless Blender scripts)

- `tools/mia_rig.py` (runs in `C:\AI\MIA\venv`): `raw.glb` → `assets/models/meshy/<name>/mia.fbx/glb` with Mixamo
  joints + weights. If MIA can't be made to run on Windows, skip it and use the heuristic fitter.
- `tools/blender_rig.py` (Blender 4.5, `-b --factory-startup`): build the Meshy 24-bone armature (template copied
  from an existing `rigged.glb`) at MIA's or the heuristic's joints, height-scaled to 1.75 m (or `CHILDREN`),
  weights from MIA or bone heat on a remeshed proxy → `rigged.glb`.
- `tools/blender_retarget.py`: take clips from a donor's `anims.glb` (and an `idle.glb` dealt out in turn, like
  `meshy_idles.py`), plus any Mixamo/Quaternius FBX in `assets/anims/`, bake them onto the new rig, name the
  actions `idle, walk, wave, work, dance, sit`, write `anims.glb`, `idle.glb` and `clips.json`. That is exactly
  what `blender_folk.py` reads, so it and `modelfolk.js` run unchanged (the RightHand finder matches `RightHand`).
- Quadrupeds: static → `blender_static.py`, or option 2 above writing `walk.glb` / `run.glb` for
  `blender_animal.py`.

### 4.4 Expected time per asset (4090, estimates)

| Asset | Generation | Rig + clips | Total |
|---|---|---|---|
| Prop / building | 1–3 min | – | 1–3 min |
| Folk (A-pose pre-pass + TRELLIS.2 + rig + 6 clips) | 2–4 min | 1–2 min | about 5 min + a look |
| Quadruped (static + procedural) | 1–3 min | – | 1–3 min |

A full re-run of all 159 crops would be roughly 4–8 hours unattended. Model load is the slow part of the first
item; keep ComfyUI running between items.

### 4.5 Meshy stays as a fallback

Leave `meshy_batch.py` and `meshy_idles.py` as they are. `trellis_batch.py` never touches a folder whose
`state.json` says `"source": "meshy"`, so a figure can be done by Meshy (e.g. a hard pose or a hero animal) and
everything downstream is identical.

### 4.6 Risks

1. **Pose**: no A-pose control; fused arms/hands on many folk crops (section 1). Biggest risk for rigged figures.
2. **Windows**: ComfyUI native support is new (Aug 2026) and node/parameter names in the API workflow may change
   with updates; pin the ComfyUI version once it works. MIA and UniRig Windows support is unverified.
3. **VRAM**: 1536_cascade on 24 GB unverified; 1024_cascade should be the working default.
4. **Auto-rig quality**: skinning on skirts/bustles (most of the saloon girls) will need manual tolerance; the
   walk clip may make long dresses clip through legs (Meshy had the same issue).
5. **Holes / thin parts**: raw meshes can have small holes; bone heat fails on non-manifold meshes (proxy +
   Data Transfer mitigates); ComfyUI has Fill Holes.
6. **Licences**: TRELLIS.2 MIT; DINOv3 custom licence (commercial allowed per Meta); avoid RMBG-2.0 (non-commercial)
   by using the ComfyUI/BiRefNet route; Pixal3D licence history is mixed; Hunyuan3D excludes EU/UK/KR; Mixamo
   clips are royalty-free in projects but not redistributable as raw files; reusing Meshy clips depends on
   Meshy's terms.
7. **Style match**: TRELLIS.2 output may look different from the Meshy models already in the game; A/B on
   existing crops before replacing anything.

### 4.7 What still needs the user

- Approving installs (ComfyUI, PyTorch, model downloads) when the time comes.
- Hugging Face sign-in and licence acceptance only if a gated model is needed (DINOv3 on the non-Comfy routes).
- Mixamo or ActorCore sign-in and downloads, only if new clip types are wanted (Claude never types passwords).
- Judging the first test models and the A-pose redraws by eye.

## 5. First three steps

1. **Install ComfyUI (>= 0.34.0) in `C:\AI\ComfyUI` with its own venv, download the TRELLIS.2/Pixal3D/BiRefNet/DINOv3
   files listed in https://docs.comfy.org/tutorials/3d/trellis2 , and run the stock template by hand** on four
   crops already done by Meshy: `prop_barrel`, `bldg_church_ruined`, `animal_dog`, `saloon_1`. Record VRAM peak,
   time, triangle count and look, at 1024_cascade (and 1536_cascade once), TRELLIS.2 vs Pixal3D.
2. **Export the workflow in API format and write `tools/trellis_batch.py`** (section 4.2), output to a scratch
   name first (e.g. `assets/models/meshy/_trellis_test/<name>/raw.glb`), then run `blender_static.py` on a
   prop to confirm the downstream chain works with normalised TRELLIS output.
3. **Prove the rig path on one figure with free arms**: write `blender_retarget.py` and test it Meshy→Meshy
   (donor clips onto an existing `rigged.glb`), then build `blender_rig.py` with the heuristic joint fitter on the
   TRELLIS `saloon_1` (or an A-posed redraw), and only then try Make-It-Animatable for better joints/weights.

## Sources

- TRELLIS.2 repo: https://github.com/microsoft/TRELLIS.2 ; model card: https://huggingface.co/microsoft/TRELLIS.2-4B ;
  pipeline config: https://huggingface.co/microsoft/TRELLIS.2-4B/raw/main/pipeline.json ; pipeline code:
  https://github.com/microsoft/TRELLIS.2/blob/main/trellis2/pipelines/trellis2_image_to_3d.py ; Windows issues:
  https://github.com/microsoft/TRELLIS.2/issues?q=windows
- ComfyUI native TRELLIS.2/Pixal3D: https://blog.comfy.org/p/trellis2-and-pixal3d-are-now-native ,
  https://docs.comfy.org/tutorials/3d/trellis2 ; ComfyUI server routes: https://docs.comfy.org/development/comfyui-server/comms_routes
- Community Windows builds: https://github.com/visualbruno/ComfyUI-Trellis2 , https://github.com/JanskNeh/ComfyUI-Trellis2-GGUF ,
  https://github.com/IgorAherne/TRELLIS.2-stableprojectorz , (not for 4090) https://huggingface.co/PixWizardry/AI_Trellis2-WHLs-RTX-PRO-6000
- RMBG-2.0 licence: https://huggingface.co/briaai/RMBG-2.0 ; DINOv3: https://huggingface.co/facebook/dinov3-vitl16-pretrain-lvd1689m ,
  https://ai.meta.com/resources/models-and-libraries/dinov3-license
- Pixal3D: https://github.com/TencentARC/Pixal3D , https://huggingface.co/TencentARC/Pixal3D
- Hunyuan3D-2.1: https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1 ; comparison (vendor blog, treat with care):
  https://www.3daistudio.com/blog/pixal3d-vs-trellis-2-vs-hunyuan-3d-comparison
- UniRig: https://github.com/VAST-AI-Research/UniRig ; SkinTokens: https://github.com/VAST-AI-Research/SkinTokens ,
  https://huggingface.co/VAST-AI/SkinTokens
- Make-It-Animatable: https://github.com/jasongzy/Make-It-Animatable , paper https://arxiv.org/abs/2411.18197
- Mixamo FAQ: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html ; 2025 login breakage:
  https://community.adobe.com/t5/mixamo-discussions/mixamo-login-amp-download-broken-due-to-outdated-account-url/m-p/15378115
- AccuRIG 2: https://www.cgchannel.com/2025/07/rig-and-animate-3d-characters-for-free-with-accurig-2-0/
- Quaternius UAL (CC0): https://quaternius.com/packs/universalanimationlibrary.html
- Rokoko Blender plugin: https://support.rokoko.com/hc/en-us/articles/4410463492241-Install-the-Blender-plugin , https://www.rokoko.com/pricing
