// Passing showers. Every few minutes the clouds roll in and a soft rain of thin paper slivers falls around
// the farmer for a minute or two; the light goes grey and gentle, the rain hisses, crops and woods regrow
// faster and the fish bite sooner. Cheap: one instanced mesh of ≤ 420 crossed slivers near the camera focus.
import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { paperMaterial } from './materials.js';
import { getHeight } from './world.js';

const MAX = 420, BOX = 34, TOP = 16, FALL = 13;

export class Weather {
  constructor(scene) {
    this.rain = 0;       // 0 … 1, eased (rain or snow falling)
    this.kind = 'rain';  // 'rain' | 'snow'
    this.snow = 0;       // 0 … 1, snow lying on the ground (builds while it snows, melts slowly after)
    this.target = 0;
    this.next = 200 + Math.random() * 160; // seconds until the first shower
    this.nextKind = Math.random() < 0.35 ? 'snow' : 'rain'; // decided ahead, so the barn's weathervane can tell
    this.nextStorm = this.nextKind === 'rain' && Math.random() < 0.28; // about one shower in four is a thunderstorm
    this.storm = false;
    this.left = 0;
    this.onStart = null; this.onEnd = null;
    const a = new THREE.PlaneGeometry(0.035, 0.6), b = new THREE.PlaneGeometry(0.035, 0.6).rotateY(Math.PI / 2);
    const geo = mergeGeometries([a, b]);
    const mat = paperMaterial({ color: 0xdfe8ec, side: THREE.DoubleSide });
    this.mesh = new THREE.InstancedMesh(geo, mat, MAX);
    this.mesh.frustumCulled = false;
    this.mesh.count = 0;
    scene.add(this.mesh);
    this.drops = [];
    for (let i = 0; i < MAX; i++) this.drops.push({ x: 0, y: -1, z: 0, s: 0.8 + Math.random() * 0.5 });
  }

  start(seconds = 60 + Math.random() * 60, kind = this.nextKind) {
    if (this.target === 1) return;
    this.target = 1; this.left = seconds; this.kind = kind;
    this.storm = kind === 'rain' && this.nextStorm; if (this.storm) this.left += 40; // storms linger
    this.onStart?.();
  }

  update(dt, focus, covered = null) {
    if (this.target === 0) {
      if ((this.next -= dt) <= 0) this.start();
    } else if ((this.left -= dt) <= 0) {
      this.target = 0; this.next = 240 + Math.random() * 300; this.nextKind = Math.random() < 0.35 ? 'snow' : 'rain'; this.nextStorm = this.nextKind === 'rain' && Math.random() < 0.28;
      this.onEnd?.();
    }
    this.rain += (this.target - this.rain) * Math.min(1, dt * 0.35);
    // snow piles up over about a minute while it falls, then melts away over two or three
    if (this.kind === 'snow' && this.target === 1) this.snow = Math.min(1, this.snow + dt / 60);
    else this.snow = Math.max(0, this.snow - dt / 150);
    if (this.rain < 0.01) { this.mesh.count = 0; return; }

    const n = Math.floor(MAX * Math.min(1, this.rain * 1.1));
    for (let i = 0; i < n; i++) {
      const d = this.drops[i];
      const snowy = this.kind === 'snow';
      d.y -= (snowy ? 1.6 : FALL) * d.s * dt;
      d.x += (snowy ? Math.sin(d.y * 1.7 + i) * 0.8 : 1.6) * dt; // rain slants with the breeze; flakes drift and sway
      // the ground under a drop is looked up once, when it respawns (drift over a fall is a metre or so)
      if (d.y < (d.ground ?? -1e9) || Math.abs(d.x - focus.x) > BOX / 2 || Math.abs(d.z - focus.z) > BOX / 2) {
        d.x = focus.x + (Math.random() - 0.5) * BOX;
        d.z = focus.z + (Math.random() - 0.5) * BOX;
        d.ground = getHeight(d.x, d.z);
        d.y = d.ground + Math.random() * TOP + (d.y < 0 ? 0 : 2);
        d.off = covered ? covered(d.x, d.z) : false; // no rain falls under a roof
      }
      if (d.off) _m.makeScale(0, 0, 0);
      else if (snowy) { _m.makeRotationY(d.y * 2 + i); _m.scale(_flake); } // a little paper square, tumbling
      else _m.makeRotationZ(-0.12);
      _m.setPosition(d.x, d.y, d.z);
      this.mesh.setMatrixAt(i, _m);
    }
    this.mesh.count = n;
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}

const _m = new THREE.Matrix4(), _flake = new THREE.Vector3(2.6, 0.12, 2.6);
