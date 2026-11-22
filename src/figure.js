// Papercraft folk: folded paper models, the kind scored and bent from printed sheets of patterned paper. Every
// part is a faceted shell of card (the facets catch the light one by one, and every fold carries a pale scored
// line where the fibres were bent): a slender figure about eight heads high with a small head, its face painted
// like a storybook illustration (almond eyes, fine brows, soft lips), the women in corseted bodices with lace
// trim, puffed sleeves and tiered, accordion-pleated skirts over heeled lace-up boots, their hair up in curls
// with a rose or a feather; the men in shirts and vests, long coats and folded hats. They move like people: a
// walk with swinging arms and bending elbows, a little weight shift and breath when they stand, a glance up at
// the sky now and then. All of a figure's prints go into one atlas; each jointed part is one mesh.
import * as THREE from 'three/webgpu';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { texture, uv, attribute, smoothstep, min, vec3 } from 'three/tsl';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

const hex = (c) => '#' + new THREE.Color(c).getHexString();
const tone = (c, k) => { const o = new THREE.Color(c); o.multiplyScalar(k); return '#' + o.getHexString(); };
const rgbA = (c) => { const o = new THREE.Color(c); return `rgba(${Math.round(o.r * 255)},${Math.round(o.g * 255)},${Math.round(o.b * 255)},A)`; };
const PPU = 420; // texels per metre on the printed sheets (the face gets more)

/** Collects printed faces for one figure, packs them into an atlas, and bakes each rigid part into one mesh. */
class Atlas {
  constructor() { this.parts = []; }

  /** A flat die-cut card (brims, crown tops, things held): outline points, its art and where it goes. */
  card(group, pts, { base, draw, back, x = 0, y = 0, z = 0, ry = 0, rx = 0, rz = 0 }) {
    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    for (const [px, py] of pts) { minX = Math.min(minX, px); maxX = Math.max(maxX, px); minY = Math.min(minY, py); maxY = Math.max(maxY, py); }
    const W = Math.max(24, Math.round((maxX - minX) * 1.08 * PPU)), H = Math.max(24, Math.round((maxY - minY) * 1.08 * PPU));
    const tex = paintCard(pts, { W, H, seed: this.parts.length * 7 + 3, base, fills: [rgbA(base), rgbA(tone(base, 0.94)), rgbA(tone(base, 1.05))], edge: `rgba(${rgbA(tone(base, 0.5)).slice(5, -3)},1)`, details: draw });
    const c = tex.image, g = c.getContext('2d');
    g.fillStyle = back ?? tone(base, 0.92); g.fillRect(0, H - 12, 12, 12); // the plain back's swatch, in a corner outside the cut
    tex.dispose?.();
    const w0 = maxX - minX, h0 = maxY - minY, bx = minX - w0 * 0.04 + (6 / W) * w0 * 1.08, by = minY - h0 * 0.04 + (6 / H) * h0 * 1.08;
    const geo = cardGeometry(pts, 0.03, [bx, by]);
    geo.applyMatrix4(new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rx, ry, rz)), new THREE.Vector3(1, 1, 1)));
    this.parts.push({ group, geo, canvas: c });
  }

  /** One printed face of a fold: four corners [bottom-left, bottom-right, top-right, top-left] seen from outside. */
  quad(group, corners, { W, H, base, draw, mirror = false, matrix }) {
    const c = document.createElement('canvas'); c.width = Math.max(8, Math.round(W)); c.height = Math.max(8, Math.round(H));
    const g = c.getContext('2d'); W = c.width; H = c.height;
    g.fillStyle = base; g.fillRect(0, 0, W, H);
    // a little unevenness in the print, so a flat face isn't a flat fill
    let s = this.parts.length * 9301 + 49297; const rnd = () => ((s = (s * 233280 + 49297) % 2147483647) / 2147483647);
    for (let i = 0; i < 6; i++) { g.fillStyle = `rgba(${rnd() < 0.5 ? '255,248,230' : '60,40,24'},0.05)`; g.beginPath(); g.ellipse(rnd() * W, rnd() * H, W * (0.2 + rnd() * 0.3), H * (0.2 + rnd() * 0.3), rnd() * 3, 0, Math.PI * 2); g.fill(); }
    if (draw) { g.save(); if (mirror) { g.translate(W, 0); g.scale(-1, 1); } draw(g, W, H); g.restore(); }
    // the fold: a thin scored line round the face, and a pale lip along the top where the light catches it
    g.strokeStyle = 'rgba(52,32,20,0.55)'; g.lineWidth = 2; g.strokeRect(1, 1, W - 2, H - 2);
    g.fillStyle = 'rgba(255,246,226,0.35)'; g.fillRect(2, 2, W - 4, 2);
    const [bl, br, tr, tl] = corners, pos = [], uvs = [];
    for (const [p, u, v] of [[bl, 0, 0], [br, 1, 0], [tr, 1, 1], [bl, 0, 0], [tr, 1, 1], [tl, 0, 1]]) { pos.push(...p); uvs.push(u, v); }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
    geo.computeVertexNormals();
    if (matrix) geo.applyMatrix4(matrix);
    this.parts.push({ group, geo, canvas: c });
  }

  /**
   * A folded box (a frustum if the top is a different size), its base centred at (x, y, z). faces: front, back,
   * side (printed back-to-front, used on both sides), left/right (to override), top, bottom; each { base, draw }.
   */
  box(group, { w, h, d, wt = w, dt = d, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, ppu = PPU, faces }) {
    const m = new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rx, ry, rz)), new THREE.Vector3(1, 1, 1));
    const W = w / 2, D = d / 2, Wt = wt / 2, Dt = dt / 2;
    const F = (k) => faces[k] ?? (k === 'left' || k === 'right' ? faces.side : null) ?? faces.all;
    const add = (k, corners, pw, ph, mirror = false) => { const f = F(k); if (f) this.quad(group, corners, { W: pw * ppu, H: ph * ppu, base: f.base, draw: f.draw, mirror: mirror && !faces[k], matrix: m }); };
    const mw = Math.max(w, wt), md = Math.max(d, dt);
    add('front', [[-W, 0, D], [W, 0, D], [Wt, h, Dt], [-Wt, h, Dt]], mw, h);
    add('back', [[W, 0, -D], [-W, 0, -D], [-Wt, h, -Dt], [Wt, h, -Dt]], mw, h);
    add('left', [[-W, 0, -D], [-W, 0, D], [-Wt, h, Dt], [-Wt, h, -Dt]], md, h);           // printed back (left) to front (right)
    add('right', [[W, 0, D], [W, 0, -D], [Wt, h, -Dt], [Wt, h, Dt]], md, h, true);         // the same print, mirrored
    add('top', [[-Wt, h, Dt], [Wt, h, Dt], [Wt, h, -Dt], [-Wt, h, -Dt]], wt, dt);
    add('bottom', [[-W, 0, -D], [W, 0, -D], [W, 0, D], [-W, 0, D]], w, d);
  }

  /** An n-sided folded tube (a hat crown, a bedroll) standing on (x, y, z), radius rb at the bottom, rt at the top. */
  prism(group, { n = 8, rb, rt = rb, h, x = 0, y = 0, z = 0, rx = 0, rz = 0, base, draw, top }) {
    const m = new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rx, 0, rz)), new THREE.Vector3(1, 1, 1));
    const side = 2 * Math.max(rb, rt) * Math.sin(Math.PI / n);
    for (let i = 0; i < n; i++) {
      const a0 = ((i + 0.5) / n) * Math.PI * 2, a1 = ((i + 1.5) / n) * Math.PI * 2; // a flat face toward +z
      const P = (a, r, yy) => [Math.sin(a) * r, yy, Math.cos(a) * r];
      this.quad(group, [P(a0, rb, 0), P(a1, rb, 0), P(a1, rt, h), P(a0, rt, h)], { W: side * PPU, H: h * PPU, base: tone(base, i === 0 ? 1 : 0.94 + (i % 2) * 0.05), draw: draw && ((g, W, H) => draw(g, W, H, i)), matrix: m });
    }
    if (top !== null) {
      const cap = []; for (let i = 0; i < n; i++) { const a = ((i + 0.5) / n) * Math.PI * 2; cap.push([Math.sin(a) * rt, -Math.cos(a) * rt]); }
      this.card(group, cap, { base: top ?? tone(base, 0.9), draw: null, // laid flat on the crown
        ...decompose(m, new THREE.Matrix4().compose(new THREE.Vector3(0, h + 0.012, 0), new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI / 2, 0, 0)), new THREE.Vector3(1, 1, 1))) });
    }
  }

  /**
   * A folded paper shell, scored and bent from one printed sheet: n flat facets round each ring (an ellipse rx by
   * rz, pushed dz forward), rings stacked bottom to top. pleat folds every other facet in (an accordion pleat), and
   * hem(angle) lifts or drops the bottom edge (a skirt cut high in front, a drape). The print goes on from the
   * front and from the back (front(g, W, H, X, Y) / back(...), X and Y take metres), so a face, a bodice or a fall
   * of hair lands where it should and wraps round the sides; every facet takes the light on its own, and every
   * fold carries a pale scored line (see bake).
   */
  lathe(group, rings, { n = 8, ppu = PPU, base, front, back, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, caps = true, pleat = 0, hem = null }) {
    const m = new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rx, ry, rz)), new THREE.Vector3(1, 1, 1));
    let R = 0, dzAvg = 0; for (const r of rings) { R = Math.max(R, r[1], r[2] ?? r[1]); dzAvg += (r[3] || 0) / rings.length; }
    const y0 = rings[0][0] - 0.15 * (hem ? 1 : 0), y1 = rings[rings.length - 1][0], Hm = Math.max(0.01, y1 - y0);
    const half = Math.max(12, Math.round(2 * R * ppu)), H = Math.max(12, Math.round(Hm * ppu));
    const c = document.createElement('canvas'); c.width = half * 2; c.height = H; const g = c.getContext('2d');
    g.fillStyle = base; g.fillRect(0, 0, half * 2, H);
    let sd = this.parts.length * 7919 + 104729; const rnd = () => ((sd = (sd * 233280 + 49297) % 2147483647) / 2147483647);
    for (let i = 0; i < 8; i++) { g.fillStyle = `rgba(${rnd() < 0.5 ? '255,248,230' : '60,40,24'},0.045)`; g.beginPath(); g.ellipse(rnd() * half * 2, rnd() * H, half * (0.2 + rnd() * 0.3), H * (0.2 + rnd() * 0.3), rnd() * 3, 0, Math.PI * 2); g.fill(); }
    const X = (xx) => (0.5 + xx / (2 * R)) * half, Y = (yy) => (1 - (yy - y0) / Hm) * H;
    for (const [k, draw] of [[0, front], [1, back ?? front]]) if (draw) { g.save(); g.translate(k * half, 0); g.beginPath(); g.rect(0, 0, half, H); g.clip(); draw(g, half, H, X, Y); g.restore(); }
    const P = (r, i, k) => {
      const a = (i / n) * Math.PI * 2 + Math.PI / n, pl = pleat && k < rings.length - 1 && i % 2 ? 1 - pleat : 1;
      return [Math.sin(a) * r[1] * pl, r[0] + (k === 0 && hem ? hem(a) : 0), Math.cos(a) * (r[2] ?? r[1]) * pl + (r[3] || 0)];
    };
    const pos = [], uvs = [], bar = [];
    const tri = (pts, bs) => {
      const behind = (pts[0][2] + pts[1][2] + pts[2][2]) / 3 - dzAvg < 0;
      pts.forEach((p, j) => { pos.push(...p); bar.push(...bs[j]); uvs.push(behind ? 0.75 - 0.25 * (p[0] / R) : 0.25 + 0.25 * (p[0] / R), (p[1] - y0) / Hm); });
    };
    // a quad's two triangles share a diagonal that is no fold: its edge is kept off the crease lines
    const Q1 = [[1, 1, 1], [0, 2, 1], [0, 1, 2]], Q2 = [[1, 0, 1], [1, 1, 1], [1, 0, 2]]; // (only the lengthwise folds are scored)
    for (let k = 0; k < rings.length - 1; k++) for (let i = 0; i < n; i++) {
      const bl = P(rings[k], i, k), br = P(rings[k], i + 1, k), tr = P(rings[k + 1], i + 1, k + 1), tl = P(rings[k + 1], i, k + 1);
      tri([bl, br, tr], Q1); tri([bl, tr, tl], Q2);
    }
    if (caps) {
      const lo = rings[0], hi = rings[rings.length - 1], L = rings.length - 1, C = [[1, 1, 0], [1, 1, 0], [1, 1, 0]];
      if (lo[1] > 0.012) for (let i = 0; i < n; i++) tri([[0, lo[0], lo[3] || 0], P(lo, i + 1, 0), P(lo, i, 0)], C);
      if (hi[1] > 0.012) for (let i = 0; i < n; i++) tri([[0, hi[0], hi[3] || 0], P(hi, i, L), P(hi, i + 1, L)], C);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
    geo.setAttribute('bary', new THREE.Float32BufferAttribute(bar, 3));
    geo.computeVertexNormals(); geo.applyMatrix4(m);
    this.parts.push({ group, geo, canvas: c });
  }

  /** Pack every face into one texture, remap the uvs (half a texel in, so nothing bleeds), merge per group. */
  bake() {
    const parts = [...this.parts].sort((a, b) => b.canvas.height - a.canvas.height);
    let SIZE = 1024;
    const pack = () => { let x = 0, y = 0, row = 0; for (const p of parts) { const { width: w, height: h } = p.canvas; if (x + w > SIZE) { x = 0; y += row + 3; row = 0; } p.rect = [x, y, w, h]; x += w + 3; row = Math.max(row, h); } return y + row <= SIZE; };
    if (!pack()) { SIZE = 2048; pack(); }
    const atlas = document.createElement('canvas'); atlas.width = atlas.height = SIZE; const g = atlas.getContext('2d');
    for (const p of parts) g.drawImage(p.canvas, p.rect[0], p.rect[1]);
    const tex = new THREE.CanvasTexture(atlas); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4;
    const mat = cardMaterial(tex, { paperScale: 5 * (SIZE / 1024), pulp: 0.22 }); // little figures: a finer, quieter grain
    // a soft fill of their own, so a face turned from the sun stays a face; and the scored folds of the shells: a pale
    // line of card along every crease, where the paper was bent and its fibres catch the light
    const b = attribute('bary', 'vec3'), crease = smoothstep(0.0, 0.03, min(b.x, min(b.y, b.z))).oneMinus();
    mat.emissiveNode = texture(tex, uv()).rgb.mul(0.2).add(vec3(1.0, 0.94, 0.82).mul(crease).mul(0.22));
    for (const p of this.parts) {
      const [ax, ay, w, h] = p.rect, a = p.geo.attributes.uv;
      for (let i = 0; i < a.count; i++) a.setXY(i, (ax + 0.5 + a.getX(i) * (w - 1)) / SIZE, 1 - (ay + 0.5 + (1 - a.getY(i)) * (h - 1)) / SIZE);
    }
    const byGroup = new Map();
    for (const p of this.parts) { if (!byGroup.has(p.group)) byGroup.set(p.group, []); byGroup.get(p.group).push(p.geo); }
    for (const [group, geos] of byGroup) {
      const flat = geos.map((q) => { const g2 = q.index ? q.toNonIndexed() : q; if (!g2.attributes.bary) { const n = g2.attributes.position.count; g2.setAttribute('bary', new THREE.Float32BufferAttribute(new Float32Array(n * 3).fill(1), 3)); } if (!g2.attributes.normal) g2.computeVertexNormals(); return g2; });
      const merged = mergeGeometries(flat, false);
      const mesh = new THREE.Mesh(merged, mat); mesh.castShadow = true; mesh.receiveShadow = true; group.add(mesh);
    }
    return mat;
  }
}

