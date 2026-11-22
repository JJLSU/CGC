// Marmalade, the barn cat: a ginger tabby paper puppet who keeps her own hours. By day she naps in a loaf
// on her favourite spots (the top of the hay bales, the porch boards by the rocker, a warm patch of yard by
// the garden, under the washing line), hopping up and down where she has to, and every few minutes she
// strolls off to another. After dark she goes mousing along the garden rows, low and slow. She's in no hurry
// to be friends, but stand by her and press E for a scratch and she purrs. She gives Old Blue a wide berth.
import * as THREE from 'three/webgpu';
import { Puppet } from './puppets.js';
import { getHeight, springRise } from './world.js';

export class Cat {
  constructor(scene, center, porch) {
    const C = center;
    const ground = (x, z) => new THREE.Vector3(x, getHeight(x, z), z);
    const bale = ground(C.x - 6, C.z - 3.5); bale.y += 1.15;
    const deck = porch.seat.clone().add(new THREE.Vector3(-0.9 * Math.cos(porch.facing), -0.28, 0.9 * Math.sin(porch.facing)));
    this.spots = [bale, deck, ground(C.x - 4.2, C.z + 2.6), ground(C.x + 8.5, C.z + 2.4), bale];
    this.garden = { x0: C.x - 12.5, x1: C.x - 6.5, z0: C.z + 2.2, z1: C.z + 7.2 };
    this.puppet = new Puppet('cat', 1.6);
    this.pos = this.puppet.group.position;
    this.pos.copy(this.spots[0]);
    scene.add(this.puppet.group);
    this.dir = new THREE.Vector3(1, 0, 0);
    this.state = 'rest'; this.spot = 0; this.t = 0;
    this.restFor = 40 + Math.random() * 60;
    this.goal = new THREE.Vector3(); this.hop = null; // { from, to, t }
    this.patT = 0; this.flickT = 2;
    this.onPurr = null;
  }

