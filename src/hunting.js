// Hunting: with the hunting bow in hand, a click looses an arrow, a paper-fletched ash shaft that flies a shallow
// arc. It finds the deer you are facing (within ~32 m and a few degrees, leading a running one a little), so a
// steady shot lands; a miss thunks into a tree trunk or a rock in its way, or the turf, and quivers there a while. A struck deer folds down flat on the page like a pop-up
// closing, and when you walk up you dress it for venison and a hide. Only the deer of the woods and meadows;
// the farm's animals, rabbits and the bison herd are never targets.
import * as THREE from 'three/webgpu';
import { paperMaterial } from './materials.js';
import { getHeight, RESOURCE_TYPES } from './world.js';

const SPEED = 26, G = 9.8, RANGE = 32, CONE = 0.26;
// what stops an arrow, and how high it stands (m per unit of scale): trunks run up into the crown, rocks are low
const TRUNKS = new Set(['pine', 'maple', 'snag', 'birch', 'goldtree', 'sagetree', 'appletree']);
const ROCKS = new Set(['rock', 'ore', 'quartz', 'silver', 'geode', 'amber']);
const _q0 = new THREE.Quaternion(), _ax = new THREE.Vector3(1, 0, 0), _rp = new THREE.Vector3(), _ad = new THREE.Vector3(), _ndc = new THREE.Vector2(), _ray = new THREE.Raycaster();
const _ad0 = new THREE.Vector3();
const RET_Y = 0.2; // (the reticle's height on screen, in NDC: a little above the middle, where Jim stands)
let _ret = null;
function ret() {
  if (_ret) return _ret;
  const st = document.createElement('style');
  st.textContent = '#reticle{position:fixed;pointer-events:none;transform:translate(-50%,-50%);z-index:40;display:none;filter:drop-shadow(1px 2px 1px rgba(60,40,20,.35))}' +
    '#reticle .ring{stroke:#efe2c4;stroke-width:5}#reticle .ink{stroke:#4a3426;stroke-width:2;fill:none}#reticle .fill{stroke:#a8352a;stroke-width:6;fill:none;stroke-linecap:round}' +
    '#reticle.on .ring{stroke:#f0c048}#reticle.on .fill{stroke:#d89a20}' +
    '#reticle.blocked .ring{stroke:#a89a86}#reticle.blocked .fill{stroke:#7a6a58}#reticle .cross{display:none;stroke:#7a3a2a;stroke-width:5;stroke-linecap:round}#reticle.blocked .cross{display:inline}';
  document.head.appendChild(st);
  _ret = document.createElement('div'); _ret.id = 'reticle';
  _ret.innerHTML = '<svg viewBox="-50 -50 100 100" width="100%" height="100%"><circle class="ring" r="34" fill="none"/><circle class="ink" r="37"/><circle class="ink" r="31"/>' +
    '<path class="ink" d="M0 -46 V-26 M0 26 V46 M-46 0 H-26 M26 0 H46" style="stroke-width:3"/><circle r="3" fill="#4a3426"/><path class="cross" d="M-12 -12 L12 12 M12 -12 L-12 12"/>' +
    '<circle class="fill" r="46" transform="rotate(-90)" stroke-dasharray="0 400"/></svg>';
  document.body.appendChild(_ret);
  return _ret;
}
const mat = (hex) => paperMaterial({ color: hex, flatShading: true, side: THREE.DoubleSide });

function arrowMesh() {
  const g = new THREE.Group();
  const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.8, 5).rotateX(Math.PI / 2), mat(0xc8a46e)); g.add(shaft);
  const head = new THREE.Mesh(new THREE.ConeGeometry(0.03, 0.09, 4).rotateX(Math.PI / 2).translate(0, 0, 0.44), mat(0x6e6a64)); g.add(head);
  // fletching: two crossed paper vanes, barn red and cream
  const vane = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0, 0, -0.38), new THREE.Vector3(0, 0.05, -0.36), new THREE.Vector3(0, 0, -0.22)]);
  vane.setIndex([0, 1, 2]); vane.computeVertexNormals();
  for (let i = 0; i < 4; i++) { const v = new THREE.Mesh(vane, mat(i % 2 ? 0xefe2c4 : 0xa8352a)); v.rotation.z = (i * Math.PI) / 2; g.add(v); }
  g.traverse((o) => { if (o.isMesh) o.castShadow = true; });
  return g;
}

