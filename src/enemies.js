// Guardians from the old tales: they watch over treasure, not the whole countryside.
// Dust-devil coyotes keep the iron veins in the highlands; an old bramble boar keeps each wild-hive grove.
// They patrol near their site, give chase only so far from it, lunge to bite or gore, and fold down flat
// when beaten. A beaten guardian stays gone (its key is remembered with the world's destroyed props).
import * as THREE from 'three/webgpu';
import { Puppet } from './puppets.js';
import { getHeight, isWater, springRise } from './world.js';
import { mulberry32 } from './noise.js';
import { cardMaterial } from './materials.js';
import { vec3 } from 'three/tsl';
import { cardGeometry } from './props.js';
import { paintCard, asLayer } from './textures.js';

// a cream "z z" card that bobs over a guardian dozing after a peace offering
let _zz = null;
function zzKit() {
  if (_zz) return _zz;
  const pts = [[-0.22, 0], [0.22, 0], [0.24, 0.2], [-0.24, 0.2]];
  const art = paintCard(pts, {
    W: 128, H: 64, seed: 123, base: '#efe3c4', fills: ['rgba(239,227,196,A)'], edge: 'rgba(90,70,50,1)',
    details(g) { g.fillStyle = '#4f6f96'; g.font = 'bold italic 40px Georgia, serif'; g.textAlign = 'center'; g.fillText('z z', 64, 46); },
  });
  return (_zz = { geometry: cardGeometry(pts, 0.015), material: cardMaterial(art) });
}

// the warning card: a little red paper badge with a cream "!" that pops up over a guardian winding up
let _warn = null;
function warnKit() {
  if (_warn) return _warn;
  const pts = []; for (let i = 0; i < 18; i++) { const a = (i / 18) * Math.PI * 2; pts.push([Math.cos(a) * 0.2, 0.2 + Math.sin(a) * 0.2]); }
  const art = paintCard(pts, {
    W: 128, H: 128, seed: 121, base: '#c4362f', fills: ['rgba(196,54,47,A)', 'rgba(170,40,36,A)'], edge: 'rgba(110,24,20,1)',
    details(g, px) {
      const [x, y] = px(0, 0.2);
      asLayer(g, () => { g.fillStyle = '#f6efe0'; g.fillRect(x - 7, y - 34, 14, 42); g.beginPath(); g.arc(x, y + 22, 8, 0, Math.PI * 2); g.fill(); }, 0.6);
    },
  });
  return (_warn = { geometry: cardGeometry(pts, 0.02), material: cardMaterial(art) });
}

export const GUARDS = {
  coyote: { name: 'Dust-devil coyote', hp: 6, dmg: 9, speed: 6.2, aggro: 9, leash: 12, reach: 1.5, cooldown: 1.2, pelt: [1, 2], scale: 1.0 },
  boar: { name: 'Old bramble boar', hp: 12, dmg: 16, speed: 5.4, aggro: 8, leash: 11, reach: 1.7, cooldown: 1.6, pelt: [2, 3], scale: 1.15, top: 1.25 },
  // the wild lands' keepers: they lie in wait (folded flat in the grass, or not there at all) and spring up
  hodag: { name: 'Hodag', hp: 16, dmg: 18, speed: 4.6, aggro: 7, leash: 12, reach: 1.9, cooldown: 1.8, pelt: [2, 3], scale: 1.3, top: 1.6, lurk: 'flat' },
  wampus: { name: 'Wampus cat', hp: 10, dmg: 14, speed: 7.6, aggro: 10, leash: 15, reach: 1.7, cooldown: 1.1, pelt: [2, 3], scale: 1.2, top: 1.25, lurk: 'flat' },
  gouger: { name: 'Sidehill gouger', hp: 9, dmg: 11, speed: 5.0, aggro: 8, leash: 11, reach: 1.6, cooldown: 1.4, pelt: [1, 2], scale: 1.05, top: 1.35 },
  hidebehind: { name: 'Hidebehind', hp: 8, dmg: 15, speed: 6.6, aggro: 6, leash: 10, reach: 1.6, cooldown: 1.3, pelt: [1, 2], scale: 1.0, top: 2.5, lurk: 'unseen' },
};
GUARDS.coyote.top = 1.1;

