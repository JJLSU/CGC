// Tumbleweeds: on dry days in town and out in the Redrock Breaks, now and then a ball of dry brush comes bowling down
// the wind (out of the west, the way the smoke leans), hopping and spinning, and rolls on past you and away. Each one is
// five ragged discs of pale straw card slotted through each other at different angles, the way a paper ball is made; never more
// than two about at once, and none at all when it rains or away from the dry country.
import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { getHeight, isWater, landAt } from './world.js';

const MAX = 2;

function ballGeometry(seed) {
  let s = seed; const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  const disc = () => { // a ragged round of brush: chunky lobes, a few deeper notches, never thin spikes
    const n = 22, pts = [];
    for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2, r = 0.5 * (i % 2 ? 0.78 + rnd() * 0.12 : 0.95 + rnd() * 0.12); pts.push([Math.cos(a) * r, Math.sin(a) * r]); }
    return cardGeometry(pts, 0.03).toNonIndexed();
  };
  const parts = [disc(), disc().rotateY(Math.PI / 3), disc().rotateY((2 * Math.PI) / 3), disc().rotateX(Math.PI / 2), disc().rotateX(Math.PI / 4).rotateY(Math.PI / 6)];
  for (const g of parts) for (const k of Object.keys(g.attributes)) if (k !== 'position' && k !== 'normal') g.deleteAttribute(k);
  return mergeGeometries(parts);
}

export class Tumbleweeds {
  constructor(scene) {
    this.scene = scene; this.list = []; this.wait = 8;
    this.geos = [ballGeometry(7), ballGeometry(31), ballGeometry(97)];
    this.mats = [paperMaterial({ color: 0xd2b47c, flatShading: true }), paperMaterial({ color: 0xc4a468, flatShading: true })];
  }

  /** dry: is it dry country here (town or the Breaks), with no rain? */
  update(dt, player, dry, colliders = []) {
    this.wait -= dt;
    if (dry && this.wait <= 0 && this.list.length < MAX) {
      this.wait = 18 + Math.random() * 25;
      const x = player.pos.x - 26 - Math.random() * 6, z = player.pos.z + (Math.random() - 0.5) * 22;
      if (!isWater(x, z)) {
        const r = 0.45 + Math.random() * 0.25, mesh = new THREE.Mesh(this.geos[Math.floor(Math.random() * 3)], this.mats[Math.floor(Math.random() * 2)]);
        mesh.scale.setScalar(r * 2); mesh.castShadow = true; mesh.rotation.set(Math.random() * 6, Math.random() * 6, 0);
        this.scene.add(mesh);
        this.list.push({ mesh, r, x, z, v: 2.6 + Math.random() * 1.6, t: Math.random() * 5, drift: (Math.random() - 0.5) * 0.4, hop: 0.9 + Math.random() * 0.6 });
      }
    }
    for (let i = this.list.length - 1; i >= 0; i--) {
      const w = this.list[i];
      w.t += dt;
      const gust = 0.75 + 0.35 * Math.sin(w.t * 0.9 + w.r * 9); // (it slows, then the wind catches it again)
      w.drift *= 1 - dt * 0.4; // (a shove off a wall dies away)
      w.x += w.v * gust * dt; w.z += (w.drift + Math.sin(w.t * 0.6) * 0.25) * dt;
      // it fetches up against walls, posts and tents and is shoved round them, never through
      for (const c of colliders) { const dx = w.x - c.x, dz = w.z - c.z, rr = c.r + w.r * 0.8, d2 = dx * dx + dz * dz; if (d2 < rr * rr && d2 > 1e-6) { const d = Math.sqrt(d2); w.x = c.x + (dx / d) * rr; w.z = c.z + (dz / d) * rr; w.drift = Math.sign(dz || 1) * 0.9; } }
      const hop = Math.abs(Math.sin(w.t * w.hop * 2.2)) * 0.45 * gust; // (bouncing along on its twigs)
      w.mesh.position.set(w.x, getHeight(w.x, w.z) + w.r + hop, w.z);
      w.mesh.rotation.z -= (w.v * gust * dt) / w.r; w.mesh.rotation.x += w.drift * dt;
      if (w.x > player.pos.x + 34 || Math.abs(w.z - player.pos.z) > 40 || isWater(w.x, w.z)) { this.scene.remove(w.mesh); this.list.splice(i, 1); }
    }
  }

  /** Is (x, z) tumbleweed country: the Redrock Breaks? (main.js adds the town) */
  static dryAt(x, z) { return landAt(x, z).w.breaks > 0.5; }
}
