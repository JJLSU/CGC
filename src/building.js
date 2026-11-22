// Building: paper-model pieces that snap to a 2 m grid. A ghost preview follows the crosshair;
// left click places, right click removes (full refund). Floors and stairs are walkable, walls and
// fences block, and lanterns/campfires borrow lights from a fixed pool (so adding lights never
// forces every shader to recompile).
import * as THREE from 'three/webgpu';
import { uniform, vec3, float, sin, time, positionLocal } from 'three/tsl';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { getHeight, springRise, isWater } from './world.js';
import { cardMaterial, paperMaterial } from './materials.js';
import { cardGeometry, propKinds } from './props.js';
import { panelArt, paintCard, asLayer, rockSilhouette, rockArt, hiveSilhouette, hiveArt, pumpkinSilhouette, pumpkinArt , skepSilhouette, skepArt } from './textures.js';
import { mulberry32 } from './noise.js';
import { propModel } from './modelfolk.js';

const G = 2; // grid size (m)
const WALL_H = 2.2;
const glowU = uniform(0);

export const PIECES = {
  workbench: { name: 'Workbench', cost: { wood: 8 }, snap: 'free', free: true },
  campfire: { name: 'Campfire', cost: { stone: 4, wood: 2 }, snap: 'free', free: true, light: 'fire' },
  floor: { name: 'Floor', cost: { wood: 2 }, snap: 'cell', surface: 'floor' },
  wall: { name: 'Wall', cost: { wood: 3 }, snap: 'edge', solid: [1, 0.12, WALL_H] },
  stonewall: { name: 'Stone wall', cost: { stone: 4 }, snap: 'edge', solid: [1, 0.15, WALL_H] },
  door: { name: 'Doorway', cost: { wood: 3 }, snap: 'edge', solid: 'door' },
  window: { name: 'Window wall', cost: { wood: 3, stone: 1 }, snap: 'edge', solid: [1, 0.12, WALL_H] }, // a plank wall with a four-pane window and shutters; the panes glow after dark
  roof: { name: 'Roof', cost: { wood: 2 }, snap: 'cell' },
  ridge: { name: 'Roof ridge', cost: { wood: 2 }, snap: 'cell' }, // finishes a roof: aimed at a roof, it peaks the next square up its slope
  stairs: { name: 'Stairs', cost: { wood: 3 }, snap: 'cell', surface: 'stairs' },
  fence: { name: 'Fence', cost: { wood: 1 }, snap: 'edge', solid: [1, 0.08, 1.0] },
  lantern: { name: 'Lantern', cost: { wood: 2, stone: 1 }, snap: 'free', light: 'lamp' },
  forge: { name: 'Forge', cost: { stone: 10, clay: 6 }, snap: 'free', light: 'fire' },
  jack: { name: "Jack-o'-lantern", cost: { pumpkin: 1 }, snap: 'free', free: true, light: 'jack' },
  sapling: { name: 'Apple sapling', cost: { apples: 3, wood: 1 }, snap: 'free', free: true },
  homeapple: { name: 'Your apple tree', cost: { wood: 3 }, snap: 'free', free: true, grown: true },
  trophy: { name: 'Old Whiskers on a plaque', cost: { whiskers: 1 }, snap: 'free', free: true },
  snowman: { name: 'Snowman', cost: { stone: 2, wood: 1 }, snap: 'free', free: true, needsSnow: true },
  skep: { name: 'Bee skep', cost: { wood: 2, fiber: 6, honey: 1 }, snap: 'free', free: true },
  dock: { name: 'Plank dock', cost: { wood: 3, rope: 1 }, snap: 'cell', surface: 'floor', free: true },
  scarecrow: { name: 'Scarecrow', cost: { wood: 3, fiber: 4 }, snap: 'free', free: true },
  patch: { name: 'Giant-pumpkin patch', cost: { pumpkin: 1, wood: 1 }, snap: 'free', free: true },
  woodpile: { name: 'Woodpile', cost: { wood: 2 }, snap: 'free', free: true },
  feeder: { name: 'Bird feeder', cost: { wood: 3 }, snap: 'free', free: true },
  press: { name: 'Cider press', cost: { wood: 6, iron: 1 }, snap: 'free', free: true },
  bed: { name: 'Quilted bed', cost: { wood: 6, fiber: 6, rope: 1 }, snap: 'free' },
  // works: the storehouse your settlers fill, and the sites they run (each unlocks once you've gathered its stuff yourself)
  storehouse: { name: 'Storehouse', cost: { wood: 12, stone: 4 }, snap: 'free', free: true },
  woodlot: { name: "Woodcutter's lot", cost: { wood: 6, stone: 2 }, snap: 'free', free: true, work: 'wood' },
  quarry: { name: 'Stone quarry', cost: { wood: 6, stone: 2 }, snap: 'free', free: true, work: 'stone' },
  weir: { name: 'Fish weir', cost: { wood: 8, fiber: 4 }, snap: 'free', free: true, work: 'fish' },
  claypit: { name: 'Clay pit', cost: { wood: 4, stone: 2 }, snap: 'free', free: true, work: 'clay' },
  kiln: { name: 'Brick kiln', cost: { stone: 10, clay: 8, wood: 4 }, snap: 'free', free: true, work: 'clay', light: 'fire' },
  brickwall: { name: 'Brick wall', cost: { bricks: 4 }, snap: 'edge', solid: [1, 0.15, WALL_H] },
  charpit: { name: 'Charcoal pit', cost: { wood: 16, stone: 4, clay: 4 }, snap: 'free', free: true, work: 'iron' },
  tannery: { name: 'Tannery', cost: { wood: 12, stone: 4, rope: 2 }, snap: 'free', free: true, work: 'pelt' },
  shack: { name: 'Sugar shack', cost: { wood: 14, stone: 6, iron: 1 }, snap: 'free', free: true, work: 'sap', light: 'fire' },
  mill: { name: 'Grist mill', cost: { wood: 14, stone: 8 }, snap: 'free', free: true, work: 'wheat', needsWater: true },
  sluice: { name: 'Sluice box', cost: { wood: 12, stone: 4, rope: 1 }, snap: 'free', free: true, work: 'gold', needsWater: true },
  beeyard: { name: 'Bee yard', cost: { wood: 8, fiber: 8, honey: 1 }, snap: 'free', free: true, work: 'honey' },
  diggings: { name: 'Ore diggings', cost: { wood: 10, stone: 6, rope: 1 }, snap: 'free', free: true, work: 'ore' },
};
// hit points when broken with tools; stone pieces count as rock for tool damage
export const PIECE_HP = { sluice: 4, storehouse: 6, woodlot: 4, quarry: 5, weir: 3, claypit: 3, diggings: 5, beeyard: 3, mill: 6, kiln: 7, brickwall: 7, shack: 5, tannery: 4, charpit: 4, forge: 8, workbench: 4, campfire: 3, floor: 3, wall: 4, window: 4, stonewall: 6, door: 4, roof: 3, ridge: 3, stairs: 3, fence: 2, lantern: 2, bed: 3, scarecrow: 2, dock: 3, skep: 2, snowman: 1, trophy: 2, sapling: 1, homeapple: 4, jack: 1, press: 4, feeder: 2, woodpile: 2, patch: 1 };
export const STONE_PIECES = new Set(['stonewall', 'campfire', 'forge', 'kiln', 'brickwall']);
export const PIECE_CHIPS = {
  stonewall: [0xb3a896, 0x8a7f70, 0xefe5cc], campfire: [0x9a907f, 0xff9a48, 0x5a3e2a],
  window: [0xc99a5e, 0x6a7a5a, 0xf6d9a0], roof: [0x6d6f86, 0xc99a5e, 0xefe5cc], ridge: [0x6d6f86, 0xc99a5e, 0xefe5cc], lantern: [0x5a3e2a, 0xf6d9a0, 0xefe5cc],
};
const WOOD_CHIPS = [0xc99a5e, 0x8a5a34, 0xefe5cc];

/** Half-size footprint (local x, local z) and height of each piece, for aiming at it. */
const FOOT = {
  sluice: [1.2, 1.6, 1.2], storehouse: [1.4, 1.2, 2.6], woodlot: [1.1, 0.8, 1.2], quarry: [1.3, 1.1, 1.4], weir: [1.3, 0.9, 1.0], claypit: [1.2, 1.2, 0.8], diggings: [1.3, 1.1, 2.2], beeyard: [1.4, 0.8, 1.3], mill: [1.6, 1.3, 3.0], kiln: [1.2, 1.2, 2.4], brickwall: [1, 0.15, WALL_H], shack: [1.4, 1.2, 2.8], tannery: [1.5, 1.0, 2.0], charpit: [1.3, 1.3, 1.3],
  workbench: [0.8, 0.4, 1.2], campfire: [0.7, 0.7, 0.6], floor: [1, 1, 0.2], wall: [1, 0.12, WALL_H],
  stonewall: [1, 0.15, WALL_H], door: [1, 0.12, WALL_H], window: [1, 0.12, WALL_H], roof: [1, 1, 1.2], ridge: [1, 1, 1.0], stairs: [0.8, 1, WALL_H],
  fence: [1, 0.08, 1], lantern: [0.6, 0.2, 2.4], forge: [0.9, 0.7, 2.2], bed: [0.6, 1.05, 1.1], scarecrow: [0.7, 0.2, 2.5], dock: [1, 1, 0.9], skep: [0.5, 0.5, 1.4], snowman: [0.5, 0.5, 1.9], trophy: [0.9, 0.2, 1.8], sapling: [0.4, 0.4, 1.3], jack: [0.5, 0.5, 0.9], homeapple: [1.2, 1.2, 5], press: [0.8, 0.6, 1.9], feeder: [0.4, 0.4, 1.9], woodpile: [0.4, 0.8, 1.1], patch: [1.1, 1.1, 0.6],
};

// the build menu, in four shelves (keys 1–4 in build mode jump to a shelf; Q/E step through everything)
export const PIECE_GROUPS = [
  ['Workshop', ['workbench', 'campfire', 'forge', 'press']],
  ['Cabin', ['floor', 'wall', 'door', 'window', 'stonewall', 'brickwall', 'roof', 'ridge', 'stairs', 'bed']],
  ['Yard', ['fence', 'lantern', 'scarecrow', 'dock', 'skep', 'sapling', 'feeder', 'woodpile', 'patch']],
  ['Odds & ends', ['jack', 'snowman', 'trophy']],
  ['Works', ['storehouse', 'woodlot', 'quarry', 'weir', 'claypit', 'diggings', 'sluice', 'beeyard', 'mill', 'kiln', 'shack', 'tannery', 'charpit']],
];
export const PIECE_ORDER = PIECE_GROUPS.flatMap(([, list]) => list);

// ------------------------------------------------------------------ painted materials

/** Fired brick: rows of warm red bricks, each a touch different, with pale mortar lines. */
let _brick = null;
function brickMat() {
  if (_brick) return _brick;
  _brick = cardMaterial(panelArt(256, 256, '#d8c8a8', ['rgba(216,200,168,A)'], (g, W, H, rng) => {
    for (let y = 0, row = 0; y < H; y += 26, row++) for (let x = (row % 2) * -26; x < W; x += 52) {
      const c = 0.82 + rng() * 0.3; g.fillStyle = `rgb(${Math.round(176 * c)},${Math.round(84 * c)},${Math.round(58 * c)})`; g.fillRect(x + 3, y + 3, 46, 20);
      g.fillStyle = 'rgba(255,230,200,0.25)'; g.fillRect(x + 3, y + 3, 46, 3);
    }
  }, 57));
  return _brick;
}