export class Enemies {
  constructor(scene, world) {
    this.scene = scene;
    this.world = world;
    this.list = [];
    this.calmBySite = {}; // site key → clock (day + time) till which its guardians doze (saved with the game)
    this.rng = mulberry32(911);
    this.onPlayerHit = null; // (damage, enemy) => void
    this.onWindup = null;    // (enemy) => void: a growl before the lunge
    world.onSiteLoad = (site) => this.spawnSite(site);
    world.onSiteUnload = (site) => this.despawnSite(site);
  }

  spawnSite(site) {
    const kind = site.guard || (site.kind === 'grove' ? 'boar' : 'coyote'); // veins and thickets: coyotes; groves: the boar; the wild lands: their own
    for (let i = 0; i < site.guards; i++) {
      const key = `${site.key}:g${i}`;
      if (this.world.destroyed.has(key)) continue;
      const a = (i / site.guards) * Math.PI * 2, d = 3 + this.rng() * 2;
      const x = site.x + Math.cos(a) * d, z = site.z + Math.sin(a) * d;
      const spec = GUARDS[kind];
      const puppet = new Puppet(kind, spec.scale, kind === 'gouger' ? 'animal_boar' : undefined);
      if (kind === 'gouger' && puppet.model) gougerize(puppet);
      const k = warnKit();
      const warn = new THREE.Mesh(k.geometry, k.material);
      warn.position.set(0.3, spec.top, 0.06); warn.visible = false;
      puppet.flip.add(warn);
      const zk = zzKit();
      const zz = new THREE.Mesh(zk.geometry, zk.material);
      zz.position.set(0.2, spec.top - 0.2, 0.06); zz.visible = false;
      puppet.flip.add(zz);
      puppet.group.position.set(x, getHeight(x, z), z);
      this.scene.add(puppet.group);
      this.list.push({
        kind, key, site, spec, puppet, pos: puppet.group.position, hp: spec.hp, state: 'guard', timer: this.rng() * 3,
        target: new THREE.Vector3(x, 0, z), dir: new THREE.Vector3(1, 0, 0), speed: 0, cool: 0, lunge: 0, hurt: 0, dying: 0, windup: 0, warn, zz, calmUntil: this.calmBySite[site.key] || 0,
      });
      if (spec.lurk) { // lying in wait
        const e = this.list[this.list.length - 1]; e.state = 'lurk'; e.rise = 0;
        if (spec.lurk === 'flat') puppet.setFold(0); else puppet.group.visible = false; // pressed flat on the page, a folded pop-up waiting to be opened
      }
    }
  }

  despawnSite(site) {
    for (const e of [...this.list]) if (e.site === site) this.remove(e);
  }

  remove(e) {
    this.scene.remove(e.puppet.group);
    this.list.splice(this.list.indexOf(e), 1);
  }

  /** The guardian the farmer would hit: nearest one in front within reach. */
  findTarget(player, reach) {
    const f = player.forward(_f);
    let best = null, bd = Infinity;
    for (const e of this.list) {
      if (e.dying || this.isCalm(e, this.clock || 0)) continue; // never strike a dozing guardian
      const dx = e.pos.x - player.pos.x, dz = e.pos.z - player.pos.z, d = Math.hypot(dx, dz);
      if (d > reach + 0.6 || Math.abs(e.pos.y - player.pos.y) > 2) continue;
      if (d > 0.3 && (dx * f.x + dz * f.z) / d < 0.2) continue;
      if (d < bd) { bd = d; best = e; }
    }
    return best ? { enemy: best, dist: bd } : null;
  }

  /** Hit a guardian. Returns { killed, loot } (loot: pelts). */
  damage(e, amount, from) {
    e.hp -= amount;
    e.hurt = 0.3;
    e.state = 'chase';
    // knock back a little
    const dx = e.pos.x - from.x, dz = e.pos.z - from.z, d = Math.hypot(dx, dz) || 1;
    e.pos.x += (dx / d) * 0.5; e.pos.z += (dz / d) * 0.5;
    if (e.hp > 0) return { killed: false };
    e.dying = 0.001;
    this.world.destroyed.add(e.key);
    const [a, b] = e.spec.pelt;
    return { killed: true, loot: a + Math.floor(this.rng() * (b - a + 1)) };
  }

