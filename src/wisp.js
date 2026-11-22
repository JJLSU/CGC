// The will-o'-the-wisp: on some nights a little paper lantern-light bobs at the edge of the dark. Folks say
// they lead to lost things, and this one does: it drifts ahead of the farmer toward the nearest unopened lost
// satchel, waits if you fall behind, and fades away over the satchel when you get there.
// One small glowing card pair and nothing else; it costs next to nothing.
import * as THREE from 'three/webgpu';
import { getHeight, CHUNK } from './world.js';

export class Wisp {
  constructor(scene) {
    this.state = 'idle'; // idle · searching · leading · fading
    this.cool = 40;      // seconds until it may appear
    this.target = null;
    this.pos = new THREE.Vector3();
    this.goal = new THREE.Vector3();
    this.t = 0; this.fade = 1;
    this.onAppear = null;
    const mat = new THREE.MeshBasicNodeMaterial({ color: 0xffe2a0, transparent: true, opacity: 0.9, depthWrite: false, side: THREE.DoubleSide });
    const halo = new THREE.MeshBasicNodeMaterial({ color: 0xffc070, transparent: true, opacity: 0.25, depthWrite: false, side: THREE.DoubleSide });
    const core = new THREE.CircleGeometry(0.16, 14), glow = new THREE.CircleGeometry(0.5, 18);
    this.group = new THREE.Group();
    for (const [g, m] of [[glow, halo], [core, mat]]) {
      const a = new THREE.Mesh(g, m), b = new THREE.Mesh(g, m);
      b.rotation.y = Math.PI / 2;
      this.group.add(a, b);
    }
    this.mats = [mat, halo];
    this.group.visible = false;
    scene.add(this.group);
  }

  update(dt, { world, player, camera, night }) {
    const p = player.pos;
    this.t += dt;
    if (this.state === 'idle') {
      if (night < 0.7 || (this.cool -= dt) > 0) return;
      this.cool = 90 + Math.random() * 90;
      // look around for a lost satchel a couple of chunks per frame (generating far chunks costs ~1 ms each)
      this.state = 'searching'; this.search = { cx: Math.floor(p.x / CHUNK), cz: Math.floor(p.z / CHUNK), i: 0, best: null, bd: Infinity };
      return;
    }
    if (this.state === 'searching') {
      const S = this.search;
      for (let n = 0; n < 2 && S.i < 81; n++, S.i++) {
        const dx = (S.i % 9) - 4, dz = Math.floor(S.i / 9) - 4;
        for (const q of world.satchelsFor(S.cx + dx, S.cz + dz)) {
          const d = Math.hypot(q.x - p.x, q.z - p.z);
          if (d > 20 && d < S.bd) { S.bd = d; S.best = q; }
        }
      }
      if (S.i < 81) return;
      this.state = 'idle';
      this.target = S.best;
      if (!this.target || night < 0.7) return;
      this.state = 'leading'; this.fade = 0;
      this.place(p, 9);
      this.pos.copy(this.goal);
      this.group.visible = true;
      this.onAppear?.();
    }
    if (this.state === 'leading') {
      if (night < 0.5 || world.destroyed.has(this.target.key)) { this.state = 'fading'; }
      const toT = Math.hypot(this.target.x - p.x, this.target.z - p.z);
      if (toT < 7) { this.goal.set(this.target.x, getHeight(this.target.x, this.target.z) + 1.4, this.target.z); if (toT < 3) this.state = 'fading'; }
      else if (Math.hypot(this.pos.x - p.x, this.pos.z - p.z) < 5) this.place(p, 11); // you caught up: it drifts on ahead
      this.fade = Math.min(1, this.fade + dt * 0.8);
    } else if (this.state === 'fading') {
      this.fade -= dt * 0.6;
      if (this.fade <= 0) { this.state = 'idle'; this.group.visible = false; return; }
    }
    // drift lazily toward its goal, bobbing and swaying
    this.pos.lerp(this.goal, Math.min(1, dt * 0.9));
    this.group.position.set(this.pos.x + Math.sin(this.t * 1.3) * 0.3, this.pos.y + Math.sin(this.t * 2.1) * 0.25, this.pos.z + Math.cos(this.t * 1.1) * 0.3);
    this.group.rotation.y = Math.atan2(camera.position.x - this.group.position.x, camera.position.z - this.group.position.z);
    const flicker = 0.85 + Math.sin(this.t * 9) * 0.08 + Math.sin(this.t * 23) * 0.05;
    this.mats[0].opacity = 0.9 * this.fade * flicker; this.mats[1].opacity = 0.25 * this.fade * flicker;
  }

  /** Put the goal `d` metres from the farmer, toward the satchel. */
  place(p, d) {
    const dx = this.target.x - p.x, dz = this.target.z - p.z, L = Math.hypot(dx, dz) || 1;
    const k = Math.min(d, L);
    const x = p.x + (dx / L) * k, z = p.z + (dz / L) * k;
    this.goal.set(x, getHeight(x, z) + 1.5, z);
  }
}