/** card() takes a position and Euler angles: turn a composed matrix back into those. */
function decompose(a, b) {
  const m = new THREE.Matrix4().multiplyMatrices(a, b), p = new THREE.Vector3(), q = new THREE.Quaternion(), s = new THREE.Vector3();
  m.decompose(p, q, s); const e = new THREE.Euler().setFromQuaternion(q);
  return { x: p.x, y: p.y, z: p.z, rx: e.x, ry: e.y, rz: e.z };
}

// ---------------------------------------------------------------- printed cloth

/** Print a cloth pattern over a region already filled with the base colour. */
function cloth(g, pat, x0, y0, x1, y1) {
  g.save(); g.beginPath(); g.rect(x0, y0, x1 - x0, y1 - y0); g.clip();
  const W = x1 - x0, H = y1 - y0;
  if (pat === 7) { // buffalo plaid: dark bands both ways, a pale thread
    g.fillStyle = 'rgba(30,24,36,0.42)'; for (let k = x0; k < x1; k += 26) g.fillRect(k, y0, 13, H); for (let k = y0; k < y1; k += 26) g.fillRect(x0, k, W, 13);
    g.fillStyle = 'rgba(240,226,190,0.5)'; for (let k = x0 + 19; k < x1; k += 26) g.fillRect(k, y0, 2, H); for (let k = y0 + 19; k < y1; k += 26) g.fillRect(x0, k, W, 2);
  } else if (pat === 8) { // denim: fine twill
    g.strokeStyle = 'rgba(255,255,255,0.1)'; g.lineWidth = 2; for (let k = -H; k < W; k += 6) { g.beginPath(); g.moveTo(x0 + k, y1); g.lineTo(x0 + k + H, y0); g.stroke(); }
  } else if (pat === 1) { // ticking stripes
    g.fillStyle = 'rgba(30,26,22,0.32)'; for (let k = x0 + 4; k < x1; k += 14) g.fillRect(k, y0, 4, H);
  } else if (pat === 2) { // calico: little cream sprigs
    g.fillStyle = 'rgba(246,236,214,0.85)'; for (let yy = y0 + 6; yy < y1; yy += 16) for (let xx = x0 + ((yy / 16) % 2) * 8 + 4; xx < x1; xx += 16) { g.beginPath(); g.arc(xx, yy, 2.6, 0, Math.PI * 2); g.fill(); }
  } else if (pat === 3) { // sackcloth / straw weave
    g.strokeStyle = 'rgba(80,60,30,0.22)'; g.lineWidth = 2; for (let k = y0; k < y1; k += 7) { g.beginPath(); g.moveTo(x0, k); g.lineTo(x1, k); g.stroke(); } for (let k = x0; k < x1; k += 9) { g.beginPath(); g.moveTo(k, y0); g.lineTo(k, y1); g.stroke(); }
  }
  g.restore();
}
/** A whole face printed in a cloth (base already filled). */
const clothFace = (pat, extra) => (g, W, H) => { cloth(g, pat || 0, 0, 0, W, H); extra?.(g, W, H); };
/** Draw a polygon given in 0..1 face coordinates (x right, y up). */
function poly(g, W, H, pts, fill) { g.fillStyle = fill; g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(x * W, (1 - y) * H) : g.moveTo(x * W, (1 - y) * H))); g.closePath(); g.fill(); }


// ---------------------------------------------------------------- printing helpers for the puppet cards

/** A path through points given in card metres (px maps metres to pixels), filled and optionally stroked. */
function shapeP(g, px, pts, fill, stroke) { g.beginPath(); pts.forEach(([x, y], i) => { const [a, b] = px(x, y); i ? g.lineTo(a, b) : g.moveTo(a, b); }); g.closePath(); if (fill) { g.fillStyle = fill; g.fill(); } if (stroke) { g.strokeStyle = stroke; g.lineWidth = 2; g.stroke(); } }
/** Cloth over the card's bounding box (in metres). */
function clothP(g, px, pat, x0, y0, x1, y1) { const [a, b] = px(x0, y1), [c, d] = px(x1, y0); cloth(g, pat || 0, Math.min(a, c), Math.min(b, d), Math.max(a, c), Math.max(b, d)); }
/** A brass paper fastener: a domed brass head with a bright highlight and a little shadow, at (x, y). */
function brad(g, px, x, y, r = 0.022) {
  const [a, b] = px(x, y), [c] = px(x + r, y), R = Math.abs(c - a);
  g.fillStyle = 'rgba(40,24,10,0.35)'; g.beginPath(); g.arc(a + R * 0.25, b + R * 0.3, R, 0, 7); g.fill();
  const gr = g.createRadialGradient(a - R * 0.35, b - R * 0.35, R * 0.1, a, b, R); gr.addColorStop(0, '#fff2b0'); gr.addColorStop(0.45, '#d8a83a'); gr.addColorStop(1, '#8a5a1a');
  g.fillStyle = gr; g.beginPath(); g.arc(a, b, R, 0, 7); g.fill();
  g.strokeStyle = 'rgba(90,56,16,0.8)'; g.lineWidth = 1.5; g.stroke();
}
/** Soft painted shading along one side of a part (the print's own modelling: light from the upper left). */
function shade(g, px, x0, y0, x1, y1, k = 0.16) {
  const [a, b] = px(x0, y1), [c, d] = px(x1, y0); const gr = g.createLinearGradient(a, 0, c, 0);
  gr.addColorStop(0, `rgba(255,246,226,${k * 0.8})`); gr.addColorStop(0.45, 'rgba(255,246,226,0)'); gr.addColorStop(0.7, 'rgba(60,36,20,0)'); gr.addColorStop(1, `rgba(60,36,20,${k})`);
  g.fillStyle = gr; g.fillRect(Math.min(a, c), Math.min(b, d), Math.abs(c - a), Math.abs(d - b));
}
/** Hair strands: soft darker and lighter combed lines over a hair area. */
function strandsP(g, px, x0, x1, ya, yb, n = 14) {
  for (let i = 0; i < n; i++) { const t = (i + 0.5) / n, x = x0 + (x1 - x0) * t, [a, b] = px(x, ya), [c, d] = px(x + (t - 0.5) * 0.04, (ya + yb) / 2), [e, f] = px(x + (t - 0.5) * 0.06, yb); g.strokeStyle = i % 3 === 1 ? 'rgba(255,240,210,0.22)' : 'rgba(0,0,0,0.18)'; g.lineWidth = 1.6; g.beginPath(); g.moveTo(a, b); g.quadraticCurveTo(c, d, e, f); g.stroke(); }
}

