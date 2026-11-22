// Crows in the corn: every few minutes by day a little murder of paper crows flaps down into the kitchen
// garden and pecks at the crops. Walk at them and they scatter cawing; leave them and they each carry off a
// corn ear or pumpkin (it grows back, like everything). A scarecrow standing near the garden keeps them away.
import * as THREE from 'three/webgpu';
import { propModel } from './modelfolk.js';
import { getHeight } from './world.js';
import { paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';

const N = 4;

function crowParts() {
  const body = cardGeometry([[0.32, 0.16], [0.2, 0.22], [0.1, 0.3], [0.02, 0.26], [-0.16, 0.2], [-0.34, 0.24], [-0.36, 0.18], [-0.16, 0.08], [0.12, 0.08], [0.22, 0.12]], 0.025);
  const beak = cardGeometry([[0.44, 0.2], [0.31, 0.23], [0.31, 0.17]], 0.02);
  const wing = cardGeometry([[0.12, 0], [-0.14, 0.03], [-0.34, 0.28], [-0.1, 0.22]], 0.015);
  // seen from above (the usual camera), a crow is its back: a flat card of body, folded wings and fanned tail
  const back = cardGeometry([[0.4, 0], [0.3, 0.06], [0.14, 0.11], [-0.12, 0.1], [-0.3, 0.07], [-0.46, 0.12], [-0.5, 0], [-0.46, -0.12], [-0.3, -0.07], [-0.12, -0.1], [0.14, -0.11], [0.3, -0.06]], 0.02)
    .rotateX(-Math.PI / 2).translate(0, 0.26, 0);
  // spread wings for flight, also flat: they flap about the body's long axis
  const spread = cardGeometry([[0.12, 0], [-0.16, 0], [-0.3, 0.5], [-0.05, 0.42]], 0.015).rotateX(-Math.PI / 2);
  return { body, beak, wing, back, spread };
}

export class Crows {
  constructor(scene) {
    this.scene = scene;
    this.state = 'away'; // away · coming · pecking · leaving
    this.timer = 90 + Math.random() * 60;
    this.onLand = null; this.onScatter = null; this.onSteal = null; this.onCaw = null;
    const parts = crowParts();
    const ink = paperMaterial({ color: 0x2a2a36 }), wingMat = paperMaterial({ color: 0x3a3a4a, side: THREE.DoubleSide }), beakMat = paperMaterial({ color: 0x5a5048 });
    this.birds = [];
    for (let i = 0; i < N; i++) {
      const g = new THREE.Group();
      const body = new THREE.Mesh(parts.body, ink), beak = new THREE.Mesh(parts.beak, beakMat);
      body.castShadow = true;
      const back = new THREE.Mesh(parts.back, ink); back.castShadow = true;
      // wings: flat cards hinged at the shoulders, folded along the back when landed, spread and flapping in flight
      const wl = new THREE.Mesh(parts.spread, wingMat), wr = new THREE.Mesh(parts.spread, wingMat);
      wl.position.set(0.02, 0.27, 0.06); wr.position.set(0.02, 0.27, -0.06); wl.scale.z = -1; // the left wing mirrored to reach +z
      wl.castShadow = wr.castShadow = true;
      g.add(body, beak, back, wl, wr);
      // landed, each is the crow from the reference art (a still model; the cards fly in and out, wings beating)
      let model = null; const src = propModel('animal_crow');
      if (src) {
        const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3());
        model = new THREE.Group(); m.position.set(-c.x, -bb.min.y, -c.z); model.add(m); model.scale.setScalar(0.27 / sz.z); model.rotation.y = Math.PI / 2; model.visible = false; g.add(model); // (beak, glTF +Z, along the crow's +x)
      }
      g.scale.setScalar(2.1);
      g.visible = false;
      scene.add(g);
      this.birds.push({ model, cards: [body, beak, back, wl, wr], g, wl, wr, from: new THREE.Vector3(), to: new THREE.Vector3(), t: 0, target: null, phase: Math.random() * 6 });
    }
  }

  /** Crops in the garden that are standing right now. */
  crops(world) {
    const out = [];
    for (const type of ['corn', 'pumpkin']) {
      const pool = world.pools[type];
      if (!pool) continue;
      for (let i = 0; i < pool.mesh.count; i++) { const r = pool.owners[i]; if (r?.alive) out.push(r); }
    }
    return out;
  }

  update(dt, { world, player, camera, sky, guarded, kite = null }) {
    this.timer -= dt;
    const day = sky.night < 0.4;
    if (this.state === 'away') {
      if (this.timer > 0 || !day) return;
      const crops = this.crops(world);
      this.timer = 120 + Math.random() * 120;
      if (crops.length < 3 || guarded(crops[0]) || (kite && Math.hypot(kite.x - crops[0].x, kite.z - crops[0].z) < 30)) return; // a scarecrow minds the garden: they don't even try
      this.state = 'coming';
      const ang = Math.random() * Math.PI * 2;
      this.birds.forEach((b, i) => {
        b.target = crops[Math.floor(Math.random() * crops.length)];
        const side = Math.random() < 0.5 ? -0.65 : 0.65; // on the soil between the rows, where they can be seen
        const lx = b.target.x + (Math.random() - 0.5) * 0.5, lz = b.target.z + side;
        b.to.set(lx, getHeight(lx, lz), lz);
        b.from.set(b.to.x + Math.cos(ang + i * 0.3) * 45, b.to.y + 18, b.to.z + Math.sin(ang + i * 0.3) * 45);
        b.t = -i * 0.4;
        b.g.visible = true;
      });
      this.onCaw?.();
      return;
    }
    const near = this.birds[0].to;
    const playerD = Math.hypot(player.pos.x - near.x, player.pos.z - near.z);
    const kiteD = kite ? Math.hypot(kite.x - near.x, kite.z - near.z) : Infinity; // a kite riding over the garden spooks them
    if ((this.state === 'coming' || this.state === 'pecking') && (playerD < 7 || kiteD < 30)) this.scatter();

    let allDone = true;
    for (const b of this.birds) {
      b.t += dt;
      b.phase += dt * (this.state === 'pecking' ? 2 : 18);
      const g = b.g;
      if (this.state === 'coming') {
        const k = THREE.MathUtils.clamp(b.t / 4, 0, 1), e = 1 - (1 - k) ** 2;
        g.position.lerpVectors(b.from, b.to, e); g.position.y += Math.sin(k * Math.PI) * 3;
        if (k < 1) allDone = false;
        this.flap(b, k < 0.92);
      } else if (this.state === 'pecking') {
        g.position.copy(b.to);
        g.rotation.z = Math.max(0, Math.sin(b.phase * 2.5)) * 0.5; // peck
        this.flap(b, false);
        if (b.t < 9) allDone = false;
      } else if (this.state === 'leaving') {
        const k = THREE.MathUtils.clamp(b.t / 3, 0, 1);
        g.position.lerpVectors(b.to, b.from, k * k); g.position.y += Math.sin(k * Math.PI) * 2;
        g.rotation.z = 0;
        this.flap(b, true);
        if (k < 1) allDone = false; else g.visible = false;
      }
      // face along the flight (or toward the crop), a little turned to the camera like the other puppets
      const dirX = this.state === 'leaving' ? b.from.x - b.to.x : b.to.x - b.from.x, dirZ = this.state === 'leaving' ? b.from.z - b.to.z : b.to.z - b.from.z;
      g.rotation.y = Math.atan2(-dirZ, dirX);
    }
    if (this.state === 'coming' && allDone) { this.state = 'pecking'; for (const b of this.birds) b.t = Math.random() * 2; this.onLand?.(); }
    else if (this.state === 'pecking' && allDone) {
      // they each make off with what they were pecking at
      const taken = new Set(this.birds.map((b) => b.target).filter((r) => r?.alive));
      for (const r of taken) this.onSteal?.(r);
      this.leave();
    } else if (this.state === 'leaving' && allDone) this.state = 'away';
  }

  flap(b, flying) {
    if (b.model) { b.model.visible = !flying; for (const p of b.cards) p.visible = flying; }
    // flying: spread and beating; landed: folded down along the back (tucked toward the tail)
    if (flying) {
      const a = Math.sin(b.phase) * 0.7;
      b.wl.rotation.set(-a, 0, 0); b.wr.rotation.set(a, 0, 0);
    } else {
      b.wl.rotation.set(0.15, 0, 0); b.wr.rotation.set(-0.15, 0, 0);
      b.wl.rotation.y = -1.15; b.wr.rotation.y = 1.15; // swept back over the tail
    }
  }

  scatter() { this.onScatter?.(); this.leave(); }

  leave() {
    this.state = 'leaving';
    for (const b of this.birds) { b.to.copy(b.g.position); b.t = -Math.random() * 0.3; }
  }
}
