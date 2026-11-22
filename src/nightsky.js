// The night sky of a pop-up book: die-cut paper stars (cream and old gold, each with its printed rays and a
// cut edge) and a paper crescent moon with a sleepy man-in-the-moon face. At dusk they turn in on their
// creases one by one, from edge-on to facing you, and at dawn they turn away again. They hang far out on
// the sky, follow the camera like the dome does, and only exist after dark.
import * as THREE from 'three/webgpu';
import { texture, uniform, vec3, uv } from 'three/tsl';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { springRise } from './world.js';
import { mulberry32 } from './noise.js';

const N = 70, R = 380;

function starShape(points = 5, r0 = 0.42, r1 = 1) {
  const pts = [];
  for (let k = 0; k < points * 2; k++) {
    const a = Math.PI / 2 + (k * Math.PI) / points, r = k % 2 ? r0 : r1;
    pts.push([Math.cos(a) * r, Math.sin(a) * r]);
  }
  return pts;
}

function crescentShape() {
  // outer arc minus an offset inner arc, as one outline: a fat, friendly crescent opening to the right
  const pts = [];
  for (let k = 0; k <= 24; k++) { const a = Math.PI * 0.32 + (k / 24) * Math.PI * 1.36; pts.push([Math.cos(a), Math.sin(a)]); }
  for (let k = 24; k >= 0; k--) { const a = Math.PI * 0.42 + (k / 24) * Math.PI * 1.16; pts.push([0.42 + Math.cos(a) * 0.82, Math.sin(a) * 0.82]); }
  return pts;
}

const basic = (map, glow) => {
  const m = new THREE.MeshBasicNodeMaterial({ side: THREE.DoubleSide, fog: false, transparent: false });
  m.colorNode = texture(map, uv()).rgb.mul(glow);
  return m;
};

export class NightSky {
  constructor(scene) {
    this.glow = uniform(1.15);
    const star = starShape();
    const starArt = paintCard(star, {
      W: 128, H: 128, seed: 171, base: '#f3e6b8', fills: ['rgba(246,234,190,A)', 'rgba(228,206,140,A)'], edge: 'rgba(120,90,40,1)',
      details(g, px) {
        g.strokeStyle = 'rgba(190,150,70,0.7)'; g.lineWidth = 3; // a printed ray down each point
        for (let k = 0; k < 5; k++) { const a = Math.PI / 2 + (k * 2 * Math.PI) / 5; const [x0, y0] = px(0, 0), [x1, y1] = px(Math.cos(a) * 0.8, Math.sin(a) * 0.8); g.beginPath(); g.moveTo(x0, y0); g.lineTo(x1, y1); g.stroke(); }
        g.fillStyle = '#e8c870'; const [cx, cy] = px(0, 0); g.beginPath(); g.arc(cx, cy, 10, 0, Math.PI * 2); g.fill();
      },
    });
    this.stars = new THREE.InstancedMesh(cardGeometry(star, 0.06), basic(starArt, this.glow), N);
    this.stars.frustumCulled = false; this.stars.count = 0;
    const c = new THREE.Color();
    const rng = mulberry32(919);
    this.list = Array.from({ length: N }, (_, i) => {
      const az = rng() * Math.PI * 2, el = THREE.MathUtils.degToRad(14 + Math.pow(rng(), 0.8) * 66);
      this.stars.setColorAt(i, c.setHSL(0.12, 0.5, 0.82 + rng() * 0.18));
      return { dir: new THREE.Vector3(Math.cos(el) * Math.cos(az), Math.sin(el), Math.cos(el) * Math.sin(az)), size: 2.6 + rng() * 3.6, delay: rng() * 2.5, spin: rng() * 6.28, ph: rng() * 6.28 };
    });
    scene.add(this.stars);

    const cres = crescentShape();
    const moonArt = paintCard(cres, {
      W: 256, H: 256, seed: 173, base: '#f1e4bc', fills: ['rgba(244,232,196,A)', 'rgba(222,206,160,A)'], edge: 'rgba(110,84,44,1)',
      details(g, px) {
        g.fillStyle = 'rgba(200,180,130,0.55)'; // a few printed craters
        for (const [x, y, r] of [[-0.7, 0.3, 12], [-0.55, -0.45, 9], [-0.82, -0.1, 7], [-0.3, 0.78, 8]]) { const [a, b] = px(x, y); g.beginPath(); g.arc(a, b, r, 0, Math.PI * 2); g.fill(); }
        // the man in the moon, dozing: a closed eye, a nose bump, a small smile along the inner edge
        g.strokeStyle = 'rgba(80,58,34,0.85)'; g.lineWidth = 3.5;
        { const [a, b] = px(-0.32, 0.22); g.beginPath(); g.arc(a, b, 9, 0.15 * Math.PI, 0.85 * Math.PI); g.stroke(); }
        { const [a, b] = px(-0.32, -0.32); g.beginPath(); g.arc(a, b, 12, -0.9 * Math.PI, -0.35 * Math.PI); g.stroke(); }
        g.fillStyle = 'rgba(214,130,110,0.5)'; { const [a, b] = px(-0.42, -0.12); g.beginPath(); g.arc(a, b, 9, 0, Math.PI * 2); g.fill(); } // a rosy cheek
      },
    });
    // the harvest moon: on the eve of the County Fair the same card rises big, low and pumpkin-gold
    this.moonTint = uniform(new THREE.Color(1, 1, 1));
    const moonMat = basic(moonArt, this.glow);
    moonMat.colorNode = moonMat.colorNode.mul(this.moonTint);
    this.moon = new THREE.Mesh(cardGeometry(cres, 0.05), moonMat);
    this.harvest = false;
    // ...and on that night it's a full moon: a round card with craters and the man in the moon smiling
    const disc = Array.from({ length: 32 }, (_, i) => { const t = (i / 32) * Math.PI * 2; return [Math.cos(t), Math.sin(t)]; });
    const fullArt = paintCard(disc, {
      W: 256, H: 256, seed: 175, base: '#f1e4bc', fills: ['rgba(244,232,196,A)', 'rgba(222,206,160,A)'], edge: 'rgba(110,84,44,1)',
      details(g, px) {
        g.fillStyle = 'rgba(200,180,130,0.5)';
        for (const [x, y, r] of [[-0.55, 0.45, 16], [0.5, -0.5, 12], [0.62, 0.3, 9], [-0.3, -0.62, 10], [0.15, 0.7, 8]]) { const [a, b] = px(x, y); g.beginPath(); g.arc(a, b, r, 0, Math.PI * 2); g.fill(); }
        g.strokeStyle = 'rgba(80,58,34,0.85)'; g.lineWidth = 4;
        for (const ex of [-0.3, 0.3]) { const [a, b] = px(ex, 0.2); g.beginPath(); g.arc(a, b, 12, 0.15 * Math.PI, 0.85 * Math.PI); g.stroke(); } // dozing eyes
        { const [a, b] = px(0, -0.25); g.beginPath(); g.arc(a, b, 30, 0.2 * Math.PI, 0.8 * Math.PI); g.stroke(); } // a broad smile
        g.fillStyle = 'rgba(214,130,110,0.45)'; for (const ex of [-0.48, 0.48]) { const [a, b] = px(ex, -0.08); g.beginPath(); g.arc(a, b, 14, 0, Math.PI * 2); g.fill(); }
      },
    });
    const fullMat = basic(fullArt, this.glow); fullMat.colorNode = fullMat.colorNode.mul(this.moonTint);
    this.fullMoon = new THREE.Mesh(cardGeometry(disc, 0.05), fullMat);
    this.fullMoon.frustumCulled = false; this.fullMoon.visible = false;
    scene.add(this.fullMoon);
    this.moon.frustumCulled = false; this.moon.visible = false;
    scene.add(this.moon);
    this.t = 0;      // seconds of "night is on" (runs back down at dawn)
    this.clock = 0;
  }

