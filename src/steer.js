// Walking round things: a little steering helper for the farm's walkers (Old Blue, the lost calf, Johnny
// Appleseed). Given where a walker wants to go, it bends the heading to slip round the side of any obstacle
// circle ahead (buildings, bales, the tinker's wagon, fences), and pushes the walker back out if it ever ends
// up inside one. Obstacles near the walker are re-gathered twice a second, so it costs next to nothing.
import * as THREE from 'three/webgpu';

export class Steer {
  constructor(margin = 0.3) { this.margin = margin; this.near = []; this.scanT = 0; }

  /** desired: unit heading (x, z). goal: where it's going (an obstacle that contains the goal is ignored). */
  heading(desired, pos, goal, colliders, dt) {
    if ((this.scanT -= dt) <= 0) {
      this.scanT = 0.5;
      this.near = colliders.filter((c) => Math.hypot(c.x - pos.x, c.z - pos.z) < c.r + 6 && !(goal && Math.hypot(c.x - goal.x, c.z - goal.z) < c.r + 0.2));
    }
    const out = _o.copy(desired);
    for (const c of this.near) {
      const dx = pos.x - c.x, dz = pos.z - c.z, d = Math.hypot(dx, dz) || 1e-3, R = c.r + this.margin;
      if (d > R + 1.6) continue;
      if (desired.x * -dx + desired.z * -dz > 0) { // heading toward it: slip round the side nearer the goal
        let tx = -dz / d, tz = dx / d;
        if (tx * desired.x + tz * desired.z < 0) { tx = -tx; tz = -tz; }
        const w = (R + 1.6 - d) / 1.6;
        out.x += tx * w * 2.2 + (dx / d) * w * 0.4; out.z += tz * w * 2.2 + (dz / d) * w * 0.4;
      }
    }
    out.y = 0;
    return out.lengthSq() > 1e-6 ? out.normalize() : out.copy(desired);
  }

  /** Never end up inside an obstacle. */
  pushOut(pos) {
    for (const c of this.near) {
      const dx = pos.x - c.x, dz = pos.z - c.z, d = Math.hypot(dx, dz), R = c.r + this.margin * 0.8;
      if (d < R && d > 1e-4) { pos.x = c.x + (dx / d) * R; pos.z = c.z + (dz / d) * R; }
    }
  }
}

const _o = new THREE.Vector3();
