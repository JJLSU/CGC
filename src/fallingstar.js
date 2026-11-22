// Falling stars: now and then on a clear night a paper star breaks loose from the sky and streaks down,
// trailing a ribbon of gold paper, and comes to rest in a meadow not far off, standing up from the grass and
// glowing. A note says which way it fell. Walk out (the lightning-bug jar helps) and press E by it to take it
// home: folk say a fallen star brings luck, and this one leaves a little something behind. Unfound stars
// fade at first light.
import * as THREE from 'three/webgpu';
import { texture, uniform, uv } from 'three/tsl';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight, isWater, springRise } from './world.js';

const STAR = (() => {
  const pts = [];
  for (let k = 0; k < 10; k++) { const a = Math.PI / 2 + (k * Math.PI) / 5, r = k % 2 ? 0.42 : 1; pts.push([Math.cos(a) * r, 0.95 + Math.sin(a) * r]); }
  return pts;
})();
const DIRS = ['east', 'north-east', 'north', 'north-west', 'west', 'south-west', 'south', 'south-east'];
export const STAR_GIFTS = [
  [{ honey: 2 }, 'a jar of honey that tastes faintly of summer'], [{ iron: 2 }, 'two bars of star-iron, still warm'],
  [{ rope: 2, wool: 2 }, 'a skein of silver-grey wool and two coils of rope'], [{ fish: 2, egg: 2 }, 'a breakfast: two trout and two eggs, somehow'],
  [{ apples: 4, berries: 4 }, 'a pocketful of apples and berries'], [{ honeycake: 1 }, 'a honey cake, wrapped in a scrap of sky'],
];

export class FallingStars {
  constructor(scene) {
    const art = paintCard(STAR, {
      W: 192, H: 192, seed: 177, base: '#f6e8b0', fills: ['rgba(250,238,190,A)', 'rgba(236,210,130,A)'], edge: 'rgba(140,100,40,1)',
      details(g, px) {
        g.strokeStyle = 'rgba(214,170,80,0.8)'; g.lineWidth = 4;
        for (let k = 0; k < 5; k++) { const a = Math.PI / 2 + (k * 2 * Math.PI) / 5; const [x0, y0] = px(0, 0.95), [x1, y1] = px(Math.cos(a) * 0.8, 0.95 + Math.sin(a) * 0.8); g.beginPath(); g.moveTo(x0, y0); g.lineTo(x1, y1); g.stroke(); }
      },
    });
    this.glow = uniform(1.6);
    const mat = new THREE.MeshBasicNodeMaterial({ side: THREE.DoubleSide, fog: false });
    mat.colorNode = texture(art, uv()).rgb.mul(this.glow);
    this.star = new THREE.Mesh(cardGeometry(STAR, 0.05), mat);
    this.star.visible = false; this.star.frustumCulled = false;
    scene.add(this.star);
    // the gold ribbon tail while it falls: a thin strip of card stretched behind it
    const tailMat = new THREE.MeshBasicNodeMaterial({ color: 0xf0c868, transparent: true, opacity: 0.85, side: THREE.DoubleSide, fog: false, depthWrite: false });
    this.tail = new THREE.Mesh(new THREE.PlaneGeometry(1, 1).translate(0.5, 0, 0), tailMat);
    this.tail.visible = false; this.tail.frustumCulled = false;
    scene.add(this.tail);
    this.light = new THREE.PointLight(0xffd890, 0, 9, 1.4);
    scene.add(this.light);
    this.state = 'none'; // 'none' | 'falling' | 'landed'
    this.next = 70 + Math.random() * 90;
    this.t = 0;
    this.at = new THREE.Vector3(); this.from = new THREE.Vector3(); this.to = new THREE.Vector3();
  }

  near(pos, r = 1.8) { return this.state === 'landed' && this.t > 0.6 && Math.hypot(pos.x - this.at.x, pos.z - this.at.z) < r; }

  /** Pick a meadow spot 22–40 m off and send a star down toward it. Returns the direction word, or null. */
  launch(player, camera) {
    for (let tries = 0; tries < 12; tries++) {
      const a = Math.random() * Math.PI * 2, d = 22 + Math.random() * 18;
      const x = player.pos.x + Math.cos(a) * d, z = player.pos.z + Math.sin(a) * d;
      if (isWater(x, z)) continue;
      this.at.set(x, getHeight(x, z), z);
      // the streak: high in the sky over the landing spot, falling at a slant toward it
      this.from.set(x - Math.cos(a) * 60, this.at.y + 70, z - Math.sin(a) * 60);
      this.to.copy(this.at);
      this.state = 'falling'; this.t = 0;
      const ang = Math.atan2(-(z - player.pos.z), x - player.pos.x); // north is -z
      return DIRS[((Math.round(ang / (Math.PI / 4)) % 8) + 8) % 8];
    }
    return null;
  }

  /** Taken home: the star folds down into the grass. */
  take() { this.state = 'none'; this.star.visible = false; this.light.intensity = 0; this.next = 120 + Math.random() * 150; }

  /** Returns the direction word the moment a star falls (for a note), else null. */
  update(dt, { player, camera, night, rain }) {
    this.t += dt;
    let fell = null;
    if (this.state === 'none') {
      if (night > 0.75 && rain < 0.1 && (this.next -= dt) <= 0) fell = this.launch(player, camera);
      if (!fell && this.next <= 0) this.next = 30;
    } else if (this.state === 'falling') {
      const k = Math.min(1, this.t / 1.8);
      const e = k * k; // gathers speed as it falls
      this.star.visible = this.tail.visible = true;
      this.star.position.lerpVectors(this.from, this.to, e);
      this.star.lookAt(camera.position);
      this.star.rotateZ(Math.sin(this.t * 7) * 0.3); // rocking as it falls
      this.star.scale.setScalar(1.4);
      // the tail streams back toward where it came from
      // trailing back up its path: a strip from the star toward where it came from, turned to face the camera
      const head = _c.copy(this.star.position); head.y += 0.95 * 1.4;
      const xAxis = _d.subVectors(this.from, head).normalize();
      const toCam = _v.subVectors(camera.position, head).normalize();
      const zAxis = toCam.addScaledVector(xAxis, -toCam.dot(xAxis)).normalize();
      const yAxis = _w.crossVectors(zAxis, xAxis);
      _m.makeBasis(xAxis, yAxis, zAxis);
      this.tail.quaternion.setFromRotationMatrix(_m);
      this.tail.position.copy(head);
      const len = 6 + k * 10;
      this.tail.scale.set(len, 0.35, 1);
      this.light.position.copy(this.star.position); this.light.intensity = 3;
      if (k >= 1) { this.state = 'landed'; this.t = 0; this.tail.visible = false; }
    } else if (this.state === 'landed') {
      // stands up out of the grass with a springy overshoot, and turns slowly, glowing
      const rise = springRise(this.t * 1.4);
      this.star.position.copy(this.at);
      this.star.rotation.set(-(1 - rise) * Math.PI / 2, this.t * 0.6, 0);
      this.star.scale.setScalar(0.55);
      this.glow.value = 1.3 + Math.sin(this.t * 3) * 0.25;
      this.light.position.set(this.at.x, this.at.y + 0.8, this.at.z);
      this.light.intensity = 2.2 + Math.sin(this.t * 3) * 0.4;
      if (night < 0.2) this.take(); // gone at first light
    }
    return fell;
  }
}

const _d = new THREE.Vector3(), _c = new THREE.Vector3(), _v = new THREE.Vector3(), _w = new THREE.Vector3(), _m = new THREE.Matrix4();
