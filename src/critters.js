// Paper animals: die-cut profile cards (printed both sides, so the back is the mirror image).
// Each card turns to face the camera and flips to its back when walking the other way, so it always
// reads as a side view. Rabbits hop, deer walk with a gentle bob, hens potter about the farmyard and peck.
// Rabbits and deer bolt when the farmer comes close; out on the highland a bison herd grazes, and lumbers off if crowded.
import * as THREE from 'three/webgpu';
import { Puppet } from './puppets.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { isWater, regionAt, getHeight } from './world.js';
import { mulberry32 } from './noise.js';

const SHAPES = {
  rabbit: [[-0.2, 0], [0.14, 0], [0.16, 0.08], [0.24, 0.16], [0.27, 0.24], [0.24, 0.3], [0.2, 0.32], [0.21, 0.46], [0.17, 0.47], [0.15, 0.33], [0.12, 0.45], [0.08, 0.45], [0.09, 0.3], [0.02, 0.26], [-0.1, 0.27], [-0.2, 0.22], [-0.26, 0.16], [-0.27, 0.1], [-0.24, 0.04]],
  deer: [[-0.45, 0], [-0.36, 0], [-0.34, 0.6], [-0.27, 0.6], [-0.27, 0], [-0.19, 0], [-0.19, 0.6], [0.22, 0.6], [0.22, 0], [0.3, 0], [0.3, 0.6], [0.36, 0.6], [0.36, 0], [0.44, 0], [0.45, 0.66], [0.52, 0.82], [0.58, 1.1], [0.64, 1.36], [0.8, 1.33], [0.83, 1.28], [0.72, 1.45], [0.7, 1.58], [0.63, 1.52], [0.6, 1.45], [0.52, 1.36], [0.42, 1.0], [0.3, 1.03], [-0.3, 1.03], [-0.44, 0.97], [-0.53, 1.04], [-0.52, 0.9], [-0.46, 0.72]],
  hen: [[-0.08, 0], [0.06, 0], [0.04, 0.08], [0.16, 0.14], [0.2, 0.24], [0.18, 0.32], [0.25, 0.34], [0.18, 0.38], [0.15, 0.46], [0.1, 0.47], [0.06, 0.4], [0.04, 0.3], [-0.1, 0.32], [-0.21, 0.43], [-0.23, 0.3], [-0.19, 0.18], [-0.11, 0.1]],
};

