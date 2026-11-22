// Landmarks of the wild lands: one rare, tall set piece per land, seen from far off over the trees, each with
// something to find the first time you reach it. Built the papercraft way: layered printed flats, cards and a
// few folded beams.
//   the Redrock Breaks      the Redrock Arch: three layered flats of banded red rock, a natural bridge
//   the Misty Fen           the Belle of the Fen: a sternwheeler sunk to her rails, stacks leaning, wheel rotting
//   the Bluepine Highlands  the fire lookout: a timber tower with a cabin on top; climb its view to fill the map
//   the Golden Prairie      a lost prairie schooner: a broken covered wagon, canvas torn, an ox skull in the grass
//   the Silver Birch Hollows the Grandmother Birch: a birch three times any other, in a ring of toadstools
// Each landmark is built once per kind (shared geometry and materials) and placed with its chunk.
import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { cardMaterial, paperMaterial } from './materials.js';
import { cardGeometry, propKinds } from './props.js';
import { paintCard } from './textures.js';
import { Puppet } from './puppets.js';
import { Figure } from './figure.js';
import { propModel, ModelFigure, hasFolk } from './modelfolk.js';

const rgbA = (hex) => { const c = new THREE.Color(hex); return `rgba(${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)},A)`; };
const tone = (hex, k) => { const c = new THREE.Color(hex); c.multiplyScalar(k); return `#${c.getHexString()}`; };
function art(pts, base, draw, { W = 512, H = 512, seed = 1 } = {}) {
  return paintCard(pts, { W, H, seed, base, fills: [rgbA(base), rgbA(tone(base, 0.9)), rgbA(tone(base, 1.08))], edge: rgbA(tone(base, 0.45)).replace(',A)', ',1)'), details: draw });
}
/** A printed card mesh: outline points, its art, thickness. */
function card(pts, base, draw, opts = {}) {
  const m = new THREE.Mesh(cardGeometry(pts, opts.thick ?? 0.08), cardMaterial(art(pts, base, draw, opts)));
  m.castShadow = true; m.receiveShadow = true;
  return m;
}
/** Square timber beams between pairs of points, merged into one mesh. */
function beams(list, color, w = 0.16) {
  const geos = list.map(([a, b, ww = w]) => {
    const A = new THREE.Vector3(...a), B = new THREE.Vector3(...b), d = B.clone().sub(A), len = d.length();
    const g = new THREE.BoxGeometry(ww, len, ww);
    g.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), d.normalize()));
    g.translate((A.x + B.x) / 2, (A.y + B.y) / 2, (A.z + B.z) / 2);
    return g.toNonIndexed();
  });
  const m = new THREE.Mesh(mergeGeometries(geos), paperMaterial({ color, flatShading: true }));
  m.castShadow = true; m.receiveShadow = true;
  return m;
}
const disc = (r, n = 18, y0 = 0) => { const p = []; for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2; p.push([Math.cos(a) * r, y0 + Math.sin(a) * r]); } return p; };
/** A cart wheel / paddle wheel print: rim, hub and spokes. */
const wheelArt = (r, rim, spokes = 10) => (g, px) => {
  const [cx, cy] = px(0, 0), R = px(r, 0)[0] - cx;
  g.strokeStyle = rim; g.lineWidth = R * 0.14; g.beginPath(); g.arc(cx, cy, R * 0.86, 0, Math.PI * 2); g.stroke();
  g.lineWidth = R * 0.07; for (let k = 0; k < spokes; k++) { const a = (k / spokes) * Math.PI * 2; g.beginPath(); g.moveTo(cx, cy); g.lineTo(cx + Math.cos(a) * R * 0.82, cy + Math.sin(a) * R * 0.82); g.stroke(); }
  g.fillStyle = rim; g.beginPath(); g.arc(cx, cy, R * 0.16, 0, Math.PI * 2); g.fill();
};

// ---------------------------------------------------------------- the five landmarks

