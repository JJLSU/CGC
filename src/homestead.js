// A cozy vintage-Americana homestead built as a paper model: clapboard farmhouse with a porch and
// chimney smoke, a red gambrel barn (fieldstone footing, shake roof, cupola, hay hood, sliding doors, a barn quilt), a windmill, picket fence, hay bales, pumpkins and lantern posts
// that glow (with real point lights) after dusk.
import * as THREE from 'three/webgpu';
import { uniform, vec3, float, texture, uv, mix, step, positionWorld } from 'three/tsl';
// the barn's cutaway: above this height (world y) the barn model isn't drawn, so you can see in while you're inside it
const uBarnCut = uniform(1e4);
import { getHeight, setGarden } from './world.js';
import { paperMaterial, cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { panelArt, paintCard, soilSilhouette, soilArt } from './textures.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { mulberry32 } from './noise.js';
import { propModel } from './modelfolk.js';

const glowU = uniform(0); // 0 day … 1 night: window & lantern glow

// shared materials (one per texture / colour), so baking can merge everything that looks the same
const _cardMats = new Map(), _paperMats = new Map();
function cardMat(map) {
  if (!_cardMats.has(map)) _cardMats.set(map, cardMaterial(map));
  return _cardMats.get(map);
}
function paperMat(hex, params = {}) {
  const key = `${hex}|${params.side ?? ''}`;
  if (!_paperMats.has(key)) _paperMats.set(key, paperMaterial({ color: hex, ...params }));
  return _paperMats.get(key);
}

function shadowed(m) { m.castShadow = true; m.receiveShadow = true; return m; }

function texturedBox(w, h, d, map, color = 0xffffff) {
  const m = color === 0xffffff ? cardMat(map) : cardMaterial(map);
  if (color !== 0xffffff) m.colorNode = m.colorNode.mul(vec3(new THREE.Color(color)));
  return shadowed(new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m));
}

function solidBox(w, h, d, hex) {
  return shadowed(new THREE.Mesh(new THREE.BoxGeometry(w, h, d), paperMat(hex)));
}

/** Warm window: cream frame + pane that glows at night. */
let windowMat = null;
function windowMesh(w, h) {
  if (!windowMat) {
    const art = panelArt(128, 160, '#3f4d5a', ['rgba(80,100,120,A)', 'rgba(50,60,80,A)'], (g, W, H) => {
      g.strokeStyle = '#efe5cc'; g.lineWidth = 14; g.strokeRect(7, 7, W - 14, H - 14);
      g.lineWidth = 8; g.beginPath(); g.moveTo(W / 2, 0); g.lineTo(W / 2, H); g.moveTo(0, H / 2); g.lineTo(W, H / 2); g.stroke();
    }, 31);
    windowMat = cardMaterial(art);
    const tex = texture(art, uv());
    // panes (darker texels) glow amber at night; the frame stays paper
    const pane = float(1).sub(tex.r.mul(1.4)).clamp(0, 1);
    windowMat.emissiveNode = vec3(1.0, 0.62, 0.28).mul(pane).mul(glowU).mul(3.2);
  }
  return new THREE.Mesh(new THREE.BoxGeometry(w, h, 0.08), windowMat);
}