/**
 * The face card: a soft oval with ears, painted like a storybook illustration. Big kind eyes (whites, a coloured
 * iris with a ring, a pupil and two catch-lights, a lid line), brows, a little curved nose with a warm tip, a
 * smile, rosy cheeks and freckles; the hair's fringe and sideburns laid over the brow. Men get a squarer jaw,
 * heavier brows and narrower eyes; the glamorous coloured lids, lashes and painted lips.
 */
function facePts(MAN) {
  const p = [];
  for (let i = 0; i <= 24; i++) { const a = Math.PI * (i / 24); const x = Math.cos(a) * (MAN ? 0.19 : 0.18), y = 0.27 + Math.sin(a) * 0.24; p.push([x, y]); } // the crown, right to left
  const jaw = MAN ? [[-0.19, 0.2], [-0.185, 0.12], [-0.15, 0.04], [-0.08, -0.005], [0, -0.012], [0.08, -0.005], [0.15, 0.04], [0.185, 0.12], [0.19, 0.2]]
    : [[-0.18, 0.2], [-0.165, 0.13], [-0.125, 0.06], [-0.07, 0.012], [-0.03, -0.006], [0, -0.01], [0.03, -0.006], [0.07, 0.012], [0.125, 0.06], [0.165, 0.13], [0.18, 0.2]];
  const E = MAN ? 0.19 : 0.18; const ear = (sx) => (sx < 0 ? [[-E, 0.27], [-E - 0.022, 0.29], [-E - 0.032, 0.25], [-E - 0.022, 0.19], [-E, 0.17]] : [[E, 0.17], [E + 0.022, 0.19], [E + 0.032, 0.25], [E + 0.022, 0.29], [E, 0.27]]);
  return [...p, ...ear(-1), ...jaw, ...ear(1)];
}
function faceArt(S, MAN, shut) {
  const hairC = S.hair != null ? hex(S.hair) : S.beard != null ? hex(S.beard) : '#5a3e2a';
  return (g, px) => {
    const P = (x, y) => px(x, y), r = (m) => Math.abs(px(m, 0)[0] - px(0, 0)[0]);
    // modelling: a warm glow on the cheeks and nose, a cool shade at the temples and under the jaw
    { const [a, b] = P(0, 0.2); const gr = g.createRadialGradient(a, b, r(0.02), a, b, r(0.22)); gr.addColorStop(0, 'rgba(240,160,120,0.18)'); gr.addColorStop(1, 'rgba(240,160,120,0)'); g.fillStyle = gr; g.fillRect(0, 0, g.canvas.width, g.canvas.height); }
    { const [a, b] = P(0, -0.02); g.fillStyle = 'rgba(110,64,44,0.14)'; g.beginPath(); g.ellipse(a, b, r(0.15), r(0.05), 0, 0, 7); g.fill(); }
    // inner ears
    for (const sx of [-1, 1]) { const [a, b] = P(sx * 0.205, 0.23); g.fillStyle = 'rgba(180,96,74,0.45)'; g.beginPath(); g.ellipse(a, b, r(0.008), r(0.03), 0, 0, 7); g.fill(); }
    // eyes
    for (const sx of [-1, 1]) {
      const [ex, ey] = P(sx * 0.078, 0.25), ew = r(MAN ? 0.038 : 0.047), eh = r(MAN ? 0.019 : 0.028);
      if (S.glam) { g.fillStyle = S.lids != null ? hex(S.lids) : 'rgba(160,110,170,0.6)'; g.globalAlpha = 0.5; g.beginPath(); g.ellipse(ex, ey - eh * 0.8, ew * 1.2, eh * 1.25, 0, Math.PI, 0); g.fill(); g.globalAlpha = 1; }
      if (shut) { g.strokeStyle = '#3a2418'; g.lineWidth = r(0.007); g.lineCap = 'round'; g.beginPath(); g.moveTo(ex - ew, ey); g.quadraticCurveTo(ex, ey + eh, ex + ew, ey); g.stroke(); }
      else {
        g.save(); g.beginPath(); g.moveTo(ex - sx * ew, ey + eh * 0.15); g.quadraticCurveTo(ex - sx * ew * 0.2, ey - eh * 1.7, ex + sx * ew, ey - eh * 0.25); g.quadraticCurveTo(ex + sx * ew * 0.1, ey + eh * 1.3, ex - sx * ew, ey + eh * 0.15); g.closePath(); g.fillStyle = '#fbf6ec'; g.fill(); g.clip();
        const ir = r(MAN ? 0.017 : 0.023), ix = ex + sx * r(0.002);
        g.fillStyle = S.eyes || (S.glam ? '#3e6a8a' : MAN ? '#4a5a6a' : '#5a7a4a'); g.beginPath(); g.arc(ix, ey, ir, 0, 7); g.fill();
        g.strokeStyle = 'rgba(20,12,8,0.6)'; g.lineWidth = r(0.003); g.stroke();
        g.fillStyle = '#140c08'; g.beginPath(); g.arc(ix, ey, ir * 0.5, 0, 7); g.fill();
        g.fillStyle = '#fff'; g.beginPath(); g.arc(ix - ir * 0.35, ey - ir * 0.4, ir * 0.28, 0, 7); g.fill(); g.beginPath(); g.arc(ix + ir * 0.35, ey + ir * 0.3, ir * 0.12, 0, 7); g.fill();
        g.fillStyle = 'rgba(120,70,50,0.22)'; g.fillRect(ex - ew * 1.2, ey - eh * 2, ew * 2.4, eh * 0.9); // the lid's shadow over the iris
        g.restore();
        g.strokeStyle = '#2a1810'; g.lineWidth = r(MAN ? 0.008 : 0.011); g.lineCap = 'round'; g.beginPath(); g.moveTo(ex - sx * ew * 1.02, ey + eh * 0.1); g.quadraticCurveTo(ex - sx * ew * 0.2, ey - eh * 1.75, ex + sx * ew * 1.08, ey - eh * 0.35); g.stroke(); // the upper lid line
        if (!MAN) { g.lineWidth = r(0.006); for (let k = 0; k < 4; k++) { const t = 0.55 + k * 0.2, bx = ex + sx * ew * (t * 1.1 - 0.2), by = ey - eh * (1.45 - t * 1.1); g.beginPath(); g.moveTo(bx, by); g.lineTo(bx + sx * r(0.011), by - r(0.009)); g.stroke(); } } // lashes at the outer corner
        g.strokeStyle = 'rgba(150,90,70,0.35)'; g.lineWidth = r(0.004); g.beginPath(); g.moveTo(ex - sx * ew * 0.6, ey + eh * 0.9); g.quadraticCurveTo(ex, ey + eh * 1.3, ex + sx * ew * 0.8, ey + eh * 0.5); g.stroke(); // the lower lid
      }
      if (S.glam) { g.strokeStyle = '#1e130b'; g.lineWidth = r(0.004); for (let k = 0; k < 4; k++) { const a = Math.PI * (1.15 + k * 0.12) + (sx > 0 ? Math.PI * 0.25 : -Math.PI * 0.03), bx = ex + Math.cos(a) * ew, by = ey + Math.sin(a) * eh; g.beginPath(); g.moveTo(bx, by); g.lineTo(bx + sx * r(0.01), by - r(0.014)); g.stroke(); } }
      // brow
      const [bx, by] = P(sx * 0.078, MAN ? 0.3 : 0.31);
      g.strokeStyle = MAN ? hairC : tone(S.hair ?? 0x5a3e2a, 0.8); g.lineWidth = r(MAN ? 0.013 : 0.0055); g.lineCap = 'round'; g.beginPath();
      g.moveTo(bx - sx * r(0.038), by + r(MAN ? 0.002 : 0.004)); g.quadraticCurveTo(bx + sx * r(0.01), by - r(MAN ? (S.stern ? 0.0 : 0.006) : 0.02), bx + sx * r(0.046), by + r(MAN ? 0.0 : 0.006)); g.stroke();
    }
    // nose: a little curved line and a warm tip
    { const [a, b] = P(0.012, 0.22), [c, d] = P(0.02, 0.165), [e, f] = P(-0.012, 0.15); g.strokeStyle = 'rgba(150,84,60,0.55)'; g.lineWidth = r(0.005); g.lineCap = 'round'; g.beginPath(); g.moveTo(a, b); g.quadraticCurveTo(c, d, e, f); g.stroke();
      const [n0, n1] = P(0, 0.16); g.fillStyle = 'rgba(230,130,110,0.4)'; g.beginPath(); g.ellipse(n0, n1, r(MAN ? 0.028 : 0.02), r(0.016), 0, 0, 7); g.fill(); }
    // cheeks and freckles
    if (!MAN) for (const sx of [-1, 1]) { const [a, b] = P(sx * 0.11, 0.165); g.fillStyle = 'rgba(232,120,110,0.26)'; g.beginPath(); g.ellipse(a, b, r(0.035), r(0.022), 0, 0, 7); g.fill(); if (!S.glam && S.freckles) { g.fillStyle = 'rgba(150,80,50,0.4)'; for (let k = 0; k < 4; k++) { g.beginPath(); g.arc(a + r(-0.02 + k * 0.013), b - r(0.012) + (k % 2) * r(0.008), r(0.0035), 0, 7); g.fill(); } } }
    // mouth
    for (const sx of [-1, 1]) { const [a, b] = P(sx * 0.14, 0.13); g.fillStyle = 'rgba(150,90,70,0.12)'; g.beginPath(); g.ellipse(a, b, r(0.03), r(0.06), sx * 0.3, 0, 7); g.fill(); } // contour under the cheekbones
    if (!MAN) {
      const lc = S.lips != null ? hex(S.lips) : '#c8706a', [mx, my] = P(0, 0.09), w = r(S.glam ? 0.036 : 0.032), h = r(S.glam ? 0.013 : 0.011);
      g.fillStyle = lc; g.beginPath(); g.moveTo(mx - w, my); g.quadraticCurveTo(mx - w * 0.5, my - h * 1.7, mx, my - h * 0.7); g.quadraticCurveTo(mx + w * 0.5, my - h * 1.7, mx + w, my); g.quadraticCurveTo(mx, my + h * 2.3, mx - w, my); g.fill();
      g.fillStyle = 'rgba(255,255,255,0.4)'; g.beginPath(); g.ellipse(mx + w * 0.2, my + h * 0.9, w * 0.25, h * 0.35, 0, 0, 7); g.fill();
      if (S.mole) { const [a, b] = P(0.062, 0.11); g.fillStyle = '#2a1810'; g.beginPath(); g.arc(a, b, r(0.006), 0, 7); g.fill(); }
    } else if (!S.beard) { { const [a, b] = P(0, 0.07); g.fillStyle = 'rgba(70,56,50,0.13)'; g.beginPath(); g.ellipse(a, b, r(0.13), r(0.085), 0, 0, Math.PI); g.fill(); g.beginPath(); g.ellipse(a, b, r(0.15), r(0.04), 0, Math.PI, 0); g.fill(); } /* a stubble shadow along the jaw */ const [a, b] = P(-0.034, 0.093), [c, d] = P(0, S.stern ? 0.09 : 0.083), [e, f] = P(0.034, 0.093); g.strokeStyle = '#7a3a2a'; g.lineWidth = r(0.005); g.lineCap = 'round'; g.beginPath(); g.moveTo(a, b); g.quadraticCurveTo(c, d, e, f); g.stroke(); const [l0, l1] = P(0, 0.074); g.fillStyle = 'rgba(170,90,74,0.35)'; g.beginPath(); g.ellipse(l0, l1, r(0.02), r(0.007), 0, 0, 7); g.fill(); const [j0, j1] = P(0, 0.035); g.fillStyle = 'rgba(120,80,60,0.12)'; g.beginPath(); g.ellipse(j0, j1, r(0.03), r(0.012), 0, 0, 7); g.fill(); } // a defined mouth and the cleft of the chin
    // the hair laid over the brow: a fringe for the women, a side-parted sweep for the men
    if (S.hat !== 'bonnet' && !(S.hair == null && S.beard != null)) {
      g.fillStyle = hairC;
      const fr = MAN ? [[-0.2, 0.22], [-0.185, 0.33], [-0.15, 0.39], [-0.08, 0.405], [0.0, 0.41], [0.07, 0.42], [0.13, 0.4], [0.175, 0.36], [0.195, 0.3], [0.2, 0.22], [0.21, 0.56], [-0.21, 0.56]]
        : [[-0.205, 0.12], [-0.2, 0.32], [-0.15, 0.4], [-0.06, 0.405], [-0.02, 0.43], [0.04, 0.4], [0.13, 0.39], [0.19, 0.33], [0.205, 0.12], [0.21, 0.52], [-0.21, 0.52]];
      shapeP(g, px, fr, hairC); strandsP(g, px, -0.18, 0.18, 0.5, MAN ? 0.42 : 0.38, 16);
    }
  };
}