let M = null;
function mats() {
  if (M) return M;
  const planks = panelArt(512, 512, '#c99a5e', ['rgba(214,166,104,A)', 'rgba(180,128,78,A)', 'rgba(226,184,124,A)'], (g, W, H, rng) => {
    g.strokeStyle = 'rgba(92,56,30,0.6)'; g.lineWidth = 3;
    for (let y = 0; y <= H; y += 64) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); }
    for (let row = 0; row < 8; row++) {
      const x = 80 + ((row * 173) % 300);
      g.beginPath(); g.moveTo(x, row * 64); g.lineTo(x, row * 64 + 64); g.stroke();
      g.fillStyle = 'rgba(60,40,30,0.7)';
      for (const nx of [12, W - 12]) { g.beginPath(); g.arc(nx, row * 64 + 32, 3, 0, Math.PI * 2); g.fill(); }
      g.strokeStyle = 'rgba(120,76,40,0.25)'; g.lineWidth = 1.5;
      for (let k = 0; k < 4; k++) { const yy = row * 64 + 10 + rng() * 44; g.beginPath(); g.moveTo(rng() * W, yy); g.lineTo(rng() * W, yy + (rng() - 0.5) * 4); g.stroke(); }
      g.strokeStyle = 'rgba(92,56,30,0.6)'; g.lineWidth = 3;
    }
  }, 61);
  const stone = panelArt(512, 512, '#b3a896', ['rgba(170,160,145,A)', 'rgba(150,140,128,A)', 'rgba(196,186,170,A)'], (g, W, H, rng) => {
    for (let row = 0, y = 0; y < H; y += 72, row++) {
      for (let x = (row % 2) * -50; x < W; x += 100 + rng() * 20) {
        g.fillStyle = `rgba(${150 + rng() * 40},${140 + rng() * 35},${125 + rng() * 30},0.55)`;
        g.strokeStyle = 'rgba(70,60,50,0.7)'; g.lineWidth = 3;
        g.beginPath(); g.roundRect(x + 4, y + 4, 92, 64, 16); g.fill(); g.stroke();
      }
    }
  }, 62);
  const shingle = panelArt(512, 512, '#6d6f86', ['rgba(110,112,140,A)', 'rgba(90,92,116,A)', 'rgba(130,128,150,A)'], (g, W, H) => {
    g.strokeStyle = 'rgba(40,40,60,0.6)'; g.lineWidth = 2.5;
    for (let row = 0, y = 12; y < H + 20; y += 24, row++) {
      for (let x = (row % 2) * 18; x < W + 36; x += 36) { g.beginPath(); g.arc(x, y, 18, 0, Math.PI); g.stroke(); }
    }
  }, 63);
  // a patchwork quilt: squares of calico in barn red, mustard, teal and cream, with running stitches
  const quilt = panelArt(512, 512, '#efe3c4', ['rgba(239,227,196,A)', 'rgba(226,210,176,A)'], (g, W, H, rng) => {
    const cols = ['#b5523b', '#d9a441', '#4f8a86', '#efe3c4', '#8a5a3a', '#c4774a'];
    const n = 6, s = W / n;
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
      g.fillStyle = cols[(i * 7 + j * 3 + Math.floor(rng() * 2)) % cols.length];
      g.fillRect(i * s + 3, j * s + 3, s - 6, s - 6);
      g.fillStyle = 'rgba(255,248,230,0.45)'; // tiny calico flowers
      for (let k = 0; k < 4; k++) { g.beginPath(); g.arc(i * s + 12 + rng() * (s - 24), j * s + 12 + rng() * (s - 24), 3, 0, Math.PI * 2); g.fill(); }
    }
    g.strokeStyle = 'rgba(250,240,215,0.9)'; g.lineWidth = 2; g.setLineDash([7, 6]);
    for (let i = 0; i <= n; i++) { g.beginPath(); g.moveTo(i * s, 0); g.lineTo(i * s, H); g.stroke(); g.beginPath(); g.moveTo(0, i * s); g.lineTo(W, i * s); g.stroke(); }
    g.setLineDash([]);
  }, 64);
  M = {
    quilt: cardMaterial(quilt),
    pillow: paperMaterial({ color: 0xf3ead6 }),
    snow: paperMaterial({ color: 0xf6f3ec }), coal: paperMaterial({ color: 0x2b2a30 }), carrot: paperMaterial({ color: 0xe07a2e }), scarf: paperMaterial({ color: 0xb5473a }),
    flannel: paperMaterial({ color: 0xb5473a }), burlap: paperMaterial({ color: 0xc9a670 }), straw: paperMaterial({ color: 0xe2c27a }),
    planks: cardMaterial(planks), stone: cardMaterial(stone), shingle: cardMaterial(shingle),
    dark: paperMaterial({ color: 0x5a3e2a, flatShading: true }),
    rock: paperMaterial({ color: 0x9a907f, flatShading: true }),
    glass: paperMaterial({ color: 0xf6d9a0 }),
    flame: new THREE.MeshBasicNodeMaterial({ side: THREE.DoubleSide }),
  };
  M.glass.emissiveNode = vec3(1.0, 0.65, 0.3).mul(glowU).mul(4);
  // flames flicker by squashing in the vertex stage
  const flick = sin(time.mul(13).add(positionLocal.x.mul(9))).mul(0.08).add(1);
  M.flame.positionNode = positionLocal.mul(vec3(1, flick, 1));
  M.flame.colorNode = vec3(2.2, 1.0, 0.35);
  return M;
}

function box(w, h, d, x, y, z) { return new THREE.BoxGeometry(w, h, d).translate(x, y, z); }