function arch() {
  const g = new THREE.Group();
  // three flats, back to front: the back one biggest and darkest, the front one smallest and lightest
  for (const [k, z, sc, base] of [[0, -0.7, 1.08, '#8e4a30'], [1, 0, 1.0, '#a85a3a'], [2, 0.7, 0.93, '#bd6d48']]) {
    const pts = [[-4.6, 0]];
    for (let i = 0; i <= 14; i++) { const a = Math.PI - (i / 14) * Math.PI; pts.push([Math.cos(a) * 4.6 + Math.sin(i * 2.7 + k) * 0.18, 4.2 + Math.sin(a) * 2.3 + Math.cos(i * 1.9 + k) * 0.16]); }
    pts.push([4.6, 0], [2.5, 0]);
    for (let i = 0; i <= 10; i++) { const a = (i / 10) * Math.PI; pts.push([Math.cos(a) * 2.5, 2.7 + Math.sin(a) * 1.3]); }
    pts.push([-2.5, 0]);
    const m = card(pts.map(([x, y]) => [x * sc, y * sc]), base, (gg, px, rng) => {
      // bands of strata, each a torn strip of a slightly different red; dark desert-varnish streaks; lichen
      for (let b = 0; b < 9; b++) { const y = 0.3 + b * 0.75; gg.fillStyle = b % 2 ? 'rgba(120,50,30,0.35)' : 'rgba(226,150,110,0.3)'; gg.beginPath(); for (let i = 0; i <= 20; i++) { const [x1, y1] = px(-5 + i * 0.5, y + Math.sin(i * 1.3 + b) * 0.08); i ? gg.lineTo(x1, y1) : gg.moveTo(x1, y1); } for (let i = 20; i >= 0; i--) { const [x1, y1] = px(-5 + i * 0.5, y + 0.32 + Math.sin(i * 1.1 + b) * 0.08); gg.lineTo(x1, y1); } gg.fill(); }
      for (let i = 0; i < 14; i++) { const [x1, y1] = px(-4.4 + rng() * 8.8, 6.2 - rng() * 1.5); gg.fillStyle = 'rgba(60,30,24,0.35)'; gg.fillRect(x1, y1, 4 + rng() * 6, 30 + rng() * 60); }
      for (let i = 0; i < 18; i++) { const [x1, y1] = px(-4.4 + rng() * 8.8, rng() * 6); gg.fillStyle = 'rgba(214,220,170,0.55)'; gg.beginPath(); gg.arc(x1, y1, 3 + rng() * 5, 0, Math.PI * 2); gg.fill(); }
    }, { W: 768, H: 512, seed: 301 + k, thick: 0.1 });
    m.position.z = z; g.add(m);
  }
  return { group: g, colliders: [[-3.6, 0, 1.3], [3.6, 0, 1.3]], radius: 6 };
}

