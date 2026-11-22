// The hens' nesting box beside the barn: every morning the hens lay a few eggs in the straw (you can see
// them sitting there); press E by the box to gather them. Eggs go into flapjacks at the campfire.
import * as THREE from 'three/webgpu';
import { getHeight } from './world.js';
import { paperMaterial } from './materials.js';
import { bakeByMaterial } from './bake.js';
import { propModel } from './modelfolk.js';

const SLOTS = [[-0.36, 0.1], [-0.12, 0.16], [0.12, 0.08], [0.36, 0.15]];

export class Coop {
  constructor(scene, world, center) {
    const x = center.x - 3.2, z = center.z - 1.5;
    this.pos = new THREE.Vector3(x, getHeight(x, z), z);
    world.colliders.push({ x, z, r: 0.8 });
    world.exclusions.push({ x, z, r: 2.6 }, { x, z, r: 4.6 }); // keep trees off the box (and the hen house behind it)
    this.eggs = 3;
    this.laidDay = 1;

    const g = (this.group = new THREE.Group());
    g.position.copy(this.pos);
    g.rotation.y = Math.atan2(center.x + 2 - x, center.z + 6.5 - z); // open side toward the yard
    const red = paperMaterial({ color: 0xa8352a }), dark = paperMaterial({ color: 0x5a3e2a }), cream = paperMaterial({ color: 0xefe3c4 });
    const straw = paperMaterial({ color: 0xd9b45a });
    const add = (geo, mat) => { const m = new THREE.Mesh(geo, mat); m.castShadow = m.receiveShadow = true; g.add(m); return m; };
    // legs, a red box with an open front, a cream trim, a shingled lean-to roof, straw spilling over the ledge
    for (const [lx, lz] of [[-0.6, -0.35], [0.6, -0.35], [-0.6, 0.35], [0.6, 0.35]]) add(new THREE.BoxGeometry(0.1, 0.5, 0.1).translate(lx, 0.25, lz), dark);
    add(new THREE.BoxGeometry(1.4, 0.08, 0.9).translate(0, 0.5, 0), dark);
    add(new THREE.BoxGeometry(1.4, 0.8, 0.08).translate(0, 0.9, -0.41), red);
    add(new THREE.BoxGeometry(0.08, 0.8, 0.9).translate(-0.66, 0.9, 0), red);
    add(new THREE.BoxGeometry(0.08, 0.8, 0.9).translate(0.66, 0.9, 0), red);
    add(new THREE.BoxGeometry(0.08, 0.8, 0.9).translate(0, 0.9, 0), red); // divider: two nests
    add(new THREE.BoxGeometry(1.5, 0.08, 0.1).translate(0, 0.62, 0.45), cream);
    add(new THREE.BoxGeometry(1.6, 0.07, 0.6).rotateX(0.38).translate(0, 1.42, -0.24), dark); // covers the back only, so the eggs show
    add(new THREE.BoxGeometry(1.3, 0.12, 0.8).translate(0, 0.6, 0.02), straw);
    const egg = new THREE.SphereGeometry(0.075, 9, 7).scale(1, 1.3, 1);
    const eggMats = [paperMaterial({ color: 0xf3ead6 }), paperMaterial({ color: 0xd9b48a })];
    this.eggMeshes = SLOTS.map(([ex, ez], i) => { const m = add(egg, eggMats[i % 2]); m.position.set(ex, 0.72, ez); return m; });
    for (const m of this.eggMeshes) m.castShadow = false;
    bakeByMaterial(g, new Set(this.eggMeshes)); // 16 meshes → 4 static + 4 eggs
    this.refresh();
    // the hens' own house from the reference art, just beside the nesting box: a red hen house on legs with a ramp
    // and a wire run, its front to the yard (the open box stays where you gather the eggs)
    const src = propModel('bldg_coop');
    if (src) {
      const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = 3.6 / sz.x;
      const hold = new THREE.Group(); m.position.set(-c.x, -bb.min.y, -c.z); hold.add(m); hold.scale.setScalar(k); hold.position.set(3.3, 0, -0.5); /* (beside the box, clear of the hay bales and the barn) */ g.add(hold);
      g.updateMatrixWorld(true); const w = new THREE.Vector3();
      for (const lx of [1.9, 3.3, 4.7]) { w.set(lx, 0, -0.5).applyMatrix4(g.matrixWorld); world.colliders.push({ x: w.x, z: w.z, r: 0.8 }); }
      this.roostAt = new THREE.Vector3(3.3, 0, 1.3).applyMatrix4(g.matrixWorld); // (the foot of its ramp, where the hens go in of an evening)
    }
    scene.add(g);
  }

  refresh() { this.eggMeshes.forEach((m, i) => { m.visible = i < this.eggs; }); }

  near(pos, r = 2.4) { return Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z) < r && Math.abs(pos.y - this.pos.y) < 1.5; }

  /** Each morning (from 06:00) the hens lay two to four eggs, up to a full box of four. */
  update(sky, inv = null) {
    if (sky.day !== this.laidDay && sky.time >= 0.25 && sky.time < 0.8) {
      this.laidDay = sky.day;
      // laying mash from the feed & grain: a scoop a morning, and the hens lay two more (tucked in the straw)
      if (inv?.mash > 0) { inv.mash--; this.extra = (this.extra || 0) + 2; }
      this.eggs = Math.min(SLOTS.length, this.eggs + 2 + Math.floor(Math.random() * 3));
      this.refresh();
    }
  }

  collect() {
    const n = this.eggs + (this.extra || 0);
    this.eggs = 0; this.extra = 0;
    this.refresh();
    return n;
  }
}
