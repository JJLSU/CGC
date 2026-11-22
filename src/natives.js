// The people of the valleys. Out past the home valley, in an open valley of its own, stands a camp whose land is
// marked out by painted poles (red and white bands, two feathers hanging) in a ring round it. Their warriors patrol
// the camp. The prospector is the stranger here: cross the poles and a warrior runs out to meet you, signals you to
// turn back and puts an arrow in the ground at your feet. Stay, or push on toward the camp, and they run you down
// and shoot, and fight hand to hand up close. Step back over the poles and they break off and walk home. They are
// never hunted down. Once it comes to a fight, the bowmen run to their horses and ride at you, shooting from the
// saddle; and you can fight back: your arrows and your blows wound them, and a warrior struck down falls.
import * as THREE from 'three/webgpu';
import { uniform, vec3 } from 'three/tsl';
import { paperMaterial } from './materials.js';
import { getHeight, isWater, rangeAt, regionAt } from './world.js';
import { ModelFigure, hasFolk, propModel, animalModel } from './modelfolk.js';
import { Puppet } from './puppets.js';
import { makeMesh } from './building.js';
import { mulberry32 } from './noise.js';

const R = 46;            // the camp's land: a ring of poles this far out
const mat = (hex) => paperMaterial({ color: hex, flatShading: true });
const box = (w, h, d, hex) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat(hex)); m.castShadow = true; return m; };

// after dark a fire burns low in every lodge: the hide glows warm from within, its painted bands showing through
// (one shared uniform, set from the sky each frame; no extra lights)
const uLodgeGlow = uniform(0), LODGE_MATS = new Map();
let campAbed = false; // (late at night the camp's folk are in their lodges; the warriors keep watch)
let campDay = 0; // (the game day, for gifts' peace)
export function setLodgeGlow(night, t, abed = false, day = 0) { campAbed = abed; campDay = day; uLodgeGlow.value = Math.max(0, night - 0.35) * 0.45 * (0.92 + Math.sin(t * 6.1) * 0.04 + Math.sin(t * 1.7) * 0.04); }
function lodgeLit(g) {
  g.traverse((o) => {
    if (!o.isMesh) return;
    let m = LODGE_MATS.get(o.material);
    if (!m) { m = o.material.clone(); const e = o.material.emissiveNode; m.emissiveNode = e ? e.mul(uLodgeGlow.mul(5).add(1)).add(vec3(1.0, 0.5, 0.2).mul(uLodgeGlow.mul(0.14))) : vec3(1.0, 0.55, 0.25).mul(uLodgeGlow.mul(0.5)); LODGE_MATS.set(o.material, m); LODGE_MATS.set(m, m); }
    o.material = m;
  });
  return g;
}

function markerPole(rng) {
  const g = new THREE.Group();
  const post = box(0.12, 2.3, 0.12, 0x7a5232); post.position.y = 1.15; g.add(post);
  for (const [y, hex] of [[1.7, 0xa8352a], [1.85, 0xefe2c4], [2.0, 0xa8352a], [0.9, 0x4f6680]]) { const b = box(0.15, 0.1, 0.15, hex); b.position.y = y; g.add(b); }
  for (const s of [-1, 1]) { // two feathers on thongs, cream with dark tips
    const f = new THREE.Group(); f.position.set(s * 0.09, 2.15, 0); f.rotation.z = s * (0.3 + rng() * 0.2);
    const quill = box(0.035, 0.34, 0.01, 0xefe2c4); quill.position.y = -0.2; f.add(quill);
    const tip = box(0.037, 0.08, 0.012, 0x3a2e28); tip.position.y = -0.34; f.add(tip);
    g.add(f);
  }
  return g;
}

function paperTipi(rng, painted) {
  const g = new THREE.Group();
  const cone = new THREE.Mesh(new THREE.ConeGeometry(2, 4.2, 9, 1, true), paperMaterial({ color: painted ? 0xe6d3ae : 0xd8bf92, side: THREE.DoubleSide, flatShading: true }));
  cone.position.y = 2.1; cone.castShadow = true; g.add(cone);
  for (let i = 0; i < 6; i++) { const pole = box(0.06, 1.1, 0.06, 0x6e4a2c); const a = i / 6 * Math.PI * 2; pole.position.set(Math.cos(a) * 0.12, 4.5, Math.sin(a) * 0.12); pole.rotation.set(Math.sin(a) * 0.35, 0, -Math.cos(a) * 0.35); g.add(pole); }
  const door = new THREE.Mesh(new THREE.CircleGeometry(0.55, 3, Math.PI / 2), mat(0x4a3426)); door.position.set(0, 0.62, 1.5); door.rotation.x = -0.44; g.add(door);
  if (painted) { const band = new THREE.Mesh(new THREE.CylinderGeometry(1.62, 1.84, 0.35, 9, 1, true), paperMaterial({ color: 0x4f6680, side: THREE.DoubleSide })); band.position.y = 0.75; g.add(band); }
  return g;
}

/** A model prop from the reference art if it's been made, sized to `len`; else null. */
function prop(name, len) {
  const src = propModel(name); if (!src) return null;
  const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = len / Math.max(sz.x, sz.z);
  const g = new THREE.Group(); m.position.set(-c.x * k, -bb.min.y * k, -c.z * k); m.scale.setScalar(k); g.add(m); return g;
}

function bowMesh() {
  const g = new THREE.Group();
  const stave = new THREE.Mesh(new THREE.TorusGeometry(0.62, 0.02, 5, 12, 1.4).rotateZ(Math.PI / 2 - 0.7).translate(-0.62, 0, 0), mat(0x8a5e36)); g.add(stave);
  return g;
}

