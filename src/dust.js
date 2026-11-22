// Hoof dust: riding hard on dry ground, Biscuit's hooves kick up little rounds of tan paper that puff out behind her,
// drift up a hand or two and shrink away. None in the wet (rain, fords) and only at a lope or better. One instanced
// mesh of a couple of dozen scraps, recycled.
import * as THREE from 'three/webgpu';
import { paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { getHeight, isWater } from './world.js';

const N = 28, LIFE = 1.1;
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _p = new THREE.Vector3(), _s = new THREE.Vector3();

export class HoofDust {
  constructor(scene) {
    const puff = Array.from({ length: 18 }, (_, i) => { const a = (i / 18) * Math.PI * 2, r = 0.4 + 0.1 * Math.abs(Math.sin(a * 2.5)); return [Math.cos(a) * r, Math.sin(a) * r * 0.8]; });
    this.mat = paperMaterial({ color: 0xcdb48a, emissive: 0xb89a6a, emissiveIntensity: 0.25 });
    this.mesh = new THREE.InstancedMesh(cardGeometry(puff, 0.03), this.mat, N);
    this.mesh.frustumCulled = false; this.mesh.count = 0; scene.add(this.mesh);
    this.p = Array.from({ length: N }, () => ({ age: LIFE, x: 0, y: 0, z: 0, vx: 0, vz: 0, s: 1, spin: 0 }));
    this.next = 0; this.acc = 0;
  }

  /** pos/vel: the horse's; on: riding at a lope on dry ground. */
  update(dt, pos, vel, on, camera) {
    const sp = Math.hypot(vel.x, vel.z);
    if (on && sp > 4) {
      this.acc += dt * Math.min(14, sp * 1.6); // (more puffs the harder she runs)
      while (this.acc >= 1) {
        this.acc -= 1;
        const P = this.p[this.next]; this.next = (this.next + 1) % N;
        const bx = pos.x - (vel.x / sp) * 0.9 + (Math.random() - 0.5) * 0.7, bz = pos.z - (vel.z / sp) * 0.9 + (Math.random() - 0.5) * 0.7;
        if (isWater(bx, bz)) continue;
        Object.assign(P, { age: 0, x: bx, y: getHeight(bx, bz) + 0.15, z: bz, vx: -vel.x * 0.12 + (Math.random() - 0.5) * 0.6, vz: -vel.z * 0.12 + (Math.random() - 0.5) * 0.6, s: 0.35 + Math.random() * 0.3, spin: Math.random() * 6 });
      }
    } else this.acc = 0;
    let n = 0;
    for (const P of this.p) {
      if (P.age >= LIFE) continue;
      P.age += dt; if (P.age >= LIFE) continue;
      const k = P.age / LIFE;
      P.x += P.vx * dt; P.z += P.vz * dt; P.y += dt * 0.5 * (1 - k); P.vx *= 1 - dt * 2; P.vz *= 1 - dt * 2;
      const s = P.s * (0.5 + k * 0.9) * (k < 0.12 ? k / 0.12 : 1) * (1 - k * k); // (swell out, then shrink away)
      _p.set(P.x, P.y, P.z);
      _q.setFromEuler(_e.set(-Math.atan2(camera.position.y - P.y, Math.hypot(camera.position.x - P.x, camera.position.z - P.z)), Math.atan2(camera.position.x - P.x, camera.position.z - P.z), P.spin + k, 'YXZ'));
      this.mesh.setMatrixAt(n++, _m.compose(_p, _q, _s.setScalar(Math.max(0.001, s))));
    }
    this.mesh.count = n; if (n) this.mesh.instanceMatrix.needsUpdate = true;
  }
}
