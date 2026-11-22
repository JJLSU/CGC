// Washing day: a clothesline strung between two T-posts in the farmyard, hung with a buffalo-plaid shirt,
// the farmer's overalls, a patchwork quilt, a pair of wool socks and a striped tea towel. Each is a printed
// die-cut card pegged to the twine (the clothespins are cut into the card's own top edge), and each swings on
// the line as on a crease: lazily in the breeze, harder in a gust, and hanging heavy and still in the rain.
import * as THREE from 'three/webgpu';
import { cardMaterial, paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight } from './world.js';
import { bakeByMaterial } from './bake.js';

function pegsLR(a, b) {
  // left peg then right peg, walking left → right along the top edge (y = 0)
  return [[a - 0.03, 0], [a - 0.03, 0.08], [a + 0.03, 0.08], [a + 0.03, 0], [b - 0.03, 0], [b - 0.03, 0.08], [b + 0.03, 0.08], [b + 0.03, 0]];
}

const PEG = '#b08a5a';
function drawPegs(g, px, a, b) {
  for (const x of [a, b]) {
    const [x0, y0] = px(x - 0.03, 0.08), [x1, y1] = px(x + 0.03, -0.05);
    g.fillStyle = PEG; g.fillRect(x0, y0, x1 - x0, y1 - y0);
    g.fillStyle = 'rgba(70,44,28,0.6)'; g.fillRect((x0 + x1) / 2 - 1.5, y0, 3, y1 - y0); // the split of the peg
  }
}

