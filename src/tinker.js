// The travelling tinker: every other day, from breakfast to late afternoon, a painted wagon stands at the
// end of the farm lane with the tinker beside it, a paper doll in a long coat and stovepipe. Press E by it to trade surplus for sundries
// (the trades live in the crafting panel under "Tinker's wagon"). The wagon hinges up off the page
// when it arrives and folds flat when it leaves.
import * as THREE from 'three/webgpu';
import { Folk } from './folk.js';
import { getHeight, springRise } from './world.js';
import { paperMaterial, cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { panelArt, paintCard, asLayer } from './textures.js';
import { bakeByMaterial } from './bake.js';
import { propModel, ModelFigure, hasFolk } from './modelfolk.js';

export class Tinker {
  constructor(scene, world, center, spot = null) {
    // in Paydirt Hollow he draws up at the head of Main Street (spot), facing across it; otherwise at the end of the lane
    const x = spot ? spot.x : center.x + 9, z = spot ? spot.z : center.z + 15; const look = spot ? spot.look : center;
    this.pos = new THREE.Vector3(x, getHeight(x, z), z);
    world.exclusions.push({ x, z, r: 4.8 });
    world.colliders.push({ x, z, r: 1.7 });
    this.onArrive = null; this.onLeave = null;
    this.here = false;
    this.t = 0;

    const g = (this.group = new THREE.Group());
    g.position.copy(this.pos);
    g.rotation.y = Math.atan2(look.x - x, look.z - z); // broadside (and the tinker) toward the farmyard
    const hinge = (this.hinge = new THREE.Group());
    g.add(hinge);

    const side = panelArt(512, 160, '#a8352a', ['rgba(168,53,42,A)', 'rgba(140,40,32,A)', 'rgba(190,74,56,A)'], (c, W, H) => {
      c.strokeStyle = '#d9a441'; c.lineWidth = 6; c.strokeRect(14, 14, W - 28, H - 28);
      c.fillStyle = '#efe3c4'; c.textAlign = 'center'; c.textBaseline = 'middle';
      c.font = "bold 46px Rockwell, 'Courier New', Georgia, serif"; c.fillText('TINKER & SUNDRIES', W / 2, H / 2 - 14);
      c.font = "italic 26px Georgia, serif"; c.fillStyle = '#e8c04a'; c.fillText('pots · rope · iron · honey · fine notions', W / 2, H / 2 + 30);
    }, 111);
    const red = cardMaterial(side), cream = paperMaterial({ color: 0xefe3c4 }), wood = paperMaterial({ color: 0x6b4a30 }), tin = paperMaterial({ color: 0xa9adae });
    const mesh = (geo, mat) => { const m = new THREE.Mesh(geo, mat); m.castShadow = m.receiveShadow = true; hinge.add(m); return m; };
    const src = propModel('veh_covered_wagon');
    if (src) {
      // the covered wagon from the reference art (the wagon sheet): patched canvas, a water barrel and trunks lashed
      // to its sides, his painted TINKER & SUNDRIES board hung along the near side, tongue out the way the shafts went
      const m = src.scene.clone(), b = new THREE.Box3().setFromObject(m), sz = b.getSize(new THREE.Vector3()), c = b.getCenter(new THREE.Vector3());
      const k = 5.2 / sz.x, hold = new THREE.Group();
      m.position.set(-c.x, -b.min.y, -c.z); hold.add(m); hold.scale.setScalar(k); hold.rotation.y = Math.PI; hinge.add(hold);
      const board = new THREE.Mesh(new THREE.BoxGeometry(2.3, 0.62, 0.05), [wood, wood, wood, wood, red, wood]);
      board.position.set(0, 1.3, sz.z * k * 0.36); board.castShadow = true; hinge.add(board);
    } else {
    mesh(new THREE.BoxGeometry(3.2, 1.0, 1.7).translate(0, 1.15, 0), red);
    mesh(new THREE.CylinderGeometry(0.88, 0.88, 3.0, 14, 1, true, -Math.PI / 2, Math.PI).rotateZ(Math.PI / 2).translate(0, 1.65, 0), cream);
    for (const sx of [-1.1, 1.1]) for (const sz of [-0.92, 0.92]) {
      mesh(new THREE.CylinderGeometry(0.55, 0.55, 0.09, 16).rotateX(Math.PI / 2).translate(sx, 0.55, sz), wood);
      mesh(new THREE.CylinderGeometry(0.13, 0.13, 0.14, 8).rotateX(Math.PI / 2).translate(sx, 0.55, sz * 1.04), tin);
    }
    mesh(new THREE.BoxGeometry(1.6, 0.08, 0.08).translate(2.35, 0.75, 0.45), wood);
    mesh(new THREE.BoxGeometry(1.6, 0.08, 0.08).translate(2.35, 0.75, -0.45), wood);
    for (const [px, pz] of [[-0.9, 0.95], [-0.3, 0.97], [0.5, 0.95]]) mesh(new THREE.CylinderGeometry(0.16, 0.12, 0.22, 10).translate(px, 1.05, pz), tin); // hanging pots
    }

    // the tinker himself: a die-cut card, stovepipe hat and long coat, standing by the wagon
    if (!src) bakeByMaterial(hinge); // ~22 meshes → 5
    // the tinker himself, a paper doll like the farmer: long brown coat, ticking-striped trousers, a grey beard,
    // a tall stovepipe with a red band (added after the bake so he can move)
    this.man = hasFolk('folk_tinker') ? new ModelFigure('folk_tinker') : new Folk({ coat: 0x6e4a30, pants: 0x5a5048, longcoat: true, vest: 0x8a3a2a, beard: 0xb8b0a4, hat: 'stovepipe', band: 0xa63c2e });
    this.man.root.position.set(-0.6, 0, 1.75); this.man.root.rotation.y = 0.3;
    hinge.add(this.man.root);
    this.group.visible = false;
    scene.add(this.group);
  }

  /** Is he visiting at this time of day? Every second day, 07:00–18:00. */
  visiting(sky) { return sky.day % 2 === 0 && sky.time > 0.29 && sky.time < 0.75; }

  near(pos, r = 5) { return this.here && Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z) < r; }

  update(dt, sky) {
    const want = this.visiting(sky);
    if (want !== this.here) {
      this.here = want; this.t = 0;
      if (want) { this.group.visible = true; this.onArrive?.(); } else this.onLeave?.();
    }
    this.t += dt;
    if (!this.group.visible) return;
    this.man.update(dt, 0);
    // hinge up with a springy overshoot on arrival, fold back flat when he moves on
    const k = this.here ? springRise(this.t) : 1 - Math.min(1, (this.t / 0.6) ** 2);
    this.hinge.rotation.x = -(1 - k) * (Math.PI / 2);
    if (!this.here && this.t > 0.6) this.group.visible = false;
  }
}