function spearMesh() {
  const g = new THREE.Group();
  const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.024, 2.1, 5).rotateX(Math.PI / 2).translate(0, 0, 0.5), mat(0x9a7448)); g.add(shaft);
  const head = new THREE.Mesh(new THREE.ConeGeometry(0.05, 0.22, 4).rotateX(Math.PI / 2).translate(0, 0, 1.65), mat(0x8e8a80)); g.add(head);
  const tie = box(0.06, 0.06, 0.1, 0xa8352a); tie.position.z = 1.48; g.add(tie);
  return g;
}

function clubMesh() {
  const g = new THREE.Group();
  const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.03, 0.75, 5).rotateX(Math.PI / 2).translate(0, 0, 0.2), mat(0x8a5e36)); g.add(shaft);
  const stone = new THREE.Mesh(new THREE.DodecahedronGeometry(0.11, 0), mat(0x8a8680)); stone.scale.set(1, 0.8, 1.3); stone.position.z = 0.6; g.add(stone);
  const wrap = box(0.07, 0.07, 0.12, 0xd8c08a); wrap.position.z = 0.5; g.add(wrap);
  return g;
}

function arrowMesh() {
  const g = new THREE.Group();
  g.add(new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.8, 4).rotateX(Math.PI / 2), mat(0xc8a46e)));
  const fl = box(0.005, 0.07, 0.16, 0xa8352a); fl.position.z = -0.32; g.add(fl);
  return g;
}

const _v = new THREE.Vector3(), _sa = new THREE.Vector3(), _sb = new THREE.Vector3(), _sr = new THREE.Vector3(), _q1 = new THREE.Quaternion(), _q2 = new THREE.Quaternion(), _q3 = new THREE.Quaternion(), _a1 = new THREE.Vector3(), _a2 = new THREE.Vector3(), _f = new THREE.Vector3(), _s = new THREE.Vector3();

/** Sit a rider's hips on the middle of the horse's back, facing the way she faces. */
function seat(horse, fig) {
  const hm = horse.model; if (!hm) { fig.root.position.y += 1.05; return; }
  const B = horse.seatBones ||= ['hips', 'chest'].map((n) => hm.getObjectByName(n)), hips = fig.hipBone ||= fig.model.getObjectByName('Hips');
  if (!B[0] || !B[1] || !hips) return;
  fig.root.rotation.y = (horse.heading ?? horse.flip.rotation.y) + Math.PI / 2;
  horse.group.updateWorldMatrix(true, true); fig.root.updateWorldMatrix(true, true);
  B[0].getWorldPosition(_sa); B[1].getWorldPosition(_sb); _sa.lerp(_sb, 0.55); _sa.y += 0.32 * horse.rig.scale.x / 1.7;
  hips.getWorldPosition(_sr); fig.root.position.add(_sa.sub(_sr));
}

/** The sit clip is a chair sit: swing the thighs out over the horse's barrel and let the shins hang down her flanks. */
function aim(bone, child, dir) {
  bone.updateWorldMatrix(true, true); bone.getWorldPosition(_a1); child.getWorldPosition(_a2); _a2.sub(_a1).normalize();
  _q1.setFromUnitVectors(_a2, dir.normalize()); bone.getWorldQuaternion(_q2); bone.parent.getWorldQuaternion(_q3);
  bone.quaternion.copy(_q3.invert().multiply(_q1).multiply(_q2));
}
function astride(fig) {
  const m = fig.model, L = fig.legBones ||= [['LeftUpLeg', 'LeftLeg', 'LeftFoot'], ['RightUpLeg', 'RightLeg', 'RightFoot']].map((c) => c.map((n) => m.getObjectByName(n)));
  fig.root.updateWorldMatrix(true, true); fig.root.getWorldQuaternion(_q1);
  const fwd = _f.set(0, 0, 1).applyQuaternion(_q1).clone(), side = _s.set(1, 0, 0).applyQuaternion(_q1).clone();
  L.forEach(([up, knee, foot], i) => {
    if (!up || !knee || !foot) return; const sg = i === 0 ? 1 : -1;
    aim(up, knee, fwd.clone().multiplyScalar(0.55).addScaledVector(side, sg * 0.62).add(new THREE.Vector3(0, -0.56, 0)));
    aim(knee, foot, fwd.clone().multiplyScalar(-0.22).addScaledVector(side, sg * 0.16).add(new THREE.Vector3(0, -0.96, 0)));
  });
}

