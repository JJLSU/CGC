// The railroad: once all three of Paydirt Hollow's streets stand mended, the town is worth a railroad, and a line is
// laid from a paper depot past the church out across the county, through a whistle-stop in each of the wild lands.
// Its right-of-way is surveyed from the start (cleared of trees and rocks before any of the county is built), so the
// track can go down on open ground the day the town earns it.
//
// Stage 1: the route, the cleared right-of-way, the depot and the track (ties, iron rails, trestles over water) and a
// little platform with a name board at each whistle-stop. The train itself, riding it and freight come after.
// Stage 5: a trading post behind each whistle-stop's platform, its keeper out front by day, dealing in what that land
// has plenty of and paying for what it's short of (the trades themselves are in crafting.js, station 'post-<land>').
import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { paperMaterial } from './materials.js';
import { card } from './town.js';
import { propModel, ModelFigure, hasFolk } from './modelfolk.js';
import { getHeight, isWater, landAt, LANDS } from './world.js';

const TIE = 0.9; // metres between ties
const LAND_KEYS = ['hollows', 'breaks', 'fen', 'prairie', 'pines'];
// who keeps each trading post (real figures, re-dyed; skin is never touched)
const KEEPERS = { hollows: { model: 'trades_5', hue: 0.6 }, breaks: { model: 'prospectors_4', hue: 0 }, fen: { model: 'folk_calico_01', hue: 2.2 }, prairie: { model: 'folk_farmhand_02', hue: 0.4 }, pines: { model: 'trades_2', hue: 3.4 } };

export class Railroad {
  constructor(scene, world, town, home) {
    this.scene = scene; this.town = town; this.built = false;
    this.group = new THREE.Group(); this.group.visible = false; scene.add(this.group);
    const A = town.at, along = town.along, toward = town.toward;
    // the depot, straight on from Main Street past the church, and the line out from it
    this.depot = A.clone().addScaledVector(along, 36);
    const start = A.clone().addScaledVector(along, 52);
    // a whistle-stop in each wild land: its nearest good stretch, visited in turn, nearest first
    const found = {};
    for (let r = 80; r < 760 && Object.keys(found).length < 5; r += 25) {
      for (let a = 0; a < Math.PI * 2; a += 0.08) {
        const x = this.depot.x + Math.cos(a) * r, z = this.depot.z + Math.sin(a) * r;
        const L = landAt(x, z);
        for (const k of LAND_KEYS) if (!found[k] && L.w[k] > 0.9 && !isWater(x, z)) found[k] = new THREE.Vector3(x, 0, z);
      }
    }
    const stops = [];
    let at = start.clone();
    const left = Object.entries(found);
    while (left.length) {
      left.sort((p, q) => p[1].distanceTo(at) - q[1].distanceTo(at));
      const [k, p] = left.shift(); stops.push({ land: k, name: LANDS[k].name.replace(/^the /, ''), at: p }); at = p;
    }
    this.stops = stops;
    // the route: the depot, a straight run out past the church, then stop to stop, swinging wide of the town and the
    // homestead where a leg would cut through them
    const pts = [this.depot.clone(), start.clone()];
    const avoid = [{ c: A, r: 58 }, { c: home, r: 48 }];
    for (const s of stops) {
      const from = pts[pts.length - 1];
      for (const { c, r } of avoid) {
        const d = s.at.clone().sub(from), len = d.length(), u = d.clone().divideScalar(len);
        const t = Math.max(0, Math.min(len, c.clone().sub(from).dot(u))), close = from.clone().addScaledVector(u, t);
        if (close.distanceTo(c) < r && t > 1 && t < len - 1) {
          const side = new THREE.Vector3(-u.z, 0, u.x); if (side.dot(close.clone().sub(c)) < 0) side.negate();
          pts.push(c.clone().addScaledVector(side, r + 10)); // (around it)
        }
      }
      pts.push(s.at.clone());
    }
    // sample the line every TIE metres, softening the corners a little
    this.path = [];
    for (let i = 0; i < pts.length - 1; i++) {
      const a = pts[i], b = pts[i + 1], len = a.distanceTo(b), n = Math.max(1, Math.round(len / TIE));
      for (let j = 0; j < n; j++) this.path.push(a.clone().lerp(b, j / n));
    }
    this.path.push(pts[pts.length - 1].clone());
    this.length = this.path.length * TIE;
    // the right-of-way: nothing grows on it (cleared before any chunk is built)
    for (let i = 0; i < this.path.length; i += 5) world.exclusions.push({ x: this.path[i].x, z: this.path[i].z, r: 3.4 });
    world.exclusions.push({ x: this.depot.x, z: this.depot.z, r: 9 });
    for (const s of stops) world.exclusions.push({ x: s.at.x, z: s.at.z, r: 6 });
    // each stop's layout, worked out now so its trading post's ground is cleared before the county is built: the
    // platform a few ties back along the incoming track on the outside of the bend, the post behind it
    for (const s of stops) {
      const P = this.path, k = P.reduce((bi, p, j) => (p.distanceTo(s.at) < P[bi].distanceTo(s.at) ? j : bi), 0), i = Math.max(2, k - 6);
      const a = P[Math.max(0, i - 2)], b = P[Math.min(P.length - 1, i + 2)], yaw = Math.atan2(b.x - a.x, b.z - a.z);
      const side = new THREE.Vector3(Math.cos(yaw), 0, -Math.sin(yaw));
      const out = P[Math.min(P.length - 1, k + 8)].clone().sub(P[k]); if (out.dot(side) > 0) side.negate();
      const along = new THREE.Vector3(Math.sin(yaw), 0, Math.cos(yaw));
      s.geo = { i, side, along, plat: P[i].clone().addScaledVector(side, 2.4), post: P[i].clone().addScaledVector(side, 8.6).addScaledVector(along, -1.5) };
      world.exclusions.push({ x: s.geo.post.x, z: s.geo.post.z, r: 6.5 });
      if (s.land === 'breaks') { s.geo.claim = P[i].clone().addScaledVector(side, 11).addScaledVector(along, -17); world.exclusions.push({ x: s.geo.claim.x, z: s.geo.claim.z, r: 9.5 }); } // (your gold claim, if you file one: claim.js)
    }
  }

