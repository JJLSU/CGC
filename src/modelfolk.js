// Folk from models: the townsfolk and settlers as the animated paper figures made from the reference sheets
// (Meshy image-to-3D, rigged and animated, cleaned up in Blender: see assets/PIPELINE.md and tools/). A ModelFigure
// stands in for a procedural Figure with the same face to the rest of the game: root, body, head, legs, arms (with
// elbows), hands, update(dt, speed, pose). It plays the model's own clips (idle, walk, work, wave, dance, sit),
// crossfading between them, and keeps the paper look by printing the model's texture onto the game's card
// material (the fibre and pulp of handmade stock). Models load once at start; each figure is a cheap clone.
import * as THREE from 'three/webgpu';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { cardMaterial } from './materials.js';
import { texture, uv } from 'three/tsl';

const BASE = 'assets/models/folk/';
const loaded = new Map(); // name -> { scene, clips, info }
const animals = new Map(); // the four-legged ones (assets/models/animals: walk and run clips)

/** Load the named figures, or every one that's been made (missing ones are skipped quietly). Resolves to the names that loaded. */
export const loadFolk = (names = null) => loadModels(BASE, names, loaded, false);
/** The animals made from the reference art (see Puppet in puppets.js, which wears one when it exists). */
export const loadAnimals = (names = null) => loadModels('assets/models/animals/', names, animals, false);
export const animalModel = (name) => animals.get(name) ?? null;
const props = new Map(); // the still ones: buildings, props, plants (assets/models/props)
export const loadProps = (names = null) => loadModels('assets/models/props/', names, props);
export const propModel = (name) => props.get(name) ?? null;

async function loadModels(BASE, names, loaded, snow = true) { // (snow: whether snow settles on it: the buildings and props, but not folk or beasts)
  const loader = new GLTFLoader();
  const have = await fetch(BASE + 'index.json').then((r) => (r.ok ? r.json() : [])).catch(() => []); // (only what's been made)
  await Promise.all((names ?? have).filter((n) => have.includes(n)).map(async (name) => {
    try {
      const [gltf, info] = await Promise.all([loader.loadAsync(BASE + name + '.glb'), fetch(BASE + name + '.json').then((r) => (r.ok ? r.json() : {})).catch(() => ({}))]);
      // the paper look: each mesh's texture printed on card
      gltf.scene.traverse((o) => {
        if (!o.isMesh) return;
        const map = o.material?.map; if (map) map.colorSpace = THREE.SRGBColorSpace;
        o.material = cardMaterial(map ?? null, { paperScale: 6, pulp: 0.08, side: THREE.DoubleSide, snow });
        if (map) SRC_MAP.set(o.material, map); // (kept, so a figure can be re-dyed: see ModelFigure's hue; userData would be JSON-copied by a clone and lose the texture) // a fine, quiet grain: the print carries the detail; both sides of thin cloth
        if (map) o.material.emissiveNode = texture(map, uv()).rgb.mul(0.28); // a soft fill of its own, so a face in shade stays a face
        o.castShadow = true; o.receiveShadow = true; o.frustumCulled = true;
        // a skinned figure's bounds don't follow its pose, so give it its bind-pose sphere made half again as big
        // (room for a swung arm or a kick): folk behind the camera or off the page aren't drawn at all
        if (o.isSkinnedMesh) { o.geometry.computeBoundingSphere(); o.boundingSphere = o.geometry.boundingSphere.clone(); o.boundingSphere.radius *= 1.5; }
      });
      loaded.set(name, { scene: gltf.scene, clips: gltf.animations, info });
    } catch (e) { /* not generated yet */ }
  }));
  return [...loaded.keys()];
}
export const hasFolk = (name) => loaded.has(name);

const POSE_CLIP = { cast: 'wave', work: 'work', dance: 'dance', cancan: 'dance', sit: 'sit', beckon: 'wave', clipboard: 'idle', fiddle: 'idle' };

const IDLE_FROM = { trades_1: 'trades_7', prospectors_4: 'trades_7', trades_2: 'prospectors_5', folk_silas: 'trades_7' }; // (whose idle each borrows)

const TINTED = new Map(), SRC_MAP = new WeakMap(); // (re-dyed materials, shared by every figure in the same colours)

