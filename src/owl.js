// A barn owl that keeps watch over the farm at night: after dusk it glides in to the corner post of the pen,
// turns its pale face to follow the farmer, now and then lets out a soft hoot, and flies off at dawn.
// One small printed-card puppet (body, face disc, two wings); hidden all day.
import * as THREE from 'three/webgpu';
import { propModel } from './modelfolk.js';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard, asLayer } from './textures.js';

function art(pts, base, draw, seed) {
  return cardMaterial(paintCard(pts, { W: 192, H: 192, seed, base, fills: ['rgba(200,160,110,A)', 'rgba(180,140,96,A)'], edge: 'rgba(80,56,36,1)', details: draw }));
}

export class Owl {
  constructor(scene, perch) {
    this.perch = perch.clone();
    this.state = 'away'; // away · arriving · perched · leaving
    this.t = 0; this.hootT = 6;
    this.onHoot = null;
    const g = (this.group = new THREE.Group());
    const body = [[0.16, 0], [0.2, 0.18], [0.17, 0.36], [0.1, 0.44], [-0.1, 0.44], [-0.17, 0.36], [-0.2, 0.18], [-0.16, 0], [0, -0.06]];
    const bodyMat = art(body, '#a8784a', (c, px, rng) => {
      for (let i = 0; i < 26; i++) { const [x, y] = px((rng() - 0.5) * 0.3, 0.05 + rng() * 0.32); c.fillStyle = 'rgba(90,60,40,0.55)'; c.beginPath(); c.arc(x, y, 2.5, 0, Math.PI * 2); c.fill(); }
      const [bx, by] = px(0, 0.12); c.fillStyle = 'rgba(246,238,220,0.85)'; c.beginPath(); c.ellipse(bx, by, 22, 30, 0, 0, Math.PI * 2); c.fill(); // pale breast
    }, 161);
    // a round head with two ear tufts (a great horned owl, the old storybook kind), its pale face printed on
    const face = [];
    for (let i = 0; i <= 24; i++) { const a = Math.PI + (i / 24) * Math.PI; face.push([Math.cos(a) * 0.17, Math.sin(a) * 0.14]); } // chin, left → right
    face.push([0.17, 0.04], [0.2, 0.2], [0.09, 0.11], [-0.09, 0.11], [-0.2, 0.2], [-0.17, 0.04]); // tufts
    const faceMat = art(face, '#a8784a', (c, px) => {
      const disc = (sx) => { const [x, y] = px(sx, 0.0); c.fillStyle = '#f4ead6'; c.beginPath(); c.ellipse(x, y, 30, 32, 0, 0, Math.PI * 2); c.fill(); };
      asLayer(c, () => { disc(-0.075); disc(0.075); }, 0.4);
      for (const sx of [-0.075, 0.075]) {
        const [ex, ey] = px(sx, 0.005);
        c.fillStyle = '#e8b040'; c.beginPath(); c.arc(ex, ey, 14, 0, Math.PI * 2); c.fill(); // amber eyes
        c.fillStyle = '#2b2018'; c.beginPath(); c.arc(ex, ey, 8, 0, Math.PI * 2); c.fill();
        c.fillStyle = '#fff6e0'; c.beginPath(); c.arc(ex - 3, ey - 3, 3, 0, Math.PI * 2); c.fill();
      }
      const [bx, by] = px(0, -0.05); c.fillStyle = '#4a3426'; c.beginPath(); c.moveTo(bx - 6, by + 4); c.lineTo(bx + 6, by + 4); c.lineTo(bx, by - 12); c.fill();
    }, 163);
    const wing = [[0, 0], [0.34, 0.06], [0.42, -0.04], [0.3, -0.12], [0.04, -0.1]];
    const wingMat = art(wing, '#b88a5a', (c, px) => { c.strokeStyle = 'rgba(90,60,40,0.6)'; c.lineWidth = 3; for (let k = 1; k < 4; k++) { const [a, b] = px(k * 0.1, 0.04), [x2, y2] = px(k * 0.1 - 0.03, -0.09); c.beginPath(); c.moveTo(a, b); c.lineTo(x2, y2); c.stroke(); } }, 165);
    this.body = new THREE.Mesh(cardGeometry(body, 0.04), bodyMat);
    this.head = new THREE.Group(); this.head.position.set(0, 0.52, 0.03);
    this.face = new THREE.Mesh(cardGeometry(face, 0.03), faceMat);
    this.head.add(this.face);
    this.wl = new THREE.Mesh(cardGeometry(wing, 0.02), wingMat); this.wl.position.set(0.12, 0.32, -0.03);
    this.wr = new THREE.Mesh(cardGeometry(wing.map(([x, y]) => [-x, y]), 0.02), wingMat); this.wr.position.set(-0.12, 0.32, -0.03);
    for (const m of [this.body, this.face, this.wl, this.wr]) { m.castShadow = true; }
    g.add(this.body, this.head, this.wl, this.wr);
    // perched, she's the barn owl from the reference art (a still model: the card owl flies in and out, wings beating)
    const src = propModel('animal_owl');
    if (src) {
      const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = 0.5 / sz.y; /* (about 0.75 m on her post, the group being 1.5x) */
      this.model = new THREE.Group(); m.position.set(-c.x, -bb.min.y, -c.z); this.model.add(m); this.model.scale.setScalar(k); this.model.visible = false; g.add(this.model);
    }
    g.scale.setScalar(1.5);
    g.visible = false;
    scene.add(g);
    this.from = new THREE.Vector3();
  }

