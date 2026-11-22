// Canada geese going over: every few minutes by day a skein of seven paper geese crosses the sky in a V,
// high over the farmer, honking now and then; their little shadows slide across the land below. Built to read
// from above like the crows: a flat grey-brown back with a pale breast, a black neck and head with the white
// chinstrap, and two broad wings hinged at the shoulders that beat slowly, each bird a beat out of step.
import * as THREE from 'three/webgpu';
import { getHeight } from './world.js';
import { paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';

const N = 7, HEIGHT = 16, SPEED = 8.5;

function parts() {
  const flat = (pts, t = 0.02) => cardGeometry(pts, t).rotateX(-Math.PI / 2);
  return {
    // body from above, nose toward +x: a plump teardrop with a short dark tail
    back: flat([[0.3, 0], [0.2, 0.11], [0, 0.15], [-0.26, 0.12], [-0.42, 0.05], [-0.48, 0], [-0.42, -0.05], [-0.26, -0.12], [0, -0.15], [0.2, -0.11]]),
    breast: flat([[0.28, 0], [0.18, 0.08], [0.02, 0.1], [0.02, -0.1], [0.18, -0.08]], 0.022),
    tail: flat([[-0.4, 0.06], [-0.56, 0.08], [-0.6, 0], [-0.56, -0.08], [-0.4, -0.06]], 0.024),
    neck: flat([[0.26, 0.04], [0.52, 0.04], [0.62, 0.06], [0.7, 0.03], [0.72, 0], [0.7, -0.03], [0.62, -0.06], [0.52, -0.04], [0.26, -0.04]], 0.024),
    chin: flat([[0.56, 0.035], [0.64, 0.045], [0.64, -0.045], [0.56, -0.035]], 0.026),
    // a broad wing reaching out to +z, hinged along the body's side
    wing: flat([[0.16, 0], [-0.14, 0], [-0.3, 0.5], [-0.12, 0.72], [0.08, 0.5]], 0.016),
  };
}

export class Geese {
  constructor(scene) {
    const P = parts();
    const mat = {
      back: paperMaterial({ color: 0x7d6c5a }), breast: paperMaterial({ color: 0xd8ccb4 }), ink: paperMaterial({ color: 0x2a2420 }),
      chin: paperMaterial({ color: 0xf3ead6 }), wing: paperMaterial({ color: 0x6a5a4a, side: THREE.DoubleSide }),
    };
    this.birds = [];
    for (let i = 0; i < N; i++) {
      const g = new THREE.Group();
      const m = (geo, mt) => { const x = new THREE.Mesh(geo, mt); x.castShadow = geo === P.back; g.add(x); return x; }; // one little shadow per bird is plenty
      m(P.back, mat.back); m(P.breast, mat.breast); m(P.tail, mat.ink); m(P.neck, mat.ink); m(P.chin, mat.chin);
      const wl = m(P.wing, mat.wing), wr = m(P.wing, mat.wing);
      wl.position.z = 0.12; wr.position.z = -0.12; wr.scale.z = -1;
      g.scale.setScalar(2.2); g.visible = false;
      scene.add(g);
      this.birds.push({ g, wl, wr, phase: Math.random() * 6 });
    }
    this.timer = 70 + Math.random() * 60;
    this.flying = false;
    this.lead = new THREE.Vector3(); this.dir = new THREE.Vector3(); this.side = new THREE.Vector3();
    this.t = 0; this.honkT = 0;
    this.onHonk = null; this.onFirst = null; this.seen = false;
  }

  update(dt, center, sky) {
    if (!this.flying) {
      if ((this.timer -= dt) > 0 || sky.night > 0.35) return;
      this.timer = 160 + Math.random() * 160;
      // across the sky, more or less southward with the season, passing near overhead
      const a = Math.PI / 2 + (Math.random() - 0.5) * 1.4;
      this.dir.set(Math.cos(a), 0, Math.sin(a));
      this.side.set(-this.dir.z, 0, this.dir.x);
      const off = (Math.random() - 0.5) * 16;
      this.lead.set(center.x - this.dir.x * 75 + this.side.x * off, 0, center.z - this.dir.z * 75 + this.side.z * off);
      this.flying = true; this.t = 0; this.honkT = 1.5;
      for (const b of this.birds) b.g.visible = true;
    }
    this.t += dt;
    this.lead.addScaledVector(this.dir, SPEED * dt);
    const yaw = Math.atan2(-this.dir.z, this.dir.x);
    const ground = getHeight(this.lead.x, this.lead.z);
    this.birds.forEach((b, i) => {
      // the V: the leader at the point, the rest trailing back along two arms
      const rank = Math.ceil(i / 2), arm = i === 0 ? 0 : i % 2 ? 1 : -1;
      const x = this.lead.x - this.dir.x * rank * 1.7 + this.side.x * arm * rank * 1.4;
      const z = this.lead.z - this.dir.z * rank * 1.7 + this.side.z * arm * rank * 1.4;
      b.g.position.set(x, Math.max(ground, 0) + HEIGHT + Math.sin(this.t * 0.8 + i) * 0.25, z);
      b.g.rotation.y = yaw;
      const flap = Math.sin(this.t * 5.2 + b.phase) * 0.55;
      b.wl.rotation.x = -flap; b.wr.rotation.x = flap;
    });
    if ((this.honkT -= dt) <= 0) { this.honkT = 2.5 + Math.random() * 3; this.onHonk?.(); }
    if (!this.seen && Math.hypot(this.lead.x - center.x, this.lead.z - center.z) < 30) { this.seen = true; this.onFirst?.(); }
    if (this.t > 150 / SPEED + 4) { this.flying = false; for (const b of this.birds) b.g.visible = false; }
  }
}