export class NativeCamp {
  constructor(scene, home, { r0 = 240, r1 = 340, seed = 5150, avoid = [], world = null } = {}) {
    this.scene = scene;
    this.group = new THREE.Group(); scene.add(this.group);
    // the site: an open valley a good ride out, clear of the mountains and the water for a good way round
    const rng = mulberry32(seed);
    let at = null;
    for (let r = r0; r <= r1 && !at; r += 20) for (let k = 0; k < 24 && !at; k++) {
      const a = (k / 24) * Math.PI * 2 + r * 0.01 + seed, x = home.x + Math.cos(a) * r, z = home.z + Math.sin(a) * r;
      if (isWater(x, z) || rangeAt(x, z) > 0.005 || avoid.some((q) => Math.hypot(q.x - x, q.z - z) < 180)) continue;
      let ok = true;
      for (let j = 0; j < 12 && ok; j++) { const b = (j / 12) * Math.PI * 2; for (const d of [14, 30]) { const xx = x + Math.cos(b) * d, zz = z + Math.sin(b) * d; if (isWater(xx, zz) || rangeAt(xx, zz) > 0.05 || regionAt(xx, zz) === 'water') ok = false; } }
      if (ok) at = new THREE.Vector3(x, getHeight(x, z), z);
    }
    this.at = at;
    this.warriors = []; this.arrows = []; this.alarm = 'none'; this.alarmT = 0; this.warned = false;
    if (!at) return;
    world?.exclusions.push({ x: at.x, z: at.z, r: 34 }); // (a clearing: the chunks are built after this, so no tree, bush or rock grows among the lodges)
    // the boundary poles
    for (let i = 0; i < 18; i++) {
      const a = (i / 18) * Math.PI * 2, x = at.x + Math.cos(a) * R, z = at.z + Math.sin(a) * R;
      if (isWater(x, z) || rangeAt(x, z) > 0.2) continue;
      const p = markerPole(rng); p.position.set(x, getHeight(x, z), z); p.rotation.y = -a; this.group.add(p);
    }
    // the camp: lodges round a cooking fire (the models from the reference art where they've been made)
    const spots = [[0, -7, 'prop_tipi', 1], [6.5, -2, 'prop_tipi_painted', 2], [-6.5, -2.5, 'prop_tipi', 3], [3.5, 6, 'prop_tipi_painted', 4], [-4, 5.5, 'prop_tipi', 5]];
    for (const [dx, dz, name, i] of spots) {
      const t = lodgeLit(prop(name, 4.4) || paperTipi(rng, name.endsWith('painted')));
      const x = at.x + dx, z = at.z + dz; t.position.set(x, getHeight(x, z), z); t.rotation.y = Math.atan2(-dx, -dz); this.group.add(t);
    }
    const fire = prop('prop_cookfire', 1.8) || makeMesh('campfire'); fire.position.set(at.x, getHeight(at.x, at.z), at.z); this.group.add(fire);
    // the horse picket: a rail between two posts on the camp's edge, the horses tied along it
    this.horses = [];
    { const pa = Math.atan2(home.z - at.z, home.x - at.x) + Math.PI * 0.6, px = at.x + Math.cos(pa) * 15, pz = at.z + Math.sin(pa) * 15, side = pa + Math.PI / 2;
      for (const k of [-1, 1]) { const post = box(0.14, 1.3, 0.14, 0x6e4a2c); post.position.set(px + Math.cos(side) * k * 4, getHeight(px, pz) + 0.65, pz + Math.sin(side) * k * 4); this.group.add(post); }
      const rail = box(8, 0.1, 0.1, 0x7a5232); rail.position.set(px, getHeight(px, pz) + 1.15, pz); rail.rotation.y = -side; this.group.add(rail);
      const model = !!animalModel('animal_horse');
      for (let i = 0; i < 3; i++) {
        const h = new Puppet('horse', model ? 1.7 : 1.25), k = (i - 1) * 2.6, hx = px + Math.cos(side) * k + Math.cos(pa) * 1.6, hz = pz + Math.sin(side) * k + Math.sin(pa) * 1.6;
        h.group.position.set(hx, getHeight(hx, hz), hz); this.group.add(h.group);
        this.horses.push({ puppet: h, picket: new THREE.Vector3(hx, 0, hz), rider: null });
      }
    }
    for (const [name, len, dx, dz] of [['prop_drying_rack', 2.4, 3, -4.5], ['prop_travois', 3, -8, 2], ['prop_drum', 0.9, 1.6, 1.4], ['prop_bedroll', 1.2, -2.2, 2.2]]) {
      const p = prop(name, len); if (!p) continue; const x = at.x + dx, z = at.z + dz; p.position.set(x, getHeight(x, z), z); p.rotation.y = rng() * 6; this.group.add(p);
    }
    // the warriors who keep it, each armed as in the reference art: the warrior with a spear and a bow, the archer
    // with his bow, the hunter with a stone-headed club (he closes in to fight)
    const kinds = [['folk_native_warrior', 'spear'], ['folk_native_archer', 'bow'], ['folk_native_hunter', 'club']].filter(([n]) => hasFolk(n));
    if (!kinds.length && hasFolk('folk_native_warrior')) kinds.push(['folk_native_warrior', 'spear']);
    kinds.forEach(([name, arm], i) => {
      const fig = new ModelFigure(name);
      if (arm !== 'club') fig.hands[0].add(bowMesh());
      if (arm === 'spear') fig.hands[1].add(spearMesh());
      if (arm === 'club') fig.hands[1].add(clubMesh());
      const a = (i / kinds.length) * Math.PI * 2, home = new THREE.Vector3(at.x + Math.cos(a) * 9, 0, at.z + Math.sin(a) * 9);
      fig.root.position.set(home.x, getHeight(home.x, home.z), home.z);
      this.group.add(fig.root);
      this.warriors.push({ fig, arm, pos: fig.root.position, home, state: 'patrol', goal: home.clone(), t: rng() * 3, cool: 0, act: null, hp: 9, horse: null, dead: 0 });
    });
    // the camp's folk: about the lodges and the fire, sitting a while by it; at the first sign of a fight they slip
    // back among the lodges. They never fight.
    this.folk = [];
    this.lodges = spots.map(([dx, dz]) => new THREE.Vector3(at.x + dx * 0.8, 0, at.z + dz * 0.8));
    for (const name of ['folk_native_woman', 'folk_native_maiden', 'folk_native_elder', 'folk_native_grandfather', 'folk_native_girl']) { // (the young woman in the green dress and the grandfather in his cape join as their models are made)
      if (!hasFolk(name)) continue;
      const fig = new ModelFigure(name), a = rng() * 6.28;
      fig.root.position.set(at.x + Math.cos(a) * 3, 0, at.z + Math.sin(a) * 3); fig.root.position.y = getHeight(fig.root.position.x, fig.root.position.z);
      this.group.add(fig.root);
      const kind = name.replace('folk_native_', '');
      if (kind === 'elder') { const staff = new THREE.Mesh(new THREE.CylinderGeometry(0.022, 0.028, 1.7, 5).rotateX(Math.PI / 2).translate(0, 0, 0.35), mat(0x8a6038)); staff.castShadow = true; fig.hands[1].add(staff); } // (her walking staff, as in the art)
      this.folk.push({ fig, kind, pos: fig.root.position, goal: fig.root.position.clone(), t: rng() * 4, sit: false, speed: kind === 'elder' ? 0.6 : kind === 'grandfather' ? 0.7 : kind === 'girl' ? 1.5 : 1.0 });
    }
  }

