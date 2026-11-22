// The Overland & Western's train: a little paper 4-4-0 locomotive (black boiler banded in brass, a flared red stack, a
// cowcatcher, a lamp, big red drivers), her tender, a green passenger coach and a boxcar, all cut from card and
// folded. She keeps a timetable: out from the depot mid-morning and again in the afternoon, drawing up at each
// whistle-stop a while, then running back home to the depot; smoke puffs from her stack while she runs, and she
// whistles leaving a station. Off the line, out of sight, she costs nothing.
import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { paperMaterial } from './materials.js';
import { card } from './town.js';
import { asLayer } from './textures.js';
import { getHeight, isWater } from './world.js';

const SPEED = 6.5, DWELL = 18, CAR_GAP = 0.6, TIE = 0.9;
const RUNS = [0.33, 0.6]; // (when she leaves the depot)
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _p = new THREE.Vector3(), _s = new THREE.Vector3();

function part(geos, color) { const m = new THREE.Mesh(mergeGeometries(geos.map((g) => (g.index ? g.toNonIndexed() : g))), paperMaterial({ color, flatShading: true })); m.castShadow = true; m.receiveShadow = true; return m; }
const box = (w, h, d, x, y, z) => new THREE.BoxGeometry(w, h, d).translate(x, y, z);
const cyl = (r, l, x, y, z, seg = 14) => new THREE.CylinderGeometry(r, r, l, seg).rotateX(Math.PI / 2).translate(x, y, z); // (along z)
const wheel = (r, x, y, z) => new THREE.CylinderGeometry(r, r, 0.1, 16).rotateZ(Math.PI / 2).translate(x, y, z); // (axle across x)

/** A printed side sheet for a car body, glued to both flanks: len x h metres, its lower edge at y, standing out x from
 *  the centre line. draw(d) paints in metres through d: d.rect(x0, y0, x1, y1, fill), d.line(...), d.text(...), d.dot(...). */
function sides(g, len, h, x, y, base, draw, seed) {
  for (const side of [-1, 1]) {
    const c = card([[-len / 2, 0], [len / 2, 0], [len / 2, h], [-len / 2, h]], base, (gg, px) => {
      const d = {
        rect: (x0, y0, x1, y1, fill) => { const [a, b] = px(x0, y1), [c2, e] = px(x1, y0); gg.fillStyle = fill; gg.fillRect(a, b, c2 - a, e - b); },
        round: (x0, y0, x1, y1, fill, r = 0.12) => { const [a, b] = px(x0, y1), [c2, e] = px(x1, y0), rr = Math.min((c2 - a) / 2, (px(0, 0)[1] - px(0, r)[1])); gg.fillStyle = fill; gg.beginPath(); gg.moveTo(a, e); gg.lineTo(a, b + rr); gg.quadraticCurveTo(a, b, a + rr, b); gg.lineTo(c2 - rr, b); gg.quadraticCurveTo(c2, b, c2, b + rr); gg.lineTo(c2, e); gg.closePath(); gg.fill(); },
        line: (x0, y0, x1, y1, stroke, w = 4) => { gg.strokeStyle = stroke; gg.lineWidth = w; gg.lineCap = 'round'; gg.beginPath(); gg.moveTo(...px(x0, y0)); gg.lineTo(...px(x1, y1)); gg.stroke(); },
        dot: (x0, y0, r, fill) => { gg.fillStyle = fill; gg.beginPath(); gg.arc(...px(x0, y0), r, 0, Math.PI * 2); gg.fill(); },
        text: (t, x0, y0, size, fill) => { gg.fillStyle = fill; gg.textAlign = 'center'; gg.textBaseline = 'middle'; gg.font = `bold ${size}px Georgia, serif`; gg.fillText(t, ...px(x0, y0)); },
        layer: (fn) => asLayer(gg, fn, 0.8),
      };
      draw(d);
    }, { W: Math.min(1024, Math.round(len * 170)), H: Math.round(h * 170), seed: seed + side, thick: 0.02 });
    c.position.set(side * x, y, 0); c.rotation.y = side * Math.PI / 2; g.add(c);
  }
}

