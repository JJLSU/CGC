// Procedural paper + watercolour textures, painted on 2D canvases at load time.
// Everything here is generated — no external image assets.
import * as THREE from 'three/webgpu';
import { mulberry32 } from './noise.js';

function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}

function toTexture(canvas, { srgb = true, repeat = false } = {}) {
  const t = new THREE.CanvasTexture(canvas);
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 8;
  t.needsUpdate = true;
  return t;
}

/** Draw `fn(dx, dy)` at the 9 wrap offsets so the result tiles seamlessly. */
function wrapped(S, fn) {
  for (const dy of [-S, 0, S]) for (const dx of [-S, 0, S]) fn(dx, dy);
}

// ------------------------------------------------------------------ tiling paper

/** Mid-grey paper height/tone with cloudy formation, fibres and specks. Tiles. */
export function paperFiberTexture() {
  const S = 512, c = makeCanvas(S, S), g = c.getContext('2d');
  const rng = mulberry32(7);
  g.fillStyle = '#808080';
  g.fillRect(0, 0, S, S);
  // cloudy pulp formation
  for (let i = 0; i < 260; i++) {
    const x = rng() * S, y = rng() * S, r = 12 + rng() * 46, v = rng() < 0.5 ? 255 : 0, a = 0.035 + rng() * 0.03;
    wrapped(S, (dx, dy) => {
      const gr = g.createRadialGradient(x + dx, y + dy, 0, x + dx, y + dy, r);
      gr.addColorStop(0, `rgba(${v},${v},${v},${a})`);
      gr.addColorStop(1, `rgba(${v},${v},${v},0)`);
      g.fillStyle = gr;
      g.fillRect(x + dx - r, y + dy - r, r * 2, r * 2);
    });
  }
  // fibres
  g.lineCap = 'round';
  for (let i = 0; i < 2400; i++) {
    const x = rng() * S, y = rng() * S, len = 5 + rng() * 22, a = rng() * Math.PI * 2, bend = (rng() - 0.5) * 8;
    const light = rng() < 0.62;
    g.strokeStyle = light ? `rgba(255,255,255,${0.1 + rng() * 0.16})` : `rgba(40,30,20,${0.05 + rng() * 0.08})`;
    g.lineWidth = 0.5 + rng() * 1.1;
    const ex = Math.cos(a) * len, ey = Math.sin(a) * len;
    wrapped(S, (dx, dy) => {
      g.beginPath();
      g.moveTo(x + dx, y + dy);
      g.quadraticCurveTo(x + dx + ex / 2 - ey * bend * 0.04, y + dy + ey / 2 + ex * bend * 0.04, x + dx + ex, y + dy + ey);
      g.stroke();
    });
  }
  // specks
  for (let i = 0; i < 900; i++) {
    const x = rng() * S, y = rng() * S, r = 0.4 + rng() * 0.9, d = rng() < 0.7;
    g.fillStyle = d ? `rgba(60,45,30,${0.1 + rng() * 0.25})` : `rgba(255,255,255,${0.2 + rng() * 0.3})`;
    g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.fill();
  }
  return toTexture(c, { srgb: false, repeat: true });
}

/** Watercolour "blooms": white with soft blotches whose rims are darker (wet edges). Tiles. */
export function washTexture() {
  const S = 512, c = makeCanvas(S, S), g = c.getContext('2d');
  const rng = mulberry32(11);
  g.fillStyle = '#ffffff';
  g.fillRect(0, 0, S, S);
  for (let i = 0; i < 140; i++) {
    const x = rng() * S, y = rng() * S, r = 18 + rng() * 70, n = 14;
    const pts = [];
    for (let k = 0; k < n; k++) {
      const a = (k / n) * Math.PI * 2, rr = r * (0.75 + rng() * 0.45);
      pts.push([Math.cos(a) * rr, Math.sin(a) * rr]);
    }
    const tone = Math.floor(rng() * 60);
    wrapped(S, (dx, dy) => {
      g.beginPath();
      pts.forEach(([px, py], k) => {
        const [nx, ny] = pts[(k + 1) % n];
        const mx = (px + nx) / 2, my = (py + ny) / 2;
        if (k === 0) g.moveTo(x + dx + mx, y + dy + my);
        else g.quadraticCurveTo(x + dx + px, y + dy + py, x + dx + mx, y + dy + my);
      });
      g.closePath();
      g.fillStyle = `rgba(${tone},${tone},${tone},0.05)`;
      g.fill();
      g.strokeStyle = `rgba(${tone},${tone},${tone},0.07)`;
      g.lineWidth = 2 + rng() * 2;
      g.stroke();
    });
  }
  return toTexture(c, { srgb: false, repeat: true });
}

// ------------------------------------------------------------------ painted card art

export const EDGE_UV = [0.992, 0.992]; // cream "paper core" pixel used for card side walls

const INK = 'rgba(70, 44, 28, 0.85)';

/** A silhouette is an array of [x, y] in world units (y up). Returns the canvas mapping. */
function frame(points, W, H) {
  let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
  for (const [x, y] of points) { minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
  const pad = 0.04;
  const w = maxX - minX, h = maxY - minY;
  minX -= w * pad; maxX += w * pad; minY -= h * pad; maxY += h * pad;
  const box = { minX, minY, w: maxX - minX, h: maxY - minY };
  const px = (x, y) => [((x - box.minX) / box.w) * W, (1 - (y - box.minY) / box.h) * H];
  return { box, px };
}

function pathFrom(g, pts, px) {
  g.beginPath();
  pts.forEach(([x, y], i) => { const [a, b] = px(x, y); if (i === 0) g.moveTo(a, b); else g.lineTo(a, b); });
  g.closePath();
}

/** Layered translucent blobs inside the current clip = watercolour mottling. */
function mottle(g, rng, W, H, colors, count, rMin, rMax, alpha) {
  for (let i = 0; i < count; i++) {
    const x = rng() * W, y = rng() * H, r = rMin + rng() * (rMax - rMin);
    const gr = g.createRadialGradient(x, y, r * 0.2, x, y, r);
    const col = colors[Math.floor(rng() * colors.length)];
    gr.addColorStop(0, col.replace('A', String(alpha)));
    gr.addColorStop(0.85, col.replace('A', String(alpha * 1.25)));
    gr.addColorStop(1, col.replace('A', '0'));
    g.fillStyle = gr;
    g.fillRect(x - r, y - r, r * 2, r * 2);
  }
}

function granulate(g, rng, W, H, n, rgb) {
  for (let i = 0; i < n; i++) {
    g.fillStyle = `rgba(${rgb},${0.06 + rng() * 0.12})`;
    g.fillRect(rng() * W, rng() * H, 1 + rng() * 1.5, 1 + rng() * 1.5);
  }
}

function leaf(g, x, y, s, ang, fill, vein) {
  g.save();
  g.translate(x, y); g.rotate(ang);
  g.beginPath();
  g.moveTo(0, -s);
  g.quadraticCurveTo(s * 0.7, -s * 0.2, 0, s);
  g.quadraticCurveTo(-s * 0.7, -s * 0.2, 0, -s);
  g.fillStyle = fill; g.fill();
  g.strokeStyle = vein; g.lineWidth = Math.max(1, s * 0.12);
  g.beginPath(); g.moveTo(0, -s * 0.8); g.lineTo(0, s * 0.9); g.stroke();
  g.restore();
}

/** Side walls of the card: a darkened copy of the print (~0.55x value, a little toward the cream core). */
function edgeChip(g, W, base) {
  const c = new THREE.Color(base);
  c.multiplyScalar(0.55).lerp(new THREE.Color(0xe8d3ac), 0.08);
  g.fillStyle = `#${c.getHexString()}`;
  g.fillRect(W - 10, 0, 10, 10);
}

/** A pale tone of a colour for the lit-side lip. */
function lipOf(base) {
  const c = new THREE.Color(base);
  c.lerp(new THREE.Color(0xfff4dc), 0.55);
  return `#${c.getHexString()}`;
}

/** Cut-paper layer: whatever `draw()` paints drops a short soft warm shadow away from the light (upper left). */
export function asLayer(g, draw, depth = 1) {
  g.save();
  g.shadowColor = 'rgba(74, 38, 14, 0.38)';
  g.shadowBlur = 4 * depth;
  g.shadowOffsetX = 2.5 * depth;
  g.shadowOffsetY = 3 * depth;
  draw();
  g.restore();
}

/**
 * Paint a card in the papercraft way: base sheet + mottled washes, structure layer (trunk), motif layers
 * that cast short soft shadows (cut paper collage), granulation, then THE CUT EDGE: a thin dark-brown line at
 * the silhouette and a pale highlight just inside it only on the edges that face the light (upper left).
 * `fills` are 'rgba(r,g,b,A)' templates. Returns a CanvasTexture.
 */
export function paintCard(points, { W = 512, H = 768, seed = 1, base, fills, edge, details, trunk }) {
  const c = makeCanvas(W, H), g = c.getContext('2d');
  const rng = mulberry32(seed);
  const { px } = frame(points, W, H);
  g.clearRect(0, 0, W, H);
  // bleed: the base colour beyond the outline so filtering never pulls in transparent black
  g.fillStyle = base; g.fillRect(0, 0, W, H);
  g.save();
  pathFrom(g, points, px);
  g.clip();
  mottle(g, rng, W, H, fills, 70, 20, 90, 0.22);
  if (trunk) asLayer(g, () => trunk(g, px, rng), 0.8);
  if (details) asLayer(g, () => details(g, px, rng), 1);
  mottle(g, rng, W, H, fills, 18, 10, 40, 0.1);
  granulate(g, rng, W, H, 2200, '60,40,25');
  // pigment pools slightly at the cut (dark, never a pale halo)
  pathFrom(g, points, px);
  g.strokeStyle = edge; g.lineWidth = 12; g.globalAlpha = 0.22; g.stroke();
  g.globalAlpha = 1;
  // lit-side highlight: the outline stroked again, shifted down-right, so only the upper-left edges show it
  g.translate(3.5, 4);
  pathFrom(g, points, px);
  g.strokeStyle = lipOf(base); g.lineWidth = 5; g.globalAlpha = 0.85; g.stroke();
  g.restore();
  // the cut: thin dark-brown line at the silhouette
  pathFrom(g, points, px);
  g.strokeStyle = INK; g.lineWidth = 2.6; g.lineJoin = 'round'; g.stroke();
  edgeChip(g, W, base);
  return toTexture(c);
}

/** A torn paper strip along a polyline: ragged edge + pale fibrous fringe (glued on, casts a short shadow). */
export function tornStrip(g, pts, width, fill, rng) {
  const top = [], bot = [];
  for (let i = 0; i < pts.length; i++) {
    const [x, y] = pts[i];
    const [nx, ny] = i < pts.length - 1 ? [pts[i + 1][0] - x, pts[i + 1][1] - y] : [x - pts[i - 1][0], y - pts[i - 1][1]];
    const l = Math.hypot(nx, ny) || 1, ox = -ny / l, oy = nx / l;
    top.push([x + ox * width * (0.5 + (rng() - 0.5) * 0.35), y + oy * width * (0.5 + (rng() - 0.5) * 0.35)]);
    bot.push([x - ox * width * (0.5 + (rng() - 0.5) * 0.5), y - oy * width * (0.5 + (rng() - 0.5) * 0.5)]);
  }
  const outline = [...top, ...bot.reverse()];
  asLayer(g, () => {
    // fibrous pale fringe a hair outside the torn edge
    g.beginPath(); outline.forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y))); g.closePath();
    g.strokeStyle = 'rgba(250, 242, 224, 0.9)'; g.lineWidth = 3.2; g.stroke();
    g.fillStyle = fill; g.fill();
  }, 0.8);
}

// ------------------------------------------------------------------ silhouettes

export function pineSilhouette(cut = 0) {
  // [halfWidth, tipY] per tier: the usual four-tier pine; a tall slim one of five; a stout old three-tier one
  const tiers = cut === 1 ? [[1.45, 1.0], [1.2, 1.85], [0.95, 2.65], [0.72, 3.4], [0.48, 4.05]] : cut === 2 ? [[1.95, 0.85], [1.55, 1.7], [1.1, 2.5]] : [[1.75, 0.95], [1.4, 1.75], [1.05, 2.5], [0.7, 3.2]];
  const R = [[0.16, 0], [0.16, tiers[0][1]]];
  const notch = cut === 1 ? [0.28, 0.32, 0.28, 0.22, 0.16] : cut === 2 ? [0.36, 0.4, 0.3] : [0.32, 0.38, 0.3, 0.22];
  tiers.forEach(([hw, ty], i) => {
    R.push([hw, ty - 0.12]);
    R.push([hw * 0.55, ty + 0.05]);
    R.push([notch[i], ty + 0.25]);
  });
  R.push([0.0, tiers[tiers.length - 1][1] + 1.05]);
  const L = R.slice(0, -1).reverse().map(([x, y]) => [-x, y]);
  return [...R, ...L];
}

