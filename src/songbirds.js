// Songbirds at the feeder: while a bird feeder you've built holds seed, little die-cut birds come to it, a
// cardinal (barn red, black mask), a bluebird (blue back, rusty breast) and a chickadee (black cap, buff
// sides). They perch on the tray pecking with a bob of the head, hop down to glean the grass beneath, and
// flit off and back now and then. Walk up close and they all burst away, returning once you've stepped off.
// Three instanced meshes (one per kind), for the two feeders nearest the farmer.
import * as THREE from 'three/webgpu';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight } from './world.js';
import { propModel } from './modelfolk.js';

// the birds from the reference art, by kind: each model baked into one geometry, beak along +x, profile to +z, feet at
// 0 and about as long as the card bird, so the instancing, the camera-facing turn and the pecking all stay as they were
const MODELS = ['animal_cardinal', 'animal_bluebird', 'animal_chickadee'];
function birdModel(i) {
  const src = propModel(MODELS[i]); if (!src) return null;
  let geo = null, mat = null; src.scene.updateWorldMatrix(true, true);
  src.scene.traverse((o) => { if (o.isMesh && !geo) { geo = o.geometry.clone().applyMatrix4(o.matrixWorld); mat = o.material; } });
  if (!geo) return null;
  geo.rotateY(Math.PI / 2); geo.computeBoundingBox();
  const b = geo.boundingBox, k = 0.33 / (b.max.x - b.min.x);
  geo.translate(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2).scale(k, k, k);
  return { geo, mat };
}

const BIRD = [[-0.12, 0.04], [-0.2, 0.09], [-0.18, 0.11], [-0.08, 0.1], [0.0, 0.14], [0.06, 0.17], [0.11, 0.16], [0.15, 0.13], [0.12, 0.11], [0.12, 0.07], [0.06, 0.02], [0.02, 0.0], [-0.06, 0.0]];
const KINDS = [
  { base: '#c4362f', draw(g, px) { g.fillStyle = '#2b2018'; { const [a, b] = px(0.11, 0.13); g.beginPath(); g.arc(a, b, 9, 0, Math.PI * 2); g.fill(); } g.fillStyle = '#e8a040'; { const p = [px(0.15, 0.13), px(0.2, 0.12), px(0.15, 0.11)]; g.beginPath(); g.moveTo(...p[0]); for (const q of p) g.lineTo(...q); g.fill(); } g.fillStyle = '#9a2a24'; { const [a, b] = px(-0.04, 0.08); g.beginPath(); g.ellipse(a, b, 22, 10, 0.2, 0, Math.PI * 2); g.fill(); } } },
  { base: '#4f7ab8', draw(g, px) { g.fillStyle = '#d98a4a'; { const [a, b] = px(0.05, 0.05); g.beginPath(); g.ellipse(a, b, 20, 12, 0.3, 0, Math.PI * 2); g.fill(); } g.fillStyle = '#2b2018'; { const [a, b] = px(0.1, 0.13); g.beginPath(); g.arc(a, b, 3, 0, Math.PI * 2); g.fill(); } } },
  { base: '#9a9a92', draw(g, px) { g.fillStyle = '#2b2018'; { const [a, b] = px(0.08, 0.15); g.beginPath(); g.arc(a, b, 13, Math.PI, Math.PI * 2.1); g.fill(); } g.fillStyle = '#f3ead6'; { const [a, b] = px(0.08, 0.11); g.beginPath(); g.ellipse(a, b, 9, 6, 0, 0, Math.PI * 2); g.fill(); } g.fillStyle = '#d9b48a'; { const [a, b] = px(0.0, 0.05); g.beginPath(); g.ellipse(a, b, 16, 8, 0, 0, Math.PI * 2); g.fill(); } } },
];
const PER_KIND = 2, FEEDERS = 2;

export class Songbirds {
  constructor(scene) {
    const geo = cardGeometry(BIRD, 0.01);
    this.meshes = KINDS.map((k, i) => {
      const art = paintCard(BIRD, { W: 128, H: 64, seed: 271 + i, base: k.base, fills: ['rgba(255,255,255,0)'], edge: 'rgba(40,30,24,1)', details: k.draw });
      const real = birdModel(i);
      const m = new THREE.InstancedMesh(real ? real.geo : geo, real ? real.mat : cardMaterial(art, { side: THREE.DoubleSide }), PER_KIND * FEEDERS);
      m.castShadow = true; m.frustumCulled = false; m.count = 0; scene.add(m);
      return m;
    });
    this.birds = [];
    for (let f = 0; f < FEEDERS; f++) for (let k = 0; k < KINDS.length; k++) for (let i = 0; i < PER_KIND; i++) {
      this.birds.push({ f, k, slot: this.birds.length, pos: new THREE.Vector3(), from: new THREE.Vector3(), to: new THREE.Vector3(), state: 'away', t: Math.random() * 6, dur: 1, side: 1, peck: Math.random() * 6 });
    }
    this.feeders = [];
    this.onFlush = null;
  }