function steamboat() {
  const g = new THREE.Group(), hull = new THREE.Group(); g.add(hull);
  const hullPts = [[-5, 0], [4.0, 0], [5.0, 0.9], [5.4, 1.7], [-5, 1.7]];
  for (const z of [-1.4, 1.4]) {
    const m = card(hullPts, '#e8e0cc', (gg, px) => {
      gg.strokeStyle = 'rgba(120,100,80,0.45)'; gg.lineWidth = 2; for (let y = 0.25; y < 1.7; y += 0.25) { const [a, b] = px(-5, y), [c] = px(5.4, y); gg.beginPath(); gg.moveTo(a, b); gg.lineTo(c, b); gg.stroke(); }
      gg.fillStyle = '#b5473a'; { const [a, b] = px(-5, 1.7), [c, d] = px(5.4, 1.45); gg.fillRect(a, b, c - a, d - b); }
      gg.fillStyle = '#4a6a7a'; { const [a, b] = px(-5, 0.5), [c, d] = px(5.4, 0); gg.fillRect(a, b, c - a, d - b); } // the waterline, stained
      gg.fillStyle = '#3a2a1c'; gg.font = 'italic bold 30px Georgia, serif'; gg.textAlign = 'center'; { const [a, b] = px(0.2, 0.8); gg.fillText('Belle of the Fen', a, b); }
    }, { W: 1024, H: 200, seed: 311 });
    m.position.z = z; hull.add(m);
  }
  // the cabin deck: a long white house with arched windows, and the pilot house on top
  const cabinPts = [[-3.6, 1.7], [2.6, 1.7], [2.6, 3.2], [-3.6, 3.2]];
  const windows = (x0, x1, y0, y1) => (gg, px) => { gg.fillStyle = '#2e3e48'; for (let x = x0; x < x1; x += 0.7) { const [a, b] = px(x, y1), [c, d] = px(x + 0.4, y0); gg.fillRect(a, b, c - a, d - b); gg.beginPath(); gg.arc((a + c) / 2, b, (c - a) / 2, Math.PI, 0); gg.fill(); } gg.fillStyle = '#b5473a'; { const [a, b] = px(-4, y1 + 0.35), [c, d] = px(3, y1 + 0.2); gg.fillRect(a, b, c - a, d - b); } };
  for (const z of [-1.0, 1.0]) { const m = card(cabinPts, '#f1e9d6', windows(-3.3, 2.4, 2.0, 2.8), { W: 768, H: 200, seed: 313 }); m.position.z = z; hull.add(m); }
  const roof = new THREE.Mesh(new THREE.BoxGeometry(6.8, 0.12, 2.6), paperMaterial({ color: 0x8a5a34 })); roof.position.set(-0.5, 3.25, 0); roof.castShadow = true; hull.add(roof);
  const deck = new THREE.Mesh(new THREE.BoxGeometry(10.2, 0.1, 2.9), paperMaterial({ color: 0x9a7a52 })); deck.position.set(0, 1.68, 0); hull.add(deck);
  const pilot = new THREE.Mesh(new THREE.BoxGeometry(1.4, 1.1, 1.4), paperMaterial({ color: 0xf1e9d6 })); pilot.position.set(1.4, 3.85, 0); pilot.castShadow = true; hull.add(pilot);
  // two tall black stacks with crowned tops, one leaning drunkenly
  for (const [z, lean] of [[-0.45, 0.06], [0.45, 0.22]]) {
    const stack = card([[-0.22, 0], [0.22, 0], [0.22, 3.6], [0.4, 3.8], [0.3, 4.1], [0.15, 3.95], [0, 4.15], [-0.15, 3.95], [-0.3, 4.1], [-0.4, 3.8], [-0.22, 3.6]], '#2b2622', (gg, px) => { gg.fillStyle = '#d9a441'; const [a, b] = px(-0.5, 3.6), [c, d] = px(0.5, 3.45); gg.fillRect(a, b, c - a, d - b); }, { W: 128, H: 512, seed: 317, thick: 0.1 });
    stack.position.set(2.6, 3.2, z); stack.rotation.set(0, Math.PI / 2, lean); hull.add(stack);
  }
  // the paddle wheel at the stern, half its buckets gone
  for (const z of [-1.0, 1.0]) { const w = card(disc(1.6, 20), '#b5473a', wheelArt(1.6, '#6a2a20', 12), { W: 256, H: 256, seed: 319, thick: 0.1 }); w.position.set(-5.9, 1.6, z); hull.add(w); }
  hull.rotation.set(0.07, 0, 0.09); hull.position.y = -0.55; // sunk to her rails, listing
  return { group: g, colliders: [[-4, 0, 1.6], [-1.5, 0, 1.7], [1, 0, 1.7], [3.5, 0, 1.6], [-5.9, 0, 1.2]], radius: 7 };
}