export function roundTreeSilhouette(seed = 1) {
  const rng = mulberry32(seed);
  const cy = 2.75, R = 1.45, ph = rng() * 6;
  const pts = [[0.2, 0], [0.13, cy - R * 0.92]];
  const a0 = -Math.PI / 2 + 0.1, a1 = Math.PI * 1.5 - 0.1, n = 40;
  for (let i = 0; i <= n; i++) {
    const a = a0 + ((a1 - a0) * i) / n;
    const r = R * (1 + 0.07 * Math.sin(a * 6 + ph) + 0.035 * Math.sin(a * 11 + ph * 2));
    pts.push([Math.cos(a) * r * 1.02, cy + Math.sin(a) * r * 1.12]);
  }
  pts.push([-0.13, cy - R * 0.92], [-0.2, 0]);
  return pts;
}

export function bushSilhouette(seed = 1, bumps = 3, high = 0.75) {
  const rng = mulberry32(seed);
  const pts = [[0.95, 0]];
  const n = 30;
  for (let i = 0; i <= n; i++) {
    const t = i / n, x = 0.95 - t * 1.9;
    const hump = Math.sin(t * Math.PI) * high;
    const scal = Math.abs(Math.sin(t * Math.PI * bumps)) * 0.18;
    pts.push([x, 0.1 + hump + scal + (rng() - 0.5) * 0.02]);
  }
  pts.push([-0.95, 0]);
  return pts;
}

// ------------------------------------------------------------------ card painters

export function pineArt(points, seed = 21) {
  return paintCard(points, {
    seed, base: '#5d7a4c',
    fills: ['rgba(71,104,66,A)', 'rgba(108,132,78,A)', 'rgba(52,84,58,A)', 'rgba(138,150,90,A)'],
    edge: 'rgba(40,62,42,1)',
    trunk(g, px) {
      const [x0, y0] = px(-0.2, 0), [x1, y1] = px(0.2, 1.0);
      g.fillStyle = '#7b5236'; g.fillRect(x0, y1, x1 - x0, y0 - y1);
    },
    details(g, px, rng) {
      // needle strokes along each tier
      for (let i = 0; i < 520; i++) {
        const y = 1.0 + rng() * 3.0, hw = 1.75 - (y - 1.0) * 0.42;
        const x = (rng() - 0.5) * 2 * hw * 0.85;
        const [a, b] = px(x, y);
        const s = x > 0 ? 1 : -1;
        g.strokeStyle = rng() < 0.5 ? 'rgba(170,180,110,0.45)' : 'rgba(38,64,40,0.45)';
        g.lineWidth = 1.6;
        g.beginPath(); g.moveTo(a, b); g.lineTo(a + s * 9, b + 7); g.stroke();
      }
      // central stem line
      const [sx, sy] = px(0, 1.0), [ex, ey] = px(0, 4.1);
      g.strokeStyle = 'rgba(70,50,30,0.5)'; g.lineWidth = 3;
      g.beginPath(); g.moveTo(sx, sy); g.lineTo(ex, ey); g.stroke();
    },
  });
}

const AUTUMN = {
  maple: { base: '#d9773a', fills: ['rgba(214,96,48,A)', 'rgba(232,150,64,A)', 'rgba(190,70,46,A)', 'rgba(240,184,96,A)'], leaf: ['#b8452e', '#e39a3e', '#9c3a28'], edge: 'rgba(150,52,30,1)' },
  gold: { base: '#d9a441', fills: ['rgba(224,168,62,A)', 'rgba(240,198,104,A)', 'rgba(196,132,48,A)', 'rgba(170,150,70,A)'], leaf: ['#b77a2a', '#e8be5a', '#8f6a2a'], edge: 'rgba(150,100,30,1)' },
  apple: { base: '#7d9a4e', fills: ['rgba(110,150,76,A)', 'rgba(140,170,90,A)', 'rgba(90,126,64,A)', 'rgba(190,180,96,A)'], leaf: ['#5f8a44', '#9ab45a', '#4f7038'], edge: 'rgba(56,84,40,1)' },
  sage: { base: '#93a35c', fills: ['rgba(140,160,88,A)', 'rgba(170,176,96,A)', 'rgba(110,134,76,A)', 'rgba(200,170,90,A)'], leaf: ['#6f8a48', '#c9a24c', '#5a7040'], edge: 'rgba(80,96,52,1)' },
};

/**
 * A white birch: a slim chalk-white trunk with black bark marks (lenticel dashes and dark knots where old
 * branches fell), forking into a few thin dark branches under a narrow oval crown of small leaves, butter
 * yellow and spring green. Taller and lighter than the round trees: a bright stroke among the dark pines.
 */
/** A beaver lodge: a lumpy dome of gnawed sticks and mud standing out of the pond, stick ends bristling. */
export function lodgeSilhouette() {
  const pts = [[1.25, 0]];
  for (let i = 0; i <= 28; i++) {
    const t = i / 28, x = 1.25 - t * 2.5, hump = Math.sin(t * Math.PI) ** 0.8 * 1.0;
    pts.push([x, 0.05 + hump + (i % 3 === 1 ? 0.12 : 0) + (i % 5 === 2 ? 0.08 : 0)]);
  }
  pts.push([-1.25, 0]);
  return pts;
}
export function lodgeArt(points) {
  return paintCard(points, {
    W: 512, H: 256, seed: 401, base: '#6a5034', fills: ['rgba(106,80,52,A)', 'rgba(84,62,40,A)', 'rgba(120,96,64,A)'], edge: 'rgba(48,34,22,1)',
    details(g, px, rng) {
      for (let i = 0; i < 18; i++) { const [a, b] = px((rng() - 0.5) * 2, 0.1 + rng() * 0.6); g.fillStyle = 'rgba(70,66,48,0.55)'; g.beginPath(); g.ellipse(a, b, 18 + rng() * 14, 8 + rng() * 6, 0, 0, Math.PI * 2); g.fill(); } // daubs of mud
      for (let i = 0; i < 70; i++) { // gnawed sticks laid every which way, pale where the bark is chewed off
        const x = (rng() - 0.5) * 2.1, y = 0.1 + rng() * 0.85, ang = (rng() - 0.5) * 2.4, len = 0.12 + rng() * 0.3;
        const [a, b] = px(x, y), [c, d] = px(x + Math.cos(ang) * len, y + Math.sin(ang) * len);
        g.strokeStyle = rng() < 0.3 ? '#cdb48a' : rng() < 0.5 ? '#4a3420' : '#8a6a44'; g.lineWidth = 3 + rng() * 3; g.lineCap = 'round';
        g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke();
      }
    },
  });
}

/** A dead snag: a weathered silver trunk with a jagged broken top and a few stubby limbs reaching up. */
export function snagSilhouette() {
  return [[0.22, 0], [0.17, 1.55], [0.85, 2.05], [0.92, 2.2], [0.82, 2.18], [0.15, 1.75], [0.13, 3.15], [0.55, 3.5], [0.6, 3.62], [0.5, 3.6],
    [0.12, 3.32], [0.1, 3.98], [0.05, 4.22], [0.0, 4.0], [-0.05, 4.14], [-0.1, 3.95], [-0.12, 2.98], [-0.7, 3.25], [-0.78, 3.16], [-0.68, 3.14],
    [-0.13, 2.8], [-0.17, 1.2], [-0.22, 0]];
}
export function snagArt(points, seed = 61) {
  return paintCard(points, {
    W: 256, H: 512, seed, base: '#aaa397', fills: ['rgba(170,163,151,A)', 'rgba(150,142,130,A)', 'rgba(196,190,178,A)'], edge: 'rgba(70,64,56,1)',
    details(g, px, rng) {
      g.strokeStyle = 'rgba(60,54,48,0.6)'; g.lineCap = 'round';
      for (let i = 0; i < 14; i++) { // long grain cracks up the trunk
        const x = (rng() - 0.5) * 0.3, y0 = rng() * 2.5; g.lineWidth = 2 + rng() * 2;
        g.beginPath(); const [a, b] = px(x, y0); g.moveTo(a, b); for (let k = 1; k <= 4; k++) { const [c, d] = px(x + (rng() - 0.5) * 0.03, y0 + k * 0.3); g.lineTo(c, d); } g.stroke();
      }
      for (const [x, y] of [[0.02, 2.4], [-0.04, 1.3]]) { const [a, b] = px(x, y); g.fillStyle = '#3a322c'; g.beginPath(); g.ellipse(a, b, 7, 9, 0, 0, Math.PI * 2); g.fill(); } // woodpecker holes
      for (let i = 0; i < 18; i++) { const [a, b] = px((rng() - 0.5) * 0.3, rng() * 3.6); g.fillStyle = rng() < 0.5 ? 'rgba(168,184,120,0.75)' : 'rgba(214,206,160,0.7)'; g.beginPath(); g.arc(a, b, 3 + rng() * 4, 0, Math.PI * 2); g.fill(); } // lichen
      { const [a, b] = px(0, 4.0); g.fillStyle = 'rgba(232,222,196,0.8)'; g.beginPath(); g.ellipse(a, b, 9, 14, 0, 0, Math.PI * 2); g.fill(); } // pale broken heartwood at the top
    },
  });
}

export function birchSilhouette(seed = 1) {
  const rng = mulberry32(seed);
  const cy = 3.2, R = 0.95, ph = rng() * 6;
  const pts = [[0.11, 0], [0.08, cy - R * 1.25]];
  const a0 = -Math.PI / 2 + 0.12, a1 = Math.PI * 1.5 - 0.12, n = 40;
  for (let i = 0; i <= n; i++) {
    const a = a0 + ((a1 - a0) * i) / n;
    const r = R * (1 + 0.09 * Math.sin(a * 7 + ph) + 0.04 * Math.sin(a * 13 + ph * 2));
    pts.push([Math.cos(a) * r * 0.95, cy + Math.sin(a) * r * 1.35]);
  }
  pts.push([-0.08, cy - R * 1.25], [-0.11, 0]);
  return pts;
}

export function birchArt(points, seed = 23) {
  return paintCard(points, {
    seed, base: '#c9c75a', fills: ['rgba(214,196,88,A)', 'rgba(150,170,80,A)', 'rgba(232,214,120,A)'], edge: 'rgba(96,90,40,1)',
    trunk(g, px, rng) {
      const [x0, y0] = px(-0.11, 0), [x1, y1] = px(0.11, 2.4);
      g.fillStyle = '#efe9dc'; g.fillRect(x0, y1, x1 - x0, y0 - y1);
      g.fillStyle = 'rgba(200,190,170,0.6)'; g.fillRect(x1 - (x1 - x0) * 0.3, y1, (x1 - x0) * 0.3, y0 - y1); // its shaded side
      for (let i = 0; i < 26; i++) { // the black lenticel dashes, across the trunk
        const y = 0.1 + rng() * 2.2, [a, b] = px(-0.11 + rng() * 0.08, y), [c] = px(0.02 + rng() * 0.09, y);
        g.fillStyle = '#2b2622'; g.fillRect(a, b, c - a, 3 + rng() * 3);
      }
      for (const y of [0.9, 1.6, 2.1]) { const [a, b] = px(rng() < 0.5 ? -0.04 : 0.04, y); g.fillStyle = '#2b2622'; g.beginPath(); g.ellipse(a, b, 7, 4, 0, 0, Math.PI * 2); g.fill(); } // dark knots
    },
    details(g, px, rng) {
      g.strokeStyle = 'rgba(60,52,46,0.85)'; g.lineCap = 'round';
      const branch = (x, y, ang, len, w, depth) => {
        if (depth === 0 || len < 0.1) return;
        const ex = x + Math.cos(ang) * len, ey = y + Math.sin(ang) * len;
        const [a, b] = px(x, y), [c2, d] = px(ex, ey);
        g.lineWidth = w; g.beginPath(); g.moveTo(a, b); g.lineTo(c2, d); g.stroke();
        branch(ex, ey, ang + 0.35 + (rng() - 0.5) * 0.3, len * 0.7, w * 0.6, depth - 1);
        branch(ex, ey, ang - 0.35 + (rng() - 0.5) * 0.3, len * 0.7, w * 0.6, depth - 1);
      };
      branch(0, 2.2, Math.PI / 2, 0.8, 7, 4);
      for (let i = 0; i < 170; i++) { // small leaves, butter yellow and spring green
        const a = rng() * Math.PI * 2, r = Math.sqrt(rng()) * 0.92;
        const [x, y] = px(Math.cos(a) * r * 0.95, 3.2 + Math.sin(a) * r * 1.3);
        leaf(g, x, y, 5 + rng() * 4, rng() * 6.28, ['#e8c84a', '#d9b43a', '#a8b85a', '#f0d870'][Math.floor(rng() * 4)], 'rgba(90,70,20,0.45)');
      }
    },
  });
}