/** Each vehicle is built along +z (its front), centred on its own length. */
function locomotive() {
  const g = new THREE.Group(); g.userData.len = 5.2;
  g.add(part([cyl(0.62, 3.0, 0, 1.55, 0.6)], 0x2a2624)); // the boiler
  g.add(part([cyl(0.66, 0.12, 0, 1.55, -0.4), cyl(0.66, 0.12, 0, 1.55, 0.6), cyl(0.66, 0.12, 0, 1.55, 1.6), new THREE.CylinderGeometry(0.22, 0.28, 0.4, 12).translate(0, 2.3, 0.2)], 0xc8a040)); // brass bands and the steam dome
  g.add(part([new THREE.CylinderGeometry(0.4, 0.18, 0.55, 12).translate(0, 2.75, 1.6), new THREE.CylinderGeometry(0.16, 0.16, 0.6, 10).translate(0, 2.3, 1.6)], 0xb5473a)); // the flared stack
  g.add(part([box(1.6, 1.7, 1.4, 0, 1.95, -1.55), box(1.8, 0.1, 1.6, 0, 2.85, -1.55)], 0x7a2e24)); // the cab and its roof
  g.add(part([box(1.5, 0.35, 4.6, 0, 0.75, 0.1)], 0x2a2624)); // the frame
  // the cab's printed flanks: a framed arched window, brass trim and her number in gold on a panel below
  sides(g, 1.4, 1.7, 0.81, 1.1, '#7a2e24', (d) => {
    d.rect(-0.7, 1.52, 0.7, 1.7, '#5a2018'); d.rect(-0.7, 0, 0.7, 0.14, '#5a2018');
    d.layer(() => { d.round(-0.42, 0.92, 0.42, 1.42, '#3a1a14', 0.2); d.round(-0.34, 0.98, 0.34, 1.36, '#f0d290', 0.16); d.rect(-0.02, 0.98, 0.02, 1.36, '#3a1a14'); });
    d.layer(() => { d.rect(-0.5, 0.25, 0.5, 0.75, '#6a261e'); d.line(-0.46, 0.29, 0.46, 0.29, '#c8a040', 3); d.line(-0.46, 0.71, 0.46, 0.71, '#c8a040', 3); d.line(-0.46, 0.29, -0.46, 0.71, '#c8a040', 3); d.line(0.46, 0.29, 0.46, 0.71, '#c8a040', 3); });
    d.text('No. 7', 0, 0.5, 46, '#e8c060');
    for (const x of [-0.62, 0.62]) for (let y = 0.25; y < 1.5; y += 0.25) d.dot(x, y, 4, '#c8a040');
  }, 1500);
  g.add(part([new THREE.ConeGeometry(0.75, 0.9, 4, 1).rotateX(Math.PI / 2).rotateZ(Math.PI / 4).scale(1, 0.6, 1).translate(0, 0.6, 2.6)], 0xb5473a)); // the cowcatcher
  g.add(part([box(0.36, 0.36, 0.36, 0, 2.15, 2.2)], 0xe8c070)); // the lamp
  const wheels = [];
  for (const z of [-1.0, 0.2]) for (const x of [-0.78, 0.78]) wheels.push(wheel(0.62, x, 0.62, z)); // the big drivers
  for (const z of [1.4, 2.0]) for (const x of [-0.78, 0.78]) wheels.push(wheel(0.32, x, 0.32, z)); // the leading truck
  g.add(part(wheels, 0xb5473a));
  return g;
}
function tender() {
  const g = new THREE.Group(); g.userData.len = 2.8;
  g.add(part([box(1.6, 1.2, 2.6, 0, 1.25, 0), box(1.5, 0.35, 2.6, 0, 0.6, 0)], 0x2a2624));
  g.add(part([box(1.3, 0.3, 2.2, 0, 1.95, 0)], 0x1a1816)); // a heap of coal
  // printed flanks: a brass band along the top, riveted seams, the road's initials in gold on a red panel
  sides(g, 2.6, 1.2, 0.81, 0.65, '#2a2624', (d) => {
    d.layer(() => { d.rect(-1.3, 1.02, 1.3, 1.2, '#c8a040'); d.rect(-1.3, 0, 1.3, 0.1, '#1a1614'); });
    d.layer(() => { d.round(-0.85, 0.3, 0.85, 0.82, '#8e3a2c', 0.1); });
    d.text('O. & W.', 0, 0.56, 50, '#ecc868');
    for (const x of [-1.15, -0.95, 0.95, 1.15]) for (let y = 0.22; y < 1; y += 0.18) d.dot(x, y, 4, '#7a6a58');
    for (let x = -1.2; x <= 1.21; x += 0.2) d.dot(x, 1.11, 3.5, '#7a5a20');
  }, 1520);
  const w = []; for (const z of [-0.8, 0.8]) for (const x of [-0.78, 0.78]) w.push(wheel(0.36, x, 0.36, z)); g.add(part(w, 0xb5473a));
  return g;
}
function coach(lettering) {
  const g = new THREE.Group(); g.userData.len = 6.2;
  g.add(part([box(1.8, 1.6, 6.0, 0, 1.55, 0)], 0x4a6a4a)); // green body
  g.add(part([box(2.0, 0.14, 6.3, 0, 2.42, 0), box(1.2, 0.3, 5.8, 0, 2.6, 0)], 0x3a2e26)); // the clerestory roof
  g.add(part([box(1.5, 0.35, 5.6, 0, 0.6, 0)], 0x2a2624));
  // the open back platform a passenger rides on: a plank deck with a little iron railing round it
  g.add(part([box(1.7, 0.1, 0.8, 0, 0.78, -3.4)], 0x6a4a30));
  g.add(part([box(1.7, 0.05, 0.05, 0, 1.75, -3.78), box(0.05, 0.05, 0.8, -0.83, 1.75, -3.4), box(0.05, 0.05, 0.8, 0.83, 1.75, -3.4), box(0.05, 1.0, 0.05, -0.83, 1.28, -3.78), box(0.05, 1.0, 0.05, 0.83, 1.28, -3.78)], 0x2a2624));
  const w = []; for (const z of [-2.2, -1.6, 1.6, 2.2]) for (const x of [-0.78, 0.78]) w.push(wheel(0.32, x, 0.32, z)); g.add(part(w, 0x2a2624));
  // printed flanks: a beadboard wainscot under a gold pinstripe, a letterboard, a row of arched lamp-lit windows
  // between fluted pilasters, and the road's name in gold
  sides(g, 6.0, 1.6, 0.915, 0.75, '#4a6a4a', (d) => {
    d.layer(() => { d.rect(-3, 0, 3, 0.62, '#3c5a3e'); d.rect(-3, 1.5, 3, 1.6, '#34503a'); });
    for (let x = -2.9; x < 3; x += 0.16) d.line(x, 0.06, x, 0.56, 'rgba(30,48,32,0.55)', 2.5);
    d.line(-2.95, 0.64, 2.95, 0.64, '#d8b050', 3); d.line(-2.95, 0.04, 2.95, 0.04, '#d8b050', 2);
    d.layer(() => { d.rect(-2.2, 0.16, 2.2, 0.48, '#2e4632'); });
    d.text(lettering, 0, 0.32, 40, '#ecc868');
    d.layer(() => { for (let i = -2; i <= 2; i++) { const x = i * 1.1; d.round(x - 0.36, 0.78, x + 0.36, 1.38, '#2a2016', 0.22); d.round(x - 0.29, 0.83, x + 0.29, 1.33, '#f2d48e', 0.18); d.rect(x - 0.29, 1.04, x + 0.29, 1.08, '#2a2016'); } });
    for (let i = -2; i <= 2; i++) { const x = i * 1.1; d.rect(x - 0.24, 0.86, x - 0.06, 1.0, 'rgba(255,248,220,0.5)'); }
    for (const x of [-2.75, -1.65, -0.55, 0.55, 1.65, 2.75]) { d.layer(() => d.rect(x - 0.07, 0.7, x + 0.07, 1.46, '#587a58')); d.dot(x, 1.42, 5, '#d8b050'); }
  }, 1400);
  return g;
}
function boxcar() {
  const g = new THREE.Group(); g.userData.len = 5.6;
  g.add(part([box(1.8, 1.8, 5.4, 0, 1.65, 0)], 0x9a4a32));
  g.add(part([box(1.95, 0.12, 5.6, 0, 2.6, 0), box(1.5, 0.35, 5.0, 0, 0.6, 0)], 0x3a2e26));
  // printed flanks: upright boards, a dark frame with diagonal braces, a sliding door on its rail with a Z brace,
  // and the road's initials and the car number stencilled in cream
  sides(g, 5.4, 1.8, 0.915, 0.75, '#9a4a32', (d) => {
    for (let x = -2.6; x < 2.7; x += 0.18) d.line(x, 0.08, x, 1.72, 'rgba(70,28,16,0.5)', 2.5);
    d.layer(() => { d.rect(-2.7, 1.66, 2.7, 1.8, '#5e2a1c'); d.rect(-2.7, 0, 2.7, 0.14, '#5e2a1c'); for (const x of [-2.62, -0.8, 0.8, 2.62]) d.rect(x - 0.08, 0, x + 0.08, 1.8, '#5e2a1c'); });
    d.layer(() => { d.line(-2.54, 0.14, -0.88, 1.66, '#6a301e', 9); d.line(2.54, 0.14, 0.88, 1.66, '#6a301e', 9); });
    d.layer(() => { d.rect(-0.7, 0.12, 0.7, 1.58, '#843c28'); d.rect(-0.78, 1.6, 0.78, 1.66, '#2a2624'); });
    for (let x = -0.6; x < 0.7; x += 0.2) d.line(x, 0.16, x, 1.54, 'rgba(60,24,14,0.45)', 2);
    d.layer(() => { d.line(-0.66, 0.2, 0.66, 0.2, '#5e2a1c', 8); d.line(-0.66, 1.5, 0.66, 1.5, '#5e2a1c', 8); d.line(-0.6, 0.22, 0.6, 1.48, '#5e2a1c', 8); d.dot(0.52, 0.85, 7, '#2a2624'); });
    d.text('O. & W.', -1.7, 1.15, 46, '#efe2c4'); d.text('No. 1871', 1.7, 1.15, 38, '#efe2c4');
    d.text('CAPY 40000', -1.7, 0.55, 22, '#e2d2b0');
  }, 1460);
  const w = []; for (const z of [-2.0, -1.4, 1.4, 2.0]) for (const x of [-0.78, 0.78]) w.push(wheel(0.32, x, 0.32, z)); g.add(part(w, 0x2a2624));
  return g;
}