// what's in hand: how long it takes to draw or raise, how far it carries (range0 + range1 x draw), its spread, how
// fast the shot flies, and what a hit does to a man (dmg; the warriors stand 9)
export const BOW = { draw: 0.9, range0: 12, range1: 26, spread: 0.07, speed0: 13, speed1: 15, dmg: 6 };
export const REVOLVER = { draw: 0.35, range0: 18, range1: 14, spread: 0.05, speed0: 70, speed1: 20, dmg: 5, bullet: true }; // (quick to raise, good to thirty paces)
export const RIFLE = { draw: 1.1, range0: 30, range1: 45, spread: 0.06, speed0: 90, speed1: 50, dmg: 12, bullet: true }; // (slow to settle, reaches across a valley, drops a man)
/** A bullet: a little lead slug with a pale streak behind it, so you can see the shot go. */
function bulletMesh() {
  const g = new THREE.Group();
  const slug = new THREE.Mesh(new THREE.SphereGeometry(0.035, 6, 4), new THREE.MeshBasicNodeMaterial({ color: 0x4a4a4e })); g.add(slug);
  const streak = new THREE.Mesh(new THREE.CylinderGeometry(0.008, 0.02, 0.9, 4).rotateX(Math.PI / 2).translate(0, 0, -0.45), new THREE.MeshBasicNodeMaterial({ color: 0xf2e8d0, transparent: true, opacity: 0.55 })); g.add(streak);
  return g;
}

// Powder smoke: a gunshot coughs out a little cloud of torn cream paper, three lobed scraps that billow out ahead of
// the muzzle, drift up and turn slowly as they go, then thin away. Six puffs' worth are cut once and reused.
let _puffGeo = null;
function puffGeo() {
  if (_puffGeo) return _puffGeo;
  const s = new THREE.Shape(), n = 9;
  for (let i = 0; i <= n; i++) { // a cloud: lobes round a circle, each a little bump of torn paper
    const a = (i / n) * Math.PI * 2, r = 0.22 + (i % 2 ? 0.05 : 0.0) + Math.sin(i * 2.3) * 0.02;
    const x = Math.cos(a) * r, y = Math.sin(a) * r * 0.8;
    if (!i) s.moveTo(x, y); else { const am = a - Math.PI / n; s.quadraticCurveTo(Math.cos(am) * (r + 0.09), Math.sin(am) * (r + 0.09) * 0.8, x, y); }
  }
  return (_puffGeo = new THREE.ShapeGeometry(s, 3));
}

// the wild game you can bring down: where to aim (chest height h), how wide it is to an arrow (r, hit), how tall
// (top), and how much it takes (hp: the arrow does 6, the six-shooter 5, the rifle 12). Never the farm animals.
const GAME = { deer: { r: 0.55, h: 0.8, hit: 0.75, top: 1.6, hp: 1 }, rabbit: { r: 0.32, h: 0.25, hit: 0.38, top: 0.55, hp: 1 }, bison: { r: 1.0, h: 1.0, hit: 1.15, top: 2.1, hp: 12 }, turkey: { r: 0.4, h: 0.45, hit: 0.5, top: 0.95, hp: 1 } };

export class Hunting {
  constructor(scene) {
    this.scene = scene; this.arrows = []; this.cool = 0; this.puffs = [];
    this.onHit = null; // (deer) => void
    this.onThunk = null; // () => void, an arrow striking wood or stone
  }

