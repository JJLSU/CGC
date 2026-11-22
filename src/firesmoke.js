// Smoke and sparks over your own fires: soft cream paper puffs drift up from each campfire (and the forge's
// chimney), leaning with the wind and opening out as they climb. After dusk, little orange flecks of cut paper
// fly up from the coals, twisting, and wink out. Only the fires nearest the farmer get them (up to three),
// and everything is two instanced meshes.
import * as THREE from 'three/webgpu';
import { vec3, uniform } from 'three/tsl';
import { paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';

const FIRES = 3, PUFFS = 7, SPARKS = 10;

export class FireSmoke {
  constructor(scene) {
    // a soft cloud of a puff: five round lobes, cut from one sheet
    const puff = Array.from({ length: 30 }, (_, i) => { const a = (i / 30) * Math.PI * 2, r = 0.42 + 0.1 * Math.abs(Math.sin(a * 2.5)); return [Math.cos(a) * r, Math.sin(a) * r * 0.85]; });
    this.puffs = new THREE.InstancedMesh(cardGeometry(puff, 0.04), (this.puffMat = paperMaterial({ color: 0xe8e0d0, emissive: 0xd8c8a8, emissiveIntensity: 0.35 })), FIRES * PUFFS);
    this.puffs.frustumCulled = false; this.puffs.count = 0;
    scene.add(this.puffs);
    this.glow = uniform(1);
    const sparkMat = new THREE.MeshBasicNodeMaterial({ side: THREE.DoubleSide });
    sparkMat.colorNode = vec3(2.0, 0.9, 0.25).mul(this.glow);
    this.sparks = new THREE.InstancedMesh(new THREE.PlaneGeometry(0.06, 0.1), sparkMat, FIRES * SPARKS);
    this.sparks.frustumCulled = false; this.sparks.count = 0;
    scene.add(this.sparks);
    this.t = 0;
    this.seeds = Array.from({ length: FIRES * Math.max(PUFFS, SPARKS) }, () => Math.random());
  }

  /** fires: [{ x, y, z, top }] world points where the smoke leaves (nearest first). */
  update(dt, fires, camera, night, rain) {
    this.t += dt;
    const t = this.t;
    this.puffMat.emissiveIntensity = 0.35 * (1 - Math.min(1, night * 1.4)); // (cream puffs, lit through: a soft glow of their own by day so a puff against the sun stays cream, never grey; none after dark)
    let np = 0, ns = 0;
    const lean = 0.5 + 0.25 * Math.sin(t * 0.21); // the breeze, out of the west like the barn rooster says
    for (let f = 0; f < Math.min(FIRES, fires.length); f++) {
      const F = fires[f];
      for (let i = 0; i < PUFFS; i++) {
        const k = ((t / 7 + i / PUFFS + this.seeds[f * 9 + i] * 0.1) % 1); // each puff's life, 0 → 1, about 7 s
        const rise = k * 4.2;
        _p.set(F.x + rise * lean * (0.8 + 0.4 * Math.sin(i)) + Math.sin(t * 0.9 + i * 2) * 0.12, F.y + F.top + rise, F.z + rise * 0.15 + Math.cos(t * 0.7 + i) * 0.1);
        const s = (0.18 + k * 0.75) * (k < 0.1 ? k / 0.1 : 1) * (k > 0.8 ? (1 - k) / 0.2 : 1) * (rain > 0.3 ? 0.6 : 1);
        _q.setFromEuler(_e.set(-Math.atan2(camera.position.y - _p.y, Math.hypot(camera.position.x - _p.x, camera.position.z - _p.z)), Math.atan2(camera.position.x - _p.x, camera.position.z - _p.z), i * 1.3 + t * 0.2, 'YXZ')); // (full face to the lens, pitched up to a camera looking down, so no puff is seen edge-on and in shade)
        _m.compose(_p, _q, _s.setScalar(s));
        this.puffs.setMatrixAt(np++, _m);
      }
      if (night > 0.35 && F.sparks) {
        for (let i = 0; i < SPARKS; i++) {
          const seed = this.seeds[f * 9 + (i % 9)] + i * 0.37;
          const k = ((t / 1.6 + seed) % 1);
          _p.set(F.x + Math.sin(seed * 20 + k * 3) * 0.3 * k, F.y + 0.4 + k * 2.2, F.z + Math.cos(seed * 17 + k * 2) * 0.3 * k);
          _q.setFromEuler(_e.set(t * 6 + seed * 9, t * 4 + seed * 5, 0));
          _m.compose(_p, _q, _s.setScalar(k < 0.85 ? 1 : (1 - k) / 0.15));
          this.sparks.setMatrixAt(ns++, _m);
        }
      }
    }
    this.puffs.count = np; this.sparks.count = ns;
    if (np) this.puffs.instanceMatrix.needsUpdate = true;
    if (ns) this.sparks.instanceMatrix.needsUpdate = true;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _m = new THREE.Matrix4(), _s = new THREE.Vector3();
