// A coyote on the rise: now and then on a dark night, out in the open country, a coyote trots up onto the highest
// ground nearby, sits, tips its nose to the moon and howls (and, far off, another answers), then gets up and lopes away
// over the rise. Only scenery: it never comes for you. One puppet at a time, only while it's on.
import * as THREE from 'three/webgpu';
import { Puppet } from './puppets.js';
import { getHeight, isWater } from './world.js';

export class NightHowl {
  constructor(scene) { this.scene = scene; this.wait = 40 + Math.random() * 40; this.c = null; }

  /** on: a dark night out in the country; onHowl(vol) plays the howl. */
  update(dt, player, camera, on, onHowl) {
    const C = this.c;
    if (!C) {
      if (!on || (this.wait -= dt) > 0) return;
      this.wait = 100 + Math.random() * 80;
      // the highest dry ground 26-42 m off (never down in a hollow)
      let best = null;
      for (let i = 0; i < 14; i++) {
        const a = (i / 14) * Math.PI * 2 + Math.random() * 0.3, r = 26 + Math.random() * 16, x = player.pos.x + Math.cos(a) * r, z = player.pos.z + Math.sin(a) * r;
        if (isWater(x, z)) continue;
        const h = getHeight(x, z); if (!best || h > best.h) best = { x, z, h, a };
      }
      if (!best || best.h < player.pos.y - 1) return; // (only a hollow to sit in: not tonight)
      const p = new Puppet('coyote', 1.0);
      const from = new THREE.Vector3(best.x + Math.cos(best.a) * 6, 0, best.z + Math.sin(best.a) * 6); // (it comes up from the far side)
      p.group.position.set(from.x, getHeight(from.x, from.z), from.z); this.scene.add(p.group);
      this.c = { p, at: new THREE.Vector3(best.x, best.h, best.z), away: best.a, phase: 'come', t: 0 };
      return;
    }
    C.t += dt;
    const g = C.p.group.position; let speed = 0, pitch = 0;
    if (C.phase === 'come') {
      const dx = C.at.x - g.x, dz = C.at.z - g.z, d = Math.hypot(dx, dz);
      if (d > 0.2) { speed = 2.2; g.x += (dx / d) * speed * dt; g.z += (dz / d) * speed * dt; } else { C.phase = 'howl'; C.t = 0; }
      if (C.t > 8) { C.phase = 'howl'; C.t = 0; }
    } else if (C.phase === 'howl') {
      // sit, then the nose goes up and the howl comes; a second howl after a pause
      pitch = Math.min(1, Math.max(0, (C.t - 0.6) / 0.5)) * (C.t < 7 ? 0.3 : Math.max(0, 1 - (C.t - 7) / 0.5) * 0.3);
      if (C.t - dt < 1.0 && C.t >= 1.0) onHowl?.(this.vol(player, g), false);
      if (C.t - dt < 4.6 && C.t >= 4.6) onHowl?.(this.vol(player, g), true);
      if (C.t > 7.6) { C.phase = 'go'; C.t = 0; }
    } else { // away over the rise, the way it came
      speed = 4.5; g.x += Math.cos(C.away) * speed * dt; g.z += Math.sin(C.away) * speed * dt;
      if (C.t > 5) { this.scene.remove(C.p.group); this.c = null; return; }
    }
    g.y = getHeight(g.x, g.z);
    const yawToCam = Math.atan2(camera.position.x - g.x, camera.position.z - g.z);
    C.p.update(dt, speed, speed > 3 ? 'flee' : 'idle', false, yawToCam);
    if (C.phase === 'howl') C.p.flip.rotation.y = Math.atan2(player.pos.x - g.x, player.pos.z - g.z) - Math.PI / 2 + Math.PI / 2.4; // (side-on to you, against the sky)
    C.p.flip.rotation.z = pitch; C.p.flip.position.y = -Math.sin(pitch) * 0.55; // (nose up, haunches down: sat on the rise, front paws still planted)
  }

  vol(player, g) { return Math.max(0.15, 1 - Math.hypot(g.x - player.pos.x, g.z - player.pos.z) / 70); }
}
