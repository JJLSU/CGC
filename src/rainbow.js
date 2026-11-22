// After a daytime shower, a rainbow pops up out of the page like the arch of a pop-up book: six bands of
// muted, hand-painted paper (barn red to violet) cut as half-rings, standing far off across the land with the
// sun at your back. It hinges up with a springy overshoot, stands a minute or so, then folds back down.
import * as THREE from 'three/webgpu';
import { springRise, getHeight } from './world.js';
import { paperMaterial } from './materials.js';

const BANDS = [0xc4574a, 0xd98a4a, 0xd9b45a, 0x8fa868, 0x5e9a9a, 0x8a74a8];

export class Rainbow {
  constructor(scene) {
    const g = (this.group = new THREE.Group());
    this.hinge = new THREE.Group(); g.add(this.hinge);
    const R = 19, W = 1.3;
    BANDS.forEach((c, i) => {
      const r0 = R - (i + 1) * W, r1 = R - i * W;
      // a paper strip with a little thickness, so it reads as card and catches the light along its cut edge
      const shape = new THREE.Shape();
      shape.absarc(0, 0, r1, 0, Math.PI, false);
      shape.absarc(0, 0, r0, Math.PI, 0, true);
      const geo = new THREE.ExtrudeGeometry(shape, { depth: 0.12, bevelEnabled: false, curveSegments: 48 }).translate(0, 0, -i * 0.05);
      const m = new THREE.Mesh(geo, paperMaterial({ color: c }));
      m.castShadow = false; m.receiveShadow = true;
      this.hinge.add(m);
    });
    g.visible = false;
    scene.add(g);
    this.t = 0; this.state = 'down'; this.stand = 0;
  }

  /** Pop up somewhere ahead of the farmer, on the side away from the sun. */
  show(player, sunDir) {
    if (this.state !== 'down') return;
    const away = new THREE.Vector3(-sunDir.x, 0, -sunDir.z);
    if (away.lengthSq() < 1e-4) away.set(0, 0, -1);
    away.normalize();
    const x = player.pos.x + away.x * 42, z = player.pos.z + away.z * 42;
    this.group.position.set(x, getHeight(x, z) - 0.5, z);
    this.group.rotation.y = Math.atan2(away.x, away.z); // its face toward the farmer
    this.group.visible = true;
    this.state = 'up'; this.t = 0; this.stand = 70 + Math.random() * 30;
  }

  update(dt) {
    if (this.state === 'down') return;
    this.t += dt;
    if (this.state === 'up') {
      this.hinge.rotation.x = -(1 - springRise(this.t * 0.45)) * (Math.PI / 2); // rise from lying flat, slowly: it's big
      if (this.t > this.stand) { this.state = 'folding'; this.t = 0; }
    } else if (this.state === 'folding') {
      const k = Math.min(1, this.t / 2.5);
      this.hinge.rotation.x = -(k * k) * (Math.PI / 2);
      if (k >= 1) { this.state = 'down'; this.group.visible = false; }
    }
  }
}