  /** The warriors the player can strike: { pos, r, h, w } for arrows; nearest in front within reach for blows. */
  targets() { return this.warriors.filter((w) => !w.dead).map((w) => ({ pos: w.pos, r: w.horse ? 1.1 : 0.55, h: w.horse ? 3 : 1.9, w })); }
  findTarget(player, reach) {
    const f = player.forward(_v);
    let best = null, bd = Infinity;
    for (const w of this.warriors) {
      if (w.dead) continue;
      const dx = w.pos.x - player.pos.x, dz = w.pos.z - player.pos.z, d = Math.hypot(dx, dz);
      if (d > reach + 0.8 || (d > 0.3 && (dx * f.x + dz * f.z) / d < 0.2)) continue;
      if (d < bd) { bd = d; best = w; }
    }
    return best;
  }
  /** A wound: an attack on them is a fight, wherever you stand; enough and the warrior falls. Returns true if he fell. */
  damage(w, n, hooks = {}) {
    if (w.dead) return false;
    w.hp -= n; w.hurt = 0.3; this.peaceUntil = 0; // (an attack ends any peace a gift bought)
    if (this.alarm !== 'fight') { this.alarm = 'fight'; this.alarmT = 0; this.fightAnyway = true; hooks.onFight?.(); }
    if (w.hp > 0) return false;
    w.dead = 0.001;
    if (w.horse) { w.horse.rider = null; w.horse.loose = 6; w.horse = null; }
    hooks.onFall?.(w);
    return true;
  }

  /** Is (x, z) by the camp's ring of poles (just outside it, or just inside)? Where a gift can be left. */
  atPoles(x, z) { return !!this.at && Math.abs(Math.hypot(x - this.at.x, z - this.at.z) - R) < 5; }
  /** A gift left at the poles: peace on their land for `days`. */
  gift(days) { this.peaceUntil = campDay + days; if (this.alarm !== 'fight') this.alarm = 'none'; }
  /** Is (x, z) on the camp's land? */
  onLand(x, z) { return !!this.at && Math.hypot(x - this.at.x, z - this.at.z) < R; }