export function roundTreeArt(points, kind = 'maple', seed = 3) {
  const pal = AUTUMN[kind];
  return paintCard(points, {
    seed, base: pal.base, fills: pal.fills, edge: pal.edge,
    trunk(g, px) {
      const [x0, y0] = px(-0.2, 0), [x1, y1] = px(0.2, 1.6);
      g.fillStyle = '#6e4630'; g.fillRect(x0, y1, x1 - x0, y0 - y1);
    },
    details(g, px, rng) {
      // branches
      g.strokeStyle = 'rgba(96,58,36,0.85)'; g.lineCap = 'round';
      const branch = (x, y, ang, len, w, depth) => {
        if (depth === 0 || len < 0.12) return;
        const ex = x + Math.cos(ang) * len, ey = y + Math.sin(ang) * len;
        const [a, b] = px(x, y), [c2, d] = px(ex, ey);
        g.lineWidth = w; g.beginPath(); g.moveTo(a, b); g.lineTo(c2, d); g.stroke();
        branch(ex, ey, ang + 0.45 + (rng() - 0.5) * 0.3, len * 0.68, w * 0.62, depth - 1);
        branch(ex, ey, ang - 0.45 + (rng() - 0.5) * 0.3, len * 0.68, w * 0.62, depth - 1);
      };
      branch(0, 1.4, Math.PI / 2, 0.9, 11, 5);
      // leaf stamps
      for (let i = 0; i < 150; i++) {
        const a = rng() * Math.PI * 2, r = Math.sqrt(rng()) * 1.35;
        const [x, y] = px(Math.cos(a) * r, 2.75 + Math.sin(a) * r * 1.1);
        leaf(g, x, y, 7 + rng() * 6, rng() * 6.28, pal.leaf[Math.floor(rng() * pal.leaf.length)], 'rgba(80,40,20,0.45)');
      }
      if (kind === 'apple') {
        // red apples hung through the crown, each a little cut disc with a lit highlight and a stem
        for (let i = 0; i < 26; i++) {
          const a = rng() * Math.PI * 2, r = Math.sqrt(rng()) * 1.2;
          const [x, y] = px(Math.cos(a) * r, 2.7 + Math.sin(a) * r * 1.05);
          const rr = 9 + rng() * 4;
          asLayer(g, () => { g.fillStyle = rng() < 0.8 ? '#c4362f' : '#e0a03a'; g.beginPath(); g.arc(x, y, rr, 0, Math.PI * 2); g.fill(); }, 0.6);
          g.fillStyle = 'rgba(255,240,220,0.55)'; g.beginPath(); g.arc(x - rr * 0.35, y - rr * 0.35, rr * 0.3, 0, Math.PI * 2); g.fill();
          g.strokeStyle = '#4a3020'; g.lineWidth = 2; g.beginPath(); g.moveTo(x, y - rr); g.lineTo(x + 2, y - rr - 5); g.stroke();
        }
      }
    },
  });
}

/** A lost leather satchel, left by a stick with a red rag tied on so it can be found again. */
export function satchelSilhouette() {
  return [[-0.27, 0], [0.27, 0], [0.28, 0.32], [0.2, 0.37], [0.2, 0.8], [0.46, 0.86], [0.2, 0.94], [0.2, 1.04], [0.15, 1.04], [0.15, 0.37], [-0.2, 0.37], [-0.28, 0.32]];
}

export function satchelArt(points, seed = 117) {
  return paintCard(points, {
    W: 256, H: 384, seed, base: '#8a5a34',
    fills: ['rgba(138,90,52,A)', 'rgba(116,74,42,A)', 'rgba(160,110,66,A)'],
    edge: 'rgba(70,42,22,1)',
    details(g, px) {
      const rect = (x0, y0, x1, y1, col, d = 0.7) => { const [a, b] = px(x0, y1), [c, e] = px(x1, y0); asLayer(g, () => { g.fillStyle = col; g.fillRect(a, b, c - a, e - b); }, d); };
      rect(0.15, 0.36, 0.2, 1.04, '#6b4a30', 0.4);           // the stick
      const [f0x, f0y] = px(0.2, 0.94), [f1x, f1y] = px(0.46, 0.86), [f2x, f2y] = px(0.2, 0.8);
      asLayer(g, () => { g.fillStyle = '#c4362f'; g.beginPath(); g.moveTo(f0x, f0y); g.lineTo(f1x, f1y); g.lineTo(f2x, f2y); g.closePath(); g.fill(); }, 0.6);
      rect(-0.26, 0.17, 0.26, 0.34, '#6e4428');               // the flap
      g.strokeStyle = 'rgba(240,220,180,0.7)'; g.setLineDash([5, 4]); g.lineWidth = 2;
      const [s0x, s0y] = px(-0.22, 0.2), [s1x] = px(0.22, 0.2); g.beginPath(); g.moveTo(s0x, s0y); g.lineTo(s1x, s0y); g.stroke(); g.setLineDash([]);
      rect(-0.04, 0.12, 0.04, 0.22, '#d9a441', 0.4);          // brass buckle
    },
  });
}

/** A little heap of windfall apples in the grass. */
export function appleHeapSilhouette() {
  const pts = [[0.4, 0]];
  for (let i = 0; i <= 12; i++) { const t = (i / 12) * Math.PI; const bump = 1 + 0.12 * Math.abs(Math.sin(t * 4)); pts.push([Math.cos(t) * 0.4 * bump, 0.02 + Math.sin(t) * 0.26 * bump]); }
  pts.push([-0.4, 0]);
  return pts;
}

export function appleHeapArt(points, seed = 115) {
  return paintCard(points, {
    W: 256, H: 192, seed, base: '#9aa564',
    fills: ['rgba(154,165,100,A)', 'rgba(130,146,84,A)'],
    edge: 'rgba(70,86,44,1)',
    details(g, px, rng) {
      for (let i = 0; i < 9; i++) {
        const [x, y] = px((rng() - 0.5) * 0.6, 0.06 + rng() * 0.16 + (i > 5 ? 0.06 : 0));
        asLayer(g, () => { g.fillStyle = rng() < 0.75 ? '#c4362f' : '#e0a03a'; g.beginPath(); g.arc(x, y, 15 + rng() * 4, 0, Math.PI * 2); g.fill(); }, 0.6);
        g.fillStyle = 'rgba(255,240,220,0.5)'; g.beginPath(); g.arc(x - 5, y - 5, 4.5, 0, Math.PI * 2); g.fill();
      }
    },
  });
}

/**
 * Prairie wildflowers: a loose handful of separate stems standing up out of a low tuft of leaves, each with its own
 * bloom: purple coneflowers (pink petals drooping round a copper cone), black-eyed Susans (gold round a dark heart)
 * and little blue asters. The stems and the round heads are the cut outline, with sky between them, so it reads as
 * flowers, not a hedge.
 */
const BLOOMS = [[0.72, 0.6, 'susan'], [0.47, 0.86, 'cone'], [0.24, 0.52, 'aster'], [0.02, 0.96, 'cone'], [-0.22, 0.7, 'susan'], [-0.45, 0.48, 'aster'], [-0.67, 0.8, 'cone']];
// two more patches (right to left, as above): a run of black-eyed Susans with an aster or two; a tall clump of
// coneflowers over low asters
export const BLOOMS_SUSAN = [[0.7, 0.72, 'susan'], [0.44, 0.5, 'aster'], [0.2, 0.88, 'susan'], [-0.04, 0.62, 'susan'], [-0.3, 0.94, 'susan'], [-0.56, 0.55, 'aster'], [-0.74, 0.76, 'susan']];
export const BLOOMS_CONE = [[0.68, 0.5, 'aster'], [0.42, 1.02, 'cone'], [0.16, 0.78, 'cone'], [-0.1, 1.1, 'cone'], [-0.36, 0.46, 'aster'], [-0.6, 0.9, 'cone']];
const BLOOM_R = { cone: 0.12, susan: 0.11, aster: 0.08 };
const STEM_W = 0.028;
const tuftY = (x) => 0.12 + Math.abs(Math.sin(x * 9.1)) * 0.06 + Math.abs(Math.sin(x * 3.7)) * 0.04;
export function wildflowerSilhouette(blooms = BLOOMS) {
  // a true outline, right to left: along the leafy tuft, and at each flower up its stem, round its head and down
  const pts = [[0.95, 0], [0.95, tuftY(0.95)]];
  let x = 0.95;
  for (const [x0, h, kind] of blooms) { // (blooms run right to left)
    for (; x > x0 + STEM_W + 0.012; x -= 0.02) pts.push([x, tuftY(x)]);
    const r = BLOOM_R[kind], a = Math.asin(STEM_W / r);
    pts.push([x0 + STEM_W, tuftY(x0 + STEM_W)]);
    for (let k = 0; k <= 20; k++) { const t = -Math.PI / 2 + a + (k / 20) * (2 * Math.PI - 2 * a); pts.push([x0 + Math.cos(t) * r, h + Math.sin(t) * r]); }
    pts.push([x0 - STEM_W, tuftY(x0 - STEM_W)]);
    x = x0 - STEM_W - 0.012;
  }
  for (; x > -0.95; x -= 0.02) pts.push([x, tuftY(x)]);
  pts.push([-0.95, tuftY(-0.95)], [-0.95, 0]);
  return pts;
}
export function wildflowerArt(points, seed = 6, blooms = BLOOMS) {
  return paintCard(points, {
    W: 512, H: 400, seed,
    base: '#6f9450',
    fills: ['rgba(111,148,80,A)', 'rgba(132,164,94,A)', 'rgba(86,124,66,A)'],
    edge: 'rgba(44,66,34,1)',
    details(g, px, rng) {
      // the tuft: overlapping leaves along the ground
      for (let i = 0; i < 34; i++) { const lx = (rng() - 0.5) * 1.8, [a, b] = px(lx, 0.04 + rng() * (tuftY(lx) - 0.04)); leaf(g, a, b, 9 + rng() * 5, -1.2 - rng() * 0.8 + (lx < 0 ? -0.3 : 0.3), rng() < 0.5 ? '#557f40' : '#8fb066', 'rgba(30,50,24,0.5)'); }
      for (const [x0, h, kind] of blooms) {
        // the stem, a strip of darker green, with a leaf or two up it
        const [sa, sb] = px(x0, 0.08), [ta, tb] = px(x0, h);
        g.strokeStyle = '#4a6e36'; g.lineWidth = 7; g.beginPath(); g.moveTo(sa, sb); g.lineTo(ta, tb); g.stroke();
        g.strokeStyle = '#7ea25a'; g.lineWidth = 2.5; g.beginPath(); g.moveTo(sa - 1.5, sb); g.lineTo(ta - 1.5, tb); g.stroke();
        for (const t of [0.35, 0.6]) { const [la, lb] = px(x0, 0.08 + (h - 0.08) * t); leaf(g, la + (t < 0.5 ? 9 : -9), lb, 11, t < 0.5 ? -0.6 : -2.5, '#5f8a44', 'rgba(30,50,24,0.5)'); }
        const [ca, cb] = px(x0, h), R = (px(x0 + BLOOM_R[kind], h)[0] - ca);
        // the head's cut disc, inked in the bloom's deeper tone first, so no green shows round the petals
        g.fillStyle = kind === 'cone' ? '#a8467a' : kind === 'susan' ? '#c98a18' : '#6e78bc';
        g.beginPath(); g.arc(ca, cb, R * 1.08, 0, Math.PI * 2); g.fill();
        if (kind === 'cone') { // purple coneflower: pink petals hanging down from a domed copper cone
          for (let p = 0; p < 11; p++) {
            const pa = Math.PI * (-0.05 + 1.1 * (p / 10)), ex = ca + Math.cos(pa) * R * 0.6, ey = cb + Math.sin(pa) * R * 0.55 + R * 0.08;
            g.fillStyle = p % 2 ? '#d47aa6' : '#c45f94'; g.beginPath(); g.ellipse(ex, ey, R * 0.16, R * 0.42, pa - Math.PI / 2, 0, Math.PI * 2); g.fill();
            g.strokeStyle = 'rgba(110,40,80,0.55)'; g.lineWidth = 1.4; g.stroke();
          }
          g.fillStyle = '#b8642a'; g.beginPath(); g.ellipse(ca, cb + R * 0.05, R * 0.62, R * 0.62, 0, Math.PI, 0); g.lineTo(ca + R * 0.62, cb + R * 0.12); g.lineTo(ca - R * 0.62, cb + R * 0.12); g.fill(); g.strokeStyle = 'rgba(90,40,10,0.6)'; g.lineWidth = 1.5; g.stroke();
          g.fillStyle = '#e09a4a'; for (let k = 0; k < 14; k++) { const ka = Math.PI * (1.08 + (k % 7) * 0.12), kr = R * (k < 7 ? 0.45 : 0.25); g.beginPath(); g.arc(ca + Math.cos(ka) * kr, cb + Math.sin(ka) * kr, R * 0.06, 0, Math.PI * 2); g.fill(); }
        } else { // a daisy face: petals all round a heart (gold round brown for the Susan, lilac-blue round gold for the aster)
          const n = kind === 'susan' ? 12 : 14;
          for (let p = 0; p < n; p++) {
            const pa = (p / n) * Math.PI * 2, ex = ca + Math.cos(pa) * R * 0.6, ey = cb + Math.sin(pa) * R * 0.6;
            g.fillStyle = kind === 'susan' ? (p % 2 ? '#f0bc32' : '#e3a422') : (p % 2 ? '#8f9ad8' : '#a7aee6');
            g.beginPath(); g.ellipse(ex, ey, R * 0.42, R * 0.13, pa, 0, Math.PI * 2); g.fill();
            g.strokeStyle = kind === 'susan' ? 'rgba(130,80,10,0.5)' : 'rgba(60,60,120,0.5)'; g.lineWidth = 1.2; g.stroke();
          }
          g.fillStyle = kind === 'susan' ? '#4a2a18' : '#e8b42e'; g.beginPath(); g.arc(ca, cb, R * (kind === 'susan' ? 0.26 : 0.2), 0, Math.PI * 2); g.fill();
          g.fillStyle = 'rgba(255,240,200,0.35)'; g.beginPath(); g.arc(ca - R * 0.07, cb - R * 0.07, R * 0.08, 0, Math.PI * 2); g.fill();
        }
      }
    },
  });
}

