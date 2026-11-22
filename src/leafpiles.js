// Leaf piles: four heaps of die-cut autumn leaves (maple-orange, barn red, mustard) raked up round the yard.
// Run or walk through one, or let Old Blue barrel into it, and the leaves burst up, flutter and spin down,
// lying flat and scattered where they land; after a while the breeze sweeps them back into a heap, one by one.
// All the leaves are one instanced mesh, and it only updates while leaves are on the move.
import * as THREE from 'three/webgpu';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight } from './world.js';
import { mulberry32 } from './noise.js';

const PER = 46;
const COLS = [0xe08a3a, 0xc8552f, 0xd9a441, 0xb8452e, 0xe6b45a, 0xa8642e];
// a maple-ish leaf: five lobes and a stem
const LEAF = [[0, -0.02], [0.03, 0.04], [0.12, 0.02], [0.09, 0.08], [0.14, 0.13], [0.07, 0.13], [0.06, 0.2], [0, 0.15], [-0.06, 0.2], [-0.07, 0.13], [-0.14, 0.13], [-0.09, 0.08], [-0.12, 0.02], [-0.03, 0.04]];

export class LeafPiles {
  constructor(scene, center) {
    const C = center;
    const art = paintCard(LEAF, {
      W: 128, H: 128, seed: 241, base: '#f1e6cc', fills: ['rgba(255,250,240,A)', 'rgba(230,220,200,A)'], edge: 'rgba(120,70,40,1)',
      details(g, px) { g.strokeStyle = 'rgba(110,60,30,0.55)'; g.lineWidth = 2.5; for (const [x, y] of [[0, 0.17], [0.11, 0.11], [-0.11, 0.11]]) { const [a, b] = px(0, 0.01), [c, d] = px(x, y); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); } },
    });
    this.spots = [[-2.4, 3.2], [5.2, 3.8], [8.6, -1.4], [-5.4, 1.2]].map(([x, z]) => { const v = new THREE.Vector3(C.x + x, 0, C.z + z); v.y = getHeight(v.x, v.z); return v; });
    const N = PER * this.spots.length;
    this.mesh = new THREE.InstancedMesh(cardGeometry(LEAF, 0.006).rotateX(-Math.PI / 2), cardMaterial(art, { side: THREE.DoubleSide }), N);
    this.mesh.castShadow = true; this.mesh.receiveShadow = true;
    const rng = mulberry32(243), c = new THREE.Color();
    this.leaves = [];
    this.spots.forEach((s, pi) => {
      for (let i = 0; i < PER; i++) {
        // stacked into a dome: more leaves low and wide, fewer up top
        const h = Math.pow(rng(), 1.6), r = (1 - h * 0.8) * 0.95 * Math.sqrt(rng()), a = rng() * Math.PI * 2;
        const home = new THREE.Vector3(s.x + Math.cos(a) * r, s.y + 0.02 + h * 0.5, s.z + Math.sin(a) * r);
        const L = { pile: pi, home, pos: home.clone(), vel: new THREE.Vector3(), rot: new THREE.Euler((rng() - 0.5) * 0.9, rng() * 6.28, (rng() - 0.5) * 0.9), spin: new THREE.Vector3(), state: 'heap', t: 0, scale: 1.6 + rng() * 0.8 };
        this.leaves.push(L);
        this.mesh.setColorAt(this.leaves.length - 1, c.setHex(COLS[Math.floor(rng() * COLS.length)]));
        this.write(this.leaves.length - 1);
      }
    });
    scene.add(this.mesh);
    this.moving = 0;
    this.onKick = null;
    this.cool = this.spots.map(() => 0);
  }

  write(i) {
    const L = this.leaves[i];
    _q.setFromEuler(L.rot); _m.compose(L.pos, _q, _s.setScalar(L.scale));
    this.mesh.setMatrixAt(i, _m);
  }

  /** kickers: [{ pos, speed }] (the farmer, Old Blue). Returns the pile index kicked this frame, or -1. */
  update(dt, kickers) {
    let kicked = -1;
    this.spots.forEach((s, pi) => {
      this.cool[pi] = Math.max(0, this.cool[pi] - dt);
      for (const k of kickers) {
        if (k.speed < 1.2 || this.cool[pi] > 0) continue;
        const d = Math.hypot(k.pos.x - s.x, k.pos.z - s.z);
        if (d > 1.1) continue;
        // whoosh: every leaf of the heap that's still near it bursts up and away from whoever ran through
        this.cool[pi] = 1.5; kicked = pi;
        for (const L of this.leaves) {
          if (L.pile !== pi || Math.hypot(L.pos.x - s.x, L.pos.z - s.z) > 1.4) continue;
          const ax = L.pos.x - k.pos.x, az = L.pos.z - k.pos.z, al = Math.hypot(ax, az) || 1;
          const f = 1.2 + Math.random() * 2.2;
          L.vel.set((ax / al) * f + (Math.random() - 0.5), 2.2 + Math.random() * 3.2, (az / al) * f + (Math.random() - 0.5));
          L.spin.set((Math.random() - 0.5) * 12, (Math.random() - 0.5) * 8, (Math.random() - 0.5) * 12);
          L.state = 'fly'; L.t = 0;
        }
      }
    });
    if (kicked >= 0) this.onKick?.(kicked);
    // move what's moving: fluttering down, lying still a while, then swept home by the breeze
    let moving = 0;
    for (let i = 0; i < this.leaves.length; i++) {
      const L = this.leaves[i];
      if (L.state === 'heap') continue;
      moving++;
      L.t += dt;
      if (L.state === 'fly') {
        L.vel.y -= 6 * dt; // light paper: gravity is gentle, and air drags it
        L.vel.multiplyScalar(1 - Math.min(1, dt * 1.6));
        if (L.vel.y < -1.2) L.vel.y = -1.2 + Math.sin(L.t * 6 + i) * 0.3; // a falling leaf flutters
        L.pos.addScaledVector(L.vel, dt);
        L.pos.x += Math.sin(L.t * 4 + i) * 0.4 * dt;
        L.rot.x += L.spin.x * dt; L.rot.y += L.spin.y * dt; L.rot.z += L.spin.z * dt;
        const g = getHeight(L.pos.x, L.pos.z) + 0.02;
        if (L.pos.y <= g && L.vel.y < 0) { L.pos.y = g; L.state = 'lie'; L.t = 0; L.rot.x = (Math.random() - 0.5) * 0.2; L.rot.z = (Math.random() - 0.5) * 0.2; }
      } else if (L.state === 'lie') {
        if (L.t > 25 + (i % 17)) { L.state = 'home'; L.t = 0; }
      } else if (L.state === 'home') {
        // skitters back over the grass, a hop at a time
        const to = _v.subVectors(L.home, L.pos); const d = to.length();
        if (d < 0.05) { L.pos.copy(L.home); L.state = 'heap'; }
        else {
          L.pos.addScaledVector(to.normalize(), Math.min(d, dt * 0.6));
          L.pos.y = Math.max(getHeight(L.pos.x, L.pos.z) + 0.02, L.pos.y) + Math.abs(Math.sin(L.t * 5 + i)) * 0.004;
          L.rot.y += dt * 0.8;
        }
      }
      this.write(i);
    }
    if (moving || this.moving) this.mesh.instanceMatrix.needsUpdate = true;
    this.moving = moving;
    return kicked;
  }
}

const _q = new THREE.Quaternion(), _m = new THREE.Matrix4(), _s = new THREE.Vector3(), _v = new THREE.Vector3();
