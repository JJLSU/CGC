// The lost calf: now and then (about one day in five, from Day 4, never on fair day) Daisy the cow's calf
// slips through the pasture rails in the night and wanders off. In the morning a note says which way it went.
// It's out in the meadows 40–70 m off, a little paper calf grazing and bawling for its mother now and then
// (you hear it from a good way off). Press E by it and it trots after you; bring it within sight of the pasture
// and it scampers in to Daisy, who's so glad she gives extra milk. If you never find it, it finds its own way
// home by nightfall.
import * as THREE from 'three/webgpu';
import { Puppet } from './puppets.js';
import { getHeight, isWater, regionAt } from './world.js';
import { Steer } from './steer.js';

const DIRS = ['east', 'north-east', 'north', 'north-west', 'west', 'south-west', 'south', 'south-east'];

export class Calf {
  constructor(scene, pasture) {
    this.pasture = pasture; // centre of the cows' pasture
    this.puppet = new Puppet('cow', 0.55, 'animal_calf');
    this.pos = this.puppet.group.position;
    this.puppet.group.visible = false;
    scene.add(this.puppet.group);
    this.state = 'home'; this.lostDay = -1; this.dir = new THREE.Vector3(1, 0, 0); this.speed = 0;
    this.mooT = 3; this.t = 0;
    this.onMoo = null;
    this.steer = new Steer(0.3);
  }

  lostToday(day) { return day >= 4 && day % 7 !== 0 && ((day * 2246822519) >>> 0) % 5 === 2; }
  near(pos, r = 2.4) { return this.state === 'lost' && Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z) < r; }

  /** Morning: it's gone. Returns the direction word for the note, or null. */
  wander(day) {
    for (let tries = 0; tries < 30; tries++) {
      const a = Math.random() * Math.PI * 2, d = 40 + Math.random() * 30;
      const x = this.pasture.x + Math.cos(a) * d, z = this.pasture.z + Math.sin(a) * d;
      const reg = regionAt(x, z);
      if (isWater(x, z) || (reg !== 'meadow' && reg !== 'field')) continue;
      this.pos.set(x, getHeight(x, z), z);
      this.state = 'lost'; this.lostDay = day; this.puppet.group.visible = true;
      return DIRS[((Math.round(Math.atan2(-(z - this.pasture.z), x - this.pasture.x) / (Math.PI / 4)) % 8) + 8) % 8];
    }
    return null;
  }

  update(dt, sky, player, camera, colliders = []) {
    this.t += dt;
    if (this.state === 'home') {
      if (sky.day !== this.lostDay && this.lostToday(sky.day) && sky.time > 0.27 && sky.time < 0.5) { const w = this.wander(sky.day); return w ? { lost: w } : null; }
      return null;
    }
    // it finds its own way home by nightfall
    if (sky.time > 0.8 || sky.day !== this.lostDay) { this.state = 'home'; this.puppet.group.visible = false; return null; }
    const p = player.pos;
    let speed = 0;
    if (this.state === 'lost') {
      // grazing about, and bawling for its mother now and then
      if ((this.mooT -= dt) <= 0) { this.mooT = 6 + Math.random() * 6; const d = Math.hypot(p.x - this.pos.x, p.z - this.pos.z); if (d < 90) this.onMoo?.(Math.max(0.15, 1 - d / 90)); }
    } else if (this.state === 'follow') {
      const tx = p.x - this.pos.x, tz = p.z - this.pos.z, d = Math.hypot(tx, tz);
      if (d > 2.2) { this.dir.copy(this.steer.heading(_h.set(tx / d, 0, tz / d), this.pos, p, colliders, dt)); speed = Math.min(6.5, 1.5 + d * 1.2); }
      if (d > 45) { this.pos.set(p.x - 2, getHeight(p.x - 2, p.z), p.z - 2); } // never lose it on the way home
      // home: in sight of the pasture, it scampers in to Daisy
      if (Math.hypot(this.pos.x - this.pasture.x, this.pos.z - this.pasture.z) < 11) { this.state = 'run'; this.t = 0; return { home: true }; }
    } else if (this.state === 'run') {
      const tx = this.pasture.x - this.pos.x, tz = this.pasture.z - this.pos.z, d = Math.hypot(tx, tz);
      this.dir.copy(this.steer.heading(_h.set(tx / (d || 1), 0, tz / (d || 1)), this.pos, this.pasture, colliders, dt)); speed = 5;
      if (d < 2 || this.t > 6) { this.state = 'home'; this.puppet.group.visible = false; }
    }
    this.speed += (speed - this.speed) * Math.min(1, dt * 5);
    if (this.speed > 0.05) {
      const nx = this.pos.x + this.dir.x * this.speed * dt, nz = this.pos.z + this.dir.z * this.speed * dt;
      if (!isWater(nx, nz)) { this.pos.x = nx; this.pos.z = nz; }
      this.steer.pushOut(this.pos);
    }
    this.pos.y = getHeight(this.pos.x, this.pos.z);
    const yawToCam = Math.atan2(camera.position.x - this.pos.x, camera.position.z - this.pos.z);
    const camYaw = Math.atan2(camera.position.x - p.x, camera.position.z - p.z);
    this.puppet.update(dt, this.speed, this.speed > 0.3 ? 'walk' : 'idle', this.dir.x * Math.cos(camYaw) - this.dir.z * Math.sin(camYaw) < 0, yawToCam);
    if (this.state === 'lost') this.puppet.head.rotation.z = -0.5 + Math.sin(this.t * 1.3) * 0.15; // nose down in the grass
    return null;
  }

  /** For the save: is it out today, and where? */
  save() { return { lostDay: this.lostDay, out: this.state === 'lost' || this.state === 'follow', x: this.pos.x, z: this.pos.z }; }
  load(s, day) {
    if (!s || s.lostDay !== day) return;
    this.lostDay = day;
    if (s.out) { this.pos.set(s.x, getHeight(s.x, s.z), s.z); this.state = 'lost'; this.puppet.group.visible = true; }
  }

  lead() { if (this.state === 'lost') { this.state = 'follow'; return true; } return false; }
}

const _h = new THREE.Vector3();