export function bushArt(points, berries, seed = 5) {
  return paintCard(points, {
    W: 512, H: 320, seed,
    base: '#3f7d74',
    fills: ['rgba(52,120,110,A)', 'rgba(70,140,120,A)', 'rgba(40,96,92,A)', 'rgba(120,150,96,A)'],
    edge: 'rgba(28,70,64,1)',
    details(g, px, rng) {
      for (let i = 0; i < 60; i++) {
        const x = (rng() - 0.5) * 1.6, y = 0.15 + rng() * 0.7;
        const [a, b] = px(x, y);
        leaf(g, a, b, 9 + rng() * 6, rng() * 6.28, rng() < 0.5 ? '#2f6a62' : '#6f9b6a', 'rgba(20,50,40,0.5)');
      }
      for (let i = 0; i < (berries ? 26 : 12); i++) {
        const x = (rng() - 0.5) * 1.5, y = 0.2 + rng() * 0.6;
        const [a, b] = px(x, y);
        if (berries) {
          g.fillStyle = rng() < 0.5 ? '#c4363a' : '#a8272f';
          g.beginPath(); g.arc(a, b, 6 + rng() * 3, 0, Math.PI * 2); g.fill();
          g.fillStyle = 'rgba(255,240,220,0.7)'; g.beginPath(); g.arc(a - 2, b - 2, 1.6, 0, Math.PI * 2); g.fill();
        } else {
          for (let p = 0; p < 6; p++) {
            const pa = (p / 6) * Math.PI * 2;
            g.fillStyle = '#f0dcb0';
            g.beginPath(); g.ellipse(a + Math.cos(pa) * 6, b + Math.sin(pa) * 6, 5, 3, pa, 0, Math.PI * 2); g.fill();
          }
          g.fillStyle = '#e08a3a'; g.beginPath(); g.arc(a, b, 3.5, 0, Math.PI * 2); g.fill();
        }
      }
    },
  });
}

/** Generic painted rectangle panel, for building walls/roofs. `draw(g, W, H, rng)` adds detail. */
export function panelArt(W, H, base, fills, draw, seed = 9) {
  const c = makeCanvas(W, H), g = c.getContext('2d');
  const rng = mulberry32(seed);
  g.fillStyle = base; g.fillRect(0, 0, W, H);
  mottle(g, rng, W, H, fills, 60, 20, 80, 0.2);
  if (draw) draw(g, W, H, rng);
  granulate(g, rng, W, H, (W * H) / 120, '60,40,25');
  g.strokeStyle = INK; g.lineWidth = 4; g.strokeRect(2, 2, W - 4, H - 4);
  return toTexture(c);
}

// ------------------------------------------------------------------ new pieces: grass, hills, peaks, rocks

/** Chunky grass tuft: 5 fat blades (nothing thin or spiky). */
export function grassSilhouette(seed = 1) {
  const rng = mulberry32(seed);
  const pts = [[0.55, 0]];
  const blades = [[0.42, 0.55], [0.22, 0.85], [0.0, 1.0], [-0.22, 0.8], [-0.42, 0.5]];
  for (const [x, h] of blades) {
    const lean = (rng() - 0.5) * 0.12;
    pts.push([x + 0.11, 0.18], [x + 0.05 + lean, h * 0.85], [x + lean, h], [x - 0.05 + lean, h * 0.85], [x - 0.11, 0.18]);
  }
  pts.push([-0.55, 0]);
  return pts;
}

export function grassArt(points, seed = 31) {
  return paintCard(points, {
    W: 256, H: 256, seed, base: '#9aa564',
    fills: ['rgba(150,166,92,A)', 'rgba(120,140,76,A)', 'rgba(184,180,104,A)'],
    edge: 'rgba(70,86,44,1)',
    details(g, px, rng) {
      for (let i = 0; i < 9; i++) {
        const [a, b] = px((rng() - 0.5) * 0.8, 0.15 + rng() * 0.5);
        g.fillStyle = rng() < 0.5 ? '#7d9150' : '#c3b46a';
        g.beginPath(); g.ellipse(a, b, 5, 14, (rng() - 0.5) * 0.6, 0, Math.PI * 2); g.fill();
      }
    },
  });
}

// ------------------------------------------------------------------ pond life: cattails and lily pads

export function cattailSilhouette() {
  const pts = [[0.55, 0]];
  const blade = (x, h) => pts.push([x + 0.07, 0.15], [x + 0.03, h * 0.85], [x, h], [x - 0.03, h * 0.85], [x - 0.07, 0.15]);
  const stem = (x, h0, h1) => pts.push([x + 0.025, 0.15], [x + 0.025, h0], [x + 0.07, h0 + 0.05], [x + 0.07, h1 - 0.05], [x + 0.02, h1],
    [x + 0.012, h1 + 0.16], [x - 0.012, h1 + 0.16], [x - 0.02, h1], [x - 0.07, h1 - 0.05], [x - 0.07, h0 + 0.05], [x - 0.025, h0], [x - 0.025, 0.15]);
  blade(0.42, 0.9); stem(0.24, 0.95, 1.3); blade(0.06, 1.25); stem(-0.12, 1.12, 1.48); blade(-0.3, 1.0); blade(-0.46, 0.68);
  pts.push([-0.55, 0]);
  return pts;
}

export function cattailArt(points, seed = 103) {
  return paintCard(points, {
    W: 256, H: 384, seed, base: '#8c9a58',
    fills: ['rgba(140,154,88,A)', 'rgba(116,130,70,A)', 'rgba(170,170,100,A)'],
    edge: 'rgba(64,72,36,1)',
    details(g, px) {
      // the velvet-brown heads, each a cut layer with a lit lip
      for (const [x, h0, h1] of [[0.24, 0.95, 1.3], [-0.12, 1.12, 1.48]]) {
        const [a, b] = px(x - 0.075, h1 - 0.02), [c, d] = px(x + 0.075, h0 + 0.02);
        asLayer(g, () => { g.fillStyle = '#7a4a2a'; g.beginPath(); g.roundRect(a, b, c - a, d - b, 9); g.fill(); }, 0.7);
        g.fillStyle = 'rgba(186,130,84,0.55)'; g.fillRect(a + 3, b + 6, 4, d - b - 12);
      }
      // blade midribs
      g.strokeStyle = 'rgba(214,214,150,0.5)'; g.lineWidth = 2;
      for (const [x, h] of [[0.42, 0.9], [0.06, 1.25], [-0.3, 1.0], [-0.46, 0.68]]) { const [a, b] = px(x, 0.2), [c, d] = px(x, h * 0.85); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); }
    },
  });
}

export function lilypadSilhouette() {
  // a round pad with its notch, centred on the origin (laid flat on the water)
  const pts = [[0, 0]];
  for (let i = 0; i <= 16; i++) { const a = 0.32 + (i / 16) * (Math.PI * 2 - 0.64); pts.push([Math.sin(a) * 0.5, Math.cos(a) * 0.5]); }
  return pts;
}

export function lilypadArt(points, bloom, seed = 105) {
  return paintCard(points, {
    W: 256, H: 256, seed, base: '#5f8a52',
    fills: ['rgba(95,138,82,A)', 'rgba(80,120,70,A)', 'rgba(124,160,96,A)'],
    edge: 'rgba(40,64,34,1)',
    details(g, px) {
      const [cx, cy] = px(0, 0);
      g.strokeStyle = 'rgba(190,214,150,0.55)'; g.lineWidth = 2.5;
      for (let i = 0; i < 9; i++) { const a = 0.6 + (i / 8) * (Math.PI * 2 - 1.2); const [x, y] = px(Math.sin(a) * 0.44, Math.cos(a) * 0.44); g.beginPath(); g.moveTo(cx, cy); g.lineTo(x, y); g.stroke(); }
      if (bloom) {
        // a water lily: cream petals blushing pink, a butter-yellow heart
        const [fx, fy] = px(0.08, -0.12);
        asLayer(g, () => {
          for (let i = 0; i < 8; i++) {
            const a = (i / 8) * Math.PI * 2;
            g.fillStyle = i % 2 ? '#f1e2d6' : '#e9b8b4';
            g.beginPath(); g.ellipse(fx + Math.cos(a) * 22, fy + Math.sin(a) * 22, 11, 26, a + Math.PI / 2, 0, Math.PI * 2); g.fill();
          }
        });
        asLayer(g, () => { g.fillStyle = '#e8c04a'; g.beginPath(); g.arc(fx, fy, 11, 0, Math.PI * 2); g.fill(); }, 0.5);
      }
    },
  });
}

/** A hill sail: flat base, a broad hump with a couple of soft lobes. Units: ~10 wide, ~4 tall. */
export function hillSilhouette(seed = 1, w = 10, h = 4) {
  const rng = mulberry32(seed);
  const pts = [[w / 2, 0]];
  const n = 28, ph = rng() * 6;
  for (let i = 0; i <= n; i++) {
    const t = i / n, x = w / 2 - t * w;
    const hump = Math.pow(Math.sin(t * Math.PI), 0.8) * h;
    const lobes = Math.sin(t * Math.PI * 3 + ph) * 0.12 * h * Math.sin(t * Math.PI);
    pts.push([x, Math.max(0.15, hump + lobes)]);
  }
  pts.push([-w / 2, 0]);
  return pts;
}

function crestLine(points, px, inset) {
  // the top edge of the silhouette, pushed down by `inset` world units
  return points.slice(1, -1).map(([x, y]) => px(x, Math.max(0, y - inset)));
}