function lookout() {
  const g = new THREE.Group(), H = 9, B = 1.9, T = 1.15;
  const corners = [[-1, -1], [1, -1], [1, 1], [-1, 1]];
  const at = (s, y, [cx, cz]) => [cx * s, y, cz * s];
  const L = [];
  for (const c of corners) L.push([at(B, 0, c), at(T, H, c), 0.24]); // the four legs, leaning in
  for (let i = 0; i < 4; i++) { // cross-bracing on every side, three storeys of X
    const a = corners[i], b = corners[(i + 1) % 4];
    for (let k = 0; k < 3; k++) {
      const y0 = k * 3, y1 = y0 + 3, s0 = B + (T - B) * (y0 / H), s1 = B + (T - B) * (y1 / H);
      L.push([at(s0, y0, a), at(s1, y1, b)], [at(s0, y0, b), at(s1, y1, a)], [at(s1, y1, a), at(s1, y1, b), 0.12]);
    }
  }
  g.add(beams(L, 0x7a5236));
  // the cabin: four printed walls with windows all round, a catwalk, a red pyramid roof and a flag
  const wall = [[-1.3, 0], [1.3, 0], [1.3, 1.8], [-1.3, 1.8]];
  for (let i = 0; i < 4; i++) {
    const m = card(wall, '#c99a5e', (gg, px) => { gg.strokeStyle = 'rgba(90,60,30,0.5)'; gg.lineWidth = 2; for (let y = 0.2; y < 1.8; y += 0.2) { const [a, b] = px(-1.3, y), [c] = px(1.3, y); gg.beginPath(); gg.moveTo(a, b); gg.lineTo(c, b); gg.stroke(); } gg.fillStyle = '#3e5662'; const [a, b] = px(-1.0, 1.55), [c, d] = px(1.0, 0.85); gg.fillRect(a, b, c - a, d - b); gg.strokeStyle = '#efe3c4'; gg.lineWidth = 4; gg.strokeRect(a, b, c - a, d - b); gg.beginPath(); gg.moveTo((a + c) / 2, b); gg.lineTo((a + c) / 2, d); gg.stroke(); }, { W: 256, H: 192, seed: 331 + i });
    m.position.set(Math.sin(i * Math.PI / 2) * 1.3, H, Math.cos(i * Math.PI / 2) * 1.3); m.rotation.y = i * Math.PI / 2; g.add(m);
  }
  const deck = new THREE.Mesh(new THREE.BoxGeometry(3.6, 0.14, 3.6), paperMaterial({ color: 0x9a6a3e })); deck.position.y = H; deck.castShadow = true; g.add(deck);
  g.add(beams([[[-1.8, H + 0.9, -1.8], [1.8, H + 0.9, -1.8]], [[1.8, H + 0.9, -1.8], [1.8, H + 0.9, 1.8]], [[1.8, H + 0.9, 1.8], [-1.8, H + 0.9, 1.8]], [[-1.8, H + 0.9, 1.8], [-1.8, H + 0.9, -1.8]],
    [[-1.8, H, -1.8], [-1.8, H + 0.9, -1.8]], [[1.8, H, -1.8], [1.8, H + 0.9, -1.8]], [[1.8, H, 1.8], [1.8, H + 0.9, 1.8]], [[-1.8, H, 1.8], [-1.8, H + 0.9, 1.8]]], 0x6a4428, 0.09)); // the catwalk rail
  const roof = new THREE.Mesh(new THREE.ConeGeometry(2.1, 1.3, 4, 1).rotateY(Math.PI / 4), paperMaterial({ color: 0xb5473a, flatShading: true })); roof.position.y = H + 1.8 + 0.65; roof.castShadow = true; g.add(roof);
  const pole = beams([[[0, H + 2.4, 0], [0, H + 3.5, 0], 0.06]], 0x5a3a24); g.add(pole);
  const flag = card([[0, 0], [0.7, -0.1], [0.62, -0.25], [0.7, -0.42], [0, -0.38]], '#c4362f', null, { W: 96, H: 64, seed: 337, thick: 0.03 }); flag.position.set(0.03, H + 3.5, 0); g.add(flag);
  // a ladder up one leg, so it reads as climbable
  const lad = []; for (let y = 0.4; y < H; y += 0.45) { const s = B + (T - B) * (y / H) + 0.12; lad.push([[s, y, -0.3], [s, y, 0.3], 0.05]); }
  lad.push([[B + 0.12, 0, -0.3], [T + 0.12, H, -0.3], 0.07], [[B + 0.12, 0, 0.3], [T + 0.12, H, 0.3], 0.07]);
  g.add(beams(lad, 0x8a6038));
  return { group: g, colliders: corners.map(([cx, cz]) => [cx * B, cz * B, 0.6]), radius: 4 };
}

/** An ox skull bleaching in the grass. */
function oxSkull() {
  const skull = card([[-0.22, 0], [0.22, 0], [0.26, 0.28], [0.62, 0.42], [0.66, 0.5], [0.3, 0.42], [0.18, 0.5], [-0.18, 0.5], [-0.3, 0.42], [-0.66, 0.5], [-0.62, 0.42], [-0.26, 0.28]], '#efe6d2', (gg, px) => { gg.fillStyle = '#3a2e24'; for (const sx of [-1, 1]) { const [a, b] = px(sx * 0.1, 0.3); gg.beginPath(); gg.ellipse(a, b, 8, 10, 0, 0, Math.PI * 2); gg.fill(); } }, { W: 192, H: 96, seed: 353, thick: 0.05 });
  skull.position.set(-2.6, 0, 1.6); skull.rotation.set(-0.4, 0.6, 0); return skull;
}