function art(type) {
  const pts = SHAPES[type];
  const common = { W: 256, H: 256, seed: type.length * 7 };
  if (type === 'rabbit') return paintCard(pts, { ...common, base: '#a4886c', fills: ['rgba(164,136,108,A)', 'rgba(140,114,90,A)', 'rgba(190,166,138,A)'], edge: 'rgba(90,66,44,1)',
    details(g, px) {
      const [bx, by] = px(0.0, 0.07); g.fillStyle = '#efe3cc'; g.beginPath(); g.ellipse(bx, by, 34, 14, 0, 0, Math.PI * 2); g.fill();
      const [tx, ty] = px(-0.25, 0.15); g.fillStyle = '#f6efe0'; g.beginPath(); g.arc(tx, ty, 13, 0, Math.PI * 2); g.fill();
      const [ex, ey] = px(0.15, 0.4); g.fillStyle = '#d98f8a'; g.beginPath(); g.ellipse(ex, ey, 4, 14, 0.15, 0, Math.PI * 2); g.fill();
      const [ix, iy] = px(0.2, 0.25); g.fillStyle = '#2b2018'; g.beginPath(); g.arc(ix, iy, 5, 0, Math.PI * 2); g.fill();
    } });
  if (type === 'deer') return paintCard(pts, { ...common, W: 320, H: 320, base: '#b8834e', fills: ['rgba(184,131,78,A)', 'rgba(160,110,64,A)', 'rgba(206,160,104,A)'], edge: 'rgba(96,60,30,1)',
    details(g, px, r) {
      const [bx, by] = px(0.0, 0.66); g.fillStyle = '#efe0c4'; g.beginPath(); g.ellipse(bx, by, 70, 10, 0, 0, Math.PI * 2); g.fill();
      for (let i = 0; i < 9; i++) { const [sx, sy] = px(-0.3 + r() * 0.6, 0.78 + r() * 0.2); g.fillStyle = 'rgba(246,236,214,0.9)'; g.beginPath(); g.arc(sx, sy, 4 + r() * 2, 0, Math.PI * 2); g.fill(); }
      const [ix, iy] = px(0.69, 1.4); g.fillStyle = '#2b2018'; g.beginPath(); g.arc(ix, iy, 4, 0, Math.PI * 2); g.fill();
      const [nx, ny] = px(0.8, 1.31); g.beginPath(); g.arc(nx, ny, 4, 0, Math.PI * 2); g.fill();
      const [tx, ty] = px(-0.49, 0.95); g.fillStyle = '#f6efe0'; g.beginPath(); g.ellipse(tx, ty, 6, 10, 0.4, 0, Math.PI * 2); g.fill();
    } });
  return paintCard(pts, { ...common, base: '#f1e6d0', fills: ['rgba(241,230,208,A)', 'rgba(224,210,186,A)'], edge: 'rgba(130,100,70,1)',
    details(g, px) {
      const [cx, cy] = px(0.12, 0.47); g.fillStyle = '#c4363a'; g.beginPath(); g.ellipse(cx, cy, 14, 9, 0, 0, Math.PI * 2); g.fill();
      const [wx, wy] = px(0.18, 0.31); g.fillStyle = '#c4363a'; g.beginPath(); g.ellipse(wx, wy, 6, 9, 0, 0, Math.PI * 2); g.fill();
      const [kx, ky] = px(0.22, 0.35); g.fillStyle = '#e0a03a'; g.beginPath(); g.moveTo(kx - 4, ky - 6); g.lineTo(kx + 14, ky); g.lineTo(kx - 4, ky + 6); g.fill();
      const [ix, iy] = px(0.13, 0.39); g.fillStyle = '#2b2018'; g.beginPath(); g.arc(ix, iy, 4, 0, Math.PI * 2); g.fill();
      const [gx, gy] = px(-0.05, 0.22); g.fillStyle = 'rgba(200,180,150,0.7)'; g.beginPath(); g.ellipse(gx, gy, 40, 18, -0.2, 0, Math.PI * 2); g.fill();
    } });
}

const FARM = new Set(['hen', 'cow', 'sheep']); // farm animals keep to their yard and never despawn
const SPEC = {
  rabbit: { walk: 1.2, run: 6.5, flee: 7, range: 7 },
  deer: { walk: 1.1, run: 7.5, flee: 11, range: 12 },
  hen: { walk: 0.6, run: 2.2, flee: 1.5, range: 4 },
  cow: { walk: 0.45, run: 1.6, flee: 0.7, range: 6 },   // tame: they let you walk right up
  sheep: { walk: 0.55, run: 2.6, flee: 0.8, range: 6 },
  bison: { walk: 0.5, run: 4.2, flee: 6, range: 9 },
  turkey: { walk: 0.7, run: 4.8, flee: 6, range: 6 }, // a flock pecking through the oak woods; off at a run if you come close   // a herd grazing the high prairie; they lumber off if crowded
};

export class Critters {
  constructor(scene, yard, pasture = null) {
    this.scene = scene;
    this.rng = mulberry32(4242);
    this.list = [];
    this.onSpotted = null; // (critter) => void, the first time the farmer gets near a deer
    this.onDressed = null; // (deer) => void, when you walk up to a deer your arrow brought down
    // hens live in the farmyard
    for (let i = 0; i < 5; i++) { const h = this.spawn('hen', yard.x + (this.rng() - 0.5) * 6, yard.z + (this.rng() - 0.5) * 6, yard, i === 0 ? 'rooster' : 'hen'); if (i === 0 && h) { h.rooster = true; this.rooster = h; } } // (and one of them's the rooster)
    // a milk cow and a few sheep graze the pasture south of the yard; like the hens, they stay put
    if (pasture) {
      for (let i = 0; i < 2; i++) this.spawn('cow', pasture.x + (this.rng() - 0.5) * 6, pasture.z + (this.rng() - 0.5) * 6, pasture);
      for (let i = 0; i < 4; i++) this.spawn('sheep', pasture.x + (this.rng() - 0.5) * 7, pasture.z + (this.rng() - 0.5) * 7, pasture);
    }
    this.spawnT = 0;
  }