  /** hooks: onWarn(), onFight(), onHit(damage), onLeave() */
  update(dt, player, camera, hooks = {}) {
    if (!this.at || !this.warriors.length) return;
    const p = player.pos, dCamp = Math.hypot(p.x - this.at.x, p.z - this.at.z);
    const near = Math.hypot(camera.position.x - this.at.x, camera.position.z - this.at.z) < 140;
    this.group.visible = near;
    // the camp's mood: a trespasser warned, then fought, then let go once they've gone
    const inside = dCamp < R && !player.dead;
    const peace = (this.peaceUntil || 0) > campDay; // (a gift left at the poles: welcome on their land for a few days)
    if (inside && this.alarm === 'none' && !peace) { this.alarm = 'warn'; this.alarmT = 0; this.warnShot = false; }
    if (this.alarm !== 'none') this.alarmT += dt;
    if (this.alarm === 'warn' && inside && this.alarmT > 7) { this.alarm = 'fight'; hooks.onFight?.(); }
    if (this.alarm === 'warn' && inside && dCamp < R * 0.55) { this.alarm = 'fight'; hooks.onFight?.(); } // (pushing on toward the lodges)
    if (this.alarm !== 'none' && (dCamp > (this.fightAnyway ? R + 40 : R + 6) || player.dead)) { if (this.alarm === 'fight') hooks.onLeave?.(); this.alarm = 'none'; this.fightAnyway = false; }
    if (!near) return;
    let warner = null;
    if (this.alarm === 'warn') warner = this.warriors.reduce((a, b) => (a.pos.distanceTo(p) < b.pos.distanceTo(p) ? a : b));
    for (const w of this.warriors) {
      w.t -= dt; w.cool -= dt;
      if (w.horse) w.pos.copy(w.horse.puppet.group.position); // (mounted, he goes where his horse stands; the seat below shifts his body onto her back each frame)
      if (w.dead) { // struck down: he folds over onto the grass, lies a while, and is gone (the camp mourns him; he's back another day)
        w.dead += dt; w.fig.root.rotation.x = -Math.min(1, w.dead / 0.6) * Math.PI / 2 * 0.95; w.fig.play('idle', 0.2); w.fig.mixer.update(0);
        w.pos.y = getHeight(w.pos.x, w.pos.z); // (thrown from the saddle: he lies on the grass, not up where he sat)
        if (w.dead > 40) { w.dead = 0; w.hp = 9; w.fig.root.rotation.x = 0; w.pos.set(w.home.x, getHeight(w.home.x, w.home.z), w.home.z); }
        continue;
      }
      // to horse: in a fight a bowman runs to his horse and mounts; when it's over he rides back to the picket
      if (this.alarm === 'fight' && w.arm !== 'club' && !w.horse) {
        const h = w.myHorse ||= this.horses.find((q) => !q.owner && (q.owner = w));
        if (h && !h.rider) { const hp = h.puppet.group.position; if (Math.hypot(hp.x - w.pos.x, hp.z - w.pos.z) < 1.6) { w.horse = h; h.rider = w; } else { w.goal.set(hp.x, 0, hp.z); w.mounting = true; } }
      } else w.mounting = false;
      if (w.horse && this.alarm !== 'fight') { const h = w.horse, pk = h.picket; if (Math.hypot(pk.x - w.pos.x, pk.z - w.pos.z) < 1) { h.rider = null; w.horse = null; w.fig.root.rotation.x = 0; } }
      const dx = p.x - w.pos.x, dz = p.z - w.pos.z, dP = Math.hypot(dx, dz);
      let speed = 0, face = null, act = null;
      if (w.mounting) { const gx = w.goal.x - w.pos.x, gz = w.goal.z - w.pos.z; face = Math.atan2(gx, gz); speed = 4.6; }
      else if (w.horse && this.alarm !== 'fight') { const pk = w.horse.picket; face = Math.atan2(pk.x - w.pos.x, pk.z - w.pos.z); speed = 3; w.goal.set(pk.x, 0, pk.z); }
      else if (w.horse) { // mounted: ride in to bowshot and circle, loosing from the saddle
        face = Math.atan2(dx, dz);
        if (dP > 14) speed = 8; else { speed = 5; face += Math.PI / 2.4; }
        if (dP < 22 && w.cool <= 0) { w.cool = 2.0; act = 'Archery_Shot'; this.shoot(w.pos, p, Math.random() < 0.5, hooks); }
      }
      else if (this.alarm === 'fight') {
        face = Math.atan2(dx, dz);
        if (w.arm === 'club' ? dP > 2.4 : dP > 16) { speed = 4.6; }
        else if (dP > 2.6) { act = 'Archery_Shot'; if (w.cool <= 0) { w.cool = 2.3; this.shoot(w.pos, p, Math.random() < 0.6, hooks); } }
        else { act = 'Attack'; if (w.cool <= 0) { w.cool = 1.5; hooks.onHit?.(w.arm === 'club' ? 12 : 10); } }
      } else if (w === warner) {
        // out to meet you, stopping a stone's throw off; a signal to turn back, then an arrow at your feet
        face = Math.atan2(dx, dz);
        if (dP > 10) speed = 4;
        else { act = this.alarmT < 4.5 ? 'wave' : 'idle'; if (!this.warnShot && this.alarmT > 3) { this.warnShot = true; this.shoot(w.pos, p, false, hooks, true); hooks.onWarn?.(); } }
      } else {
        // about the camp: from one spot to another, a pause, then on
        const g = w.goal, gx = g.x - w.pos.x, gz = g.z - w.pos.z, gd = Math.hypot(gx, gz);
        if (gd > 0.4) { speed = this.alarm === 'none' && w.pos.distanceTo(this.at) > R * 0.6 ? 2.4 : 1.2; face = Math.atan2(gx, gz); }
        else if (w.t <= 0) { const a = Math.random() * 6.28, r = 3 + Math.random() * 12; g.set(this.at.x + Math.cos(a) * r, 0, this.at.z + Math.sin(a) * r); w.t = 3 + Math.random() * 6; }
      }
      if (speed > 0 && (w.mounting || (w.horse && this.alarm !== 'fight'))) { const gx = w.goal.x - w.pos.x, gz = w.goal.z - w.pos.z, gl = Math.hypot(gx, gz) || 1; w.pos.x += (gx / gl) * Math.min(speed * dt, gl); w.pos.z += (gz / gl) * Math.min(speed * dt, gl); speed = -speed; }
      else if (speed > 0 && w.horse) { w.pos.x += Math.sin(face) * speed * dt; w.pos.z += Math.cos(face) * speed * dt; speed = -speed; }
      speed = Math.abs(speed) * (speed < 0 ? -1 : 1);
      if (speed > 0) {
        const tx = this.alarm === 'none' || w !== warner && this.alarm !== 'fight' ? w.goal.x - w.pos.x : dx, tz = this.alarm === 'none' || w !== warner && this.alarm !== 'fight' ? w.goal.z - w.pos.z : dz, tl = Math.hypot(tx, tz) || 1;
        w.pos.x += (tx / tl) * speed * dt; w.pos.z += (tz / tl) * speed * dt;
      }
      speed = Math.abs(speed);
      w.pos.y = getHeight(w.pos.x, w.pos.z);
      if (face !== null) { let d = face - w.fig.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d)); w.fig.root.rotation.y += d * Math.min(1, dt * 8); }
      if (w.horse) {
        // in the saddle: the horse goes where he goes; he sits her back, legs astride, the bow up when he looses
        const hpz = w.horse.puppet.group.position; hpz.set(w.pos.x, w.pos.y, w.pos.z);
        w.horse.puppet.update(dt, speed * 0.8, speed > 0.2 ? 'walk' : 'idle', false, 0, 0);
        w.fig.play(act || 'sit', 0.2); w.fig.mixer.update(dt);
        if (!act) astride(w.fig);
        seat(w.horse.puppet, w.fig);
      } else {
        if (act) w.fig.play(act, 0.2); else if (speed > 3) w.fig.play('run', 0.2); else if (speed > 0.2) w.fig.play('walk', 0.25); else w.fig.play('idle', 0.4);
        w.fig.mixer.update(dt);
      }
    }
    // the horses: tied at the picket; a horse whose rider fell runs off a way, then wanders back to it
    for (const h of this.horses) {
      if (h.rider) continue;
      const hp = h.puppet.group.position; let spd = 0;
      if (h.loose > 0) { h.loose -= dt; spd = 5; const a = h.looseA ??= Math.random() * 6.28; hp.x += Math.cos(a) * spd * dt; hp.z += Math.sin(a) * spd * dt; }
      else { const dx = h.picket.x - hp.x, dz = h.picket.z - hp.z, d = Math.hypot(dx, dz); h.looseA = undefined; if (d > 0.3) { spd = Math.min(1.4, d); hp.x += (dx / d) * spd * dt; hp.z += (dz / d) * spd * dt; } }
      hp.y = getHeight(hp.x, hp.z);
      const yaw = Math.atan2(camera.position.x - hp.x, camera.position.z - hp.z);
      h.puppet.update(dt, spd * 0.8, spd > 0.2 ? 'walk' : 'idle', false, yaw, 0);
    }
    // the camp's folk
    for (const f of this.folk) {
      f.fig.root.visible = !(campAbed && this.alarm !== 'fight'); if (!f.fig.root.visible) continue; // (abed in the lodges till first light)
      f.t -= dt;
      let speed = 0, act = null;
      if (this.alarm === 'fight' && !f.hiding) { f.hiding = true; f.sit = false; const l = this.lodges.reduce((a, b) => (a.distanceTo(f.pos) < b.distanceTo(f.pos) ? a : b)); const ax = this.at.x - p.x, az = this.at.z - p.z, al = Math.hypot(ax, az) || 1, sd = this.folk.indexOf(f) - 1; f.goal.set(l.x + (ax / al) * 3.2 - (az / al) * sd * 1.1, 0, l.z + (az / al) * 3.2 + (ax / al) * sd * 1.1); } // (they gather close by a lodge on the far side from the trouble, out in the open where you can still see them, not inside it)
      if (this.alarm !== 'fight') f.hiding = false;
      const gx = f.goal.x - f.pos.x, gz = f.goal.z - f.pos.z, gd = Math.hypot(gx, gz);
      if (gd > 0.35) { speed = f.hiding ? f.speed * 1.6 : f.speed; f.pos.x += (gx / gd) * speed * dt; f.pos.z += (gz / gd) * speed * dt; let d = Math.atan2(gx, gz) - f.fig.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d)); f.fig.root.rotation.y += d * Math.min(1, dt * 6); }
      else if (!f.hiding && f.t <= 0) {
        f.t = 5 + Math.random() * 9;
        f.sit = Math.random() < ({ elder: 0.8, grandfather: 0.7, woman: 0.4, maiden: 0.3, girl: 0.12 }[f.kind] ?? 0.4);
        if (f.sit) { const a = Math.random() * 6.28; f.goal.set(this.at.x + Math.cos(a) * 2.2, 0, this.at.z + Math.sin(a) * 2.2); }
        else if (f.kind === 'girl' && this.horses.length && Math.random() < 0.45) { const h = this.horses[Math.floor(Math.random() * this.horses.length)].picket; f.goal.set(h.x + (Math.random() - 0.5) * 3, 0, h.z + (Math.random() - 0.5) * 3); f.t = 4 + Math.random() * 4; } // (off to see the horses)
        else if (f.kind === 'girl') { const a = Math.random() * 6.28, r = 4 + Math.random() * 11; f.goal.set(this.at.x + Math.cos(a) * r, 0, this.at.z + Math.sin(a) * r); f.t = 2 + Math.random() * 4; }
        else { const l = this.lodges[Math.floor(Math.random() * this.lodges.length)], a = Math.random() * 6.28; f.goal.set(l.x + Math.cos(a) * 2, 0, l.z + Math.sin(a) * 2); }
      }
      if (gd <= 0.35 && f.sit && !f.hiding) { act = 'sit'; const d = Math.atan2(this.at.x - f.pos.x, this.at.z - f.pos.z) - f.fig.root.rotation.y; f.fig.root.rotation.y += Math.atan2(Math.sin(d), Math.cos(d)) * Math.min(1, dt * 4); }
      f.pos.y = getHeight(f.pos.x, f.pos.z);
      if (act) f.fig.play(act, 0.4); else if (speed > 1.8) f.fig.play('walk', 0.2, 1.9); else if (speed > 0.2) f.fig.play('walk', 0.25, Math.max(0.6, speed / 1.2)); else f.fig.play('idle', 0.4);
      f.fig.mixer.update(dt);
    }
    // arrows in flight
    for (let i = this.arrows.length - 1; i >= 0; i--) {
      const a = this.arrows[i]; a.t += dt;
      const k = Math.min(1, a.t / a.dur), m = a.mesh;
      m.position.lerpVectors(a.from, a.to, k); m.position.y += Math.sin(k * Math.PI) * a.arc;
      if (k < 1) m.lookAt(_v.lerpVectors(a.from, a.to, Math.min(1, k + 0.05)).setY(m.position.y + Math.cos(k * Math.PI) * a.arc * 0.2));
      if (k >= 1 && !a.landed) { a.landed = true; if (a.hit) { hooks.onHit?.(8); this.scene.remove(m); this.arrows.splice(i, 1); continue; } }
      if (a.t > a.dur + 6) { this.scene.remove(m); this.arrows.splice(i, 1); }
    }
  }

  /** Loose an arrow from a warrior at the player: a hit, a near miss, or (warning) into the ground at their feet. */
  shoot(from, p, hit, hooks, warning = false) {
    const m = arrowMesh(); this.scene.add(m);
    const src = new THREE.Vector3(from.x, from.y + 1.4, from.z);
    const off = warning ? 1.6 : hit ? 0 : 1.2 + Math.random();
    const ang = Math.random() * 6.28, dx = p.x - from.x, dz = p.z - from.z, d = Math.hypot(dx, dz) || 1;
    const to = warning ? new THREE.Vector3(p.x - (dx / d) * off, getHeight(p.x - (dx / d) * off, p.z - (dz / d) * off) + 0.2, p.z - (dz / d) * off)
      : new THREE.Vector3(p.x + Math.cos(ang) * off, p.y + (hit ? 1.2 : 0.2), p.z + Math.sin(ang) * off);
    this.arrows.push({ mesh: m, from: src, to, t: 0, dur: Math.max(0.25, d / 24), arc: d * 0.04, hit, landed: false });
    hooks.onShoot?.();
  }
}