  /**
   * Drawing the bow (hold the mouse button), the way bows work in most games: the draw fills over about a second and
   * a paper reticle stands fixed on the screen a little above Jim. Pan the camera with the mouse (left, right, up and
   * down) to bring it onto your quarry; it never sticks to anything. It starts wide and tightens as you draw (the
   * spread of the shot), and turns gold while a deer is under it in range with a clear line (grey with a cross when
   * something is in the way). Let go and the arrow flies to whatever is under the reticle.
   */
  aim(dt, camera, from, critters, canvas, world = null, W = BOW) {
    this.charge = Math.min(1, (this.charge || 0) + dt / W.draw);
    const k = this.charge, range = W.range0 + W.range1 * k, spread = W.spread * (1 - k) + 0.008; // (radians: wide at first, then steady)
    this.cam = camera; _ray.setFromCamera(_ndc.set(0, RET_Y), camera);
    const o = _ray.ray.origin, d = _ray.ray.direction;
    // the deer under the reticle: nearest along the ray whose chest the ray (widened by the spread) passes through
    let best = null, bt = Infinity;
    for (const c of critters.list) {
      const g = GAME[c.type]; if (!g || c.state === 'down' || !c.mesh.visible) continue;
      if (Math.hypot(c.pos.x - from.x, c.pos.z - from.z) > range) continue;
      c.aimY = g.h * c.scale; _rp.set(c.pos.x, c.pos.y + c.aimY, c.pos.z).sub(o);
      const t = _rp.dot(d); if (t <= 0) continue;
      const miss = _rp.addScaledVector(d, -t).length();
      if (miss < g.r * c.scale + spread * t && t < bt) { bt = t; best = c; }
    }
    // a warrior under it, once it's a fight (aimed at his chest, or at the rider's on horseback)
    for (const t of this.targets?.() || []) {
      if (Math.hypot(t.pos.x - from.x, t.pos.z - from.z) > range) continue;
      const sc = t.h / 1.15; _rp.set(t.pos.x, t.pos.y + 0.8 * sc, t.pos.z).sub(o);
      const tt = _rp.dot(d); if (tt <= 0 || tt >= bt) continue;
      if (_rp.addScaledVector(d, -tt).length() < t.r + spread * tt) { bt = tt; best = { pos: t.pos, dir: _ad0, speed: 0, scale: sc, state: '', mesh: { visible: true } }; }
    }
    this.blocked = !!best && !!world && this.covered(from, best, world);
    this.target = this.blocked ? null : best;
    // where the reticle meets the ground (for a shot at nothing): march along the ray to the terrain
    this.groundAt = null;
    for (let t = 1; t < 90; t += 0.6) { const x = o.x + d.x * t, y = o.y + d.y * t, z = o.z + d.z * t; if (y <= getHeight(x, z)) { this.groundAt = new THREE.Vector3(x, getHeight(x, z), z); break; } }
    this.aimDir = _ad.set(d.x, 0, d.z).normalize();
    const r = canvas.getBoundingClientRect(), R = ret(), size = Math.round(84 - 52 * k);
    R.style.display = 'block'; R.style.left = r.left + r.width / 2 + 'px'; R.style.top = r.top + (1 - RET_Y) / 2 * r.height + 'px'; R.style.width = R.style.height = size + 'px';
    R.classList.toggle('on', !!this.target); R.classList.toggle('blocked', this.blocked);
    R.querySelector('.fill').setAttribute('stroke-dasharray', `${(k * 289).toFixed(1)} 400`);
  }