function schooner() {
  const src = propModel('veh_broken_wagon');
  if (src) { // the broken-down schooner from the reference art (the wagon sheet): canvas in tatters on its bows, a wheel off, boards sprung
    const g = new THREE.Group(), m = src.scene.clone(), b = new THREE.Box3().setFromObject(m), sz = b.getSize(new THREE.Vector3()), c = b.getCenter(new THREE.Vector3());
    const hold = new THREE.Group(); m.position.set(-c.x, -b.min.y, -c.z); hold.add(m); hold.scale.setScalar(5.6 / sz.x); g.add(hold);
    g.add(oxSkull());
    return { group: g, colliders: [[-1, 0, 1.4], [1, 0, 1.4]], radius: 4 };
  }
  const g = new THREE.Group(), wagon = new THREE.Group(); g.add(wagon);
  const side = [[-1.8, 0], [1.8, 0], [1.9, 0.75], [-1.9, 0.75]];
  const boards = (gg, px) => { gg.strokeStyle = 'rgba(60,36,20,0.5)'; gg.lineWidth = 2; for (let y = 0.25; y < 0.75; y += 0.25) { const [a, b] = px(-2, y), [c] = px(2, y); gg.beginPath(); gg.moveTo(a, b); gg.lineTo(c, b); gg.stroke(); } gg.fillStyle = 'rgba(70,96,120,0.55)'; { const [a, b] = px(-2, 0.75), [c, d] = px(2, 0.6); gg.fillRect(a, b, c - a, d - b); } };
  for (const z of [-0.75, 0.75]) { const m = card(side, '#9a7448', boards, { W: 384, H: 96, seed: 341 }); m.position.set(0, 0.55, z); wagon.add(m); }
  for (const x of [-1.85, 1.85]) { const m = card([[-0.75, 0], [0.75, 0], [0.75, 0.75], [-0.75, 0.75]], '#8a6440', boards, { W: 128, H: 96, seed: 343 }); m.position.set(x, 0.55, 0); m.rotation.y = Math.PI / 2; wagon.add(m); }
  // the bonnet: a torn canvas hood on bent bows, patched and weathered
  const canvasPts = [[-2, 0], [2, 0], [2, 1], [-2, 1]];
  const canvas = art(canvasPts, '#e8dcc0', (gg, px, rng) => {
    for (let i = 0; i < 5; i++) { const [a, b] = px(-1.8 + rng() * 3.4, rng() * 0.8); gg.fillStyle = i % 2 ? 'rgba(180,150,110,0.45)' : 'rgba(150,120,90,0.35)'; gg.fillRect(a, b, 40 + rng() * 50, 30 + rng() * 30); gg.strokeStyle = 'rgba(90,70,50,0.6)'; gg.setLineDash([4, 4]); gg.strokeRect(a, b, 40, 30); gg.setLineDash([]); }
    gg.strokeStyle = 'rgba(60,40,24,0.7)'; gg.lineWidth = 3; for (let i = 0; i < 4; i++) { const [a, b] = px(-1.8 + rng() * 3.6, rng() * 0.9); gg.beginPath(); gg.moveTo(a, b); gg.lineTo(a + (rng() - 0.5) * 60, b + 20 + rng() * 40); gg.stroke(); } // rents in the canvas
  }, { W: 512, H: 160, seed: 347 });
  const hood = new THREE.Mesh(new THREE.CylinderGeometry(0.95, 0.95, 3.4, 10, 1, true, 0, Math.PI).rotateZ(Math.PI / 2), cardMaterial(canvas));
  hood.material.side = THREE.DoubleSide; hood.position.y = 1.3; hood.scale.set(1, 1.15, 1); hood.castShadow = true; wagon.add(hood);
  wagon.add(beams([-1.5, -0.5, 0.5, 1.5].map((x) => [[x, 1.3, 0.92], [x, 1.3, -0.92], 0.06]), 0x8a6440));
  // wheels: three on their axles, the fourth fallen flat in the grass
  const wheel = (r) => card(disc(r, 18), '#9a7448', wheelArt(r, '#5a3a20', 12), { W: 192, H: 192, seed: 349, thick: 0.08 });
  for (const [x, z, r] of [[1.3, 0.9, 0.55], [-1.3, 0.9, 0.7], [-1.3, -0.9, 0.7]]) { const w = wheel(r); w.position.set(x, r, z); wagon.add(w); }
  const fallen = wheel(0.55); fallen.rotation.x = -Math.PI / 2; fallen.position.set(2.4, 0.05, -1.2); g.add(fallen);
  wagon.rotation.z = 0.12; wagon.position.y = -0.05; // down at the front corner where the wheel came off
  g.add(oxSkull()); // an ox skull bleaching in the grass
  return { group: g, colliders: [[-1, 0, 1.3], [1, 0, 1.3]], radius: 4 };
}