export function hillArt(points, seed = 41) {
  return paintCard(points, {
    W: 768, H: 320, seed, base: '#a4a06a',
    fills: ['rgba(164,160,104,A)', 'rgba(138,146,92,A)', 'rgba(196,176,110,A)', 'rgba(176,132,80,A)'],
    edge: 'rgba(84,80,46,1)',
    details(g, px, rng) {
      // rows of little printed trees (autumn dots and pine wedges) across the slope
      for (let i = 0; i < 60; i++) {
        const x = (rng() - 0.5) * 9, y = 0.25 + rng() * 2.6;
        const [a, b] = px(x, y);
        if (rng() < 0.45) {
          g.fillStyle = ['#c86a34', '#d9a441', '#b8452e'][Math.floor(rng() * 3)];
          g.beginPath(); g.arc(a, b, 7 + rng() * 5, 0, Math.PI * 2); g.fill();
        } else {
          g.fillStyle = rng() < 0.5 ? '#5f7a4c' : '#6f8a52';
          g.beginPath(); g.moveTo(a, b - 16); g.lineTo(a + 8, b + 6); g.lineTo(a - 8, b + 6); g.closePath(); g.fill();
        }
      }
      // a lighter glued crest band with a torn lower edge
      tornStrip(g, crestLine(points, px, 0.25), 16, '#c9c38c', rng);
    },
  });
}

export function peakArt(points, seed = 51) {
  return paintCard(points, {
    W: 768, H: 320, seed, base: '#8f94a6',
    fills: ['rgba(143,148,166,A)', 'rgba(118,124,146,A)', 'rgba(170,170,180,A)'],
    edge: 'rgba(60,64,84,1)',
    details(g, px, rng) {
      // strata scratches and a torn snow cap
      g.strokeStyle = 'rgba(70,74,96,0.45)'; g.lineWidth = 3;
      for (let i = 0; i < 14; i++) {
        const y = 0.3 + rng() * 3, x = (rng() - 0.5) * 7;
        const [a, b] = px(x, y), [c2, d] = px(x + 0.8 + rng(), y + (rng() - 0.5) * 0.3);
        g.beginPath(); g.moveTo(a, b); g.lineTo(c2, d); g.stroke();
      }
      tornStrip(g, crestLine(points, px, 0.45), 40, '#f3eee2', rng);
    },
  });
}

/** A chunky rock slab card (one face of an outcrop). */
export function rockSilhouette(seed = 1) {
  const rng = mulberry32(seed);
  const pts = [[0.55, 0], [0.62, 0.45 + rng() * 0.2], [0.4, 1.05 + rng() * 0.25], [0.05, 1.35 + rng() * 0.2], [-0.35, 1.1 + rng() * 0.2], [-0.6, 0.5 + rng() * 0.2], [-0.55, 0]];
  return pts;
}

export function rockArt(points, seed = 61) {
  return paintCard(points, {
    W: 320, H: 384, seed, base: '#b9ad99',
    fills: ['rgba(185,173,153,A)', 'rgba(160,150,134,A)', 'rgba(204,194,176,A)'],
    edge: 'rgba(82,72,60,1)',
    details(g, px, rng) {
      // folded facet: the right side turned from the light, a crease line between them
      const [a0, b0] = px(0.1, 0), [a1, b1] = px(0.05, 1.5), [a2] = px(0.7, 0);
      g.fillStyle = 'rgba(120,108,94,0.55)';
      g.beginPath(); g.moveTo(a0, b0); g.lineTo(a1, b1); g.lineTo(a2 + 40, b1); g.lineTo(a2 + 40, b0); g.closePath(); g.fill();
      g.strokeStyle = 'rgba(80,68,56,0.6)'; g.lineWidth = 2;
      for (let i = 0; i < 4; i++) {
        const [x, y] = px((rng() - 0.5) * 0.9, 0.2 + rng() * 0.9);
        g.beginPath(); g.moveTo(x, y); g.lineTo(x + (rng() - 0.5) * 30, y + 12 + rng() * 14); g.stroke();
      }
      for (let i = 0; i < 6; i++) {
        const [x, y] = px((rng() - 0.5) * 0.9, 0.1 + rng() * 0.6);
        g.fillStyle = rng() < 0.5 ? '#8f9a64' : '#c9b46a';
        g.beginPath(); g.arc(x, y, 4 + rng() * 4, 0, Math.PI * 2); g.fill();
      }
    },
  });
}

// ------------------------------------------------------------------ handmade paper + noise

/**
 * Handmade paper, 512² and tiling, in colour: cloudy pulp formation, long and short fibres, and sparse
 * inclusions (plant bits, seed husks, the odd petal fleck) like real cotton-rag / flower paper.
 * Mean colour is a warm cream (~#ede4cf); shaders divide by that to use it as a tint.
 */
export function handmadePaperTexture() {
  const S = 512, c = makeCanvas(S, S), g = c.getContext('2d');
  const rng = mulberry32(2026);
  g.fillStyle = '#ede4cf';
  g.fillRect(0, 0, S, S);
  // pulp formation: soft cloudy density variations
  for (let i = 0; i < 420; i++) {
    const x = rng() * S, y = rng() * S, r = 10 + rng() * 60, light = rng() < 0.55;
    const a = 0.03 + rng() * 0.05;
    wrapped(S, (dx, dy) => {
      const gr = g.createRadialGradient(x + dx, y + dy, 0, x + dx, y + dy, r);
      gr.addColorStop(0, light ? `rgba(255,252,242,${a})` : `rgba(196,182,152,${a})`);
      gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr;
      g.fillRect(x + dx - r, y + dy - r, r * 2, r * 2);
    });
  }
  // fibres: mostly short and pale, some long wandering dark ones
  g.lineCap = 'round';
  for (let i = 0; i < 3200; i++) {
    const long = rng() < 0.08;
    let x = rng() * S, y = rng() * S, a = rng() * Math.PI * 2;
    const steps = long ? 10 + Math.floor(rng() * 10) : 3 + Math.floor(rng() * 4);
    const seg = long ? 4 + rng() * 3 : 2 + rng() * 2.5;
    const light = rng() < 0.7;
    g.strokeStyle = light ? `rgba(255,253,246,${0.25 + rng() * 0.35})` : `rgba(120,98,70,${0.08 + rng() * (long ? 0.2 : 0.1)})`;
    g.lineWidth = long ? 0.6 + rng() * 0.6 : 0.5 + rng() * 0.9;
    const pts = [[x, y]];
    for (let k = 0; k < steps; k++) { a += (rng() - 0.5) * 0.7; x += Math.cos(a) * seg; y += Math.sin(a) * seg; pts.push([x, y]); }
    wrapped(S, (dx, dy) => {
      g.beginPath();
      pts.forEach(([px, py], k) => (k ? g.lineTo(px + dx, py + dy) : g.moveTo(px + dx, py + dy)));
      g.stroke();
    });
  }
  // inclusions: plant fragments, husks, petal flecks (sparse, small)
  const incl = [['rgba(110,84,52,0.55)', 70], ['rgba(98,112,64,0.45)', 26], ['rgba(196,120,96,0.45)', 10], ['rgba(214,170,80,0.45)', 10]];
  for (const [col, n] of incl) {
    for (let i = 0; i < n; i++) {
      const x = rng() * S, y = rng() * S, a = rng() * Math.PI, l = 1.5 + rng() * 4, w = 0.6 + rng() * 1.2;
      wrapped(S, (dx, dy) => {
        g.save(); g.translate(x + dx, y + dy); g.rotate(a);
        g.fillStyle = col; g.beginPath(); g.ellipse(0, 0, l, w, 0, 0, Math.PI * 2); g.fill();
        g.restore();
      });
    }
  }
  return toTexture(c, { srgb: true, repeat: true });
}