const ART = {};
function art() {
  if (ART.clap) return ART;
  ART.clap = panelArt(512, 384, '#efe6d2', ['rgba(240,232,214,A)', 'rgba(220,210,190,A)', 'rgba(250,240,220,A)'], (g, W, H) => {
    g.strokeStyle = 'rgba(120,100,80,0.45)'; g.lineWidth = 2.5;
    for (let y = 20; y < H; y += 26) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); }
  }, 41);
  ART.shingle = panelArt(512, 384, '#7e3b32', ['rgba(140,60,48,A)', 'rgba(110,48,40,A)', 'rgba(160,80,60,A)'], (g, W, H, rng) => {
    g.strokeStyle = 'rgba(60,25,20,0.6)'; g.lineWidth = 2.5;
    for (let row = 0, y = 12; y < H + 20; y += 22, row++) {
      for (let x = (row % 2) * 16; x < W + 32; x += 32) {
        g.beginPath(); g.arc(x, y, 16, 0, Math.PI); g.stroke();
      }
    }
  }, 42);
  ART.barn = panelArt(512, 384, '#a63c2e', ['rgba(170,60,44,A)', 'rgba(140,46,36,A)', 'rgba(190,84,60,A)'], (g, W, H) => {
    g.strokeStyle = 'rgba(70,24,18,0.5)'; g.lineWidth = 2.5;
    for (let x = 18; x < W; x += 30) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, H); g.stroke(); }
  }, 43);
  ART.barnDoor = panelArt(256, 320, '#a63c2e', ['rgba(170,60,44,A)', 'rgba(140,46,36,A)'], (g, W, H) => {
    g.strokeStyle = '#efe5cc'; g.lineWidth = 16;
    g.strokeRect(10, 10, W - 20, H - 20);
    g.beginPath(); g.moveTo(10, 10); g.lineTo(W - 10, H - 10); g.moveTo(W - 10, 10); g.lineTo(10, H - 10); g.stroke();
  }, 44);
  // weathered cedar shakes: rows run along the barn, staggered butt joints, a few darker shakes
  ART.shakes = panelArt(512, 384, '#6a5a50', ['rgba(120,104,92,A)', 'rgba(90,76,68,A)', 'rgba(140,124,108,A)'], (g, W, H, rng) => {
    for (let x = 0, row = 0; x < W; x += 48, row++) {
      g.fillStyle = 'rgba(40,30,26,0.35)'; g.fillRect(x, 0, 6, H); // each row's shadowed butt edge
      g.fillStyle = 'rgba(200,184,160,0.35)'; g.fillRect(x + 6, 0, 2, H); // its lit lip
      for (let y = (row % 2) * 22; y < H; y += 30 + rng() * 22) {
        g.fillStyle = 'rgba(40,30,26,0.45)'; g.fillRect(x + 6, y, 40, 3);
        if (rng() < 0.18) { g.fillStyle = 'rgba(60,46,40,0.35)'; g.fillRect(x + 8, y + 3, 38, 26); }
      }
    }
  }, 47);
  // a fieldstone footing: rounded grey-buff stones with dark mortar between
  ART.stone = panelArt(512, 128, '#5d544c', ['rgba(90,82,74,A)'], (g, W, H, rng) => {
    for (let y = 10; y < H; y += 38) for (let x = (y % 76 ? 0 : 20) + rng() * 8; x < W; x += 34 + rng() * 18) {
      const w = 26 + rng() * 16, h = 26 + rng() * 6, c = 150 + rng() * 40;
      g.fillStyle = 'rgb(' + c + ',' + (c * 0.95) + ',' + (c * 0.86) + ')'; g.beginPath(); g.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = 'rgba(255,248,230,0.35)'; g.beginPath(); g.ellipse(x + w / 2 - 3, y + h / 2 - 5, w / 3, h / 5, 0, 0, Math.PI * 2); g.fill();
    }
  }, 48);
  // a painted barn quilt: an eight-point star of barn red and mustard on cream, in a teal border
  ART.quilt = panelArt(256, 256, '#efe3c4', ['rgba(246,236,210,A)'], (g, W, H) => {
    g.fillStyle = '#3f6a6a'; g.fillRect(0, 0, W, H);
    g.fillStyle = '#efe3c4'; g.fillRect(22, 22, W - 44, H - 44);
    const cx = W / 2, cy = H / 2, R = 96, r = 40;
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2, b = a + Math.PI / 8, c = a - Math.PI / 8;
      g.fillStyle = i % 2 ? '#d9a441' : '#b5473a';
      g.beginPath(); g.moveTo(cx, cy); g.lineTo(cx + Math.cos(c) * r, cy + Math.sin(c) * r); g.lineTo(cx + Math.cos(a) * R, cy + Math.sin(a) * R); g.lineTo(cx + Math.cos(b) * r, cy + Math.sin(b) * r); g.closePath(); g.fill();
      g.strokeStyle = 'rgba(60,30,20,0.55)'; g.lineWidth = 2.5; g.stroke();
    }
    g.fillStyle = '#3f6a6a'; g.beginPath(); g.arc(cx, cy, 13, 0, Math.PI * 2); g.fill();
    g.strokeStyle = 'rgba(40,30,20,0.6)'; g.lineWidth = 4; g.strokeRect(22, 22, W - 44, H - 44);
  }, 49);
  ART.louver = panelArt(128, 128, '#efe5cc', ['rgba(240,230,206,A)'], (g, W, H) => {
    g.fillStyle = '#a63c2e'; g.fillRect(0, 0, W, H);
    g.fillStyle = '#efe5cc'; g.fillRect(14, 14, W - 28, H - 28);
    for (let y = 22; y < H - 18; y += 14) { g.fillStyle = 'rgba(60,40,30,0.55)'; g.fillRect(18, y + 7, W - 36, 5); }
  }, 50);
  ART.brick = panelArt(256, 256, '#8e4434', ['rgba(150,70,52,A)', 'rgba(120,56,44,A)'], (g, W, H, rng) => {
    for (let y = 0, row = 0; y < H; y += 22, row++) for (let x = (row % 2) * -24; x < W; x += 48) {
      const c = 0.85 + rng() * 0.3; g.fillStyle = 'rgba(' + Math.round(170 * c) + ',' + Math.round(80 * c) + ',' + Math.round(60 * c) + ',1)';
      g.fillRect(x + 3, y + 3, 42, 16);
    }
  }, 51);
  ART.shutter = panelArt(64, 160, '#4f6d55', ['rgba(80,110,86,A)', 'rgba(64,92,70,A)'], (g, W, H) => {
    g.strokeStyle = 'rgba(30,44,32,0.6)'; g.lineWidth = 4; g.strokeRect(5, 5, W - 10, H - 10);
    for (let y = 16; y < H - 12; y += 11) { g.fillStyle = 'rgba(30,44,32,0.45)'; g.fillRect(10, y, W - 20, 4); g.fillStyle = 'rgba(190,210,180,0.35)'; g.fillRect(10, y + 4, W - 20, 2); }
    g.fillStyle = '#efe5cc'; g.beginPath(); g.moveTo(W / 2, H * 0.12); g.lineTo(W / 2 + 7, H * 0.17); g.lineTo(W / 2, H * 0.22); g.lineTo(W / 2 - 7, H * 0.17); g.fill(); // a little cut-out diamond
  }, 52);
  ART.geranium = panelArt(256, 96, '#5d7f45', ['rgba(100,140,72,A)', 'rgba(80,116,60,A)'], (g, W, H, rng) => {
    for (let i = 0; i < 9; i++) { const x = 18 + i * 28 + rng() * 6, y = 26 + rng() * 14;
      g.fillStyle = '#c4362f'; for (let k = 0; k < 5; k++) { g.beginPath(); g.arc(x + Math.cos(k * 1.26) * 7, y + Math.sin(k * 1.26) * 7, 6, 0, Math.PI * 2); g.fill(); }
      g.fillStyle = '#f2c24a'; g.beginPath(); g.arc(x, y, 3.5, 0, Math.PI * 2); g.fill(); }
  }, 53);
  // the windmill's tail vane: barn red with a cream border, a cream star and the farm's name lettered on
  ART.tail = panelArt(256, 160, '#a63c2e', ['rgba(170,60,44,A)', 'rgba(140,46,36,A)'], (g, W, H) => {
    g.strokeStyle = '#efe5cc'; g.lineWidth = 10; g.strokeRect(10, 10, W - 20, H - 20);
    g.fillStyle = '#efe5cc'; g.beginPath();
    for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + (i / 10) * Math.PI * 2, r = i % 2 ? 14 : 32; g.lineTo(56 + Math.cos(a) * r, H / 2 + Math.sin(a) * r); }
    g.closePath(); g.fill();
    g.font = 'bold 34px Georgia, serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('PELL', 168, H / 2 - 18);
    g.font = 'bold 22px Georgia, serif'; g.fillText('& SONS', 168, H / 2 + 20);
  }, 54);
  // a windmill blade: cream sheet with a barn-red tip band and a pinstripe
  ART.blade = panelArt(256, 64, '#efe5cc', ['rgba(244,236,214,A)', 'rgba(226,216,192,A)'], (g, W, H) => {
    g.fillStyle = '#b5473a'; g.fillRect(W * 0.74, 0, W * 0.26, H);
    g.fillStyle = 'rgba(90,40,30,0.6)'; g.fillRect(W * 0.7, 0, 5, H);
  }, 55);
  ART.door = panelArt(128, 256, '#4f6d6a', ['rgba(70,110,104,A)', 'rgba(60,90,90,A)'], (g, W, H) => {
    g.strokeStyle = 'rgba(30,40,40,0.6)'; g.lineWidth = 4;
    g.strokeRect(18, 18, W - 36, H * 0.4); g.strokeRect(18, H * 0.52, W - 36, H * 0.4);
    g.fillStyle = '#d8b24a'; g.beginPath(); g.arc(W - 26, H * 0.52, 6, 0, Math.PI * 2); g.fill();
  }, 45);
  ART.hay = panelArt(256, 256, '#d9b45a', ['rgba(230,190,100,A)', 'rgba(200,160,70,A)'], (g, W, H, rng) => {
    g.strokeStyle = 'rgba(150,110,40,0.5)'; g.lineWidth = 1.5;
    for (let i = 0; i < 160; i++) { const x = rng() * W, y = rng() * H; g.beginPath(); g.moveTo(x, y); g.lineTo(x + (rng() - 0.5) * 30, y + (rng() - 0.5) * 8); g.stroke(); }
  }, 46);
  return ART;
}

/** Gable roof: two shingled planes meeting at a ridge, plus clapboard gable-end triangles. */
function gableRoof(w, d, rise, overhang = 0.35) {
  const g = new THREE.Group();
  const half = w / 2 + overhang;
  const slope = Math.hypot(half, rise);
  const ang = Math.atan2(rise, half);
  for (const s of [-1, 1]) {
    const p = texturedBox(slope, 0.12, d + overhang * 2, art().shingle);
    p.position.set((s * half) / 2, rise / 2, 0);
    p.rotation.z = -s * ang;
    g.add(p);
  }
  const tri = cardGeometry([[-w / 2, 0], [w / 2, 0], [0, rise]], d - 0.02);
  const ends = shadowed(new THREE.Mesh(tri, cardMat(art().clap)));
  g.add(ends);
  return g;
}

function picketFence(points, rng) {
  const g = new THREE.Group();
  const pick = cardGeometry([[-0.07, 0], [0.07, 0], [0.07, 0.75], [0, 0.88], [-0.07, 0.75]], 0.04);
  const mat = paperMat(0xf1e8d4);
  for (let i = 0; i < points.length - 1; i++) {
    const [ax, az] = points[i], [bx, bz] = points[i + 1];
    const len = Math.hypot(bx - ax, bz - az), n = Math.floor(len / 0.32);
    const ang = Math.atan2(bz - az, bx - ax);
    const rails = solidBox(len, 0.07, 0.04, 0xe9dfca);
    for (const ry of [0.25, 0.6]) {
      const r = rails.clone();
      r.position.set((ax + bx) / 2, getHeight((ax + bx) / 2, (az + bz) / 2) + ry, (az + bz) / 2);
      r.rotation.y = -ang;
      g.add(r);
    }
    for (let k = 0; k <= n; k++) {
      const t = k / n, x = ax + (bx - ax) * t, z = az + (bz - az) * t;
      const p = shadowed(new THREE.Mesh(pick, mat));
      p.position.set(x, getHeight(x, z) - 0.05, z);
      p.rotation.y = -ang;
      p.rotation.z = (rng() - 0.5) * 0.06;
      g.add(p);
    }
  }
  return g;
}