  /** Lay the track and put up the depot (once; the town has earned its railroad). */
  build() {
    if (this.built) return; this.built = true; this.group.visible = true;
    const P = this.path, wood = paperMaterial({ color: 0x6a4a30, flatShading: true }), iron = paperMaterial({ color: 0x3a3632, flatShading: true });
    const ys = P.map((p) => (isWater(p.x, p.z) ? 0.55 : getHeight(p.x, p.z) + 0.04)); // (over water the track runs on a trestle)
    // ties: one instanced mesh down the whole line
    const ties = new THREE.InstancedMesh(new THREE.BoxGeometry(1.7, 0.08, 0.24), wood, P.length);
    const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), one = new THREE.Vector3(1, 1, 1), pos = new THREE.Vector3();
    const posts = [];
    for (let i = 0; i < P.length; i++) {
      const a = P[Math.max(0, i - 1)], b = P[Math.min(P.length - 1, i + 1)], yaw = Math.atan2(b.x - a.x, b.z - a.z);
      ties.setMatrixAt(i, m.compose(pos.set(P[i].x, ys[i], P[i].z), q.setFromEuler(e.set(0, yaw + Math.PI / 2, 0)), one));
      if (ys[i] > getHeight(P[i].x, P[i].z) + 0.3 && i % 3 === 0) for (const s of [-0.7, 0.7]) { // trestle legs down to the water's bottom
        const px = P[i].x + Math.cos(yaw) * s, pz = P[i].z - Math.sin(yaw) * s, h = ys[i] - Math.min(0, getHeight(px, pz)) + 0.2;
        posts.push(new THREE.BoxGeometry(0.14, h, 0.14).translate(px, ys[i] - h / 2, pz));
      }
    }
    ties.castShadow = true; ties.receiveShadow = true; ties.frustumCulled = false; this.group.add(ties);
    if (posts.length) { const pm = new THREE.Mesh(mergeGeometries(posts), wood); pm.castShadow = true; this.group.add(pm); }
    // the two iron rails, a short straight bar between every few ties, following the ground
    const bars = [], STEP = 3;
    for (let i = 0; i + STEP < P.length; i += STEP) {
      const a = P[i], b = P[i + STEP], ya = ys[i] + 0.08, yb = ys[i + STEP] + 0.08, yaw = Math.atan2(b.x - a.x, b.z - a.z);
      for (const s of [-0.55, 0.55]) {
        const ax = a.x + Math.cos(yaw) * s, az = a.z - Math.sin(yaw) * s, bx = b.x + Math.cos(yaw) * s, bz = b.z - Math.sin(yaw) * s;
        const from = new THREE.Vector3(ax, ya, az), to = new THREE.Vector3(bx, yb, bz), mid = from.clone().add(to).multiplyScalar(0.5);
        const g = new THREE.BoxGeometry(0.07, 0.07, from.distanceTo(to) + 0.02); g.lookAt(to.clone().sub(from)); g.translate(mid.x, mid.y, mid.z); bars.push(g.toNonIndexed());
      }
    }
    const rails = new THREE.Mesh(mergeGeometries(bars), iron); rails.castShadow = true; this.group.add(rails);
    this.stringWire(ys, wood);
    this.makeDepot(wood);
    this.freightAt = this.depotGroup.localToWorld(new THREE.Vector3(-4.6, 0.3, 2.4)); // (the freight office's end of the platform)
    for (const s of this.stops) this.makeStop(s, wood);
  }

  /** Telegraph poles beside the line, a crossarm and two glass insulators on each, and two sagging wires strung
   *  between them: the poles merged into one mesh, the wires one set of line segments. */
  stringWire(ys, wood) {
    const P = this.path, poles = [], wire = [], tops = [], OFF = 2.9, EVERY = 24;
    const glass = []; let last = null;
    const clearOf = (x, z) => this.stops.every((s) => Math.hypot(s.geo.plat.x - x, s.geo.plat.z - z) > 6 && Math.hypot(s.geo.post.x - x, s.geo.post.z - z) > 7) && Math.hypot(this.depot.x - x, this.depot.z - z) > 11;
    for (let i = 8; i < P.length - 4; i += EVERY) {
      const a = P[i - 1], b = P[i + 1], yaw = Math.atan2(b.x - a.x, b.z - a.z), x = P[i].x - Math.cos(yaw) * OFF, z = P[i].z + Math.sin(yaw) * OFF;
      if (isWater(x, z) || ys[i] > getHeight(P[i].x, P[i].z) + 0.3 || !clearOf(x, z)) { last = null; continue; } // (no poles in the water or on a platform; the wire breaks there)
      const y = getHeight(x, z), lean = ((i * 7919) % 100) / 100 - 0.5; // (each pole a little off true, as they are)
      const g = new THREE.BoxGeometry(0.16, 4.6, 0.16).translate(0, 2.3, 0);
      poles.push(g.rotateZ(lean * 0.04).rotateY(yaw).translate(x, y, z).toNonIndexed());
      poles.push(new THREE.BoxGeometry(1.3, 0.12, 0.12).translate(0, 4.3, 0).rotateY(yaw).translate(x, y, z).toNonIndexed());
      const ends = [-0.55, 0.55].map((u) => new THREE.Vector3(x + Math.cos(yaw) * u, y + 4.46, z - Math.sin(yaw) * u));
      for (const e of ends) glass.push(new THREE.CylinderGeometry(0.05, 0.07, 0.16, 6).translate(e.x, e.y - 0.02, e.z).toNonIndexed());
      if (last) for (let w = 0; w < 2; w++) { // each wire sags between its two poles
        const p0 = last[w], p1 = ends[w], N = 6;
        for (let k = 0; k < N; k++) {
          const t0 = k / N, t1 = (k + 1) / N, sag = (t) => Math.sin(t * Math.PI) * 0.45;
          wire.push(p0.x + (p1.x - p0.x) * t0, p0.y + (p1.y - p0.y) * t0 - sag(t0), p0.z + (p1.z - p0.z) * t0, p0.x + (p1.x - p0.x) * t1, p0.y + (p1.y - p0.y) * t1 - sag(t1), p0.z + (p1.z - p0.z) * t1);
        }
      }
      last = ends;
    }
    if (!poles.length) return;
    const pm = new THREE.Mesh(mergeGeometries(poles), paperMaterial({ color: 0x5e4630, flatShading: true })); pm.castShadow = true; pm.receiveShadow = true; this.group.add(pm);
    const gm = new THREE.Mesh(mergeGeometries(glass), paperMaterial({ color: 0x7fb0a0, flatShading: true })); this.group.add(gm);
    const wg = new THREE.BufferGeometry(); wg.setAttribute('position', new THREE.Float32BufferAttribute(wire, 3));
    this.group.add(new THREE.LineSegments(wg, new THREE.LineBasicMaterial({ color: 0x2a2018 })));
  }

  /** The depot: a printed clapboard station house (the telegraph office's model, a station agent's office being much the
   *  same), on a long plank platform beside the line, with the name board up on two posts at the end of it. */
  makeDepot(wood) {
    const g = new THREE.Group(), y = getHeight(this.depot.x, this.depot.z);
    const deck = new THREE.Mesh(new THREE.BoxGeometry(14, 0.3, 4.6).translate(0, 0.15, 2.6), wood); deck.castShadow = deck.receiveShadow = true; g.add(deck);
    const src = propModel('bldg_telegraph_restored') || propModel('bldg_assay');
    if (src) {
      const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = 7 / Math.max(sz.x, sz.z);
      const hold = new THREE.Group(); m.position.set(-c.x, -bb.min.y, -c.z); hold.add(m); hold.scale.setScalar(k); hold.position.set(0, 0, -1.4); g.add(hold);
    }
    const sign = card([[-2.1, 0], [2.1, 0.02], [2.15, 0.62], [-2.1, 0.6]], '#efe3c4', (gg, px) => {
      gg.fillStyle = '#3a2a1c'; gg.textAlign = 'center'; gg.textBaseline = 'middle';
      let [x, yy] = px(0, 0.38); gg.font = 'bold 34px Georgia, serif'; gg.fillText('PAYDIRT HOLLOW', x, yy);
      [x, yy] = px(0, 0.15); gg.font = 'italic 22px Georgia, serif'; gg.fillText('Overland & Western Rail Road', x, yy);
    }, { W: 512, H: 96, seed: 1201, thick: 0.04 });
    sign.position.set(5.2, 2.1, 4.6); g.add(sign);
    for (const x of [3.3, 7.1]) { const post = new THREE.Mesh(new THREE.BoxGeometry(0.14, 2.6, 0.14), wood); post.position.set(x, 1.3, 4.6); post.castShadow = true; g.add(post); }
    // set beside the first stretch of line, its platform edge along the track
    const a = this.path[0], b = this.path[6], yaw = Math.atan2(b.x - a.x, b.z - a.z), side = new THREE.Vector3(Math.cos(yaw), 0, -Math.sin(yaw));
    g.rotation.y = yaw + Math.PI / 2; // (its front and platform toward the track)
    const p = this.path[3].clone().addScaledVector(side, -5.4); g.position.set(p.x, y, p.z);
    this.group.add(g); this.depotGroup = g;
  }

  /** A whistle-stop: a short plank platform beside the line and a name board on two posts. */
  makeStop(s, wood) {
    // (each stop is a bend in the line: the platform stands a few ties back along the incoming track, on the outside of
    // the bend, so the outgoing track never runs across it; see the constructor)
    const { i, side } = s.geo, p = s.geo.plat, y = getHeight(p.x, p.z);
    const g = new THREE.Group();
    const deck = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.25, 6), wood); deck.position.y = 0.12; deck.castShadow = deck.receiveShadow = true; g.add(deck);
    for (const z of [-2.2, 2.2]) { const post = new THREE.Mesh(new THREE.BoxGeometry(0.12, 2.2, 0.12), wood); post.position.set(0.9, 1.1, z * 0.45); post.castShadow = true; g.add(post); }
    const board = card([[-1.2, 0], [1.2, 0.02], [1.22, 0.42], [-1.2, 0.4]], '#efe3c4', (gg, px) => {
      gg.fillStyle = '#3a2a1c'; gg.textAlign = 'center'; gg.textBaseline = 'middle';
      const [x, yy] = px(0, 0.21); gg.font = `bold ${s.name.length > 14 ? 30 : 36}px Georgia, serif`; gg.fillText(s.name.toUpperCase(), x, yy);
    }, { W: 512, H: 96, seed: 1300 + s.name.length, thick: 0.04 });
    board.position.set(0.9, 2.0, 0); board.rotation.y = -Math.PI / 2; g.add(board); // (read from the track)
    g.position.set(p.x, y, p.z); g.lookAt(p.x + side.x, y, p.z + side.z); g.rotateY(-Math.PI / 2); // (deck along the track, name board on the far edge, facing it)
    this.group.add(g); s.platform = p; s.stand = this.path[i].clone(); // (where the train will draw up)
    this.makePost(s, wood);
  }

  /** The trading post behind a whistle-stop: a little printed clapboard store facing the track, a barrel and crates by
   *  its door, a path of planks down to the platform, and its keeper standing out front by day. */
  makePost(s, wood) {
    const { side, along, post } = s.geo, y = getHeight(post.x, post.z), face = Math.atan2(-side.x, -side.z);
    const g = new THREE.Group(); g.position.set(post.x, y, post.z); g.rotation.y = face;
    const put = (name, size, x, z, turn = 0, byHeight = false) => {
      const src = propModel(name); if (!src) return;
      const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = size / (byHeight ? sz.y : Math.max(sz.x, sz.z));
      const hold = new THREE.Group(); m.position.set(-c.x, -bb.min.y, -c.z); hold.add(m); hold.scale.setScalar(k); hold.position.set(x, 0, z); hold.rotation.y = turn; g.add(hold);
    };
    put('bldg_cottage_restored', 6.2, 0, -0.6);
    put('prop_barrel', 0.95, 2.7, 2.6, 0.4, true); put('prop_crates', 1.0, -2.8, 2.4, -0.3, true);
    // a plank walk from the door to the platform
    const planks = [];
    for (let k = 0; k < 5; k++) planks.push(new THREE.BoxGeometry(1.3, 0.06, 0.32).translate((k % 2) * 0.08 - 0.04, 0.03, 3.1 + k * 0.62).toNonIndexed());
    const walk = new THREE.Mesh(mergeGeometries(planks), wood); walk.receiveShadow = true; g.add(walk);
    // a hand-lettered board over the door's side: TRADING POST, and the land's name under it
    const sign = card([[-1.5, 0], [1.5, 0.03], [1.52, 0.56], [-1.48, 0.54]], '#e9dcb8', (gg, px) => {
      gg.fillStyle = '#4a2a18'; gg.textAlign = 'center'; gg.textBaseline = 'middle';
      let [x, yy] = px(0, 0.36); gg.font = 'bold 40px Georgia, serif'; gg.fillText('TRADING POST', x, yy);
      [x, yy] = px(0, 0.13); gg.font = 'italic 22px Georgia, serif'; gg.fillText('Goods bought & sold', x, yy);
    }, { W: 512, H: 100, seed: 1700 + s.name.length, thick: 0.04 });
    sign.position.set(-2.6, 1.9, 3.0); g.add(sign);
    for (const x of [-3.8, -1.4]) { const pst = new THREE.Mesh(new THREE.BoxGeometry(0.12, 2.3, 0.12), wood); pst.position.set(x, 1.15, 3.0); pst.castShadow = true; g.add(pst); }
    this.group.add(g); s.postGroup = g;
    s.door = g.localToWorld(new THREE.Vector3(0, 0, 2.6)); // (where you trade: the step before the door)
    const K = KEEPERS[s.land];
    if (K && hasFolk(K.model)) {
      const f = new ModelFigure(K.model, { hue: K.hue }); const at = g.localToWorld(new THREE.Vector3(1.3, 0, 2.9));
      f.root.position.set(at.x, getHeight(at.x, at.z), at.z); f.root.rotation.y = face + 0.3; this.group.add(f.root); s.keeper = f;
    }
  }
  /** The whistle-stop whose trading post (x, z) is standing at, if any. */
  postAt(x, z, r = 3) { if (!this.built) return null; return this.stops.find((s) => s.door && Math.hypot(s.door.x - x, s.door.z - z) < r) || null; }
  /** The keepers: out front by day (inside after dark), and only animated while you're near. */
  update(dt, player, day) {
    if (!this.built) return;
    for (const s of this.stops) {
      if (!s.keeper) continue;
      const near = Math.hypot(s.door.x - player.pos.x, s.door.z - player.pos.z) < 60;
      s.keeper.root.visible = day && near;
      if (s.keeper.root.visible) s.keeper.update(dt, 0, null);
    }
  }

  /** A crate of freight set out on the platform (they stack up, five to a pile) for the next train. */
  addFreight() {
    this.freight = (this.freight || 0) + 1;
    const src = propModel('prop_crates'); if (!src || !this.depotGroup) return;
    const i = this.freight - 1; if (i >= 8) return;
    const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = 1.1 / sz.y;
    const hold = new THREE.Group(); m.position.set(-c.x, -bb.min.y, -c.z); hold.add(m); hold.scale.setScalar(k);
    hold.position.set(-5.8 + (i % 4) * 1.1, 0.3, 3.6 - Math.floor(i / 4) * 1.1); hold.rotation.y = (i * 1.7) % 1 - 0.5;
    this.depotGroup.add(hold); (this.crates ||= []).push(hold);
  }
  /** The train has called at the depot and taken the freight aboard. */
  takeFreight() { const n = this.freight || 0; for (const c of this.crates || []) this.depotGroup.remove(c); this.crates = []; this.freight = 0; return n; }
  save() { return { built: this.built, freight: this.freight || 0 }; }
}