function grandmotherBirch() {
  const g = new THREE.Group(), k = propKinds();
  const tree = new THREE.Mesh(k.birch.geometry, k.birch.material); tree.scale.setScalar(3.4); tree.castShadow = true; tree.receiveShadow = true; g.add(tree);
  for (let i = 0; i < 9; i++) { // a fairy ring of toadstools round her roots
    const a = (i / 9) * Math.PI * 2, m = new THREE.Mesh(k.mushroom.geometry, k.mushroom.material);
    m.position.set(Math.cos(a) * 3.6, 0, Math.sin(a) * 3.6); m.rotation.y = -a; m.scale.setScalar(1.3); m.castShadow = true; g.add(m);
  }
  return { group: g, colliders: [[0, 0, 0.9]], radius: 5 };
}

/** The hermit's lean-to: a slanted bark roof on two poles, a back wall of split boards, a stump and a fire ring. */
function leanTo() {
  const g = new THREE.Group(), src = propModel('bldg_leanto');
  if (src) { // Old Asa's lean-to from the reference art: bark-slab roof, a board back, his bedroll and bucket, his sign over it all
    const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3());
    const k = 3.6 / sz.x, hold = new THREE.Group(); m.position.set(-c.x, -bb.min.y, -c.z); hold.add(m); hold.scale.setScalar(k); hold.position.z = -0.1; g.add(hold);
  } else {
  const roof = card([[-1.75, 0], [1.75, 0], [1.75, 3.2], [-1.75, 3.2]], '#7a5a3e', (gg, px, rng) => {
    gg.strokeStyle = 'rgba(40,26,16,0.55)'; gg.lineWidth = 3; for (let x = -1.5; x < 1.6; x += 0.22) { const [a, b] = px(x, 0), [c, d] = px(x + (rng() - 0.5) * 0.05, 3.2); gg.beginPath(); gg.moveTo(a, b); gg.lineTo(c, d); gg.stroke(); }
    for (let i = 0; i < 16; i++) { const [a, b] = px(-1.5 + rng() * 3, rng() * 3.1); gg.fillStyle = 'rgba(160,180,120,0.55)'; gg.beginPath(); gg.arc(a, b, 4 + rng() * 6, 0, Math.PI * 2); gg.fill(); } // moss
  }, { W: 384, H: 288, seed: 361, thick: 0.08 });
  roof.position.set(0, 0.95, -1.5); roof.rotation.x = Math.atan2(2.85, 1.4); g.add(roof); // from the back wall's top, up to the front poles
  const back = card([[-1.6, 0], [1.6, 0], [1.6, 1.0], [-1.6, 1.0]], '#9a7448', (gg, px) => { gg.strokeStyle = 'rgba(50,30,18,0.5)'; gg.lineWidth = 2; for (let x = -1.4; x < 1.6; x += 0.3) { const [a, b] = px(x, 0), [, d] = px(x, 1); gg.beginPath(); gg.moveTo(a, b); gg.lineTo(a, d); gg.stroke(); } }, { W: 256, H: 96, seed: 363 });
  back.position.set(0, 0, -1.4); g.add(back);
  g.add(beams([[[-1.5, 0, 1.35], [-1.5, 2.35, 1.35], 0.12], [[1.5, 0, 1.35], [1.5, 2.35, 1.35], 0.12], [[-1.6, 2.3, 1.35], [1.6, 2.3, 1.35], 0.1]], 0x6a4428));
  }
  const stump = new THREE.Mesh(new THREE.CylinderGeometry(0.28, 0.32, 0.45, 8), paperMaterial({ color: 0x8a6440, flatShading: true })); stump.position.set(1.4, 0.22, 2.2); stump.castShadow = true; g.add(stump);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.1, 5, 9).rotateX(Math.PI / 2), paperMaterial({ color: 0x8a8278, flatShading: true })); ring.position.set(-0.6, 0.05, 2.6); g.add(ring);
  const ember = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.42, 5).translate(0, 0.21, 0), new THREE.MeshBasicNodeMaterial({ color: 0xff9a48 })); ember.position.set(-0.6, 0.02, 2.6); g.add(ember);
  return { group: g, colliders: [[0, -0.6, 1.6]], radius: 4 };
}