/** Tileable smooth value noise: R = broad (periods 64/32 px), G = medium (16/8), B = fine (4/2). */
export function noiseTexture() {
  const S = 256, c = makeCanvas(S, S), g = c.getContext('2d');
  const img = g.createImageData(S, S);
  const rng = mulberry32(77);
  const layer = (period) => {
    const n = S / period, grid = new Float32Array(n * n);
    for (let i = 0; i < grid.length; i++) grid[i] = rng();
    const fade = (t) => t * t * (3 - 2 * t);
    return (x, y) => {
      const gx = x / period, gy = y / period;
      const x0 = Math.floor(gx), y0 = Math.floor(gy), tx = fade(gx - x0), ty = fade(gy - y0);
      const at = (i, j) => grid[((j % n) + n) % n * n + ((i % n) + n) % n];
      const a = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * tx;
      const b = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * tx;
      return a + (b - a) * ty;
    };
  };
  const r1 = layer(64), r2 = layer(32), g1 = layer(16), g2 = layer(8), b1 = layer(4), b2 = layer(2);
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      const o = (y * S + x) * 4;
      img.data[o] = (r1(x, y) * 0.65 + r2(x, y) * 0.35) * 255;
      img.data[o + 1] = (g1(x, y) * 0.65 + g2(x, y) * 0.35) * 255;
      img.data[o + 2] = (b1(x, y) * 0.6 + b2(x, y) * 0.4) * 255;
      img.data[o + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  return toTexture(c, { srgb: false, repeat: true });
}

// ------------------------------------------------------------------ gatherables: clay, toadstools, ore, hives

export function clayArt(points, seed = 81) {
  return paintCard(points, {
    W: 384, H: 256, seed, base: '#b8693f',
    fills: ['rgba(184,105,63,A)', 'rgba(160,86,52,A)', 'rgba(204,130,84,A)'],
    edge: 'rgba(110,54,30,1)',
    details(g, px, rng) {
      g.strokeStyle = 'rgba(120,60,34,0.6)'; g.lineWidth = 3;
      for (let k = 0; k < 4; k++) {
        const y = 0.15 + k * 0.16;
        g.beginPath();
        for (let i = 0; i <= 12; i++) { const [a, b] = px(-0.9 + i * 0.15, y + Math.sin(i * 1.3 + k) * 0.02); i ? g.lineTo(a, b) : g.moveTo(a, b); }
        g.stroke();
      }
      for (let i = 0; i < 10; i++) { const [a, b] = px((rng() - 0.5) * 1.5, 0.1 + rng() * 0.5); g.fillStyle = 'rgba(232,196,160,0.6)'; g.beginPath(); g.arc(a, b, 3 + rng() * 3, 0, Math.PI * 2); g.fill(); }
    },
  });
}

export function toadstoolSilhouette() {
  // three toadstools on one card, chunky caps
  const pts = [[0.55, 0]];
  const caps = [[0.32, 0.42, 0.2], [-0.02, 0.62, 0.26], [-0.36, 0.34, 0.18]];
  for (const [x, h, r] of caps) {
    pts.push([x + 0.06, 0], [x + 0.06, h - 0.04], [x + r, h], [x + r * 0.8, h + r * 0.55], [x, h + r * 0.75], [x - r * 0.8, h + r * 0.55], [x - r, h], [x - 0.06, h - 0.04], [x - 0.06, 0]);
  }
  pts.push([-0.55, 0]);
  return pts;
}

export function toadstoolArt(points, seed = 83) {
  return paintCard(points, {
    W: 320, H: 320, seed, base: '#efe3cc',
    fills: ['rgba(239,227,204,A)', 'rgba(220,206,180,A)'],
    edge: 'rgba(110,70,40,1)',
    details(g, px, rng) {
      for (const [x, h, r] of [[0.32, 0.42, 0.2], [-0.02, 0.62, 0.26], [-0.36, 0.34, 0.18]]) {
        const [cx, cy] = px(x, h + r * 0.3);
        const [rx] = px(x + r, 0);
        const rr = rx - cx;
        g.fillStyle = '#c4362f'; g.beginPath(); g.ellipse(cx, cy, rr * 1.02, rr * 0.62, 0, Math.PI, 0); g.lineTo(cx + rr, cy + rr * 0.12); g.lineTo(cx - rr, cy + rr * 0.12); g.fill();
        g.fillStyle = '#f6efe0';
        for (let k = 0; k < 4; k++) { g.beginPath(); g.arc(cx + (rng() - 0.5) * rr * 1.2, cy - rng() * rr * 0.45, 3 + rng() * 4, 0, Math.PI * 2); g.fill(); }
      }
    },
  });
}

export function oreArt(points, seed = 85) {
  return paintCard(points, {
    W: 320, H: 384, seed, base: '#8f8a86',
    fills: ['rgba(143,138,134,A)', 'rgba(116,110,108,A)', 'rgba(170,164,158,A)'],
    edge: 'rgba(60,54,50,1)',
    details(g, px, rng) {
      const [a0, b0] = px(0.1, 0), [a1, b1] = px(0.05, 1.5), [a2] = px(0.7, 0);
      g.fillStyle = 'rgba(80,74,72,0.5)';
      g.beginPath(); g.moveTo(a0, b0); g.lineTo(a1, b1); g.lineTo(a2 + 40, b1); g.lineTo(a2 + 40, b0); g.closePath(); g.fill();
      // rusty iron seams and flecks
      g.strokeStyle = 'rgba(176,84,40,0.85)'; g.lineWidth = 5;
      for (let i = 0; i < 3; i++) {
        g.beginPath();
        let [x, y] = px((rng() - 0.5) * 0.8, 0.2 + rng() * 0.6); g.moveTo(x, y);
        for (let k = 0; k < 4; k++) { x += (rng() - 0.3) * 40; y -= 10 + rng() * 20; g.lineTo(x, y); }
        g.stroke();
      }
      for (let i = 0; i < 14; i++) { const [x, y] = px((rng() - 0.5) * 0.9, 0.1 + rng() * 1.0); g.fillStyle = rng() < 0.6 ? '#c46a32' : '#e0a050'; g.beginPath(); g.arc(x, y, 3 + rng() * 5, 0, Math.PI * 2); g.fill(); }
    },
  });
}

/** Gold quartz: a milky white ledge shot through with seams of rusty iron stain and fat wires and flakes of gold. */
export function quartzArt(points, seed = 91) {
  return paintCard(points, {
    W: 320, H: 384, seed, base: '#dcd6cc',
    fills: ['rgba(220,214,204,A)', 'rgba(184,178,170,A)', 'rgba(242,238,230,A)'],
    edge: 'rgba(92,78,64,1)',
    details(g, px, rng) {
      const [a0, b0] = px(0.1, 0), [a1, b1] = px(0.05, 1.5), [a2] = px(0.7, 0);
      g.fillStyle = 'rgba(160,146,128,0.45)'; // the shaded face
      g.beginPath(); g.moveTo(a0, b0); g.lineTo(a1, b1); g.lineTo(a2 + 40, b1); g.lineTo(a2 + 40, b0); g.closePath(); g.fill();
      g.strokeStyle = 'rgba(176,110,60,0.55)'; g.lineWidth = 9; // rusty stain along the seams
      const seams = [];
      for (let i = 0; i < 3; i++) {
        const pts = []; let [x, y] = px((rng() - 0.5) * 0.8, 0.15 + rng() * 0.5); pts.push([x, y]);
        for (let k = 0; k < 4; k++) { x += (rng() - 0.3) * 44; y -= 12 + rng() * 20; pts.push([x, y]); }
        seams.push(pts); g.beginPath(); pts.forEach(([u, v], j) => (j ? g.lineTo(u, v) : g.moveTo(u, v))); g.stroke();
      }
      g.strokeStyle = '#e8b830'; g.lineWidth = 7; // the gold wire in the seams
      for (const pts of seams) { g.beginPath(); pts.forEach(([u, v], j) => (j ? g.lineTo(u, v) : g.moveTo(u, v))); g.stroke(); }
      for (let i = 0; i < 18; i++) { // fat flakes: a gold blob with a bright lip
        const [x, y] = px((rng() - 0.5) * 0.85, 0.1 + rng() * 1.0), r = 6 + rng() * 8;
        g.fillStyle = '#c8901e'; g.beginPath(); g.arc(x + 1.5, y + 1.5, r, 0, Math.PI * 2); g.fill();
        g.fillStyle = '#f0c840'; g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.fill();
        g.fillStyle = '#fff2b0'; g.beginPath(); g.arc(x - r * 0.35, y - r * 0.35, r * 0.35, 0, Math.PI * 2); g.fill();
      }
    },
  });
}

// ------------------------------------------------------------------ the kitchen garden: corn and pumpkins

export function cornSilhouette() {
  // a stalk with arching leaf blades and a tassel; chunky, flat base
  // two husked ears stand proud of the stalk (one each side) so they read from the camera
  return [[0.07, 0], [0.08, 0.5], [0.5, 0.7], [0.56, 0.86], [0.1, 0.72], [0.1, 0.76], [0.2, 0.76], [0.27, 0.88], [0.24, 1.02], [0.13, 1.04],
    [0.1, 1.1], [0.44, 1.32], [0.42, 1.44], [0.09, 1.3],
    [0.08, 1.7], [0.2, 1.92], [0.02, 1.86], [-0.14, 1.96], [-0.08, 1.7], [-0.08, 1.54], [-0.17, 1.53], [-0.26, 1.42], [-0.23, 1.31], [-0.1, 1.27],
    [-0.08, 1.2], [-0.46, 1.3], [-0.52, 1.18], [-0.08, 1.02],
    [-0.08, 0.62], [-0.48, 0.46], [-0.46, 0.34], [-0.07, 0.44], [-0.06, 0]];
}

export function cornArt(points, seed = 95) {
  return paintCard(points, {
    W: 256, H: 512, seed, base: '#8a9a4e',
    fills: ['rgba(138,154,78,A)', 'rgba(116,132,64,A)', 'rgba(170,176,96,A)'],
    edge: 'rgba(60,70,30,1)',
    details(g, px, rng) {
      // leaf midribs
      g.strokeStyle = 'rgba(214,214,150,0.6)'; g.lineWidth = 2.5;
      for (const [[a, b], [c, d]] of [[[0.1, 0.55], [0.5, 0.78]], [[0.1, 1.15], [0.42, 1.38]], [[-0.08, 1.07], [-0.48, 1.24]], [[-0.07, 0.5], [-0.46, 0.4]]]) {
        const [x0, y0] = px(a, b), [x1, y1] = px(c, d); g.beginPath(); g.moveTo(x0, y0); g.quadraticCurveTo((x0 + x1) / 2, Math.min(y0, y1) - 10, x1, y1); g.stroke();
      }
      // two ears in husks with golden kernels peeking out, and a straw tassel
      for (const [ex, ey, rot] of [[0.19, 0.9, 0.35], [-0.17, 1.41, -0.4]]) {
        const [x, y] = px(ex, ey);
        asLayer(g, () => {
          g.save(); g.translate(x, y); g.rotate(rot);
          g.fillStyle = '#ecc24a'; g.beginPath(); g.ellipse(0, 0, 14, 30, 0, 0, Math.PI * 2); g.fill();
          g.fillStyle = 'rgba(176,130,40,0.7)';
          for (let k = -3; k <= 3; k++) for (const s of [-5, 0, 5]) { g.beginPath(); g.arc(s, k * 7, 2.6, 0, Math.PI * 2); g.fill(); }
          // husk leaves wrap only the lower half, so the gold shows; a pale silk tuft on top
          g.fillStyle = '#9fae5a'; g.beginPath(); g.moveTo(-15, 30); g.quadraticCurveTo(-17, 12, -8, 2); g.lineTo(-3, 30); g.fill();
          g.beginPath(); g.moveTo(15, 30); g.quadraticCurveTo(17, 14, 8, 4); g.lineTo(3, 30); g.fill();
          g.strokeStyle = '#efe0a8'; g.lineWidth = 2; for (let k = -1; k <= 1; k++) { g.beginPath(); g.moveTo(0, -28); g.quadraticCurveTo(k * 6, -38, k * 9, -42); g.stroke(); }
          g.restore();
        });
      }
      const [tx, ty] = px(0.02, 1.86); g.strokeStyle = '#d9b24c'; g.lineWidth = 3;
      for (let k = -2; k <= 2; k++) { g.beginPath(); g.moveTo(tx, ty + 10); g.lineTo(tx + k * 9, ty - 16 + Math.abs(k) * 4); g.stroke(); }
    },
  });
}

export function pumpkinSilhouette() {
  const pts = [[0.5, 0]];
  for (let k = 0; k <= 20; k++) {
    const t = (k / 20) * Math.PI;
    const lobe = 1 + 0.06 * Math.cos(t * 6);
    pts.push([Math.cos(t) * 0.56 * lobe, 0.08 + Math.sin(t) * 0.62 * lobe]);
    if (k === 10) pts.splice(pts.length - 1, 1, [0.08, 0.68], [0.06, 0.9], [-0.05, 0.9], [-0.09, 0.68]);
  }
  pts.push([-0.5, 0]);
  return pts;
}

export function pumpkinArt(points, seed = 97) {
  return paintCard(points, {
    W: 256, H: 256, seed, base: '#de7a32',
    fills: ['rgba(222,122,50,A)', 'rgba(240,150,64,A)', 'rgba(196,96,40,A)'],
    edge: 'rgba(140,60,20,1)',
    details(g, px) {
      for (const x of [-0.32, -0.12, 0.12, 0.32]) { const [a, b] = px(x, 0.36); g.fillStyle = 'rgba(176,80,30,0.55)'; g.beginPath(); g.ellipse(a, b, 9, 70, 0, 0, Math.PI * 2); g.fill(); }
      const [sx, sy] = px(-0.01, 0.82); g.fillStyle = '#5b6a3a'; g.fillRect(sx - 7, sy - 14, 14, 30);
      const [lx, ly] = px(0.16, 0.76);
      asLayer(g, () => { g.fillStyle = '#7d9150'; g.beginPath(); g.ellipse(lx, ly, 18, 9, -0.4, 0, Math.PI * 2); g.fill(); }, 0.6);
      g.strokeStyle = '#5b6a3a'; g.lineWidth = 2.5; g.beginPath(); g.moveTo(sx + 6, sy - 10); g.bezierCurveTo(sx + 30, sy - 30, sx - 20, sy - 36, sx - 24, sy - 12); g.stroke();
    },
  });
}

/** The garden bed: torn-edged sheet of dark soil with printed furrows (laid flat on the page). */
export function soilSilhouette(w, d, seed = 99) {
  const rng = mulberry32(seed), pts = [];
  const edge = (x0, y0, x1, y1, n) => { for (let i = 0; i < n; i++) { const t = i / n; pts.push([x0 + (x1 - x0) * t + (rng() - 0.5) * 0.12, y0 + (y1 - y0) * t + (rng() - 0.5) * 0.12]); } };
  edge(-w / 2, 0, w / 2, 0, 14); edge(w / 2, 0, w / 2, d, 12); edge(w / 2, d, -w / 2, d, 14); edge(-w / 2, d, -w / 2, 0, 12);
  return pts;
}

export function soilArt(points, rows, d, seed = 101) {
  return paintCard(points, {
    W: 512, H: 448, seed, base: '#6e4a30',
    fills: ['rgba(110,74,48,A)', 'rgba(92,60,38,A)', 'rgba(132,92,60,A)'],
    edge: 'rgba(60,38,22,1)',
    details(g, px, rng) {
      for (const z of rows) {
        const [x0, y] = px(-10, z), [x1] = px(10, z);
        asLayer(g, () => { g.fillStyle = '#8a6040'; g.fillRect(x0, y - 14, x1 - x0, 22); }, 0.7);
        g.fillStyle = 'rgba(60,38,22,0.55)'; g.fillRect(x0, y + 9, x1 - x0, 5);
      }
      for (let i = 0; i < 40; i++) { const [a, b] = px((rng() - 0.5) * 10, rng() * d); g.fillStyle = rng() < 0.5 ? 'rgba(150,110,74,0.6)' : 'rgba(70,46,28,0.6)'; g.beginPath(); g.arc(a, b, 2 + rng() * 3, 0, Math.PI * 2); g.fill(); }
    },
  });
}

// ------------------------------------------------------------------ hand-painted warning signs at guarded sites

export function signSilhouette() {
  // a weathered board nailed to a post, one corner knocked off
  return [[0.07, 0], [0.08, 0.84], [0.6, 0.83], [0.63, 1.3], [0.52, 1.44], [-0.58, 1.46], [-0.61, 0.88], [-0.07, 0.86], [-0.06, 0]];
}

export function signArt(points, kind, seed = 91) {
  const [title, line] = kind === 'vein' ? ['IRON VEIN', 'mind the coyotes'] : kind === 'thicket' ? ['BERRY PATCH', 'mind the coyotes'] : ['WILD HONEY', "beware o' the boar"];
  return paintCard(points, {
    W: 512, H: 640, seed, base: '#a8784a',
    fills: ['rgba(168,120,74,A)', 'rgba(146,100,60,A)', 'rgba(188,142,92,A)'],
    edge: 'rgba(80,50,28,1)',
    details(g, px, rng) {
      // wood grain on the post and the board
      g.strokeStyle = 'rgba(110,72,40,0.55)'; g.lineWidth = 2.5;
      for (let k = 0; k < 3; k++) { const [a, b] = px(-0.03 + k * 0.03, 0.05), [, d] = px(0, 0.82); g.beginPath(); g.moveTo(a, b); g.lineTo(a + (rng() - 0.5) * 6, d); g.stroke(); }
      for (let k = 0; k < 6; k++) {
        const y = 0.9 + k * 0.09;
        g.beginPath();
        for (let i = 0; i <= 10; i++) { const [a, b] = px(-0.58 + i * 0.118, y + Math.sin(i * 1.7 + k * 2) * 0.008); i ? g.lineTo(a, b) : g.moveTo(a, b); }
        g.stroke();
      }
      // a cream painted panel, worn at the edges, lettered by hand in barn red and ink
      asLayer(g, () => {
        const [x0, y0] = px(-0.5, 1.38), [x1, y1] = px(0.5, 0.92);
        g.fillStyle = '#efe3c4';
        g.beginPath(); g.moveTo(x0 + 4, y0); g.lineTo(x1 - 2, y0 + 3); g.lineTo(x1, y1 - 2); g.lineTo(x0, y1); g.closePath(); g.fill();
        g.fillStyle = 'rgba(168,120,74,0.55)';
        for (let i = 0; i < 9; i++) { g.beginPath(); g.arc(x0 + rng() * (x1 - x0), rng() < 0.5 ? y0 + rng() * 8 : y1 - rng() * 8, 3 + rng() * 6, 0, Math.PI * 2); g.fill(); }
      });
      const [cx, ty] = px(0, 1.2), [, ly] = px(0, 1.02), [lx0] = px(-0.48, 0), [lx1] = px(0.48, 0);
      g.textAlign = 'center'; g.textBaseline = 'middle';
      asLayer(g, () => {
        g.fillStyle = '#a8352a';
        g.font = "bold 62px Rockwell, 'Courier New', Georgia, serif";
        g.save(); g.translate(cx, ty); g.rotate(-0.02); g.fillText(title, 0, 0, lx1 - lx0); g.restore();
      }, 0.5);
      g.fillStyle = '#3a2a1c';
      g.font = "italic 40px Georgia, 'Times New Roman', serif";
      g.save(); g.translate(cx, ly); g.rotate(0.015); g.fillText(line, 0, 0, lx1 - lx0); g.restore();
      // nails
      g.fillStyle = '#4a4440';
      for (const [nx, ny] of [[-0.03, 1.41], [0.03, 0.89], [-0.53, 1.4], [0.55, 0.9]]) { const [a, b] = px(nx, ny); g.beginPath(); g.arc(a, b, 5, 0, Math.PI * 2); g.fill(); }
    },
  });
}

export function hiveSilhouette() {
  const pts = [[0.42, 0], [0.42, 0.28], [0.36, 0.3]];
  for (let i = 0; i <= 14; i++) { const t = (i / 14) * Math.PI; pts.push([Math.cos(t) * 0.36, 0.3 + Math.sin(t) * 0.5]); }
  pts.push([-0.36, 0.3], [-0.42, 0.28], [-0.42, 0]);
  return pts;
}

export function hiveArt(points, seed = 87) {
  return paintCard(points, {
    W: 256, H: 320, seed, base: '#d9a948',
    fills: ['rgba(217,169,72,A)', 'rgba(196,146,56,A)', 'rgba(236,196,104,A)'],
    edge: 'rgba(120,80,30,1)',
    details(g, px) {
      // stump below, coiled straw rings, a dark entrance
      const [s0x, s0y] = px(-0.42, 0), [s1x, s1y] = px(0.42, 0.28);
      g.fillStyle = '#7b5236'; g.fillRect(s0x, s1y, s1x - s0x, s0y - s1y);
      g.strokeStyle = 'rgba(140,96,34,0.8)'; g.lineWidth = 4;
      for (let k = 1; k <= 5; k++) {
        const y = 0.3 + k * 0.08;
        const w = Math.sqrt(Math.max(0, 1 - ((y - 0.3) / 0.5) ** 2)) * 0.36;
        const [a, b] = px(-w, y), [c] = px(w, y);
        g.beginPath(); g.moveTo(a, b); g.quadraticCurveTo((a + c) / 2, b + 8, c, b); g.stroke();
      }
      const [ex, ey] = px(0, 0.36); g.fillStyle = '#3a2614'; g.beginPath(); g.ellipse(ex, ey, 14, 9, 0, Math.PI, 0); g.fill();
      // a few bees
      g.fillStyle = '#2b2018';
      for (const [bx, by] of [[0.3, 0.75], [-0.25, 0.7], [0.05, 0.86]]) { const [x, y] = px(bx, by); g.beginPath(); g.ellipse(x, y, 5, 3.5, 0.4, 0, Math.PI * 2); g.fill(); }
    },
  });
}

// ------------------------------------------------------------------ field dressing: round hay bales, wheat stooks

/** A round bale standing on its end-face edge: a fat disc with a flat foot. */
export function baleSilhouette() {
  const pts = [[0.42, 0]];
  for (let k = 1; k < 20; k++) {
    const a = -Math.PI / 2 + 0.55 + (k / 20) * (Math.PI * 2 - 1.1);
    pts.push([Math.cos(a) * 0.56, 0.55 + Math.sin(a) * 0.55 + (Math.sin(a * 7) * 0.012)]);
  }
  pts.push([-0.42, 0]);
  return pts.map(([x, y]) => [x, Math.max(0, y)]);
}

export function baleArt(points, seed = 141) {
  return paintCard(points, {
    W: 256, H: 256, seed, base: '#d2b064',
    fills: ['rgba(214,180,100,A)', 'rgba(190,156,80,A)', 'rgba(232,204,130,A)'],
    edge: 'rgba(110,80,36,1)',
    details(g, px, rng) {
      // the rolled spiral, wound outward, with short loose straws along it
      const [cx, cy] = px(0, 0.55), R = px(0.5, 0)[0] - px(0, 0)[0];
      g.strokeStyle = 'rgba(140,104,48,0.75)'; g.lineWidth = 4;
      g.beginPath();
      for (let t = 0; t < 1; t += 0.004) { const a = t * Math.PI * 9, r = t * R; g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); }
      g.stroke();
      g.strokeStyle = 'rgba(246,228,170,0.8)'; g.lineWidth = 2;
      for (let i = 0; i < 70; i++) {
        const a = rng() * Math.PI * 2, r = rng() * R * 0.95;
        const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r, d = a + Math.PI / 2 + (rng() - 0.5) * 0.6;
        g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(d) * 9, y + Math.sin(d) * 9); g.stroke();
      }
      // a twine band round the middle
      g.strokeStyle = 'rgba(181,71,58,0.85)'; g.lineWidth = 5;
      g.beginPath(); g.arc(cx, cy, R * 0.72, 0, Math.PI * 2); g.stroke();
    },
  });
}

