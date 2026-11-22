// Ambient life around the player: printed autumn leaves fluttering down by day, fireflies after dusk.
// Each is a single instanced mesh updated on the CPU (cheap: a few dozen instances).
import * as THREE from 'three/webgpu';
import { uniform, vec3 } from 'three/tsl';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { mulberry32 } from './noise.js';
import { getHeight } from './world.js';

const LEAVES = 70, FLIES = 60;
const LEAF_COLS = [0xe08a3a, 0xc8552f, 0xd9a441, 0xb8452e, 0xe6b45a];

export class Ambient {
  constructor(scene) {
    const rng = (this.rng = mulberry32(31337));

    // ---- falling leaves: a small die-cut leaf card, printed with a vein, both sides
    const leafPts = [];
    for (let i = 0; i <= 12; i++) {
      const t = (i / 12) * Math.PI * 2;
      leafPts.push([Math.cos(t) * 0.09, 0.13 + Math.sin(t) * 0.13 * (1 - 0.35 * Math.cos(t))]);
    }
    const leafArt = paintCard(leafPts, {
      W: 128, H: 160, seed: 9, base: '#f1e6cc',
      fills: ['rgba(255,250,240,A)', 'rgba(230,220,200,A)'],
      edge: 'rgba(150,110,70,1)',
      details(g, px) {
        const [a, b] = px(0, 0.01), [c, d] = px(0, 0.25);
        g.strokeStyle = 'rgba(110,70,40,0.55)'; g.lineWidth = 3;
        g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke();
      },
    });
    this.leaves = new THREE.InstancedMesh(cardGeometry(leafPts, 0.01), cardMaterial(leafArt, { side: THREE.DoubleSide }), LEAVES);
    this.leaves.frustumCulled = false;
    this.leaves.castShadow = true;
    this.leafState = [];
    const c = new THREE.Color();
    for (let i = 0; i < LEAVES; i++) {
      this.leaves.setColorAt(i, c.setHex(LEAF_COLS[i % LEAF_COLS.length]));
      this.leafState.push({ p: new THREE.Vector3(), v: new THREE.Vector3(), rot: new THREE.Euler(), w: new THREE.Vector3(), seed: rng() * 10, alive: false });
    }
    scene.add(this.leaves);

    // ---- fireflies: tiny glowing beads (bloom catches them on High)
    this.glow = uniform(0);
    const flyMat = new THREE.MeshBasicNodeMaterial();
    flyMat.colorNode = vec3(2.4, 2.1, 0.7).mul(this.glow);
    this.flies = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(0.035, 0), flyMat, FLIES);
    this.flies.frustumCulled = false;
    this.flyState = [];
    for (let i = 0; i < FLIES; i++) this.flyState.push({ home: new THREE.Vector3(), pos: new THREE.Vector3(), seed: rng() * 100 });
    scene.add(this.flies);
    this.flyHomeT = 0;
    this.time = 0;
  }

  /** The nearest glowing firefly within r of pos (and not far overhead), or -1. */
  fireflyNear(pos, r = 1.7) {
    if (this.glow.value < 0.3) return -1;
    let best = -1, bd = r * r;
    this.flyState.forEach((f, i) => {
      const d = (f.pos.x - pos.x) ** 2 + (f.pos.z - pos.z) ** 2;
      if (d < bd && f.pos.y - pos.y < 2.6) { bd = d; best = i; }
    });
    return best;
  }

  /** Caught: this firefly goes into the jar, and a fresh one wanders in somewhere off in the dark. */
  catchFirefly(i) {
    const f = this.flyState[i], a = this.rng() * Math.PI * 2, d = 10 + this.rng() * 12;
    const fx = f.home.x + Math.cos(a) * d, fz = f.home.z + Math.sin(a) * d;
    f.home.set(fx, getHeight(fx, fz) + 0.5 + this.rng() * 1.6, fz);
    f.pos.set(1e6, 0, 1e6);
  }

  respawnLeaf(s, center, anywhere) {
    const r = this.rng;
    const a = r() * Math.PI * 2, d = 3 + r() * 22;
    const base = getHeight(center.x, center.z);
    s.p.set(center.x + Math.cos(a) * d, base + (anywhere ? r() * 9 : 7 + r() * 3), center.z + Math.sin(a) * d);
    s.v.set((r() - 0.5) * 0.6, -0.4 - r() * 0.5, (r() - 0.5) * 0.6);
    s.rot.set(r() * 6, r() * 6, r() * 6);
    s.w.set((r() - 0.5) * 5, (r() - 0.5) * 5, (r() - 0.5) * 5);
    s.alive = true;
    s.ground = getHeight(s.p.x, s.p.z) + 0.02;
  }

  update(dt, center, night, wind = 0.6) {
    this.time += dt;
    const t = this.time;
    // leaves: fewer at night
    const active = Math.round(LEAVES * (1 - 0.7 * night));
    for (let i = 0; i < LEAVES; i++) {
      const s = this.leafState[i];
      if (i >= active) { _m.makeScale(0, 0, 0); this.leaves.setMatrixAt(i, _m); s.alive = false; continue; }
      if (!s.alive || s.p.y < s.ground || Math.abs(s.p.x - center.x) > 30 || Math.abs(s.p.z - center.z) > 30) this.respawnLeaf(s, center, !s.alive);
      // flutter: side-to-side sway + a steady drift with the wind
      s.p.x += (s.v.x + Math.sin(t * 2.1 + s.seed) * 0.7 + wind * 0.5) * dt;
      s.p.z += (s.v.z + Math.cos(t * 1.7 + s.seed) * 0.5) * dt;
      s.p.y += s.v.y * dt * (0.8 + 0.4 * Math.sin(t * 3 + s.seed));
      s.rot.x += s.w.x * dt; s.rot.y += s.w.y * dt; s.rot.z += s.w.z * dt;
      _m.compose(s.p, _q.setFromEuler(s.rot), _s.setScalar(1));
      this.leaves.setMatrixAt(i, _m);
    }
    this.leaves.instanceMatrix.needsUpdate = true;

    // fireflies: drift in slow loops near the ground, blinking; only after dusk
    this.glow.value = THREE.MathUtils.smoothstep(night, 0.45, 0.85);
    if ((this.flyHomeT -= dt) <= 0) {
      this.flyHomeT = 4;
      for (const f of this.flyState) {
        if (f.home.distanceToSquared(center) > 26 * 26 || f.home.lengthSq() === 0) {
          const a = this.rng() * Math.PI * 2, d = 3 + this.rng() * 20;
          const fx = center.x + Math.cos(a) * d, fz = center.z + Math.sin(a) * d;
          f.home.set(fx, getHeight(fx, fz) + 0.5 + this.rng() * 1.6, fz);
        }
      }
    }
    const on = this.glow.value > 0.01;
    for (let i = 0; i < FLIES; i++) {
      const f = this.flyState[i];
      if (!on) { _m.makeScale(0, 0, 0); this.flies.setMatrixAt(i, _m); continue; }
      const k = f.seed;
      _p.set(f.home.x + Math.sin(t * 0.4 + k) * 1.4, f.home.y + Math.sin(t * 0.9 + k * 2) * 0.35, f.home.z + Math.cos(t * 0.33 + k) * 1.4);
      f.pos.copy(_p);
      const blink = Math.max(0, Math.sin(t * (1.3 + (k % 1)) + k * 7));
      _m.compose(_p, _q.identity(), _s.setScalar(0.4 + blink * 0.9));
      this.flies.setMatrixAt(i, _m);
    }
    this.flies.instanceMatrix.needsUpdate = true;
  }
}

const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _s = new THREE.Vector3(), _p = new THREE.Vector3();
