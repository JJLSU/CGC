// Summer thunderstorms: about one rain shower in four rolls in as a thunderstorm. While it pours, every ten
// seconds or so a cut-paper lightning bolt (a jagged cream-gold card) stabs down out of the clouds somewhere
// far off across the county, flickers twice, and is gone; the whole page flashes pale for an instant, and a
// beat or three later (the farther off, the longer) the thunder rolls in. Snug on the porch, it's a fine show.
import * as THREE from 'three/webgpu';
import { cardGeometry } from './props.js';
import { vec3 } from 'three/tsl';

const BOLT = [[0, 0], [0.9, 2.6], [0.3, 2.6], [1.3, 5.4], [0.6, 5.4], [1.8, 8.6], [-0.2, 4.6], [0.5, 4.6], [-0.6, 2.0], [0.1, 2.0], [-0.5, 0]];

export class Storm {
  constructor(scene) {
    const m = new THREE.MeshBasicNodeMaterial({ side: THREE.DoubleSide, fog: false });
    m.colorNode = vec3(2.4, 2.15, 1.5); // brighter than paper: it should crack the gloom
    this.bolt = new THREE.Mesh(cardGeometry(BOLT.map(([x, y]) => [x, -y]), 0.1), m);
    this.bolt.visible = false; this.bolt.frustumCulled = false;
    scene.add(this.bolt);
    this.next = 4; this.t = 9; this.flash = 0;
    this.thunder = []; // { at, vol } pending rolls
    this.onThunder = null;
  }

  update(dt, camera, center, storming) {
    this.flash = Math.max(0, this.flash - dt * 5);
    // the thunder arrives a while after the flash
    for (const th of this.thunder) th.at -= dt;
    while (this.thunder.length && this.thunder[0].at <= 0) this.onThunder?.(this.thunder.shift().vol);
    if (this.t < 0.45) {
      this.t += dt;
      // two quick flickers, then gone
      this.bolt.visible = this.t < 0.12 || (this.t > 0.2 && this.t < 0.3);
      if (this.t >= 0.45) this.bolt.visible = false;
    }
    if (!storming) return;
    if ((this.next -= dt) > 0) return;
    this.next = 7 + Math.random() * 14;
    // a strike somewhere off in the distance, hanging from the clouds
    const a = Math.random() * Math.PI * 2, d = 110 + Math.random() * 120;
    this.bolt.position.set(center.x + Math.cos(a) * d, 70 + Math.random() * 10, center.z + Math.sin(a) * d);
    this.bolt.lookAt(camera.position.x, this.bolt.position.y, camera.position.z);
    this.bolt.scale.setScalar(6 + Math.random() * 3);
    this.bolt.scale.x *= Math.random() < 0.5 ? -1 : 1;
    this.t = 0; this.bolt.visible = true;
    this.flash = 1;
    this.thunder.push({ at: 0.6 + d / 120, vol: Math.max(0.35, 1.3 - d / 250) });
  }
}
