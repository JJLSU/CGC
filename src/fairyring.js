// Fairy rings: the morning after a rainy night, a ring of red-capped toadstools comes up overnight in a meadow
// not far from the farmer, nine of them in a circle a few paces across, hinging up out of the grass one by one.
// A note mentions it (old folks say a ring comes up after a wet night, and it's lucky to find one). Step into the
// middle and press E to gather them: a basket of mushrooms, and now and then the luck folks talk about. The ring
// is gone by evening if nobody finds it.
import * as THREE from 'three/webgpu';
import { cardGeometry } from './props.js';
import { cardMaterial } from './materials.js';
import { paintCard } from './textures.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { getHeight, isWater, regionAt, springRise } from './world.js';

const N = 9;
const DIRS = ['east', 'north-east', 'north', 'north-west', 'west', 'south-west', 'south', 'south-east'];

export class FairyRing {
  constructor(scene) {
    // one plump toadstool: a pale stem with a little skirt, a red domed cap with cream spots (crossed cards)
    const pts = [[-0.05, 0], [0.05, 0], [0.045, 0.14], [0.08, 0.15], [0.05, 0.17], [0.05, 0.21], [0.19, 0.22], [0.17, 0.29], [0.1, 0.35], [0, 0.37], [-0.1, 0.35], [-0.17, 0.29], [-0.19, 0.22], [-0.05, 0.21], [-0.05, 0.17], [-0.08, 0.15], [-0.045, 0.14]];
    const art = paintCard(pts, {
      W: 128, H: 128, seed: 281, base: '#efe3c4', fills: ['rgba(239,227,196,A)'], edge: 'rgba(90,40,30,1)',
      details(g, px) {
        g.fillStyle = '#c4362f'; g.beginPath(); [[0.19, 0.22], [0.17, 0.29], [0.1, 0.35], [0, 0.37], [-0.1, 0.35], [-0.17, 0.29], [-0.19, 0.22]].forEach(([x, y], i) => { const [a, b] = px(x, y); i ? g.lineTo(a, b) : g.moveTo(a, b); }); g.closePath(); g.fill();
        g.fillStyle = '#f6efe0'; for (const [x, y, r] of [[-0.09, 0.28, 6], [0.04, 0.32, 5], [0.11, 0.26, 5], [-0.02, 0.25, 4]]) { const [a, b] = px(x, y); g.beginPath(); g.arc(a, b, r, 0, Math.PI * 2); g.fill(); }
      },
    });
    const geo = mergeGeometries([cardGeometry(pts, 0.02), cardGeometry(pts, 0.02).rotateY(Math.PI / 2)]);
    this.mesh = new THREE.InstancedMesh(geo, cardMaterial(art), N);
    this.mesh.castShadow = true; this.mesh.count = 0; this.mesh.frustumCulled = false;
    scene.add(this.mesh);
    this.at = new THREE.Vector3(); this.day = -1; this.state = 'none'; this.t = 0; this.R = 1.7;
  }

  near(pos) { return this.state === 'up' && Math.hypot(pos.x - this.at.x, pos.z - this.at.z) < this.R + 0.6; }

  /** Morning after a wet night: a ring comes up somewhere 25–50 m off. Returns the direction word, or null. */
  sprout(day, from) {
    for (let tries = 0; tries < 30; tries++) {
      const a = Math.random() * Math.PI * 2, d = 25 + Math.random() * 25;
      const x = from.x + Math.cos(a) * d, z = from.z + Math.sin(a) * d;
      if (isWater(x, z) || regionAt(x, z) !== 'meadow') continue;
      this.at.set(x, getHeight(x, z), z); this.day = day; this.state = 'up'; this.t = 0;
      return DIRS[((Math.round(Math.atan2(-(z - from.z), x - from.x) / (Math.PI / 4)) % 8) + 8) % 8];
    }
    return null;
  }

  gather() { this.state = 'none'; this.mesh.count = 0; }

  update(dt, sky) {
    if (this.state !== 'up') return;
    if (sky.day !== this.day || sky.time > 0.8) { this.gather(); return; } // gone by evening
    this.t += dt;
    for (let i = 0; i < N; i++) {
      const a = (i / N) * Math.PI * 2;
      const x = this.at.x + Math.cos(a) * this.R, z = this.at.z + Math.sin(a) * this.R;
      const k = springRise(Math.max(0, this.t * 1.2 - i * 0.12)); // hinging up out of the grass one by one, round the ring
      _p.set(x, getHeight(x, z), z);
      _q.setFromEuler(_e.set(-(1 - k) * Math.PI / 2, a * 1.7, 0));
      _m.compose(_p, _q, _s.setScalar(1.5 + ((i * 7) % 5) * 0.12));
      this.mesh.setMatrixAt(i, _m);
    }
    this.mesh.count = N;
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _m = new THREE.Matrix4(), _s = new THREE.Vector3();