// ---------------------------------------------------------------- prints for the folded shells (X, Y: metres)

/** Damask: a printed flourish of curls and leaves in a darker tone, the patterned paper of a good dress. */
function damask(g, W, H, col, k = 0.18) {
  g.strokeStyle = `rgba(${rgbA(col).slice(5, -3)},${k})`; g.lineWidth = Math.max(1.2, W / 90);
  const s = Math.max(16, W / 6);
  for (let y = s * 0.5; y < H + s; y += s) for (let x = ((y / s) % 2) * s * 0.5; x < W + s; x += s) {
    g.beginPath(); g.arc(x, y, s * 0.18, 0.3, 4.4); g.stroke(); g.beginPath(); g.arc(x + s * 0.2, y - s * 0.1, s * 0.1, 3, 7.5); g.stroke();
    g.beginPath(); g.ellipse(x - s * 0.18, y + s * 0.12, s * 0.09, s * 0.04, 0.6, 0, 7); g.stroke();
  }
}
/** Lace: a scalloped edge with little holes, along y = yy across the sheet. */
function lace(g, W, X, Y, yy, x0, x1, down = true, col = '#f3e9d6') {
  const a = X(x0), b = X(x1), y = Y(yy), r = Math.max(3, (b - a) / 24);
  g.fillStyle = col; g.fillRect(Math.min(a, b), y - r * (down ? 0.2 : 1.6), Math.abs(b - a), r * 1.8);
  for (let x = Math.min(a, b); x < Math.max(a, b); x += r * 2) { g.beginPath(); g.arc(x + r, y + (down ? r * 1.4 : -r * 1.4), r, down ? 0 : Math.PI, down ? Math.PI : 0); g.fill(); }
  g.fillStyle = 'rgba(90,60,40,0.35)'; for (let x = Math.min(a, b) + r; x < Math.max(a, b); x += r * 2) { g.beginPath(); g.arc(x, y + r * 0.5 * (down ? 1 : -1), r * 0.3, 0, 7); g.fill(); }
}
const rectXY = (g, X, Y, x0, y0, x1, y1, fill) => { g.fillStyle = fill; g.fillRect(Math.min(X(x0), X(x1)), Math.min(Y(y0), Y(y1)), Math.abs(X(x1) - X(x0)), Math.abs(Y(y1) - Y(y0))); };
const polyXY = (g, X, Y, pts, fill, stroke) => { g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(X(x), Y(y)) : g.moveTo(X(x), Y(y)))); g.closePath(); if (fill) { g.fillStyle = fill; g.fill(); } if (stroke) { g.strokeStyle = stroke; g.lineWidth = 1.5; g.stroke(); } };

// ---------------------------------------------------------------- the figure

/**
 * spec: skin, coat, coatPat, sleeve, pants, pantsPat, boots, barefoot, dress, dressPat, apron, longcoat, vest,
 *       overalls, pack, sack, beard, hair, bun, long, cheeks, eyes, stern, glam, lips, lids, mole, flower, feather,
 *       burly, rolled, neckline, corset, short, stockings, garter, hat ('stovepipe' | 'pot' | 'sunday' | 'straw' |
 *       'cap' | 'bonnet' | 'none'), hatColor, band, collar, hold, scale
 */