/** A wheat stook: a sheaf bundle stood upright, tied at the waist, the heads fanned out on top. */
export function stookSilhouette() {
  return [[0.3, 0], [0.22, 0.32], [0.12, 0.62], [0.16, 0.8], [0.3, 0.9], [0.34, 1.02], [0.24, 1.08], [0.2, 1.2], [0.08, 1.16],
    [0.02, 1.28], [-0.06, 1.17], [-0.18, 1.22], [-0.22, 1.1], [-0.33, 1.03], [-0.3, 0.9], [-0.16, 0.8], [-0.12, 0.62], [-0.22, 0.32], [-0.3, 0]];
}

export function stookArt(points, seed = 143) {
  return paintCard(points, {
    W: 192, H: 384, seed, base: '#b07f3a',
    fills: ['rgba(184,134,62,A)', 'rgba(156,108,46,A)', 'rgba(204,156,80,A)'],
    edge: 'rgba(110,80,36,1)',
    details(g, px, rng) {
      // straight stalks down the bundle, darker in the gaps
      g.strokeStyle = 'rgba(150,114,52,0.7)'; g.lineWidth = 3;
      for (let x = -0.24; x <= 0.24; x += 0.06) { const [a, b] = px(x * 0.5, 0.66), [c, d] = px(x, 0.02); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); }
      // the heads: plump golden ears with whiskers
      for (let i = 0; i < 9; i++) {
        const hx = -0.24 + (i / 8) * 0.48 + (rng() - 0.5) * 0.04, hy = 0.96 + Math.sin((i / 8) * Math.PI) * 0.18;
        const [x, y] = px(hx, hy);
        asLayer(g, () => {
          g.save(); g.translate(x, y); g.rotate((hx) * 1.6);
          g.fillStyle = '#ecd08a'; g.beginPath(); g.ellipse(0, 0, 8, 17, 0, 0, Math.PI * 2); g.fill();
          g.strokeStyle = 'rgba(120,88,40,0.6)'; g.lineWidth = 1.5;
          for (let k = -2; k <= 2; k++) { g.beginPath(); g.moveTo(-6, k * 6); g.lineTo(6, k * 6 - 3); g.stroke(); }
          g.strokeStyle = 'rgba(240,222,160,0.8)'; g.beginPath(); g.moveTo(0, -16); g.lineTo(rng() * 8 - 4, -30); g.stroke();
          g.restore();
        }, 0.6);
      }
      // the tie: a twist of straw round the waist
      const [a, b] = px(-0.15, 0.68), [c, d] = px(0.15, 0.6);
      g.fillStyle = '#9a7436'; g.fillRect(a, d, c - a, b - d);
      g.strokeStyle = 'rgba(240,222,160,0.7)'; g.lineWidth = 2; for (let k = 0; k < 5; k++) { g.beginPath(); g.moveTo(a + k * (c - a) / 5, d); g.lineTo(a + (k + 1) * (c - a) / 5, b); g.stroke(); }
    },
  });
}

// ------------------------------------------------------------------ the bee skep: a coiled-straw bell

/** A skep's bell outline: a flared rim at the foot, swelling sides, a rounded crown with a little knob. */
export function skepSilhouette() {
  const right = [[0.33, 0], [0.34, 0.035], [0.3, 0.06]];
  for (let k = 1; k <= 12; k++) {
    const t = k / 12, y = 0.06 + t * 0.56;
    right.push([0.3 * Math.pow(Math.cos(t * Math.PI / 2), 0.55) + 0.012 * Math.sin(t * 9), y]);
  }
  right.push([0.04, 0.64], [0.03, 0.68]);
  const left = right.slice().reverse().map(([x, y]) => [-x, y]);
  return [...right, [0, 0.69], ...left];
}

export function skepArt(points, seed = 197) {
  return paintCard(points, {
    W: 256, H: 256, seed, base: '#d6b056',
    fills: ['rgba(214,176,86,A)', 'rgba(190,150,66,A)', 'rgba(232,200,110,A)'],
    edge: 'rgba(110,80,30,1)',
    details(g, px, rng) {
      // coiled straw: one rope of straw wound round and round, each coil lit on top and shadowed beneath
      for (let k = 0; k < 10; k++) {
        const y = 0.07 + k * 0.058;
        const [x0, y0] = px(-0.36, y), [x1] = px(0.36, y);
        g.strokeStyle = 'rgba(120,86,30,0.75)'; g.lineWidth = 4;
        g.beginPath(); g.moveTo(x0, y0); g.quadraticCurveTo((x0 + x1) / 2, y0 + 7, x1, y0); g.stroke();
        g.strokeStyle = 'rgba(246,226,160,0.7)'; g.lineWidth = 3;
        g.beginPath(); g.moveTo(x0, y0 - 6); g.quadraticCurveTo((x0 + x1) / 2, y0 + 1, x1, y0 - 6); g.stroke();
        // the bramble binding that stitches each coil to the one below: short dark slanted marks
        g.strokeStyle = 'rgba(96,64,24,0.8)'; g.lineWidth = 2.5;
        for (let s = -0.3 + (k % 2) * 0.05; s < 0.3; s += 0.1) { const [a, b] = px(s, y + 0.01); g.beginPath(); g.moveTo(a - 3, b - 7); g.lineTo(a + 3, b + 3); g.stroke(); }
      }
      // the little arched doorway at the foot, and a bee or two coming home
      const [dx, dy] = px(0, 0.03);
      g.fillStyle = '#2b2018'; g.beginPath(); g.moveTo(dx - 13, dy + 6); g.lineTo(dx - 13, dy - 4); g.arc(dx, dy - 4, 13, Math.PI, 0); g.lineTo(dx + 13, dy + 6); g.fill();
      for (const [bx, by] of [[0.1, 0.12], [-0.15, 0.2]]) {
        const [a, b] = px(bx, by);
        g.fillStyle = '#e8b030'; g.beginPath(); g.ellipse(a, b, 6, 4, 0, 0, Math.PI * 2); g.fill();
        g.fillStyle = '#2b2018'; g.fillRect(a - 1.5, b - 4, 3, 8);
        g.fillStyle = 'rgba(246,240,224,0.85)'; g.beginPath(); g.ellipse(a - 1, b - 6, 4, 3, -0.4, 0, Math.PI * 2); g.fill();
      }
    },
  });
}