const GARMENTS = [
  { // buffalo-plaid flannel shirt, sleeves hanging out
    body: [[-0.3, 0], [0.3, 0], [0.48, -0.06], [0.5, -0.42], [0.34, -0.44], [0.3, -0.24], [0.29, -0.8], [-0.29, -0.8], [-0.3, -0.24], [-0.34, -0.44], [-0.5, -0.42], [-0.48, -0.06]],
    pegs: [-0.24, 0.24], base: '#a8352a', fills: ['rgba(180,60,46,A)', 'rgba(150,40,34,A)'],
    draw(g, px) {
      g.fillStyle = 'rgba(40,24,22,0.55)';
      for (let x = -0.5; x < 0.5; x += 0.16) { const [a, b] = px(x, 0.1), [c, d] = px(x + 0.08, -0.9); g.fillRect(a, b, c - a, d - b); }
      for (let y = 0; y > -0.9; y -= 0.16) { const [a, b] = px(-0.6, y), [c, d] = px(0.6, y - 0.08); g.fillRect(a, b, c - a, d - b); }
      g.strokeStyle = 'rgba(240,226,196,0.5)'; g.lineWidth = 2;
      for (let x = -0.46; x < 0.5; x += 0.16) { const [a, b] = px(x, 0.1), [, d] = px(x, -0.9); g.beginPath(); g.moveTo(a, b); g.lineTo(a, d); g.stroke(); }
      // collar, placket and cream buttons
      g.fillStyle = '#7a2620'; g.beginPath(); { const p = [px(-0.14, 0), px(0, -0.12), px(0.14, 0), px(0.06, 0), px(0, -0.05), px(-0.06, 0)]; g.moveTo(...p[0]); for (const q of p) g.lineTo(...q); } g.fill();
      g.strokeStyle = 'rgba(40,24,22,0.7)'; g.lineWidth = 3; { const [a, b] = px(0, -0.12), [, d] = px(0, -0.8); g.beginPath(); g.moveTo(a, b); g.lineTo(a, d); g.stroke(); }
      g.fillStyle = '#efe3c4'; for (let y = -0.2; y > -0.78; y -= 0.14) { const [a, b] = px(0.03, y); g.beginPath(); g.arc(a, b, 6, 0, Math.PI * 2); g.fill(); }
      // a breast pocket
      g.strokeStyle = 'rgba(240,226,196,0.7)'; g.lineWidth = 3; { const [a, b] = px(-0.22, -0.2), [c, d] = px(-0.08, -0.34); g.strokeRect(a, b, c - a, d - b); }
    },
  },
  { // denim overalls, hung by the bib
    body: [[-0.17, 0], [0.17, 0], [0.18, -0.26], [0.27, -0.3], [0.27, -1.0], [0.05, -1.0], [0.0, -0.62], [-0.05, -1.0], [-0.27, -1.0], [-0.27, -0.3], [-0.18, -0.26]],
    pegs: [-0.12, 0.12], base: '#4f6f96', fills: ['rgba(90,124,166,A)', 'rgba(64,92,130,A)'],
    draw(g, px) {
      g.strokeStyle = 'rgba(40,52,78,0.35)'; g.lineWidth = 2; // twill
      for (let k = -1.2; k < 1.2; k += 0.035) { const [a, b] = px(k, 0.1), [c, d] = px(k + 1.1, -1.0); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); }
      g.setLineDash([7, 6]); g.strokeStyle = '#e0b04a'; g.lineWidth = 3; // yellow stitched seams
      const seam = (pts) => { g.beginPath(); pts.forEach(([x, y], i) => { const [a, b] = px(x, y); i ? g.lineTo(a, b) : g.moveTo(a, b); }); g.stroke(); };
      seam([[-0.14, -0.03], [-0.14, -0.22], [0.14, -0.22], [0.14, -0.03]]);
      seam([[-0.24, -0.32], [0.24, -0.32]]);
      seam([[-0.2, -0.36], [-0.2, -0.97]]); seam([[0.2, -0.36], [0.2, -0.97]]);
      seam([[-0.09, -0.06], [-0.09, -0.17], [0.09, -0.17], [0.09, -0.06]]); // bib pocket
      g.setLineDash([]);
      g.fillStyle = '#d9a43a'; for (const x of [-0.13, 0.13]) { const [a, b] = px(x, -0.29); g.beginPath(); g.arc(a, b, 8, 0, Math.PI * 2); g.fill(); }
      g.fillStyle = 'rgba(40,52,78,0.5)'; { const [a, b] = px(-0.27, -0.94), [c, d] = px(0.27, -1.0); g.fillRect(a, b, c - a, d - b); } // turned-up cuffs
    },
  },
  { // a patchwork quilt, the big one
    body: [[-0.66, 0], [0.66, 0], [0.67, -0.6], [0.6, -1.12], [0.2, -1.08], [-0.25, -1.13], [-0.65, -1.08], [-0.67, -0.6]],
    pegs: [-0.56, 0.56], base: '#efe3c4', fills: ['rgba(240,228,200,A)', 'rgba(226,212,182,A)'],
    draw(g, px, rng) {
      const cols = ['#b5473a', '#d9a43a', '#8a9a5e', '#efe3c4', '#6f8aa8', '#c97a4a'];
      const S = 0.22;
      for (let i = 0; i < 6; i++) for (let j = 0; j < 6; j++) {
        const x = -0.66 + i * S, y = -j * S - 0.02;
        const [a, b] = px(x + 0.01, y), [c, d] = px(x + S - 0.01, y - S + 0.02);
        g.fillStyle = cols[Math.floor(rng() * cols.length)]; g.fillRect(a, b, c - a, d - b);
        if (rng() < 0.4) { g.fillStyle = cols[Math.floor(rng() * cols.length)]; g.beginPath(); g.moveTo(a, b); g.lineTo(c, b); g.lineTo(a, d); g.fill(); } // half-square triangles
      }
      g.setLineDash([5, 5]); g.strokeStyle = 'rgba(70,44,28,0.55)'; g.lineWidth = 2;
      for (let i = 0; i <= 6; i++) { const [a, b] = px(-0.66 + i * S, 0), [, d] = px(0, -1.13); g.beginPath(); g.moveTo(a, b); g.lineTo(a, d); g.stroke(); }
      for (let j = 0; j <= 6; j++) { const [a, b] = px(-0.7, -j * S - 0.02), [c] = px(0.7, 0); g.beginPath(); g.moveTo(a, b); g.lineTo(c, b); g.stroke(); }
      g.setLineDash([]);
      // a barn star sewn on in the middle
      const [cx, cy] = px(0, -0.55), R = 46;
      g.fillStyle = '#efe3c4'; g.beginPath(); for (let k = 0; k < 10; k++) { const r = k % 2 ? R * 0.45 : R, a = -Math.PI / 2 + (k * Math.PI) / 5; g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); } g.closePath(); g.fill();
      g.strokeStyle = 'rgba(70,44,28,0.75)'; g.lineWidth = 2.5; g.stroke();
    },
  },
  { // wool sock
    body: [[-0.08, 0], [0.08, 0], [0.08, -0.32], [0.2, -0.4], [0.19, -0.48], [-0.06, -0.47], [-0.08, -0.4]],
    pegs: [-0.04, 0.04], base: '#d9cfbc', fills: ['rgba(222,212,192,A)', 'rgba(196,186,166,A)'], sock: true,
  },
  { // its mate, a little askew
    body: [[-0.08, 0], [0.08, 0], [0.08, -0.3], [0.2, -0.37], [0.19, -0.45], [-0.06, -0.44], [-0.08, -0.37]],
    pegs: [-0.04, 0.04], base: '#d9cfbc', fills: ['rgba(222,212,192,A)', 'rgba(196,186,166,A)'], sock: true,
  },
  { // striped tea towel
    body: [[-0.25, 0], [0.25, 0], [0.26, -0.52], [-0.25, -0.54]],
    pegs: [-0.2, 0.2], base: '#efe3c4', fills: ['rgba(244,234,210,A)', 'rgba(228,216,190,A)'],
    draw(g, px) {
      g.fillStyle = '#b5473a';
      for (const y of [-0.06, -0.1, -0.44, -0.48]) { const [a, b] = px(-0.3, y), [c, d] = px(0.3, y - 0.025); g.fillRect(a, b, c - a, d - b); }
      g.fillStyle = 'rgba(181,71,58,0.35)'; { const [a, b] = px(-0.3, -0.2), [c, d] = px(0.3, -0.34); g.fillRect(a, b, c - a, d - b); }
    },
  },
];