  /** A peace offering: every guardian at this one's site dozes off till the next morning (clock: day + time). */
  calm(e, clock) {
    const until = Math.floor(clock) + 1.25;
    this.calmBySite[e.site.key] = until;
    for (const g of this.list) if (g.site === e.site && !g.dying) { g.calmUntil = until; g.state = 'guard'; g.windup = 0; g.lunge = 0; g.warn.visible = false; }
  }

  isCalm(e, clock) { return clock < e.calmUntil; }

  /** The nearest awake guardian within r (for offering it something), or null. */
  awakeNear(pos, clock, r = 3.6) {
    let best = null, bd = r;
    for (const e of this.list) {
      if (e.dying || this.isCalm(e, clock)) continue;
      const d = Math.hypot(e.pos.x - pos.x, e.pos.z - pos.z);
      if (d < bd) { bd = d; best = e; }
    }
    return best;
  }

  update(dt, player, camera, clock = 0) {
    this.clock = clock;
    const p = player.pos;
    const camYaw = Math.atan2(camera.position.x - p.x, camera.position.z - p.z);
    const camRight = _r.set(Math.cos(camYaw), 0, -Math.sin(camYaw));
    for (const e of [...this.list]) {
      const yawToCam = Math.atan2(camera.position.x - e.pos.x, camera.position.z - e.pos.z);
      if (e.dying) {
        // folds down flat onto the page, then leaves it
        e.dying += dt;
        e.puppet.setFold(1 - Math.min(1, e.dying / 0.5) ** 2); // folds flat onto the page along its creases
        if (e.dying > 1.4) this.remove(e);
        continue;
      }
      const s = e.spec;
      if (this.isCalm(e, clock)) {
        // dozing by the treasure: settled down low, legs tucked, chin on the ground, a "z z" bobbing over its head
        e.puppet.update(dt, 0, 'idle', e.dir.dot(camRight) < 0, yawToCam, 0);
        const rig = e.puppet.rig; if (!e.puppet.model) rig.position.y -= 0.12 * s.scale; /* (the paper beast settles; a model stands dozing) */
        for (const l of e.puppet.legs) l.rotation.z = l.position.x > 0 ? -1.35 : 1.35;
        e.puppet.head.rotation.z = -0.35 + Math.sin(performance.now() * 0.0012) * 0.03;
        e.zz.visible = true; e.zz.position.y = s.top - 0.2 + Math.sin(performance.now() * 0.002) * 0.05;
        e.puppet.flip.rotation.x = 0; e.puppet.setFold(1);
        continue;
      }
      e.zz.visible = false;
      const toP = _v.set(p.x - e.pos.x, 0, p.z - e.pos.z);
      const dist = toP.length();
      // lying in wait: still as paper till you're close, then up it springs on its hinge, with a roar
      if (e.state === 'lurk') {
        if (dist < s.aggro * 0.75 && !player.dead) { e.state = 'rise'; e.rise = 0; e.puppet.group.visible = true; e.dir.copy(toP).normalize(); this.onAmbush?.(e); }
        else { if (s.lurk === 'flat') e.puppet.update(dt, 0, 'idle', false, yawToCam, 0); continue; }
      }
      if (e.state === 'rise') {
        e.rise += dt;
        const k = springRise(e.rise * 1.1);
        e.puppet.setFold(k); // unfolds up off the page with a springy overshoot
        e.puppet.update(dt, 0, 'attack', e.dir.dot(camRight) < 0, yawToCam, Math.max(0, 1 - e.rise * 2) * 0.6);
        if (s.lurk === 'unseen') e.puppet.group.scale.setScalar(Math.min(1, 0.3 + k * 0.7));
        if (e.rise > 0.8) { e.state = 'chase'; e.timer = 0; e.puppet.setFold(1); e.puppet.group.scale.setScalar(1); }
        continue;
      }
      const fromHome = Math.hypot(e.pos.x - e.site.x, e.pos.z - e.site.z);
      const playerFromHome = Math.hypot(p.x - e.site.x, p.z - e.site.z);
      e.cool = Math.max(0, e.cool - dt);
      e.hurt = Math.max(0, e.hurt - dt);
      e.timer -= dt;

      // decide
      if (player.dead) e.state = 'return';
      else if (e.state === 'guard' && dist < s.aggro) { e.state = 'chase'; e.timer = 0; }
      if ((e.state === 'chase' || e.state === 'attack') && (playerFromHome > s.leash || fromHome > s.leash + 4)) e.state = 'return';
      if (e.state === 'return' && fromHome < 3) { e.state = 'guard'; e.timer = 1; }
      if (e.state === 'chase' && dist < s.reach) e.state = 'attack';
      if (e.state === 'attack' && dist > s.reach + 0.6) e.state = 'chase';

      // act
      let speed = 0;
      if (e.state === 'guard') {
        if (e.timer <= 0) { // pace around the treasure
          const a = this.rng() * Math.PI * 2, d = 1.5 + this.rng() * 4;
          e.target.set(e.site.x + Math.cos(a) * d, 0, e.site.z + Math.sin(a) * d);
          e.timer = 3 + this.rng() * 4;
        }
        const to = _w.set(e.target.x - e.pos.x, 0, e.target.z - e.pos.z);
        if (to.length() > 0.4) { e.dir.copy(to.normalize()); speed = 1.2; }
      } else if (e.state === 'chase') {
        e.dir.copy(toP).normalize(); speed = s.speed;
      } else if (e.state === 'return') {
        e.dir.set(e.site.x - e.pos.x, 0, e.site.z - e.pos.z).normalize(); speed = s.speed * 0.6;
      } else if (e.state === 'attack') {
        e.dir.copy(toP).normalize();
        // a readable wind-up before every lunge: it rears back, a red "!" pops up, a growl; step away to dodge
        if (e.cool <= 0 && e.windup <= 0 && e.lunge <= 0) { e.windup = WINDUP; e.warn.visible = true; this.onWindup?.(e); }
      }
      if (e.windup > 0) {
        e.windup -= dt;
        if (e.windup <= 0 || e.state !== 'attack') {
          e.warn.visible = false;
          if (e.state === 'attack') { e.cool = s.cooldown; e.lunge = 1; }
          e.windup = 0;
        }
      }
      // the lunge: snaps forward, and lands the hit at its peak
      if (e.lunge > 0) {
        const before = e.lunge;
        e.lunge = Math.max(0, e.lunge - dt * 3.2);
        if (before > 0.55 && e.lunge <= 0.55 && dist < s.reach + 0.5 && !player.dead) this.onPlayerHit?.(s.dmg, e);
      }
      e.speed += (speed - e.speed) * Math.min(1, dt * 7);
      if (e.speed > 0.01) {
        const nx = e.pos.x + e.dir.x * e.speed * dt, nz = e.pos.z + e.dir.z * e.speed * dt;
        if (!isWater(nx, nz)) { e.pos.x = nx; e.pos.z = nz; }
      }
      e.pos.y = getHeight(e.pos.x, e.pos.z);
      const left = e.dir.dot(camRight) < 0;
      const lungeAmt = e.windup > 0 ? -0.5 * (1 - e.windup / WINDUP) : Math.sin(Math.min(1, 1 - e.lunge) * Math.PI) * (e.lunge > 0 ? 1 : 0);
      if (e.warn.visible) e.warn.scale.setScalar(1 + Math.sin((WINDUP - e.windup) * 30) * 0.08); // the badge quivers
      e.puppet.update(dt, e.speed, e.state === 'attack' ? 'attack' : e.state === 'chase' ? 'chase' : 'idle', left, yawToCam, lungeAmt);
      // flinch when struck
      e.puppet.flip.rotation.x = e.hurt > 0 ? Math.sin(e.hurt * 40) * 0.08 : 0;
    }
  }
}

const WINDUP = 0.5; // seconds of warning before a lunge
const _v = new THREE.Vector3(), _w = new THREE.Vector3(), _r = new THREE.Vector3(), _f = new THREE.Vector3();

// The sidehill gouger has no model of its own yet, so it wears the bramble boar's, made its own: dyed a shaggy rust
// red, and with its uphill (left) legs drawn short so on level ground it lists like a barn in a gale, as the tale
// says. The materials are cloned so the old boar of the groves keeps his colour.
function gougerize(pup) {
  const m = pup.model;
  m.traverse((o) => { if (o.isMesh) { o.material = o.material.clone(); o.material.colorNode = o.material.colorNode.mul(vec3(1.22, 0.7, 0.52)); } });
  const bones = ['frontUprL', 'rearLegL_01'].map((n) => m.getObjectByName(n)).filter(Boolean);
  if (bones.length === 2) pup.lop = { bones, rest: bones.map((b) => b.scale.clone()), k: 0.66, roll: -0.6, drop: 0.1 };
}