  update(dt, { night, player, camera }) {
    this.t += dt;
    const g = this.group;
    const want = night > 0.6;
    if (this.state === 'away' && want) {
      this.state = 'arriving'; this.t = 0;
      this.from.set(this.perch.x + 30, this.perch.y + 14, this.perch.z - 25);
      g.visible = true;
    } else if (this.state === 'perched' && !want) {
      this.state = 'leaving'; this.t = 0;
    }
    // wings beat in flight; perched, they fold down flat along the body's sides
    const flap = (on) => { const a = on ? Math.sin(this.t * 16) * 0.9 : -1.25; this.wl.rotation.z = a; this.wr.rotation.z = -a; this.wl.position.z = this.wr.position.z = on ? -0.03 : 0.035; };
    if (this.state === 'arriving' || this.state === 'leaving') {
      const k = Math.min(1, this.t / 3.5), e = this.state === 'arriving' ? 1 - (1 - k) ** 2 : k * k;
      if (this.state === 'arriving') g.position.lerpVectors(this.from, this.perch, e); else g.position.lerpVectors(this.perch, this.from, e);
      g.position.y += Math.sin(k * Math.PI) * 2;
      flap(true);
      if (k >= 1) { if (this.state === 'arriving') { this.state = 'perched'; this.t = 0; } else { this.state = 'away'; g.visible = false; } }
    } else if (this.state === 'perched') {
      g.position.copy(this.perch);
      flap(false);
      // hoot now and then, with a little bob
      if ((this.hootT -= dt) <= 0) { this.hootT = 9 + Math.random() * 14; this.onHoot?.(); this.t = 0; }
      g.position.y += this.t < 0.6 ? Math.sin(this.t * 10) * 0.02 : 0;
    }
    if (this.model) { const sit = this.state === 'perched'; this.model.visible = sit; for (const p of [this.body, this.head, this.wl, this.wr]) p.visible = !sit; }
    if (!g.visible) return;
    // the body faces the camera like the other puppets; the face swivels toward the farmer
    g.rotation.y = Math.atan2(camera.position.x - g.position.x, camera.position.z - g.position.z);
    const toFarmer = Math.atan2(player.pos.x - g.position.x, player.pos.z - g.position.z) - g.rotation.y;
    this.head.rotation.y = THREE.MathUtils.clamp(Math.atan2(Math.sin(toFarmer), Math.cos(toFarmer)), -0.45, 0.45); // a card can only turn so far
    this.head.rotation.z = Math.sin(this.t * 0.7) * 0.12; // the slow owl head-tilt
  }
}
