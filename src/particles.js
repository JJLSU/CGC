// Paper confetti / chips: one instanced mesh of tiny fluttering card scraps.
import * as THREE from 'three/webgpu';
import { paperMaterial } from './materials.js';

const MAX = 500;

export class Confetti {
  constructor(scene) {
    const geo = new THREE.PlaneGeometry(0.16, 0.1);
    this.mesh = new THREE.InstancedMesh(geo, paperMaterial({ side: THREE.DoubleSide, flatShading: false }), MAX);
    this.mesh.frustumCulled = false;
    this.mesh.castShadow = true;
    const zero = new THREE.Matrix4().makeScale(0, 0, 0);
    const white = new THREE.Color(1, 1, 1);
    for (let i = 0; i < MAX; i++) { this.mesh.setMatrixAt(i, zero); this.mesh.setColorAt(i, white); }
    scene.add(this.mesh);
    this.parts = [];
    this.next = 0;
    this.color = new THREE.Color();
  }

  burst(pos, colors, count = 20, power = 1) {
    for (let n = 0; n < count; n++) {
      const i = this.next; this.next = (this.next + 1) % MAX;
      const a = Math.random() * Math.PI * 2, up = 2 + Math.random() * 4;
      const sp = (1 + Math.random() * 2.5) * power;
      this.parts[i] = {
        p: new THREE.Vector3(pos.x + (Math.random() - 0.5) * 0.6, pos.y + Math.random() * 0.6, pos.z + (Math.random() - 0.5) * 0.6),
        v: new THREE.Vector3(Math.cos(a) * sp, up * power, Math.sin(a) * sp),
        r: new THREE.Euler(Math.random() * 6, Math.random() * 6, Math.random() * 6),
        w: new THREE.Vector3((Math.random() - 0.5) * 14, (Math.random() - 0.5) * 14, (Math.random() - 0.5) * 14),
        life: 1.6 + Math.random() * 1.2, seed: Math.random() * 10, s: 0.7 + Math.random() * 0.8,
      };
      this.mesh.setColorAt(i, this.color.setHex(colors[n % colors.length]).offsetHSL(0, 0, (Math.random() - 0.5) * 0.1));
    }
    this.mesh.instanceColor.needsUpdate = true;
  }

  update(dt, groundAt) {
    let any = false;
    for (let i = 0; i < this.parts.length; i++) {
      const q = this.parts[i];
      if (!q) continue;
      q.life -= dt;
      if (q.life <= 0) { this.parts[i] = null; _m.makeScale(0, 0, 0); this.mesh.setMatrixAt(i, _m); any = true; continue; }
      q.v.y -= 9 * dt;
      if (q.v.y < -1.8) q.v.y = -1.8; // paper flutters, it doesn't drop
      q.v.x *= 1 - dt * 1.5; q.v.z *= 1 - dt * 1.5;
      const t = performance.now() * 0.001 + q.seed;
      q.p.x += (q.v.x + Math.sin(t * 5) * 0.6) * dt;
      q.p.z += (q.v.z + Math.cos(t * 4) * 0.6) * dt;
      q.p.y += q.v.y * dt;
      const g = groundAt(q.p.x, q.p.z) + 0.03;
      if (q.p.y < g) { q.p.y = g; q.v.set(0, 0, 0); q.w.multiplyScalar(0.8); }
      q.r.x += q.w.x * dt; q.r.y += q.w.y * dt; q.r.z += q.w.z * dt;
      const s = q.s * Math.min(1, q.life * 2);
      _m.compose(q.p, _q.setFromEuler(q.r), _s.setScalar(s));
      this.mesh.setMatrixAt(i, _m);
      any = true;
    }
    if (any) this.mesh.instanceMatrix.needsUpdate = true;
  }
}

const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _s = new THREE.Vector3();
