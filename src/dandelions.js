// Dandelion clocks: little clumps of seeded dandelions stand about the meadows (never in the lanes), each a
// crossed die-cut card: a sage stem and toothed leaves under a cream puff ball printed with radiating seeds.
// Walk through a clump (or let Old Blue barrel through it) and the clocks you brushed puff away: a dozen tiny
// paper parachutes each drift up and off on the west wind, turning slowly, and the clock is left a bald green
// nub. Folks say you count the puffs to tell the hour. They seed again by the next morning.
// Three instanced meshes; the seeds only update while some are in the air.
import * as THREE from 'three/webgpu';
import { cardGeometry } from './props.js';
import { cardMaterial } from './materials.js';
import { paintCard } from './textures.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { getHeight, isWater, regionAt, pathField } from './world.js';
import { mulberry32 } from './noise.js';

const CELL = 13, REACH = 3, PER = 5;            // a clump in some 13 m cells, within 3 cells of the farmer
const MAXC = (REACH * 2 + 1) ** 2 * PER, SEEDS = 120;
const LEAVES = [[-0.17, 0.11], [-0.12, 0.075], [-0.14, 0.055], [-0.08, 0.042], [-0.1, 0.02], [-0.03, 0], [0.03, 0], [0.1, 0.02], [0.08, 0.042], [0.14, 0.055], [0.12, 0.075], [0.17, 0.11], [0.1, 0.09], [0.05, 0.065], [0.02, 0.055]];
const LEAVES_L = [[-0.02, 0.055], [-0.05, 0.065], [-0.1, 0.09]];

function outline(cy, r) {
  const pts = [...LEAVES, [0.017, cy - r + 0.004]];
  const a0 = -Math.PI / 2 + Math.asin(0.017 / r);
  for (let i = 0; i <= 18; i++) { const a = a0 + (i / 18) * (Math.PI * 2 - 2 * Math.asin(0.017 / r)); pts.push([Math.cos(a) * r, cy + Math.sin(a) * r]); }
  pts.push([-0.017, cy - r + 0.004], ...LEAVES_L);
  return pts;
}

function art(pts, cy, r, bald) {
  return paintCard(pts, {
    W: 128, H: 160, seed: bald ? 307 : 303, base: '#efe6cf', fills: ['rgba(246,240,224,A)', 'rgba(226,216,190,A)'], edge: 'rgba(84,62,40,1)',
    details(g, px) {
      // the stem and the toothed leaves, sage with a darker midrib
      g.fillStyle = '#6f9448';
      g.beginPath(); [...LEAVES, [0.017, cy - r], [-0.017, cy - r], ...LEAVES_L].forEach(([x, y], i) => { const [a, b] = px(x, y); i ? g.lineTo(a, b) : g.moveTo(a, b); }); g.closePath(); g.fill();
      g.strokeStyle = '#3f5a2c'; g.lineWidth = 4; g.beginPath();
      for (const s of [-1, 1]) { const [a, b] = px(0, 0.01), [c, d] = px(s * 0.14, 0.085); g.moveTo(a, b); g.lineTo(c, d); }
      const [sa, sb] = px(0, 0.02), [sc, sd] = px(0, cy - r); g.moveTo(sa, sb); g.lineTo(sc, sd); g.stroke();
      const [cx0, cy0] = px(0, cy), [rx] = px(r, cy), R = rx - cx0;
      if (bald) { g.fillStyle = '#a3864e'; g.beginPath(); g.arc(cx0, cy0, R * 0.9, 0, Math.PI * 2); g.fill(); g.fillStyle = '#6f5a34'; g.beginPath(); g.arc(cx0, cy0, R * 0.45, 0, Math.PI * 2); g.fill(); return; }
      // the clock: a cream ball with a ring of seeds radiating from a tan heart, each tipped with a tuft
      g.fillStyle = '#f7f1e2'; g.beginPath(); g.arc(cx0, cy0, R, 0, Math.PI * 2); g.fill();
      g.strokeStyle = 'rgba(150,128,96,0.75)'; g.lineWidth = 2.5; g.fillStyle = '#fffaf0';
      for (let i = 0; i < 16; i++) {
        const a = (i / 16) * Math.PI * 2 + 0.1, x1 = cx0 + Math.cos(a) * R * 0.78, y1 = cy0 + Math.sin(a) * R * 0.78;
        g.beginPath(); g.moveTo(cx0 + Math.cos(a) * R * 0.2, cy0 + Math.sin(a) * R * 0.2); g.lineTo(x1, y1); g.stroke();
        g.beginPath(); g.arc(x1, y1, 3.6, 0, Math.PI * 2); g.fill(); g.stroke();
      }
      g.fillStyle = '#b89a62'; g.beginPath(); g.arc(cx0, cy0, R * 0.2, 0, Math.PI * 2); g.fill();
    },
  });
}

const SEED = [[-0.008, 0], [0.008, 0], [0.008, 0.03], [0.04, 0.05], [0.026, 0.066], [0, 0.052], [-0.026, 0.066], [-0.04, 0.05], [-0.008, 0.03]];