  spawn(type, x, z, home = null, kit = type) { // (kit: a different puppet for the same beast: the rooster among the hens)
    const scale = type === 'turkey' ? 1.55 + this.rng() * 0.2 : type === 'bison' ? 1.0 + this.rng() * 0.18 : type === 'deer' ? 1.05 + this.rng() * 0.2 : type === 'cow' ? 1.0 + this.rng() * 0.1 : 0.95 + this.rng() * 0.2;
    const puppet = new Puppet(kit, scale);
    const mesh = puppet.group;
    mesh.position.set(x, getHeight(x, z), z);
    this.scene.add(mesh);
    const c = {
      type, mesh, puppet, pos: mesh.position, home: home ? home.clone() : new THREE.Vector3(x, 0, z), target: new THREE.Vector3(x, 0, z),
      state: 'idle', timer: this.rng() * 3, phase: this.rng() * 6, dir: new THREE.Vector3(1, 0, 0), speed: 0, spotted: false,
      scale,
    };
    this.list.push(c);
    return c;
  }

  despawn(c) {
    this.scene.remove(c.mesh);
    this.list.splice(this.list.indexOf(c), 1);
  }

  /** Keep a few rabbits and deer around the farmer: spawn out in the haze, drop the far ones. */
  manage(player) {
    const p = player.pos;
    for (const c of [...this.list]) if (!FARM.has(c.type) && c.pos.distanceToSquared(p) > 85 * 85) this.despawn(c);
    const count = (t) => this.list.filter((c) => c.type === t && c.state !== 'down').length;
    // a bison herd: out on the open highland, four or five together around one grazing spot (one herd at a time)
    if (!this.list.some((c) => c.type === 'bison') && this.rng() < 0.25) {
      const a = this.rng() * Math.PI * 2, d = 35 + this.rng() * 25, hx = p.x + Math.cos(a) * d, hz = p.z + Math.sin(a) * d;
      if (regionAt(hx, hz) === 'highland') {
        const home = new THREE.Vector3(hx, 0, hz);
        for (let i = 0, n = 4 + (this.rng() < 0.5 ? 1 : 0); i < n; i++) {
          const x = hx + (this.rng() - 0.5) * 7, z = hz + (this.rng() - 0.5) * 7;
          if (!isWater(x, z)) this.spawn('bison', x, z, home);
        }
      }
    }
    // a flock of wild turkeys: three or four together in the woods, one flock at a time
    if (!this.list.some((c) => c.type === 'turkey') && this.rng() < 0.2) {
      const a = this.rng() * Math.PI * 2, d = 26 + this.rng() * 20, hx = p.x + Math.cos(a) * d, hz = p.z + Math.sin(a) * d;
      if (regionAt(hx, hz) === 'forest') {
        const home = new THREE.Vector3(hx, 0, hz);
        for (let i = 0, n = 3 + (this.rng() < 0.5 ? 1 : 0); i < n; i++) { const x = hx + (this.rng() - 0.5) * 4, z = hz + (this.rng() - 0.5) * 4; if (!isWater(x, z)) this.spawn('turkey', x, z, home); }
      }
    }
    for (const [t, want] of [['rabbit', 6], ['deer', 4]]) {
      if (count(t) >= want) continue;
      const a = this.rng() * Math.PI * 2, d = 28 + this.rng() * 30;
      const x = p.x + Math.cos(a) * d, z = p.z + Math.sin(a) * d;
      const reg = regionAt(x, z);
      if (reg === 'water' || reg === 'peak') continue;
      if (t === 'deer' && reg !== 'forest' && reg !== 'meadow') continue;
      this.spawn(t, x, z);
    }
  }

