// The rooster weathervane on the barn ridge: a die-cut copper rooster gone green at the edges, riding an
// arrow over the N-E-S-W letters. Most days the wind comes out of the west and he faces it, nodding a little
// in the gusts. About three quarters of a minute before a shower he swings round to the east ("wind from
// the east, weather's a beast"), and a farmer who knows the old saying can bring the washing in.
import * as THREE from 'three/webgpu';
import { cardMaterial, paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

const ROOSTER = [
  [-0.3, 0.06], [-0.36, 0.26], [-0.42, 0.52], [-0.32, 0.44], [-0.28, 0.6], [-0.18, 0.44], [-0.06, 0.32], [0.1, 0.3],
  [0.14, 0.44], [0.13, 0.54], [0.18, 0.61], [0.22, 0.57], [0.25, 0.62], [0.29, 0.56], [0.27, 0.52], [0.36, 0.47],
  [0.28, 0.44], [0.27, 0.36], [0.21, 0.28], [0.24, 0.14], [0.14, 0.05], [0.04, 0.0], [-0.12, 0.0], [-0.24, 0.02],
];
const ARROW = [[-0.62, -0.02], [-0.5, -0.06], [-0.54, -0.1], [-0.42, -0.06], [0.44, -0.06], [0.42, -0.13], [0.62, -0.04], [0.42, 0.05], [0.44, -0.02], [-0.42, -0.02], [-0.54, 0.02], [-0.5, -0.02]];

export class Weathervane {
  constructor(scene, anchor) {
    anchor.updateWorldMatrix(true, false);
    const at = new THREE.Vector3().setFromMatrixPosition(anchor.matrixWorld);
    const g = (this.group = new THREE.Group());
    g.position.copy(at);
    // the fixed part: a post, the compass cross and its four letters
    const iron = paperMaterial({ color: 0x4a3c34 });
    const stat = [];
    stat.push(new THREE.BoxGeometry(0.05, 0.95, 0.05).translate(0, 0.47, 0));
    stat.push(new THREE.BoxGeometry(0.9, 0.035, 0.035).translate(0, 0.42, 0), new THREE.BoxGeometry(0.035, 0.035, 0.9).translate(0, 0.42, 0));
    stat.push(new THREE.SphereGeometry(0.06, 8, 6).translate(0, 0.62, 0));
    const post = new THREE.Mesh(mergeGeometries(stat), iron); post.castShadow = true; g.add(post);
    // N E S W, cut from one printed sheet (one material, one mesh); world north is -z
    const c = document.createElement('canvas'); c.width = 256; c.height = 64;
    const x = c.getContext('2d');
    x.fillStyle = '#4a3c34'; x.fillRect(0, 0, 256, 64);
    x.font = 'bold 50px Georgia, serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillStyle = '#d9a43a';
    ['N', 'E', 'S', 'W'].forEach((L, i) => x.fillText(L, 32 + i * 64, 35));
    const letterTex = new THREE.CanvasTexture(c); letterTex.colorSpace = THREE.SRGBColorSpace;
    const letters = [[0, -0.47, 0], [0.47, 0, 1], [0, 0.47, 2], [-0.47, 0, 3]].map(([lx, lz, i]) => {
      const pg = new THREE.PlaneGeometry(0.17, 0.17);
      const uv = pg.attributes.uv; for (let k = 0; k < uv.count; k++) uv.setX(k, (i + uv.getX(k)) / 4);
      return pg.rotateY(Math.atan2(lx, lz)).translate(lx, 0.42, lz); // each letter faces outward
    });
    const lm = new THREE.Mesh(mergeGeometries(letters), new THREE.MeshLambertNodeMaterial({ map: letterTex, side: THREE.DoubleSide }));
    g.add(lm);
    // the turning part: the rooster riding the arrow
    this.turn = new THREE.Group(); this.turn.position.y = 0.66; g.add(this.turn);
    const art = paintCard(ROOSTER, {
      W: 256, H: 256, seed: 411, base: '#b87a4a', fills: ['rgba(196,134,82,A)', 'rgba(160,100,60,A)'], edge: 'rgba(60,40,28,1)',
      details(gc, px) {
        gc.fillStyle = 'rgba(127,168,152,0.85)'; // verdigris where the rain sits
        for (const [vx, vy, r] of [[-0.34, 0.4, 16], [-0.1, 0.12, 22], [0.05, 0.2, 14], [-0.26, 0.24, 12]]) { const [a, b] = px(vx, vy); gc.beginPath(); gc.arc(a, b, r, 0, Math.PI * 2); gc.fill(); }
        gc.strokeStyle = 'rgba(90,54,32,0.8)'; gc.lineWidth = 4; // wing and tail feathers, hammered in
        for (const [a0, b0, a1, b1] of [[-0.05, 0.22, 0.12, 0.16], [-0.06, 0.16, 0.1, 0.1], [-0.3, 0.3, -0.36, 0.48], [-0.24, 0.28, -0.26, 0.54]]) {
          const [a, b] = px(a0, b0), [cc, d] = px(a1, b1); gc.beginPath(); gc.moveTo(a, b); gc.lineTo(cc, d); gc.stroke();
        }
        gc.fillStyle = '#b5473a'; { const p = [px(0.16, 0.56), px(0.2, 0.63), px(0.23, 0.58), px(0.26, 0.63), px(0.29, 0.56)]; gc.beginPath(); gc.moveTo(...p[0]); for (const q of p) gc.lineTo(...q); gc.fill(); } // comb
        { const p = [px(0.26, 0.4), px(0.29, 0.34), px(0.24, 0.36)]; gc.beginPath(); gc.moveTo(...p[0]); for (const q of p) gc.lineTo(...q); gc.fill(); } // wattle
        gc.fillStyle = '#efe3c4'; { const [a, b] = px(0.24, 0.49); gc.beginPath(); gc.arc(a, b, 6, 0, Math.PI * 2); gc.fill(); }
        gc.fillStyle = '#3a2a20'; { const [a, b] = px(0.245, 0.49); gc.beginPath(); gc.arc(a, b, 3, 0, Math.PI * 2); gc.fill(); }
        gc.fillStyle = '#d9a43a'; { const p = [px(0.3, 0.5), px(0.38, 0.47), px(0.3, 0.45)]; gc.beginPath(); gc.moveTo(...p[0]); for (const q of p) gc.lineTo(...q); gc.fill(); } // beak
      },
    });
    const rooster = new THREE.Mesh(cardGeometry(ROOSTER, 0.025), cardMaterial(art, { side: THREE.DoubleSide }));
    rooster.position.y = 0.02;
    const arrow = new THREE.Mesh(cardGeometry(ARROW, 0.025), iron);
    for (const m of [rooster, arrow]) { m.castShadow = true; this.turn.add(m); }
    this.group.scale.setScalar(1.6);
    scene.add(g);
    this.angle = Math.PI; // the arrowhead points where the wind comes from: west
    this.vel = 0; this.t = 0;
    this.warned = false;
  }

  /** Returns 'rain' | 'snow' the moment he swings round ahead of a shower (once per shower), else null. */
  update(dt, weather) {
    this.t += dt;
    const t = this.t;
    const coming = weather.target === 0 && weather.next < 45;
    // fair weather: out of the west, wandering a little; a shower coming: round to the east
    const goal = coming || weather.target === 1 ? 0.15 * Math.sin(t * 0.13) : Math.PI + 0.35 * Math.sin(t * 0.021) + 0.12 * Math.sin(t * 0.17);
    let d = goal - this.angle; d = Math.atan2(Math.sin(d), Math.cos(d));
    this.vel += (d * 2.2 - this.vel * 1.6) * dt;
    this.vel += Math.sin(t * 2.3) * Math.sin(t * 0.7) * 0.25 * dt; // gusts nudge him
    this.angle += this.vel * dt;
    this.turn.rotation.y = this.angle;
    let said = null;
    if (coming && !this.warned) { this.warned = true; said = weather.nextKind; }
    if (!coming && weather.target === 0) this.warned = false;
    return said;
  }
}
