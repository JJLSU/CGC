// A beaver at home: near the farmer, a paper beaver swims slow loops round its lodge, its broad head and back
// just showing, a flat scaly tail trailing, and a pale V of wake spreading behind it. Now and then it slaps
// its tail on the water (a plop) and dives, and comes up again a little later somewhere else on its round.
// Built to read from above, like the geese: flat cards just above the water. One small group, near lodges only.
import * as THREE from 'three/webgpu';
import { paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { isWater } from './world.js';

export class Beaver {
  constructor(scene) {
    const flat = (pts, t = 0.03) => cardGeometry(pts, t).rotateX(-Math.PI / 2);
    this.g = new THREE.Group();
    const m = (geo, hex, shadow = true) => { const x = new THREE.Mesh(geo, paperMaterial({ color: hex })); x.castShadow = shadow; this.g.add(x); return x; };
    // nose toward +x: a plump brown back, a rounder head with little ears, a dark paddle of a tail
    m(flat([[0.32, 0], [0.24, 0.13], [0, 0.18], [-0.24, 0.15], [-0.34, 0], [-0.24, -0.15], [0, -0.18], [0.24, -0.13]]), 0x7a5232);
    m(flat([[0.5, 0], [0.44, 0.08], [0.36, 0.12], [0.3, 0.1], [0.3, -0.1], [0.36, -0.12], [0.44, -0.08]], 0.04), 0x6a4428).position.y = 0.02;
    m(flat([[-0.3, 0.07], [-0.5, 0.11], [-0.66, 0.08], [-0.7, 0], [-0.66, -0.08], [-0.5, -0.11], [-0.3, -0.07]], 0.02), 0x3a2a20).position.y = -0.01;
    // the wake: two pale streaks spreading back from the nose in a V
    const streak = flat([[0, 0.012], [-1.4, 0.03], [-1.4, -0.03], [0, -0.012]], 0.005);
    this.wake = [1, -1].map((s) => { const w = m(streak, 0xe6ece6, false); w.position.set(0.45, -0.02, 0); w.rotation.y = s * 0.42; return w; });
    this.g.scale.setScalar(1.35); this.g.visible = false;
    scene.add(this.g);
    this.lodge = null; this.a = 0; this.R = 2.6; this.dive = 0; this.next = 18; this.scanT = 0;
    this.onSlap = null;
  }

  update(dt, world, center) {
    // which lodge is ours: the nearest one within 45 m of the farmer (looked up now and then)
    if ((this.scanT -= dt) <= 0) {
      this.scanT = 2;
      const pool = world.pools.lodge; let best = null, bd = 45 * 45;
      if (pool) for (let i = 0; i < pool.mesh.count; i++) { const r = pool.owners[i]; if (!r) continue; const d = (r.x - center.x) ** 2 + (r.z - center.z) ** 2; if (d < bd) { bd = d; best = r; } }
      if (best !== this.lodge) { this.lodge = best; this.a = Math.random() * 6.28; }
    }
    if (!this.lodge) { this.g.visible = false; return; }
    this.g.visible = true;
    const L = this.lodge;
    // round and round the lodge, a slow paddle
    this.a += dt * (0.9 / this.R);
    const x = L.x + Math.cos(this.a) * this.R, z = L.z + Math.sin(this.a) * this.R;
    this.g.position.set(x, 0.03, z);
    this.g.rotation.y = -this.a - Math.PI; // facing along the circle (counter-clockwise)
    // the slap and dive, then up again further round
    this.next -= dt;
    if (this.next <= 0 && this.dive === 0) { this.dive = 0.001; this.onSlap?.(); }
    if (this.dive > 0) {
      this.dive += dt;
      this.g.position.y = 0.03 - Math.min(1, this.dive / 0.6) * 0.6; // under it goes
      if (this.dive > 0.6) this.g.visible = false;
      if (this.dive > 5) { this.dive = 0; this.next = 20 + Math.random() * 25; this.a += 1.6; }
    }
    if (!isWater(x, z) && this.dive === 0) this.g.visible = false; // round the far side of a small pond he swims under the bank
    for (const w of this.wake) w.visible = this.dive === 0;
  }
}
