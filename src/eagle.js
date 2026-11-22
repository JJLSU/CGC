// A bald eagle over the high country: by day, when there's highland or peak within reach of the farmer, an eagle
// soars in wide slow circles high over it, banking into the turn, its shadow sweeping the hillside. Now and then
// it gives three lazy wingbeats, then glides on. Built to read from above like the geese: dark-brown broad
// wings with fingered tips, a white head with a yellow hooked beak, a white fan of a tail.
import * as THREE from 'three/webgpu';
import { getHeight, regionAt } from './world.js';
import { paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';

export class Eagle {
  constructor(scene) {
    const flat = (pts, t = 0.02) => cardGeometry(pts, t).rotateX(-Math.PI / 2);
    this.g = new THREE.Group();
    const m = (geo, hex, shadow = false) => { const x = new THREE.Mesh(geo, paperMaterial({ color: hex, side: THREE.DoubleSide })); x.castShadow = shadow; this.g.add(x); return x; };
    m(flat([[0.36, 0], [0.24, 0.12], [-0.1, 0.13], [-0.36, 0.08], [-0.36, -0.08], [-0.1, -0.13], [0.24, -0.12]]), 0x4a3424, true); // body
    m(flat([[0.62, 0], [0.56, 0.08], [0.4, 0.11], [0.3, 0.08], [0.3, -0.08], [0.4, -0.11], [0.56, -0.08]], 0.03), 0xf3ead6).position.y = 0.01; // white head
    m(flat([[0.72, 0], [0.62, 0.035], [0.6, -0.035]], 0.035), 0xe0a832).position.y = 0.012; // yellow beak
    m(flat([[-0.34, 0.08], [-0.66, 0.16], [-0.7, 0.05], [-0.72, -0.05], [-0.66, -0.16], [-0.34, -0.08]], 0.02), 0xf3ead6).position.y = 0.005; // white tail fan
    // broad wings with fingered primaries, hinged at the shoulders
    const wing = flat([[0.16, 0], [-0.16, 0], [-0.28, 0.6], [-0.2, 1.2], [-0.04, 1.4], [0.02, 1.3], [0.08, 1.38], [0.12, 1.26], [0.18, 1.3], [0.2, 0.9]], 0.018);
    this.wl = m(wing, 0x3e2c1e, true); this.wr = m(wing, 0x3e2c1e, true);
    this.wl.position.z = 0.1; this.wr.position.z = -0.1; this.wr.scale.z = -1;
    this.g.scale.setScalar(2.4); this.g.visible = false;
    scene.add(this.g);
    this.center = new THREE.Vector3(); this.has = false; this.a = 0; this.t = 0; this.scanT = 0; this.flapT = 8;
  }

  update(dt, focus, sky) {
    // find high ground to circle over, now and then: the nearest highland or peak within ~70 m of the farmer
    if ((this.scanT -= dt) <= 0) {
      this.scanT = 12; this.has = false;
      let bd = Infinity;
      for (let k = 0; k < 24; k++) {
        const a = (k / 24) * Math.PI * 2, d = 25 + (k % 3) * 20, x = focus.x + Math.cos(a) * d, z = focus.z + Math.sin(a) * d;
        const reg = regionAt(x, z);
        if ((reg === 'highland' || reg === 'peak') && d < bd) { bd = d; this.center.set(x, getHeight(x, z), z); this.has = true; }
      }
    }
    this.g.visible = this.has && sky.night < 0.35;
    if (!this.g.visible) return;
    this.t += dt;
    this.a += dt * 0.16; // one slow round in about forty seconds
    const R = 16, x = this.center.x + Math.cos(this.a) * R, z = this.center.z + Math.sin(this.a) * R;
    this.g.position.set(x, this.center.y + 26 + Math.sin(this.t * 0.3) * 1.5, z);
    this.g.rotation.set(0, -this.a - Math.PI / 2, 0); // nose along the circle
    this.g.rotateX(0.3); // banked into the turn
    // mostly gliding with wings held a touch up; now and then three slow beats
    this.flapT -= dt;
    let flap = 0.08;
    if (this.flapT < 0) { flap = 0.08 + Math.sin(-this.flapT * 4.5) * 0.45; if (this.flapT < -2.1) this.flapT = 9 + Math.random() * 8; }
    this.wl.rotation.x = -flap; this.wr.rotation.x = flap;
  }
}
