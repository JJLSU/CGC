// A mallard hen and her ducklings: by day, on a pond near the farmer, a brown paper duck paddles slow loops with
// three or four downy yellow ducklings strung out behind her in a line, each following the one in front. Come close
// and she hurries them off across the water; walk on and they settle again. One family at a time, only while you're
// near water; nothing at all otherwise.
import * as THREE from 'three/webgpu';
import { Puppet } from './puppets.js';
import { isWater } from './world.js';

const WATER_Y = 0.03;

export class Ducks {
  constructor(scene) { this.scene = scene; this.fam = null; this.look = 0; this.onRing = null; this.onQuack = null; } // (onRing(x, z, size): a wake ring; onQuack(dist))

  /** The open water nearest (x, z), if the ducks are within reach of it: where tossed corn would land. */
  tossSpot(x, z) {
    const F = this.fam; if (!F || Math.hypot(F.ducks[0].pos.x - x, F.ducks[0].pos.z - z) > 10) return null;
    for (let r = 1; r <= 4; r += 0.5) for (let a = 0; a < Math.PI * 2; a += 0.4) { const px = x + Math.cos(a) * r, pz = z + Math.sin(a) * r; if (isWater(px, pz) && isWater(px + Math.cos(a) * 0.6, pz + Math.sin(a) * 0.6)) return { x: px + Math.cos(a) * 0.6, z: pz + Math.sin(a) * 0.6 }; }
    return null;
  }
  /** Corn tossed on the water at (x, z): the family comes over to it and dabbles a while. */
  feed(spot) { if (this.fam) { this.fam.come = { x: spot.x, z: spot.z, t: 14 }; this.fam.quackT = 0.4; } }
  /** day: whether it's daylight (they're off the water at night) */
  update(dt, player, camera, day, dog = null) { // (dog: Old Blue's position: his barking from the bank hurries them too)
    const F = this.fam;
    if (F && (!day || Math.hypot(F.c.x - player.pos.x, F.c.z - player.pos.z) > 75)) { for (const d of F.ducks) this.scene.remove(d.p.group); this.fam = null; return; }
    if (!F) {
      if (!day || (this.look -= dt) > 0) return;
      this.look = 4;
      // a pond within 12-40 m: a water point with open water a good few metres all round it
      for (let i = 0; i < 16; i++) {
        const a = Math.random() * Math.PI * 2, r = 12 + Math.random() * 28, x = player.pos.x + Math.cos(a) * r, z = player.pos.z + Math.sin(a) * r;
        if (![0, 1, 2, 3, 4, 5, 6, 7].every((k) => isWater(x + Math.cos(k * 0.785) * 3.5, z + Math.sin(k * 0.785) * 3.5)) || !isWater(x, z)) continue;
        const n = 3 + Math.floor(Math.random() * 2), ducks = [];
        for (let j = 0; j <= n; j++) {
          const p = new Puppet(j ? 'duckling' : 'duck', j ? 0.55 : 1.0); p.group.position.set(x, WATER_Y, z); this.scene.add(p.group);
          ducks.push({ p, pos: p.group.position, phase: Math.random() * 6 });
        }
        this.fam = { c: new THREE.Vector3(x, 0, z), r: 2.4, ang: 0, ducks, trail: [] };
        return;
      }
      return;
    }
    // the mother paddles a slow loop (quicker, and wider, if you've come close); each duckling follows the trail
    const near = Math.hypot(F.ducks[0].pos.x - player.pos.x, F.ducks[0].pos.z - player.pos.z) < 5 || (dog && Math.hypot(F.ducks[0].pos.x - dog.x, F.ducks[0].pos.z - dog.z) < 7.5);
    let speed = near ? 1.4 : 0.45, tx, tz;
    const m = F.ducks[0];
    if (F.come && (F.come.t -= dt) > 0) { // corn on the water: she paddles straight over to it, the brood behind, and dabbles there
      speed = 0; const dx = F.come.x - m.pos.x, dz = F.come.z - m.pos.z, d = Math.hypot(dx, dz);
      if (d > 0.35) { speed = 0.8; tx = m.pos.x + (dx / d) * speed * dt; tz = m.pos.z + (dz / d) * speed * dt; } else { tx = m.pos.x; tz = m.pos.z; }
      if (!isWater(tx, tz)) { tx = m.pos.x; tz = m.pos.z; speed = 0; }
      F.ang = Math.atan2(tz - F.c.z, tx - F.c.x); F.r = Math.max(1.2, Math.hypot(tx - F.c.x, tz - F.c.z)); // (so she picks up her loop again from here)
    } else {
      F.come = null;
      F.ang += (speed / F.r) * dt;
      tx = F.c.x + Math.cos(F.ang) * F.r; tz = F.c.z + Math.sin(F.ang) * F.r;
      if (!isWater(tx, tz)) { F.r = Math.max(1.2, F.r * 0.9); tx = F.c.x + Math.cos(F.ang) * F.r; tz = F.c.z + Math.sin(F.ang) * F.r; } // (keep to open water)
      else if (F.r < 3.2) F.r += dt * 0.05;
    }
    m.pos.set(tx, WATER_Y, tz);
    F.trail.unshift([tx, tz]); if (F.trail.length > 400) F.trail.length = 400;
    // a little V of rings spreading behind her as she paddles, and a quack every so often (a flurry when you come close)
    F.ringT = (F.ringT ?? 0) - dt; if (F.ringT <= 0) { F.ringT = near ? 0.35 : 0.9; this.onRing?.(tx, tz, 0.55); }
    F.quackT = (F.quackT ?? 3) - dt; if (F.quackT <= 0) { F.quackT = near ? 1.2 + Math.random() : 7 + Math.random() * 9; this.onQuack?.(Math.hypot(tx - player.pos.x, tz - player.pos.z)); }
    const yawToCam = Math.atan2(camera.position.x - tx, camera.position.z - tz);
    F.ducks.forEach((d, j) => {
      if (j) { // a stride behind the one in front along the mother's wake
        const want = j * 0.55; let acc = 0, k = 1;
        for (; k < F.trail.length; k++) { acc += Math.hypot(F.trail[k][0] - F.trail[k - 1][0], F.trail[k][1] - F.trail[k - 1][1]); if (acc >= want) break; }
        const pt = F.trail[Math.min(k, F.trail.length - 1)]; d.pos.set(pt[0], WATER_Y, pt[1]);
      }
      d.p.update(dt, speed, 'walk', false, yawToCam);
      d.p.group.position.y = WATER_Y + Math.sin(performance.now() / 600 + d.phase) * 0.012; // (bobbing on the ripples)
    });
  }
}
