// The bunkhouse: the homestead's second purchase, after the root cellar. Before it's built there's a surveyor's
// stake with a paper tag (BUNKHOUSE · $40) in the old camp ground west of the yard. Pay at the stake and a long, low
// log bunkhouse goes up: chinked log walls, a shake roof with a stovepipe, a plank door, two little lamplit windows
// and a bench by the door. Your hired hands sleep there instead of trudging back to Squatters' Row, so they're at
// work sooner and longer: every work turns out a quarter more.
import * as THREE from 'three/webgpu';
import { paperMaterial, cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight } from './world.js';
import { makeMesh } from './building.js';

const box = (w, h, d, color) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), paperMaterial({ color, flatShading: true })); m.castShadow = true; m.receiveShadow = true; return m; };

export const BUNK_COST = 40;

export class Bunkhouse {
  constructor(scene, world, center) {
    const x = center.x - 22, z = center.z + 15;
    this.pos = new THREE.Vector3(x, getHeight(x, z), z);
    this.world = world; this.built = false;
    world.exclusions.push({ x, z, r: 5.5 });
    const face = Math.atan2(center.x - x, center.z - z); // the door toward the farmyard

    // the stake and its paper tag
    this.stake = new THREE.Group(); this.stake.position.copy(this.pos); this.stake.rotation.y = face;
    const post = box(0.07, 1.0, 0.07, 0x8a6038); post.position.y = 0.5; this.stake.add(post);
    const pts = [[-0.32, 0], [0.3, 0.02], [0.32, 0.36], [-0.3, 0.34]];
    const tag = new THREE.Mesh(cardGeometry(pts, 0.02), cardMaterial(paintCard(pts, { W: 192, H: 112, seed: 913, base: '#efe3c4', fills: ['rgba(239,227,196,A)', 'rgba(220,206,170,A)', 'rgba(248,240,220,A)'], edge: 'rgba(90,70,50,1)',
      details(g, px) { g.fillStyle = '#5a6a4a'; g.font = 'bold 30px Georgia, serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; { const [a, b] = px(0, 0.24); g.fillText('BUNKHOUSE', a, b); } g.fillStyle = '#2a201a'; g.font = 'italic 26px Georgia, serif'; { const [a, b] = px(0, 0.1); g.fillText(`build here · $${BUNK_COST}`, a, b); } } })));
    tag.position.set(0, 0.62, 0.05); tag.rotation.z = 0.04; tag.castShadow = true; this.stake.add(tag);
    scene.add(this.stake);

    // the bunkhouse: log walls (stacked rounds with pale chinking), a shake roof, a door, windows, a stovepipe, a bench
    const g = (this.group = new THREE.Group()); g.position.copy(this.pos); g.rotation.y = face; g.visible = false;
    const W = 6.4, D = 3.6, H = 2.2;
    const logMat = paperMaterial({ color: 0x8a6038 }), chink = paperMaterial({ color: 0xd8c8a0 });
    for (let k = 0; k < 7; k++) {
      const y = 0.16 + k * 0.3;
      for (const [w, d, px, pz] of [[W, 0.3, 0, D / 2], [W, 0.3, 0, -D / 2], [0.3, D, W / 2, 0], [0.3, D, -W / 2, 0]]) {
        const log = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, Math.max(w, d) + 0.3, 7).rotateZ(Math.PI / 2), logMat);
        if (d > w) log.rotation.y = Math.PI / 2;
        log.position.set(px, y, pz); log.castShadow = true; log.receiveShadow = true; g.add(log);
      }
      const ch = box(W - 0.2, 0.05, D - 0.2, 0xd8c8a0); ch.material = chink; ch.position.y = y + 0.15; g.add(ch); // chinking between the rounds
    }
    const fill = box(W - 0.1, H, D - 0.1, 0x6a4a30); fill.position.y = H / 2; g.add(fill);
    for (const sz of [-1, 1]) { // the shake roof: two planes meeting at the ridge, overhanging all round
      const r = box(W + 0.8, 0.12, D / 2 + 0.75, 0x7a6a5a); r.position.set(0, H + 0.62, sz * (D / 4 + 0.2)); r.rotation.x = sz * 0.52; g.add(r);
    }
    const door = box(0.9, 1.7, 0.08, 0x5a3a24); door.position.set(-1.2, 0.85, D / 2 + 0.17); g.add(door);
    const latch = box(0.05, 0.05, 0.05, 0x2a2622); latch.position.set(-0.85, 0.9, D / 2 + 0.23); g.add(latch);
    this.panes = [];
    for (const wx of [0.8, 2.2]) {
      const fr = box(0.7, 0.6, 0.06, 0xd8c8a0); fr.position.set(wx, 1.3, D / 2 + 0.17); g.add(fr);
      const pane = new THREE.Mesh(new THREE.BoxGeometry(0.58, 0.48, 0.05), new THREE.MeshBasicNodeMaterial({ color: 0x3e4a50 })); pane.position.set(wx, 1.3, D / 2 + 0.2); g.add(pane); this.panes.push(pane);
    }
    const pipe = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 1.1, 7), paperMaterial({ color: 0x2b2622 })); pipe.position.set(2.2, H + 1.2, -0.6); pipe.castShadow = true; g.add(pipe);
    const bench = box(1.6, 0.08, 0.4, 0x8a6038); bench.position.set(1.4, 0.45, D / 2 + 0.6); g.add(bench);
    for (const bx of [0.75, 2.05]) { const l = box(0.08, 0.45, 0.32, 0x5a3e2a); l.position.set(bx, 0.22, D / 2 + 0.6); g.add(l); }
    scene.add(g);
    this.door = new THREE.Vector3(-1.2, 0, D / 2 + 1.0).applyAxisAngle(new THREE.Vector3(0, 1, 0), face).add(this.pos);
    // the supper fire: a ring of stones out front, with four split logs round it to sit on; lit at dusk while the
    // hands eat, cold the rest of the day
    this.fireAt = new THREE.Vector3(2.6, 0, D / 2 + 6.5).applyAxisAngle(new THREE.Vector3(0, 1, 0), face).add(this.pos);
    this.fire = new THREE.Group(); this.fire.position.set(this.fireAt.x, getHeight(this.fireAt.x, this.fireAt.z), this.fireAt.z);
    const flame = makeMesh('campfire'); this.fire.add(flame); this.flame = flame;
    this.logs = [];
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * Math.PI * 2 + 0.4, log = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.22, 1.1, 8).rotateZ(Math.PI / 2), paperMaterial({ color: 0x7a5232, flatShading: true }));
      log.position.set(Math.cos(a) * 1.75, 0.2, Math.sin(a) * 1.75); log.rotation.y = -a + Math.PI / 2; log.castShadow = true; this.fire.add(log); this.logs.push(a);
    }
    this.fire.visible = false; scene.add(this.fire);
  }
  near(pos, r = 2.6) { return Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z) < r; }
  build() {
    if (this.built) return; this.built = true;
    this.stake.visible = false; this.group.visible = true;
    for (const [dx, dz] of [[-2, 0], [0, 0], [2, 0]]) { const p = new THREE.Vector3(dx, 0, dz).applyAxisAngle(new THREE.Vector3(0, 1, 0), this.group.rotation.y).add(this.pos); this.world.colliders.push({ x: p.x, z: p.z, r: 2.0 }); }
  }
  /** The log by the supper fire where hired hand i sits of an evening. */
  fireSpot(i) { const a = this.logs[i % 4] + Math.floor(i / 4) * 0.35; return new THREE.Vector3(this.fireAt.x + Math.cos(a) * 1.4, 0, this.fireAt.z + Math.sin(a) * 1.4); } // (feet a little in from the log: the sit clip sets the hips back, onto it)
  /** The fire is laid once the bunkhouse stands; the flames are lit only while supper is on. */
  supper(on) { if (!this.built) return; this.fire.visible = true; this.flame.visible = on; }
  /** Where hired hand i beds down: about the bunkhouse door and its bench. */
  homeFor(i) { const a = this.group.rotation.y, off = new THREE.Vector3(-2.0 + (i % 4) * 1.35, 0, 4.4 + Math.floor(i / 4) * 1.3).applyAxisAngle(new THREE.Vector3(0, 1, 0), a); return this.pos.clone().add(off); }
  /** Its windows glow after dark. */
  update(night) { if (!this.built) return; const on = night > 0.45; if (on !== this.lit) { this.lit = on; for (const p of this.panes) p.material.color.setHex(on ? 0xffb860 : 0x3e4a50); } }
  save() { return { built: this.built }; }
  load(d) { if (d?.built) this.build(); }
}