export class Figure {
  constructor(spec = {}) {
    const S = (this.spec = { skin: 0xf2dcc4, coat: 0x6b4a30, pants: 0x4a4038, boots: 0x3a2a20, hat: 'none', ...spec });
    this.root = new THREE.Group();
    this.turn = new THREE.Group(); this.root.add(this.turn);
    this.body = new THREE.Group(); this.turn.add(this.body);
    if (S.scale) this.root.scale.setScalar(S.scale);
    const A = new Atlas();
    const skin = hex(S.skin), coat = hex(S.coat), sleeve = hex(S.sleeve ?? S.coat), pants = hex(S.pants);
    const hairCol = S.hair != null ? hex(S.hair) : S.beard != null ? hex(S.beard) : '#5a3e2a';
    const MAN = !(S.dress || S.long || S.bun || S.glam || S.curvy), BURLY = !!S.burly, DRESS = !!S.dress;
    const bootCol = S.barefoot ? skin : hex(S.boots);
    // proportions: about eight heads high, long in the leg
    const HIP = MAN ? 0.94 : 0.97, SH = MAN ? 1.55 : 1.5, NECK = SH + 0.015, HH = MAN ? 0.26 : 0.255;
    const K = BURLY ? 1.3 : 1; // the burly men are built broader
    const SR = (MAN ? 0.2 : 0.15) * K; // shoulder half-width

    // ---------------- legs: trouser or stocking shells (ankle, calf, knee, thigh), and the boots
    const LK = (MAN ? 1.12 : 0.92) * (BURLY ? 1.2 : 1);
    this.legs = [-1, 1].map((s) => {
      const hip = new THREE.Group(); hip.position.set((MAN ? 0.085 : 0.075) * K * s, HIP, 0); this.body.add(hip);
      const legCol = S.stockings != null ? hex(S.stockings) : DRESS ? skin : pants;
      const legArt = (g, W, H, X, Y) => {
        if (S.stockings != null) { g.strokeStyle = 'rgba(0,0,0,0.3)'; g.lineWidth = 1; for (let k = -H; k < W + H; k += 6) { g.beginPath(); g.moveTo(k, 0); g.lineTo(k + H, H); g.moveTo(k + H, 0); g.lineTo(k, H); g.stroke(); } rectXY(g, X, Y, -1, -0.32, 1, -0.29, S.garter != null ? hex(S.garter) : '#c4302c'); }
        else if (!DRESS) { cloth(g, S.pantsPat || 0, 0, 0, W, H); g.strokeStyle = 'rgba(0,0,0,0.16)'; g.lineWidth = 2; g.beginPath(); g.moveTo(W / 2, 0); g.lineTo(W / 2, H); g.stroke(); }
      };
      A.lathe(hip, [[-HIP + 0.12, 0.028 * LK, 0.03 * LK], [-HIP * 0.66, 0.042 * LK, 0.046 * LK, 0.004], [-HIP * 0.5, 0.038 * LK, 0.04 * LK], [-HIP * 0.26, 0.056 * LK, 0.06 * LK], [0.04, 0.07 * LK, 0.072 * LK], [0.07, 0.04, 0.04]], { n: 6, base: legCol, front: legArt, back: legArt });
      // the boot: a laced shaft (tall and heeled for the women), a shaped foot, a sole
      const bt = MAN ? 0.15 : 0.24, bootArt = (back) => (g, W, H, X, Y) => {
        g.fillStyle = 'rgba(0,0,0,0.12)'; g.fillRect(0, 0, W, H);
        if (!back && !S.barefoot) { g.strokeStyle = '#e2cfa4'; g.lineWidth = 1.5; for (let y = 0.02; y < bt - 0.02; y += 0.025) { g.beginPath(); g.moveTo(X(-0.016), Y(-HIP + 0.02 + y)); g.lineTo(X(0.016), Y(-HIP + 0.035 + y)); g.moveTo(X(0.016), Y(-HIP + 0.02 + y)); g.lineTo(X(-0.016), Y(-HIP + 0.035 + y)); g.stroke(); } }
        if (!MAN) lace(g, W, X, Y, -HIP + bt + 0.01, -0.06, 0.06, false, '#efe2c8');
      };
      A.lathe(hip, [[-HIP + 0.02, 0.036 * LK, 0.04 * LK], [-HIP + bt * 0.5, 0.032 * LK, 0.036 * LK], [-HIP + bt, 0.037 * LK, 0.04 * LK]], { n: 6, base: bootCol, front: bootArt(false), back: bootArt(true), caps: false });
      A.box(hip, { w: 0.075 * LK, wt: 0.06 * LK, h: 0.055, d: 0.17, dt: 0.12, y: -HIP + (MAN ? 0.0 : 0.03), z: 0.045, rx: MAN ? 0 : 0.18, faces: { all: { base: bootCol, draw: (g, W, H) => { g.fillStyle = 'rgba(0,0,0,0.25)'; g.fillRect(0, H * 0.8, W, H * 0.2); } }, top: { base: tone(S.boots ?? 0x3a2a20, 1.1) } } });
      if (!MAN) A.box(hip, { w: 0.035, h: 0.045, d: 0.04, y: -HIP, z: -0.03, faces: { all: { base: tone(S.boots ?? 0x3a2a20, 0.7) } } }); // the heel
      hip.knee = new THREE.Group(); hip.add(hip.knee);
      return hip;
    });

    // ---------------- skirts: tiered, accordion-pleated bells of patterned paper with lace at the hems
    const WY = HIP + 0.17, dressCol = DRESS ? hex(S.dress) : coat;
    const skirtArt = (apron, laceAt) => (g, W, H, X, Y) => {
      cloth(g, S.dressPat || 0, 0, 0, W, H); damask(g, W, H, tone(S.dress ?? 0x6b4a30, 0.6), 0.16);
      if (apron && S.apron) { polyXY(g, X, Y, [[-0.1, WY], [0.1, WY], [0.15, laceAt + 0.06], [-0.15, laceAt + 0.06]], hex(S.apron), 'rgba(120,96,70,0.5)'); g.setLineDash([3, 3]); g.strokeStyle = 'rgba(120,96,70,0.6)'; g.stroke(); g.setLineDash([]); }
      lace(g, W, X, Y, laceAt, -1, 1, true);
    };
    if (DRESS) {
      if (S.short) { // three short ruffled tiers to the knee, cut a little high in front, a lace petticoat under
        A.lathe(this.body, [[0.46, 0.2, 0.18, -0.01], [WY, 0.11, 0.085]], { n: 16, pleat: 0.1, base: '#f3e9d6', front: (g, W, H, X, Y) => lace(g, W, X, Y, 0.47, -1, 1), caps: false });
        for (const [lo, r, k] of [[0.52, 0.23, 0], [0.62, 0.2, 1], [0.72, 0.17, 2]]) A.lathe(this.body, [[lo, r, r * 0.88, -0.01], [WY + 0.01 - k * 0.0, 0.112 + k * 0.002, 0.087]], { n: 16, pleat: 0.14, base: dressCol, front: skirtArt(k === 0, lo + 0.015), back: skirtArt(false, lo + 0.015), caps: false, hem: (a) => 0.05 * Math.max(0, Math.cos(a)) });
      } else { // a long underskirt to the boots, and a draped overskirt gathered up behind
        A.lathe(this.body, [[0.04, 0.25, 0.24, -0.03], [0.5, 0.17, 0.15, -0.015], [WY, 0.11, 0.085]], { n: 16, pleat: 0.12, base: dressCol, front: skirtArt(true, 0.06), back: skirtArt(false, 0.06), caps: false });
        A.lathe(this.body, [[0.4, 0.2, 0.2, -0.04], [0.75, 0.15, 0.14, -0.02], [WY + 0.01, 0.113, 0.088]], { n: 16, pleat: 0.08, base: tone(S.dress ?? 0x6b4a30, 0.9), front: skirtArt(false, 0.42), back: skirtArt(false, 0.42), caps: false, hem: (a) => 0.12 * Math.max(0, Math.cos(a)) - 0.08 * Math.max(0, -Math.cos(a)) });
      }
    }
    if (S.longcoat) A.lathe(this.body, [[0.5, 0.16 * K, 0.13 * K, -0.01], [HIP + 0.05, 0.15 * K, 0.105 * K]], { n: 10, pleat: 0.05, base: coat, front: (g, W, H, X, Y) => { cloth(g, S.coatPat || 0, 0, 0, W, H); g.fillStyle = 'rgba(30,20,14,0.5)'; g.fillRect(X(0) - 1, 0, 2, H); }, back: (g, W, H, X, Y) => { cloth(g, S.coatPat || 0, 0, 0, W, H); g.fillStyle = 'rgba(30,20,14,0.4)'; g.fillRect(X(0) - 1, Y(0.75), 2, H); }, caps: false });

    // ---------------- the torso: hips, waist, chest and shoulders, the costume printed on
    const T = MAN ? [[HIP - 0.05, 0.15 * K, 0.1 * K], [HIP + 0.12, 0.142 * K, 0.095 * K], [HIP + 0.3, 0.158 * K, 0.104 * K, 0.004], [HIP + 0.45, 0.19 * K, 0.115 * K, 0.008], [SH - 0.04, SR, 0.105 * K], [SH + 0.01, 0.12 * K, 0.08 * K], [SH + 0.03, 0.05, 0.045]]
      : [[HIP - 0.04, 0.16, 0.105], [HIP + 0.08, 0.14, 0.095], [WY, 0.1, 0.075], [HIP + 0.3, 0.125, 0.093, 0.014], [HIP + 0.38, 0.135, 0.098, 0.022], [SH - 0.05, SR, 0.08], [SH, 0.085, 0.058], [SH + 0.025, 0.035, 0.032]];
    const torsoArt = (back) => (g, W, H, X, Y) => {
      cloth(g, (DRESS ? S.dressPat : S.coatPat) || 0, 0, 0, W, H);
      if (DRESS) damask(g, W, H, tone(S.dress ?? 0x6b4a30, 0.6), 0.14);
      if (!DRESS && !S.longcoat) { rectXY(g, X, Y, -1, HIP - 0.06, 1, HIP + 0.07, pants); cloth(g, S.pantsPat || 0, 0, Y(HIP + 0.07), W, H); }
      if (!DRESS) { rectXY(g, X, Y, -1, HIP + 0.05, 1, HIP + 0.085, '#3a2a20'); if (!back) rectXY(g, X, Y, -0.015, HIP + 0.048, 0.015, HIP + 0.088, '#d8b24a'); } // the belt and its buckle
      if (S.overalls) {
        if (!back) { polyXY(g, X, Y, [[-0.09, HIP + 0.06], [0.09, HIP + 0.06], [0.09, HIP + 0.36], [-0.09, HIP + 0.36]], pants); g.strokeStyle = 'rgba(232,196,110,0.85)'; g.setLineDash([3, 3]); g.lineWidth = 1.5; g.strokeRect(X(-0.08), Y(HIP + 0.35), X(0.08) - X(-0.08), Y(HIP + 0.08) - Y(HIP + 0.35)); g.setLineDash([]); }
        for (const sx of [-1, 1]) polyXY(g, X, Y, [[sx * 0.06, HIP + 0.3], [sx * 0.095, HIP + 0.3], [sx * 0.13, SH], [sx * 0.095, SH]], pants);
      }
      if (S.vest && !back) for (const sx of [-1, 1]) polyXY(g, X, Y, [[sx * 0.01, HIP + 0.06], [sx * 0.25, HIP + 0.06], [sx * 0.25, SH], [sx * 0.08, SH], [sx * 0.02, HIP + 0.32]], hex(S.vest));
      if (S.vest && back) rectXY(g, X, Y, -1, HIP + 0.06, 1, SH, hex(S.vest));
      if (S.vest && !back) { g.fillStyle = '#d8b24a'; for (const yy of [0.12, 0.18, 0.24]) { g.beginPath(); g.arc(X(0.025), Y(HIP + yy), 2.5, 0, 7); g.fill(); } g.strokeStyle = '#d8b24a'; g.lineWidth = 1.2; g.beginPath(); g.moveTo(X(0.03), Y(HIP + 0.16)); g.quadraticCurveTo(X(0.08), Y(HIP + 0.11), X(0.12), Y(HIP + 0.17)); g.stroke(); } // buttons, a watch chain
      if (S.longcoat && !back) { polyXY(g, X, Y, [[-0.05, SH], [0.05, SH], [0, HIP + 0.3]], '#efe3c4'); for (const sx of [-1, 1]) polyXY(g, X, Y, [[sx * 0.05, SH], [sx * 0.11, SH - 0.02], [sx * 0.02, HIP + 0.28]], tone(S.coat, 0.8)); }
      if (S.apron && !DRESS) polyXY(g, X, Y, back ? [[-0.04, HIP + 0.1], [0.04, HIP + 0.1], [0.04, HIP + 0.13], [-0.04, HIP + 0.13]] : [[-0.12, HIP - 0.06], [0.12, HIP - 0.06], [0.1, SH - 0.12], [-0.1, SH - 0.12]], hex(S.apron));
      if (DRESS && S.apron && !back) polyXY(g, X, Y, [[-0.07, WY], [0.07, WY], [0.07, HIP + 0.36], [-0.07, HIP + 0.36]], hex(S.apron));
      if (S.corset != null && !back) { polyXY(g, X, Y, [[-0.13, HIP + 0.1], [0.13, HIP + 0.1], [0.16, HIP + 0.36], [0, HIP + 0.31], [-0.16, HIP + 0.36]], hex(S.corset)); g.strokeStyle = '#f6efe0'; g.lineWidth = 1.5; for (let y = HIP + 0.13; y < HIP + 0.31; y += 0.025) { g.beginPath(); g.moveTo(X(-0.012), Y(y)); g.lineTo(X(0.012), Y(y + 0.025)); g.moveTo(X(0.012), Y(y)); g.lineTo(X(-0.012), Y(y + 0.025)); g.stroke(); } g.fillStyle = '#d8b24a'; for (const sx of [-1, 1]) for (let y = HIP + 0.14; y < HIP + 0.3; y += 0.035) { g.beginPath(); g.arc(X(sx * 0.07), Y(y), 1.8, 0, 7); g.fill(); } }
      if (DRESS && !S.neckline && !back) { g.fillStyle = '#d8b24a'; for (let y = WY + 0.03; y < SH - 0.02; y += 0.028) { g.beginPath(); g.arc(X(0), Y(y), 2, 0, 7); g.fill(); } lace(g, W, X, Y, SH - 0.005, -0.06, 0.06, false); } // a row of buttons up to a lace collar
      if (S.neckline) { const h = Y(SH - 0.1) - Y(SH + 0.03); if (!back) { g.fillStyle = skin; g.beginPath(); g.ellipse(X(0), Y(SH + 0.03), X(0.13) - X(0), h, 0, 0, Math.PI); g.fill(); g.strokeStyle = 'rgba(170,100,80,0.35)'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(X(0), Y(SH - 0.07)); g.lineTo(X(0), Y(SH - 0.095)); g.stroke(); } lace(g, W, X, Y, SH - 0.075, -0.14, 0.14, true); }
      if (!DRESS && !back) { const col = hex(S.collar ?? 0xefe3c4); for (const sx of [-1, 1]) polyXY(g, X, Y, [[0, SH + 0.01], [sx * 0.06, SH + 0.03], [sx * 0.045, SH - 0.04]], col, 'rgba(60,40,24,0.4)'); if (!S.overalls && !S.vest && !S.apron && !S.longcoat) { g.fillStyle = 'rgba(40,28,20,0.6)'; for (const yy of [0.18, 0.28, 0.38, 0.48]) { g.beginPath(); g.arc(X(0), Y(HIP + yy), 2.2, 0, 7); g.fill(); } } }
      if (MAN && !back && !S.overalls && !S.vest && !S.apron) { g.strokeStyle = 'rgba(40,24,16,0.16)'; g.lineWidth = 1.5; for (const sx of [-1, 1]) { g.beginPath(); g.moveTo(X(sx * 0.02), Y(HIP + 0.47)); g.quadraticCurveTo(X(sx * 0.12), Y(HIP + 0.43), X(sx * 0.16), Y(HIP + 0.38)); g.stroke(); } }
    };
    A.lathe(this.body, T, { n: 8, base: DRESS ? dressCol : coat, front: torsoArt(false), back: torsoArt(true) });
    // the neck
    const NR = MAN ? 0.042 * K : 0.03;
    A.lathe(this.body, [[SH - 0.03, NR * 1.15, NR * 1.1], [NECK + 0.08, NR, NR * 0.95]], { n: 6, base: skin, caps: false, front: (g, W, H) => { g.fillStyle = 'rgba(120,70,50,0.2)'; g.fillRect(0, 0, W, H * 0.25); } });
    if (S.pack) {
      A.box(this.body, { w: 0.3, h: 0.34, d: 0.12, y: HIP + 0.14, z: -0.16, faces: { all: { base: '#7b5a3a' }, back: { base: '#7b5a3a', draw: (g, W, H) => { g.fillStyle = '#6a4c30'; g.fillRect(0, 0, W, H * 0.4); g.fillStyle = '#d8b24a'; g.fillRect(W / 2 - 5, H * 0.36, 10, 8); } } } });
      A.prism(this.body, { n: 6, rb: 0.06, h: 0.36, x: 0.18, y: HIP + 0.52, z: -0.16, rz: Math.PI / 2, base: '#5f7f6a', draw: (g, W, H) => { g.fillStyle = '#4a3424'; g.fillRect(0, H * 0.2, W, 4); g.fillRect(0, H * 0.75, W, 4); }, top: '#c9b98f' });
    }
    if (S.sack) A.box(this.body, { w: 0.26, wt: 0.2, h: 0.32, d: 0.15, dt: 0.12, y: HIP + 0.16, z: -0.15, rz: 0.25, faces: { all: { base: '#c9b07a', draw: clothFace(3, (g, W, H) => { g.fillStyle = '#c4362f'; g.beginPath(); g.arc(W * 0.4, H * 0.12, W * 0.12, 0, 7); g.fill(); }) } } });

    // ---------------- arms: an upper arm (puffed at the shoulder on a dress), an elbow, a forearm and a hand
    const AK = BURLY ? 1.55 : MAN ? 1.22 : 0.85;
    this.hands = [];
    this.arms = [-1, 1].map((s) => {
      const sh = new THREE.Group(); sh.position.set((SR - 0.015) * s, SH - 0.045, 0); this.body.add(sh);
      const cuff = (g, W, H, X, Y) => { cloth(g, S.coatPat || 0, 0, 0, W, H); if (DRESS) damask(g, W, H, tone(S.sleeve ?? S.dress ?? 0x6b4a30, 0.6), 0.14); };
      A.lathe(sh, [[-0.29, 0.026 * AK, 0.027 * AK], [-0.15, 0.033 * AK, 0.035 * AK], [-0.03, 0.04 * AK, 0.042 * AK], [0.03, 0.038 * AK, 0.04 * AK], [0.055, 0.012, 0.012]], { n: 6, base: sleeve, front: cuff, back: cuff });
      if (DRESS && !S.rolled) A.lathe(sh, [[-0.1, 0.05, 0.05], [-0.03, 0.068, 0.068], [0.045, 0.045, 0.045], [0.065, 0.015, 0.015]], { n: 12, pleat: 0.18, base: sleeve, front: (g, W, H, X, Y) => { cuff(g, W, H); lace(g, W, X, Y, -0.095, -1, 1, true); }, back: cuff }); // a puffed sleeve
      const el = (sh.elbow = new THREE.Group()); el.position.set(0, -0.285, 0); sh.add(el);
      const fore = S.rolled ? skin : DRESS && S.short ? skin : sleeve;
      A.lathe(el, [[-0.255, 0.019 * AK, 0.02 * AK], [-0.13, 0.026 * AK, 0.028 * AK], [-0.02, 0.027 * AK, 0.028 * AK], [0.015, 0.016, 0.016]], { n: 6, base: fore, front: (g, W, H, X, Y) => { if (fore === sleeve) { cuff(g, W, H); g.fillStyle = DRESS ? '#f3e9d6' : 'rgba(255,248,232,0.7)'; g.fillRect(0, H - 6, W, 6); } else if (S.rolled) { g.fillStyle = tone(S.coat, 0.85); g.fillRect(0, 0, W, H * 0.15); } } });
      A.lathe(el, [[-0.345, 0.008, 0.006], [-0.315, 0.021, 0.009], [-0.275, 0.024, 0.011], [-0.25, 0.018, 0.013]], { n: 6, base: skin, front: (g, W, H) => { g.strokeStyle = 'rgba(150,84,60,0.35)'; g.lineWidth = 1; for (const k of [0.38, 0.5, 0.62]) { g.beginPath(); g.moveTo(W * k, H * 0.45); g.lineTo(W * k, H); g.stroke(); } } }); // a slender hand
      const hand = new THREE.Group(); hand.position.set(0, -0.3, 0.012); el.add(hand); this.hands.push(hand);
      const hs = new THREE.Group(); hs.position.y = -0.08; sh.add(hs); // (the longer arm: what's held rides lower)
      if (s > 0 && S.hold === 'clipboard') A.card(hs, [[-0.15, 0], [0.15, 0], [0.15, 0.38], [-0.15, 0.38]], { base: '#b08a5a', draw: (g, px) => { g.fillStyle = '#f3ead6'; const [a0, b0] = px(-0.12, 0.33), [a1, b1] = px(0.12, 0.03); g.fillRect(a0, b0, a1 - a0, b1 - b0); g.strokeStyle = 'rgba(60,50,40,0.5)'; for (let k = 0; k < 5; k++) { g.beginPath(); g.moveTo(a0 + 4, b0 + 8 + k * 9); g.lineTo(a1 - 4, b0 + 8 + k * 9); g.stroke(); } }, y: -0.62, z: 0.14, rx: -0.3 });
      if (s > 0 && S.hold === 'staff') A.box(hs, { w: 0.05, h: 1.75, d: 0.05, y: -1.32, z: 0.1, faces: { all: { base: '#7a5a38' } } });
      if (s > 0 && (S.hold === 'axe' || S.hold === 'pick')) {
        const rx = Math.PI / 2 - 0.5, up = [Math.cos(rx), Math.sin(rx)];
        A.box(hs, { w: 0.05, h: 0.8, d: 0.05, y: -0.5, z: 0.1, rx, faces: { all: { base: '#8a6038' } } });
        if (S.hold === 'axe') A.box(hs, { w: 0.04, h: 0.24, d: 0.16, y: -0.5 + up[0] * 0.62, z: 0.1 + up[1] * 0.62 + 0.06, rx, faces: { all: { base: '#b9bec4' } } });
        else A.box(hs, { w: 0.04, h: 0.05, d: 0.5, y: -0.5 + up[0] * 0.7, z: 0.1 + up[1] * 0.7, rx: rx - Math.PI / 2, faces: { all: { base: '#9a9da2' } } });
      }
      // the tools of other trades, so you can tell who does what at a glance
      if (s > 0 && S.hold === 'rod') { // a willow fishing pole with a red-and-white bob hanging off the tip
        A.box(hs, { w: 0.03, wt: 0.015, h: 1.9, d: 0.03, dt: 0.015, y: -0.55, z: 0.08, rx: 0.6, faces: { all: { base: '#a88a50' } } });
        A.box(hs, { w: 0.07, h: 0.09, d: 0.07, y: -0.55 + Math.cos(0.6) * 1.9 - 0.75, z: 0.08 + Math.sin(0.6) * 1.9, faces: { all: { base: '#efe3c4', draw: (g, W, H) => { g.fillStyle = '#c4362f'; g.fillRect(0, 0, W, H / 2); } } } });
        A.box(hs, { w: 0.008, h: 0.66, d: 0.008, y: -0.55 + Math.cos(0.6) * 1.9 - 0.66, z: 0.08 + Math.sin(0.6) * 1.9, faces: { all: { base: '#e8e2d6' } } });
      }
      if (s > 0 && S.hold === 'bucket') { // a stave sap bucket on a wire bail, hanging from the hand
        A.prism(hs, { n: 8, rb: 0.1, rt: 0.13, h: 0.22, y: -0.86, z: 0.02, base: '#a8784a', draw: (g, W, H) => { g.fillStyle = '#6e7274'; g.fillRect(0, H * 0.15, W, 4); g.fillRect(0, H * 0.75, W, 4); g.strokeStyle = 'rgba(60,36,20,0.4)'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(W / 2, 0); g.lineTo(W / 2, H); g.stroke(); }, top: '#c98a3a' });
        A.box(hs, { w: 0.25, h: 0.2, d: 0.012, y: -0.64, z: 0.02, wt: 0.04, faces: { front: { base: '#6e7274' }, back: { base: '#6e7274' }, side: { base: '#6e7274' } } });
      }
      if (s > 0 && S.hold === 'shovel') { // a long-handled spade, its blade resting on the ground
        A.box(hs, { w: 0.045, h: 0.98, d: 0.045, y: -0.88, z: 0.12, faces: { all: { base: '#8a6038' } } });
        A.box(hs, { w: 0.14, h: 0.05, d: 0.05, y: -0.08, z: 0.12, faces: { all: { base: '#8a6038' } } });
        A.box(hs, { w: 0.22, wt: 0.2, h: 0.28, d: 0.03, y: -1.12, z: 0.12, faces: { all: { base: '#9a9da2', draw: (g, W, H) => { g.fillStyle = 'rgba(120,80,50,0.45)'; g.fillRect(0, H * 0.6, W, H * 0.4); } } } });
      }
      if (s > 0 && S.hold === 'smoker') { // a beekeeper's tin smoker: a can, a spout and a pair of leather bellows
        A.prism(hs, { n: 8, rb: 0.075, h: 0.2, y: -0.8, z: 0.06, base: '#b9bec4', draw: (g, W, H) => { g.fillStyle = 'rgba(0,0,0,0.18)'; g.fillRect(0, H - 5, W, 5); } });
        A.prism(hs, { n: 8, rb: 0.07, rt: 0.025, h: 0.09, y: -0.6, z: 0.06, base: '#a9adae', top: '#5a5048' });
        A.box(hs, { w: 0.05, h: 0.18, d: 0.12, wt: 0.05, dt: 0.06, y: -0.78, z: -0.06, faces: { all: { base: '#8a5a34', draw: (g, W, H) => { g.strokeStyle = 'rgba(40,24,14,0.5)'; g.lineWidth = 1.5; for (let k = 1; k < 4; k++) { g.beginPath(); g.moveTo(0, H * k / 4); g.lineTo(W, H * k / 4); g.stroke(); } } } } });
      }
      if (s > 0 && S.hold === 'flour') // a sack of flour humped on the shoulder, stencilled with the mill's blue stripe
        A.box(hs, { w: 0.34, wt: 0.3, h: 0.3, d: 0.58, dt: 0.5, y: -0.02, x: 0.02, faces: { all: { base: '#efe5cc', draw: (g, W, H) => { g.fillStyle = 'rgba(80,110,160,0.75)'; g.fillRect(0, H * 0.4, W, H * 0.18); g.fillStyle = 'rgba(255,255,255,0.5)'; for (let k = 0; k < 6; k++) g.fillRect((k + 0.2) * W / 6, H * 0.8, 3, 3); } } } });
      if (s > 0 && S.hold === 'hide') // a tanned hide slung over the forearm
        A.card(hs, [[-0.12, 0], [0.12, 0], [0.16, -0.12], [0.12, -0.42], [0.04, -0.36], [-0.04, -0.44], [-0.12, -0.38], [-0.16, -0.1]], { base: '#b08048', draw: (g, px) => { g.fillStyle = 'rgba(90,56,30,0.35)'; for (let k = 0; k < 5; k++) { const [a, b] = px(-0.1 + k * 0.05, -0.1 - (k % 2) * 0.12); g.beginPath(); g.ellipse(a, b, 6, 4, 0, 0, 7); g.fill(); } }, y: -0.4, z: 0.12 });
      if (S.hold === 'bow') A.card(hs, s > 0 ? [[-0.015, 0], [0.015, 0], [0.015, -0.7], [-0.015, -0.7]] : [[-0.13, -0.5], [0.13, -0.5], [0.09, -0.9], [-0.09, -0.9]], { base: s > 0 ? '#5a3a24' : '#9a5a2a', y: s > 0 ? -0.6 : 0, z: 0.14, rx: s > 0 ? -1.4 : 0 });
      return sh;
    });

    // ---------------- the head: a faceted head with the face painted on; hair up in curls, or a hat
    this.head = new THREE.Group(); this.head.position.set(0, NECK + (MAN ? 0.035 : 0.06), 0); this.body.add(this.head);
    const k = HH / 0.62, HR = (MAN ? [[0, 0.11, 0.09, 0.035], [0.06, 0.165, 0.14, 0.04], [0.16, 0.205, 0.19, 0.03], [0.29, 0.222, 0.212, 0.018], [0.41, 0.232, 0.228, 0.006], [0.5, 0.222, 0.226, -0.004], [0.57, 0.175, 0.19, -0.016], [0.62, 0.07, 0.09, -0.026]]
      : [[0, 0.075, 0.075, 0.035], [0.06, 0.13, 0.13, 0.04], [0.16, 0.18, 0.18, 0.03], [0.29, 0.212, 0.21, 0.018], [0.41, 0.226, 0.226, 0.006], [0.5, 0.218, 0.224, -0.004], [0.57, 0.175, 0.19, -0.016], [0.62, 0.07, 0.09, -0.026]]).map(([y, a, b, d]) => [y * k, a * k, b * k, d * k]);
    const kc = HH / 0.52; // the face's painting frame (face-card units) onto the head
    const facePrint = (shut) => (g, W, H, X, Y) => {
      const px = (x, y) => [X(x * kc), Y(y * kc)];
      faceArt(S, MAN, shut)(g, px);
      if (S.beard != null) { // a beard combed down the jaw, a moustache
        const bp = [[-0.2, 0.22], [-0.16, 0.18], [-0.1, 0.13], [-0.05, 0.12], [0.05, 0.12], [0.1, 0.13], [0.16, 0.18], [0.2, 0.22], [0.2, -0.1], [-0.2, -0.1]];
        shapeP(g, px, bp, hex(S.beard)); strandsP(g, px, -0.19, 0.19, 0.16, -0.05, 18);
        shapeP(g, px, [[-0.1, 0.13], [-0.03, 0.115], [0, 0.12], [0.03, 0.115], [0.1, 0.13], [0.06, 0.1], [0, 0.105], [-0.06, 0.1]], tone(S.beard, 0.8));
        shapeP(g, px, [[-0.03, 0.09], [0.03, 0.09], [0.02, 0.075], [-0.02, 0.075]], '#9a4a3a');
      }
    };
    const headBack = (g, W, H, X, Y) => { const bald = S.hair == null && S.beard != null; g.fillStyle = bald ? skin : hairCol; g.fillRect(0, 0, W, Y(MAN ? 0.05 * k : 0.0)); if (bald) { g.fillStyle = hex(S.beard); g.fillRect(0, Y(0.4 * k), W, Y(0.15 * k) - Y(0.4 * k)); } strandsP(g, (x, y) => [X(x), Y(y)], -0.1, 0.1, HH, 0.02, 16); };
    A.lathe(this.head, HR, { n: 8, ppu: 1300, base: skin, front: facePrint(false), back: headBack });
    A.box(this.head, { w: MAN ? 0.026 : 0.019, wt: MAN ? 0.012 : 0.009, h: MAN ? 0.045 : 0.036, d: 0.028, dt: 0.006, y: (MAN ? 0.23 : 0.245) * k, z: 0.212 * k + 0.004, ppu: 1300, faces: { front: { base: tone(S.skin, 0.98) }, side: { base: tone(S.skin, 0.9) }, top: { base: skin }, bottom: { base: tone(S.skin, 0.72) } } }); // the folded nose
    for (const sx of [-1, 1]) A.card(this.head, [[0, -0.02], [0.01, -0.016], [0.014, 0], [0.011, 0.016], [0, 0.02], [-0.006, 0.01], [-0.006, -0.01]], { base: tone(S.skin, 0.94), x: sx * 0.224 * k, y: 0.31 * k, z: -0.01, ry: sx * Math.PI / 2 });
    // hair: a sculpted cap of paper hair over the crown (its front edge lifted into a swept hairline with a side
    // parting), and for the women an updo of curls piled on the crown, loose tendrils, a fall at the nape
    const bald = S.hair == null && S.beard != null;
    if (!bald && S.hat !== 'bonnet') {
      const capArt = (g, W, H, X, Y) => { g.strokeStyle = 'rgba(0,0,0,0.22)'; g.lineWidth = 1.6; for (let i = 0; i < 16; i++) { const x = -0.12 + i * 0.016; g.beginPath(); g.moveTo(X(x), Y(HH * 1.02)); g.quadraticCurveTo(X(x + (MAN ? 0.03 : 0.04)), Y(HH * 0.75), X(x + (MAN ? 0.04 : 0.06)), Y(HH * 0.45)); g.stroke(); } g.strokeStyle = 'rgba(255,240,210,0.28)'; for (let i = 0; i < 8; i++) { const x = -0.11 + i * 0.03; g.beginPath(); g.moveTo(X(x), Y(HH)); g.quadraticCurveTo(X(x + 0.035), Y(HH * 0.78), X(x + 0.05), Y(HH * 0.5)); g.stroke(); } };
      const hk = 1.07, lift = (a) => (MAN ? 0.2 : 0.25) * HH * Math.max(0, Math.cos(a - 0.3)) ** 1.5; // swept: higher over one brow than the other
      A.lathe(this.head, [[0.36 * k, 0.236 * k * hk, 0.234 * k * hk, 0.004], [0.46 * k, 0.24 * k * hk, 0.24 * k * hk, 0.0], [0.55 * k, 0.21 * k * hk, 0.22 * k * hk, -0.01], [0.62 * k, 0.12 * k * hk, 0.14 * k * hk, -0.02], [0.66 * k, 0.02, 0.02, -0.025]], { n: 10, base: hairCol, front: capArt, back: capArt, hem: lift, caps: false });
    }
    if (!MAN && S.hat !== 'bonnet') {
      for (const [cx, cy, cz, r] of [[0.0, 0.66, -0.06, 0.055], [-0.045, 0.6, -0.085, 0.042], [0.05, 0.61, -0.08, 0.04], [-0.02, 0.53, -0.1, 0.04], [0.03, 0.7, -0.02, 0.038]]) A.lathe(this.head, [[-r * 0.9, r * 0.35, r * 0.35], [-r * 0.4, r * 0.95, r * 0.9], [r * 0.3, r, r * 0.95], [r * 0.85, r * 0.45, r * 0.45]], { n: 7, base: tone(S.hair ?? 0x5a3e2a, 0.92 + (cx > 0 ? 0.06 : 0)), x: cx, y: cy * HH / 0.62 * 1.08, z: cz, rz: cx * 4, front: (g, W, H) => { g.strokeStyle = 'rgba(0,0,0,0.25)'; g.lineWidth = 1.5; g.beginPath(); g.arc(W / 2, H / 2, Math.min(W, H) * 0.3, 0.4, 5.6); g.stroke(); }, back: (g, W, H) => { g.strokeStyle = 'rgba(0,0,0,0.22)'; g.lineWidth = 1.5; g.beginPath(); g.arc(W / 2, H / 2, Math.min(W, H) * 0.3, 0.4, 5.6); g.stroke(); } }); // the curls of the updo
    }
    // the old single bun, a short fall, tendrils and trimmings
    if (!MAN && S.hat !== 'bonnet') {
      const curls = (g, W, H) => { g.fillStyle = tone(S.hair ?? 0x5a3e2a, 0.78); for (let i = 0; i < 9; i++) { g.beginPath(); g.arc((i % 3 + 0.5) * W / 3, (Math.floor(i / 3) + 0.5) * H / 3, Math.min(W, H) / 7, 0.3, 5.2); g.lineWidth = 2; g.strokeStyle = tone(S.hair ?? 0x5a3e2a, 0.7); g.stroke(); } g.strokeStyle = 'rgba(255,240,210,0.25)'; g.lineWidth = 1.5; for (let i = 0; i < 6; i++) { g.beginPath(); g.arc((i + 0.5) * W / 6, H * 0.5, W / 14, 3.4, 6); g.stroke(); } };
      if (S.long) A.lathe(this.head, [[-0.07, 0.035, 0.02, -0.075], [0.06, 0.07, 0.035, -0.07], [0.2 * k, 0.085, 0.045, -0.06]], { n: 8, base: hairCol, front: curls, back: curls }); // a fall of curls at the nape
      for (const sx of [-1, 1]) A.lathe(this.head, [[0.05, 0.008, 0.008], [0.14, 0.013, 0.013], [0.22, 0.008, 0.008]], { n: 5, base: hairCol, x: sx * 0.085, z: 0.02, rz: sx * 0.15 }); // tendrils by the ears
    }
    if (S.flower != null || (!MAN && S.glam)) { // a paper rose pinned in the hair
      const fc = hex(S.flower ?? 0xb8505a);
      A.prism(this.head, { n: 7, rb: 0.022, rt: 0.032, h: 0.022, x: 0.06, y: 0.2, z: 0.0, rx: -0.5, rz: -0.5, base: fc, draw: (g, W, H) => { g.strokeStyle = 'rgba(0,0,0,0.25)'; g.lineWidth = 1.5; g.beginPath(); g.arc(W / 2, H, W * 0.4, 3.4, 6); g.stroke(); }, top: tone(S.flower ?? 0xb8505a, 0.8) });
    }
    if (S.feather || (!MAN && S.glam && S.hat === 'none')) A.card(this.head, [[0, 0], [0.012, 0.03], [0.02, 0.08], [0.012, 0.13], [-0.004, 0.16], [-0.01, 0.12], [-0.008, 0.06], [-0.004, 0.02]], { base: hex(S.feather ?? 0xe8d8b8), x: 0.045, y: 0.2, z: -0.03, rz: -0.35, draw: (g, px) => { g.strokeStyle = 'rgba(90,70,50,0.6)'; g.lineWidth = 1.5; const [a, b] = px(0, 0), [c, d] = px(0.004, 0.15); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); g.lineWidth = 1; for (let i = 1; i < 12; i++) { const [e, f] = px(0.002 * i / 12, i * 0.012), [h, j] = px(0.016, i * 0.012 + 0.008); g.beginPath(); g.moveTo(e, f); g.lineTo(h, j); g.stroke(); } } });
    // blinking: the same head with the eyes shut, a hair larger, shown for a moment
    this.blinkGroup = new THREE.Group(); this.head.add(this.blinkGroup);
    A.lathe(this.blinkGroup, HR.slice(1, 6).map(([y, a, b, d]) => [y, a * 1.012, b * 1.012, d]), { n: 8, ppu: 900, base: skin, front: facePrint(true), back: headBack, caps: false });