/**
 * All the camps: one in a valley a good ride out, more further off, each with its own people, horses and land.
 * Looks like one camp to the rest of the game (targets, blows, fights and the map see them all).
 */
export class NativeCamps {
  constructor(scene, home, world = null) {
    this.list = [];
    this.raid = new Raid(scene);
    for (const [r0, r1, seed] of [[240, 340, 5150], [400, 560, 7331], [560, 760, 9127]]) {
      const c = new NativeCamp(scene, home, { r0, r1, seed, avoid: this.list.map((q) => q.at), world });
      if (c.at) this.list.push(c);
    }
    this.at = this.list[0]?.at ?? null;
  }
  get warriors() { return this.list.flatMap((c) => c.warriors); }
  targets() { return this.list.flatMap((c) => c.targets()).concat(this.raid.targets()); }
  findTarget(player, reach) { for (const c of this.list) { const w = c.findTarget(player, reach); if (w) return w; } return this.raid.findTarget(player, reach); }
  damage(w, n, hooks, raidHooks) { if (w.raider) return this.raid.damage(w, n, raidHooks); const c = this.list.find((q) => q.warriors.includes(w)); return c ? c.damage(w, n, hooks) : false; }
  onLand(x, z) { return this.list.some((c) => c.onLand(x, z)); }
  atPoles(x, z) { return this.list.find((c) => c.atPoles(x, z)) || null; }
  /** A camp at peace with you whose fire (x, z) is beside: where you can trade. */
  fireAt(x, z, r = 5) { return this.list.find((c) => c.at && (c.peaceUntil || 0) > campDay && Math.hypot(x - c.at.x, z - c.at.z) < r) || null; }
  save() { return this.list.map((c) => c.peaceUntil || 0); }
  load(d) { (d || []).forEach((v, i) => { if (this.list[i]) this.list[i].peaceUntil = v; }); }
  update(dt, player, camera, hooks, raidHooks) { for (const c of this.list) c.update(dt, player, camera, hooks); this.raid.update(dt, player, raidHooks); }
  /** Send a war party from the nearest camp down on the town, at the building `target` = { id, name, door }. */
  startRaid(townAt, target) { if (this.raid.on || !this.list.length) return false; const c = this.list.reduce((a, b) => (a.at.distanceTo(townAt) < b.at.distanceTo(townAt) ? a : b)); if ((c.peaceUntil || 0) > campDay) return false; this.raid.start(townAt, c.at, target); return true; } // (no war party from a camp you're at peace with)
}


