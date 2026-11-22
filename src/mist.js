// Morning mist, the papercraft way: long torn sheets of cream tissue paper lying low over the fields at first
// light, a few hands above the grass. You can see the land through them, and their torn edges are fibrous.
// They drift slowly with the breeze and, as the sun gets up, lift away and thin out until by mid-morning
// they're gone. Not every morning: most, and always after a night of rain. One instanced mesh of 14 sheets
// around the farmer.
import * as THREE from 'three/webgpu';
import { texture, uv, uniform, float, mix, vec3 } from 'three/tsl';
import { getHeight } from './world.js';
import { mulberry32 } from './noise.js';

const N = 14;

function tissueTexture() {
  const W = 512, H = 192, c = document.createElement('canvas'); c.width = W; c.height = H;
  const g = c.getContext('2d'), rng = mulberry32(57);
  // a long, soft-ended torn sheet: the outline wanders, with a fibrous fringe
  g.fillStyle = '#fbf6ea';
  g.filter = 'blur(10px)'; // tissue: the torn edge is soft, the sheet thinner toward its rim
  g.beginPath();
  const pts = 64;
  for (let i = 0; i <= pts; i++) {
    const a = (i / pts) * Math.PI * 2;
    const r = 1 + (rng() - 0.5) * 0.12 + Math.sin(a * 3 + 1) * 0.06;
    g.lineTo(W / 2 + Math.cos(a) * (W * 0.46) * r, H / 2 + Math.sin(a) * (H * 0.4) * r);
  }
  g.closePath(); g.fill();
  g.filter = 'none';
  // fibres poking out of the torn edge, and thinner patches where the tissue is translucent
  g.strokeStyle = 'rgba(251,246,234,0.8)'; g.lineWidth = 1.2;
  for (let i = 0; i < 260; i++) {
    const a = rng() * Math.PI * 2, x = W / 2 + Math.cos(a) * W * 0.45, y = H / 2 + Math.sin(a) * H * 0.39, d = 4 + rng() * 10;
    g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(a + (rng() - 0.5)) * d, y + Math.sin(a + (rng() - 0.5)) * d); g.stroke();
  }
  g.globalCompositeOperation = 'destination-out';
  for (let i = 0; i < 18; i++) { g.fillStyle = `rgba(0,0,0,${0.15 + rng() * 0.25})`; g.beginPath(); g.ellipse(rng() * W, rng() * H, 20 + rng() * 60, 8 + rng() * 20, rng(), 0, Math.PI * 2); g.fill(); }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

export class Mist {
  constructor(scene) {
    const tex = tissueTexture();
    this.opacity = uniform(0);
    this.fenTint = uniform(0); // 0 = cream morning tissue, 1 = the fen's cold grey-green
    const m = new THREE.MeshLambertNodeMaterial({ transparent: true, depthWrite: false, side: THREE.DoubleSide });
    const tx = texture(tex, uv());
    m.colorNode = mix(tx.rgb, tx.rgb.mul(vec3(0.82, 0.9, 0.86)), this.fenTint);
    m.opacityNode = tx.a.mul(this.opacity);
    this.mesh = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), m, N);
    this.mesh.frustumCulled = false; this.mesh.count = 0; this.mesh.renderOrder = 2;
    scene.add(this.mesh);
    const rng = mulberry32(61);
    this.sheets = Array.from({ length: N }, () => ({ off: new THREE.Vector3((rng() - 0.5) * 60, 0, (rng() - 0.5) * 60), w: 9 + rng() * 9, d: 3 + rng() * 2.5, h: 1.1 + rng() * 1.4, rot: rng() * 0.6 - 0.3, ph: rng() * 6 }));
    this.anchor = null; this.day = -1; this.misty = false; this.t = 0; this.fen = 0;
  }

  /**
   * time: 0..1 day clock; rainedLastNight: was there a shower since dusk? fen: how deep in the Misty Fen the farmer
   * stands (0..1): there the mist never lifts, lying low and grey-green over the pools all day and night.
   */
  update(dt, center, sky, rainedLastNight, fen = 0) {
    this.t += dt;
    const time = sky.time;
    if (sky.day !== this.day && time > 0.18 && time < 0.24) {
      this.day = sky.day;
      this.misty = rainedLastNight || ((sky.day * 7919) % 10) < 6; // most mornings, every morning after rain
      this.anchor = center.clone();
    }
    // lies thick at first light (05:30–07:00), lifts and thins by about 09:30
    const k = time < 0.22 ? 0 : time < 0.29 ? 1 : time < 0.4 ? 1 - (time - 0.29) / 0.11 : 0;
    const lift = time < 0.29 ? 0 : Math.max(0, time - 0.29) / 0.11;
    this.fen += (fen - this.fen) * Math.min(1, dt * 0.5); // eases in as you walk into the fen
    const morning = this.misty ? k * 0.3 : 0, fenly = this.fen * 0.5;
    this.opacity.value = Math.max(morning, fenly);
    this.fenTint.value = fenly > morning ? Math.min(1, this.fen * 1.4) : 0;
    if (fenly > morning && !this.anchor) this.anchor = center.clone();
    if (this.opacity.value <= 0.005 || !this.anchor) { this.mesh.count = 0; return; }
    // re-centre if the farmer wanders far off
    if (this.anchor.distanceToSquared(center) > 35 * 35) this.anchor.copy(center);
    const drift = this.t * 0.35;
    for (let i = 0; i < N; i++) {
      const s = this.sheets[i];
      let x = this.anchor.x + s.off.x + drift, z = this.anchor.z + s.off.z + Math.sin(this.t * 0.05 + s.ph) * 2;
      x = this.anchor.x + ((((x - this.anchor.x) + 30) % 60) + 60) % 60 - 30; // wrap round the farmer
      const low = fenly > morning; // in the fen it hugs the water, a little lower and never lifting
      const y = Math.max(0, getHeight(x, z)) + (low ? s.h * 0.55 : s.h + lift * 2.5) + Math.sin(this.t * 0.3 + s.ph) * 0.08;
      _q.setFromEuler(_e.set(Math.sin(this.t * 0.2 + s.ph) * 0.03, s.rot, 0));
      _m.compose(_p.set(x, y, z), _q, _s.set(s.w, 1, s.d));
      this.mesh.setMatrixAt(i, _m);
    }
    this.mesh.count = N;
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _m = new THREE.Matrix4(), _s = new THREE.Vector3();