export class Train {
  constructor(scene, railroad) {
    this.rr = railroad; this.scene = scene;
    this.cars = [locomotive(), tender(), boxcar(), coach('OVERLAND & WESTERN')]; // (the coach last: its back platform open to the line behind, for a passenger to stand on)
    this.group = new THREE.Group(); for (const c of this.cars) this.group.add(c); this.group.visible = false; scene.add(this.group);
    // where along the line (metres) each whistle-stop's platform lies
    const P = railroad.path;
    this.stopS = railroad.stops.map((s) => { const k = P.reduce((bi, p, j) => (p.distanceTo(s.stand || s.at) < P[bi].distanceTo(s.stand || s.at) ? j : bi), 0); return k * TIE; });
    this.end = (P.length - 1) * TIE;
    this.s = 0; this.dir = 1; this.state = 'home'; this.wait = 0; this.stopI = 0; this.ran = -1;
    // smoke from the stack: soft cream paper puffs, one instanced mesh
    const puff = Array.from({ length: 18 }, (_, i) => { const a = (i / 18) * Math.PI * 2, r = 0.42 + 0.1 * Math.abs(Math.sin(a * 2.5)); return [Math.cos(a) * r, Math.sin(a) * r * 0.85]; });
    const shape = new THREE.Shape(puff.map(([x, y]) => new THREE.Vector2(x, y)));
    this.puffs = new THREE.InstancedMesh(new THREE.ShapeGeometry(shape), paperMaterial({ color: 0xe8e0d0, emissive: 0xd8c8a8, emissiveIntensity: 0.3, side: THREE.DoubleSide }), 24);
    this.puffs.frustumCulled = false; this.puffs.count = 0; scene.add(this.puffs);
    this.pp = Array.from({ length: 24 }, () => ({ age: 9, x: 0, y: 0, z: 0, s: 1 })); this.pn = 0; this.pacc = 0;
    this.onWhistle = null; this.onChuff = null; this.chuffAcc = 0;
  }