/**
 * A raid on the town. Now and then a war party of three rides down out of the hills from the nearest camp, straight
 * for one of the mended buildings, and circles it whooping and loosing arrows while they tear at it. Drive them off
 * (bring down two of the three with arrows or blows) and the last one wheels away; let them circle long enough and
 * they wreck the place, so it stands run-down again and wants mending (at half the cost, the frame still sound).
 * hooks: onSack(id), onRepelled(), onHit(damage), onShoot(), onFall(w).
 */
export class Raid {
  constructor(scene) { this.scene = scene; this.on = false; this.riders = []; this.arrows = []; this.group = new THREE.Group(); scene.add(this.group); }
  start(townAt, campAt, target) {
    const dx = campAt.x - townAt.x, dz = campAt.z - townAt.z, d = Math.hypot(dx, dz) || 1;
    this.from = new THREE.Vector3(townAt.x + (dx / d) * 110, 0, townAt.z + (dz / d) * 110); // (out of the hills on the camp's side of town)
    this.target = target; this.on = true; this.t = 0; this.sackT = 0; this.fleeing = false;
    const kinds = ['folk_native_warrior', 'folk_native_archer', 'folk_native_hunter'];
    for (let i = 0; i < 3; i++) {
      const name = hasFolk(kinds[i]) ? kinds[i] : kinds.find(hasFolk); if (!name) continue;
      const fig = new ModelFigure(name); fig.hands[0].add(bowMesh());
      const h = new Puppet('horse', animalModel('animal_horse') ? 1.7 : 1.25);
      const side = (i - 1) * 4, x = this.from.x - (dz / d) * side, z = this.from.z + (dx / d) * side;
      h.group.position.set(x, getHeight(x, z), z); this.group.add(h.group); this.group.add(fig.root);
      fig.root.position.copy(h.group.position);
      this.riders.push({ fig, raider: true, pos: fig.root.position, horse: { puppet: h }, hp: 7, dead: 0, cool: 1 + i, ang: (i / 3) * Math.PI * 2 });
    }
    if (!this.riders.length) this.on = false;
  }
  targets() { return this.riders.filter((w) => !w.dead).map((w) => ({ pos: w.pos, r: 1.1, h: 3, w })); }
  findTarget(player, reach) {
    let best = null, bd = reach + 1.2;
    for (const w of this.riders) { if (w.dead) continue; const d = Math.hypot(w.pos.x - player.pos.x, w.pos.z - player.pos.z); if (d < bd) { bd = d; best = w; } }
    return best;
  }
  damage(w, n, hooks = {}) {
    if (w.dead) return false;
    w.hp -= n; if (w.hp > 0) return false;
    w.dead = 0.001; w.loose = w.horse; w.horse = null; hooks.onFall?.(w); // (his horse bolts riderless back to the hills)
    if (!this.fleeing && this.riders.filter((q) => !q.dead).length <= 1) { this.fleeing = true; hooks.onRepelled?.(); }
    return true;
  }
  end() { for (const w of this.riders) { this.group.remove(w.fig.root); (w.horse || w.loose) && this.group.remove((w.horse || w.loose).puppet.group); } for (const a of this.arrows) this.scene.remove(a.mesh); this.riders = []; this.arrows = []; this.on = false; }
  update(dt, player, hooks = {}) {
    if (!this.on) return;
    this.t += dt;
    const door = this.target.door, p = player.pos;
    if (!this.fleeing) {
      const circling = this.riders.some((w) => !w.dead && w.circling);
      if (circling) this.sackT += dt;
      if (this.sackT > 22) { this.fleeing = true; hooks.onSack?.(this.target.id); } // (they've had long enough at it)
    }
    let gone = 0;
    for (const w of this.riders) {
      if (w.dead) { // thrown from the saddle: he lies a while in the dust, then is gone
        w.dead += dt; w.fig.root.rotation.x = -Math.min(1, w.dead / 0.6) * Math.PI / 2 * 0.95; w.fig.play('idle', 0.2); w.fig.mixer.update(dt); w.pos.y = getHeight(w.pos.x, w.pos.z);
        if (w.loose) { const hp = w.loose.puppet.group.position, a = Math.atan2(this.from.z - hp.z, this.from.x - hp.x); hp.x += Math.cos(a) * 7 * dt; hp.z += Math.sin(a) * 7 * dt; hp.y = getHeight(hp.x, hp.z); w.loose.puppet.update(dt, 5.6, 'walk', false, 0, 0); }
        if (w.dead > 25) { w.fig.root.visible = false; if (w.loose) w.loose.puppet.group.visible = false; gone++; }
        continue;
      }
      w.cool -= dt;
      w.pos.copy(w.horse.puppet.group.position); // (he goes where his horse goes; the seat shifts his body onto her back each frame)
      let gx, gz, speed, act = null;
      if (this.fleeing) { gx = this.from.x; gz = this.from.z; speed = 10; }
      else {
        const dd = Math.hypot(door.x - w.pos.x, door.z - w.pos.z);
        if (!w.circling && dd < 9) w.circling = true;
        if (w.circling) { w.ang += dt * 0.55; gx = door.x + Math.cos(w.ang) * 7; gz = door.z + Math.sin(w.ang) * 7; speed = 5.5; }
        else { gx = door.x; gz = door.z; speed = 9; }
        const dP = Math.hypot(p.x - w.pos.x, p.z - w.pos.z);
        if (dP < 24 && w.cool <= 0 && !player.dead) { w.cool = 2.4 + Math.random(); act = 'Archery_Shot'; NativeCamp.prototype.shoot.call(this, w.pos, p, Math.random() < 0.4, hooks); }
      }
      const tx = gx - w.pos.x, tz = gz - w.pos.z, tl = Math.hypot(tx, tz) || 1, step = Math.min(speed * dt, tl);
      w.pos.x += (tx / tl) * step; w.pos.z += (tz / tl) * step; w.pos.y = getHeight(w.pos.x, w.pos.z);
      if (this.fleeing && tl < 3) { w.fig.root.visible = false; w.horse.puppet.group.visible = false; gone++; continue; }
      const hpz = w.horse.puppet.group.position; hpz.copy(w.pos);
      w.horse.puppet.update(dt, speed * 0.8, 'walk', false, 0, 0);
      w.fig.play(act || 'sit', 0.2); w.fig.mixer.update(dt);
      if (!act) astride(w.fig);
      seat(w.horse.puppet, w.fig);
    }
    for (let i = this.arrows.length - 1; i >= 0; i--) {
      const a = this.arrows[i]; a.t += dt;
      const k = Math.min(1, a.t / a.dur), m = a.mesh;
      m.position.lerpVectors(a.from, a.to, k); m.position.y += Math.sin(k * Math.PI) * a.arc;
      if (k < 1) m.lookAt(_v.lerpVectors(a.from, a.to, Math.min(1, k + 0.05)).setY(m.position.y + Math.cos(k * Math.PI) * a.arc * 0.2));
      if (k >= 1 && !a.landed) { a.landed = true; if (a.hit) { hooks.onHit?.(8); this.scene.remove(m); this.arrows.splice(i, 1); continue; } }
      if (a.t > a.dur + 6) { this.scene.remove(m); this.arrows.splice(i, 1); }
    }
    if (gone >= this.riders.length || this.t > 240) this.end();
  }
}
