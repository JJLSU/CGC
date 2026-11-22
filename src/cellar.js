// The root cellar: the first thing your gold buys for the homestead. Before it's dug there's only a surveyor's stake
// by the house with a paper tag (ROOT CELLAR · $20). Pay at the stake and a grassy earth mound rises there, with a
// pair of slanted plank doors on iron hinges and a stovepipe vent: every morning it has a little something put by
// (apples and a loaf), so a prospector back from the hills never goes hungry.
import * as THREE from 'three/webgpu';
import { paperMaterial, cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight } from './world.js';

const box = (w, h, d, color) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), paperMaterial({ color, flatShading: true })); m.castShadow = true; m.receiveShadow = true; return m; };

export const CELLAR_COST = 20;

export class RootCellar {
  constructor(scene, world, center) {
    const x = center.x + 10.5, z = center.z - 7.5;
    this.pos = new THREE.Vector3(x, getHeight(x, z), z);
    this.world = world;
    world.exclusions.push({ x, z, r: 2.6 });
    this.built = false; this.day = -1;
    const face = Math.atan2(center.x + 5 - x, center.z - 4 - z); // the doors open toward the house's side

    // the stake and its tag
    this.stake = new THREE.Group(); this.stake.position.copy(this.pos); this.stake.rotation.y = face;
    const post = box(0.07, 1.0, 0.07, 0x8a6038); post.position.y = 0.5; this.stake.add(post);
    const pts = [[-0.32, 0], [0.3, 0.02], [0.32, 0.36], [-0.3, 0.34]];
    const tag = new THREE.Mesh(cardGeometry(pts, 0.02), cardMaterial(paintCard(pts, { W: 192, H: 112, seed: 907, base: '#efe3c4', fills: ['rgba(239,227,196,A)', 'rgba(220,206,170,A)', 'rgba(248,240,220,A)'], edge: 'rgba(90,70,50,1)',
      details(g, px) { g.fillStyle = '#9a5a48'; g.font = 'bold 30px Georgia, serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; { const [a, b] = px(0, 0.24); g.fillText('ROOT CELLAR', a, b); } g.fillStyle = '#2a201a'; g.font = 'italic 26px Georgia, serif'; { const [a, b] = px(0, 0.1); g.fillText(`dig here · $${CELLAR_COST}`, a, b); } } })));
    tag.position.set(0, 0.62, 0.05); tag.rotation.z = -0.05; tag.castShadow = true; this.stake.add(tag);
    const twine = box(0.4, 0.015, 0.015, 0xb8a888); twine.position.set(0, 0.8, 0.04); twine.rotation.z = 0.2; this.stake.add(twine);
    scene.add(this.stake);

    // the cellar itself: a grassed earth mound, a stone header, two plank doors on a slant, a vent pipe
    this.group = new THREE.Group(); this.group.position.copy(this.pos); this.group.rotation.y = face; this.group.visible = false;
    const mound = new THREE.Mesh(new THREE.SphereGeometry(1.6, 9, 5, 0, Math.PI * 2, 0, Math.PI / 2), paperMaterial({ color: 0x8a9a5a, flatShading: true }));
    mound.scale.set(1.1, 0.55, 1.25); mound.position.z = -0.4; mound.castShadow = true; mound.receiveShadow = true; this.group.add(mound);
    const header = box(1.5, 0.36, 0.3, 0x9a948a); header.position.set(0, 0.62, 0.55); this.group.add(header); // a fieldstone header over the doors
    for (const sx of [-1, 1]) {
      const door = new THREE.Group(); door.position.set(sx * 0.33, 0.06, 1.15); door.rotation.x = -1.05; this.group.add(door);
      const leaf = box(0.62, 1.15, 0.06, 0x8a5a34); leaf.position.y = 0.58; door.add(leaf);
      for (const yy of [0.25, 0.9]) { const strap = box(0.6, 0.06, 0.03, 0x3a3634); strap.position.set(0, yy, 0.04); door.add(strap); } // iron hinge straps
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.06, 0.015, 4, 10), paperMaterial({ color: 0x3a3634 })); ring.position.set(-sx * 0.22, 0.6, 0.06); door.add(ring);
    }
    const vent = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 0.7, 7), paperMaterial({ color: 0x5a5450 })); vent.position.set(0.5, 1.05, -0.8); vent.castShadow = true; this.group.add(vent);
    const cap = box(0.24, 0.04, 0.24, 0x5a5450); cap.position.set(0.5, 1.42, -0.8); this.group.add(cap);
    // a basket of apples set out on the doors when there's something put by today
    this.basket = new THREE.Group(); this.basket.position.set(0.95, 0, 0.9); this.group.add(this.basket);
    const bk = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.17, 0.2, 9, 1, true), paperMaterial({ color: 0xb8874f, side: THREE.DoubleSide })); bk.position.y = 0.1; this.basket.add(bk);
    for (let i = 0; i < 5; i++) { const a = new THREE.Mesh(new THREE.IcosahedronGeometry(0.07, 0), paperMaterial({ color: i === 2 ? 0xd8b060 : 0xc4362f, flatShading: true })); a.position.set(Math.cos(i * 1.3) * 0.09, 0.2 + (i % 2) * 0.04, Math.sin(i * 1.3) * 0.09); this.basket.add(a); }
    scene.add(this.group);
  }
  near(pos, r = 2.4) { return Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z) < r; }
  stocked(day) { return this.built && this.day !== day; }
  build() {
    if (this.built) return; this.built = true;
    this.stake.visible = false; this.group.visible = true;
    this.world.colliders.push({ x: this.pos.x, z: this.pos.z, r: 1.3 });
  }
  /** Something put by today? The basket shows when there is. */
  update(day) { if (this.built) this.basket.visible = this.day !== day; }
  save() { return { built: this.built, day: this.day }; }
  load(d) { if (d?.built) this.build(); this.day = d?.day ?? -1; }
}
