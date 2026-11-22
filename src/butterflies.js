// Butterflies on fine days: little die-cut paper wings (monarch orange, sulphur yellow, cabbage white)
// flapping on a crease along the body, looping lazily over the grass around the farmer. They keep out of the
// rain and go to roost at dusk. Two instanced meshes (left and right wings) for all of them.
import * as THREE from 'three/webgpu';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight } from './world.js';

const N = 18;
const COLS = [0xf3ede0, 0xf0d84a, 0xe0782e, 0xf3ede0, 0xbcd0e8, 0xf0d84a]; // whites, sulphurs and blues stand out against the autumn leaves; a monarch now and then

export class Butterflies {
  constructor(scene) {
    // one wing, hinged at the body (x = 0), reaching out along +x; the other is its mirror
    const wing = [[0, 0.02], [0.08, 0.1], [0.16, 0.1], [0.18, 0.04], [0.12, -0.01], [0.14, -0.07], [0.08, -0.11], [0.02, -0.06]];
    const art = paintCard(wing, {
      W: 160, H: 160, seed: 181, base: '#f6f0e4', fills: ['rgba(255,252,244,A)', 'rgba(240,232,214,A)'], edge: 'rgba(40,32,28,1)',
      details(g, px) {
        g.strokeStyle = 'rgba(40,32,28,0.85)'; g.lineWidth = 3;
        for (const [x1, y1] of [[0.15, 0.09], [0.17, 0.03], [0.12, -0.08]]) { const [a, b] = px(0.01, 0), [c, d] = px(x1, y1); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); }
        g.fillStyle = 'rgba(40,32,28,0.9)'; // a dark border with little white spots
        const [ox, oy] = px(0.165, 0.07); g.beginPath(); g.arc(ox, oy, 9, 0, Math.PI * 2); g.fill();
        g.fillStyle = '#fffaf0'; g.beginPath(); g.arc(ox, oy, 3.5, 0, Math.PI * 2); g.fill();
      },
    });
    const mat = cardMaterial(art, { side: THREE.DoubleSide });
    const left = cardGeometry(wing, 0.004).rotateX(-Math.PI / 2);
    const right = cardGeometry(wing.map(([x, y]) => [-x, y]), 0.004).rotateX(-Math.PI / 2);
    this.wl = new THREE.InstancedMesh(left, mat, N); this.wr = new THREE.InstancedMesh(right, mat, N);
    const c = new THREE.Color();
    for (const m of [this.wl, this.wr]) {
      m.frustumCulled = false; m.count = 0;
      for (let i = 0; i < N; i++) m.setColorAt(i, c.setHex(COLS[i % COLS.length]));
      scene.add(m);
    }
    this.bugs = Array.from({ length: N }, (_, i) => ({ home: new THREE.Vector3(), seed: i * 7.31, set: false }));
    this.t = 0;
  }

  update(dt, center, { night, rain }) {
    this.t += dt;
    const show = night < 0.3 && rain < 0.15;
    const n = show ? N : 0;
    this.wl.count = this.wr.count = n;
    if (!n) return;
    for (let i = 0; i < n; i++) {
      const b = this.bugs[i];
      // each keeps to a patch of meadow; a new patch when the farmer has wandered far off
      if (!b.set || b.home.distanceToSquared(center) > 30 * 30) {
        const a = Math.random() * Math.PI * 2, d = 4 + Math.random() * 18;
        b.home.set(center.x + Math.cos(a) * d, 0, center.z + Math.sin(a) * d); b.set = true;
      }
      const s = b.seed, t = this.t;
      const x = b.home.x + Math.sin(t * 0.37 + s) * 3 + Math.sin(t * 1.3 + s * 2) * 0.4;
      const z = b.home.z + Math.cos(t * 0.29 + s * 1.7) * 3 + Math.cos(t * 1.1 + s) * 0.4;
      const y = getHeight(x, z) + 0.6 + Math.sin(t * 0.8 + s) * 0.35 + Math.abs(Math.sin(t * 3.1 + s)) * 0.15;
      // heading along the path; wings beat on the body crease
      const dx = Math.cos(t * 0.37 + s) * 0.37 * 3, dz = -Math.sin(t * 0.29 + s * 1.7) * 0.29 * 3;
      const yaw = Math.atan2(dx, dz);
      const flap = 0.2 + Math.abs(Math.sin(t * 13 + s * 3)) * 1.1;
      _p.set(x, y, z);
      _q.setFromEuler(_e.set(0, yaw, flap, 'YXZ')); _m.compose(_p, _q, _s); this.wl.setMatrixAt(i, _m);
      _q.setFromEuler(_e.set(0, yaw, -flap, 'YXZ')); _m.compose(_p, _q, _s); this.wr.setMatrixAt(i, _m);
    }
    this.wl.instanceMatrix.needsUpdate = this.wr.instanceMatrix.needsUpdate = true;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _m = new THREE.Matrix4(), _s = new THREE.Vector3(2.3, 2.3, 2.3);