const sockDraw = (g, px) => {
  g.fillStyle = '#b5473a';
  for (const y of [-0.05, -0.1]) { const [a, b] = px(-0.1, y), [c, d] = px(0.1, y - 0.03); g.fillRect(a, b, c - a, d - b); }
  g.beginPath(); { const p = [px(0.12, -0.34), px(0.22, -0.4), px(0.2, -0.5), px(0.1, -0.5)]; g.moveTo(...p[0]); for (const q of p) g.lineTo(...q); } g.fill(); // red toe
  g.beginPath(); { const p = [px(-0.1, -0.38), px(-0.02, -0.38), px(-0.02, -0.5), px(-0.1, -0.5)]; g.moveTo(...p[0]); for (const q of p) g.lineTo(...q); } g.fill(); // red heel
  g.strokeStyle = 'rgba(70,44,28,0.25)'; g.lineWidth = 2; // ribbing
  for (let x = -0.07; x < 0.08; x += 0.025) { const [a, b] = px(x, -0.13), [, d] = px(x, -0.3); g.beginPath(); g.moveTo(a, b); g.lineTo(a, d); g.stroke(); }
};

export class Laundry {
  constructor(scene, world, center) {
    const ax = center.x + 6.5, bx = center.x + 11.3, z = center.z + 1.2;
    const y0 = Math.min(getHeight(ax, z), getHeight(bx, z));
    const top = 2.05;
    world.colliders.push({ x: ax, z, r: 0.25 }, { x: bx, z, r: 0.25 });
    world.exclusions.push({ x: (ax + bx) / 2, z, r: 3.2 });
    const g = (this.group = new THREE.Group());
    g.position.set(ax, y0, z);
    const L = bx - ax, sag = 0.16;
    const lineY = (u) => top - sag * 4 * u * (1 - u);
    const wood = paperMaterial({ color: 0x8a6a48 }), twine = paperMaterial({ color: 0xe6dcc2 });
    const add = (geo, mat) => { const m = new THREE.Mesh(geo, mat); m.castShadow = m.receiveShadow = true; g.add(m); return m; };
    for (const x of [0, L]) {
      add(new THREE.BoxGeometry(0.1, top + 0.15, 0.1).translate(x, (top + 0.15) / 2, 0), wood); // the post
      add(new THREE.BoxGeometry(0.08, 0.08, 0.7).translate(x, top, 0), wood);                  // the crossbar
      add(new THREE.BoxGeometry(0.06, 0.06, 0.5).rotateX(0.8).translate(x, top - 0.25, 0.14), wood); // a brace
    }
    const curve = new THREE.QuadraticBezierCurve3(new THREE.Vector3(0, top, 0), new THREE.Vector3(L / 2, top - sag * 2, 0), new THREE.Vector3(L, top, 0));
    add(new THREE.TubeGeometry(curve, 16, 0.014, 4, false), twine).castShadow = false;
    bakeByMaterial(g);

    // the washing, left to right along the line
    const at = [0.12, 0.3, 0.55, 0.735, 0.78, 0.9];
    this.items = GARMENTS.map((G, i) => {
      const pts = G.body.slice(0, 1).concat(pegsLR(G.pegs[0], G.pegs[1]), G.body.slice(1));
      const art = paintCard(pts, {
        W: 256, H: 256, seed: 301 + i * 7, base: G.base, fills: G.fills, edge: 'rgba(60,40,28,1)',
        details(gc, px, rng) { (G.sock ? sockDraw : G.draw)(gc, px, rng); drawPegs(gc, px, G.pegs[0], G.pegs[1]); },
      });
      const mesh = new THREE.Mesh(cardGeometry(pts, 0.012), cardMaterial(art, { side: THREE.DoubleSide }));
      mesh.castShadow = mesh.receiveShadow = true;
      const pivot = new THREE.Group(); // hinge: the twine itself
      const u = at[i];
      pivot.position.set(u * L, lineY(u) - 0.02, 0);
      if (i === 4) mesh.rotation.z = 0.12; // the second sock hangs a bit crooked
      pivot.add(mesh); g.add(pivot);
      return { pivot, mesh, ph: i * 1.7, heavy: G.body.length > 9 ? 0.75 : 1 };
    });
    g.rotation.y = 0;
    scene.add(g);
    this.t = 0; this.wet = 0;
  }

  /** The washing swings on the line with the wind; rain soaks it so it hangs heavy and nearly still. */
  update(dt, player, rain) {
    const p = this.group.position;
    const far = Math.hypot(player.pos.x - p.x - 2.4, player.pos.z - p.z) > 70;
    this.group.visible = !far;
    if (far) return;
    this.t += dt;
    this.wet += ((rain > 0.2 ? 1 : 0) - this.wet) * Math.min(1, dt * (rain > 0.2 ? 0.25 : 0.04)); // soaks fast, dries slowly
    const t = this.t;
    const gust = 0.65 + 0.25 * Math.sin(t * 0.21) + 0.2 * Math.sin(t * 0.57 + 1.3);
    const amp = (0.06 + 0.16 * gust) * (1 - this.wet * 0.8);
    for (const it of this.items) {
      const s = Math.sin(t * 1.1 + it.ph) + 0.35 * Math.sin(t * 2.7 + it.ph * 2);
      it.pivot.rotation.x = -amp * it.heavy * (0.6 + 0.4 * s) - 0.03;  // blown out away from the house, swinging about the twine
      it.pivot.rotation.y = 0.05 * Math.sin(t * 0.7 + it.ph) * (1 - this.wet);
    }
  }
}
