// Pond frogs: little die-cut paper frogs (moss green with dark spots, a cream chin, gold eyes) squatting on the
// lily pads near the farmer. Walk up close and the nearest one leaps off in a high arc and plops into the
// water with a ring of ripples; a while later it hinges back up onto its pad. Toward dusk and through the night
// they croak now and then. All frogs are one instanced mesh, the ripples another.
import * as THREE from 'three/webgpu';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { propModel } from './modelfolk.js';
import { springRise, CHUNK } from './world.js';

const N = 8;
const FROG = [[-0.15, 0], [-0.18, 0.05], [-0.15, 0.1], [-0.08, 0.13], [0.0, 0.14], [0.06, 0.16], [0.09, 0.21], [0.13, 0.2], [0.15, 0.15], [0.18, 0.1], [0.15, 0.07], [0.1, 0.055], [0.11, 0.0], [0.06, 0.0], [0.05, 0.035], [0.0, 0.03], [-0.05, 0.0]];

export class Frogs {
  constructor(scene) {
    const art = paintCard(FROG, {
      W: 192, H: 128, seed: 431, base: '#6f8a4a', fills: ['rgba(120,148,80,A)', 'rgba(92,118,62,A)'], edge: 'rgba(50,40,24,1)',
      details(g, px) {
        g.fillStyle = 'rgba(52,70,36,0.8)'; // spots
        for (const [x, y, r] of [[-0.1, 0.08, 7], [-0.03, 0.11, 6], [0.03, 0.12, 5], [-0.12, 0.04, 5]]) { const [a, b] = px(x, y); g.beginPath(); g.arc(a, b, r, 0, Math.PI * 2); g.fill(); }
        g.fillStyle = '#e8dcb4'; { const p = [px(0.17, 0.09), px(0.1, 0.055), px(0.04, 0.04), px(0.1, 0.075)]; g.beginPath(); g.moveTo(...p[0]); for (const q of p) g.lineTo(...q); g.fill(); } // cream chin
        g.strokeStyle = 'rgba(50,40,24,0.75)'; g.lineWidth = 3; // haunch and the long folded back leg
        { const [a, b] = px(-0.13, 0.02), [c, d] = px(-0.04, 0.09), [e, f] = px(0.02, 0.01); g.beginPath(); g.moveTo(a, b); g.quadraticCurveTo(c, d, e, f); g.stroke(); }
        { const [a, b] = px(0.17, 0.095), [c, d] = px(0.1, 0.085); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); } // the smile
        const [ex, ey] = px(0.11, 0.17); // a gold eye on top of the head
        g.fillStyle = '#d9a43a'; g.beginPath(); g.arc(ex, ey, 9, 0, Math.PI * 2); g.fill();
        g.fillStyle = '#2a2018'; g.beginPath(); g.ellipse(ex, ey, 6, 3, 0, 0, Math.PI * 2); g.fill();
      },
    });
    // the bullfrog from the reference art, baked to one geometry: nose along +x, profile to +z, feet at 0, the card's length
    let geo = cardGeometry(FROG, 0.012), mat = cardMaterial(art, { side: THREE.DoubleSide });
    const src = propModel('animal_frog');
    if (src) {
      let g = null, mm = null; src.scene.updateWorldMatrix(true, true);
      src.scene.traverse((o) => { if (o.isMesh && !g) { g = o.geometry.clone().applyMatrix4(o.matrixWorld); mm = o.material; } });
      if (g) { g.rotateY(Math.PI / 2); g.computeBoundingBox(); const b = g.boundingBox, k = 0.3 / (b.max.x - b.min.x); g.translate(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2).scale(k, k, k); geo = g; mat = mm; }
    }
    this.mesh = new THREE.InstancedMesh(geo, mat, N);
    this.mesh.castShadow = true; this.mesh.frustumCulled = false; this.mesh.count = 0;
    scene.add(this.mesh);
    // ripple rings, flat on the water
    this.rings = new THREE.InstancedMesh(new THREE.RingGeometry(0.9, 1, 28).rotateX(-Math.PI / 2),
      new THREE.MeshBasicNodeMaterial({ color: 0x4f6f78, transparent: true, opacity: 0.4, depthWrite: false }), N * 2);
    this.rings.frustumCulled = false; this.rings.count = 0;
    scene.add(this.rings);
    this.frogs = Array.from({ length: N }, (_, i) => ({ pad: null, state: 'sit', t: 0, side: i % 2 ? 1 : -1, from: new THREE.Vector3(), to: new THREE.Vector3(), croakT: 3 + Math.random() * 20 }));
    this.ripples = []; // { x, y, z, t }
    this.scanT = 0;
    this.onCroak = null; this.onPlop = null;
  }

  /** Lily pads within reach, nearest first (decor resources of the loaded chunks). */
  pads(world, at) {
    const out = [];
    for (const ch of world.chunks.values()) {
      if (Math.abs((ch.cx + 0.5) * CHUNK - at.x) > CHUNK + 30 || Math.abs((ch.cz + 0.5) * CHUNK - at.z) > CHUNK + 30) continue;
      for (const r of ch.resources) if ((r.type === 'lilypad' || r.type === 'lilybloom') && r.alive) {
        const d = Math.hypot(r.x - at.x, r.z - at.z);
        if (d < 30) out.push([d, r]);
      }
    }
    return out.sort((a, b) => a[0] - b[0]).map(([, r]) => r);
  }

  update(dt, { world, player, camera, night, snow }) {
    // every couple of seconds, settle frogs onto the nearest free pads (some pads stay empty)
    if ((this.scanT -= dt) <= 0) {
      this.scanT = 2;
      const pads = snow > 0.3 ? [] : this.pads(world, player.pos).filter((r, i) => i % 2 === 0); // every other pad: never crowded
      const keep = new Set(pads);
      for (const f of this.frogs) if (f.pad && (!keep.has(f.pad))) { if (f.state === 'sit') f.pad = null; }
      const used = new Set(this.frogs.map((f) => f.pad).filter(Boolean));
      for (const f of this.frogs) if (!f.pad) {
        const p = pads.find((r) => !used.has(r));
        if (!p) break;
        f.pad = p; used.add(p); f.state = 'rise'; f.t = 0;
      }
    }
    let n = 0;
    const yawToCam = (x, z) => Math.atan2(camera.position.x - x, camera.position.z - z);
    for (const f of this.frogs) {
      if (!f.pad) continue;
      f.t += dt;
      const P = f.pad, x = P.x, z = P.z, y = P.y + 0.02;
      const near = Math.hypot(player.pos.x - x, player.pos.z - z) < 3.6;
      let px = x, py = y, pz = z, pitch = 0, rise = 1;
      if (f.state === 'rise') { rise = springRise(f.t * 1.2); if (f.t > 1.2) { f.state = 'sit'; f.t = 0; } }
      else if (f.state === 'sit' && near) {
        // leap away from the farmer, out over open water
        f.state = 'leap'; f.t = 0;
        const ax = x - player.pos.x, az = z - player.pos.z, l = Math.hypot(ax, az) || 1;
        f.from.set(x, y, z); f.to.set(x + (ax / l) * 1.6, y - 0.05, z + (az / l) * 1.6);
        f.side = ax * Math.cos(yawToCam(x, z)) - az * Math.sin(yawToCam(x, z)) > 0 ? 1 : -1;
      } else if (f.state === 'sit') {
        // the odd croak at dusk and by night (the throat puffs), quieter the farther off
        if (night > 0.3 && (f.croakT -= dt) <= 0) { f.croakT = 14 + Math.random() * 30; f.puff = 0.5; this.onCroak?.(Math.max(0.2, 1 - Math.hypot(player.pos.x - x, player.pos.z - z) / 30)); }
      }
      if (f.state === 'leap') {
        const k = Math.min(1, f.t / 0.55);
        px = f.from.x + (f.to.x - f.from.x) * k; pz = f.from.z + (f.to.z - f.from.z) * k;
        py = f.from.y + (f.to.y - f.from.y) * k + Math.sin(k * Math.PI) * 0.9;
        pitch = (0.6 - k * 1.4);
        if (k >= 1) { f.state = 'under'; f.t = 0; this.ripples.push({ x: f.to.x, y: f.to.y + 0.06, z: f.to.z, t: 0 }, { x: f.to.x, y: f.to.y + 0.06, z: f.to.z, t: -0.35 }); this.onPlop?.(); }
      }
      if (f.state === 'under') { if (f.t > 18 && !near) { f.state = 'rise'; f.t = 0; } continue; }
      f.puff = Math.max(0, (f.puff || 0) - dt);
      const puff = 1 + Math.sin(Math.min(1, f.puff / 0.5) * Math.PI * 2) * 0.08 * (f.puff > 0 ? 1 : 0);
      _p.set(px, py, pz);
      // hinged up from lying flat on the pad (rotation about its base), facing the camera, nose left or right
      _e.set(-(1 - rise) * (Math.PI / 2), yawToCam(px, pz), pitch * f.side, 'YXZ');
      _q.setFromEuler(_e);
      _s.set(2.2 * f.side, 2.2 * puff, 2.2);
      _m.compose(_p, _q, _s);
      this.mesh.setMatrixAt(n++, _m);
    }
    this.mesh.count = n;
    if (n) this.mesh.instanceMatrix.needsUpdate = true;
    // ripples spread and fade
    let r = 0;
    this.ripples = this.ripples.filter((w) => (w.t += dt) < 1.4);
    for (const w of this.ripples) {
      if (w.t < 0) continue;
      const s = 0.15 + w.t * 0.7;
      _m.makeScale(s, 1, s).setPosition(w.x, w.y, w.z);
      this.rings.setMatrixAt(r++, _m);
    }
    this.rings.count = r;
    if (r) this.rings.instanceMatrix.needsUpdate = true;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _m = new THREE.Matrix4(), _s = new THREE.Vector3();