// ------------------------------------------------------------------ the wild lands' treasures

/** Wild ginseng ("sang"): a low plant of three five-leaf whorls with a knot of red berries on top. */
export function sangSilhouette() {
  return [[-0.05, 0], [0.05, 0], [0.06, 0.26], [0.3, 0.3], [0.44, 0.42], [0.36, 0.5], [0.16, 0.44], [0.08, 0.5], [0.15, 0.6], [0.14, 0.76], [0.04, 0.82], [-0.06, 0.82], [-0.15, 0.74], [-0.15, 0.6],
    [-0.08, 0.5], [-0.16, 0.44], [-0.36, 0.5], [-0.44, 0.42], [-0.3, 0.3], [-0.06, 0.26]];
}
export function sangArt(points, seed = 171) {
  return paintCard(points, {
    W: 256, H: 224, seed, base: '#7fa24e',
    fills: ['rgba(127,162,78,A)', 'rgba(150,182,92,A)', 'rgba(104,138,64,A)'],
    edge: 'rgba(50,76,34,1)',
    details(g, px, rng) {
      // leaflets: pale-veined ovals fanned out on each whorl
      for (const [cx, cy, sx] of [[0.24, 0.38, 1], [-0.24, 0.38, -1]]) for (let k = 0; k < 5; k++) {
        const [x, y] = px(cx + sx * (k - 2) * 0.05, cy + (k % 2) * 0.04); g.fillStyle = k % 2 ? '#a6c868' : '#8cb058';
        g.beginPath(); g.ellipse(x, y, 14, 7, sx * (0.3 + k * 0.2), 0, Math.PI * 2); g.fill();
        g.strokeStyle = 'rgba(214,226,170,0.6)'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(x - 10, y); g.lineTo(x + 10, y); g.stroke();
      }
      g.strokeStyle = '#4a6a34'; g.lineWidth = 4; { const [a, b] = px(0, 0), [c, d] = px(0, 0.64); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); }
      // the berries: a bright red knot, each with a cream catch-light
      { const [cx, cy] = px(0, 0.69); g.fillStyle = 'rgba(120,20,16,0.35)'; g.beginPath(); g.arc(cx + 2, cy + 3, 19, 0, Math.PI * 2); g.fill(); } // the knot's shadow
      for (let k = 0; k < 12; k++) { const a = k * 2.4, rr = 4 + (k % 4) * 3.5, [cx, cy] = px(0, 0.69), x = cx + Math.cos(a) * rr, y = cy + Math.sin(a) * rr * 0.8; g.fillStyle = k % 3 ? '#e8402c' : '#b82a22'; g.beginPath(); g.arc(x, y, 7.5, 0, Math.PI * 2); g.fill(); g.fillStyle = 'rgba(255,240,224,0.9)'; g.beginPath(); g.arc(x - 2.5, y - 2.5, 2.2, 0, Math.PI * 2); g.fill(); }
    },
  });
}

/** A silver vein: rust-red country rock cut through with bright silver seams and glints. */
export function silverArt(points, seed = 173) {
  return paintCard(points, {
    W: 320, H: 384, seed, base: '#a85a3a',
    fills: ['rgba(168,90,58,A)', 'rgba(140,72,46,A)', 'rgba(190,112,74,A)'],
    edge: 'rgba(80,36,22,1)',
    details(g, px, rng) {
      g.strokeStyle = 'rgba(80,40,26,0.45)'; g.lineWidth = 3;
      for (let k = 0; k < 5; k++) { const [a, b] = px(-0.8, 0.15 + k * 0.2), [c, d] = px(0.8, 0.12 + k * 0.2); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); } // bedding lines
      for (let i = 0; i < 3; i++) { // the seams: a pale grey band with a bright white core
        let [x, y] = px((rng() - 0.5) * 0.8, 0.15 + rng() * 0.4); const pts = [[x, y]];
        for (let k = 0; k < 5; k++) { x += (rng() - 0.3) * 36; y -= 12 + rng() * 20; pts.push([x, y]); }
        for (const [w, c] of [[24, 'rgba(70,40,30,0.45)'], [18, '#9aa6b2'], [11, '#d8e0e8'], [5, '#ffffff']]) { g.strokeStyle = c; g.lineWidth = w; g.lineJoin = 'round'; g.lineCap = 'round'; g.beginPath(); pts.forEach(([a, b], j) => (j ? g.lineTo(a, b) : g.moveTo(a, b))); g.stroke(); }
        for (const [a, b] of pts) { g.fillStyle = '#f4f8fc'; g.beginPath(); g.arc(a + (rng() - 0.5) * 8, b, 6 + rng() * 4, 0, Math.PI * 2); g.fill(); } // nuggets along the seam
      }
      for (let i = 0; i < 9; i++) { const [x, y] = px((rng() - 0.5) * 0.9, 0.1 + rng() * 1.0); g.fillStyle = '#ffffff'; g.beginPath(); g.moveTo(x, y - 12); g.lineTo(x + 3, y - 3); g.lineTo(x + 12, y); g.lineTo(x + 3, y + 3); g.lineTo(x, y + 12); g.lineTo(x - 3, y + 3); g.lineTo(x - 12, y); g.lineTo(x - 3, y - 3); g.closePath(); g.fill(); } // four-point glints
    },
  });
}

/** A thunder egg: a knobbly tan stone split open on a violet crystal heart. */
export function geodeSilhouette() {
  const p = []; for (let i = 0; i <= 18; i++) { const a = Math.PI * (i / 18); const r = 0.42 + 0.04 * Math.sin(i * 2.3); p.push([Math.cos(a) * r, Math.sin(a) * r * 1.05]); }
  return p;
}
export function geodeArt(points, seed = 177) {
  return paintCard(points, {
    W: 288, H: 160, seed, base: '#a89880',
    fills: ['rgba(168,152,128,A)', 'rgba(146,130,108,A)', 'rgba(190,176,152,A)'],
    edge: 'rgba(80,66,50,1)',
    details(g, px, rng) {
      const [cx, cy] = px(0, 0.02), [rx] = px(0.3, 0), R = rx - cx;
      for (const [k, c] of [[1, '#efe6d6'], [0.86, '#b8a0d0'], [0.7, '#8a6ab8'], [0.5, '#5e3e8e']]) { g.fillStyle = c; g.beginPath(); g.ellipse(cx, cy, R * k, R * k * 0.95, 0, Math.PI, 0); g.fill(); }
      for (let i = 0; i < 16; i++) { const a = Math.PI + rng() * Math.PI, r = R * (0.5 + rng() * 0.3), x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r * 0.95; g.fillStyle = 'rgba(246,240,255,0.85)'; g.beginPath(); g.moveTo(x, y - 6); g.lineTo(x + 3, y); g.lineTo(x, y + 4); g.lineTo(x - 3, y); g.fill(); } // crystal points
      for (let i = 0; i < 12; i++) { const [x, y] = px((rng() - 0.5) * 0.8, rng() * 0.4); if (Math.hypot(x - cx, y - cy) < R) continue; g.fillStyle = 'rgba(110,96,76,0.5)'; g.beginPath(); g.arc(x, y, 3 + rng() * 4, 0, Math.PI * 2); g.fill(); } // knobbly rind
    },
  });
}

/** A mussel bed at the water's edge: a low mound of blue-black shells, one gaping on a pearl. */
export function musselSilhouette() {
  return [[-0.5, 0], [0.5, 0], [0.46, 0.1], [0.34, 0.2], [0.18, 0.24], [0.04, 0.3], [-0.12, 0.26], [-0.3, 0.22], [-0.44, 0.12]];
}
export function musselArt(points, seed = 179) {
  return paintCard(points, {
    W: 320, H: 128, seed, base: '#5a6a5a',
    fills: ['rgba(90,106,90,A)', 'rgba(70,86,74,A)', 'rgba(110,124,100,A)'],
    edge: 'rgba(30,40,36,1)',
    details(g, px, rng) {
      for (let i = 0; i < 9; i++) { // shells: dark blue-black ovals with pale growth rings
        const [x, y] = px(-0.38 + i * 0.095, 0.06 + (i % 3) * 0.05); g.save(); g.translate(x, y); g.rotate((rng() - 0.5) * 1.4);
        g.fillStyle = i % 2 ? '#2e3a4a' : '#3a4a5c'; g.beginPath(); g.ellipse(0, 0, 18, 9, 0, 0, Math.PI * 2); g.fill();
        g.strokeStyle = 'rgba(150,170,190,0.5)'; g.lineWidth = 1.5; for (const k of [0.5, 0.8]) { g.beginPath(); g.ellipse(-4, 0, 16 * k, 7 * k, 0, 0, Math.PI * 2); g.stroke(); }
        g.restore();
      }
      // the one gaping open: a nacre lining and a pearl
      const [x, y] = px(0.02, 0.19); g.fillStyle = '#d8e2ea'; g.beginPath(); g.ellipse(x, y, 20, 11, -0.2, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#fbf8f2'; g.beginPath(); g.arc(x + 2, y, 7, 0, Math.PI * 2); g.fill(); g.fillStyle = '#ffffff'; g.beginPath(); g.arc(x, y - 2, 2.5, 0, Math.PI * 2); g.fill();
    },
  });
}

/** An old pine stump weeping amber: jagged bark, golden resin drips and a bead or two. */
export function amberSilhouette() {
  return [[-0.32, 0], [0.32, 0], [0.28, 0.42], [0.2, 0.6], [0.12, 0.5], [0.04, 0.72], [-0.06, 0.54], [-0.16, 0.66], [-0.26, 0.46]];
}
export function amberArt(points, seed = 181) {
  return paintCard(points, {
    W: 256, H: 256, seed, base: '#7b5236',
    fills: ['rgba(123,82,54,A)', 'rgba(100,64,42,A)', 'rgba(146,104,70,A)'],
    edge: 'rgba(56,34,22,1)',
    details(g, px, rng) {
      g.strokeStyle = 'rgba(50,30,18,0.5)'; g.lineWidth = 4; for (let k = 0; k < 6; k++) { const [a, b] = px(-0.25 + k * 0.1, 0), [c, d] = px(-0.24 + k * 0.1 + (rng() - 0.5) * 0.04, 0.5); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); } // bark furrows
      for (let i = 0; i < 5; i++) { // the drips: long golden tears with a bright edge
        const [x, y] = px(-0.22 + i * 0.11 + (rng() - 0.5) * 0.04, 0.52 - rng() * 0.12), len = 30 + rng() * 40;
        g.fillStyle = '#d8902a'; g.beginPath(); g.moveTo(x - 6, y); g.lineTo(x + 6, y); g.lineTo(x + 4, y + len); g.arc(x, y + len, 6, 0, Math.PI); g.lineTo(x - 6, y); g.fill();
        g.fillStyle = 'rgba(255,224,140,0.85)'; g.fillRect(x - 3, y + 4, 2.5, len - 6);
      }
      for (let i = 0; i < 2; i++) { const [x, y] = px(-0.12 + i * 0.22, 0.12); g.fillStyle = '#e8a83a'; g.beginPath(); g.arc(x, y, 10, 0, Math.PI * 2); g.fill(); g.fillStyle = 'rgba(255,240,200,0.9)'; g.beginPath(); g.arc(x - 3, y - 3, 3, 0, Math.PI * 2); g.fill(); }
    },
  });
}