  update(dt, player, camera) {
    if ((this.spawnT -= dt) <= 0) { this.spawnT = 1.5; this.manage(player); }
    // a gobble from the flock every so often, when it's within earshot
    if ((this.gobbleT = (this.gobbleT ?? 6) - dt) <= 0) {
      this.gobbleT = 12 + this.rng() * 16;
      let bd = Infinity; for (const c of this.list) if (c.type === 'turkey' && c.state !== 'down') bd = Math.min(bd, c.pos.distanceTo(player.pos));
      if (bd < 35) this.onGobble?.(bd);
    }
    const camRightX = Math.cos(Math.atan2(camera.position.x - player.pos.x, camera.position.z - player.pos.z));
    const camRight = _r.set(camRightX, 0, -Math.sin(Math.atan2(camera.position.x - player.pos.x, camera.position.z - player.pos.z)));
    for (const c of [...this.list]) {
      const spec = SPEC[c.type];
      const toP = _v.subVectors(c.pos, player.pos).setY(0);
      const dist = toP.length();
      if (c.state === 'down') { // struck: it folds down flat onto the page, and lies there till you come to dress it
        c.timer += dt; c.puppet.setFold(1 - Math.min(1, c.timer / 0.45) ** 2);
        if (dist < 2.2 && c.timer > 0.5) { this.onDressed?.(c); this.despawn(c); }
        else if (c.timer > 120) this.despawn(c);
        continue;
      }
      // the hens go in to roost at nightfall: up to the foot of the hen house ramp and in; out again at sunup
      // (and the cow and the sheep come in to the barn, through its big doors)
      const den = c.type === 'hen' ? this.roost : c.type === 'cow' || c.type === 'sheep' ? this.barn : null;
      if (den) {
        if (this.abed) {
          if (c.roosting) continue;
          const rx = den.x - c.pos.x, rz = den.z - c.pos.z, rd = Math.hypot(rx, rz);
          if (rd < (c.type === 'hen' ? 0.45 : 1.2)) { c.roosting = true; c.mesh.visible = false; c.lod = -1; continue; }
          c.dir.set(rx / rd, 0, rz / rd); c.speed = spec.walk * 1.4; c.state = 'walk';
          c.pos.x += c.dir.x * c.speed * dt; c.pos.z += c.dir.z * c.speed * dt; c.pos.y = getHeight(c.pos.x, c.pos.z);
          const yawToCam = Math.atan2(camera.position.x - c.pos.x, camera.position.z - c.pos.z);
          c.puppet.update(dt, c.speed, c.state, c.dir.dot(camRight) < 0, yawToCam);
          continue;
        } else if (c.roosting) { c.roosting = false; c.pos.set(den.x + (this.rng() - 0.5) * 1.5, getHeight(den.x, den.z), den.z + (this.rng() - 0.5) * 1.5); c.lod = -1; c.state = 'idle'; c.timer = 1 + this.rng() * 3; }
      }
      if (c.type === 'deer' && !c.spotted && dist < 12) { c.spotted = true; this.onSpotted?.(c); }
      if (c.type === 'bison' && !this.herdSeen && dist < 26) { this.herdSeen = true; this.onHerd?.(c); }
      if (dist < spec.flee && c.state !== 'flee') {
        c.state = 'flee'; c.timer = c.type === 'hen' ? 0.8 : 2.6;
        c.dir.copy(toP.normalize()).applyAxisAngle(_up, (this.rng() - 0.5) * 0.8);
      }
      c.timer -= dt;
      if (c.state === 'idle' && c.timer <= 0) {
        const a = this.rng() * Math.PI * 2, d = 1.5 + this.rng() * spec.range;
        c.target.set(c.home.x + Math.cos(a) * d, 0, c.home.z + Math.sin(a) * d);
        c.state = 'walk';
      }
      let speed = 0;
      if (c.state === 'walk') {
        const to = _w.subVectors(c.target, c.pos).setY(0);
        if (to.length() < 0.3) { c.state = 'idle'; c.timer = 1 + this.rng() * 4; }
        else { c.dir.copy(to.normalize()); speed = spec.walk; }
      } else if (c.state === 'flee') {
        speed = spec.run;
        if (c.timer <= 0) { c.state = 'idle'; c.timer = 1 + this.rng() * 2; if (!FARM.has(c.type)) c.home.copy(c.pos); }
      }
      c.speed += (speed - c.speed) * Math.min(1, dt * 6);
      if (c.speed > 0.01) {
        const nx = c.pos.x + c.dir.x * c.speed * dt, nz = c.pos.z + c.dir.z * c.speed * dt;
        if (isWater(nx, nz)) { c.dir.negate(); c.state = 'idle'; c.timer = 0.5; } else { c.pos.x = nx; c.pos.z = nz; }
      }
      // level of detail: far puppets (lost in the haze anyway) are hidden; mid-distance ones cast no shadow
      const cd2 = (camera.position.x - c.pos.x) ** 2 + (camera.position.z - c.pos.z) ** 2;
      const lod = cd2 > 55 * 55 ? 2 : cd2 > 22 * 22 ? 1 : 0;
      if (lod !== c.lod) {
        c.lod = lod;
        c.mesh.visible = lod < 2;
        c.puppet.setShadows(lod === 0);
      }
      if (lod === 2) continue;
      // the puppet strides, hops or pecks; it faces the camera and shows its back when going screen-left
      c.pos.y = getHeight(c.pos.x, c.pos.z);
      const yawToCam = Math.atan2(camera.position.x - c.pos.x, camera.position.z - c.pos.z);
      const left = c.dir.dot(camRight) < 0;
      c.puppet.update(dt, c.speed, c.state, left, yawToCam);
      // the rooster crowing at sunup: he stops, draws himself up and throws his head back
      if (c.crowT > 0) { c.crowT -= dt; c.speed = 0; const k = Math.min(1, Math.min(c.crowT, 1.8 - c.crowT) * 4); c.puppet.head.rotation.z = 0.75 * k; c.puppet.rig.position.y += 0.04 * k; c.puppet.rig.rotation.z += 0.25 * k; }
    }
  }