  spot(F, b) {
    // crumbs on a boardwalk (F.ground: a bakery doorstep): pecking about on the planks
    if (F.ground) { const a = Math.random() * Math.PI * 2, r = 0.3 + Math.random() * 1.3; return new THREE.Vector3(F.x + Math.cos(a) * r, F.y + 0.16, F.z + Math.sin(a) * r); }
    // on the tray (y 1.57) or on the grass under it
    if (Math.random() < 0.6) { const a = Math.random() * Math.PI * 2; return _t.set(F.x + Math.cos(a) * 0.22, F.y + 1.57, F.z + Math.sin(a) * 0.16).clone(); }
    const a = Math.random() * Math.PI * 2, r = 0.5 + Math.random() * 1.0, x = F.x + Math.cos(a) * r, z = F.z + Math.sin(a) * r;
    return new THREE.Vector3(x, getHeight(x, z) + 0.01, z);
  }

  fly(b, to) { b.from.copy(b.pos); b.to.copy(to); b.state = 'fly'; b.t = 0; b.dur = 0.5 + b.from.distanceTo(to) * 0.08; }

  update(dt, feeders, player, camera) {
    this.feeders = feeders.slice(0, FEEDERS);
    let flushed = false;
    const counts = [0, 0, 0];
    for (const b of this.birds) {
      const F = this.feeders[b.f];
      const mesh = this.meshes[b.k];
      if (!F) { b.state = 'away'; continue; }
      const pd = Math.hypot(player.pos.x - F.x, player.pos.z - F.z);
      b.t += dt;
      if (b.state === 'away') {
        if (pd > 6 && b.t > 2 + (b.slot % 5)) { b.pos.set(F.x + (Math.random() - 0.5) * 30, F.y + 9, F.z + (Math.random() - 0.5) * 30); this.fly(b, this.spot(F, b)); }
        else continue;
      } else if (b.state === 'perch') {
        if (pd < 3.2) { flushed = true; this.fly(b, _t.set(F.x + (Math.random() - 0.5) * 40, F.y + 10, F.z + (Math.random() - 0.5) * 40).clone()); b.leaving = true; }
        else if (b.t > b.dur) { if (Math.random() < 0.15) { this.fly(b, _t.set(F.x + (Math.random() - 0.5) * 16, F.y + 5, F.z + (Math.random() - 0.5) * 16).clone()); b.leaving = true; } else this.fly(b, this.spot(F, b)); }
      } else if (b.state === 'fly') {
        const k = Math.min(1, b.t / b.dur);
        b.pos.lerpVectors(b.from, b.to, k); b.pos.y += Math.sin(k * Math.PI) * (b.leaving ? 1.5 : 0.6);
        b.side = b.to.x - b.from.x >= 0 ? 1 : -1;
        if (k >= 1) {
          if (b.leaving) { b.leaving = false; b.state = 'away'; b.t = 0; continue; }
          b.state = 'perch'; b.t = 0; b.dur = 2 + Math.random() * 5;
        }
      }
      // a card facing the camera, nose the way it's going; a pecking bob when perched, a flutter when flying
      const yaw = Math.atan2(camera.position.x - b.pos.x, camera.position.z - b.pos.z);
      const camRight = _r.set(Math.cos(yaw), 0, -Math.sin(yaw));
      const facing = (b.state === 'fly' ? _d.subVectors(b.to, b.from) : _d.set(b.side, 0, 0)).dot(camRight) >= 0 ? 1 : -1;
      const tilt = b.state === 'perch' ? (Math.sin(b.t * 9 + b.peck) > 0.6 ? -0.5 : 0.05) : Math.sin(b.t * 30) * 0.25;
      _q.setFromEuler(_e.set(0, yaw, tilt * facing));
      _m.compose(b.pos, _q, _s.set(1.5 * facing, 1.5, 1.5));
      mesh.setMatrixAt(counts[b.k]++, _m);
    }
    this.meshes.forEach((m, i) => { m.count = counts[i]; if (counts[i]) m.instanceMatrix.needsUpdate = true; });
    if (flushed) this.onFlush?.();
  }
}

const _t = new THREE.Vector3(), _r = new THREE.Vector3(), _d = new THREE.Vector3(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _m = new THREE.Matrix4(), _s = new THREE.Vector3();