const BUILD = { arch, steamboat, lookout, schooner, birch: grandmotherBirch, hermit: leanTo };
export const LANDMARK_OF = { breaks: 'arch', fen: 'steamboat', pines: 'lookout', prairie: 'schooner', hollows: 'birch' };
// the one-of-a-kind encounters each world places once: [land, mark] (the landmarks, then the legends)
export const UNIQUES = [['breaks', 'arch'], ['fen', 'steamboat'], ['pines', 'lookout'], ['prairie', 'schooner'], ['hollows', 'birch'], ['pines', 'babe'], ['hollows', 'hermit']];
export const LANDMARK_INFO = {
  arch: { name: 'the Redrock Arch', found: 'You stand under the Redrock Arch, a bridge of banded red stone nobody built. Wedged in a crack: a prospector\'s poke.', gift: { silver: 1, iron: 2 } },
  steamboat: { name: 'the Belle of the Fen', found: 'The Belle of the Fen, a sternwheeler sunk to her rails in the marsh. In the purser\'s strongbox:', gift: { pearl: 1, rope: 3, honey: 2 } },
  lookout: { name: 'the fire lookout', found: 'You climb the fire lookout. From the cabin you can see for miles: the county map fills in all round. Someone left a lump of amber on the sill.', gift: { amber: 1 }, reveal: 150 },
  schooner: { name: 'the lost schooner', found: 'A prairie schooner, broken down and abandoned long ago. Under the seat, wrapped in an oilcloth:', gift: { geode: 1, leather: 2, pelt: 1 } },
  babe: { name: 'Babe the Blue Ox', found: 'Babe the Blue Ox, Paul Bunyan\'s own, big as a barn and blue as a winter sky! She snuffles at your pack. She\'d dearly love some apples.', needs: { apples: 3 },
    thanks: 'Babe crunches your apples, one, two, three, and leans her great blue head against you. Paul Bunyan\'s blessing goes with you now: every tree you fell gives an extra stick of wood.', gift: {}, blessing: true },
  hermit: { name: 'the Hermit of the Hollows', found: 'Old Asa, the Hermit of the Hollows, looks up from his fire. "Company! Sit, sit." He talks for an hour, and by the end he has inked every strange place in the county onto your map: the arch, the wreck, the lookout, the lost wagon, the old birch, and where the blue ox grazes. He sends you off with a comb of honey.', gift: { honey: 1 }, mapAll: true },
  birch: { name: 'the Grandmother Birch', found: 'The Grandmother Birch, older than the county, in her ring of toadstools. You rest a while in her shade and feel wholly mended. Tucked among her roots:', gift: { sang: 2, honey: 1 }, mend: true },
};

// what you can climb on each landmark (see climb.js): decks to walk, ladders (or scrambles) to get up there
const archTop = (lx) => 4.2 + 2.3 * Math.sqrt(Math.max(0, 1 - (lx / 4.6) ** 2)); // the middle flat's crest
const boatDeck = (lx) => 1.18 + 0.09 * lx, boatRoof = (lx) => 2.76 + 0.09 * lx; // sunk 0.55, listing 0.09 bow-up
export const CLIMB = {
  lookout: { decks: [{ x: 0, z: 0, hw: 1.75, hd: 1.75, y: 9.07, rail: true }],
    ladders: [{ foot: [2.6, 0, 0], top: [1.35, 9.07, 0], land: [1.55, 0], name: 'the fire lookout' }] },
  arch: { decks: [{ x: 0, z: 0, hw: 4.3, hd: 0.8, y: 0, yAt: archTop }],
    ladders: [{ foot: [-5.4, 0, 0], top: [-4.1, archTop(-4.1), 0], land: [-3.8, 0], name: 'the stone arch' }] },
  steamboat: { decks: [{ x: 0, z: 0, hw: 5, hd: 1.35, y: 0, yAt: boatDeck, rail: true }, { x: -0.5, z: 0, hw: 3.3, hd: 1.2, y: 0, yAt: boatRoof, rail: true }],
    ladders: [{ foot: [3.4, 0, 2.6], top: [3.4, boatDeck(3.4), 1.4], land: [3.4, 0.5], name: 'the wreck of the Belle' },
      { foot: [3.3, boatDeck(3.3), -0.9], top: [2.75, boatRoof(2.75), -0.9], land: [2.4, -1.0], name: "the Belle's hurricane deck" }] },
};