  /** A deer struck by an arrow: down it goes, and the others nearby bolt. */
  fell(c) {
    c.state = 'down'; c.timer = 0; c.speed = 0;
    for (const o of this.list) if (o !== c && o.type === c.type && o.state !== 'down' && o.pos.distanceTo(c.pos) < 25) { o.state = 'flee'; o.timer = 3; o.dir.subVectors(o.pos, c.pos).setY(0).normalize(); }
  }

  /** The nearest cow or sheep within r metres of the farmer (for milking and shearing). */
  livestockNear(pos, r = 2.3) {
    let best = null, bd = r;
    for (const c of this.list) {
      if ((c.type !== 'cow' && c.type !== 'sheep') || c.roosting) continue; // (not the ones in the barn for the night)
      const d = Math.hypot(c.pos.x - pos.x, c.pos.z - pos.z);
      if (d < bd) { bd = d; best = c; }
    }
    return best;
  }

  /** Hold an animal still for a moment (while you milk or shear it). */
  hold(c, seconds = 2.5) { c.state = 'idle'; c.timer = seconds; c.speed = 0; }

  /** A shorn sheep looks slimmer until its fleece grows back. */
  setShorn(c, shorn) { c.puppet.body.scale.set(shorn ? 0.86 : 1, shorn ? 0.82 : 1, 1); }

  /** Is any animal startled near (x, z)? Used by nothing yet; handy for future gameplay. */
  count(type) { return this.list.filter((c) => c.type === type).length; }
}

const _v = new THREE.Vector3(), _w = new THREE.Vector3(), _r = new THREE.Vector3(), _up = new THREE.Vector3(0, 1, 0);