  update(dt, camera, sunDir, night, harvest = false) {
    this.harvest = harvest;
    this.clock += dt;
    const on = night > 0.6;
    this.t = on ? Math.min(this.t + dt, 6) : Math.max(this.t - dt * 1.5, 0);
    if (this.t <= 0) { this.stars.count = 0; this.moon.visible = false; this.fullMoon.visible = false; return; }
    const cam = camera.position;
    let n = 0;
    for (let i = 0; i < N; i++) {
      const s = this.list[i];
      const k = springRise(Math.max(0, this.t - s.delay) * 1.1); // turning in on its crease, a quiver at the end
      if (k <= 0.001) continue;
      _p.copy(s.dir).multiplyScalar(R).add(cam);
      _m.lookAt(cam, _p, _up);                                    // face the camera...
      _q.setFromRotationMatrix(_m);
      _q2.setFromAxisAngle(_y, (1 - k) * (Math.PI / 2));          // ...turned from edge-on
      _q.multiply(_q2);
      _q2.setFromAxisAngle(_z, s.spin + Math.sin(this.clock * 0.6 + s.ph) * 0.06); // and a slow twinkle-rock
      _q.multiply(_q2);
      _m.compose(_p, _q, _s.setScalar(s.size));
      this.stars.setMatrixAt(n++, _m);
    }
    this.stars.count = n;
    this.stars.instanceMatrix.needsUpdate = true;
    // the moon rides opposite the sun, when it's up
    const md = _d.copy(sunDir).negate();
    if (harvest) { md.y = Math.max(md.y, 0.08) * 0.35 + 0.06; md.normalize(); } // it hangs low over the fields all night
    this.moonTint.value.setRGB(harvest ? 1.15 : 1, harvest ? 0.78 : 1, harvest ? 0.45 : 1);
    this.moon.visible = md.y > -0.03;
    if (this.moon.visible) {
      const k = springRise(this.t * 0.9);
      _p.copy(md).multiplyScalar(R * 0.98).add(cam);
      this.moon.position.copy(_p);
      _m.lookAt(cam, _p, _up); this.moon.quaternion.setFromRotationMatrix(_m);
      this.moon.quaternion.multiply(_q2.setFromAxisAngle(_y, (1 - k) * (Math.PI / 2))).multiply(_q.setFromAxisAngle(_z, -0.35));
      this.moon.scale.setScalar(21);
    }
    // the harvest night swaps the crescent for the full moon card (same place, same turn-in)
    this.fullMoon.visible = this.moon.visible && harvest;
    if (this.fullMoon.visible) {
      this.fullMoon.position.copy(this.moon.position); this.fullMoon.quaternion.copy(this.moon.quaternion);
      this.fullMoon.scale.setScalar(24); this.moon.visible = false;
    }
  }
}

const _p = new THREE.Vector3(), _d = new THREE.Vector3(), _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _q2 = new THREE.Quaternion();
const _s = new THREE.Vector3(), _up = new THREE.Vector3(0, 1, 0), _y = new THREE.Vector3(0, 1, 0), _z = new THREE.Vector3(0, 0, 1);
