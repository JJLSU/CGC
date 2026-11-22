// Wading: flat cream paper rings spreading out on the water from the farmer's shins, one with every step and a
// slow one now and then while he stands still; a few flicks of paper spray when he's moving. Six ring meshes,
// reused round-robin.
import * as THREE from 'three/webgpu';

const N = 6, LIFE = 1.6;
export class Wake {
  constructor(scene) {
    const geo = new THREE.RingGeometry(0.86, 1, 32).rotateX(-Math.PI / 2);
    this.rings = Array.from({ length: N }, () => {
      const m = new THREE.Mesh(geo, new THREE.MeshBasicNodeMaterial({ color: 0xf3ead6, transparent: true, depthWrite: false }));
      m.visible = false; m.renderOrder = 2; scene.add(m); return { m, t: 9, size: 1 };
    });
    this.idle = 0;
  }
  ring(x, z, size = 1) {
    const r = this.rings.reduce((a, b) => (b.t > a.t ? b : a));
    r.t = 0; r.size = size; r.m.position.set(x, 0.035, z); r.m.visible = true;
  }
  /** wading: is he in the water; moving: his speed (m/s). */
  update(dt, pos, wading, moving) {
    if (wading && moving < 0.3 && (this.idle -= dt) <= 0) { this.idle = 1.4 + Math.random() * 0.8; this.ring(pos.x, pos.z, 0.7); }
    for (const r of this.rings) {
      if (r.t > LIFE) { r.m.visible = false; continue; }
      r.t += dt;
      const k = r.t / LIFE;
      r.m.scale.setScalar((0.3 + k * 1.3) * r.size);
      r.m.material.opacity = 0.75 * (1 - k) * (1 - k);
    }
  }
}
