// Giant pumpkins: on each pumpkin patch you've built, a prize pumpkin swells a little bigger every day you
// tend it (once a day, E), from a fist-sized green-gold fruit to a great ribbed orange whopper you could sit on.
// They're the garden's own crossed pumpkin cards, one instanced mesh, set to each patch's size.
import * as THREE from 'three/webgpu';
import { propKinds } from './props.js';

export const GIANT_STAGES = 5;
const PATCHES = 4;
const SIZE = [0.5, 0.9, 1.4, 2.0, 2.7, 3.4]; // by stage

export class GiantPumpkins {
  constructor(scene) {
    const k = propKinds().pumpkin;
    this.mesh = new THREE.InstancedMesh(k.geometry, k.material, PATCHES);
    this.mesh.castShadow = true; this.mesh.receiveShadow = true; this.mesh.count = 0; this.mesh.frustumCulled = false;
    scene.add(this.mesh);
    this.sig = '';
    this.t = 0;
  }

  update(dt, pieces, center) {
    this.t += dt;
    const patches = pieces.filter((p) => p.type === 'patch' && p.risen).sort((a, b) => ((a.x - center.x) ** 2 + (a.z - center.z) ** 2) - ((b.x - center.x) ** 2 + (b.z - center.z) ** 2)).slice(0, PATCHES);
    const sig = patches.map((p) => `${p.x.toFixed(1)},${p.z.toFixed(1)},${p.stage || 0}`).join('|');
    // a fresh stage swells up with a little springy overshoot (the card hinging fuller), then settles
    if (sig !== this.sig) { this.sig = sig; this.grownAt = this.t; }
    const k = Math.min(1, (this.t - (this.grownAt ?? -9)) / 0.9), pop = 1 + Math.sin(k * Math.PI) * 0.08 * (1 - k);
    let n = 0;
    for (const p of patches) {
      const s = SIZE[Math.min(GIANT_STAGES, p.stage || 0)] * pop;
      _q.setFromAxisAngle(_y, ((p.rot || 0) * Math.PI) / 2 + 0.4);
      _m.compose(_p.set(p.x, p.y + 0.05, p.z), _q, _s.set(s, s * 0.92, s));
      this.mesh.setMatrixAt(n++, _m);
    }
    this.mesh.count = n;
    if (n) this.mesh.instanceMatrix.needsUpdate = true;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _m = new THREE.Matrix4(), _s = new THREE.Vector3(), _y = new THREE.Vector3(0, 1, 0);