export class ModelFigure {
  constructor(name, spec = {}) {
    const src = loaded.get(name);
    this.spec = spec; this.name = name;
    this.root = new THREE.Group(); this.turn = new THREE.Group(); this.body = new THREE.Group();
    this.root.add(this.turn); this.turn.add(this.body);
    if (spec.scale) this.root.scale.setScalar(spec.scale);
    const model = SkeletonUtils.clone(src.scene);
    // re-dyed: the same figure in other clothes (spec.hue, radians), its skin, hair and leather left as they are
    if (spec.hue) model.traverse((o) => {
      const src = o.isMesh && SRC_MAP.get(o.material); if (!src) return;
      const key = o.material.uuid + ':' + spec.hue;
      const m = (TINTED.get(key) || TINTED.set(key, cardMaterial(src, { paperScale: 6, pulp: 0.08, side: THREE.DoubleSide, hue: spec.hue, snow: false })).get(key));
      if (!m.emissiveNode) m.emissiveNode = m.inkNode.mul(0.28);
      o.material = m;
    });
    this.body.add(model); this.model = model;
    this.mixer = new THREE.AnimationMixer(model);
    this.actions = {};
    for (const clip of src.clips) this.actions[clip.name] = this.mixer.clipAction(clip);
    // a few figures came back from Meshy with an idle that looks wrong on them (arms flung out, a crouch, a lean):
    // they borrow a calmer figure's idle instead, joint turns only (no hip travel), since every rig shares its bones
    const donor = IDLE_FROM[name] && loaded.get(IDLE_FROM[name])?.clips.find((c) => c.name === 'idle');
    if (donor) { const c = donor.clone(); c.tracks = c.tracks.filter((t) => t.name.endsWith('.quaternion')); c.name = 'idle'; this.actions.idle = this.mixer.clipAction(c); }
    // stand-ins for the joints other code pokes at (they no longer drive anything)
    const stub = () => { const g = new THREE.Group(); g.elbow = new THREE.Group(); g.knee = new THREE.Group(); return g; };
    this.legs = [stub(), stub()]; this.arms = [stub(), stub()];
    this.blinkGroup = new THREE.Group();
    // the head and the hands: real bones where the rig has them, so tools and things held ride along
    const bones = {}; model.traverse((o) => { if (o.isBone) bones[o.name.toLowerCase()] = o; });
    const find = (...keys) => Object.entries(bones).find(([n]) => keys.every((k) => n.includes(k)))?.[1];
    this.head = find('head') ?? new THREE.Group();
    const rh = (src.info?.hand && bones[src.info.hand.toLowerCase()]) || find('right', 'hand') || find('hand', 'r');
    const lh = find('left', 'hand') || find('hand', 'l');
    // (a Meshy rig's bones carry its centimetre scale: undo it, so a tool put in the hand keeps its own size)
    model.updateWorldMatrix(true, true); const _s = new THREE.Vector3();
    this.hands = [lh, rh].map((b) => { const g = new THREE.Group(); (b ?? this.body).add(g); if (b) { b.getWorldScale(_s); g.scale.setScalar(1 / (_s.x || 1)); } return g; });
    this.current = null; this.t = 0; this.phase = 0;
    // no two folk idle in step: each has an idle of their own (tools/meshy_idles.py) and breathes at their own pace
    // from their own point in it
    this.rate = 0.85 + Math.random() * 0.3;
    this.play('idle', 0);
    if (this.actions.idle) this.actions.idle.time = Math.random() * this.actions.idle.getClip().duration;
  }

  play(name, fade = 0.25, timeScale = 1) {
    const a = this.actions[name] ?? this.actions.idle ?? Object.values(this.actions)[0];
    if (!a) return;
    a.timeScale = name === 'idle' ? timeScale * this.rate : timeScale;
    if (a === this.current) return;
    const keep = name === 'idle' ? a.time : 0; // (an idle picks up where it left off, so the folk stay out of step)
    a.reset().setEffectiveWeight(1).play(); a.time = keep;
    if (this.current) this.current.crossFadeTo(a, fade, false);
    this.current = a;
  }

  /** speed in m/s; pose as for Figure. */
  update(dt, speed = 0, pose = null) {
    this.t += dt; this.phase += dt * (2.4 + speed * 1.9);
    if (pose === 'swing' && this.actions.work) this.play('work', 0.08, this.actions.work.getClip().duration / 0.55); // a tool swing: the whole clip in about the swing's time
    else if (pose && POSE_CLIP[pose]) this.play(POSE_CLIP[pose]);
    else if (speed > 0.3) this.play('walk', 0.25, Math.min(2, Math.max(0.6, speed / 1.4)));
    else this.play('idle', 0.4);
    this.mixer.update(dt);
  }
}
