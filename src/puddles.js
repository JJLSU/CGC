// Rain on the ground: while a shower lasts, torn-paper puddles (a grey-blue sheet with a pale sky-gleam stroke
// and a darker wet rim) gather on the gentler stretches of the footpaths near the farmer, lying flush with the ground (never on a hillside), and dry away over a
// few minutes once it stops. On ponds, little rings of rain open and spread across the water all around you.
// Two instanced meshes; nothing runs on a dry day.
import * as THREE from 'three/webgpu';
import { texture, uv, uniform } from 'three/tsl';
import { getHeight, isWater, pathField } from './world.js';
import { mulberry32 } from './noise.js';

const PUDDLES = 18, RINGS = 40;

function puddleTexture() {
  const W = 256, H = 160, c = document.createElement('canvas'); c.width = W; c.height = H;
  const g = c.getContext('2d'), rng = mulberry32(251);
  const blob = (sx, sy, fill) => {
    g.fillStyle = fill; g.beginPath();
    for (let i = 0; i <= 40; i++) { const a = (i / 40) * Math.PI * 2, r = 1 + (rng() - 0.5) * 0.14 + Math.sin(a * 3 + 2) * 0.1; g.lineTo(W / 2 + Math.cos(a) * sx * r, H / 2 + Math.sin(a) * sy * r); }
    g.closePath(); g.fill();
  };
  blob(W * 0.47, H * 0.45, '#5b6c74');            // the wet rim: darker mud-soaked paper
  blob(W * 0.42, H * 0.38, '#8fa6ae');            // the water: grey-blue
  g.strokeStyle = 'rgba(236,240,236,0.75)'; g.lineWidth = 5; g.lineCap = 'round'; // a pale gleam of sky
  g.beginPath(); g.moveTo(W * 0.3, H * 0.38); g.quadraticCurveTo(W * 0.45, H * 0.3, W * 0.62, H * 0.36); g.stroke();
  g.lineWidth = 3; g.beginPath(); g.moveTo(W * 0.55, H * 0.6); g.lineTo(W * 0.68, H * 0.58); g.stroke();
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

export class Puddles {
  constructor(scene) {
    const tex = puddleTexture();
    this.wet = uniform(0);
    const m = new THREE.MeshLambertNodeMaterial({ transparent: true, depthWrite: false });
    const tx = texture(tex, uv());
    m.colorNode = tx.rgb; m.opacityNode = tx.a.mul(this.wet);
    m.polygonOffset = true; m.polygonOffsetFactor = -2;
    this.puddles = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), m, PUDDLES);
    this.puddles.frustumCulled = false; this.puddles.count = 0; this.puddles.receiveShadow = true;
    scene.add(this.puddles);
    this.rings = new THREE.InstancedMesh(new THREE.RingGeometry(0.88, 1, 20).rotateX(-Math.PI / 2),
      new THREE.MeshBasicNodeMaterial({ color: 0xdfe8e6, transparent: true, opacity: 0.5, depthWrite: false }), RINGS);
    this.rings.frustumCulled = false; this.rings.count = 0;
    scene.add(this.rings);
    this.spots = []; this.anchor = new THREE.Vector3(1e9, 0, 0);
    this.drops = Array.from({ length: RINGS }, () => ({ x: 0, y: 0, z: 0, t: 1 + Math.random() }));
    this.level = 0;
  }

  /** Find puddle spots on the footpaths around the farmer (re-done when they wander off). */
  place(center) {
    this.anchor.copy(center); this.spots = [];
    const rng = mulberry32((Math.floor(center.x / 10) * 7919) ^ Math.floor(center.z / 10));
    for (let tries = 0; tries < 400 && this.spots.length < PUDDLES; tries++) {
      const a = rng() * Math.PI * 2, d = 3 + rng() * 26, x = center.x + Math.cos(a) * d, z = center.z + Math.sin(a) * d;
      if (isWater(x, z) || pathField(x, z) > 0.06) continue; // only in the lanes, where the ruts hold water
      if (this.spots.some((s) => Math.hypot(s.x - x, s.z - z) < 2.5)) continue;
      const w = 1.2 + rng() * 1.6, dd = 0.7 + rng() * 0.8, rot = rng() * Math.PI;
      // water lies flush on gentle ground: tilt the sheet to the slope under it, and skip hillsides (too steep)
      // and humps or hollows (where a flat sheet would float off the ground or sink into it)
      const cs = Math.cos(rot), sn = Math.sin(rot), y0 = getHeight(x, z), e = 0.5;
      const gx = (getHeight(x + e, z) - getHeight(x - e, z)) / (2 * e), gz = (getHeight(x, z + e) - getHeight(x, z - e)) / (2 * e);
      if (Math.hypot(gx, gz) > 0.2) continue;
      let bend = 0;
      for (const [u, v] of [[0.5, 0], [-0.5, 0], [0, 0.5], [0, -0.5], [0.35, 0.35], [-0.35, 0.35], [0.35, -0.35], [-0.35, -0.35]]) {
        const lx = u * w, lz = v * dd, px = x + lx * cs + lz * sn, pz = z - lx * sn + lz * cs;
        bend = Math.max(bend, Math.abs(getHeight(px, pz) - (y0 + gx * (px - x) + gz * (pz - z))));
      }
      if (bend > 0.035) continue;
      const n = new THREE.Vector3(-gx, 1, -gz).normalize();
      const q = new THREE.Quaternion().setFromUnitVectors(_y, n).multiply(new THREE.Quaternion().setFromAxisAngle(_y, rot));
      this.spots.push({ x, z, y: y0 + 0.025, w, d: dd, rot, q, bend });
    }
  }

  update(dt, center, rain, snowing) {
    // puddles fill in a minute or so of rain and take about two minutes to dry
    const target = rain > 0.3 && !snowing ? 1 : 0;
    this.level += (target - this.level) * Math.min(1, dt * (target ? 0.03 : 0.012));
    if (this.level < 0.01 && rain < 0.05) { this.puddles.count = 0; this.rings.count = 0; return; }
    if (this.anchor.distanceToSquared(center) > 18 * 18) this.place(center);
    this.wet.value = Math.min(1, this.level * 1.2);
    let n = 0;
    for (const s of this.spots) {
      const k = 0.6 + 0.4 * this.level; // they spread a little as they fill
      _m.compose(_p.set(s.x, s.y, s.z), s.q, _s.set(s.w * k, 1, s.d * k));
      this.puddles.setMatrixAt(n++, _m);
    }
    this.puddles.count = n; this.puddles.instanceMatrix.needsUpdate = true;
    // rain rings on the ponds (and in the puddles), only while it's actually raining
    let r = 0;
    if (rain > 0.2 && !snowing) {
      for (const d of this.drops) {
        d.t += dt * 1.6;
        if (d.t >= 1) {
          d.t = Math.random() * 0.2;
          if (Math.random() < 0.35 && this.spots.length) { const s = this.spots[Math.floor(Math.random() * this.spots.length)]; d.x = s.x + (Math.random() - 0.5) * s.w * 0.6; d.z = s.z + (Math.random() - 0.5) * s.d * 0.6; d.y = s.y + 0.01; }
          else {
            const a = Math.random() * Math.PI * 2, dd = 2 + Math.random() * 20; d.x = center.x + Math.cos(a) * dd; d.z = center.z + Math.sin(a) * dd;
            if (!isWater(d.x, d.z)) { d.t = 1; continue; }
            d.y = getHeight(d.x, d.z) + 0.05;
          }
        }
        const sc = 0.05 + d.t * 0.35;
        _m.makeScale(sc, 1, sc).setPosition(d.x, d.y, d.z);
        this.rings.setMatrixAt(r++, _m);
      }
    }
    this.rings.count = r; if (r) this.rings.instanceMatrix.needsUpdate = true;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _m = new THREE.Matrix4(), _s = new THREE.Vector3(), _y = new THREE.Vector3(0, 1, 0);