/** Builds and shows landmarks as their chunks load (one shared model per kind, cloned per placement). */
export class Landmarks {
  constructor(scene) { this.scene = scene; this.models = {}; this.live = new Map(); this.found = new Set(); this.blessed = false; this.hintAt = new Map(); }
  model(kind) { return (this.models[kind] ||= BUILD[kind]()); }
  spawn(site) {
    if (site.mark === 'hermit') { // the lean-to, and old Asa himself standing by his fire
      const g = this.model('hermit').group.clone(); g.position.set(site.x, site.y, site.z); g.rotation.y = site.rot;
      const fig = hasFolk('folk_asa') ? new ModelFigure('folk_asa') : new Figure({ coat: 0x6a5a48, coatPat: 3, pants: 0x4a4038, longcoat: true, beard: 0xe8e2d6, hair: 0xe8e2d6, hat: 'cap', hatColor: 0x5a4a38, hold: 'staff', stern: false });
      fig.root.position.set(0.9, 0, 1.9); fig.root.rotation.y = 0.4; g.add(fig.root);
      this.scene.add(g); this.live.set(site.key, { site, group: g, figure: fig });
      return;
    }
    if (site.mark === 'babe') { // a living legend, not a model: a big paper puppet grazing on her own
      const pup = new Puppet('ox', 2.3); pup.group.position.set(site.x, site.y, site.z);
      this.scene.add(pup.group); this.live.set(site.key, { site, group: pup.group, puppet: pup });
      return;
    }
    const g = this.model(site.mark).group.clone();
    g.position.set(site.x, site.y, site.z); g.rotation.y = site.rot;
    this.scene.add(g); this.live.set(site.key, { site, group: g });
    if (CLIMB[site.mark]) this.climbs?.add(site.key, site.x, site.y, site.z, site.rot, CLIMB[site.mark]);
  }
  despawn(site) { const l = this.live.get(site.key); if (l) { this.scene.remove(l.group); this.live.delete(site.key); } this.climbs?.remove(site.key); }
  /** Babe grazes, swishes her tail and turns her head to watch you. */
  update(dt, camera) {
    for (const l of this.live.values()) if (l.figure) l.figure.update(dt, 0);
    for (const l of this.live.values()) if (l.puppet) {
      const p = l.group.position, yaw = Math.atan2(camera.position.x - p.x, camera.position.z - p.z);
      l.puppet.update(dt, 0, 'idle', false, yaw, 0);
    }
  }
  /**
   * The landmark you've just reached for the first time, if any (then it's remembered). Babe wants apples first:
   * without them she's only met (a hint, now and then), and the encounter waits for you to come back.
   */
  reached(pos, inv, r = 7.5) {
    for (const { site } of this.live.values()) {
      if (this.found.has(site.key)) continue;
      const rad = site.mark === 'babe' ? 4 : this.model(site.mark).radius * 0.5;
      if (Math.hypot(pos.x - site.x, pos.z - site.z) >= r + rad) continue;
      if (site.mark === 'lookout' && pos.y < site.y + 8) continue; // the lookout's view is only had from the top
      const needs = LANDMARK_INFO[site.mark].needs;
      if (needs && !Object.entries(needs).every(([k, n]) => (inv[k] || 0) >= n)) {
        const t = performance.now(); if (t - (this.hintAt.get(site.key) || -1e9) < 60000) continue;
        this.hintAt.set(site.key, t); return { site, hint: true };
      }
      this.found.add(site.key); return { site };
    }
    return null;
  }
  save() { return { found: [...this.found], blessed: this.blessed }; }
  load(d) { const list = Array.isArray(d) ? d : d?.found; for (const k of list || []) this.found.add(k); this.blessed = !!d?.blessed; }
}
/** Collider circles (x, z, r) of a landmark kind at a placement. */
export function landmarkColliders(mark, x, z, rot) {
  const spec = { hermit: [[0, -0.6, 1.6]], babe: [[0, 0, 1.6]], arch: [[-3.6, 0, 1.3], [3.6, 0, 1.3]], steamboat: [[-4, 0, 1.6], [-1.5, 0, 1.7], [1, 0, 1.7], [3.5, 0, 1.6], [-5.9, 0, 1.2]], lookout: [[-1.9, -1.9, 0.6], [1.9, -1.9, 0.6], [1.9, 1.9, 0.6], [-1.9, 1.9, 0.6]], schooner: [[-1, 0, 1.3], [1, 0, 1.3]], birch: [[0, 0, 0.9]] }[mark];
  const c = Math.cos(rot), s = Math.sin(rot);
  return spec.map(([lx, lz, r]) => ({ x: x + lx * c + lz * s, z: z - lx * s + lz * c, r }));
}