  /** Let go: the arrow flies to what's under the reticle: the deer if one is, else the ground there (as far as the draw carries). */
  loose(from, W = BOW) {
    const k = this.charge || 0, target = this.target, ground = this.groundAt, dir = this.aimDir;
    this.charge = 0; this.target = null; if (_ret) _ret.style.display = 'none';
    if (k < 0.18 || !dir) return false; // (barely drawn: you ease the string back)
    const speed = W.speed0 + W.speed1 * k, range = W.range0 + W.range1 * k, vel = new THREE.Vector3();
    let to = null;
    if (target) { const t0 = Math.hypot(target.pos.x - from.x, target.pos.z - from.z) / speed; to = _rp.set(target.pos.x + target.dir.x * target.speed * t0, target.pos.y + (target.aimY ?? 0.8 * target.scale), target.pos.z + target.dir.z * target.speed * t0); }
    else if (ground) {
      to = _rp.copy(ground);
      const dd = Math.hypot(to.x - from.x, to.z - from.z);
      if (dd > range) { to.x = from.x + (to.x - from.x) * range / dd; to.z = from.z + (to.z - from.z) * range / dd; to.y = getHeight(to.x, to.z); } // (short of the mark: the draw only carries so far)
    }
    if (to) {
      vel.set(to.x - from.x, 0, to.z - from.z); const t = Math.max(0.08, vel.length() / speed);
      vel.normalize().multiplyScalar(speed); vel.y = (to.y - from.y) / t + 0.5 * G * t;
    } else { vel.copy(dir).multiplyScalar(speed); vel.y = 2 + 3 * k; } // (aimed at the sky: off it goes in a long arc)
    const mesh = W.bullet ? bulletMesh() : arrowMesh(); mesh.position.copy(from); this.scene.add(mesh);
    if (W.bullet) this.puff(from, vel, W.dmg > 8 ? 1.4 : 1);
    this.arrows.push({ mesh, vel, age: 0, stuck: false, aim: target, bullet: !!W.bullet, dmg: W.dmg });
    return true;
  }

  /** A cough of powder smoke at the muzzle (`big` for the rifle). */
  puff(from, vel, big = 1) {
    const dir = _rp.copy(vel).setY(0).normalize();
    for (let k = 0; k < 3; k++) {
      let p = this.puffs.find((q) => q.age >= q.life);
      if (!p) {
        if (this.puffs.length >= 18) return;
        const mat = new THREE.MeshBasicNodeMaterial({ color: [0xe6dcc4, 0xd8ccb2, 0xcbc0a8][this.puffs.length % 3], transparent: true, side: THREE.DoubleSide, depthWrite: false });
        p = { mesh: new THREE.Mesh(puffGeo(), mat), vel: new THREE.Vector3(), age: 0, life: 0 }; this.puffs.push(p); this.scene.add(p.mesh);
        // its cut edge: the same scrap a hair bigger in warm brown, just behind it, so it reads as torn paper, not a glow
        p.rim = new THREE.Mesh(puffGeo(), new THREE.MeshBasicNodeMaterial({ color: 0x8a7458, transparent: true, side: THREE.DoubleSide, depthWrite: false }));
        p.rim.scale.setScalar(1.07); p.rim.position.z = -0.006; p.rim.renderOrder = -1; p.mesh.add(p.rim);
      }
      const f = 0.35 + k * 0.32;
      p.mesh.position.copy(from).addScaledVector(dir, f); p.mesh.position.y += (Math.random() - 0.5) * 0.1;
      p.vel.copy(dir).multiplyScalar((1.6 - k * 0.35) * big); p.vel.y = 0.35 + Math.random() * 0.25; p.vel.x += (Math.random() - 0.5) * 0.3; p.vel.z += (Math.random() - 0.5) * 0.3;
      p.age = 0; p.life = (0.9 + Math.random() * 0.4) * big; p.spin = (Math.random() - 0.5) * 1.6; p.size = (0.8 + k * 0.25) * big;
      p.mesh.scale.setScalar(p.size); p.mesh.material.opacity = 0.92; p.mesh.visible = true; p.roll = Math.random() * 6.28;
    }
  }

  /** Stop drawing without loosing (the bow put away, a menu opened). */
  ease() { this.charge = 0; this.target = null; if (_ret) _ret.style.display = 'none'; }