    // ---------------- hats: folded paper, a card brim and a faceted crown
    const hatG = new THREE.Group(); hatG.position.y = 0.5 * k; this.head.add(hatG);
    const hc = hex(S.hatColor ?? 0x2e2824), band = hex(S.band ?? 0xa63c2e), straw = '#e2c27a';
    const disc = (r, n = 18) => { const p = []; for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2; p.push([Math.cos(a) * r, Math.sin(a) * r * 0.92]); } return p; };
    const brim = (r, col, weave) => A.card(hatG, disc(r), { base: col, rx: -Math.PI / 2, y: 0.005, draw: (g, px) => { const [a0, b0] = px(-r, r), [a1, b1] = px(r, -r); if (weave) cloth(g, 3, a0, b0, a1, b1); } });
    const crown = (rb, rt, h, col, extra) => A.prism(hatG, { n: 8, rb, rt, h, base: col, draw: (g, W, H, i) => { if (col === straw) cloth(g, 3, 0, 0, W, H); g.fillStyle = band; g.fillRect(0, H * 0.62, W, H * 0.24); extra?.(g, W, H, i); } });
    if (S.hat === 'straw') { brim(0.2, straw, true); crown(0.1, 0.088, 0.075, straw); }
    else if (S.hat === 'sunday') { hatG.rotation.set(-0.12, 0, 0.12); brim(0.15, hc, false); crown(0.085, 0.078, 0.06, hc); A.card(hatG, [[0, 0], [0.012, 0.03], [0.02, 0.08], [0.012, 0.13], [-0.004, 0.16], [-0.01, 0.12], [-0.008, 0.06]], { base: '#5a4a3e', x: 0.06, y: 0.05, z: -0.03, rz: -0.6 }); }
    else if (S.hat === 'stovepipe') { brim(0.14, hc, false); crown(0.08, 0.082, 0.17, hc); }
    else if (S.hat === 'pot') { A.prism(hatG, { n: 8, rb: 0.11, rt: 0.105, h: 0.08, y: -0.02, base: '#a9adae' }); }
    else if (S.hat === 'cap') { A.prism(hatG, { n: 8, rb: 0.105, rt: 0.088, h: 0.05, y: -0.01, base: hc }); A.card(hatG, [[-0.06, 0], [0.06, 0], [0.05, 0.055], [-0.05, 0.055]], { base: tone(S.hatColor ?? 0x2e2824, 0.85), y: 0.0, z: 0.085, rx: Math.PI / 2 - 0.15 }); }
    else if (S.hat === 'bonnet') { A.prism(hatG, { n: 8, rb: 0.11, rt: 0.075, h: 0.13, y: -0.11, z: -0.03, rx: -0.5, base: hex(S.hatColor ?? 0x8a74a8), draw: (g, W, H) => cloth(g, 2, 0, 0, W, H) }); }

    A.bake();
    hatG.traverse((o) => { if (o.isMesh) o.castShadow = false; });
    this.blinkGroup.visible = false;
    this.phase = Math.random() * 6; this.t = Math.random() * 10; this.blinkT = 2 + Math.random() * 3;
    this.look = 0; this.gaze = Math.random() * 20;
  }

  /** Where the farmer is (set each frame by main.js), so folk can look round at him. */
  static watch = null;
  static cam = null;

  /** speed in m/s; pose: null | 'work' | 'dance' | 'clipboard' | 'fiddle' | 'sit' | 'cancan' | 'beckon'; opts.air / opts.swim. */
  update(dt, speed = 0, pose = null, opts = {}) {
    this.t += dt;
    const moving = Math.min(1, speed / 4.5), still = 1 - moving;
    this.phase += dt * (2.4 + speed * 1.9);
    const s = Math.sin(this.phase), c = Math.cos(this.phase);
    const [L, R] = this.legs, [AL, AR] = this.arms;
    const air = opts.air, swim = opts.swim;
    // the walk: legs swing from the hip, arms swing against them with a soft bend at the elbow, a gentle bob
    const hip = air ? 0 : 0.6 * moving;
    L.rotation.set(s * hip + (air ? -0.45 : 0), 0, 0); R.rotation.set(-s * hip + (air ? 0.25 : 0), 0, 0);
    const breath = Math.sin(this.t * 1.6) * 0.012;
    AL.rotation.set(-s * 0.5 * moving, 0, -0.1 - breath); AR.rotation.set(s * 0.5 * moving, 0, 0.1 + breath);
    AL.elbow.rotation.set(-0.18 - 0.35 * moving * (0.5 + 0.5 * Math.max(0, -s)), 0, 0); AR.elbow.rotation.set(-0.18 - 0.35 * moving * (0.5 + 0.5 * Math.max(0, s)), 0, 0);
    // standing: a slow shift of weight from one hip to the other, a breath, and now and then a long look up at the sky
    const shift = Math.sin(this.t * 0.45) * still;
    this.body.position.set(shift * 0.012, air ? 0 : Math.abs(c) * 0.035 * moving + breath * 0.5, 0);
    this.body.rotation.set(swim ? 0.9 : moving * 0.05, s * 0.06 * moving, shift * 0.025);
    L.rotation.z = Math.max(0, shift) * 0.04; R.rotation.z = Math.min(0, shift) * 0.04;
    this.gaze += dt; const up = still * Math.max(0, Math.sin(this.gaze * 0.17) - 0.55) * 1.2;
    this.head.rotation.set(-up * 0.5 + c * 0.02 * moving, still * Math.sin(this.t * 0.31) * 0.15, -shift * 0.04);
    if (swim) { AL.rotation.x = -2.2 + Math.sin(this.phase * 1.2) * 0.8; AR.rotation.x = -2.2 - Math.sin(this.phase * 1.2) * 0.8; }
    if (pose === 'work') { const k = Math.sin(this.t * 4.2); AR.rotation.set(-1.9 + k * 1.2, 0, 0.1); AR.elbow.rotation.x = -0.5 - k * 0.3; AL.rotation.set(-1.1 + k * 0.6, 0, -0.05); AL.elbow.rotation.x = -0.6; this.body.rotation.x = 0.12 + k * 0.08; }
    if (pose === 'dance') { const k = Math.sin(this.t * 4); AL.rotation.set(-0.3, 0, -1.1 - k * 0.2); AR.rotation.set(-0.3, 0, 1.1 + k * 0.2); AL.elbow.rotation.x = -0.7; AR.elbow.rotation.x = -0.7; this.body.position.y += Math.abs(k) * 0.05; L.rotation.x += Math.max(0, k) * 0.4; R.rotation.x -= Math.max(0, -k) * 0.4; this.body.rotation.y += k * 0.2; }
    if (pose === 'clipboard') { AR.rotation.set(-0.45, 0, 0.1); AR.elbow.rotation.x = -1.2; }
    if (pose === 'cancan') { const k = Math.sin(this.t * 5.5); L.rotation.x = k > 0 ? -k * 1.45 : 0; R.rotation.x = k < 0 ? k * 1.45 : 0; AL.rotation.set(-0.35, 0, -0.55); AR.rotation.set(-0.35, 0, 0.55); AL.elbow.rotation.x = -0.9; AR.elbow.rotation.x = -0.9; this.body.position.y = Math.abs(k) * 0.06; this.body.rotation.x = -Math.abs(k) * 0.08; }
    if (pose === 'beckon') { const k = Math.sin(this.t * 2.4); AL.rotation.set(0.15, 0, -0.62); AL.elbow.rotation.set(-0.4, 0, 1.75); AR.rotation.set(-1.2, 0, 0.25); AR.elbow.rotation.x = -1.0 - Math.max(0, k) * 0.5; this.body.rotation.z = 0.06; this.head.rotation.z = -0.12; L.rotation.z = 0.06; R.rotation.x = -0.15; }
    if (pose === 'fiddle') { AL.rotation.set(-1.3, 0, -0.45); AL.elbow.rotation.x = -1.4; AR.rotation.set(-0.9, 0, 0.3); AR.elbow.rotation.x = -1.0 + Math.sin(this.t * 7) * 0.35; this.head.rotation.z = 0.25; }
    if (pose === 'sit') { L.rotation.set(-1.45, 0, 0.12); R.rotation.set(-1.45, 0, -0.12); }
    // folk notice you: within a few metres, a figure standing about turns its head to look at you
    let want = 0;
    const w = Figure.watch, e = this.root.matrixWorld.elements;
    if (w && pose !== 'work' && pose !== 'dance' && pose !== 'cancan' && moving < 0.5) {
      const dx = w.x - e[12], dz = w.z - e[14], d2 = dx * dx + dz * dz;
      if (d2 > 0.36 && d2 < 49) { const fwd = Math.atan2(e[8], e[10]); let a = Math.atan2(dx, dz) - fwd; a = Math.atan2(Math.sin(a), Math.cos(a)); if (Math.abs(a) < 2.4) want = Math.max(-1.4, Math.min(1.4, a)); }
    }
    this.look += (want - this.look) * Math.min(1, dt * (want ? 3 : 1.5));
    if (Math.abs(this.look) > 0.01) { this.head.rotation.y = this.head.rotation.y * 0.3 + this.look * 0.7; this.head.rotation.x *= 0.3; this.body.rotation.y += this.look * 0.25; }
    // a blink every few seconds
    if ((this.blinkT -= dt) <= 0) { this.blinkT = 2.5 + Math.random() * 3.5; this.blinkUntil = this.t + 0.13; }
    this.blinkGroup.visible = this.t < (this.blinkUntil || 0);
  }
}