  near(pos, r = 1.6) {
    const up = this.pos.y - getHeight(this.pos.x, this.pos.z) > 0.3; // on a perch you can reach up a bit further
    return Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z) < r + (up ? 1.1 : 0) && Math.abs(pos.y - this.pos.y) < 1.8;
  }

  pat() { this.patT = 2.2; this.t = Math.min(this.t, 5); this.onPurr?.(); }

  /** Pick where to go next: another napping spot by day, a mousing round in the garden by night. */
  nextGoal(night) {
    if (night > 0.6) {
      const G = this.garden;
      this.target = null;
      this.goal.set(G.x0 + Math.random() * (G.x1 - G.x0), 0, G.z0 + Math.random() * (G.z1 - G.z0));
      this.goal.y = getHeight(this.goal.x, this.goal.z);
      return;
    }
    let i; do { i = Math.floor(Math.random() * this.spots.length); } while (this.spots[i] === this.spots[this.spot]);
    this.spot = i; this.target = this.spots[i];
    this.goal.copy(this.target); this.goal.y = getHeight(this.goal.x, this.goal.z);
  }

  /** Steer round the farm's buildings, fences and bales instead of walking through them. */
  steer(desired, world, dt) {
    if ((this.scanT = (this.scanT || 0) - dt) <= 0) {
      this.scanT = 0.5;
      const g = this.goal;
      // nearby obstacles, leaving out any she's actually headed onto (the bales she means to hop up on)
      this.obstacles = world.colliders.filter((c) => Math.hypot(c.x - this.pos.x, c.z - this.pos.z) < c.r + 6 && Math.hypot(c.x - g.x, c.z - g.z) > c.r + 0.1);
    }
    const out = _s.copy(desired);
    for (const c of this.obstacles || []) {
      const dx = this.pos.x - c.x, dz = this.pos.z - c.z, d = Math.hypot(dx, dz) || 1e-3, R = c.r + 0.3;
      if (d > R + 1.6) continue;
      if (desired.x * -dx + desired.z * -dz > 0) { // heading toward it: slip round the side nearer the goal
        let tx = -dz / d, tz = dx / d;
        if (tx * desired.x + tz * desired.z < 0) { tx = -tx; tz = -tz; }
        const w = (R + 1.6 - d) / 1.6;
        out.x += tx * w * 2.2 + (dx / d) * w * 0.4; out.z += tz * w * 2.2 + (dz / d) * w * 0.4;
      }
    }
    return out.normalize();
  }

  /** Never end up inside an obstacle. */
  pushOut() {
    for (const c of this.obstacles || []) {
      const dx = this.pos.x - c.x, dz = this.pos.z - c.z, d = Math.hypot(dx, dz), R = c.r + 0.25;
      if (d < R && d > 1e-4) { this.pos.x = c.x + (dx / d) * R; this.pos.z = c.z + (dz / d) * R; }
    }
  }

  update(dt, player, camera, dog, night, world) {
    this.t += dt;
    this.patT = Math.max(0, this.patT - dt);
    const groundY = getHeight(this.pos.x, this.pos.z);
    let speed = 0;
    if (this.hop) {
      // a springy hop up onto (or down off) a perch
      const H = this.hop; H.t += dt;
      const k = Math.min(1, H.t / 0.45);
      this.pos.lerpVectors(H.from, H.to, k); this.pos.y += Math.sin(k * Math.PI) * 0.6;
      if (k >= 1) { this.hop = null; if (H.then) this.state = H.then; this.t = 0; }
    } else if (this.state === 'rest') {
      const prowling = night > 0.6;
      if (this.t > (prowling ? 6 + Math.random() * 3 : this.restFor) && this.patT <= 0 || (dog.near(this.pos, 1.8) && this.pos.y - groundY < 0.3)) {
        this.nextGoal(night); this.restFor = 40 + Math.random() * 70;
        if (this.pos.y - groundY > 0.3) { // hop down first
          const to = this.pos.clone().addScaledVector(_v.set(this.goal.x - this.pos.x, 0, this.goal.z - this.pos.z).normalize(), 0.9);
          to.y = getHeight(to.x, to.z);
          this.hop = { from: this.pos.clone(), to, t: 0, then: 'walk' };
        } else this.state = 'walk';
        this.t = 0;
      }
    } else if (this.state === 'walk') {
      const d = _v.set(this.goal.x - this.pos.x, 0, this.goal.z - this.pos.z);
      const len = d.length();
      const raised = this.target && this.target.y - this.goal.y > 0.3;
      if (len < (raised ? 0.85 : 0.2) || this.t > 40) {
        if (raised) this.hop = { from: this.pos.clone(), to: this.target.clone(), t: 0, then: 'rest' };
        else { this.state = 'rest'; this.t = 0; }
      } else {
        this.dir.lerp(this.steer(d.normalize(), world, dt), Math.min(1, dt * 6)).normalize(); // turns smoothly, like a cat
        speed = night > 0.6 ? 0.7 : 1.3; // low and slow when mousing
        this.pos.x += this.dir.x * speed * dt; this.pos.z += this.dir.z * speed * dt;
        this.pushOut();
        this.pos.y = getHeight(this.pos.x, this.pos.z);
      }
    }
    const yawToCam = Math.atan2(camera.position.x - this.pos.x, camera.position.z - this.pos.z);
    const camYaw = Math.atan2(camera.position.x - player.pos.x, camera.position.z - player.pos.z);
    const camRight = _r.set(Math.cos(camYaw), 0, -Math.sin(camYaw));
    this.puppet.update(dt, speed, speed > 0.1 ? 'walk' : 'idle', this.dir.dot(camRight) < 0, yawToCam);
    // resting: settled into a loaf, paws tucked, tail curled round; a pat sets her purring and leaning in
    const loaf = this.state === 'rest' && !this.hop ? Math.min(1, this.t / 0.6) : 0;
    const rig = this.puppet.rig;
    if (!this.puppet.model) rig.position.y -= loaf * 0.16; /* (the paper cat settles; the model stands) */
    for (const l of this.puppet.legs) l.rotation.z = (l.position.x > 0 ? -1.45 : 1.45) * loaf + l.rotation.z * (1 - loaf); // paws tucked under
    if (this.puppet.tail) this.puppet.tail.rotation.z = loaf * -0.9 + Math.sin(this.t * (this.patT > 0 ? 6 : 1.3)) * (this.patT > 0 ? 0.12 : 0.06);
    if (this.patT > 0) { this.puppet.head.rotation.z = 0.25 + Math.sin(this.patT * 4) * 0.08; rig.rotation.z += Math.sin(this.patT * 9) * 0.03; }
    else if (loaf) {
      // the odd ear flick, and a lazy look round toward the farmer
      if ((this.flickT -= dt) <= 0) { this.flickT = 3 + Math.random() * 6; this.flick = 0.3; }
      this.flick = Math.max(0, (this.flick || 0) - dt);
      for (const e of this.puppet.ears) e.rotation.z = Math.sin(this.flick * 30) * 0.3 * (this.flick > 0 ? 1 : 0);
      this.puppet.head.rotation.z = Math.sin(this.t * 0.4) * 0.08;
    }
    // a little hop squash, so she lands like paper settling (rotation only)
    if (this.hop) rig.rotation.z += (springRise(this.hop.t * 2.2) - 1) * 0.2;
  }
}

const _v = new THREE.Vector3(), _r = new THREE.Vector3(), _s = new THREE.Vector3();