export class Dandelions {
  constructor(scene) {
    const CY = 0.33, R = 0.095, BR = 0.035;
    const crossed = (pts) => mergeGeometries([cardGeometry(pts, 0.012), cardGeometry(pts, 0.012).rotateY(Math.PI / 2)]);
    const full = outline(CY, R), bald = outline(CY - 0.06, BR);
    this.clocks = new THREE.InstancedMesh(crossed(full), cardMaterial(art(full, CY, R, false)), MAXC);
    this.bald = new THREE.InstancedMesh(crossed(bald), cardMaterial(art(bald, CY - 0.06, BR, true)), MAXC);
    const seedArt = paintCard(SEED, { W: 64, H: 64, seed: 311, base: '#f7f1e2', fills: ['rgba(255,250,240,A)'], edge: 'rgba(120,100,76,1)' });
    this.seeds = new THREE.InstancedMesh(cardGeometry(SEED, 0.004), cardMaterial(seedArt, { side: THREE.DoubleSide }), SEEDS);
    for (const m of [this.clocks, this.bald]) { m.castShadow = true; m.receiveShadow = true; m.count = 0; m.frustumCulled = false; scene.add(m); }
    this.seeds.count = 0; this.seeds.frustumCulled = false; scene.add(this.seeds);
    this.cell = '';
    this.list = [];                     // { x, y, z, s, rot, key }
    this.blown = new Map();             // key → day it was blown (it seeds again the next day)
    this.flying = [];                   // { p, v, rot, spin, t, life }
    this.day = 0;
    this.dirty = true;
  }

  /** Lay out the clumps around the farmer (re-done when he walks into another cell). */
  place(cx, cz) {
    this.list = [];
    for (let dz = -REACH; dz <= REACH; dz++) for (let dx = -REACH; dx <= REACH; dx++) {
      const gx = cx + dx, gz = cz + dz, rng = mulberry32(((gx * 73856093) ^ (gz * 19349663)) >>> 0);
      if (rng() > 0.45) continue; // not every patch of meadow has them
      const x0 = (gx + 0.15 + rng() * 0.7) * CELL, z0 = (gz + 0.15 + rng() * 0.7) * CELL;
      if (isWater(x0, z0) || regionAt(x0, z0) !== 'meadow' || pathField(x0, z0) < 0.12) continue;
      for (let i = 0; i < PER; i++) {
        const a = rng() * Math.PI * 2, r = 0.25 + rng() * 0.75, x = x0 + Math.cos(a) * r, z = z0 + Math.sin(a) * r;
        this.list.push({ x, z, y: getHeight(x, z), s: 1.25 + rng() * 0.45, rot: rng() * Math.PI, key: `${gx},${gz},${i}` });
      }
    }
    this.dirty = true;
  }

  write() {
    let a = 0, b = 0;
    for (const c of this.list) {
      const gone = this.blown.get(c.key) === this.day;
      _q.setFromAxisAngle(_y, c.rot); _m.compose(_p.set(c.x, c.y, c.z), _q, _s.setScalar(c.s));
      (gone ? this.bald : this.clocks).setMatrixAt(gone ? b++ : a++, _m);
    }
    this.clocks.count = a; this.bald.count = b;
    this.clocks.instanceMatrix.needsUpdate = true; this.bald.instanceMatrix.needsUpdate = true;
    this.dirty = false;
  }

  /** kickers: [{ pos, speed }]. Returns how many clocks were blown this frame. */
  update(dt, day, center, kickers) {
    if (day !== this.day) { this.day = day; this.dirty = true; }
    const cx = Math.floor(center.x / CELL), cz = Math.floor(center.z / CELL), cell = `${cx},${cz}`;
    if (cell !== this.cell) { this.cell = cell; this.place(cx, cz); }
    let blown = 0;
    for (const c of this.list) {
      if (this.blown.get(c.key) === day) continue;
      for (const k of kickers) {
        if (k.speed < 0.8 || Math.abs(k.pos.x - c.x) > 0.7 || Math.abs(k.pos.z - c.z) > 0.7) continue;
        this.blown.set(c.key, day); blown++; this.dirty = true;
        // a puff of a dozen seeds, away from whoever brushed past and off downwind
        const ax = c.x - k.pos.x, az = c.z - k.pos.z, al = Math.hypot(ax, az) || 1;
        for (let i = 0; i < 12 && this.flying.length < SEEDS; i++) {
          this.flying.push({
            p: new THREE.Vector3(c.x + (Math.random() - 0.5) * 0.2, c.y + 0.33 * c.s + (Math.random() - 0.5) * 0.15, c.z + (Math.random() - 0.5) * 0.2),
            v: new THREE.Vector3((ax / al) * 0.8 + (Math.random() - 0.5) * 0.9, 0.5 + Math.random() * 0.7, (az / al) * 0.8 + (Math.random() - 0.5) * 0.9),
            rot: new THREE.Euler(Math.random() * 6, Math.random() * 6, 0), spin: (Math.random() - 0.5) * 2, t: 0, life: 9 + Math.random() * 5, ph: Math.random() * 6,
          });
        }
        break;
      }
    }
    if (this.dirty) this.write();
    // the seeds: they rise on the warm air, sway, and ride the west wind off over the meadow
    if (this.flying.length || this.seeds.count) {
      let n = 0;
      for (let i = this.flying.length - 1; i >= 0; i--) {
        const f = this.flying[i]; f.t += dt;
        if (f.t > f.life) { this.flying.splice(i, 1); continue; }
        f.v.x += (1.1 - f.v.x) * dt * 0.6; f.v.z += (0 - f.v.z) * dt * 0.4; f.v.y += (0.25 - f.v.y) * dt * 0.5;
        f.p.addScaledVector(f.v, dt);
        f.p.x += Math.sin(f.t * 1.7 + f.ph) * 0.25 * dt; f.p.z += Math.cos(f.t * 1.3 + f.ph) * 0.25 * dt;
        f.rot.y += f.spin * dt; f.rot.x = Math.sin(f.t * 2 + f.ph) * 0.35;
        _q.setFromEuler(f.rot); _m.compose(f.p, _q, _s.setScalar(1.6));
        this.seeds.setMatrixAt(n++, _m);
      }
      this.seeds.count = n; this.seeds.instanceMatrix.needsUpdate = true;
    }
    return blown;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _m = new THREE.Matrix4(), _s = new THREE.Vector3(), _y = new THREE.Vector3(0, 1, 0);
