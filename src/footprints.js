// Footprints in the snow: once the page is white over, the farmer's boots press a trail of little prints into it,
// left, right, left, a stride apart (round hoofprints, two by two, when riding), each a shallow blue-grey dent cut
// from paper, laid flat on the snow. They fill in slowly with fresh snow (shrinking away over half a minute or so),
// and the oldest are reused first. One instanced mesh of 90 prints (and a small one for Old Blue's paw prints, two by two); nothing at all when there's no snow.
import * as THREE from 'three/webgpu';
import { cardGeometry } from './props.js';
import { getHeight, isWater } from './world.js';

const N = 90, LIFE = 35;
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _p = new THREE.Vector3(), _s = new THREE.Vector3();

export class Footprints {
  constructor(scene) {
    // a boot sole: a rounded toe and a narrower heel, as one cut shape (it reads well at a glance from above)
    const sole = [];
    for (let i = 0; i <= 16; i++) { const a = (i / 16) * Math.PI; sole.push([Math.cos(a) * 0.075, 0.1 + Math.sin(a) * 0.08]); } // toe
    for (let i = 0; i <= 10; i++) { const a = Math.PI + (i / 10) * Math.PI; sole.push([Math.cos(a) * 0.055, -0.08 + Math.sin(a) * 0.05]); } // heel
    const geo = cardGeometry(sole, 0.006).rotateX(-Math.PI / 2); // (flat on the ground, toe along -z)
    this.mat = new THREE.MeshLambertNodeMaterial({ color: 0x8494b4 }); // (not the paper stock: that whitens anything facing up when it snows, and these must stay a shadowed blue)
    this.mesh = new THREE.InstancedMesh(geo, this.mat, N);
    this.mesh.frustumCulled = false; this.mesh.count = 0; this.mesh.receiveShadow = true; scene.add(this.mesh);
    this.p = Array.from({ length: N }, () => ({ age: LIFE, x: 0, z: 0, y: 0, yaw: 0, s: 1 }));
    // a dog's paw: a round pad (one more instanced mesh, small)
    const paw = []; for (let i = 0; i < 12; i++) { const a = (i / 12) * Math.PI * 2; paw.push([Math.cos(a) * 0.05, Math.sin(a) * 0.055]); }
    this.pawMesh = new THREE.InstancedMesh(cardGeometry(paw, 0.005).rotateX(-Math.PI / 2), this.mat, 60);
    this.pawMesh.frustumCulled = false; this.pawMesh.count = 0; scene.add(this.pawMesh);
    this.paws = Array.from({ length: 60 }, () => ({ age: LIFE, x: 0, z: 0, y: 0, yaw: 0, s: 1 }));
    this.next = 0; this.dist = 0; this.left = false; this.last = null; this.pawNext = 0; this.pawLast = null;
  }

  /** Old Blue's tracks: a pair of paw prints every half stride, close together (pos: the dog's) */
  dogTrack(snow, pos) {
    if (snow < 0.5) { this.pawLast = null; return; }
    if (!this.pawLast) { this.pawLast = pos.clone(); return; }
    const dx = pos.x - this.pawLast.x, dz = pos.z - this.pawLast.z, step = Math.hypot(dx, dz);
    if (step > 3) { this.pawLast.copy(pos); return; }
    if (step < 0.45) return;
    const yaw = Math.atan2(dx, dz);
    for (const off of [-0.07, 0.07]) {
      const x = pos.x + Math.cos(yaw) * off, z = pos.z - Math.sin(yaw) * off;
      if (isWater(x, z)) continue;
      Object.assign(this.paws[this.pawNext], { age: 0, x, z, y: getHeight(x, z) + 0.02, yaw, s: 1 });
      this.pawNext = (this.pawNext + 1) % this.paws.length;
    }
    this.pawLast.copy(pos);
  }

  /** snow: 0..1 cover; pos: the farmer's feet; riding: hoofprints instead of boots */
  update(dt, snow, pos, riding) {
    if (snow < 0.5) { if (this.mesh.count || this.pawMesh.count) { for (const P of [...this.p, ...this.paws]) P.age = LIFE; this.mesh.count = 0; this.pawMesh.count = 0; } this.last = null; return; }
    if (!this.last) this.last = pos.clone();
    const dx = pos.x - this.last.x, dz = pos.z - this.last.z, step = Math.hypot(dx, dz);
    if (step > 3) this.last.copy(pos); // (a jump in position: no trail across it)
    else if (step > (riding ? 0.9 : 0.62)) {
      const yaw = Math.atan2(dx, dz), side = this.left ? 1 : -1; this.left = !this.left;
      const n = riding ? 2 : 1;
      for (let k = 0; k < n; k++) {
        const off = (riding ? 0.22 * (k ? 1 : -1) : 0.13 * side), x = pos.x + Math.cos(yaw) * off, z = pos.z - Math.sin(yaw) * off;
        if (isWater(x, z)) continue;
        Object.assign(this.p[this.next], { age: 0, x, z, y: getHeight(x, z) + 0.02, yaw: yaw + Math.PI, s: riding ? 1.6 : 1.35 });
        this.next = (this.next + 1) % N;
      }
      this.last.copy(pos);
    }
    let c = 0;
    for (const P of this.p) {
      if (P.age >= LIFE) continue;
      P.age += dt; if (P.age >= LIFE) continue;
      const k = P.age / LIFE, s = P.s * (k < 0.7 ? 1 : 1 - (k - 0.7) / 0.3); // (filling in towards the end)
      _p.set(P.x, P.y, P.z); _q.setFromEuler(_e.set(0, P.yaw, 0));
      this.mesh.setMatrixAt(c++, _m.compose(_p, _q, _s.set(s, 1, s)));
    }
    this.mesh.count = c; if (c) this.mesh.instanceMatrix.needsUpdate = true;
    let pc = 0;
    for (const P of this.paws) {
      if (P.age >= LIFE) continue;
      P.age += dt; if (P.age >= LIFE) continue;
      const k = P.age / LIFE, s = k < 0.7 ? 1 : 1 - (k - 0.7) / 0.3;
      _p.set(P.x, P.y, P.z); _q.setFromEuler(_e.set(0, P.yaw, 0));
      this.pawMesh.setMatrixAt(pc++, _m.compose(_p, _q, _s.set(s, 1, s)));
    }
    this.pawMesh.count = pc; if (pc) this.pawMesh.instanceMatrix.needsUpdate = true;
  }
}