  /** Point and heading at distance s along the line. */
  at(s) {
    const P = this.rr.path, f = Math.max(0, Math.min(P.length - 1.001, s / TIE)), i = Math.floor(f), t = f - i, a = P[i], b = P[i + 1];
    const x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t;
    const y = isWater(x, z) ? 0.55 : getHeight(x, z) + 0.04;
    return { x, y, z, yaw: Math.atan2(b.x - a.x, b.z - a.z) };
  }

  /** Where she's standing for passengers, if she is: at the depot (home) or a whistle-stop (dwelling there). */
  stoppedAt() {
    if (!this.rr.built) return null;
    if (this.state === 'home') return { name: 'Paydirt Hollow', platform: this.rr.depotGroup ? this.rr.depotGroup.localToWorld(new THREE.Vector3(-2, 0.3, 3.4)) : this.rr.depot.clone(), depot: true };
    if (this.state === 'dwell' && this.atStop >= 0) { const s = this.rr.stops[this.atStop]; return { name: s.name, platform: s.platform.clone() }; }
    return null;
  }
  /** The coach's back platform, where a passenger stands to ride. */
  ridePoint(out) { const c = this.cars[3]; return c.localToWorld(out.set(0.35, 0.83, -3.35)); } // (on the back platform, by the railing)
  /** The next stop she'll draw up at, by name (for the passenger). */
  nextStopName() {
    const order = this.stopS.map((s, i) => [s, i]).filter(([s]) => (this.dir > 0 ? s > this.s + 0.05 : s < this.s - 0.05)).sort((a, b) => (this.dir > 0 ? a[0] - b[0] : b[0] - a[0]));
    return order.length ? this.rr.stops[order[0][1]].name : 'Paydirt Hollow';
  }
  /** All aboard from the depot: she leaves straight away (a passenger needn't wait for the timetable). */
  depart() { if (this.state === 'home') { this.state = 'run'; this.dir = 1; this.stopI = 0; this.onWhistle?.(this.at(this.s)); this.onDepart?.(); } else if (this.state === 'dwell') this.wait = Math.min(this.wait, 2.5); }
  update(dt, clock, camera, player) {
    if (!this.rr.built) { this.group.visible = false; return; }
    // the timetable: away from the depot at each run's hour, out to the end of the line stop by stop, and home again
    if (this.state === 'home') {
      const run = RUNS.findIndex((t) => clock > t && clock < t + 0.08);
      if (run >= 0 && this.ran !== run) { this.ran = run; this.state = 'run'; this.dir = 1; this.stopI = 0; this.onWhistle?.(this.at(this.s)); this.onDepart?.(); }
      if (run < 0) this.ran = -1;
    }
    let moving = false;
    if (this.state === 'run') {
      const order = this.dir > 0 ? this.stopS.map((s, i) => [s, i]).sort((a, b) => a[0] - b[0]) : this.stopS.map((s, i) => [s, i]).sort((a, b) => b[0] - a[0]);
      const next = order.find(([s]) => (this.dir > 0 ? s > this.s + 0.05 : s < this.s - 0.05)); // (the stop she has just left drops out; the one ahead stays till she reaches it)
      const target = next ? next[0] : this.dir > 0 ? this.end : 0;
      const d = Math.abs(target - this.s), v = Math.min(SPEED, 0.6 + d * 0.5); // (easing into each stop)
      if (d < 0.3) {
        this.s = target;
        if (!next && this.dir < 0) { this.state = 'home'; } // home at the depot
        else if (!next) { this.dir = -1; this.state = 'dwell'; this.wait = DWELL; } // the end of the line: back the way she came
        else { this.state = 'dwell'; this.wait = DWELL; this.atStop = next[1]; if (this.dir > 0 && next[0] >= this.end - 0.5) this.dir = -1; } // (a stop at the very end of the line: she turns back from there)
      } else { this.s += Math.sign(target - this.s) * v * dt; moving = true; }
    } else if (this.state === 'dwell' && (this.wait -= dt) <= 0) { this.state = 'run'; this.atStop = -1; this.onWhistle?.(this.at(this.s)); }
    // place the cars along the line, coupled one behind another (behind = the way she's come from)
    const cp = camera.position, head = this.at(this.s), far = Math.hypot(cp.x - head.x, cp.z - head.z) > 170;
    this.group.visible = !far;
    if (!far) {
      let off = 0;
      for (const [i, c] of this.cars.entries()) {
        const half = c.userData.len / 2; off += i ? half : 0;
        const p = this.at(this.s - this.dir * off), q = this.at(this.s - this.dir * (off + 0.5));
        c.position.set(p.x, p.y, p.z); c.rotation.set(0, Math.atan2(p.x - q.x, p.z - q.z), 0);
        off += half + CAR_GAP;
      }
      if (player && moving && !this.passenger) { // she won't run a man down: anyone on the track is nudged off it
        for (const c of this.cars) { const dx = player.pos.x - c.position.x, dz = player.pos.z - c.position.z, d = Math.hypot(dx, dz); if (d < 1.9 && d > 0.01) { player.pos.x += (dx / d) * (1.9 - d); player.pos.z += (dz / d) * (1.9 - d); } }
      }
    }
    // smoke and chuff while she runs (and a lazy wisp while she stands)
    const L = this.cars[0], stack = L.localToWorld(_p.set(0, 3.0, 1.6)).clone();
    this.pacc += dt * (moving ? 6 : 0.8);
    while (this.pacc >= 1) { this.pacc -= 1; Object.assign(this.pp[this.pn], { age: 0, x: stack.x, y: stack.y, z: stack.z, s: 0.35 + Math.random() * 0.25 }); this.pn = (this.pn + 1) % this.pp.length; }
    let n = 0;
    for (const P of this.pp) {
      if (P.age > 2.6) continue; P.age += dt; const k = P.age / 2.6;
      P.y += dt * (1.2 - k * 0.6); P.x += dt * 0.5; // (drifting up and off with the breeze)
      const sc = P.s * (0.6 + k * 1.6) * (k < 0.1 ? k / 0.1 : 1) * (1 - k * k);
      _q.setFromEuler(_e.set(0, Math.atan2(camera.position.x - P.x, camera.position.z - P.z), 0));
      this.puffs.setMatrixAt(n++, _m.compose(_p.set(P.x, P.y, P.z), _q, _s.setScalar(Math.max(0.001, sc))));
    }
    this.puffs.count = far ? 0 : n; if (n) this.puffs.instanceMatrix.needsUpdate = true;
    if (moving && !far) { this.chuffAcc += dt * (1.2 + Math.min(SPEED, 6) * 0.6); if (this.chuffAcc >= 1) { this.chuffAcc = 0; this.onChuff?.(head); } }
  }

  save() { return { s: this.s, dir: this.dir, state: this.state, stopI: this.stopI }; }
}