  /** Is there a trunk, rock or wall between `from` and the deer (on the flat, below the arrow's height)? */
  covered(from, deer, world) {
    const ax = from.x, az = from.z, bx = deer.pos.x, bz = deer.pos.z, dx = bx - ax, dz = bz - az, L = Math.hypot(dx, dz);
    if (L < 1) return false;
    const segd = (x, z) => { const t = Math.max(0, Math.min(1, ((x - ax) * dx + (z - az) * dz) / (L * L))); return Math.hypot(ax + dx * t - x, az + dz * t - z); };
    const near = (x, z) => Math.hypot(x - bx, z - bz) < 0.9; // (not the ground the deer itself stands on)
    for (const r of world.resourcesNear((ax + bx) / 2, (az + bz) / 2, L / 2 + 1)) {
      if (!TRUNKS.has(r.type) && !ROCKS.has(r.type)) continue;
      if (!near(r.x, r.z) && segd(r.x, r.z) < RESOURCE_TYPES[r.type].radius * r.scale * (TRUNKS.has(r.type) ? 0.7 : 0.85) + 0.05) return true;
    }
    for (const c of world.colliders) if (!near(c.x, c.z) && Math.abs(c.x - ax - dx / 2) < L / 2 + c.r && Math.abs(c.z - az - dz / 2) < L / 2 + c.r && segd(c.x, c.z) < c.r) return true;
    return false;
  }

  stick(a) { a.stuck = true; a.age = 0; a.still = false; a.rest = a.mesh.quaternion.clone(); }

  strike(a, world) {
    const p = a.mesh.position, gy = getHeight(p.x, p.z);
    for (const r of world.resourcesNear(p.x, p.z, 0.1)) {
      const tall = TRUNKS.has(r.type) ? 7 : ROCKS.has(r.type) ? 1.3 : 0;
      if (!tall || p.y - gy > tall * r.scale) continue;
      if (this.bury(a, r.x, r.z, RESOURCE_TYPES[r.type].radius * r.scale * (TRUNKS.has(r.type) ? 0.7 : 0.85))) return true;
    }
    for (const c of world.colliders) {
      if ((c.x - p.x) ** 2 + (c.z - p.z) ** 2 > (c.r + 0.1) ** 2 || p.y - gy > 3) continue;
      if (this.bury(a, c.x, c.z, c.r)) return true;
    }
    return false;
  }

  /** Set the arrow on the circle of radius r round (x, z), its tip a little inside, and stick it there. */
  bury(a, x, z, r) {
    const p = a.mesh.position, dx = p.x - x, dz = p.z - z, d = Math.hypot(dx, dz);
    if (d > r || d < 1e-4) return false;
    const out = r + 0.3; // (the arrow's middle sits outside the bark; its head is in)
    p.x = x + (dx / d) * out; p.z = z + (dz / d) * out;
    this.stick(a); this.onThunk?.(); return true;
  }