// Each builder returns [{ geo, mat }] in piece-local space (origin at base centre, length along x).
const BUILD = {
  floor: () => [
    { geo: box(G, 0.2, G, 0, 0.1, 0), mat: mats().planks },
    { geo: mergeGeometries([[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([x, z]) => box(0.18, 3, 0.18, x * 0.88, -1.5, z * 0.88))), mat: mats().dark },
  ],
  wall: () => [
    { geo: box(G, WALL_H, 0.2, 0, WALL_H / 2, 0), mat: mats().planks },
    { geo: mergeGeometries([box(0.16, WALL_H, 0.26, -0.96, WALL_H / 2, 0), box(0.16, WALL_H, 0.26, 0.96, WALL_H / 2, 0)]), mat: mats().dark },
  ],
  // the window wall: planks round a square opening, a dark frame and sill, four panes behind a cross of muntins, and
  // a pair of sage-green shutters folded back against the outside
  window: () => {
    const w = 0.9, y0 = 0.95, y1 = 1.85, side = (G - w) / 2;
    return [
      { geo: mergeGeometries([box(side, WALL_H, 0.2, -(w + side) / 2, WALL_H / 2, 0), box(side, WALL_H, 0.2, (w + side) / 2, WALL_H / 2, 0), box(w, y0, 0.2, 0, y0 / 2, 0), box(w, WALL_H - y1, 0.2, 0, (y1 + WALL_H) / 2, 0)]), mat: mats().planks },
      { geo: mergeGeometries([box(0.16, WALL_H, 0.26, -0.96, WALL_H / 2, 0), box(0.16, WALL_H, 0.26, 0.96, WALL_H / 2, 0), box(w + 0.16, 0.08, 0.32, 0, y0 - 0.02, 0), box(w + 0.16, 0.08, 0.28, 0, y1 + 0.02, 0), box(0.08, y1 - y0, 0.28, -w / 2 - 0.02, (y0 + y1) / 2, 0), box(0.08, y1 - y0, 0.28, w / 2 + 0.02, (y0 + y1) / 2, 0), box(0.035, y1 - y0, 0.07, 0, (y0 + y1) / 2, 0), box(w, 0.035, 0.07, 0, (y0 + y1) / 2, 0)]), mat: mats().dark },
      { geo: box(w, y1 - y0, 0.03, 0, (y0 + y1) / 2, 0), mat: mats().glass, noShadow: true },
      { geo: mergeGeometries([box(0.4, y1 - y0, 0.04, -w / 2 - 0.26, (y0 + y1) / 2, 0.13), box(0.4, y1 - y0, 0.04, w / 2 + 0.26, (y0 + y1) / 2, 0.13)]), mat: (mats().shutter ||= paperMaterial({ color: 0x6a7a5a })) },
    ];
  },
  stonewall: () => [{ geo: box(G, WALL_H, 0.3, 0, WALL_H / 2, 0), mat: mats().stone }],
  brickwall: () => [{ geo: box(G, WALL_H, 0.28, 0, WALL_H / 2, 0), mat: brickMat() }],
  door: () => [
    { geo: mergeGeometries([box(0.55, WALL_H, 0.2, -0.725, WALL_H / 2, 0), box(0.55, WALL_H, 0.2, 0.725, WALL_H / 2, 0), box(0.9, 0.35, 0.2, 0, WALL_H - 0.175, 0)]), mat: mats().planks },
    { geo: mergeGeometries([box(0.12, 1.85, 0.28, -0.45, 0.925, 0), box(0.12, 1.85, 0.28, 0.45, 0.925, 0), box(1.02, 0.12, 0.28, 0, 1.86, 0)]), mat: mats().dark },
  ],
  roof: () => {
    const ang = Math.atan2(1.15, G);
    const len = Math.hypot(1.15, G) + 0.2;
    return [{ geo: new THREE.BoxGeometry(G + 0.3, 0.12, len).rotateX(-ang).translate(0, 0.6, 0), mat: mats().shingle }];
  },
  // the roof ridge: two shingled slopes rising from the square's two edges to a ridge down its middle, and a dark
  // ridge board along the top
  ridge: () => {
    // (it stands on the top edge of the roof below it: same pitch as a roof square, so the slopes run on unbroken)
    const rise = 1.15 / 2, ang = Math.atan2(rise, G / 2), len = Math.hypot(rise, G / 2) + 0.1;
    const slopes = mergeGeometries([1, -1].map((s) => new THREE.BoxGeometry(G + 0.3, 0.12, len).rotateX(s * ang).translate(0, rise / 2 + 0.04, s * G / 4)));
    return [{ geo: slopes, mat: mats().shingle }, { geo: box(G + 0.36, 0.1, 0.2, 0, rise + 0.07, 0), mat: mats().dark }]; // (no gable walls: in the middle of a long roof they'd only end up inside it)
  },
  stairs: () => {
    const steps = [];
    for (let i = 0; i < 6; i++) steps.push(box(1.6, 0.18, G / 6, 0, (i + 1) * (WALL_H / 6) - 0.09, -1 + (i + 0.5) * (G / 6)));
    const sides = mergeGeometries([-1, 1].map((s) => new THREE.BoxGeometry(0.12, 0.3, Math.hypot(G, WALL_H)).rotateX(-Math.atan2(WALL_H, G)).translate(s * 0.86, WALL_H / 2, 0)));
    return [{ geo: mergeGeometries(steps), mat: mats().planks }, { geo: sides, mat: mats().dark }];
  },
  fence: () => [{
    geo: mergeGeometries([
      box(0.12, 1.0, 0.12, -0.94, 0.5, 0), box(0.12, 1.0, 0.12, 0.94, 0.5, 0),
      box(G, 0.1, 0.06, 0, 0.35, 0), box(G, 0.1, 0.06, 0, 0.75, 0),
    ]), mat: mats().planks,
  }],
  workbench: () => [
    { geo: box(1.6, 0.14, 0.8, 0, 0.9, 0), mat: mats().planks },
    { geo: mergeGeometries([[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([x, z]) => box(0.12, 0.9, 0.12, x * 0.7, 0.45, z * 0.3)).concat([box(0.4, 0.3, 0.3, -0.45, 1.12, 0), box(0.04, 0.22, 0.5, 0.4, 1.08, 0)])), mat: mats().dark },
  ],
  campfire: () => {
    // papercraft fire ring: nine little die-cut stone cards stood on edge around three printed log cards in a teepee
    const rng = mulberry32(5);
    const rock = rockSilhouette(3);
    const stones = [];
    for (let i = 0; i < 9; i++) {
      const a = (i / 9) * Math.PI * 2, sc = 0.24 + rng() * 0.08;
      stones.push(cardGeometry(rock, 0.06).scale(sc, sc * 0.75, sc).rotateY(-a + Math.PI / 2).translate(Math.cos(a) * 0.62, 0, Math.sin(a) * 0.62));
    }
    const logPts = [[0.45, -0.08], [0.45, 0.08], [-0.45, 0.08], [-0.45, -0.08]];
    const logArt = paintCard(logPts, {
      W: 384, H: 96, seed: 151, base: '#6b4a30', fills: ['rgba(107,74,48,A)', 'rgba(86,58,38,A)', 'rgba(130,92,60,A)'], edge: 'rgba(50,32,20,1)',
      details(g, px) {
        g.strokeStyle = 'rgba(40,26,16,0.6)'; g.lineWidth = 3;
        for (let k = 0; k < 5; k++) { const [a0, b0] = px(-0.4 + k * 0.18, 0.05), [a1, b1] = px(-0.3 + k * 0.18, -0.05); g.beginPath(); g.moveTo(a0, b0); g.lineTo(a1, b1); g.stroke(); }
        const [ex, ey] = px(0.41, 0); g.fillStyle = '#e8c88a'; g.beginPath(); g.ellipse(ex, ey, 10, 30, 0, 0, Math.PI * 2); g.fill(); // cut end
        g.fillStyle = '#e07a2e'; for (let k = 0; k < 4; k++) { const [cx, cy] = px(0.3 - k * 0.06, (k % 2 ? 0.03 : -0.03)); g.beginPath(); g.arc(cx, cy, 4, 0, Math.PI * 2); g.fill(); } // embers
      },
    });
    const logs = mergeGeometries([0, 1, 2].map((i) => cardGeometry(logPts, 0.04).rotateZ(Math.PI / 2 - 0.35).rotateY((i / 3) * Math.PI * 2 + 0.3).translate(0, 0.32, 0)));
    const flameShape = [[0, 0], [0.32, 0.25], [0.22, 0.7], [0.05, 1.05], [-0.12, 0.62], [-0.3, 0.3]];
    const flame = mergeGeometries([cardGeometry(flameShape, 0.02), cardGeometry(flameShape, 0.02).rotateY(Math.PI / 2)]);
    flame.deleteAttribute('uv');
    return [
      { geo: mergeGeometries(stones), mat: (mats().paperRock ||= cardMaterial(rockArt(rock, 63))) },
      { geo: logs, mat: (mats().paperLog ||= cardMaterial(logArt)) },
      { geo: flame.translate(0, 0.15, 0), mat: mats().flame, noShadow: true },
    ];
  },
  forge: () => [
    // a squat stone-and-clay furnace with a glowing mouth and a chimney
    { geo: mergeGeometries([box(1.7, 1.1, 1.3, 0, 0.55, 0), box(0.5, 1.2, 0.5, 0.45, 1.7, -0.25)]), mat: mats().stone },
    { geo: box(0.6, 0.45, 0.04, -0.2, 0.42, 0.66), mat: mats().flame, noShadow: true },
    { geo: mergeGeometries([box(1.8, 0.12, 1.4, 0, 1.16, 0), box(0.6, 0.1, 0.6, 0.45, 2.33, -0.25)]), mat: mats().dark },
  ],
  bed: () => [
    // a farmhouse bed: plank frame, a tall headboard, a patchwork quilt and a plump pillow
    { geo: mergeGeometries([box(1.2, 1.15, 0.1, 0, 0.58, -1.02), box(1.2, 0.75, 0.1, 0, 0.38, 1.02), box(1.1, 0.22, 2.0, 0, 0.3, 0),
      box(0.1, 0.12, 0.1, -0.5, 1.2, -1.02), box(0.1, 0.12, 0.1, 0.5, 1.2, -1.02)]), mat: mats().dark },
    { geo: box(1.12, 0.2, 1.6, 0, 0.5, 0.18), mat: mats().quilt },
    { geo: box(0.82, 0.17, 0.38, 0, 0.5, -0.76).translate(0, 0.02, 0), mat: mats().pillow },
  ],
  // a carved pumpkin: the garden pumpkin's printed card, with a grinning face cut through it that glows by night
  jack: () => {
    const pts = pumpkinSilhouette();
    const card = cardGeometry(pts, 0.05).scale(0.9, 0.9, 0.9);
    const eye = (x) => [[x - 0.08, 0.38], [x + 0.08, 0.38], [x, 0.5]];
    const mouth = [[-0.3, 0.24], [-0.18, 0.18], [-0.1, 0.24], [0, 0.16], [0.1, 0.24], [0.18, 0.18], [0.3, 0.24], [0.2, 0.12], [0, 0.08], [-0.2, 0.12]];
    const face = [eye(-0.16), eye(0.16), mouth].flatMap((s) => [0.03, -0.03].map((z) => cardGeometry(s, 0.01).scale(0.9, 0.9, 0.9).translate(0, 0, z)));
    const faceGeo = mergeGeometries(face.map((g) => { g.deleteAttribute('uv'); return g; }));
    return [
      { geo: mergeGeometries([card, card.clone().rotateY(Math.PI / 2)]), mat: (mats().jackCard ||= cardMaterial(pumpkinArt(pts, 191))) },
      { geo: mergeGeometries([faceGeo, faceGeo.clone().rotateY(Math.PI / 2)]), mat: jackGlow(), noShadow: true },
    ];
  },
  // an apple sapling: a staked little printed tree card (the orchard tree's own art, in miniature)
  sapling: () => {
    const k = propKinds().appletree;
    return [
      { geo: k.geometry.clone().scale(0.28, 0.28, 0.28), mat: k.material },
      { geo: mergeGeometries([box(0.05, 1.1, 0.05, 0.22, 0.55, 0), box(0.24, 0.04, 0.04, 0.11, 0.7, 0)]), mat: mats().dark },
    ];
  },
  // ...and what it grows into, two mornings later: a full apple tree of your own
  homeapple: () => [{ geo: propKinds().appletree.geometry.clone(), mat: propKinds().appletree.material }],
  trophy: () => {
    // a plank plaque on two posts with Old Whiskers mounted on it: a printed catfish card as long as a man is tall
    const fish = [[0.92, -0.02], [1.12, -0.2], [1.15, -0.16], [0.96, 0.0], [1.15, 0.18], [1.12, 0.22], [0.92, 0.03], [0.6, 0.2], [0.1, 0.26], [-0.5, 0.18], [-0.75, 0.32], [-0.9, 0.3], [-0.78, 0], [-0.9, -0.3], [-0.75, -0.32], [-0.5, -0.18], [0.1, -0.24], [0.6, -0.2]];
    const art = paintCard(fish, {
      W: 512, H: 192, seed: 171, base: '#6f7f62', fills: ['rgba(111,127,98,A)', 'rgba(90,104,80,A)', 'rgba(140,150,110,A)'], edge: 'rgba(40,48,34,1)',
      details(g, px) {
        const [bx0, by0] = px(-0.6, -0.05), [bx1] = px(0.7, 0); g.fillStyle = 'rgba(232,220,180,0.75)'; g.fillRect(bx0, by0, bx1 - bx0, 26); // pale belly
        g.fillStyle = 'rgba(40,50,34,0.5)'; for (let k = 0; k < 14; k++) { const [x, y] = px(-0.5 + k * 0.09, 0.08 + (k % 3) * 0.04); g.beginPath(); g.arc(x, y, 5, 0, Math.PI * 2); g.fill(); }
        const [ex, ey] = px(0.62, 0.06); g.fillStyle = '#f3ead6'; g.beginPath(); g.arc(ex, ey, 11, 0, Math.PI * 2); g.fill(); g.fillStyle = '#2b2018'; g.beginPath(); g.arc(ex + 2, ey, 6, 0, Math.PI * 2); g.fill();
        g.strokeStyle = '#2b2a24'; g.lineWidth = 4; // the whiskers, long and proud
        for (const [dy, ex2, ey2] of [[0.02, 1.13, 0.2], [-0.02, 1.13, -0.18]]) { const [a0, b0] = px(0.82, dy), [a1, b1] = px(ex2, ey2); g.beginPath(); g.moveTo(a0, b0); g.quadraticCurveTo((a0 + a1) / 2, b0 - 20, a1, b1); g.stroke(); }
      },
    });
    const plaquePts = [[-1.1, 0], [1.1, 0], [1.1, 0.8], [-1.1, 0.8]];
    const plaque = paintCard(plaquePts, {
      W: 512, H: 192, seed: 173, base: '#8a5a34', fills: ['rgba(138,90,52,A)', 'rgba(116,74,42,A)'], edge: 'rgba(60,36,20,1)',
      details(g, px) { const [x, y] = px(0, 0.1); g.fillStyle = '#efe3c4'; g.font = "bold 24px Georgia, serif"; g.textAlign = 'center'; g.fillText('~ OLD WHISKERS ~', x, y); },
    });
    return [
      { geo: mergeGeometries([box(0.12, 1.7, 0.12, -0.8, 0.85, -0.06), box(0.12, 1.7, 0.12, 0.8, 0.85, -0.06)]), mat: mats().dark },
      { geo: cardGeometry(plaquePts, 0.06).translate(0, 0.9, 0), mat: (mats().plaque ||= cardMaterial(plaque)) },
      { geo: cardGeometry(fish, 0.04).translate(0, 1.3, 0.06), mat: (mats().whiskers ||= cardMaterial(art)) },
    ];
  },
  snowman: () => {
    // a die-cut paper snowman, two printed cards slotted crosswise like the trees: three snowballs, twig arms,
    // a battered hat, coal eyes and buttons, a carrot nose and a red knitted scarf
    const pts = snowmanSilhouette();
    const art = paintCard(pts, {
      W: 384, H: 512, seed: 141, base: '#f6f3ec', fills: ['rgba(246,243,236,A)', 'rgba(226,228,236,A)', 'rgba(250,248,242,A)'], edge: 'rgba(120,124,150,1)',
      details(g, px) {
        // lilac shading low on each ball, where the light doesn't reach
        for (const [cy, r] of [[0.45, 0.5], [1.08, 0.36], [1.56, 0.25]]) {
          const [x, y] = px(0.08, cy - r * 0.35), [x2] = px(0.08 + r, 0);
          g.fillStyle = 'rgba(160,166,196,0.35)'; g.beginPath(); g.ellipse(x, y, (x2 - x) * 0.85, (x2 - x) * 0.45, 0, 0, Math.PI * 2); g.fill();
        }
        const dot = (x0, y0, r, col) => { const [x, y] = px(x0, y0); g.fillStyle = col; g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.fill(); };
        for (const [x0, y0] of [[-0.08, 1.62], [0.08, 1.62]]) dot(x0, y0, 7, '#2b2a30');
        for (const y0 of [1.18, 1.03, 0.88, 0.6]) dot(0, y0, 8, '#2b2a30');
        const [nx, ny] = px(0.0, 1.54), [tx] = px(0.2, 0);
        asLayer(g, () => { g.fillStyle = '#e07a2e'; g.beginPath(); g.moveTo(nx, ny - 7); g.lineTo(tx, ny + 4); g.lineTo(nx, ny + 7); g.fill(); }, 0.5);
        // scarf: a knitted band and a hanging end with stripes
        const [sx0, sy0] = px(-0.3, 1.38), [sx1, sy1] = px(0.3, 1.29);
        asLayer(g, () => {
          g.fillStyle = '#b5473a'; g.fillRect(sx0, sy0, sx1 - sx0, sy1 - sy0);
          const [ex, ey] = px(0.1, 1.33), [, ey2] = px(0, 1.02); g.fillRect(ex, ey, 26, ey2 - ey);
          g.fillStyle = '#efe3c4'; for (let k = 1; k < 4; k++) g.fillRect(ex, ey + ((ey2 - ey) * k) / 4, 26, 5);
        }, 0.7);
        // the hat
        const [hx0, hy0] = px(-0.36, 1.79), [hx1, hy1] = px(0.36, 1.74), [cx0, cy0] = px(-0.2, 2.0), [cx1, cy1] = px(0.2, 1.79);
        asLayer(g, () => { g.fillStyle = '#3a2e26'; g.fillRect(hx0, hy0, hx1 - hx0, hy1 - hy0); g.fillRect(cx0, cy0, cx1 - cx0, cy1 - cy0); g.fillStyle = '#d9a441'; g.fillRect(cx0, cy1 - 12, cx1 - cx0, 6); }, 0.6);
        // twig arms
        g.strokeStyle = '#6b4a30'; g.lineWidth = 5;
        for (const sgn of [1, -1]) { const [a0, b0] = px(0.36 * sgn, 1.14), [a1, b1] = px(0.9 * sgn, 1.29); g.beginPath(); g.moveTo(a0, b0); g.lineTo(a1, b1); g.stroke(); }
      },
    });
    const card = cardGeometry(pts, 0.05);
    return [{ geo: mergeGeometries([card, card.clone().rotateY(Math.PI / 2)]), mat: cardMaterial(art) }];
  },
  patch: () => [
    // a round mound of dark, well-dug soil ringed with a little stick edging, and a curling vine with broad leaves
    { geo: mergeGeometries([new THREE.CylinderGeometry(1.1, 1.25, 0.18, 16).translate(0, 0.09, 0)]), mat: (mats().soil ||= paperMaterial({ color: 0x5e4130 })) },
    { geo: mergeGeometries(Array.from({ length: 14 }, (_, i) => { const a = (i / 14) * Math.PI * 2; return box(0.06, 0.24, 0.06, Math.cos(a) * 1.22, 0.12, Math.sin(a) * 1.22); })), mat: mats().dark },
    { geo: mergeGeometries([0, 1, 2, 3, 4].map((k) => new THREE.CylinderGeometry(0.2, 0.24, 0.03, 7).scale(1, 1, 0.75).translate(Math.cos(k * 1.3 + 0.4) * 0.85, 0.2, Math.sin(k * 1.3 + 0.4) * 0.85))), mat: (mats().leaf ||= paperMaterial({ color: 0x6f8a4a })) },
  ],
  storehouse: () => [
    // a plank storehouse with a shake roof and a wide door, a crate and a barrel by the door
    { geo: mergeGeometries([box(2.6, 1.9, 2.2, 0, 0.95, 0), box(0.5, 0.5, 0.5, 1.0, 0.25, 1.5), box(0.4, 0.4, 0.4, 0.95, 0.7, 1.5)]), mat: mats().planks },
    { geo: mergeGeometries([new THREE.BoxGeometry(3.0, 0.08, 1.45).rotateX(0.55).translate(0, 2.2, 0.6), new THREE.BoxGeometry(3.0, 0.08, 1.45).rotateX(-0.55).translate(0, 2.2, -0.6),
      box(1.2, 1.5, 0.06, -0.3, 0.75, 1.12), new THREE.CylinderGeometry(0.24, 0.26, 0.6, 10).translate(-1.15, 0.3, 1.45)]), mat: mats().dark },
    { geo: mergeGeometries([box(1.4, 0.1, 0.07, -0.3, 1.55, 1.13), box(0.07, 1.5, 0.07, -0.95, 0.75, 1.14), box(0.07, 1.5, 0.07, 0.35, 0.75, 1.14)]), mat: (mats().cream ||= paperMaterial({ color: 0xefe5cc })) },
  ],
  woodlot: () => [
    // a woodcutter's lot: a chopping block with the axe bitten in, a sawbuck, and a rick of split logs
    { geo: mergeGeometries([new THREE.CylinderGeometry(0.32, 0.36, 0.5, 10).translate(-0.6, 0.25, 0.3), ...[-1, 1].flatMap((s) => [new THREE.BoxGeometry(0.07, 1.0, 0.07).rotateZ(s * 0.5).translate(0.55, 0.45, 0.25), new THREE.BoxGeometry(0.07, 1.0, 0.07).rotateZ(s * 0.5).translate(0.55, 0.45, -0.25)]),
      box(0.07, 0.07, 0.6, 0.55, 0.35, 0)]), mat: mats().dark },
    { geo: mergeGeometries([0, 1, 2, 3, 4, 5, 6, 7, 8].map((k) => new THREE.CylinderGeometry(0.1, 0.11, 0.9, 6).rotateX(Math.PI / 2).translate(-0.2 + (k % 3) * 0.22 - (Math.floor(k / 3) % 2) * 0.11, 0.1 + Math.floor(k / 3) * 0.19, -0.75))
      .concat([new THREE.CylinderGeometry(0.11, 0.12, 1.3, 7).rotateZ(Math.PI / 2).translate(0.55, 0.62, 0)])), mat: mats().planks },
    { geo: mergeGeometries([box(0.04, 0.5, 0.04, -0.6, 0.72, 0.3).rotateZ(0), box(0.05, 0.18, 0.2, -0.6, 0.55, 0.3)]), mat: (mats().iron ||= paperMaterial({ color: 0x8e9294 })) },
  ],
  quarry: () => [
    // a stone quarry: a cut face of rock, squared blocks stacked ready to haul, a pick leaning on them
    { geo: propKinds().rock.geometry.clone().scale(1.4, 1.2, 1.4).translate(-0.4, 0, -0.4), mat: propKinds().rock.material },
    { geo: mergeGeometries([box(0.5, 0.35, 0.4, 0.6, 0.18, 0.5), box(0.5, 0.35, 0.4, 0.6, 0.53, 0.45), box(0.5, 0.35, 0.4, 0.1, 0.18, 0.7), box(0.45, 0.3, 0.4, 1.0, 0.15, -0.1)]), mat: mats().stone },
    { geo: mergeGeometries([new THREE.BoxGeometry(0.05, 1.0, 0.05).rotateZ(-0.35).translate(0.95, 0.5, 0.75), new THREE.BoxGeometry(0.4, 0.06, 0.07).rotateZ(-0.35).translate(1.12, 0.98, 0.75)]), mat: mats().dark },
  ],
  weir: () => [
    // a fish weir: a V of stakes woven with withies, funnelling into a wicker trap, and a fish basket on the bank
    { geo: mergeGeometries([...[-1, 1].flatMap((s) => [0, 1, 2, 3, 4].map((k) => box(0.06, 0.9, 0.06, s * (0.25 + k * 0.22), 0.45, -0.3 + k * 0.18))),
      ...[-1, 1].flatMap((s) => [0.3, 0.6].map((y) => new THREE.BoxGeometry(1.0, 0.05, 0.04).rotateY(s * 0.7).translate(s * 0.68, y, 0.06)))]), mat: mats().dark },
    { geo: mergeGeometries([new THREE.CylinderGeometry(0.22, 0.12, 0.7, 9, 1, true).rotateX(Math.PI / 2).translate(0, 0.25, -0.55), new THREE.CylinderGeometry(0.26, 0.2, 0.32, 10).translate(1.1, 0.16, -0.75)]), mat: (mats().wicker ||= paperMaterial({ color: 0xc9a46a, side: THREE.DoubleSide })) },
    { geo: mergeGeometries([0, 1].map((k) => new THREE.BoxGeometry(0.26, 0.04, 0.09).translate(1.1, 0.34 + k * 0.03, -0.75 + k * 0.05))), mat: (mats().fishc ||= paperMaterial({ color: 0x8aa0a8 })) },
  ],
  charpit: () => [
    // a collier's charcoal pit: a low dome of turf and earth smouldering over a stack of wood, wisps of smoke
    // leaking from its vents, a rick of billets waiting, and a long rake
    { geo: mergeGeometries([new THREE.SphereGeometry(1.2, 12, 6, 0, Math.PI * 2, 0, Math.PI / 2).scale(1, 0.7, 1)]), mat: (mats().turf ||= paperMaterial({ color: 0x5a4a34 })) },
    { geo: mergeGeometries([...[0, 1, 2, 3, 4, 5, 6, 7].map((k) => new THREE.CylinderGeometry(0.08, 0.09, 0.9, 6).rotateX(Math.PI / 2).translate(1.5 + (k % 4) * 0.17, 0.09 + Math.floor(k / 4) * 0.16, -0.4)),
      new THREE.BoxGeometry(0.05, 0.05, 2.0).rotateX(0.35).translate(-1.4, 0.45, 0.2), box(0.5, 0.05, 0.08, -1.4, 0.08, 1.15)]), mat: mats().dark },
    { geo: mergeGeometries([0, 1, 2].map((k) => new THREE.SphereGeometry(0.16 + k * 0.05, 7, 5).translate(Math.cos(k * 2.1) * 0.5, 0.95 + k * 0.32, Math.sin(k * 2.1) * 0.5))), mat: (mats().smoke ||= paperMaterial({ color: 0xc8c2b8 })) },
  ],
  tannery: () => [
    // a tannery: a hide laced taut on a pole frame, two tan vats brimming with brown oak-bark liquor, a heap of bark
    { geo: mergeGeometries([box(0.09, 2.0, 0.09, -1.1, 1.0, -0.5), box(0.09, 2.0, 0.09, 0.1, 1.0, -0.5), box(1.4, 0.09, 0.09, -0.5, 1.9, -0.5), box(1.4, 0.09, 0.09, -0.5, 0.35, -0.5),
      ...[0, 1].map((k) => new THREE.CylinderGeometry(0.42, 0.38, 0.75, 12, 1, true).translate(0.6 + k * 0.9, 0.38, 0.55)),
      ...[0, 1, 2, 3, 4, 5].map((k) => new THREE.BoxGeometry(0.45, 0.05, 0.14).rotateY(k * 0.9).translate(-1.0 + (k % 3) * 0.18, 0.04 + Math.floor(k / 3) * 0.05, 0.7))]), mat: mats().dark },
    { geo: new THREE.PlaneGeometry(1.05, 1.3, 1, 1).translate(-0.5, 1.12, -0.48), mat: (mats().hide ||= paperMaterial({ color: 0xc9a074, side: THREE.DoubleSide })) },
    { geo: mergeGeometries([0, 1].map((k) => new THREE.CircleGeometry(0.4, 12).rotateX(-Math.PI / 2).translate(0.6 + k * 0.9, 0.7, 0.55))), mat: (mats().tanliquor ||= paperMaterial({ color: 0x5a3a20 })) },
  ],
  shack: () => [
    // a sugar shack: a board-and-batten shed with a long vented cupola on the ridge where the steam pours out,
    // stove wood stacked by the door, and a little sled with sap buckets
    { geo: mergeGeometries([box(2.4, 1.8, 2.0, 0, 0.9, 0), box(0.9, 0.5, 0.6, 1.6, 0.25, 0.9), ...[0, 1, 2, 3, 4, 5, 6].map((k) => new THREE.CylinderGeometry(0.09, 0.1, 0.8, 6).rotateX(Math.PI / 2).translate(-1.55 + (k % 4) * 0.2, 0.1 + Math.floor(k / 4) * 0.17, 0.3))]), mat: mats().planks },
    { geo: mergeGeometries([new THREE.BoxGeometry(2.8, 0.08, 1.3).rotateX(0.62).translate(0, 2.15, 0.52), new THREE.BoxGeometry(2.8, 0.08, 1.3).rotateX(-0.62).translate(0, 2.15, -0.52),
      box(1.6, 0.4, 0.5, 0, 2.6, 0), new THREE.BoxGeometry(1.8, 0.06, 0.4).rotateX(0.5).translate(0, 2.88, 0.18), new THREE.BoxGeometry(1.8, 0.06, 0.4).rotateX(-0.5).translate(0, 2.88, -0.18),
      box(0.7, 1.3, 0.05, -0.5, 0.65, 1.02), ...[-0.9, -0.3, 0.3, 0.9].map((x) => box(0.06, 1.8, 0.04, x, 0.9, 1.02))]), mat: mats().dark },
    { geo: mergeGeometries([0, 1].map((k) => new THREE.CylinderGeometry(0.16, 0.13, 0.3, 9).translate(1.4 + k * 0.4, 0.65, 0.9))), mat: (mats().iron ||= paperMaterial({ color: 0x8e9294 })) },
    { geo: mergeGeometries([0, 1, 2].map((k) => new THREE.SphereGeometry(0.3 + k * 0.08, 8, 6).scale(1.4, 0.7, 1).translate(-0.3 + k * 0.35, 3.1 + k * 0.45, 0))), mat: (mats().steam ||= paperMaterial({ color: 0xf3efe6 })) },
  ],
  kiln: () => [
    // a beehive brick kiln: a brick dome on a footing, an arched firebox mouth glowing with embers, a squat chimney,
    // and a stack of fresh bricks beside it
    { geo: mergeGeometries([new THREE.SphereGeometry(1.15, 14, 8, 0, Math.PI * 2, 0, Math.PI / 2).scale(1, 1.1, 1).translate(0, 0.35, 0), new THREE.CylinderGeometry(1.2, 1.25, 0.4, 14).translate(0, 0.2, 0),
      box(0.45, 0.9, 0.45, 0.3, 1.9, -0.3), ...[0, 1, 2, 3, 4, 5].map((k) => box(0.26, 0.09, 0.12, 1.25 + (k % 2) * 0.14, 0.05 + Math.floor(k / 2) * 0.1, 0.8 + (k % 3) * 0.13))]), mat: brickMat() },
    { geo: box(0.6, 0.55, 0.06, 0, 0.6, 1.15), mat: (mats().adit ||= paperMaterial({ color: 0x241c18 })) },
    { geo: box(0.44, 0.22, 0.04, 0, 0.45, 1.19), mat: (mats().ember ||= new THREE.MeshBasicNodeMaterial({ color: 0xff8a3a })) },
  ],
  sluice: () => {
    // a sluice box: a long plank trough on trestles, sloping down to the creek, with riffle slats across its floor
    // catching the gold as creek water carries the gravel over them; a feed flume at the top, a heap of gravel, a
    // shovel stood in it and a gold pan leaning on the trestle
    const tilt = 0.16, L = 3.6, trough = [], riffles = [];
    const T = (g) => g.rotateX(tilt).translate(0, 0.9, 0);
    trough.push(T(box(0.7, 0.06, L, 0, 0, 0)), T(box(0.06, 0.32, L, -0.35, 0.16, 0)), T(box(0.06, 0.32, L, 0.35, 0.16, 0)));
    for (let k = 0; k < 9; k++) riffles.push(T(box(0.62, 0.07, 0.05, 0, 0.06, -1.5 + k * 0.36)));
    return [
      { geo: mergeGeometries([...trough, ...riffles,
        box(0.08, 1.15, 0.08, -0.36, 0.58, -1.4), box(0.08, 1.15, 0.08, 0.36, 0.58, -1.4), box(0.08, 0.7, 0.08, -0.36, 0.35, 1.3), box(0.08, 0.7, 0.08, 0.36, 0.35, 1.3), // the trestle legs
        box(0.8, 0.06, 0.06, 0, 0.75, -1.4), box(0.8, 0.06, 0.06, 0, 0.45, 1.3),
        T(box(0.5, 0.3, 0.9, 0, 0.18, -2.2)), // the feed flume at the top
        box(0.05, 1.0, 0.05, 1.15, 0.5, -0.5), box(0.2, 0.26, 0.03, 1.15, 0.13, -0.5)]), mat: mats().planks }, // the shovel
      { geo: T(box(0.56, 0.03, L - 0.2, 0, 0.1, 0.1)), mat: (mats().sluiceWater ||= paperMaterial({ color: 0x8ab8c8 })) }, // creek water running down the trough
      { geo: new THREE.SphereGeometry(0.6, 9, 6, 0, Math.PI * 2, 0, Math.PI / 2).scale(1.1, 0.55, 0.9).translate(1.05, 0, -0.9), mat: (mats().gravel ||= paperMaterial({ color: 0x9a8a72, flatShading: true })) },
      { geo: new THREE.CylinderGeometry(0.28, 0.2, 0.07, 14).rotateX(1.2).translate(-0.52, 0.32, 1.15), mat: (mats().iron ||= paperMaterial({ color: 0x8e9294 })) }, // the pan
      { geo: mergeGeometries([0, 1, 2].map((k) => new THREE.SphereGeometry(0.035, 6, 4).translate(-0.1 + k * 0.09, 0.98 + 0.03 * k, 0.6 - k * 0.5).applyMatrix4(new THREE.Matrix4()))), mat: (mats().goldFleck ||= new THREE.MeshBasicNodeMaterial({ color: 0xf0c840 })) }, // a glint caught in the riffles
    ];
  },
  mill: () => {
    // a grist mill: a plank mill house with a shake roof, a flume on trestles, and a big undershot water wheel
    const spokes = [], paddles = [];
    for (let k = 0; k < 8; k++) { const a = (k / 8) * Math.PI * 2; spokes.push(new THREE.BoxGeometry(0.07, 2.1, 0.07).rotateX(a).translate(1.45, 1.3, 0)); }
    for (let k = 0; k < 12; k++) { const a = (k / 12) * Math.PI * 2; paddles.push(new THREE.BoxGeometry(0.42, 0.32, 0.05).rotateX(a).translate(1.45, 1.3 + Math.cos(a) * 1.05, Math.sin(a) * 1.05)); }
    return [
      { geo: mergeGeometries([box(2.2, 2.3, 2.2, 0, 1.15, 0), box(0.5, 0.06, 2.6, 1.0, 2.15, 0), ...paddles]), mat: mats().planks },
      { geo: mergeGeometries([new THREE.BoxGeometry(2.6, 0.08, 1.55).rotateX(0.6).translate(0, 2.65, 0.6), new THREE.BoxGeometry(2.6, 0.08, 1.55).rotateX(-0.6).translate(0, 2.65, -0.6),
        new THREE.TorusGeometry(1.05, 0.05, 4, 20).rotateY(Math.PI / 2).translate(1.42, 1.3, 0), new THREE.TorusGeometry(1.05, 0.05, 4, 20).rotateY(Math.PI / 2).translate(1.68, 1.3, 0), ...spokes,
        new THREE.CylinderGeometry(0.1, 0.1, 0.5, 8).rotateZ(Math.PI / 2).translate(1.3, 1.3, 0), box(0.07, 2.1, 0.07, 1.2, 1.05, 1.2), box(0.07, 2.1, 0.07, 1.2, 1.05, -1.2), box(0.8, 1.3, 0.05, 0, 0.65, 1.12)]), mat: mats().dark },
      { geo: mergeGeometries([box(0.5, 0.5, 0.06, -0.6, 1.5, 1.12), box(0.3, 0.2, 0.3, -0.6, 2.4, -0.6)]), mat: (mats().cream ||= paperMaterial({ color: 0xefe5cc })) },
    ];
  },
  beeyard: () => {
    // a bee yard: three straw skeps on a plank bench, a sunflower or two, and a smoker on an upturned crate
    const skep = BUILD.skep(); // reuse the bee skep's printed straw card for each hive
    const parts = [];
    for (const [x, z] of [[-0.8, 0], [0, -0.1], [0.8, 0.05]]) for (const q of skep) parts.push({ geo: q.geo.clone().scale(0.8, 0.8, 0.8).translate(x, 0.45, z), mat: q.mat });
    return [
      ...parts,
      { geo: mergeGeometries([box(2.4, 0.08, 0.5, 0, 0.42, 0), box(0.08, 0.42, 0.08, -1.1, 0.21, 0), box(0.08, 0.42, 0.08, 1.1, 0.21, 0), box(0.4, 0.4, 0.4, 1.4, 0.2, 0.7)]), mat: mats().dark },
      { geo: mergeGeometries([box(0.04, 1.4, 0.04, -1.5, 0.7, 0.6), box(0.04, 1.2, 0.04, -1.25, 0.6, 0.8)]), mat: (mats().stalk ||= paperMaterial({ color: 0x5e8040 })) },
      { geo: mergeGeometries([new THREE.CylinderGeometry(0.2, 0.2, 0.04, 12).rotateX(Math.PI / 2).translate(-1.5, 1.4, 0.62), new THREE.CylinderGeometry(0.17, 0.17, 0.04, 12).rotateX(Math.PI / 2).translate(-1.25, 1.2, 0.82)]), mat: (mats().sunflower ||= paperMaterial({ color: 0xe8b42e })) },
      { geo: new THREE.CylinderGeometry(0.1, 0.12, 0.28, 8).translate(1.4, 0.54, 0.7), mat: (mats().iron ||= paperMaterial({ color: 0x8e9294 })) },
    ];
  },
  diggings: () => [
    // ore diggings: a timbered adit into a heap of rock, a windlass over it, an ore cart on a short run of track
    { geo: propKinds().rock.geometry.clone().scale(1.6, 1.5, 1.4).translate(0, 0, -0.6), mat: propKinds().rock.material },
    { geo: mergeGeometries([box(0.14, 1.3, 0.14, -0.5, 0.65, 0.3), box(0.14, 1.3, 0.14, 0.5, 0.65, 0.3), box(1.25, 0.16, 0.16, 0, 1.3, 0.3),
      box(0.08, 1.0, 0.08, -0.4, 0.5, 1.0), box(0.08, 1.0, 0.08, 0.4, 0.5, 1.0), new THREE.CylinderGeometry(0.1, 0.1, 0.9, 8).rotateZ(Math.PI / 2).translate(0, 0.95, 1.0),
      box(0.06, 0.04, 1.6, -0.22, 0.03, 1.4), box(0.06, 0.04, 1.6, 0.22, 0.03, 1.4)]), mat: mats().dark },
    { geo: box(0.9, 1.05, 0.05, 0, 0.55, 0.26), mat: (mats().adit ||= paperMaterial({ color: 0x241c18 })) },
    { geo: mergeGeometries([box(0.55, 0.32, 0.7, 0, 0.3, 1.7), box(0.12, 0.12, 0.12, -0.2, 0.08, 1.45), box(0.12, 0.12, 0.12, 0.2, 0.08, 1.95)]), mat: (mats().iron ||= paperMaterial({ color: 0x8e9294 })) },
    { geo: mergeGeometries([0, 1, 2, 3].map((k) => new THREE.DodecahedronGeometry(0.11).translate(-0.15 + k * 0.1, 0.5, 1.6 + (k % 2) * 0.12))), mat: (mats().ore ||= paperMaterial({ color: 0xc46a32 })) },
  ],
  claypit: () => [
    // a clay pit: a dug hollow of red clay with a heap beside it, a spade standing in the heap, and a stack of drying bricks
    { geo: mergeGeometries([new THREE.CylinderGeometry(0.95, 0.8, 0.12, 14).translate(0, 0.04, 0), new THREE.SphereGeometry(0.55, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2).scale(1, 0.6, 0.8).translate(1.0, 0, 0.6)]), mat: (mats().clay ||= paperMaterial({ color: 0xb8693f })) },
    { geo: mergeGeometries([box(0.05, 0.9, 0.05, 1.05, 0.55, 0.6), box(0.18, 0.24, 0.03, 1.05, 0.12, 0.6)]), mat: mats().dark },
    { geo: mergeGeometries([0, 1, 2, 3, 4, 5].map((k) => box(0.26, 0.09, 0.12, -1.0 + (k % 3) * 0.28, 0.05 + Math.floor(k / 3) * 0.1, -0.7))), mat: (mats().brick ||= paperMaterial({ color: 0xa8553a })) },
  ],
  woodpile: () => [
    // a low plank base with a stout post at each end; the logs themselves are stacked by woodpile.js
    { geo: mergeGeometries([box(0.5, 0.06, 1.5, 0, 0.03, 0), box(0.1, 1.05, 0.1, 0, 0.52, -0.74), box(0.1, 1.05, 0.1, 0, 0.52, 0.74), box(0.36, 0.08, 0.08, 0, 0.98, -0.74), box(0.36, 0.08, 0.08, 0, 0.98, 0.74)]), mat: mats().dark },
  ],
  feeder: () => [
    // a little hanging bird-feeder house on a post: a seed tray with a lip, four corner posts, a pitched roof
    { geo: mergeGeometries([box(0.1, 1.5, 0.1, 0, 0.75, 0), box(0.62, 0.05, 0.5, 0, 1.52, 0), box(0.62, 0.06, 0.03, 0, 1.56, 0.25), box(0.62, 0.06, 0.03, 0, 1.56, -0.25),
      ...[[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([x, z]) => box(0.04, 0.32, 0.04, x * 0.27, 1.7, z * 0.21))]), mat: mats().planks },
    { geo: mergeGeometries([new THREE.BoxGeometry(0.76, 0.04, 0.36).rotateX(0.6).translate(0, 1.96, 0.14), new THREE.BoxGeometry(0.76, 0.04, 0.36).rotateX(-0.6).translate(0, 1.96, -0.14)]), mat: mats().dark },
    { geo: mergeGeometries([0, 1, 2, 3, 4, 5, 6, 7].map((k) => new THREE.SphereGeometry(0.03, 5, 4).translate(Math.cos(k * 2.4) * 0.18 * ((k % 3) / 3 + 0.3), 1.57, Math.sin(k * 2.4) * 0.14 * ((k % 3) / 3 + 0.3)))), mat: (mats().seed ||= paperMaterial({ color: 0xd9b45a })) },
  ],
  press: () => {
    // a farm cider press: two stout posts and a crossbeam, a big wooden screw with a turning bar, a slatted
    // basket of apples on a plank bed, a spout, and a crock to catch the cider
    const slats = [];
    for (let k = 0; k < 10; k++) { const a = (k / 10) * Math.PI * 2; slats.push(new THREE.BoxGeometry(0.09, 0.5, 0.035).rotateY(-a + Math.PI / 2).translate(Math.cos(a) * 0.34, 0.85, Math.sin(a) * 0.34)); }
    const apples = [];
    for (let k = 0; k < 7; k++) { const a = k * 2.4, r = k ? 0.18 : 0; apples.push(new THREE.SphereGeometry(0.1, 8, 6).translate(Math.cos(a) * r, 1.12 + (k % 3) * 0.05, Math.sin(a) * r)); }
    return [
      { geo: mergeGeometries([box(1.5, 0.12, 0.9, 0, 0.55, 0), box(0.14, 1.9, 0.14, -0.62, 0.95, 0), box(0.14, 1.9, 0.14, 0.62, 0.95, 0), box(1.5, 0.16, 0.2, 0, 1.82, 0),
        box(0.12, 0.5, 0.12, -0.6, 0.25, 0.35), box(0.12, 0.5, 0.12, 0.6, 0.25, 0.35), box(0.12, 0.5, 0.12, -0.6, 0.25, -0.35), box(0.12, 0.5, 0.12, 0.6, 0.25, -0.35),
        box(0.16, 0.06, 0.3, 0.0, 0.58, 0.58)]), mat: mats().planks },
      { geo: mergeGeometries([...slats, new THREE.CylinderGeometry(0.3, 0.3, 0.06, 14).translate(0, 1.36, 0), new THREE.CylinderGeometry(0.06, 0.06, 0.5, 8).translate(0, 1.6, 0), box(0.9, 0.06, 0.06, 0, 1.62, 0)]), mat: mats().dark },
      { geo: mergeGeometries(apples), mat: (mats().apple ||= paperMaterial({ color: 0xc4362f })) },
      { geo: new THREE.CylinderGeometry(0.16, 0.13, 0.3, 12).translate(0, 0.15, 0.78), mat: (mats().crock ||= paperMaterial({ color: 0xc9a26a })) },
    ];
  },
  skep: () => {
    // a printed straw skep (two slotted cards, coiled rings and a dark doorway) on a little plank stand
    const pts = skepSilhouette();
    const card = cardGeometry(pts, 0.04).scale(1.55, 1.55, 1.55);
    return [
      { geo: mergeGeometries([box(0.9, 0.08, 0.9, 0, 0.55, 0), ...[[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([x, z]) => box(0.08, 0.55, 0.08, x * 0.36, 0.27, z * 0.36))]), mat: mats().planks },
      { geo: mergeGeometries([card, card.clone().rotateY(Math.PI / 2)]).translate(0, 0.59, 0), mat: (mats().paperSkep ||= cardMaterial(skepArt(pts))) },
    ];
  },
  dock: () => [
    // a plank walkway on tarred posts, with a rope rail on two sides: walk out over water, or across it
    { geo: box(G, 0.16, G, 0, 0.08, 0), mat: mats().planks },
    { geo: mergeGeometries([[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([x, z]) => box(0.16, 3.3, 0.16, x * 0.9, -1.2, z * 0.9))), mat: mats().dark },
    { geo: mergeGeometries([-1, 1].map((s) => new THREE.CylinderGeometry(0.03, 0.03, G, 5).rotateZ(Math.PI / 2).translate(0, 0.72, s * 0.9))), mat: mats().straw },
  ],
  scarecrow: () => [
    // a burlap-headed scarecrow on a cross of rough poles, in an old flannel shirt and a battered straw hat
    { geo: mergeGeometries([box(0.12, 2.1, 0.12, 0, 1.05, 0), box(1.5, 0.1, 0.1, 0, 1.6, 0)]), mat: mats().dark },
    { geo: mergeGeometries([box(0.66, 0.7, 0.3, 0, 1.38, 0), box(1.3, 0.22, 0.26, 0, 1.6, 0)]), mat: mats().flannel },
    { geo: box(0.4, 0.42, 0.38, 0, 2.08, 0), mat: mats().burlap },
    { geo: mergeGeometries([new THREE.CylinderGeometry(0.42, 0.45, 0.04, 12).translate(0.03, 2.32, 0).rotateZ(-0.08),
      new THREE.CylinderGeometry(0.18, 0.22, 0.24, 10).translate(0.0, 2.44, 0),
      box(0.18, 0.06, 0.06, 0.74, 1.6, 0.05), box(0.18, 0.06, 0.06, -0.74, 1.56, -0.04), box(0.06, 0.2, 0.06, 0.08, 0.98, 0.1)]), mat: mats().straw },
  ],
  lantern: () => [
    { geo: mergeGeometries([box(0.14, 2.4, 0.14, 0, 1.2, 0), box(0.6, 0.1, 0.1, 0.25, 2.3, 0), box(0.38, 0.08, 0.38, 0.5, 2.22, 0)]), mat: mats().dark },
    { geo: box(0.3, 0.42, 0.3, 0.5, 1.98, 0), mat: mats().glass },
  ],
};

/** Outline of the snowman card: the union of three balls, twig arms and a hat, flat base at y = 0. */
function snowmanSilhouette() {
  const balls = [[0.45, 0.5], [1.08, 0.36], [1.56, 0.25]];
  const xAt = (y) => Math.max(0.02, ...balls.map(([cy, r]) => (Math.abs(y - cy) < r ? Math.sqrt(r * r - (y - cy) ** 2) : 0)));
  const right = [];
  for (let y = 0.03; y <= 1.74; y += 0.03) {
    right.push([Math.max(xAt(y), 0.3 * (y < 0.06)), y]);
    if (Math.abs(y - 1.11) < 0.015) right.push([0.88, 1.27], [0.93, 1.32], [0.37, 1.13]); // a twig arm
  }
  right.unshift([0.3, 0]);
  right.push([0.36, 1.74], [0.36, 1.79], [0.2, 1.79], [0.2, 2.0]);
  const left = right.map(([x, y]) => [-x, y]).reverse();
  return [...right, ...left];
}

/** The candlelit carving: deep orange, glowing gently after dark (never white-hot). */
let _jackGlow = null;
function jackGlow() {
  if (_jackGlow) return _jackGlow;
  _jackGlow = paperMaterial({ color: 0xe08a3a });
  _jackGlow.emissiveNode = vec3(0.9, 0.36, 0.08).mul(glowU).mul(0.75);
  return _jackGlow;
}

let _geoCache = {};
function partsFor(type) { return (_geoCache[type] ||= BUILD[type]()); }

// pieces made from the reference art (Meshy, from the mining and furniture sheets): the model stands in for the
// paper build, laid the same way, as long as it and centred on it, on the ground
const PIECE_MODELS = { sluice: 'mine_sluice', diggings: 'mine_entrance', workbench: 'prop_workbench', bed: 'furn_bed', scarecrow: 'prop_scarecrow', forge: 'prop_forge', snowman: 'prop_snowman' };
const LENGTHWISE = new Set(['sluice', 'bed']); // turned to lie as the paper build does; the rest keep their front (glTF +Z) forward
const _fit = {};
function modelFor(type) {
  if (type in _fit) return _fit[type];
  const src = PIECE_MODELS[type] && propModel(PIECE_MODELS[type]);
  if (!src) return (_fit[type] = null);
  const tb = new THREE.Box3(); for (const p of partsFor(type)) { p.geo.computeBoundingBox(); tb.union(p.geo.boundingBox); } // the paper build's box
  const mb = new THREE.Box3().setFromObject(src.scene), ms = mb.getSize(new THREE.Vector3()), ts = tb.getSize(new THREE.Vector3());
  const turn = LENGTHWISE.has(type) && (ms.x > ms.z) !== (ts.x > ts.z) ? Math.PI / 2 : 0; // lie the same way as the paper build
  const s = Math.max(ts.x, ts.z) / Math.max(ms.x, ms.z), mc = mb.getCenter(new THREE.Vector3()), tc = tb.getCenter(new THREE.Vector3());
  return (_fit[type] = { src, turn, s, mc, tc, minY: mb.min.y });
}

// the lantern post from the reference art (the props sheet): a timber post with an arm and a hanging lantern, 2.6 m
// tall, the post on the piece's spot and the lantern out over +x; a glowing core sits in the lantern for the night,
// and LAMP_AT tells the lights where the lantern hangs
let _lampFit;
export let LAMP_AT = [0.5, 1.9];
function lampPost() {
  if (_lampFit !== undefined) return _lampFit;
  const src = propModel('prop_lamppost');
  if (!src) return (_lampFit = null);
  const b = new THREE.Box3().setFromObject(src.scene), sz = b.getSize(new THREE.Vector3()), k = 2.6 / sz.y;
  // find the lantern: the mesh's points up high and out on the arm side (-x in the model)
  const v = new THREE.Vector3(), acc = new THREE.Vector3(); let n = 0;
  src.scene.updateWorldMatrix(true, true);
  src.scene.traverse((o) => { if (!o.isMesh) return; const P = o.geometry.attributes.position;
    for (let i = 0; i < P.count; i += 3) { v.fromBufferAttribute(P, i).applyMatrix4(o.matrixWorld); if (v.y > b.min.y + sz.y * 0.55 && v.y < b.min.y + sz.y * 0.9 && v.x < b.min.x + sz.x * 0.35) { acc.add(v); n++; } } });
  if (n) acc.divideScalar(n); else acc.set(b.min.x + 0.1, b.min.y + sz.y * 0.75, 0);
  const postX = b.max.x - sz.x * 0.08; // the post's middle, near the far side
  LAMP_AT = [(postX - acc.x) * k, (acc.y - b.min.y) * k]; // turned half round, the arm reaches out along +x
  return (_lampFit = { src, k, postX, minY: b.min.y, z: (b.min.z + b.max.z) / 2, lamp: acc.clone() });
}

export function makeMesh(type, ghostMat = null) {
  const L = type === 'lantern' && lampPost();
  if (L) {
    const g = new THREE.Group(), hold = new THREE.Group(), m = L.src.scene.clone();
    m.position.set(-L.postX, -L.minY, -L.z); hold.add(m); hold.scale.setScalar(L.k); hold.rotation.y = Math.PI; g.add(hold);
    const core = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.22, 0.16), ghostMat || mats().glass); core.position.set(LAMP_AT[0], LAMP_AT[1], (L.z - L.lamp.z) * L.k); g.add(core);
    if (ghostMat) m.traverse((o) => { if (o.isMesh) { o.material = ghostMat; o.castShadow = false; } });
    return g;
  }
  const F = modelFor(type);
  if (F) {
    const g = new THREE.Group(), hold = new THREE.Group(), m = F.src.scene.clone();
    m.position.set(-F.mc.x, -F.minY, -F.mc.z); hold.add(m); hold.rotation.y = F.turn; hold.scale.setScalar(F.s); hold.position.set(F.tc.x, 0, F.tc.z);
    if (ghostMat) m.traverse((o) => { if (o.isMesh) { o.material = ghostMat; o.castShadow = false; } }); // the placing preview
    g.add(hold); return g;
  }
  const g = new THREE.Group();
  for (const p of partsFor(type)) {
    const m = new THREE.Mesh(p.geo, ghostMat || p.mat);
    if (!ghostMat && !p.noShadow) { m.castShadow = true; m.receiveShadow = true; }
    g.add(m);
  }
  return g;
}

// ------------------------------------------------------------------ geometry helpers

const rotOf = (r) => (r * Math.PI) / 2;
function toLocal(piece, x, z) {
  const a = rotOf(piece.rot), c = Math.cos(a), s = Math.sin(a);
  const dx = x - piece.x, dz = z - piece.z;
  return [c * dx - s * dz, s * dx + c * dz];
}
function toWorldDir(piece, lx, lz) {
  const a = rotOf(piece.rot), c = Math.cos(a), s = Math.sin(a);
  return [c * lx + s * lz, -s * lx + c * lz];
}

// ------------------------------------------------------------------ system

const SAVE_KEY = 'paperfjord.builds.v1';
const FOLDED = -Math.PI / 2 + 0.02; // lying back on the page, a hair above it

export class BuildSystem {
  constructor(scene, camera) {
    this.scene = scene;
    this.camera = camera;
    this.pieces = [];
    this.group = new THREE.Group();
    scene.add(this.group);
    this.active = false;
    this.selected = 2; // floor
    this.rot = 0;
    this.roofManual = false; // set when the player rotates a roof by hand
    this.preview = null; // { type, x, y, z, rot, valid, reason }
    this.clock = 0; // game-time clock for hinge motion (deterministic, never wall time)
    this.closing = []; // pieces folding back down after removal
    this.hover = null; // piece under the crosshair (for removal)

    this.ghostColor = uniform(new THREE.Color(0x7fd18b));
    this.ghostMat = new THREE.MeshBasicNodeMaterial({ transparent: true, opacity: 0.5, depthWrite: false, fog: false });
    this.ghostMat.colorNode = this.ghostColor;
    this.ghost = null;
    this.ghostType = null;

    this.raycaster = new THREE.Raycaster();
    this.lightPool = Array.from({ length: 6 }, () => {
      const l = new THREE.PointLight(0xffa860, 0, 12, 1); // decay 1: no hot spots on flat paper
      scene.add(l);
      return l;
    });
  }

  get type() { return PIECE_ORDER[this.selected]; }

  // ---------------------------------------------------------------- queries used by the player

  /** Highest walkable surface under (x,z) that the player can step onto from height y. */
  surfaceAt(x, z, y) {
    let best = -Infinity;
    for (const p of this.nearby(x, z, 2)) {
      const def = PIECES[p.type];
      if (!def.surface) continue;
      const [lx, lz] = toLocal(p, x, z);
      if (Math.abs(lx) > 1 || Math.abs(lz) > 1) continue;
      const top = def.surface === 'floor' ? p.y + 0.2 : p.y + ((lz + 1) / 2) * WALL_H;
      if (top <= y + 0.65 && top > best) best = top;
    }
    return best;
  }

  /** Push a player circle out of solid pieces. Mutates pos. */
  collide(pos, radius = 0.32) {
    for (const p of this.nearby(pos.x, pos.z, 2.5)) {
      const def = PIECES[p.type];
      if (!def.solid) continue;
      const boxes = def.solid === 'door'
        ? [[-0.725, 0.275, 0.1, WALL_H], [0.725, 0.275, 0.1, WALL_H]] // [cx, hx, hz, h]
        : [[0, def.solid[0], def.solid[1], def.solid[2]]];
      for (const [cx, hx, hz, h] of boxes) {
        if (pos.y > p.y + h - 0.3 || pos.y + 1.7 < p.y) continue;
        let [lx, lz] = toLocal(p, pos.x, pos.z);
        lx -= cx;
        const qx = Math.max(-hx, Math.min(hx, lx)), qz = Math.max(-hz, Math.min(hz, lz));
        const dx = lx - qx, dz = lz - qz, d = Math.hypot(dx, dz);
        if (d >= radius) continue;
        let nx, nz, push;
        if (d > 1e-5) { nx = dx / d; nz = dz / d; push = radius - d; }
        else { // inside: leave along the shallow axis
          const ox = hx - Math.abs(lx), oz = hz - Math.abs(lz);
          if (ox < oz) { nx = Math.sign(lx) || 1; nz = 0; push = ox + radius; } else { nx = 0; nz = Math.sign(lz) || 1; push = oz + radius; }
        }
        const [wx, wz] = toWorldDir(p, nx, nz);
        pos.x += wx * push; pos.z += wz * push;
      }
    }
  }

  nearby(x, z, r) {
    const out = [];
    for (const p of this.pieces) if (Math.abs(p.x - x) < r + 1.5 && Math.abs(p.z - z) < r + 1.5) out.push(p);
    return out;
  }

  hasWorkbenchNear(x, z, r = 20) {
    return this.pieces.some((p) => p.type === 'workbench' && (p.x - x) ** 2 + (p.z - z) ** 2 < r * r);
  }

  // ---------------------------------------------------------------- placement

  /** Ray from the camera through the screen centre → { point, normal, piece } or null. */
  aim() {
    const cam = this.camera;
    const origin = cam.position.clone();
    const dir = cam.getWorldDirection(new THREE.Vector3());
    this.raycaster.set(origin, dir);
    this.raycaster.far = 40;
    let hit = null;
    const hits = this.raycaster.intersectObjects(this.group.children, true);
    if (hits.length) {
      let o = hits[0].object;
      while (o && !o.userData.piece) o = o.parent;
      const n = hits[0].face ? hits[0].face.normal.clone().transformDirection(hits[0].object.matrixWorld) : new THREE.Vector3(0, 1, 0);
      hit = { point: hits[0].point, normal: n, piece: o?.userData.piece || null, dist: hits[0].distance };
    }
    // march the terrain
    const p = new THREE.Vector3();
    let prevT = 0;
    for (let t = 0.5; t < 40; t += 0.35) {
      p.copy(origin).addScaledVector(dir, t);
      if (p.y < getHeight(p.x, p.z)) {
        let a = prevT, b = t;
        for (let k = 0; k < 10; k++) { const m = (a + b) / 2; p.copy(origin).addScaledVector(dir, m); if (p.y < getHeight(p.x, p.z)) b = m; else a = m; }
        p.copy(origin).addScaledVector(dir, b);
        if (!hit || b < hit.dist) hit = { point: p.clone(), normal: new THREE.Vector3(0, 1, 0), piece: null, dist: b };
        break;
      }
      prevT = t;
    }
    return hit;
  }

  /** Snap a hit to a placement for the selected piece type. */
  snap(hit) {
    const type = this.type, def = PIECES[type];
    let { x, z } = hit.point;
    let rot = this.rot;
    let px, pz;
    // a floor or roof aimed at a wall's side means the cell the wall encloses: reach through to the far side of it
    const atWallSide = def.snap === 'cell' && hit.piece && PIECES[hit.piece.type].solid && Math.abs(hit.normal.y) < 0.5;
    if (atWallSide) { x -= hit.normal.x * G * 0.5; z -= hit.normal.z * G * 0.5; }
    // a floor aimed at the edge of another floor carries on out from it, at its level (an upper storey spreads floor to floor)
    const atFloorSide = type === 'floor' && hit.piece && hit.piece.type === 'floor' && Math.abs(hit.normal.y) < 0.5;
    if (atFloorSide) { x += hit.normal.x * G * 0.5; z += hit.normal.z * G * 0.5; }
    if (def.snap === 'cell') { px = Math.floor(x / G) * G + G / 2; pz = Math.floor(z / G) * G + G / 2; }
    else if (def.snap === 'edge') {
      if (rot % 2 === 0) { pz = Math.round(z / G) * G; px = Math.floor(x / G) * G + G / 2; }
      else { px = Math.round(x / G) * G; pz = Math.floor(z / G) * G + G / 2; }
    } else { px = Math.round(x * 2) / 2; pz = Math.round(z * 2) / 2; }

    let y;
    if (hit.piece) {
      y = hit.normal.y > 0.6 ? hit.point.y : hit.piece.y;
      // stacking on a wall: land exactly on its top
      if (hit.normal.y > 0.6 && PIECES[hit.piece.type].solid) y = hit.piece.y + WALL_H;
      if (hit.normal.y > 0.6 && hit.piece.type === 'floor') y = hit.piece.y + 0.2;
      // aiming at stairs: a floor goes level with the stairs' top step (a landing), not on the slope
      if (hit.piece.type === 'stairs' && type === 'floor') y = hit.piece.y + WALL_H - 0.2;
    } else if (type === 'floor') {
      y = -Infinity;
      for (const [ox, oz] of [[-1, -1], [1, -1], [1, 1], [-1, 1], [0, 0]]) y = Math.max(y, getHeight(px + ox, pz + oz));
      // continue the level of a neighbouring floor if it's within a step or so above
      for (const p of this.pieces) {
        if (Math.abs(p.x - px) + Math.abs(p.z - pz) !== G) continue;
        if (p.type === 'floor' && p.y >= y - 0.01 && p.y < y + 1.6) y = Math.max(y, p.y);
        // the landing at the top of a neighbouring staircase
        if (p.type === 'stairs') y = Math.max(y, p.y + WALL_H - 0.2);
      }
    } else if (def.snap === 'edge') {
      const [ex, ez] = rot % 2 === 0 ? [1, 0] : [0, 1];
      y = Math.min(getHeight(px - ex, pz - ez), getHeight(px + ex, pz + ez), getHeight(px, pz)) - 0.05;
    } else {
      y = getHeight(px, pz);
    }
    // floors and roofs go up onto the walls round their cell: a roof always sits on the wall tops; a floor goes up to
    // them (a second storey) when it's aimed at the walls or at the ground floor inside them
    if (type === 'roof' || type === 'floor') {
      const tops = this.wallTopsAround(px, pz);
      if (tops.length) {
        if (type === 'roof') y = Math.max(...tops.filter((t) => t <= (hit.point?.y ?? y) + WALL_H + 0.5).concat(Math.min(...tops)));
        else if (atWallSide || (hit.piece && (hit.piece.type === 'floor' || PIECES[hit.piece.type].solid))) {
          const above = tops.filter((t) => t > (hit.piece ? hit.piece.y : y) + 0.5);
          if (above.length) y = Math.min(...above);
        }
      }
    }
    if (type === 'ridge') { // only onto a roof: the square its slope rises toward, sitting on its top edge, turned to match
      const r = hit.piece && (hit.piece.type === 'roof' ? hit.piece : null);
      if (!r) return { type, x: px, y, z: pz, rot, noRoof: true };
      const [ux, uz] = toWorldDir(r, 0, 1);
      return { type, x: r.x + Math.round(ux) * G, y: r.y + 1.15, z: r.z + Math.round(uz) * G, rot: r.rot };
    }
    y = Math.round(y * 20) / 20;
    if (type === 'roof' && !this.roofManual) rot = this.roofRotation(px, y, pz, rot);
    return { type, x: px, y, z: pz, rot };
  }

  /** The tops of the walls standing on the four edges of the cell centred on (cx, cz). */
  wallTopsAround(cx, cz) {
    const tops = [];
    for (const p of this.pieces) {
      if (PIECES[p.type].snap !== 'edge' || !PIECES[p.type].solid || p.type === 'fence') continue;
      const onEdge = p.rot % 2 === 0 ? Math.abs(p.x - cx) < 0.01 && Math.abs(Math.abs(p.z - cz) - G / 2) < 0.01
        : Math.abs(p.z - cz) < 0.01 && Math.abs(Math.abs(p.x - cx) - G / 2) < 0.01;
      if (onEdge) tops.push(p.y + WALL_H);
    }
    return tops;
  }

  /**
   * Pick the roof rotation that slopes up toward the middle of the structure below it, so
   * neighbouring roof cells meet in a ridge. Uses the centre of the floors and walls under the
   * roof's level; falls back to `fallback` when the cell sits on the centre line.
   */
  roofRotation(x, y, z, fallback) {
    let sx = 0, sz = 0, n = 0;
    for (const p of this.pieces) {
      if (p.type !== 'floor' && !PIECES[p.type].solid) continue;
      if (p.y < y - 3.6 || p.y > y + 0.3) continue;
      if (Math.abs(p.x - x) > 9 || Math.abs(p.z - z) > 9) continue;
      sx += p.x; sz += p.z; n++;
    }
    if (!n) return fallback;
    const dx = sx / n - x, dz = sz / n - z;
    if (Math.max(Math.abs(dx), Math.abs(dz)) < 0.25) return fallback;
    // local +z (the high edge) → world: rot 0 = +z, 1 = +x, 2 = −z, 3 = −x
    if (Math.abs(dx) > Math.abs(dz)) return dx > 0 ? 1 : 3;
    return dz > 0 ? 0 : 2;
  }

  validate(pl, inventory, player) {
    const def = PIECES[pl.type];
    if (pl.noRoof) return 'Aim at a roof: the ridge finishes it, peaking the next square up its slope';
    for (const k in def.cost) if ((inventory[k] || 0) < def.cost[k]) return `Needs ${costText(def.cost)}`;
    if (!def.free && !this.hasWorkbenchNear(pl.x, pl.z)) return 'Needs a workbench within 20 m';
    if (def.needsSnow && !(this.snow > 0.4)) return 'Needs snow on the ground';
    if (def.work && !this.discovered?.has(def.work)) return `Gather some ${def.work} yourself first`;
    if (def.needsWater && ![0, 1, 2, 3, 4, 5, 6, 7].some((k) => isWater(pl.x + Math.cos(k * 0.785) * 3.5, pl.z + Math.sin(k * 0.785) * 3.5))) return 'Build it beside running water (a creek or pond within a few strides)';
    if (this.pieces.some((p) => p.type === pl.type && p.x === pl.x && p.z === pl.z && Math.abs(p.y - pl.y) < 0.3 && (def.snap !== 'edge' || p.rot % 2 === pl.rot % 2))) return 'Already built here';
    if (def.snap === 'free' && this.pieces.some((p) => PIECES[p.type].snap === 'free' && Math.hypot(p.x - pl.x, p.z - pl.z) < 1.4 && Math.abs(p.y - pl.y) < 1)) return 'Too close to something';
    const d = Math.hypot(player.pos.x - pl.x, player.pos.z - pl.z);
    if (d > 14) return 'Too far away';
    if (def.solid && d < 0.9 && Math.abs(player.pos.y - pl.y) < 2) return 'You are standing there';
    return null;
  }

  update(dt, { inventory, player, night }) {
    glowU.value = THREE.MathUtils.smoothstep(night, 0.25, 0.8);
    this.updateLights(player.pos);

    if (!this.active) {
      if (this.ghost) this.ghost.visible = false;
      this.preview = null; this.hover = null;
      return;
    }
    if (this.ghostType !== this.type) {
      if (this.ghost) this.scene.remove(this.ghost);
      this.ghost = makeMesh(this.type, this.ghostMat);
      this.ghost.renderOrder = 2;
      this.scene.add(this.ghost);
      this.ghostType = this.type;
    }
    const hit = this.aim();
    this.hover = hit?.piece || null;
    if (!hit) { this.ghost.visible = false; this.preview = null; return; }
    const pl = this.snap(hit);
    pl.reason = this.validate(pl, inventory, player);
    pl.valid = !pl.reason;
    this.preview = pl;
    this.ghost.visible = true;
    this.ghost.position.set(pl.x, pl.y, pl.z);
    if (this.type === 'floor' && this.ghost.children[1]?.isMesh) this.ghost.children[1].visible = !this.onWallTops('floor', pl.x, pl.y, pl.z) && !(pl.y > getHeight(pl.x, pl.z) + 1.2 && this.pieces.some((q) => q.type === 'floor' && Math.abs(q.y - pl.y) < 0.06 && Math.abs(q.x - pl.x) + Math.abs(q.z - pl.z) === G && q.mesh?.children[1] && !q.mesh.children[1].visible));
    this.ghost.rotation.y = rotOf(pl.rot);
    this.ghostColor.value.setHex(pl.valid ? 0x7fd18b : 0xe0675a);
  }

  /** Try to place the previewed piece; spends inventory. Returns a message. */
  place(inventory) {
    const pl = this.preview;
    if (!pl) return null;
    if (!pl.valid) return pl.reason;
    const def = PIECES[pl.type];
    for (const k in def.cost) inventory[k] -= def.cost[k];
    this.add(pl);
    this.save(inventory);
    return `Built ${def.name.toLowerCase()}`;
  }

  remove(inventory) {
    const p = this.hover;
    if (!p) return null;
    const def = PIECES[p.type];
    for (const k in def.cost) inventory[k] = (inventory[k] || 0) + def.cost[k];
    this.foldAway(p); // folds back down onto the page, then disappears
    this.hover = null;
    this.save(inventory);
    return `Took down ${def.name.toLowerCase()} (refunded)`;
  }

  /**
   * The built piece the player would hit: nearest one in front within reach, whose height overlaps
   * the player's body (so the floor you stand on isn't targeted).
   */
  findTarget(pos, fwdX, fwdZ, reach) {
    let best = null, bestD = Infinity;
    for (const p of this.nearby(pos.x, pos.z, reach + 1.5)) {
      const [hx, hz, h] = FOOT[p.type];
      if (p.y + h < pos.y - 0.6 || p.y > pos.y + 1.9) continue;
      const [lx, lz] = toLocal(p, pos.x, pos.z);
      // standing on top of it?
      if (Math.abs(lx) <= hx && Math.abs(lz) <= hz && pos.y >= p.y + h - 0.35) continue;
      const qx = Math.max(-hx, Math.min(hx, lx)), qz = Math.max(-hz, Math.min(hz, lz));
      const [wx, wz] = toWorldDir(p, qx - lx, qz - lz);
      const d = Math.hypot(wx, wz);
      if (d > reach) continue;
      if (d > 0.05 && (wx * fwdX + wz * fwdZ) / d < 0.25) continue;
      if (d < bestD) { bestD = d; best = p; }
    }
    return best ? { piece: best, dist: bestD } : null;
  }

  /** Damage a piece. On breaking: removes it and refunds its cost. Returns { destroyed, refund }. */
  damage(p, amount, inventory) {
    p.hp = (p.hp ?? PIECE_HP[p.type]) - amount;
    p.shake = 1;
    if (p.hp > 0) return { destroyed: false };
    const def = PIECES[p.type];
    for (const k in def.cost) inventory[k] = (inventory[k] || 0) + def.cost[k];
    this.group.remove(p.mesh); // broken: it bursts into scraps rather than folding away
    this.pieces.splice(this.pieces.indexOf(p), 1);
    if (this.hover === p) this.hover = null;
    this.save(inventory);
    return { destroyed: true, refund: def.cost };
  }

  chipsFor(type) { return PIECE_CHIPS[type] || WOOD_CHIPS; }

  /** The nearest bed within r metres, or null. */
  /** Snowmen melt when the snow does: each folds down onto the page and is gone. */
  meltSnowmen() {
    for (const p of this.pieces.filter((q) => q.type === 'snowman')) this.foldAway(p);
  }

  /** The nearest bee skep within r metres, or null. */
  pressNear(pos, r = 2.3) { return this.pieces.find((p) => p.type === 'press' && Math.hypot(p.x - pos.x, p.z - pos.z) < r) || null; }
  skepNear(pos, r = 2.2) { return this.pieces.find((p) => p.type === 'skep' && Math.hypot(p.x - pos.x, p.z - pos.z) < r) || null; }

  /** Each morning every skep's bees fill another comb (up to 3 waiting). */
  /** Saplings grow into apple trees two mornings after planting; your trees ripen two apples each morning (up to 6). */
  tendTrees(day, time, onGrown) {
    for (const p of [...this.pieces]) {
      if (p.type === 'sapling') {
        p.day ??= day;
        if (day - p.day >= 2 && time >= 0.25) {
          this.foldAway(p);
          const t = this.add({ type: 'homeapple', x: p.x, y: p.y, z: p.z, rot: p.rot, stock: 2, day }); // hinges up, full grown
          onGrown?.(t);
        }
      } else if (p.type === 'homeapple') {
        p.stock ??= 2; p.day ??= day;
        if (day !== p.day && time >= 0.25) { p.day = day; p.stock = Math.min(6, p.stock + 2); }
      }
    }
  }

  /** The nearest of your own apple trees within r metres, or null. */
  appleTreeNear(pos, r = 2.6) { return this.pieces.find((p) => p.type === 'homeapple' && Math.hypot(p.x - pos.x, p.z - pos.z) < r) || null; }

  /** Each morning the birds eat a day's worth from every feeder. */
  tendFeeders(day, time) {
    for (const p of this.pieces) {
      if (p.type !== 'feeder') continue;
      p.stock ??= 0; p.day ??= day;
      if (day !== p.day && time >= 0.25) { p.day = day; p.stock = Math.max(0, p.stock - 1); }
    }
  }

  patchNear(pos, r = 2.6) { return this.pieces.find((p) => p.type === 'patch' && Math.hypot(p.x - pos.x, p.z - pos.z) < r) || null; }
  woodpileNear(pos, r = 2.2) { return this.pieces.find((p) => p.type === 'woodpile' && Math.hypot(p.x - pos.x, p.z - pos.z) < r) || null; }
  feederNear(pos, r = 2.2) { return this.pieces.find((p) => p.type === 'feeder' && Math.hypot(p.x - pos.x, p.z - pos.z) < r) || null; }

  tendSkeps(day, time) {
    for (const p of this.pieces) {
      if (p.type !== 'skep') continue;
      p.stock ??= 0; p.day ??= day;
      if (day !== p.day && time >= 0.25) { p.day = day; p.stock = Math.min(3, p.stock + 1); }
    }
  }

  bedNear(pos, r = 2.4) { return this.pieces.find((p) => p.type === 'bed' && Math.hypot(p.x - pos.x, p.z - pos.z) < r && Math.abs(p.y - pos.y) < 1.5) || null; }

  /**
   * Add a piece. It starts folded back flat on the page and rises about its base hinge with the world's
   * springy overshoot (paper moves by rotating about creases: nothing scales or stretches).
   * `upright` skips the rise (pieces loaded from a save).
   */
  add({ type, x, y, z, rot, stock, day, stage, tendDay }, upright = false) {
    const piece = { type, x, y, z, rot, stock, day, stage, tendDay, born: this.clock, risen: upright, hinge: upright ? 0 : FOLDED };
    const mesh = makeMesh(type);
    mesh.position.set(x, y, z);
    mesh.rotation.order = 'YXZ'; // yaw first, then the hinge about the piece's own base line
    mesh.rotation.y = rotOf(rot);
    mesh.rotation.x = piece.hinge;
    mesh.userData.piece = piece;
    piece.mesh = mesh;
    this.group.add(mesh);
    this.pieces.push(piece);
    if (!this.loading && (type === 'floor' || (PIECES[type].snap === 'edge' && PIECES[type].solid))) this.trimLegs();
    return piece;
  }

  /** A floor laid on the tops of the walls round it (a second storey) hangs on them: no legs under it. */
  onWallTops(type, x, y, z) { return type === 'floor' && this.wallTopsAround(x, z).some((t) => Math.abs(t - y) < 0.06); }
  trimLegs() {
    // legless: a floor on wall tops, or an upper floor carried on out from one, level with it (hung floor to floor)
    const floors = this.pieces.filter((p) => p.type === 'floor'), hung = new Set(floors.filter((p) => this.onWallTops('floor', p.x, p.y, p.z)));
    for (let grew = true; grew;) {
      grew = false;
      for (const p of floors) if (!hung.has(p) && p.y > getHeight(p.x, p.z) + 1.2 && floors.some((q) => hung.has(q) && Math.abs(q.y - p.y) < 0.06 && Math.abs(q.x - p.x) + Math.abs(q.z - p.z) === G)) { hung.add(p); grew = true; }
    }
    for (const p of floors) if (p.mesh?.children[1]?.isMesh) p.mesh.children[1].visible = !hung.has(p);
  }

  /** Take a piece out of play now (no collisions, no walking on it) and fold it back down onto the page. */
  foldAway(p) {
    this.pieces.splice(this.pieces.indexOf(p), 1);
    if (PIECES[p.type].snap === 'edge' && PIECES[p.type].solid) this.trimLegs(); // (a wall gone from under an upper floor: its legs come back)
    this.closing.push({ mesh: p.mesh, from: p.mesh.rotation.x, t: 0 });
  }

  animate(dt = 0.016) {
    this.clock += dt;
    for (const p of this.pieces) {
      if (!p.risen) {
        const t = this.clock - p.born;
        p.hinge = (1 - springRise(t)) * FOLDED;
        if (t > 1.3) { p.risen = true; p.hinge = 0; }
      }
      let x = p.hinge, z = 0;
      if (p.shake > 0) {
        p.shake = Math.max(0, p.shake - dt / 0.35);
        z = Math.sin(this.clock * 45) * 0.035 * p.shake;
        x += Math.cos(this.clock * 50) * 0.02 * p.shake;
      }
      p.mesh.rotation.x = x;
      p.mesh.rotation.z = z;
    }
    // closing is the reverse: fall back flat (softer, no overshoot), then leave the page
    for (let i = this.closing.length - 1; i >= 0; i--) {
      const c = this.closing[i];
      c.t += dt;
      const k = Math.min(1, c.t / 0.45);
      c.mesh.rotation.x = c.from + (FOLDED - c.from) * k * k;
      if (k >= 1) { this.group.remove(c.mesh); this.closing.splice(i, 1); }
    }
  }

  updateLights(center) {
    const emitters = this.pieces.filter((p) => PIECES[p.type].light)
      .map((p) => [p, (p.x - center.x) ** 2 + (p.z - center.z) ** 2])
      .sort((a, b) => a[1] - b[1]);
    const t = performance.now() * 0.001;
    this.lightPool.forEach((l, i) => {
      const e = emitters[i];
      if (!e || e[1] > 60 * 60) { l.intensity = 0; return; }
      const p = e[0];
      if (PIECES[p.type].light === 'jack') {
        // a candle inside the pumpkin: a small, warm, wavering glow after dark
        l.position.set(p.x, p.y + 0.4, p.z);
        l.color.setHex(0xff8a30);
        l.intensity = glowU.value * (2.6 + Math.sin(t * 9 + i) * 0.5 + Math.sin(t * 21) * 0.3);
        l.distance = 6;
      } else if (PIECES[p.type].light === 'fire') {
        l.position.set(p.x, p.y + 0.8, p.z);
        l.color.setHex(0xff9a48);
        l.intensity = 5 + Math.sin(t * 11 + i) * 1 + Math.sin(t * 23) * 0.6;
        l.distance = 10;
      } else {
        const [ox, oz] = toWorldDir(p, LAMP_AT[0], 0);
        l.position.set(p.x + ox, p.y + LAMP_AT[1], p.z + oz);
        l.color.setHex(0xffa860);
        l.intensity = glowU.value * 4.5;
        l.distance = 11;
      }
    });
  }

  /** Distance to the nearest campfire (Infinity if none). */
  fireDistance(pos) {
    let d = Infinity;
    for (const p of this.pieces) if (p.type === 'campfire') d = Math.min(d, Math.hypot(p.x - pos.x, p.z - pos.z));
    return d;
  }

  /** Is (x, z) under a built roof? */
  roofAt(x, z) {
    for (const p of this.nearby(x, z, 1.2)) {
      if (p.type !== 'roof' && p.type !== 'ridge') continue;
      const [lx, lz] = toLocal(p, x, z);
      if (Math.abs(lx) < 1.1 && Math.abs(lz) < 1.1) return true;
    }
    return false;
  }

  /** Is the player warming by a campfire? */
  /** Is a station (workbench, campfire, forge) within `r` metres? */
  stationNear(type, pos, r = 7) {
    return this.pieces.some((p) => p.type === type && (p.x - pos.x) ** 2 + (p.z - pos.z) ** 2 < r * r);
  }

  nearFire(pos) {
    return this.pieces.some((p) => p.type === 'campfire' && (p.x - pos.x) ** 2 + (p.z - pos.z) ** 2 < 16);
  }

  // ---------------------------------------------------------------- persistence

  save(inventory, extra = {}) {
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify({
        pieces: this.pieces.map(({ type, x, y, z, rot, stock, day, stage, tendDay }) => ({ type, x, y, z, rot, stock, day, stage, tendDay })),
        inventory, ...this.extraSave, ...extra,
      }));
    } catch { /* storage unavailable: builds just won't persist */ }
  }

  load() {
    try {
      const data = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null');
      if (!data) return null;
      this.loading = true; for (const p of data.pieces || []) if (PIECES[p.type]) this.add(p, true); this.loading = false; this.trimLegs();
      return data;
    } catch { return null; }
  }
}

/** A cost as HTML: anything you're short of is inked in red, with how many you have. */
export function costHTML(cost, inv = {}) {
  return Object.entries(cost).map(([k, v]) => ((inv[k] || 0) >= v ? `${v} ${k}` : `<span class="short">${v} ${k} <i>(${inv[k] || 0})</i></span>`)).join(', ');
}
export function costText(cost) {
  return Object.entries(cost).map(([k, v]) => `${v} ${k}`).join(', ');
}
