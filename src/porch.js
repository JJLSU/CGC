// The rocking chair on the farmhouse porch: sit (E) and let the day drift by. The chair rocks, the farmer
// rests, and time runs about twenty-four times faster until you get up (E again, or any step away).
// A cozy way to wait for nightfall, the morning, or the tinker's wagon.
import * as THREE from 'three/webgpu';
import { getHeight } from './world.js';
import { paperMaterial } from './materials.js';

export const WARP = 24; // how much faster time runs while you rock

export class Porch {
  constructor(scene, house) {
    // the house roof record: { x, z, rot } with the porch along local +z
    const c = Math.cos(house.rot), s = Math.sin(house.rot);
    const lx = 1.9, lz = 4.9; // out on the grass before the porch steps, to the right of the path (the model's porch rail ran through it)
    const x = house.x + c * lx + s * lz, z = house.z - s * lx + c * lz;
    this.seat = new THREE.Vector3(x, getHeight(house.x, house.z) + 0.28, z);
    this.facing = house.rot; // looking out over the yard
    const wood = paperMaterial({ color: 0x8a5a34 }), dark = paperMaterial({ color: 0x5a3e2a }), quilt = paperMaterial({ color: 0xb5473a });
    const g = (this.group = new THREE.Group());
    const add = (geo, mat) => { const m = new THREE.Mesh(geo, mat); m.castShadow = m.receiveShadow = true; g.add(m); };
    const box = (w, h, d, px, py, pz, rx = 0) => new THREE.BoxGeometry(w, h, d).rotateX(rx).translate(px, py, pz);
    add(box(0.62, 0.06, 0.56, 0, 0.46, 0), wood);                        // seat
    add(box(0.62, 0.8, 0.05, 0, 0.88, -0.3, -0.18), wood);              // back, leaning
    add(box(0.5, 0.36, 0.04, 0, 0.74, -0.25, -0.18), quilt);            // a folded quilt over the back
    for (const sx of [-0.28, 0.28]) {
      add(box(0.05, 0.42, 0.05, sx, 0.25, 0.22), dark);                 // legs
      add(box(0.05, 0.42, 0.05, sx, 0.25, -0.22), dark);
      add(box(0.05, 0.05, 0.86, sx, 0.03, 0), dark);                    // rockers
      add(box(0.06, 0.05, 0.5, sx, 0.66, 0.02), wood);                  // arms
    }
    g.position.set(x, this.seat.y - 0.28, z);
    g.rotation.order = 'YXZ'; g.rotation.y = this.facing; // (turned first, then rocked about its own runners)
    scene.add(g);
    this.sitting = false;
    this.t = 0;
  }

  near(pos) { return Math.hypot(pos.x - this.seat.x, pos.z - this.seat.z) < 1.6; }

  /** While sitting: the chair rocks gently and the farmer sits in it, legs bent. */
  update(dt, player) {
    this.t += dt;
    const rock = this.sitting ? Math.sin(this.t * 1.6) * 0.09 : this.group.rotation.x * 0.9;
    this.group.rotation.x = rock;
    if (!this.sitting) { this.wasSitting = false; return; }
    player.pos.copy(this.seat); player.anchor?.copy(player.pos); player.vel.set(0, 0, 0);
    player.facing = this.facing;
    const a = player.avatar;
    a.root.position.copy(this.seat); a.root.position.y -= 0.32;
    a.root.rotation.order = 'YXZ'; a.root.rotation.set(rock * 0.8, this.facing, 0); // (rocking about the chair's own axis, not the world's)
    if (!this.wasSitting && a.fig.actions?.sit) { const act = a.fig.actions.sit; a.fig.mixer.stopAllAction(); act.reset().setEffectiveWeight(1).play(); a.fig.current = act; a.fig.mixer.update(0); } // (straight into the seat: no slide while the clip blends in)
    this.wasSitting = true;
    const hips = a.fig.model?.getObjectByName('Hips');
    if (hips) { // the model: it plays its own sit clip; seat its hips on the cushion, a little back in the chair
      a.root.updateWorldMatrix(true, true); hips.getWorldPosition(_h);
      _t.set(-Math.sin(this.facing) * 0.08, 0.6, -Math.cos(this.facing) * 0.08).add(this.group.position);
      a.root.position.add(_t.sub(_h));
      return;
    }
    for (const l of a.legs) l.rotation.x = -1.45;
    a.body.rotation.x = -0.12;
  }
}

const _h = new THREE.Vector3(), _t = new THREE.Vector3();