export class Homestead {
  constructor(scene, world, center) {
    this.scene = scene;
    this.root = new THREE.Group();
    scene.add(this.root);
    this.lights = [];
    this.smoke = [];
    const rng = mulberry32(1776);
    const C = center;
    this.roofs = []; // covered footprints (local x half-width, local z range), for keeping the rain off
    const base = (x, z, r) => {
      let lo = Infinity;
      for (let k = -r; k <= r; k += r) for (let l = -r; l <= r; l += r) lo = Math.min(lo, getHeight(x + k, z + l));
      return lo - 0.15;
    };

    // keep props off the buildings and the yard only (the rest of the farm stays densely planted)
    world.exclusions.push(
      { x: C.x + 5, z: C.z - 6, r: 6 }, { x: C.x - 10, z: C.z - 7, r: 7 }, { x: C.x + 13, z: C.z + 5, r: 5 },
      { x: C.x + 1, z: C.z + 5, r: 7 }, { x: C.x - 6, z: C.z - 3, r: 4 }, { x: C.x + 2, z: C.z + 6.5, r: 3 },
    );

    // ---------------------------------------------------- kitchen garden (west of the yard)
    {
      const gx = C.x - 9.5, gz0 = C.z + 1.6, W = 7, D = 6;
      const rows = [{ z: 0.9, type: 'corn' }, { z: 2.3, type: 'corn' }, { z: 3.7, type: 'pumpkin' }, { z: 5.0, type: 'pumpkin' }];
      world.exclusions.push({ x: gx, z: gz0 + D / 2, r: 4.6 });
      setGarden({ x0: gx - W / 2 + 0.6, x1: gx + W / 2 - 0.6, rows: rows.map((r) => ({ z: gz0 + r.z, type: r.type })) });
      const pts = soilSilhouette(W, D);
      const bed = shadowed(new THREE.Mesh(cardGeometry(pts, 0.05), cardMaterial(soilArt(pts, rows.map((r) => D - r.z), D))));
      bed.rotation.x = -Math.PI / 2; // lay the sheet flat, printed face up (its local y runs north)
      bed.position.set(gx, getHeight(gx, gz0 + D / 2) + 0.04, gz0 + D);
      bed.castShadow = false;
      this.root.add(bed);
    }

    // ---------------------------------------------------- farmhouse
    {
      const x = C.x + 5, z = C.z - 6, y = base(x, z, 3);
      const house = new THREE.Group();
      house.position.set(x, y, z);
      house.rotation.y = 0.15;
      this.roofs.push({ x, z, rot: 0.15, hw: 2.9, z0: -2.4, z1: 4.0 }); // the house and its porch
      const W = 5.2, D = 4.2, H = 3.0;
      const body = texturedBox(W, H, D, art().clap);
      body.position.y = H / 2 + 0.3;
      house.add(body);
      const plinth = texturedBox(W + 0.3, 0.4, D + 0.3, art().stone); plinth.position.y = 0.2; house.add(plinth);
      const roof = gableRoof(D, W, 1.7);
      roof.rotation.y = Math.PI / 2;
      roof.position.y = H + 0.3;
      house.add(roof);
      // chimney
      const chim = texturedBox(0.6, 2.2, 0.6, art().brick); chim.position.set(1.4, H + 1.6, -1.0); house.add(chim);
      const chimCap = solidBox(0.78, 0.12, 0.78, 0x6e5a4c); chimCap.position.set(1.4, H + 2.72, -1.0); house.add(chimCap);
      this.chimneyTop = new THREE.Object3D(); this.chimneyTop.position.set(1.4, H + 2.8, -1.0); house.add(this.chimneyTop);
      // front (+z) door, windows, porch
      const door = texturedBox(0.95, 1.9, 0.1, art().door); door.position.set(0, 1.25, D / 2 + 0.02); house.add(door);
      for (const wx of [-1.6, 1.6]) {
        const win = windowMesh(0.9, 1.1); win.position.set(wx, 1.9, D / 2 + 0.03); house.add(win);
      }
      // anchors for Grandma's silhouette in the left front window, and the front door (grandma.js)
      this.frontWindow = new THREE.Object3D(); this.frontWindow.position.set(-1.6, 1.35, D / 2 + 0.085); house.add(this.frontWindow);
      this.frontDoor = new THREE.Object3D(); this.frontDoor.position.set(0, 0.4, D / 2 + 0.5); house.add(this.frontDoor);
      for (const wz of [-0.9, 0.9]) {
        const win = windowMesh(0.9, 1.1); win.position.set(W / 2 + 0.03, 1.9, wz); win.rotation.y = Math.PI / 2; house.add(win);
        const win2 = win.clone(); win2.position.x = -W / 2 - 0.03; house.add(win2);
      }
      const porch = solidBox(W + 0.4, 0.18, 1.6, 0xb08a5a); porch.position.set(0, 0.35, D / 2 + 0.8); house.add(porch);
      const awning = texturedBox(W + 0.6, 0.1, 1.9, art().shingle); awning.position.set(0, 2.75, D / 2 + 0.85); awning.rotation.x = 0.22; house.add(awning);
      for (const px of [-W / 2, -0.9, 0.9, W / 2]) {
        const post = solidBox(0.14, 2.3, 0.14, 0xf1e8d4); post.position.set(px, 1.5, D / 2 + 1.5); house.add(post);
      }
      // ---- the folk-Victorian dressing, all cut from card: the gingerbread in sage, so it reads against the cream clapboard
      const TRIM = 0x6f8f62;
      for (const sx of [-1, 1]) for (const sz of [-1, 1]) { const c = solidBox(0.16, H, 0.16, TRIM); c.position.set(sx * (W / 2 + 0.01), H / 2 + 0.3, sz * (D / 2 + 0.01)); house.add(c); }
      // gingerbread bargeboards: a scalloped cream band under each rake of the gable ends, and a round attic window
      {
        const half = D / 2 + 0.35, rise = 1.7, pts = [[-half, -0.02], [0, rise - 0.02], [half, -0.02]];
        const lower = [];
        for (const sgn of [1, -1]) {
          for (let i = 0; i <= 12; i++) {
            const t = sgn > 0 ? i / 12 : 1 - i / 12, zz = sgn * half * (1 - t), yy = rise * t - 0.02;
            lower.push([zz, yy - (i % 2 ? 0.34 : 0.2)]);
          }
        }
        pts.push(...lower.filter((q, i, arr) => i === 0 || q[0] !== arr[i - 1][0]));
        const geo = cardGeometry(pts, 0.05);
        for (const sx of [-1, 1]) {
          const b = shadowed(new THREE.Mesh(geo, paperMat(TRIM))); b.rotation.y = Math.PI / 2; b.position.set(sx * (W / 2 + 0.33), H + 0.3, 0); house.add(b);
          const oc = windowMesh(0.55, 0.55); oc.rotation.y = Math.PI / 2; oc.position.set(sx * (W / 2 + 0.03), H + 0.95, 0); house.add(oc);
        }
      }
      // the front windows: sage shutters with a cut-out diamond, a cream cap, and a box of red geraniums
      for (const wx of [-1.6, 1.6]) {
        for (const sx of [-1, 1]) { const sh = texturedBox(0.38, 1.15, 0.06, art().shutter); sh.position.set(wx + sx * 0.68, 1.9, D / 2 + 0.06); house.add(sh); }
        const capW = solidBox(1.2, 0.12, 0.16, TRIM); capW.position.set(wx, 2.52, D / 2 + 0.08); house.add(capW);
        const box = solidBox(1.0, 0.22, 0.26, 0x8a4a34); box.position.set(wx, 1.24, D / 2 + 0.16); house.add(box);
        const gp = cardGeometry([[-0.48, 0], [0.48, 0], [0.46, 0.14], [0.36, 0.2], [0.24, 0.13], [0.12, 0.22], [0, 0.14], [-0.12, 0.23], [-0.24, 0.13], [-0.36, 0.21], [-0.46, 0.13]], 0.16);
        const ger = shadowed(new THREE.Mesh(gp, cardMat(art().geranium))); ger.position.set(wx, 1.33, D / 2 + 0.16); house.add(ger);
      }
      // the porch: a baluster railing either side of the steps, scrolled brackets under the porch roof, two steps down
      {
        const pz = D / 2 + 1.5;
        for (const [x0, x1] of [[-W / 2, -0.75], [0.75, W / 2]]) {
          for (const ry of [0.62, 1.22]) { const r = solidBox(x1 - x0, 0.08, 0.08, TRIM); r.position.set((x0 + x1) / 2, ry, pz); house.add(r); }
          for (let bx = x0 + 0.17; bx < x1 - 0.08; bx += 0.19) { const b = solidBox(0.05, 0.6, 0.05, TRIM); b.position.set(bx, 0.92, pz); house.add(b); }
        }
        const brk = cardGeometry([[0, 0], [0.42, 0], [0.36, -0.06], [0.2, -0.1], [0.1, -0.2], [0.06, -0.34], [0, -0.42]], 0.05);
        for (const px of [-W / 2, -0.9, 0.9, W / 2]) for (const sx of [-1, 1]) {
          if ((px === -W / 2 && sx < 0) || (px === W / 2 && sx > 0)) continue;
          const b = shadowed(new THREE.Mesh(brk, paperMat(TRIM))); b.position.set(px + sx * 0.07, 2.58, pz); b.scale.x = sx; house.add(b);
        }
        for (const [sy, sz] of [[0.27, 0.22], [0.12, 0.6]]) { const st = solidBox(1.5, 0.14, 0.4, 0xa07a4c); st.position.set(0, sy, pz + 0.1 + sz); house.add(st); }
      }
      const warm = new THREE.PointLight(0xffb070, 0, 12, 1); warm.position.set(0, 2, D / 2 + 1.4); house.add(warm);
      this.lights.push({ light: warm, max: 5 });
      this.root.add(house);
      world.colliders.push({ x, z, r: 3.4 });
      this.house = house; this.houseW = (W + 0.6) * 1.18; /* (the model house a size up from the paper one) */ this.houseFront = D / 2 + 1.6; // (for the models from the reference art: setFortune)
    }

    // ---------------------------------------------------- red barn (gambrel)
    {
      const x = C.x - 10, z = C.z - 7, y = base(x, z, 4);
      const barn = new THREE.Group();
      barn.position.set(x, y, z);
      barn.rotation.y = -0.25;
      this.roofs.push({ x, z, rot: -0.25, hw: 3.4, z0: -4.4, z1: 4.4 });
      const W = 6, D = 8, H = 3.2;
      const body = texturedBox(W, H, D, art().barn); body.position.y = H / 2; barn.add(body);
      // gambrel profile
      const prof = [[-W / 2, 0], [W / 2, 0], [W / 2 - 0.5, 1.4], [0, 2.6], [-W / 2 + 0.5, 1.4]];
      const gam = shadowed(new THREE.Mesh(cardGeometry(prof, D), cardMat(art().barn)));
      gam.position.y = H; barn.add(gam);
      // roof planes over the gambrel
      const seg = (ax, ay, bx, by) => {
        const len = Math.hypot(bx - ax, by - ay) + 0.15;
        const p = texturedBox(len, 0.12, D + 0.6, art().shakes);
        p.position.set((ax + bx) / 2, H + (ay + by) / 2 + 0.06, 0);
        p.rotation.z = Math.atan2(by - ay, bx - ax);
        barn.add(p);
      };
      seg(-W / 2 - 0.25, -0.1, -W / 2 + 0.5, 1.4); seg(-W / 2 + 0.5, 1.4, 0, 2.6);
      seg(0, 2.6, W / 2 - 0.5, 1.4); seg(W / 2 - 0.5, 1.4, W / 2 + 0.25, -0.1);
      // a fieldstone footing the barn sits on
      const footing = texturedBox(W + 0.16, 0.42, D + 0.16, art().stone); footing.position.y = 0.16; barn.add(footing);
      // cream corner boards, and trim boards following the gambrel on both gable ends
      const TRIM = 0xefe5cc;
      for (const sx of [-1, 1]) for (const sz of [-1, 1]) { const c = solidBox(0.18, H, 0.18, TRIM); c.position.set(sx * (W / 2 + 0.01), H / 2 + 0.15, sz * (D / 2 + 0.01)); barn.add(c); }
      const trimSeg = (ax, ay, bx, by, zf) => {
        const t = solidBox(Math.hypot(bx - ax, by - ay) + 0.12, 0.16, 0.06, TRIM);
        t.position.set((ax + bx) / 2, H + (ay + by) / 2 - 0.08, zf); t.rotation.z = Math.atan2(by - ay, bx - ax); barn.add(t);
      };
      for (const zf of [D / 2 + 0.05, -D / 2 - 0.05]) {
        trimSeg(-W / 2, 0, -W / 2 + 0.5, 1.4, zf); trimSeg(-W / 2 + 0.5, 1.4, 0, 2.6, zf); trimSeg(0, 2.6, W / 2 - 0.5, 1.4, zf); trimSeg(W / 2 - 0.5, 1.4, W / 2, 0, zf);
        const band = solidBox(W, 0.16, 0.06, TRIM); band.position.set(0, H - 0.02, zf); barn.add(band);
      }
      // a ridge cap of folded shakes
      const cap = texturedBox(0.34, 0.16, D + 0.7, art().shakes); cap.position.set(0, H + 2.6 + 0.16, 0); barn.add(cap);
      // twin sliding doors on an iron track: the left one slid half open on the dark of the threshing floor
      const dark = solidBox(2.7, 2.6, 0.06, 0x2e2420); dark.position.set(0, 1.45, D / 2 + 0.01); barn.add(dark);
      const track = solidBox(3.9, 0.12, 0.12, 0x3a3230); track.position.set(-0.3, 2.86, D / 2 + 0.14); barn.add(track);
      for (const [dx, dz] of [[-1.55, 0.2], [0.66, 0.08]]) { const d = texturedBox(1.32, 2.7, 0.1, art().barnDoor); d.position.set(dx, 1.5, D / 2 + dz); barn.add(d); }
      // the hayloft: an X-braced loft door with hay spilling over its sill, under a little hay hood and pulley beam
      const loftDoor = texturedBox(1.05, 1.15, 0.1, art().barnDoor); loftDoor.position.set(0, H + 1.0, D / 2 + 0.06); barn.add(loftDoor);
      const tuft = shadowed(new THREE.Mesh(cardGeometry([[-0.5, 0], [0.5, 0], [0.46, 0.12], [0.36, 0.05], [0.28, 0.16], [0.16, 0.06], [0.05, 0.18], [-0.06, 0.07], [-0.18, 0.17], [-0.28, 0.05], [-0.38, 0.14], [-0.47, 0.06]], 0.04), cardMat(art().hay)));
      tuft.position.set(0, H + 0.38, D / 2 + 0.14); tuft.rotation.x = -0.25; barn.add(tuft);
      for (const sx of [-1, 1]) { const hood = texturedBox(0.62, 0.08, 1.0, art().shakes); hood.position.set(sx * 0.27, H + 2.38, D / 2 + 0.4); hood.rotation.z = -sx * 0.62; barn.add(hood); }
      const beam = solidBox(0.14, 0.14, 1.15, 0x6b4a30); beam.position.set(0, H + 2.05, D / 2 + 0.5); barn.add(beam);
      const rope = solidBox(0.035, 0.9, 0.035, 0xc9b07a); rope.position.set(0, H + 1.55, D / 2 + 1.0); barn.add(rope);
      const hook = solidBox(0.14, 0.12, 0.05, 0x3a3230); hook.position.set(0, H + 1.08, D / 2 + 1.0); barn.add(hook);
      // a louvered cupola on the ridge with a little shake roof; the weathervane stands on top of it
      const cup = texturedBox(0.9, 0.8, 0.9, art().louver); cup.position.set(0, H + 2.6 + 0.5, 0); barn.add(cup);
      const cupRoof = shadowed(new THREE.Mesh(new THREE.ConeGeometry(0.82, 0.6, 4).rotateY(Math.PI / 4), cardMat(art().shakes))); cupRoof.position.set(0, H + 2.6 + 1.2, 0); barn.add(cupRoof);
      this.vaneAt = new THREE.Object3D(); this.vaneAt.position.set(0, H + 2.6 + 1.5, 0); barn.add(this.vaneAt); // the weathervane stands on the cupola (weathervane.js)
      // the barn quilt, painted on a board, on the side facing the yard; and two small windows on the far side
      const quilt = texturedBox(0.06, 1.5, 1.5, art().quilt); quilt.position.set(W / 2 + 0.05, 2.05, 0.4); barn.add(quilt);
      for (const wz of [-2, 2]) { const w = windowMesh(0.7, 0.7); w.rotation.y = Math.PI / 2; w.position.set(-W / 2 - 0.03, 1.9, wz); barn.add(w); }
      this.root.add(barn);
      world.colliders.push({ x, z, r: 4.4 });
      // the red barn from the reference art, where it's been made: the paper barn steps aside, the model stands on its
      // footprint (doors to the front, as the paper barn's), and the copper rooster swings on the model's cupola
      const bsrc = propModel('bldg_barn');
      if (bsrc) {
        barn.remove(...barn.children.filter((o) => o !== this.vaneAt));
        const m = bsrc.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), k = 8.6 / (bsrc.info?.body?.x || sz.x), cx = bsrc.info?.body?.cx ?? (bb.min.x + bb.max.x) / 2; // (a big barn, big enough to walk into)
        m.scale.setScalar(k); m.position.set(-cx * k, -bb.min.y * k, -((bb.min.z + bb.max.z) / 2) * k); barn.add(m);
        m.updateMatrix(); const v = new THREE.Vector3(), top = new THREE.Vector3(); let hi = -1e9, n = 0; const pts = [];
        m.traverse((o) => { if (!o.isMesh) return; const P = o.geometry.attributes.position; for (let i = 0; i < P.count; i += 3) { v.fromBufferAttribute(P, i).applyMatrix4(m.matrix); pts.push(v.x, v.y, v.z); if (v.y > hi) hi = v.y; } });
        for (let i = 0; i < pts.length; i += 3) if (pts[i + 1] > hi - 0.1) { top.x += pts[i]; top.z += pts[i + 2]; n++; }
        this.vaneAt.position.set(top.x / n, hi - 0.2, top.z / n); this.barn = barn; // (its post seated in the cupola's peak)
        // walk-in: its own materials cut away above head height while you're inside (see barnCutaway), its walls ringed
        // with colliders and a gap at the big front doors, in place of the one round collider
        m.traverse((o) => { if (!o.isMesh) return; o.material = o.material.clone(); o.material.alphaTest = 0.5; o.material.opacityNode = step(positionWorld.y, uBarnCut); });
        const ox = 0.12, oz = 0.25, hw = 2.58, hd = 3.45, c = Math.cos(-0.25), s = Math.sin(-0.25); // (its inner walls, measured: a little off the model's middle)
        const ci = world.colliders.findIndex((q) => q.x === x && q.z === z && q.r === 4.4); if (ci >= 0) world.colliders.splice(ci, 1);
        const wall = (lx, lz) => { lx += ox; lz += oz; world.colliders.push({ x: x + c * lx + s * lz, z: z - s * lx + c * lz, r: 0.35 }); };
        for (let lx = -hw; lx <= hw + 0.01; lx += 0.5) { wall(lx, -hd); if (Math.abs(lx) > 1.25) wall(lx, hd); } // (back wall; front wall either side of the doors)
        for (let lz = -hd; lz <= hd + 0.01; lz += 0.5) { wall(-hw, lz); wall(hw, lz); }
        this.barnBox = { x, z, y, c, s, hw, hd, ox, oz };
        // inside: a working barn to walk into. Stacked square bales and a round one along the back wall, loose hay
        // drifted on the boards, a plank feed trough with oats on the left wall, a milk pail and a three-legged stool,
        // a pitchfork leaning in the corner and a tin lantern hung on a post that glows warm after dark
        {
          const inner = new THREE.Group(); inner.position.y = 0.13; barn.add(inner); // (on its plank floor)
          const put = (name, len, lx, lz, rot, ry = 0) => {
            const src = propModel(name); if (!src) return null;
            const mm = src.scene.clone(), b2 = new THREE.Box3().setFromObject(mm), s2 = b2.getSize(new THREE.Vector3()), c2 = b2.getCenter(new THREE.Vector3()), kk = len / Math.max(s2.x, s2.z);
            const g = new THREE.Group(); mm.position.set(-c2.x * kk, -b2.min.y * kk, -c2.z * kk); mm.scale.setScalar(kk); g.add(mm);
            g.position.set(lx, ry, lz); g.rotation.y = rot; inner.add(g);
            world.colliders.push({ x: x + c * lx + s * lz, z: z - s * lx + c * lz, r: len * 0.38 }); return g;
          };
          put('prop_haybales', 1.8, -1.0, -2.55, 0.1);
          put('prop_haybale_round', 1.2, 1.2, -2.45, Math.PI / 2 + 0.2);
          // loose hay: a few low torn-paper drifts on the floor
          const hayMat2 = paperMat(0xd8b45a);
          for (const [hx, hz, hr] of [[-0.6, -1.4, 0.8], [1.5, -1.3, 0.55], [-1.3, 2.4, 0.5], [0.6, 1.0, 0.45]]) {
            const drift = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(hr, hr * 1.15, 0.12, 9), hayMat2)); drift.position.set(hx, 0.06, hz); drift.rotation.y = hx * 3; drift.scale.z = 0.7; inner.add(drift);
          }
          // the feed trough along the left wall, a pail and a milking stool by it
          const plank = 0x8a5e36, dark = 0x5e3e22;
          const trough = new THREE.Group(); trough.position.set(-1.85, 0, 0.5); inner.add(trough);
          for (const [w, h, d, px, py, pz] of [[0.6, 0.06, 2.0, 0, 0.5, 0], [0.06, 0.3, 2.0, -0.3, 0.62, 0], [0.06, 0.3, 2.0, 0.3, 0.62, 0], [0.6, 0.3, 0.06, 0, 0.62, -1], [0.6, 0.3, 0.06, 0, 0.62, 1]]) { const b = solidBox(w, h, d, plank); b.position.set(px, py, pz); trough.add(b); }
          for (const [px, pz] of [[-0.25, -0.9], [0.25, -0.9], [-0.25, 0.9], [0.25, 0.9]]) { const l = solidBox(0.08, 0.5, 0.08, dark); l.position.set(px, 0.25, pz); trough.add(l); }
          const oats = solidBox(0.5, 0.06, 1.9, 0xe0c27a); oats.position.y = 0.6; trough.add(oats);
          world.colliders.push({ x: x + c * -1.85 + s * 0.5, z: z - s * -1.85 + c * 0.5, r: 0.6 });
          const pail = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.14, 0.3, 12), paperMat(0x9aa4aa))); pail.position.set(-1.0, 0.15, 2.0); inner.add(pail);
          const milk = shadowed(new THREE.Mesh(new THREE.CircleGeometry(0.15, 12).rotateX(-Math.PI / 2), paperMat(0xf4efe2))); milk.position.set(-1.0, 0.27, 2.0); inner.add(milk);
          const stool = new THREE.Group(); stool.position.set(-0.55, 0, 1.45); inner.add(stool);
          const seatS = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 0.05, 10), paperMat(plank))); seatS.position.y = 0.42; stool.add(seatS);
          for (let i = 0; i < 3; i++) { const l = solidBox(0.04, 0.44, 0.04, dark); const a2 = i * 2.1; l.position.set(Math.cos(a2) * 0.13, 0.21, Math.sin(a2) * 0.13); l.rotation.set(Math.sin(a2) * 0.15, 0, -Math.cos(a2) * 0.15); stool.add(l); }
          // a pitchfork leaning in the back-left corner
          const fork = new THREE.Group(); fork.position.set(-2.0, 0, -2.75); fork.rotation.set(0.25, 0.6, 0.12); inner.add(fork);
          const shaft = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.6, 6), paperMat(0xb08a52))); shaft.position.y = 0.8; fork.add(shaft);
          for (const ox of [-0.08, 0, 0.08]) { const t = solidBox(0.02, 0.32, 0.02, 0x7a7e82); t.position.set(ox, 1.74, 0); fork.add(t); }
          const brace = solidBox(0.2, 0.03, 0.03, 0x7a7e82); brace.position.y = 1.6; fork.add(brace);
          // a post with a hook, and the tin lantern hung on it
          const post2 = solidBox(0.14, 2.1, 0.14, dark); post2.position.set(0.9, 1.05, 0.3); inner.add(post2);
          const lant = new THREE.Group(); lant.position.set(0.9, 1.75, 0.48); inner.add(lant);
          const cage = solidBox(0.16, 0.24, 0.16, 0x3e3a36); lant.add(cage);
          const glassMat = paperMat(0xf6d9a0); glassMat.emissiveNode = vec3(1.0, 0.65, 0.3).mul(glowU).mul(4);
          const glass = new THREE.Mesh(new THREE.BoxGeometry(0.13, 0.17, 0.17), glassMat); lant.add(glass);
          const cap = shadowed(new THREE.Mesh(new THREE.ConeGeometry(0.12, 0.1, 4), paperMat(0x3e3a36))); cap.position.y = 0.17; cap.rotation.y = Math.PI / 4; lant.add(cap);
          world.colliders.push({ x: x + c * 0.9 + s * 0.3, z: z - s * 0.9 + c * 0.3, r: 0.25 });
        }
        const r0 = this.roofs.find((r) => r.x === x && r.z === z); if (r0) Object.assign(r0, { hw: hw + 0.4, z0: oz - hd - 0.3, z1: oz + hd + 0.3 }); // (dry under its roof)
      }
      // hay bales beside the barn
      const hayGeo = new THREE.CylinderGeometry(0.6, 0.6, 1.0, 12).rotateZ(Math.PI / 2);
      const hayMat = cardMat(art().hay);
      for (let i = 0; i < 4; i++) {
        const hx = x + 4 + (i % 2) * 1.3, hz = z + 3.5 + Math.floor(i / 2) * 1.2;
        const bsrc = propModel('prop_haybale_round'); // (the round bale from the reference art, where it's been made: rolled on its side)
        const bale = bsrc ? (() => { const m = bsrc.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = 1.3 / Math.max(sz.x, sz.y);
          const h = new THREE.Group(), t = new THREE.Group(); m.position.set(-c.x, -c.y, -c.z); t.add(m); t.scale.setScalar(k); t.rotation.y = Math.PI / 2; h.add(t); return h; })() : shadowed(new THREE.Mesh(hayGeo, hayMat));
        bale.position.set(hx, getHeight(hx, hz) + (bsrc ? 0.65 : 0.55), hz);
        bale.rotation.y = rng() * 0.6;
        this.root.add(bale);
      }
      world.colliders.push({ x: x + 4.6, z: z + 4.1, r: 1.4 });
      // from the reference art: a stack of twine-tied square bales by the round ones, and a cord of split firewood with
      // its chopping block against the farmhouse's west wall (dressing: the woodpiles you build are your own)
      const dress = (name, len, px, pz, rot) => {
        const src = propModel(name); if (!src) return;
        const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = len / sz.x;
        const h = new THREE.Group(); m.position.set(-c.x * k, -bb.min.y * k, -c.z * k); m.scale.setScalar(k); h.add(m);
        h.position.set(px, getHeight(px, pz), pz); h.rotation.y = rot; this.root.add(h); world.colliders.push({ x: px, z: pz, r: len * 0.4 });
      };
      dress('prop_haybales', 2.4, x + 4.2, z + 6.4, -0.25);
      dress('prop_woodpile', 2.3, C.x + 1.4, C.z - 6.8, Math.PI / 2 + 0.15);
    }

    // ---------------------------------------------------- windmill
    {
      const x = C.x + 13, z = C.z + 5, y = base(x, z, 1);
      const mill = new THREE.Group();
      mill.position.set(x, y, z); this.millAt = new THREE.Vector3(x, y, z); // (its ladder and platform are climbable: see main.js)
      const wood = 0x7b6a58;
      const legH = 8;
      for (const [lx, lz] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
        const leg = solidBox(0.14, legH + 0.4, 0.14, wood);
        leg.position.set(lx * 0.6, legH / 2, lz * 0.6);
        leg.rotation.set(-lz * 0.09, 0, lx * 0.09); // leaning in: the tower tapers toward the head
        mill.add(leg);
      }
      const legW = (yy) => 0.6 - (yy - legH / 2) * Math.tan(0.09); // how far out the leaning legs stand at a height
      for (let k = 1; k < 5; k++) {
        const w = legW(k * 1.8), ring = solidBox(w * 2 + 0.1, 0.08, 0.08, wood);
        for (const rz of [-1, 1]) { const r = ring.clone(); r.position.set(0, k * 1.8, rz * (w + 0.06)); mill.add(r); }
        for (const rx of [-1, 1]) { const r = ring.clone(); r.rotation.y = Math.PI / 2; r.position.set(rx * (w + 0.06), k * 1.8, 0); mill.add(r); }
      }
      // X-bracing on every face of each tier of the tower, a ladder up the south face, a plank platform under the head
      const yAt = (k) => (k === 0 ? 0.3 : k * 1.8), wAt = (k) => legW(yAt(k));
      for (let k = 0; k < 4; k++) {
        const y0 = yAt(k), y1 = yAt(k + 1), w0 = wAt(k), w1 = wAt(k + 1), wm = (w0 + w1) / 2;
        const len = Math.hypot(w0 + w1, y1 - y0), ang = Math.atan2(y1 - y0, w0 + w1);
        for (const face of [0, 1, 2, 3]) for (const dir of [-1, 1]) {
          const b = solidBox(len, 0.06, 0.05, 0x8a7862);
          const grp = new THREE.Group(); grp.rotation.y = (face * Math.PI) / 2; mill.add(grp);
          b.position.set(dir * (w1 - w0) / 2 * -1, (y0 + y1) / 2, wm + 0.05); b.rotation.z = dir * ang; grp.add(b);
        }
      }
      for (const lx of [-0.18, 0.18]) { const rail = solidBox(0.06, legH - 0.3, 0.06, 0x8a7862); rail.position.set(lx, (legH - 0.3) / 2, 0.58); rail.rotation.x = -0.075; mill.add(rail); }
      for (let ry = 0.5; ry < legH - 0.5; ry += 0.42) { const rung = solidBox(0.42, 0.05, 0.05, 0x8a7862); rung.position.set(0, ry, 0.79 - ry * 0.075); mill.add(rung); }
      const deck = solidBox(1.6, 0.08, 1.6, 0xa07a4c); deck.position.y = legH - 0.15; mill.add(deck);
      for (const [rx, rz, ry] of [[0, 0.78, 0], [0, -0.78, 0], [0.78, 0, 1], [-0.78, 0, 1]]) { const r = solidBox(1.6, 0.06, 0.06, 0x8a7862); r.position.set(rx, legH + 0.35, rz); r.rotation.y = ry * Math.PI / 2; mill.add(r); }
      // the pump rod down the middle to a cast-iron pump at the foot, spilling into a round stock tank
      const rod = solidBox(0.05, legH - 0.6, 0.05, 0x4a4440); rod.position.y = legH / 2; mill.add(rod);
      const pump = solidBox(0.24, 0.9, 0.24, 0x3a3634); pump.position.set(0, 0.45, 0); mill.add(pump);
      const spout = solidBox(0.1, 0.1, 0.5, 0x3a3634); spout.position.set(0, 0.75, 0.32); mill.add(spout);
      const tankR = 1.0, tank = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(tankR, tankR, 0.55, 20, 1, true), paperMat(0x8e9a9e, { side: THREE.DoubleSide })));
      tank.position.set(0, 0.27, 1.4); mill.add(tank);
      const rim = shadowed(new THREE.Mesh(new THREE.TorusGeometry(tankR, 0.045, 4, 20).rotateX(Math.PI / 2), paperMat(0x6e7a7e))); rim.position.set(0, 0.55, 1.4); mill.add(rim);
      const water = new THREE.Mesh(new THREE.CircleGeometry(tankR - 0.03, 20).rotateX(-Math.PI / 2), paperMat(0x6f97a4)); water.position.set(0, 0.46, 1.4); water.receiveShadow = true; mill.add(water);
      world.colliders.push({ x, z: z + 1.4, r: 1.1 });
      const head = new THREE.Group(); head.position.y = legH + 0.3; mill.add(head);
      head.add(solidBox(0.5, 0.5, 0.9, 0x8e9196));
      const tail = shadowed(new THREE.Mesh(cardGeometry([[0, -0.5], [2.2, -0.2], [2.2, 0.7], [0, 0.4]], 0.05), cardMat(art().tail)));
      tail.rotation.y = Math.PI / 2; tail.position.z = -0.4; head.add(tail);
      this.fan = new THREE.Group(); this.fan.position.z = 0.55; head.add(this.fan);
      const blade = cardGeometry([[0.25, -0.12], [1.9, -0.28], [1.9, 0.28], [0.25, 0.12]], 0.04);
      const bladeMat = cardMat(art().blade);
      for (let i = 0; i < 12; i++) {
        const b = shadowed(new THREE.Mesh(blade, bladeMat));
        b.rotation.set(0.35, 0, (i / 12) * Math.PI * 2);
        this.fan.add(b);
      }
      this.fan.add(solidBox(0.3, 0.3, 0.3, 0xa63c2e));
      const cap = solidBox(0.18, 0.18, 0.12, 0xefe5cc); cap.position.z = 0.2; this.fan.add(cap);
      head.rotation.y = -0.6;
      this.root.add(mill);
      world.colliders.push({ x, z, r: 1.2 });
    }

    // ---------------------------------------------------- fence, pumpkins, mailbox, lanterns
    const fx = C.x + 1, fz = C.z + 1;
    this.root.add(picketFence([[fx - 4, fz + 9], [fx + 5, fz + 9], [fx + 5, fz + 3]], rng));
    // pumpkins: crossed die-cut cards with a printed rib collage (no low-poly spheres)
    const flatBase = [[0.5, 0]];
    for (let k = 0; k <= 20; k++) {
      const t = (k / 20) * Math.PI; // right → left over the top
      const lobe = 1 + 0.06 * Math.cos(t * 6);
      flatBase.push([Math.cos(t) * 0.56 * lobe, 0.08 + Math.sin(t) * 0.62 * lobe]);
      if (k === 10) flatBase.splice(flatBase.length - 1, 1, [0.08, 0.68], [0.06, 0.9], [-0.05, 0.9], [-0.09, 0.68]); // stem
    }
    flatBase.push([-0.5, 0]);
    const pumpkinArt = paintCard(flatBase, {
      W: 256, H: 256, seed: 77, base: '#de7a32',
      fills: ['rgba(222,122,50,A)', 'rgba(240,150,64,A)', 'rgba(196,96,40,A)'],
      edge: 'rgba(140,60,20,1)',
      details(g, px, r) {
        for (const x of [-0.32, -0.12, 0.12, 0.32]) {
          const [a, b] = px(x, 0.36);
          g.fillStyle = 'rgba(176,80,30,0.55)';
          g.beginPath(); g.ellipse(a, b, 9, 70, 0, 0, Math.PI * 2); g.fill();
        }
        const [sx, sy] = px(-0.01, 0.82);
        g.fillStyle = '#5b6a3a'; g.fillRect(sx - 7, sy - 14, 14, 30);
        const [lx, ly] = px(0.14, 0.78);
        g.fillStyle = '#7d9150'; g.beginPath(); g.ellipse(lx, ly, 16, 8, -0.4, 0, Math.PI * 2); g.fill();
      },
    });
    const pumpkinGeo = (() => {
      const a = cardGeometry(flatBase, 0.04), b = cardGeometry(flatBase, 0.04).rotateY(Math.PI / 2);
      return mergeGeometries([a, b]);
    })();
    const pumpkinMat = cardMaterial(pumpkinArt);
    for (let i = 0; i < 7; i++) {
      const px = fx - 2.5 + rng() * 6, pz = fz + 4 + rng() * 4;
      const pk = shadowed(new THREE.Mesh(pumpkinGeo, pumpkinMat));
      pk.position.set(px, 0, pz);
      pk.rotation.y = 0.6 + rng() * 0.3;
      pk.scale.setScalar(0.42 + rng() * 0.28);
      this.root.add(pk);
    }
    const mbsrc = propModel('prop_mailbox');
    if (mbsrc) {
      // the mailbox from the reference art: a stitched blue tin box with a red door on a braced post. Its own red flag
      // is moulded standing up, so it's cut away (the red triangles above the lid on the flag's side) and a paper
      // pennant of our own turns on the same pin: up when there's a letter waiting (see mail.js)
      const mx = C.x + 1.5, mz = C.z + 11, my = getHeight(mx, mz), k = 1.5 / 1.9; // (a shade shorter than the model's post)
      const m = mbsrc.scene.clone();
      m.traverse((o) => {
        if (!o.isMesh) return;
        // the print, read back so the flag's red can be told from the box's blue tin and the post's wood
        const img = o.material.map?.image, cv = document.createElement('canvas');
        let px = null; if (img) { cv.width = img.width; cv.height = img.height; const cx = cv.getContext('2d'); cx.drawImage(img, 0, 0); px = cx.getImageData(0, 0, cv.width, cv.height).data; }
        const flipY = o.material.map?.flipY;
        const isRed = (u, v) => { if (!px) return true; const X = Math.min(cv.width - 1, Math.max(0, Math.floor(u * cv.width))), Y = Math.min(cv.height - 1, Math.max(0, Math.floor((flipY ? 1 - v : v) * cv.height))), i = (Y * cv.width + X) * 4; return px[i] > 110 && px[i] > px[i + 1] * 1.45 && px[i] > px[i + 2] * 1.4; };
        const g = o.geometry.clone(), P = g.attributes.position, U = g.attributes.uv, I = g.index, keep = [];
        for (let t = 0; t < I.count; t += 3) {
          let x = 0, y = 0, z = 0, u = 0, v = 0; for (let j = 0; j < 3; j++) { const q = I.getX(t + j); x += P.getX(q); y += P.getY(q); z += P.getZ(q); u += U.getX(q); v += U.getY(q); }
          x /= 3; y /= 3; z /= 3;
          const flag = z > 0.18 && (y > 0.6 || (y > 0.5 && z > 0.25 && x > -0.25 && isRed(u / 3, v / 3))); // (the red door, at the far end, is left be) // (above the lid, or the red stem standing proud of the box's side)
          if (!flag) keep.push(I.getX(t), I.getX(t + 1), I.getX(t + 2));
        }
        g.setIndex(keep); o.geometry = g; o.castShadow = true; o.receiveShadow = true;
      });
      const h = new THREE.Group(); h.scale.setScalar(k); h.rotation.y = Math.PI / 2; h.position.set(mx, my + 0.95 * k, mz); // (model centred on its middle; door to the lane)
      h.add(m); this.root.add(h);
      // the pin, in the model's frame (on the box's side, just under the lid), to the world
      h.updateMatrixWorld(true); const pin = new THREE.Vector3(0.0, 0.46, 0.3).applyMatrix4(h.matrixWorld).sub(this.root.position);
      this.mailFlag = new THREE.Group(); this.mailFlag.position.copy(pin); this.mailFlag.scale.setScalar(k);
      const red = paperMat(0xb8382f);
      const stem = solidBox(0.035, 0.42, 0.03, 0xb8382f); stem.position.y = 0.21; stem.position.x = 0.02; this.mailFlag.add(stem); // (on the model's own red pin disc)
      const blade = shadowed(new THREE.Mesh(new THREE.ExtrudeGeometry(new THREE.Shape([[0, 0], [0, 0.13], [-0.19, 0.13], [-0.14, 0.065], [-0.19, 0]].map(([z, y]) => new THREE.Vector2(z, y))), { depth: 0.025, bevelEnabled: false }).rotateY(-Math.PI / 2).translate(0.032, 0.3, 0), red)); // a swallowtail pennant
      this.mailFlag.add(blade);
      this.mailFlag.rotation.x = -Math.PI / 2; this.root.add(this.mailFlag);
      this.mailbox = new THREE.Vector3(mx, my, mz);
    } else {
      const mx = C.x + 1.5, mz = C.z + 11;
      const post = solidBox(0.12, 1.1, 0.12, 0x7b5236); post.position.set(mx, getHeight(mx, mz) + 0.55, mz); this.root.add(post);
      // a rural route mailbox: a flat-bottomed box with a rounded top, and a darker door at the lane end
      const tin = paperMat(0x5f7f9a), door = paperMat(0x48627a);
      const my = getHeight(mx, mz);
      const body = shadowed(new THREE.Mesh(mergeGeometries([
        new THREE.BoxGeometry(0.38, 0.2, 0.56).translate(0, 0.1, 0),
        new THREE.CylinderGeometry(0.19, 0.19, 0.56, 14).rotateX(Math.PI / 2).translate(0, 0.2, 0),
      ]), tin));
      body.position.set(mx, my + 1.08, mz); this.root.add(body);
      const lid = shadowed(new THREE.Mesh(mergeGeometries([
        new THREE.BoxGeometry(0.4, 0.21, 0.03).translate(0, 0.1, 0),
        new THREE.CylinderGeometry(0.2, 0.2, 0.03, 14).rotateX(Math.PI / 2).translate(0, 0.2, 0),
      ]), door));
      lid.position.set(mx, my + 1.08, mz + 0.29); this.root.add(lid);
      // the red flag turns on a pin at its foot: up when there's mail waiting (see mail.js)
      this.mailFlag = new THREE.Group(); this.mailFlag.position.set(mx + 0.21, getHeight(mx, mz) + 1.18, mz - 0.1);
      const flag = solidBox(0.04, 0.3, 0.1, 0xc4363a); flag.position.y = 0.15; this.mailFlag.add(flag);
      this.mailFlag.rotation.x = -Math.PI / 2; // lowered, pointing along the box
      this.root.add(this.mailFlag);
      this.mailbox = new THREE.Vector3(mx, getHeight(mx, mz), mz);
    }

    const lanternGlass = paperMat(0xf6d9a0);
    lanternGlass.emissiveNode = vec3(1.0, 0.65, 0.3).mul(glowU).mul(4);
    for (const [ox, oz] of [[-3, 6], [4, 10], [-8, -1.5], [9, -1]]) {
      const lx = C.x + ox, lz = C.z + oz, ly = getHeight(lx, lz);
      const g = new THREE.Group(); g.position.set(lx, ly, lz);
      const post = solidBox(0.14, 2.4, 0.14, 0x5a3e2a); post.position.y = 1.2; g.add(post);
      const arm = solidBox(0.6, 0.1, 0.1, 0x5a3e2a); arm.position.set(0.25, 2.3, 0); g.add(arm);
      const lamp = shadowed(new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.42, 0.3), lanternGlass)); lamp.position.set(0.5, 1.98, 0); g.add(lamp);
      const cap = solidBox(0.38, 0.08, 0.38, 0x2f2a26); cap.position.set(0.5, 2.22, 0); g.add(cap);
      const pl = new THREE.PointLight(0xffb070, 0, 11, 1); pl.position.set(0.5, 1.9, 0); g.add(pl);
      this.lights.push({ light: pl, max: 4.5 });
      this.root.add(g);
      world.colliders.push({ x: lx, z: lz, r: 0.3 });
    }

    // ---------------------------------------------------- chimney smoke puffs
    const puffGeo = cardGeometry(Array.from({ length: 14 }, (_, i) => {
      const a = (i / 14) * Math.PI * 2, r = 0.5 * (1 + 0.12 * Math.sin(a * 5));
      return [Math.cos(a) * r, Math.sin(a) * r];
    }), 0.06);
    const puffMat = paperMat(0xece4d6);
    for (let i = 0; i < 9; i++) {
      const p = new THREE.Mesh(puffGeo, puffMat);
      p.userData.t = i / 9;
      this.root.add(p);
      this.smoke.push(p);
    }

    // merge every static piece into one mesh per material (~150 meshes → ~15 draw calls);
    // the spinning fan and the drifting smoke stay separate
    bakeStatic(this.fan, new Set()); // the fan's blades merge into one mesh that still spins as a group
    bakeStatic(this.root, new Set([this.fan, this.mailFlag, ...this.smoke, ...(propModel('bldg_farmhouse_starter') ? [this.house] : []), ...(this.barn ? [this.barn] : [])])); // (the house stays apart when its models from the reference art stand in for it)

    this.spawn = new THREE.Vector3(C.x + 2, 0, C.z + 6.5);
    this.spawn.y = getHeight(this.spawn.x, this.spawn.z);
  }

  /**
   * The farmhouse from the reference art, in the state your fortune affords (dollars the assayer has paid you, all
   * told): the starter shack till $60, partly mended (patched roof, new porch boards) from $60, fully mended (fresh
   * paint, shutters, a tidy porch) from $200. The paper house's hooks (door, window, chimney top, porch lamp) stay;
   * only its paper is hidden under the model.
   */
  /** Inside the barn, its upper walls and roof aren't drawn, so the camera sees you among the stalls. */
  barnCutaway(pos) {
    const B = this.barnBox; if (!B) return;
    const dx = pos.x - B.x, dz = pos.z - B.z, lx = B.c * dx - B.s * dz - B.ox, lz = B.s * dx + B.c * dz - B.oz;
    const inside = Math.abs(lx) < B.hw && lz > -B.hd && lz < B.hd + 0.2;
    uBarnCut.value = inside ? B.y + 2.3 : 1e4;
  }

  setFortune(fortune) {
    const state = fortune >= 200 ? 'mended' : fortune >= 60 ? 'partly' : 'starter';
    if (!this.house || state === this.houseState) return;
    const src = propModel(`bldg_farmhouse_${state}`); if (!src) return;
    this.houseState = state;
    if (this.houseModel) this.house.remove(this.houseModel);
    else this.house.remove(...this.house.children.filter((o) => o.isMesh || (o.isGroup && !o.children.some((c) => c.isLight)))); // (once: the paper house steps aside)
    const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3());
    const k = this.houseW / (src.info?.body?.x || sz.x), cx = src.info?.body?.cx ?? (bb.min.x + bb.max.x) / 2;
    m.scale.setScalar(k); m.position.set(-cx * k, -bb.min.y * k, this.houseFront - bb.max.z * k);
    this.house.add(m); this.houseModel = m; this.onHouseModel?.(m);
    // the smoke rises from the model's own chimney: in every state it stands proud of the ridge, so it's the top of the house
    m.updateMatrix(); const v = new THREE.Vector3(), top = new THREE.Vector3(); let hi = -1e9, n = 0;
    const pts = []; m.traverse((o) => { if (!o.isMesh) return; const P = o.geometry.attributes.position; for (let i = 0; i < P.count; i += 3) { v.fromBufferAttribute(P, i).applyMatrix4(m.matrix); pts.push(v.x, v.y, v.z); if (v.y > hi) hi = v.y; } });
    for (let i = 0; i < pts.length; i += 3) if (pts[i + 1] > hi - 0.12) { top.x += pts[i]; top.y += pts[i + 1]; top.z += pts[i + 2]; n++; }
    if (n && this.chimneyTop) this.chimneyTop.position.set(top.x / n, hi + 0.1, top.z / n);
  }

  /** Is (x, z) under the farmhouse (or its porch) or the barn? */
  covers(x, z) {
    for (const r of this.roofs) {
      const dx = x - r.x, dz = z - r.z, c = Math.cos(r.rot), s = Math.sin(r.rot);
      const lx = c * dx - s * dz, lz = s * dx + c * dz;
      if (Math.abs(lx) < r.hw && lz > r.z0 && lz < r.z1) return true;
    }
    return false;
  }

  update(dt, night, camera) {
    glowU.value = THREE.MathUtils.smoothstep(night, 0.25, 0.8);
    for (const { light, max } of this.lights) light.intensity = glowU.value * max;
    this.fan.rotation.z -= dt * 1.4;
    const top = this.chimneyTop.getWorldPosition(_v);
    for (const p of this.smoke) {
      p.userData.t = (p.userData.t + dt / 9) % 1;
      const t = p.userData.t;
      p.position.set(top.x + Math.sin(t * 5 + p.id) * 0.4 + t * 2.5, top.y + t * 7, top.z + t * 1.2);
      p.scale.setScalar(0.3 + t * 1.5 * (1 - t * 0.4) * (t < 0.08 ? t / 0.08 : 1) * (t > 0.85 ? (1 - t) / 0.15 : 1));
      p.lookAt(camera.position);
    }
  }
}

