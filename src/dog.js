// Old Blue, the farm hound: a paper puppet that potters about near the farmer (ambling off to sniff a spot,
// sitting a while, then another; he lopes after you only once you're well off), and barks (once, and not too often) when a guardian or a crow
// is about. He never fights and never strays far; if he's left behind he lopes back to catch up.
import * as THREE from 'three/webgpu';
import { Puppet } from './puppets.js';
import { getHeight, isWater } from './world.js';
import { paperMaterial } from './materials.js';
import { Steer } from './steer.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

export class Dog {
  constructor(scene, at) {
    this.puppet = new Puppet('dog', 1.15);
    this.pos = this.puppet.group.position;
    this.pos.set(at.x + 1.5, getHeight(at.x + 1.5, at.z), at.z);
    scene.add(this.puppet.group);
    this.dir = new THREE.Vector3(1, 0, 0);
    this.speed = 0;
    this.state = 'idle';
    this.side = 1;
    this.barkT = 0;
    this.onBark = null;
    this.still = 0;   // seconds standing still: after a moment he sits down
    this.patT = 0;    // seconds of happy wriggling after a pat
    // once a day he wanders a little way off, digs, and trots back with something in his mouth
    this.errand = null;      // { phase: 'go' | 'dig' | 'back', spot, t }
    this.errandT = 120 + Math.random() * 120;
    this.foundDay = 0;
    this.onDig = null; this.onFind = null;
    // fetch: a good stick, with a twig off it, that he drops at your feet after a scratch
    this.stick = new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(0.7, 0.05, 0.05), new THREE.BoxGeometry(0.18, 0.035, 0.035).rotateZ(0.6).translate(0.12, 0.05, 0)]), paperMaterial({ color: 0x7a5636 }));
    this.stick.castShadow = true; this.stick.visible = false;
    scene.add(this.stick);
    this.steer = new Steer(0.35);
    this.fetch = null; // { phase: 'offered' | 'fly' | 'chase' | 'bring', t, from, to }
    this.onFetched = null;
  }

  /** After a scratch he sometimes trots up with a stick and drops it at your feet. */
  offerStick(player) {
    if (this.fetch || this.errand) return false;
    const x = (player.pos.x + this.pos.x) / 2, z = (player.pos.z + this.pos.z) / 2;
    this.fetch = { phase: 'offered', t: 0, from: new THREE.Vector3(), to: new THREE.Vector3(x, getHeight(x, z) + 0.03, z) };
    this.stick.visible = true; this.stick.position.copy(this.fetch.to); this.stick.rotation.set(0, Math.random() * 6, 0);
    return true;
  }

  stickNear(pos, r = 2.2) { return this.fetch?.phase === 'offered' && Math.hypot(pos.x - this.fetch.to.x, pos.z - this.fetch.to.z) < r; }

  /** Throw the stick: it sails off ahead of the farmer, end over end, and he's after it like a shot. */
  throwStick(player) {
    const F = this.fetch; if (!F) return;
    F.from.set(player.pos.x, player.pos.y + 1.4, player.pos.z);
    let d = 11;
    const fx = Math.sin(player.facing), fz = Math.cos(player.facing);
    while (d > 3 && isWater(player.pos.x + fx * d, player.pos.z + fz * d)) d -= 1;
    const x = player.pos.x + fx * d, z = player.pos.z + fz * d;
    F.to.set(x, getHeight(x, z) + 0.03, z);
    F.phase = 'fly'; F.t = 0;
    this.still = 0; this.onBark?.();
  }

  startErrand(player) {
    const a = Math.random() * Math.PI * 2, d = 6 + Math.random() * 3;
    const x = player.pos.x + Math.cos(a) * d, z = player.pos.z + Math.sin(a) * d;
    if (isWater(x, z)) return false;
    this.errand = { phase: 'go', spot: new THREE.Vector3(x, getHeight(x, z), z), t: 0 };
    return true;
  }

  near(pos, r = 1.9) { return Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z) < r; }

  /** A good scratch behind the ears. */
  pat() { this.patT = 1.6; this.still = 0; this.onBark?.(); }

  update(dt, player, camera, { danger = false, colliders = [], track = null, prey = null, rocker = null } = {}) {
    const p = player.pos;
    const toP = _v.set(p.x - this.pos.x, 0, p.z - this.pos.z);
    const dist = toP.length();
    // left far behind (a teleport, a long sprint): he catches up in a few bounds
    if (dist > 40) { this.pos.set(p.x - 2, getHeight(p.x - 2, p.z), p.z - 2); this.speed = 0; }
    // where he wants to be: just behind and beside the farmer (or off on his daily errand)
    const back = _w.set(player.vel.x, 0, player.vel.z);
    let moving = back.length() > 0.6;
    if (moving) back.normalize(); else back.set(0, 0, 0);
    const goal = _g.set(p.x - back.x * 2.2 + back.z * 1.3 * this.side, 0, p.z - back.z * 2.2 - back.x * 1.3 * this.side);
    const E = this.errand, Fx = this.fetch;
    // he's his own dog: rather than dogging every step, he potters about within a few paces of the farmer,
    // ambling to a spot, sniffing, sitting a while, then off to another; only when you're well off (14 m)
    // does he lope after you and settle somewhere nearby again
    this.amble = false;
    if (!Fx && !E && !this.lead) {
      this.potterT = (this.potterT ?? 0) - dt;
      const far = dist > 14, spotFar = this.potter && Math.hypot(this.potter.x - p.x, this.potter.z - p.z) > 10;
      if (!this.potter || this.potterT <= 0 || (far && spotFar)) {
        this.potterT = 6 + Math.random() * 10;
        for (let i = 0; i < 6; i++) {
          const a = Math.random() * Math.PI * 2, r = far ? 2.5 + Math.random() * 3 : 3 + Math.random() * 6.5;
          const x = p.x + Math.cos(a) * r, z = p.z + Math.sin(a) * r;
          if (!isWater(x, z)) { (this.potter ??= new THREE.Vector3()).set(x, 0, z); break; }
        }
      }
      if (this.potter) { goal.copy(this.potter); moving = true; this.amble = !far; }
    }
    // on the scent: when something's lost (the calf), every so often he dashes a few bounds toward it, stops,
    // barks and looks back at you as if to say "this way!", then trots back to heel
    this.trackT = (this.trackT ?? 6) - dt;
    if (track && !Fx && !E && !this.lead && this.trackT <= 0 && dist < 12) {
      const tx = track.x - p.x, tz = track.z - p.z, td = Math.hypot(tx, tz);
      if (td > 12) { this.lead = { to: new THREE.Vector3(p.x + (tx / td) * 9, 0, p.z + (tz / td) * 9), t: 0 }; this.trackT = 11 + Math.random() * 5; this.onTrack?.(); }
    }
    if (!track) this.lead = null;
    if (this.lead) {
      const L = this.lead; L.t += dt;
      if (L.t < 4) { goal.copy(L.to); moving = true; if (Math.hypot(L.to.x - this.pos.x, L.to.z - this.pos.z) < 0.8 && !L.barked) { L.barked = true; this.onBark?.(); this.puppet.head.rotation.z = 0.35; } }
      else this.lead = null;
    }
    // a tumbleweed bowling by is too much for him: off he goes after it, barking, a few bounds alongside it snapping
    // at the twigs, then he gives it up and trots back to you, very pleased with himself (now and then, not every one)
    this.rompT = (this.rompT ?? 0) - dt;
    if (prey && !Fx && !E && !this.lead && !this.romp && this.rompT <= 0 && dist < 14 && Math.hypot(prey.position.x - this.pos.x, prey.position.z - this.pos.z) < 12) { this.romp = { t: 0, prey }; this.rompT = 25 + Math.random() * 20; this.onBark?.(); this.puppet.head.rotation.z = 0.35; }
    if (this.romp) {
      const R = this.romp; R.t += dt;
      if (R.t < 5 && R.prey.parent && dist < 26) { goal.set(R.prey.position.x - 0.9, 0, R.prey.position.z); moving = true; if (R.t > 2.2 && !R.yip) { R.yip = true; this.onBark?.(); this.puppet.head.rotation.z = 0.3; } }
      else this.romp = null;
    }
    // you in the porch rocker: he comes and settles at its side on the grass, facing out over the yard with you
    if (rocker && !Fx && !E && !this.romp) {
      const side = new THREE.Vector3(Math.cos(rocker.facing), 0, -Math.sin(rocker.facing));
      goal.set(rocker.seat.x + side.x * 1.3 + Math.sin(rocker.facing) * 0.45, 0, rocker.seat.z + side.z * 1.3 + Math.cos(rocker.facing) * 0.45); moving = true; this.amble = true;
      if (Math.hypot(goal.x - this.pos.x, goal.z - this.pos.z) < 0.9) { this.restFace = rocker.facing; } else this.restFace = null;
    } else this.restFace = null;
    if (Fx) {
      Fx.t += dt;
      if (Fx.phase === 'offered') {
        if (Fx.t > 25) { this.fetch = null; this.stick.visible = false; } // bored: he takes it off to chew
      } else if (Fx.phase === 'fly') {
        const k = Math.min(1, Fx.t / 0.9);
        this.stick.position.lerpVectors(Fx.from, Fx.to, k); this.stick.position.y += Math.sin(k * Math.PI) * 3;
        this.stick.rotation.z = Fx.t * 14; // end over end
        if (k >= 1) { this.stick.rotation.set(0, this.stick.rotation.y, 0); this.stick.position.copy(Fx.to); }
        goal.copy(Fx.to); moving = true;
        if (k >= 1) { Fx.phase = 'chase'; }
      } else if (Fx.phase === 'chase') {
        goal.copy(Fx.to); moving = true;
        if (Math.hypot(Fx.to.x - this.pos.x, Fx.to.z - this.pos.z) < 0.7) { Fx.phase = 'bring'; Fx.t = 0; }
      } else if (Fx.phase === 'bring') {
        goal.set(p.x, 0, p.z); moving = true;
        if (dist < 1.8) {
          const x = (p.x + this.pos.x) / 2, z = (p.z + this.pos.z) / 2;
          Fx.to.set(x, getHeight(x, z) + 0.03, z); Fx.phase = 'offered'; Fx.t = 0;
          this.stick.position.copy(Fx.to); this.stick.rotation.set(0, Math.random() * 6, 0);
          this.patT = 1.2; this.onFetched?.();
        }
      }
    } else if (E) {
      E.t += dt;
      if (E.phase === 'go') { goal.copy(E.spot); moving = true; if (Math.hypot(E.spot.x - this.pos.x, E.spot.z - this.pos.z) < 0.6) { E.phase = 'dig'; E.t = 0; } }
      else if (E.phase === 'dig') { goal.copy(this.pos); if (E.t > 0.3 && E.t - dt <= 0.3) this.onDig?.(E.spot); if (E.t > 2.6) { E.phase = 'back'; E.t = 0; } }
      else if (dist < 2.2 || E.t > 20) { this.errand = null; this.onFind?.(); }
      if (E.t > 30) this.errand = null; // never get stuck on an errand
    } else if ((this.errandT -= dt) <= 0) {
      this.errandT = 60 + Math.random() * 60;
      if (this.day !== this.foundDay && dist < 10 && this.startErrand(player)) this.foundDay = this.day;
    }
    const toGoal = _t.set(goal.x - this.pos.x, 0, goal.z - this.pos.z);
    const gd = toGoal.length();
    let speed = 0;
    const chasing = !!this.romp || (this.fetch && (this.fetch.phase === 'chase' || this.fetch.phase === 'fly'));
    if (gd > (moving ? (chasing ? 0.3 : 0.8) : 2.4)) { this.dir.copy(this.steer.heading(toGoal.normalize(), this.pos, goal, colliders, dt)); speed = chasing ? 9 : this.amble ? Math.min(2.4, 0.8 + gd * 0.5) : Math.min(12, 1.5 + gd * 1.6); }
    this.speed += (speed - this.speed) * Math.min(1, dt * 5);
    if (this.speed > 0.05) {
      const nx = this.pos.x + this.dir.x * this.speed * dt, nz = this.pos.z + this.dir.z * this.speed * dt;
      if (!isWater(nx, nz)) { this.pos.x = nx; this.pos.z = nz; }
      this.steer.pushOut(this.pos);
    }
    this.pos.y = getHeight(this.pos.x, this.pos.z);
    // a bark when trouble is near (a guardian, crows in the corn), not more than every few seconds
    this.barkT -= dt;
    if (danger && this.barkT <= 0) { this.barkT = 4 + Math.random() * 3; this.onBark?.(); this.puppet.head.rotation.z = 0.3; }
    const camYaw = Math.atan2(camera.position.x - p.x, camera.position.z - p.z);
    const camRight = _r.set(Math.cos(camYaw), 0, -Math.sin(camYaw));
    const yawToCam = Math.atan2(camera.position.x - this.pos.x, camera.position.z - this.pos.z);
    this.puppet.update(dt, this.speed, this.speed > 0.3 ? 'walk' : 'idle', this.dir.dot(camRight) < 0, yawToCam);
    if (this.restFace != null && this.speed < 0.3) { let d = this.restFace - Math.PI / 2 - (this.puppet.heading ?? 0); d = Math.atan2(Math.sin(d), Math.cos(d)); this.puppet.heading = (this.puppet.heading ?? 0) + d * Math.min(1, dt * 3); this.puppet.flip.rotation.y = this.puppet.heading; } // (turned to look out the way you do)
    // sitting: after a couple of quiet seconds the rear folds down, front legs straight, head up
    this.still = this.speed < 0.3 ? this.still + dt : 0;
    this.patT = Math.max(0, this.patT - dt);
    const sit = this.patT > 0 || this.errand ? 0 : Math.min(1, Math.max(0, (this.still - 1.5) / 0.5));
    const rig = this.puppet.rig;
    if (!this.puppet.model) { rig.rotation.z += sit * 0.38; rig.position.y -= sit * 0.12; } // tip back onto his haunches (the paper dog; the model's own rest pose is a sit)
    for (const l of this.puppet.legs) if (l.position.x < 0) l.rotation.z = sit * 1.1; else l.rotation.z -= sit * 0.38;
    this.puppet.head.rotation.z = this.puppet.head.rotation.z * (1 - sit) + sit * 0.15;
    // digging: nose down, head bobbing hard
    if (this.errand?.phase === 'dig') this.puppet.head.rotation.z = -0.7 + Math.sin(this.errand.t * 22) * 0.25;
    // a pat: a happy wriggle and a blur of tail
    if (this.patT > 0) { rig.rotation.z += Math.sin(this.patT * 30) * 0.06; rig.position.y += Math.abs(Math.sin(this.patT * 12)) * 0.05; }
    // carrying the stick home: it rides crosswise in his mouth
    if (this.fetch?.phase === 'bring') { this.puppet.head.getWorldPosition(this.stick.position); this.stick.position.y -= 0.05; this.stick.rotation.set(0, Math.atan2(this.dir.x, this.dir.z), 0); }
    // a happy tail whenever the farmer is close
    if (this.puppet.tail && dist < 4) this.puppet.tail.rotation.z = Math.sin(performance.now() * (this.patT > 0 ? 0.06 : 0.02)) * (this.patT > 0 ? 0.6 : 0.35);
  }
}

const _v = new THREE.Vector3(), _w = new THREE.Vector3(), _g = new THREE.Vector3(), _t = new THREE.Vector3(), _r = new THREE.Vector3();