  update(dt, critters, world = null) {
    this.cool = Math.max(0, this.cool - dt);
    for (const p of this.puffs) { // the powder smoke: billowing out, slowing, rising, turning, thinning away
      if (p.age >= p.life) continue;
      p.age += dt; const k = p.age / p.life, m = p.mesh;
      if (k >= 1) { m.visible = false; continue; }
      p.vel.x *= Math.exp(-dt * 3); p.vel.z *= Math.exp(-dt * 3); p.vel.y += dt * 0.3;
      m.position.addScaledVector(p.vel, dt);
      if (this.cam) m.quaternion.copy(this.cam.quaternion); // (faces the lens, like a card held up)
      p.roll += p.spin * dt; m.rotateZ(p.roll);
      m.material.opacity = 0.92 * (k < 0.55 ? 1 : 1 - (k - 0.55) / 0.45); p.rim.material.opacity = m.material.opacity * 0.8;
    }
    for (let i = this.arrows.length - 1; i >= 0; i--) {
      const a = this.arrows[i], p = a.mesh.position;
      a.age += dt;
      if (a.stuck) { // it quivers a moment where it struck, then stands still till it's gone
        if (a.age < 0.6) a.mesh.quaternion.copy(a.rest).multiply(_q0.setFromAxisAngle(_ax, Math.sin(a.age * 55) * 0.09 * (1 - a.age / 0.6)));
        else if (!a.still) { a.still = true; a.mesh.quaternion.copy(a.rest); }
        if (a.age > 8) { this.scene.remove(a.mesh); this.arrows.splice(i, 1); }
        continue;
      }
      a.vel.y -= G * dt;
      // in steps of a few hand-widths, so it can't skip clean through a slim birch between frames
      const n = Math.max(1, Math.ceil((a.vel.length() * dt) / 0.18));
      let hit = false;
      let struck = null;
      for (let k = 0; k < n && !hit && !struck; k++) {
        p.addScaledVector(a.vel, dt / n);
        for (const t of this.targets?.() || []) { const dx = t.pos.x - p.x, dz = t.pos.z - p.z, dy = p.y - t.pos.y; if (dx * dx + dz * dz < t.r * t.r && dy > 0.2 && dy < t.h) { struck = t; break; } } // (a warrior in the way is struck before anything behind him)
        if (!struck && world) hit = this.strike(a, world);
      }
      if (struck) { this.onTarget?.(struck, a); this.scene.remove(a.mesh); this.arrows.splice(i, 1); continue; }
      if (hit && a.bullet) { this.scene.remove(a.mesh); this.arrows.splice(i, 1); continue; } // (a bullet: a chip of bark or a spark off the rock, and gone)
      if (hit) { a.mesh.lookAt(p.x + a.vel.x, p.y + a.vel.y, p.z + a.vel.z); a.rest.copy(a.mesh.quaternion); continue; }
      a.mesh.lookAt(p.x + a.vel.x, p.y + a.vel.y, p.z + a.vel.z);
      // a deer in its path (any deer, not only the one it was aimed at)
      for (const c of critters.list) {
        const g = GAME[c.type]; if (!g || c.state === 'down') continue;
        const dx = c.pos.x - p.x, dz = c.pos.z - p.z, dy = p.y - c.pos.y;
        if (dx * dx + dz * dz < (g.hit * c.scale) ** 2 && dy > 0.05 && dy < g.top * c.scale) {
          c.hp = (c.hp ?? g.hp) - (a.dmg ?? 6);
          if (c.hp > 0) { c.state = 'flee'; c.timer = 4; c.dir.subVectors(c.pos, p).setY(0).normalize(); this.onWound?.(c); } // (a bison takes more than one: wounded, it lumbers off)
          else { critters.fell(c); this.onHit?.(c); }
          this.scene.remove(a.mesh); this.arrows.splice(i, 1); a.done = true; break;
        }
      }
      if (a.done) continue;
      // other targets (the warriors, once it's come to a fight): any arrow that passes through one strikes him
      for (const t of this.targets?.() || []) {
        const dx = t.pos.x - p.x, dz = t.pos.z - p.z, dy = p.y - t.pos.y;
        if (dx * dx + dz * dz < t.r * t.r && dy > 0.2 && dy < t.h) { this.onTarget?.(t, a); this.scene.remove(a.mesh); this.arrows.splice(i, 1); a.done = true; break; }
      }
      if (a.done) continue;
      const gy = getHeight(p.x, p.z);
      if (a.bullet && (p.y <= gy + 0.05 || a.age > 1.5)) { this.scene.remove(a.mesh); this.arrows.splice(i, 1); continue; } // (a bullet kicks up the dirt and is gone)
      if (p.y <= gy + 0.05 || a.age > 2.5) { // a miss: it sticks in the turf, quivering, and is gone in a while
        p.y = Math.max(p.y, gy + 0.18); this.stick(a);
      }
    }
  }
}
