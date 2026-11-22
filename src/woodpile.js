// Woodpiles: the logs you've stacked on each woodpile you've built, drawn as one instanced mesh of paper log
// rounds (bark-brown sides, pale end grain with printed growth rings), laid in rows between the two end posts.
// Up to 24 logs a pile; the stack grows as you add to it and shrinks as you take from it (or the stove burns it).
import * as THREE from 'three/webgpu';
import { cardMaterial, paperMaterial } from './materials.js';

export const PILE_MAX = 24;
const PILES = 4;

function endGrain() {
  const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  g.fillStyle = '#e2c48e'; g.fillRect(0, 0, 128, 128);
  g.strokeStyle = 'rgba(150,104,56,0.6)'; g.lineWidth = 2.5;
  for (let r = 10; r < 62; r += 9) { g.beginPath(); g.arc(64 + (r % 3), 64, r, 0, Math.PI * 2); g.stroke(); } // growth rings
  g.strokeStyle = 'rgba(110,70,36,0.6)'; g.lineWidth = 3; g.beginPath(); g.moveTo(64, 64); g.lineTo(108, 40); g.stroke(); // a split
  g.strokeStyle = '#6b4a30'; g.lineWidth = 10; g.beginPath(); g.arc(64, 64, 62, 0, Math.PI * 2); g.stroke(); // bark rim
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

export class Woodpiles {
  constructor(scene) {
    const geo = new THREE.CylinderGeometry(0.11, 0.12, 0.62, 10).rotateZ(Math.PI / 2); // a log lying along x
    const mats = [paperMaterial({ color: 0x7a5636 }), cardMaterial(endGrain()), cardMaterial(endGrain())]; // side, ends
    this.mesh = new THREE.InstancedMesh(geo, mats, PILES * PILE_MAX);
    this.mesh.castShadow = true; this.mesh.receiveShadow = true; this.mesh.count = 0; this.mesh.frustumCulled = false;
    const c = new THREE.Color();
    for (let i = 0; i < PILES * PILE_MAX; i++) this.mesh.setColorAt(i, c.setHSL(0.08, 0.3, 0.8 + ((i * 37) % 10) / 50));
    scene.add(this.mesh);
    this.sig = '';
  }

  /** Lay out the logs on the woodpiles nearest the farmer (rebuilt only when something changes). */
  update(pieces, center) {
    const piles = pieces.filter((p) => p.type === 'woodpile').sort((a, b) => ((a.x - center.x) ** 2 + (a.z - center.z) ** 2) - ((b.x - center.x) ** 2 + (b.z - center.z) ** 2)).slice(0, PILES);
    const sig = piles.map((p) => `${p.x.toFixed(1)},${p.z.toFixed(1)},${p.rot},${p.stock || 0},${p.risen ? 1 : 0}`).join('|');
    if (sig === this.sig) return;
    this.sig = sig;
    let n = 0;
    for (const p of piles) {
      if (!p.risen) continue;
      const stock = Math.min(PILE_MAX, p.stock || 0);
      const a = ((p.rot || 0) * Math.PI) / 2, cs = Math.cos(a), sn = Math.sin(a); // build rotations are quarter turns
      for (let k = 0; k < stock; k++) {
        const row = Math.floor(k / 6), col = k % 6;
        // rows of six, each row nested into the hollows of the one below
        const lx = 0, lz = (col - 2.5) * 0.23 + (row % 2) * 0.11 - 0.05, ly = 0.13 + row * 0.2;
        _p.set(p.x + lx * cs + lz * sn, p.y + ly, p.z - lx * sn + lz * cs);
        _q.setFromAxisAngle(_y, a + ((k * 13) % 7 - 3) * 0.02);
        _m.compose(_p, _q, _s.set(1, 1, 1));
        this.mesh.setMatrixAt(n++, _m);
      }
    }
    this.mesh.count = n;
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _m = new THREE.Matrix4(), _s = new THREE.Vector3(), _y = new THREE.Vector3(0, 1, 0);
