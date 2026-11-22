// Saturday-night fireworks: once all three streets of the town are mended, Paydirt Hollow celebrates every Saturday
// evening. From the field behind the church, rockets go up one after another trailing a few sparks, and burst into a
// round of little cut-paper stars (red, cream, gold or blue) that open out, hang a moment, then drift down shrinking
// away. One instanced mesh of 240 star cards, lit by their own colour; only while the show is on.
import * as THREE from 'three/webgpu';
import { cardGeometry } from './props.js';

const MAX = 240, STAR = 30, COLORS = [0xff6a4a, 0xfff0c8, 0xffc848, 0x7ab0ff, 0xff8ac0];
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _p = new THREE.Vector3(), _s = new THREE.Vector3(), _c = new THREE.Color();

export class Fireworks {
  constructor(scene) {
    const star = []; for (let i = 0; i < 10; i++) { const a = (i / 10) * Math.PI * 2 + Math.PI / 2, r = i % 2 ? 0.45 : 1; star.push([Math.cos(a) * r, Math.sin(a) * r]); } // (a five-point star)
    const mat = new THREE.MeshBasicNodeMaterial({ side: THREE.DoubleSide });
    this.mesh = new THREE.InstancedMesh(cardGeometry(star, 0.04), mat, MAX);
    this.mesh.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(MAX * 3), 3);
    this.mesh.frustumCulled = false; this.mesh.count = 0; scene.add(this.mesh);
    this.p = Array.from({ length: MAX }, () => ({ age: 9, life: 1, x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0, s: 0.2, spin: 0, rocket: false }));
    this.next = 0; this.wait = 0; this.rockets = [];
  }

  spawn(o) { const P = this.p[this.next]; this.next = (this.next + 1) % MAX; Object.assign(P, o); return P; }

  /** on: the show is running; at: where rockets go up from; onPop(x, y, z) for the bang. */
  update(dt, on, at, camera, onPop) {
    if (on && (this.wait -= dt) <= 0) {
      this.wait = 1.4 + Math.random() * 1.6;
      this.rockets.push({ x: at.x + (Math.random() - 0.5) * 8, y: at.y, z: at.z + (Math.random() - 0.5) * 8, vy: 16 + Math.random() * 4, t: 0, fuse: 1.4 + Math.random() * 0.5, col: COLORS[Math.floor(Math.random() * COLORS.length)] });
    }
    for (let i = this.rockets.length - 1; i >= 0; i--) {
      const R = this.rockets[i]; R.t += dt; R.vy -= 6 * dt; R.y += R.vy * dt;
      if (Math.random() < dt * 14) this.spawn({ age: 0, life: 0.5, x: R.x, y: R.y, z: R.z, vx: (Math.random() - 0.5) * 0.6, vy: -1, vz: (Math.random() - 0.5) * 0.6, s: 0.12, spin: Math.random() * 6, col: 0xffd890 }); // (its trail)
      if (R.t >= R.fuse) { // burst: a ring of stars thrown out on a sphere
        const n = STAR, sp = 7 + Math.random() * 3;
        for (let k = 0; k < n; k++) {
          const u = Math.random() * 2 - 1, a = Math.random() * Math.PI * 2, r = Math.sqrt(1 - u * u);
          this.spawn({ age: 0, life: 2 + Math.random() * 0.8, x: R.x, y: R.y, z: R.z, vx: Math.cos(a) * r * sp, vy: u * sp, vz: Math.sin(a) * r * sp, s: 0.45 + Math.random() * 0.15, spin: Math.random() * 6, col: Math.random() < 0.2 ? 0xfff0c8 : R.col });
        }
        onPop?.(R.x, R.y, R.z); this.rockets.splice(i, 1);
      }
    }
    let n = 0;
    for (const P of this.p) {
      if (P.age >= P.life) continue;
      P.age += dt; if (P.age >= P.life) continue;
      const drag = Math.max(0, 1 - dt * 2.2); P.vx *= drag; P.vz *= drag; P.vy = P.vy * drag - 2.4 * dt; // (they open fast, then hang and drift down)
      P.x += P.vx * dt; P.y += P.vy * dt; P.z += P.vz * dt;
      const k = P.age / P.life, s = P.s * (k < 0.08 ? k / 0.08 : 1) * (1 - k * k);
      _p.set(P.x, P.y, P.z);
      _q.setFromEuler(_e.set(-Math.atan2(camera.position.y - P.y, Math.hypot(camera.position.x - P.x, camera.position.z - P.z)), Math.atan2(camera.position.x - P.x, camera.position.z - P.z), P.spin + P.age * 3, 'YXZ'));
      this.mesh.setMatrixAt(n, _m.compose(_p, _q, _s.setScalar(Math.max(0.001, s))));
      this.mesh.setColorAt(n, _c.setHex(P.col).multiplyScalar(1.6)); n++;
    }
    this.mesh.count = n;
    if (n) { this.mesh.instanceMatrix.needsUpdate = true; this.mesh.instanceColor.needsUpdate = true; }
  }
}
