// A paper kite: a patchwork diamond of barn red, cream and blue on two cross-sticks, with a tail of little
// paper bows, flown on a twine string from the farmer's hand. Press G to let it up: it climbs on the west
// wind with a springy rise, then rides high and downwind, bobbing and swaying, and follows you as you walk.
// G again reels it in; a shower brings it down. Crows won't come near the garden while a kite is up over it.
import * as THREE from 'three/webgpu';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { springRise } from './world.js';

const DIAMOND = [[0, 0.95], [0.6, 0.18], [0, -0.85], [-0.6, 0.18]];
const BOW = [[-0.16, 0.07], [0, 0.02], [0.16, 0.07], [0.16, -0.07], [0, -0.02], [-0.16, -0.07]];
const BOWS = 6;

export class Kite {
  constructor(scene) {
    const art = paintCard(DIAMOND, {
      W: 256, H: 256, seed: 231, base: '#efe3c4', fills: ['rgba(239,227,196,A)'], edge: 'rgba(70,44,28,1)',
      details(g, px) {
        const quad = (pts, col) => { g.fillStyle = col; g.beginPath(); pts.forEach(([x, y], i) => { const [a, b] = px(x, y); i ? g.lineTo(a, b) : g.moveTo(a, b); }); g.closePath(); g.fill(); };
        quad([[0, 0.95], [0.6, 0.18], [0, 0.18]], '#b5473a');
        quad([[0, -0.85], [-0.6, 0.18], [0, 0.18]], '#b5473a');
        quad([[0, 0.95], [-0.6, 0.18], [0, 0.18]], '#4f6f96');
        // a cream star sewn in the middle, and the cross-sticks showing through the paper
        const [cx, cy] = px(0, 0.18);
        g.fillStyle = '#f3ead6'; g.beginPath(); for (let k = 0; k < 10; k++) { const r = k % 2 ? 12 : 28, a = -Math.PI / 2 + (k * Math.PI) / 5; g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); } g.closePath(); g.fill();
        g.strokeStyle = 'rgba(90,60,30,0.55)'; g.lineWidth = 5;
        { const [a, b] = px(0, 0.92), [c, d] = px(0, -0.82); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); }
        { const [a, b] = px(-0.57, 0.18), [c, d] = px(0.57, 0.18); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); }
      },
    });
    this.kite = new THREE.Mesh(cardGeometry(DIAMOND, 0.02), cardMaterial(art, { side: THREE.DoubleSide }));
    this.kite.castShadow = true; this.kite.visible = false;
    scene.add(this.kite);
    const bowArt = paintCard(BOW, { W: 64, H: 32, seed: 233, base: '#d9a441', fills: ['rgba(217,164,65,A)'], edge: 'rgba(90,60,20,1)' });
    this.bows = new THREE.InstancedMesh(cardGeometry(BOW, 0.01), cardMaterial(bowArt, { side: THREE.DoubleSide }), BOWS);
    this.bows.visible = false; this.bows.frustumCulled = false;
    const c = new THREE.Color();
    [0xd9a441, 0xb5473a, 0x4f6f96, 0xd9a441, 0xb5473a, 0x4f6f96].forEach((h, i) => this.bows.setColorAt(i, c.setHex(h)));
    scene.add(this.bows);
    // the twine: a sagging line from the hand to the kite
    this.lineGeo = new THREE.BufferGeometry().setAttribute('position', new THREE.BufferAttribute(new Float32Array(17 * 3), 3));
    this.line = new THREE.Line(this.lineGeo, new THREE.LineBasicNodeMaterial({ color: 0x8a7050 }));
    this.line.frustumCulled = false; this.line.visible = false;
    scene.add(this.line);
    this.flying = false; this.t = 0; this.up = 0;
    this.pos = new THREE.Vector3(); this.hand = new THREE.Vector3();
  }

  toggle(on = !this.flying) {
    this.flying = on; this.up = on ? 0 : this.up;
    for (const o of [this.kite, this.bows, this.line]) o.visible = on;
  }

  update(dt, player, camera, rain) {
    if (!this.flying) return;
    if (rain > 0.3) { this.toggle(false); return 'rain'; }
    this.t += dt; this.up = Math.min(2, this.up + dt * 0.6);
    const t = this.t, k = springRise(this.up);
    // the hand: a little in front of the farmer, at shoulder height
    this.hand.set(player.pos.x + Math.sin(player.facing) * 0.4, player.pos.y + 1.6, player.pos.z + Math.cos(player.facing) * 0.4);
    // riding high and downwind (east, on the west wind), bobbing on the gusts
    const gust = Math.sin(t * 0.21) * 0.5 + Math.sin(t * 0.83) * 0.3;
    // like a diorama, the wind always carries it out to the side and a little toward the lens, so it stays in view
    const tc = _c.set(camera.position.x - this.hand.x, 0, camera.position.z - this.hand.z).normalize();
    const right = _r.set(tc.z, 0, -tc.x);
    _goal.set(this.hand.x + (right.x * 2.6 + tc.x * 1.2) * k + Math.sin(t * 0.4) * 1.2, this.hand.y + 6.5 * k + gust * 1.0, this.hand.z + (right.z * 2.6 + tc.z * 1.2) * k + Math.cos(t * 0.33) * 1.2);
    if (this.up < 0.05) this.pos.copy(this.hand);
    this.pos.lerp(_goal, Math.min(1, dt * 2.5));
    this.kite.position.copy(this.pos);
    // face back toward the farmer, nose up, rocking side to side
    this.kite.lookAt(this.hand);
    this.kite.rotateZ(Math.sin(t * 1.7) * 0.25 + Math.sin(t * 3.1) * 0.08);
    this.kite.scale.setScalar(1.3);
    // the tail of bows trails below and downwind, snaking
    for (let i = 0; i < BOWS; i++) {
      const s = (i + 1) / BOWS;
      _p.set(this.pos.x + right.x * s * 1.4 + Math.sin(t * 3 + i * 0.9) * 0.25 * s, this.pos.y - 1.1 - s * 2.0, this.pos.z + right.z * s * 1.4 + Math.cos(t * 2.5 + i) * 0.2 * s);
      _q.setFromEuler(_e.set(0, Math.atan2(camera.position.x - _p.x, camera.position.z - _p.z), Math.sin(t * 4 + i) * 0.5));
      _m.compose(_p, _q, _s.setScalar(1.2));
      this.bows.setMatrixAt(i, _m);
    }
    this.bows.instanceMatrix.needsUpdate = true;
    // the string: sags a little in the middle
    const a = this.lineGeo.attributes.position;
    for (let i = 0; i <= 16; i++) {
      const s = i / 16;
      a.setXYZ(i, this.hand.x + (this.pos.x - this.hand.x) * s, this.hand.y + (this.pos.y - 1.0 - this.hand.y) * s - Math.sin(s * Math.PI) * 1.2, this.hand.z + (this.pos.z - this.hand.z) * s);
    }
    a.needsUpdate = true;
    return null;
  }
}

const _goal = new THREE.Vector3(), _c = new THREE.Vector3(), _r = new THREE.Vector3(), _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _m = new THREE.Matrix4(), _s = new THREE.Vector3();