function tinkerSilhouette() {
  // boots, a long coat flaring at the hem, shoulders, head with a beard, a tall stovepipe hat
  return [[0.2, 0], [0.22, 0.12], [0.3, 0.16], [0.34, 0.75], [0.27, 1.12], [0.12, 1.2], [0.13, 1.3], [0.1, 1.42], [0.18, 1.44],
    [0.17, 1.47], [0.12, 1.48], [0.12, 1.78], [-0.12, 1.78], [-0.12, 1.48], [-0.17, 1.47], [-0.18, 1.44], [-0.1, 1.42],
    [-0.13, 1.3], [-0.12, 1.2], [-0.27, 1.12], [-0.34, 0.75], [-0.3, 0.16], [-0.22, 0.12], [-0.2, 0]];
}

function tinkerArt(pts) {
  return paintCard(pts, {
    W: 256, H: 640, seed: 113, base: '#7a5236',
    fills: ['rgba(122,82,54,A)', 'rgba(100,66,44,A)', 'rgba(140,98,64,A)'],
    edge: 'rgba(50,32,20,1)',
    details(g, px) {
      const rect = (x0, y0, x1, y1, col, depth = 1) => { const [a, b] = px(x0, y1), [c, d] = px(x1, y0); asLayer(g, () => { g.fillStyle = col; g.fillRect(a, b, c - a, d - b); }, depth); };
      rect(-0.22, 0, 0.22, 0.13, '#2f2a26');           // boots
      rect(-0.13, 0.72, 0.13, 1.1, '#d9a441', 0.7);    // mustard waistcoat
      rect(-0.04, 0.72, 0.04, 1.1, '#efe3c4', 0.4);    // shirt front
      rect(-0.1, 1.18, 0.1, 1.42, '#e9c49f', 0.6);     // face
      // a grey beard, eyes, the hat and its red band
      const [bx, by] = px(0, 1.24); asLayer(g, () => { g.fillStyle = '#b8b2a6'; g.beginPath(); g.ellipse(bx, by, 26, 30, 0, 0, Math.PI * 2); g.fill(); }, 0.6);
      g.fillStyle = '#2b2018'; for (const ex of [-0.045, 0.045]) { const [x, y] = px(ex, 1.35); g.beginPath(); g.arc(x, y, 3.5, 0, Math.PI * 2); g.fill(); }
      rect(-0.18, 1.43, 0.18, 1.48, '#2f2a26'); rect(-0.12, 1.48, 0.12, 1.78, '#2f2a26'); rect(-0.12, 1.5, 0.12, 1.56, '#a8352a', 0.5);
      // brass buttons and a satchel strap
      g.fillStyle = '#e8c04a'; for (const by2 of [0.5, 0.62]) { const [x, y] = px(0.18, by2); g.beginPath(); g.arc(x, y, 4, 0, Math.PI * 2); g.fill(); }
      const [s0x, s0y] = px(-0.26, 1.08), [s1x, s1y] = px(0.3, 0.5); g.strokeStyle = '#4a3426'; g.lineWidth = 7; g.beginPath(); g.moveTo(s0x, s0y); g.lineTo(s1x, s1y); g.stroke();
    },
  });
}