const _v = new THREE.Vector3();

/** Merge all static meshes under `root` (skipping anything under `keep`) into one mesh per material. */
function bakeStatic(root, keep) {
  root.updateMatrixWorld(true);
  const toRoot = new THREE.Matrix4().copy(root.matrixWorld).invert();
  const rel = new THREE.Matrix4();
  const byMat = new Map();
  const old = [];
  root.traverse((o) => {
    if (!o.isMesh || o.isInstancedMesh) return;
    for (let a = o; a; a = a.parent) if (keep.has(a)) return;
    let g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
    for (const name of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(name)) g.deleteAttribute(name);
    if (!g.attributes.uv) g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
    if (!g.attributes.normal) g.computeVertexNormals();
    g.clearGroups();
    g.applyMatrix4(rel.multiplyMatrices(toRoot, o.matrixWorld)); // relative to root
    if (!byMat.has(o.material)) byMat.set(o.material, { geos: [], shadow: false });
    const entry = byMat.get(o.material);
    entry.geos.push(g);
    entry.shadow ||= o.castShadow;
    old.push(o);
  });
  for (const o of old) o.parent.remove(o);
  for (const [mat, { geos, shadow }] of byMat) {
    const merged = mergeGeometries(geos, false);
    merged.computeBoundingSphere();
    const m = new THREE.Mesh(merged, mat);
    m.castShadow = shadow;
    m.receiveShadow = true;
    root.add(m);
  }
}
