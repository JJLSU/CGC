// The world is a stacked torn-paper landscape, like a layered paper topographic model: every 0.6 m of
// height is its own flat sheet, its outline a ragged torn contour (marching triangles over a 0.5 m grid),
// with the sheet's paper thickness showing as a cream wall and a white fibrous lip along the tear, casting
// a real shadow onto the sheet below. No slopes, no facets.
//
// A region field (water / meadow / forest / crop field / highland / peaks + footpaths) is painted into one
// wrapping region map as chunks stream in; the sheets print it (washes, paths, fields) in the shader.
// Props are die-cut cards that rise on their hinges with a springy overshoot when their chunk appears.
import * as THREE from 'three/webgpu';
import { propModel } from './modelfolk.js';
import { makeNoise, fbm, ridged, smoothstep, mulberry32, hash2 } from './noise.js';
import { groundMaterial, fieldKindAt } from './materials.js';
import { attribute, screenCoordinate, fract, float, select } from 'three/tsl';
import { propKinds } from './props.js';
import { UNIQUES, landmarkColliders } from './landmarks.js';

export const CHUNK = 32;
export const WATER_LEVEL = 0;
export const MAP = 256; // region map size (texels = metres), wraps toroidally around the player
const CUTS = { rock: 3, bush: 3, pine: 3, flowers: 3 }; // (props drawn in several cuts, each its own instanced pool, so a field of them isn't one stamp)
const ROCK_MODELS = { lodge: ['prop_beaverlodge', 1.15] }; // (the iron and silver veins keep their printed paper rocks: the models read too solid among the cards)
const POOL_CAP = { sang: 200, silver: 200, pearl: 300, geode: 200, amber: 200, snag: 400, lodge: 40, birch: 1100, signthicket: 120, log: 500, bale: 400, stook: 700, ore: 600, quartz: 200, clay: 900, mushroom: 900, hive: 300, satchel: 60, appletree: 500, apples: 700, cattail: 1500, lilypad: 1400, lilybloom: 400, corn: 120, pumpkin: 60, signvein: 120, signgrove: 160, pine: 2200, maple: 1800, goldtree: 1500, sagetree: 1100, grass: 2600, flowers: 2200, bush: 1300, rock: 1300, hill: 1300, peak: 900 };
// trees are stretched taller (height only) so the woods tower over the farmer
const TALL = { snag: 1.25, birch: 1.3, pine: 1.35, maple: 1.35, goldtree: 1.35, sagetree: 1.35, appletree: 1.3 };
// [height, half-width] of the cards that can hide the farmer from the camera
const OCCLUDERS = { silver: [1.4, 0.6], snag: [5.2, 0.6], birch: [5.6, 1.0], ore: [1.4, 0.6], quartz: [1.4, 0.6], pine: [5.7, 1.3], maple: [5.9, 1.35], goldtree: [5.9, 1.35], appletree: [5.7, 1.35], sagetree: [5.9, 1.35], hill: [3.6, 4.2], peak: [6.0, 4.8], rock: [1.4, 0.6] };
const VIEW_RADIUS = 3; // chunks: ~100 m, so a free camera looking out sees a full landscape before the haze
let SEED = 20261120;  // the world's seed: each new game rolls its own (see setWorldSeed)
let RING = [130, 210]; // where the wild lands begin and where they're fully wild (m from the origin)

let nCont, nHill, nRidge, nMoist, nPath, nField, nLandA, nLandB, nMarsh, nTear, nTear2, nRange, nRange2;
function makeNoises() {
  nCont = makeNoise(SEED); nHill = makeNoise(SEED + 1); nRidge = makeNoise(SEED + 2); nMoist = makeNoise(SEED + 3);
  nPath = makeNoise(SEED + 4); nField = makeNoise(SEED + 5);
  nLandA = makeNoise(SEED + 71); nLandB = makeNoise(SEED + 72); nMarsh = makeNoise(SEED + 73);
  nTear = makeNoise(SEED + 9); nTear2 = makeNoise(SEED + 10); nRange = makeNoise(SEED + 77); nRange2 = makeNoise(SEED + 78);
}
makeNoises();
/**
 * Pick the world: its seed (every lake, hill, land, landmark and treasure follows from it) and where the wild
 * lands begin. Call before the World is made. Old saves keep 20261120 and the original far-off ring.
 */
export function setWorldSeed(seed, ring = RING) { SEED = seed >>> 0; RING = ring; makeNoises(); latCache.clear(); fullCache.clear(); }
export function worldSeed() { return { seed: SEED, ring: [...RING] }; }

// ---------------------------------------------------------------- the lands beyond the county
// Close to home the country is the farm county: fields, woods, meadows. Further out (from about 130 m) the
// wild lands begin, each a broad province carved out by two slow noise fields, so a walk in any direction
// eventually crosses into somewhere else, with its own lie of the land, its own colours, its own trees, its own
// mysterious treasure and the strange creature of the old tales that keeps it.
export const LANDS = {
  home: { name: 'the home county', tint: [1, 1, 1] },
  hollows: { name: 'the Silver Birch Hollows', tint: [0.96, 1.04, 1.06], lore: 'White birches crowd the hollows like a congregation of ghosts. Something here walks only when you are not looking.' },
  breaks: { name: 'the Redrock Breaks', tint: [1.12, 0.8, 0.72], lore: 'Rust-red rock, split and stacked like old bread. The prospectors say there is silver in it, and something that walks the hillsides lopsided.' },
  fen: { name: 'the Misty Fen', tint: [0.84, 0.95, 0.9], lore: 'Black water, dead snags and a cold mist. Pearls lie in the mussel beds, and the Hodag keeps them.' },
  prairie: { name: 'the Golden Prairie', tint: [1.12, 1.02, 0.78], lore: 'Grass to your belt as far as you can see. Thunder eggs lie out in the open, and the coyotes run in packs.' },
  pines: { name: 'the Bluepine Highlands', tint: [0.76, 0.9, 1.14], lore: 'High blue timber, cold and quiet. Old pines weep amber here, and the wampus cat hunts the ridges.' },
};
const LAND_IDS = ['hollows', 'breaks', 'fen', 'prairie', 'pines'];
const _land = { id: 'home', wild: 0, w: { hollows: 0, breaks: 0, fen: 0, prairie: 0, pines: 0 } };
/**
 * Which land (x, z) lies in: { id, wild (0 at home .. 1 out in the wilds), w: per-land weight (0..1, soft at
 * the borders) }. The returned object is reused; copy what you need.
 */
export function landAt(x, z) {
  const r = Math.hypot(x, z);
  const wild = smoothstep(RING[0], RING[1], r);
  for (const k of LAND_IDS) _land.w[k] = 0;
  if (wild <= 0) { _land.id = 'home'; _land.wild = 0; _land.edge = 0.5; return _land; }
  const a = fbm(nLandA, x * 0.0026, z * 0.0026, 2), b = fbm(nLandB, x * 0.0026, z * 0.0026, 2);
  const s = ((Math.atan2(b, a) + Math.PI) / (Math.PI * 2)) * 5, i = Math.floor(s) % 5, f = s - Math.floor(s);
  // soft borders: blend into the neighbouring land over the last 18 % of each sector
  const nb = f > 0.5 ? (i + 1) % 5 : (i + 4) % 5, edge = f > 0.5 ? 1 - f : f, k = 0.5 + 0.5 * smoothstep(0, 0.18, edge);
  _land.w[LAND_IDS[i]] = k * wild; _land.w[LAND_IDS[nb]] = (1 - k) * wild;
  _land.id = wild > 0.5 ? LAND_IDS[i] : 'home'; _land.wild = wild; _land.edge = edge;
  return _land;
}
/** The land's colour tint at (x, z), blended at the borders (r, g, b multipliers). */
export function landTint(x, z, out = [1, 1, 1]) {
  const L = landAt(x, z); out[0] = out[1] = out[2] = 1 - L.wild;
  for (const k of LAND_IDS) { const w = L.w[k]; if (!w) continue; const t = LANDS[k].tint; out[0] += t[0] * w; out[1] += t[1] * w; out[2] += t[2] * w; }
  return out;
}

const WOOD_CHIPS = [0x7b5236, 0xefe5cc, 0xc98a4a];
// seconds until a gathered prop pops back up from the page (the countryside mends itself, slowly)
const CROPS = new Set(['corn', 'pumpkin', 'apples', 'berries', 'stook']);
export const REGROW = { sang: 900, silver: 1200, pearl: 900, geode: 1500, amber: 1000, snag: 420, birch: 300, stook: 240, apples: 150, appletree: 320, corn: 100, pumpkin: 150, grass: 45, bush: 90, mushroom: 120, clay: 150, maple: 300, goldtree: 300, sagetree: 320, pine: 340, rock: 360, ore: 480, quartz: 1400, hive: 480 };

export const RESOURCE_TYPES = {
  pine: { name: 'Pine', hp: 4, item: 'wood', loot: [3, 5], radius: 0.35, falls: true, chips: [0x5d7a4c, 0x7b5236, 0xefe5cc] },
  maple: { name: 'Maple', hp: 3, item: 'wood', loot: [2, 4], radius: 0.35, falls: true, chips: [0xd9773a, 0xb8452e, ...WOOD_CHIPS] },
  snag: { name: 'Dead snag', hp: 2, item: 'wood', loot: [2, 3], radius: 0.25, falls: true, chips: [0xaaa397, 0x6a6258, 0xd8cdb0] },
  birch: { name: 'White birch', hp: 3, item: 'wood', loot: [2, 3], radius: 0.25, falls: true, chips: [0xefe9dc, 0x2b2622, 0xe8c84a] },
  goldtree: { name: 'Aspen', hp: 3, item: 'wood', loot: [2, 4], radius: 0.35, falls: true, chips: [0xd9a441, 0xe8be5a, ...WOOD_CHIPS] },
  sagetree: { name: 'Oak', hp: 4, item: 'wood', loot: [3, 4], radius: 0.35, falls: true, chips: [0x93a35c, 0xc9a24c, ...WOOD_CHIPS] },
  rock: { name: 'Rock outcrop', hp: 5, item: 'stone', loot: [2, 4], radius: 0.9, falls: false, chips: [0xb0a594, 0x7f7466, 0xefe5cc] },
  bush: { name: 'Berry bush', hp: 1, item: 'berries', loot: [2, 3], radius: 0.6, falls: false, chips: [0x3f7d74, 0xc4363a, 0xefe5cc] },
  flowers: { name: 'Wildflowers', decor: true, radius: 0 },
  grass: { name: 'Tall grass', hp: 1, item: 'fiber', loot: [1, 2], radius: 0.25, falls: false, minor: true, chips: [0x9aa564, 0xc3b46a, 0xefe5cc] },
  clay: { name: 'Clay bank', hp: 2, item: 'clay', loot: [2, 3], radius: 0.6, falls: false, chips: [0xb8693f, 0xcc8254, 0xefe5cc] },
  mushroom: { name: 'Toadstools', hp: 1, item: 'mushrooms', loot: [2, 3], radius: 0.35, falls: false, chips: [0xc4362f, 0xefe3cc, 0xf6efe0] },
  ore: { name: 'Iron vein', hp: 6, item: 'ore', loot: [2, 4], radius: 0.9, falls: false, needs: 'pickaxe', chips: [0x8f8a86, 0xc46a32, 0xe0a050] },
  quartz: { name: 'Gold quartz', hp: 8, item: 'gold', loot: [1, 2], radius: 0.9, falls: false, needs: 'pickaxe', chips: [0xe6dccb, 0xf0c840, 0xc8901e] },
  hive: { name: 'Wild hive', hp: 2, item: 'honey', loot: [2, 3], radius: 0.45, falls: false, chips: [0xd9a948, 0x7b5236, 0xefe5cc] },
  appletree: { name: 'Apple tree', hp: 3, item: 'wood', loot: [2, 3], radius: 0.35, falls: true, chips: [0x7d9a4e, 0xc4362f, ...WOOD_CHIPS] },
  apples: { name: 'Windfall apples', hp: 1, item: 'apples', loot: [2, 4], radius: 0.4, falls: false, chips: [0xc4362f, 0xe0a03a, 0xefe5cc] },
  satchel: { name: 'Lost satchel', hp: 1, item: 'satchel', loot: [1, 1], radius: 0.4, falls: false, chips: [0x8a5a34, 0xc4362f, 0xd9a441] },
  cattail: { name: 'Cattails', decor: true, radius: 0 },
  lodge: { name: 'Beaver lodge', decor: true, radius: 0 },
  log: { name: 'Fallen log', decor: true, radius: 0 },
  bale: { name: 'Hay bale', decor: true, radius: 0 },
  stook: { name: 'Wheat stook', hp: 1, item: 'wheat', loot: [2, 3], radius: 0.45, falls: false, chips: [0xb07f3a, 0xecd08a, 0xefe5cc] },
  lilypad: { name: 'Lily pad', decor: true, radius: 0, flat: true },
  lilybloom: { name: 'Water lily', decor: true, radius: 0, flat: true },
  corn: { name: 'Sweet corn', hp: 1, item: 'corn', loot: [1, 2], radius: 0.3, falls: false, chips: [0x8a9a4e, 0xe8c04a, 0xefe5cc] },
  pumpkin: { name: 'Pumpkin', hp: 2, item: 'pumpkin', loot: [1, 1], radius: 0.45, falls: false, chips: [0xde7a32, 0x7d9150, 0xefe5cc] },
  signvein: { name: 'Sign', decor: true, radius: 0 },
  signgrove: { name: 'Sign', decor: true, radius: 0 },
  signthicket: { name: 'Sign', decor: true, radius: 0 },
  hill: { name: 'Hill', decor: true, radius: 0 },
  // the wild lands' treasures
  sang: { name: 'Wild ginseng', hp: 1, item: 'sang', loot: [1, 2], radius: 0.35, falls: false, chips: [0x5e7e40, 0xc4362f, 0xefe5cc] },
  silver: { name: 'Silver vein', hp: 8, item: 'silver', loot: [1, 2], radius: 0.9, falls: false, needs: 'pickaxe', chips: [0xb85a3a, 0xd8dde2, 0xf4f6f8] },
  pearl: { name: 'Mussel bed', hp: 2, item: 'pearl', loot: [1, 1], radius: 0.5, falls: false, chips: [0x3a4a5a, 0xefe9e0, 0x9ab0c0] },
  geode: { name: 'Thunder egg', hp: 4, item: 'geode', loot: [1, 1], radius: 0.6, falls: false, chips: [0xa89880, 0x8a6ab8, 0xe8e0f0] },
  amber: { name: 'Weeping pine stump', hp: 3, item: 'amber', loot: [1, 2], radius: 0.5, falls: false, chips: [0x7b5236, 0xe0a030, 0xf6d070] },
  peak: { name: 'Peak', decor: true, radius: 0 },
};

// ---------------------------------------------------------------- region field

/** The old "height" survives as a region field: water below WATER_T, highland and peaks above. */
// ---------------------------------------------------------------- the mountains
// Gold country is high country: the county is a web of connected valleys between great mountain ridges no one can
// climb. The ridges run in long broken lines (a ridged noise, cut into lengths by a second one), so there is always
// a way round, through a gap or along a valley; the home valley lies clear for a good way round the farm and the
// town, and past the last valleys an outer wall closes the world. rangeAt is 0 in the valleys and 1 on the crests;
// past RANGE_STOP (the foot of the steep slope) neither you nor the horse can climb.
export const RANGE_STOP = 0.24;
const RANGE_H = 30; // (metres the crests stand above the valley floor, in stacked paper sheets)
// the home valley is centred on the farm (set once the spawn is found; the origin till then)
const RC = { x: 0, z: 0 };
export function setRangeCenter(x, z) { RC.x = x; RC.z = z; latCache.clear(); fullCache.clear(); }
function rangeMaskL(x, z, L) {
  const r0 = Math.hypot(x, z), r = Math.hypot(x - RC.x, z - RC.z), outerR = 950 + Math.hypot(RC.x, RC.z) * 0.5;
  const warp = fbm(nRange, x * 0.018, z * 0.018, 2) * 16; // (a ragged foot, never a ruled line)
  // the ridges: crests along the ridged noise's lines, broken into lengths with gaps between
  const rn = ridged(nRange, x * 0.0038 + 3.1, z * 0.0038 - 1.7, 3);
  const breaks = smoothstep(-0.2, 0.05, fbm(nRange2, x * 0.0032, z * 0.0032, 2));
  let m = smoothstep(0.5, 0.72, rn + warp * 0.004) * breaks;
  m *= smoothstep(150, 210, r + warp); // (the home valley clear round the farm and the town)
  // the outer wall
  const wall = smoothstep(outerR - 30, outerR, r0 + warp);
  return wall > m ? wall : m;
}
let _lastRange = 0;
// The mountains are folded paper: their height lives on the nodes of a coarse lattice and runs flat between them, so
// every slope is a big flat facet with a sharp crease at its edges, near or far (the far mesh in ranges.js is built
// on the very same lattice, so the two always agree).
export const LAT = 6;
const latCache = new Map();
function mtnNode(i, j) {
  const k = i * 100003 + j; let v = latCache.get(k);
  if (v === undefined) {
    const x = i * LAT, z = j * LAT, m = rangeMaskL(x, z, null);
    v = m > 0.004 ? RANGE_H * Math.pow(m, 1.5) * (0.8 + 0.35 * fbm(nRange2, x * 0.013, z * 0.013, 2)) : 0;
    if (latCache.size > 400000) latCache.clear();
    latCache.set(k, v);
  }
  return v;
}
const fullCache = new Map();
function fullNode(i, j) {
  const k = i * 100003 + j; let v = fullCache.get(k);
  if (v === undefined) {
    const x = i * LAT, z = j * LAT, mt = mtnNode(i, j);
    v = mt > 0 ? Math.max(0, elevation(x, z, undefined, undefined, true)) + mt : -1; // (-1: no mountain at this node)
    if (fullCache.size > 400000) fullCache.clear();
    fullCache.set(k, v);
  }
  return v;
}
/** The folded mountain surface: each node's full height, flat between nodes (a valley node takes the valley's own height). */
function latticeFull(x, z) {
  const gx = x / LAT, gz = z / LAT, i = Math.floor(gx), j = Math.floor(gz), fx = gx - i, fz = gz - j;
  const at = (a, b) => { const v = fullNode(a, b); return v >= 0 ? v : Math.max(0, elevation(a * LAT, b * LAT, undefined, undefined, true)); };
  if (fx + fz <= 1) { const A = at(i, j), B = at(i + 1, j), Cc = at(i, j + 1); return A + (B - A) * fx + (Cc - A) * fz; }
  const D = at(i + 1, j + 1), Cc = at(i, j + 1), B = at(i + 1, j); return D + (Cc - D) * (1 - fx) + (B - D) * (1 - fz);
}
function mtnLattice(x, z) {
  const gx = x / LAT, gz = z / LAT, i = Math.floor(gx), j = Math.floor(gz), fx = gx - i, fz = gz - j;
  const a = mtnNode(i, j), b = mtnNode(i + 1, j), c = mtnNode(i, j + 1);
  if (a === 0 && b === 0 && c === 0 && mtnNode(i + 1, j + 1) === 0) return 0;
  if (fx + fz <= 1) return a + (b - a) * fx + (c - a) * fz;
  const d = mtnNode(i + 1, j + 1); return d + (c - d) * (1 - fx) + (b - d) * (1 - fz);
}
/** How deep in the mountains (x, z) is: 0 in the valleys, 1 on the crests. */
export function rangeAt(x, z) { return rangeMaskL(x, z, null); }
/** Too steep to climb: the mountainsides past their foothills. */
export function impassable(x, z) { return rangeAt(x, z) > RANGE_STOP; }

const WORLD_SCALE = 0.6; // < 1 = bigger lakes, forests, highlands and mountains
function regionHeight(x, z) {
  const L = landAt(x, z), W = L.w, wx = x, wz = z;
  x *= WORLD_SCALE; z *= WORLD_SCALE;
  const cont = fbm(nCont, x * 0.0021, z * 0.0021, 3);
  const land = smoothstep(-0.14, 0.22, cont);
  let h = -9 + land * 15;
  h += fbm(nHill, x * 0.014, z * 0.014, 4) * 4.5 * (0.35 + land);
  const r = ridged(nRidge, x * 0.0065, z * 0.0065, 4);
  h += Math.pow(Math.max(0, r - 0.52) / 0.48, 1.6) * 42 * smoothstep(0.02, 0.32, cont);
  h += 8 * Math.exp(-(x * x + z * z) / (2 * 60 * 60)); // keep the spawn on land
  if (L.wild > 0) {
    // the fen: a low, wet flat, all pools and hummocks; the prairie: long gentle swells, hardly a pond;
    // the breaks: rock thrust up into terraced mesas; the highlands: lifted high and cold
    if (W.fen) h += (1.6 + fbm(nMarsh, wx * 0.035, wz * 0.035, 3) * 3.2 - h) * W.fen;
    if (W.prairie) h += (4.2 + fbm(nHill, x * 0.006, z * 0.006, 2) * 2.2 - h) * W.prairie;
    if (W.breaks) { const m = Math.max(h, 4) + 9 * smoothstep(0.1, 0.3, ridged(nRidge, x * 0.012, z * 0.012, 2)); h += (Math.round(m / 4) * 4 + (m % 4) * 0.25 - h) * W.breaks; }
    if (W.pines) h += (Math.max(h, 7) + 9 - h) * W.pines; // lifted clear of the sea: high, dry timber with a few tarns
  }
  const m = (_lastRange = rangeMaskL(wx, wz, L));
  // (no lift here: the mountains stand on the valley floor as folded paper, see mtnLattice; lifting the land round
  // them raised a striped plateau at their feet)
  return h;
}
const WATER_T = 0.8;
const HIGH_T = 15;
const PEAK_T = 25;

// ---------------------------------------------------------------- stacked paper terrain

export const STEP = 0.6;  // height of one paper sheet
const GRID = 0.5;         // terrain mesher resolution
let garden = null;       // the kitchen garden rows: { x0, x1, rows: [{ z, type }] }
export function setGarden(g) { garden = g; }
let flat = null;          // { x, z, r0, r1 }: the farm sits on one level sheet

export function setFlatArea(x, z, r0, r1) { flat = { x, z, r0, r1 }; }
const extraFlats = []; // other level sheets (the town's main street); set before any chunk is built
export function addFlatArea(x, z, r0, r1) { extraFlats.push({ x, z, r0, r1 }); }

/**
 * Continuous elevation (before layering). Water is sheet 0 (y = 0); land starts at sheet 1 and rises with
 * the region field. Two scales of noise rag the contours so every sheet edge reads as torn, not cut.
 */
function elevation(x, z, rhKnown, mKnown, base = false) {
  const rh = rhKnown ?? regionHeight(x, z);
  const m = mKnown ?? (rhKnown === undefined ? _lastRange : rangeAt(x, z));
  // banks rise out of a flat water floor; land rolls gently with the region field (soft, never spiky)
  const land = smoothstep(WATER_T - 0.6, WATER_T + 2.5, rh);
  let e = land * (0.35 + Math.max(0, rh - WATER_T) * 0.18);
  e = e > 10 ? 10 + (e - 10) * 0.4 : e;
  e += land * fbm(nTear, x * 0.06, z * 0.06, 2) * 0.6; // small swells and dips across the land
  if (!base) {
    // the mountains: folded paper. Where the lattice has height, the surface runs flat between the lattice's nodes
    // (each node's full height), blending in from the valley floor over the first metre and a half of rise
    const mt = mtnLattice(x, z);
    if (mt > 0) { const full = latticeFull(x, z); e = e + (full - e) * Math.min(1, mt / 0.3) - 0.9 * smoothstep(1.5, 5, mt); } // (up the steep slopes the near sheets tuck under the folds, so a fine-grid crease never shows through)
  }
  if (flat) {
    const d = Math.hypot(x - flat.x, z - flat.z);
    if (d < flat.r1) e += (STEP * 1.5 - e) * (1 - smoothstep(flat.r0, flat.r1, d));
  }
  for (const f of extraFlats) {
    const d = Math.hypot(x - f.x, z - f.z);
    if (d < f.r1) e += (STEP * 1.5 - e) * (1 - smoothstep(f.r0, f.r1, d));
  }
  return Math.max(0, e);
}

// per-chunk elevation grids, so height lookups reuse the mesher's samples instead of recomputing noise
const CELLS = CHUNK / GRID;
const hCache = new Map();
const rCache = new Map(); // the coarse 2 m region grid per chunk (reused to paint the region map)
function coarseRegion(cx, cz, i, j) {
  const R = rCache.get(`${cx},${cz}`), CN = CHUNK / 2 + 1;
  if (!R) return regionHeight(cx * CHUNK + i, cz * CHUNK + j);
  const fx = i / 2, fz = j / 2, i0 = Math.floor(fx), j0 = Math.floor(fz), tx = fx - i0, tz = fz - j0;
  const r0 = R[j0 * CN + i0] + (R[j0 * CN + i0 + 1] - R[j0 * CN + i0]) * tx;
  const r1 = R[(j0 + 1) * CN + i0] + (R[(j0 + 1) * CN + i0 + 1] - R[(j0 + 1) * CN + i0]) * tx;
  return r0 + (r1 - r0) * tz;
}
const _gh = (ix, iz) => {
  const cx = Math.floor(ix / CELLS), cz = Math.floor(iz / CELLS);
  const H = hCache.get(`${cx},${cz}`);
  if (H) return H[(iz - cz * CELLS) * (CELLS + 1) + (ix - cx * CELLS)];
  return elevation(ix * GRID, iz * GRID);
};

/** Height of the sheet under (x, z): the same triangle split and interpolation the mesher uses. */
export function getHeight(x, z) {
  const gx = x / GRID, gz = z / GRID;
  const ix = Math.floor(gx), iz = Math.floor(gz);
  const fx = gx - ix, fz = gz - iz;
  const ha = _gh(ix, iz), hb = _gh(ix + 1, iz), hc = _gh(ix, iz + 1);
  let h;
  if (fx + fz <= 1) h = ha + (hb - ha) * fx + (hc - ha) * fz;
  else { const hd = _gh(ix + 1, iz + 1); h = hd + (hc - hd) * (1 - fx) + (hb - hd) * (1 - fz); }
  return h;
}

/** The land's height computed straight from the noise (no chunk needed): for the far mountains on the horizon. */
export function farHeight(x, z) { const i = Math.round(x / LAT), j = Math.round(z / LAT), v = fullNode(i, j); return v >= 0 ? v : Math.max(0, elevation(x, z, undefined, undefined, true)); }
/** Printed water is the bottom sheet (y = 0); it stops the farmer at the bank. */
export function isWater(x, z) { return getHeight(x, z) < 0.12; }
/** Shallow enough to wade: the pale water near the banks (the deep blue further out still turns you back). */
const WADE = 4.0; // (how far below the water line you can still wade: past the shins to the waist)
export function wadeable(x, z) { return regionHeight(x, z) > WATER_T - WADE; }
/** How deep the wading is here, 0 at the water's edge to 1 at the deepest you can wade. */
export function wadeDepth(x, z) { return Math.min(1, Math.max(0, (WATER_T - regionHeight(x, z)) / WADE)); }
/** Low growth you just walk through (no collision): grass, bushes, toadstools, fallen apples, crops... */
export const WALK_THROUGH = new Set(['grass', 'bush', 'flowers', 'mushroom', 'sang', 'pearl', 'apples', 'stook', 'corn', 'clay', 'cattail', 'lilypad', 'lilybloom']);

export function moisture(x, z) { const W = landAt(x, z).w; return fbm(nMoist, x * 0.004 * WORLD_SCALE, z * 0.004 * WORLD_SCALE, 2) + 0.3 * W.hollows + 0.2 * W.fen + 0.15 * W.pines - 0.4 * W.prairie - 0.1 * W.breaks; }

/** Distance-like value to the nearest meandering footpath (0 on the path centre line). */
export function pathField(x, z) { return Math.abs(fbm(nPath, x * 0.0075 * WORLD_SCALE, z * 0.0075 * WORLD_SCALE, 2)); }

/** Crop-field patches (0..1): striped stubble printed on the page. */
function fieldMask(x, z) { const wild = smoothstep(RING[0] - 20, RING[0] + 40, Math.hypot(x, z)); if (wild >= 1) return 0; return smoothstep(0.18, 0.3, fbm(nField, x * 0.012 * WORLD_SCALE, z * 0.012 * WORLD_SCALE, 2)) * (1 - wild); } // no ploughed fields out in the wilds

/**
 * One chunk of the paper sheet draped over the land: a 0.5 m grid with smooth normals (no facets).
 * Height layers are printed by the ground shader as torn contour lines, so the hills read as a layered
 * paper map while the surface stays smooth to walk on.
 */
function buildTerrain(cx, cz) {
  const N = CHUNK / GRID, S = N + 1, ox = cx * CHUNK, oz = cz * CHUNK;
  const C = 2, CN = CHUNK / C + 1, R = new Float32Array(CN * CN), M = new Float32Array(CN * CN);
  for (let j = 0; j < CN; j++) for (let i = 0; i < CN; i++) { R[j * CN + i] = regionHeight(ox + i * C, oz + j * C); M[j * CN + i] = _lastRange; }
  const H = new Float32Array(S * S);
  for (let j = 0; j <= N; j++) {
    for (let i = 0; i <= N; i++) {
      const fx = (i * GRID) / C, fz = (j * GRID) / C;
      const i0 = Math.min(CN - 2, Math.floor(fx)), j0 = Math.min(CN - 2, Math.floor(fz));
      const tx = fx - i0, tz = fz - j0;
      const r0 = R[j0 * CN + i0] + (R[j0 * CN + i0 + 1] - R[j0 * CN + i0]) * tx;
      const r1 = R[(j0 + 1) * CN + i0] + (R[(j0 + 1) * CN + i0 + 1] - R[(j0 + 1) * CN + i0]) * tx;
      const m0 = M[j0 * CN + i0] + (M[j0 * CN + i0 + 1] - M[j0 * CN + i0]) * tx, m1 = M[(j0 + 1) * CN + i0] + (M[(j0 + 1) * CN + i0 + 1] - M[(j0 + 1) * CN + i0]) * tx;
      H[j * S + i] = elevation(ox + i * GRID, oz + j * GRID, r0 + (r1 - r0) * tz, m0 + (m1 - m0) * tz);
    }
  }
  hCache.set(`${cx},${cz}`, H);
  rCache.set(`${cx},${cz}`, R);
  const pos = new Float32Array(S * S * 3), nor = new Float32Array(S * S * 3);
  const at = (i, j) => H[Math.min(N, Math.max(0, j)) * S + Math.min(N, Math.max(0, i))];
  for (let j = 0; j <= N; j++) {
    for (let i = 0; i <= N; i++) {
      const o = (j * S + i) * 3;
      pos[o] = ox + i * GRID; pos[o + 1] = H[j * S + i]; pos[o + 2] = oz + j * GRID;
      const nx = (at(i - 1, j) - at(i + 1, j)) / (2 * GRID), nz = (at(i, j - 1) - at(i, j + 1)) / (2 * GRID);
      const l = Math.hypot(nx, 1, nz);
      nor[o] = nx / l; nor[o + 1] = 1 / l; nor[o + 2] = nz / l;
    }
  }
  const idx = new Uint32Array(N * N * 6);
  let k = 0;
  for (let j = 0; j < N; j++) {
    for (let i = 0; i < N; i++) {
      const a = j * S + i, b = a + 1, c = a + S, d = c + 1;
      idx[k++] = a; idx[k++] = c; idx[k++] = b; // same split as getHeight
      idx[k++] = b; idx[k++] = c; idx[k++] = d;
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  g.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
  g.setAttribute('kind', new THREE.BufferAttribute(new Float32Array(S * S), 1));
  g.setIndex(new THREE.BufferAttribute(idx, 1));
  g.computeBoundingSphere();
  return g;
}

export function regionAt(x, z) {
  const h = regionHeight(x, z);
  if (h < WATER_T) return 'water';
  if (h > PEAK_T) return 'peak';
  if (h > HIGH_T) return 'highland';
  if (fieldMask(x, z) > 0.5) return 'field';
  return moisture(x, z) > 0.02 ? 'forest' : 'meadow';
}

// ---------------------------------------------------------------- prop placement

function pick(roll, table) {
  let acc = 0;
  for (const [type, p] of table) { acc += p; if (roll < acc) return type; }
  return null;
}

const TABLES = {
  // more to gather everywhere: berry bushes, toadstools and rock are a good deal commoner than they were
  forest: [['mushroom', 0.045], ['snag', 0.008], ['pine', 0.2], ['birch', 0.07], ['maple', 0.14], ['goldtree', 0.1], ['sagetree', 0.07], ['rock', 0.055], ['bush', 0.095], ['flowers', 0.07], ['grass', 0.1]],
  meadow: [['maple', 0.05], ['birch', 0.02], ['goldtree', 0.05], ['sagetree', 0.02], ['pine', 0.03], ['bush', 0.1], ['mushroom', 0.02], ['flowers', 0.15], ['grass', 0.2], ['rock', 0.055]],
  field: [['grass', 0.06], ['flowers', 0.03]],
  highland: [['rock', 0.19], ['snag', 0.025], ['pine', 0.12], ['bush', 0.03], ['grass', 0.12], ['flowers', 0.04]],
  peak: [['rock', 0.1], ['pine', 0.05]],
};

// the wild lands' own mix of things, standing in for the home tables
const LAND_TABLES = {
  hollows: { forest: [['birch', 0.42], ['mushroom', 0.08], ['maple', 0.01], ['goldtree', 0.015], ['bush', 0.06], ['flowers', 0.1], ['grass', 0.1], ['rock', 0.03], ['snag', 0.01]],
    meadow: [['birch', 0.2], ['flowers', 0.24], ['grass', 0.2], ['mushroom', 0.06], ['bush', 0.08], ['rock', 0.03]] },
  breaks: { any: [['quartz', 0.012], ['rock', 0.3], ['snag', 0.05], ['pine', 0.04], ['grass', 0.08], ['bush', 0.02], ['flowers', 0.02]] },
  fen: { any: [['snag', 0.09], ['birch', 0.03], ['sagetree', 0.05], ['mushroom', 0.07], ['grass', 0.26], ['bush', 0.03], ['flowers', 0.02]] },
  prairie: { any: [['grass', 0.36], ['flowers', 0.26], ['bush', 0.04], ['goldtree', 0.012], ['rock', 0.02]] },
  pines: { any: [['quartz', 0.008], ['pine', 0.38], ['rock', 0.1], ['bush', 0.04], ['grass', 0.08], ['snag', 0.02], ['birch', 0.02]] },
};
// how each land tints the props that grow in it (r, g, b), so a red rock is red and a blue pine is blue
const PROP_TINT = { breaks: { rock: [1.18, 0.84, 0.68], snag: [1.08, 0.9, 0.8], grass: [1.08, 0.92, 0.75] }, pines: { pine: [0.66, 0.86, 1.2], rock: [0.86, 0.94, 1.1] },
  fen: { sagetree: [0.85, 0.92, 0.86], grass: [0.88, 0.95, 0.85], birch: [0.92, 0.96, 0.94] }, prairie: { grass: [1.12, 1.02, 0.74], goldtree: [1.08, 1.02, 0.86] }, hollows: { birch: [1.04, 1.06, 1.06] } };
// One of a kind: each world places every landmark exactly once. The seed picks, for each, a starting distance
// (from about 130 to 330 m) and a starting bearing; from there we walk outward ring by ring through the chunks
// until we find one deep in the right land with good ground (dry for most, the water's edge for the wrecked
// steamboat), at least 150 m from any landmark already placed. Pure noise lookups, done once per world.
let _uniques = null, _uniquesSeed = -1;
export function uniqueEncounters() {
  if (_uniques && _uniquesSeed === SEED) return _uniques;
  _uniquesSeed = SEED; _uniques = [];
  const rng = mulberry32(hash2(17, 29, SEED + 101));
  const dry = (x, z) => [0, 1, 2, 3, 4, 5, 6, 7].every((k) => !isWater(x + Math.cos(k * 0.785) * 5, z + Math.sin(k * 0.785) * 5));
  for (const [land, mark] of UNIQUES) {
    const start = 4 + Math.floor(rng() * 6), turn = rng();
    let found = null;
    for (let r = start; r <= 30 && !found; r++) {
      const ring = []; for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) if (Math.max(Math.abs(dx), Math.abs(dz)) === r) ring.push([dx, dz, (Math.atan2(dz, dx) / (Math.PI * 2) + 1 + turn) % 1]);
      ring.sort((a, b) => a[2] - b[2]);
      for (const [cx, cz] of ring) {
        const h = mulberry32(hash2(cx, cz, SEED + 61)), x = cx * CHUNK + 8 + h() * 16, z = cz * CHUNK + 8 + h() * 16, rot = h() * Math.PI * 2;
        const L = landAt(x, z);
        if (L.id !== land || L.wild < 0.9 || L.w[land] < 0.9) continue;
        if (rangeMaskL(x, z, L) > 0.04) continue; // (never up in the mountains, nor past the outer wall)
        if (_uniques.some((u) => Math.hypot(u.x - x, u.z - z) < 150)) continue;
        if (mark === 'babe' ? isWater(x, z) : mark === 'steamboat' ? !(isWater(x, z) || [0, 2, 4, 6].some((k) => isWater(x + Math.cos(k * 0.785) * 5, z + Math.sin(k * 0.785) * 5))) : !dry(x, z)) continue;
        found = { cx, cz, x, z, rot, mark, land }; break;
      }
    }
    if (found) _uniques.push(found);
  }
  return _uniques;
}

// the treasure each land keeps, and who keeps it
export const LAND_SITES = { hollows: { kind: 'sang', guard: 'hidebehind', guards: 1 }, breaks: { kind: 'silver', guard: 'gouger', guards: 2 }, fen: { kind: 'pearl', guard: 'hodag', guards: 1 }, prairie: { kind: 'geode', guard: 'coyote', guards: 3 }, pines: { kind: 'amber', guard: 'wampus', guards: 1 } };

function placeProps(cx, cz, exclusions) {
  const rng = mulberry32(hash2(cx, cz, SEED + 7));
  const list = [];
  const spacing = 2.9;
  // (only the exclusions that reach this chunk: the railroad's right-of-way adds a long string of them)
  const x0 = cx * CHUNK - 8, x1 = (cx + 1) * CHUNK + 8, z0 = cz * CHUNK - 8, z1 = (cz + 1) * CHUNK + 8;
  const near = exclusions.filter((e) => e.x + e.r > x0 && e.x - e.r < x1 && e.z + e.r > z0 && e.z - e.r < z1);
  const blocked = (x, z, pad = 0) => near.some((e) => (e.x - x) ** 2 + (e.z - z) ** 2 < (e.r + pad) ** 2);
  for (let gz = 0; gz < CHUNK; gz += spacing) {
    for (let gx = 0; gx < CHUNK; gx += spacing) {
      const lx = gx + rng() * spacing, lz = gz + rng() * spacing;
      const x = cx * CHUNK + lx, z = cz * CHUNK + lz;
      // every random number is drawn up front, whatever happens to this cell, so the chunk's random stream
      // (and with it the guarded site drawn after the props) never depends on cached terrain heights
      const roll = rng(), s = rng(), rot = rng() * Math.PI * 2, lean = (rng() - 0.5) * 0.08;
      const region = regionAt(x, z);
      if (region === 'water' || pathField(x, z) < 0.05 || blocked(x, z)) continue;
      if (_lastRange > 0.03 || mtnLattice(x, z) > 0.25) continue; // (nothing grows up the mountainsides, nor on the first rise of their folds: regionAt just measured the range here)
      // keep a little bank between water and props; clay banks like that spot
      const nearWater = isWater(x + 1.5, z) || isWater(x - 1.5, z) || isWater(x, z + 1.5) || isWater(x, z - 1.5);
      if (nearWater && !(roll < 0.35 && !isWater(x, z))) continue;
      const lid = landAt(x, z).id, LT = lid !== 'home' && LAND_TABLES[lid];
      const type = nearWater ? 'clay' : pick(roll, LT ? (LT[region] || LT.any || LT.forest) : TABLES[region]);
      if (!type) continue;
      const scale = type === 'clay' ? 0.8 + s * 0.5 : type === 'rock' ? 0.75 + s * 0.7
        : type === 'bush' || type === 'flowers' ? 0.75 + s * 0.45
          : type === 'grass' ? 0.6 + s * 0.6 : 0.85 + s * 0.45;
      const y = getHeight(x, z);
      if (Math.abs(getHeight(x + 0.8, z) - y) + Math.abs(getHeight(x, z + 0.8) - y) > 0.7) continue; // too steep
      list.push({ type, x, z, y, lx, lz, rot, scale, lean, tint: lid !== 'home' ? PROP_TINT[lid]?.[type] : undefined });
    }
  }
  // hills & peaks: clusters of nested sails, every ~11 m in highland / peak regions
  for (let gz = 0; gz < CHUNK; gz += 11) {
    for (let gx = 0; gx < CHUNK; gx += 11) {
      const lx = gx + 2 + rng() * 7, lz = gz + 2 + rng() * 7;
      const x = cx * CHUNK + lx, z = cz * CHUNK + lz;
      const region = regionAt(x, z);
      if (true) continue; // mountains are real stacked terrain now; no sails needed
      const kind = 'peak';
      const yaw = rng() * Math.PI;
      const size = kind === 'peak' ? 1.2 + rng() * 0.5 : 0.8 + rng() * 0.45;
      // 4 nested sails: the back one tallest and darkest, each nearer one lower and lighter,
      // fanned ±5°/±13° about a common yaw; then a second, smaller set turned 90° so it reads from any side
      for (const [set, turn, scaleSet] of [[0, 0, 1], [1, Math.PI / 2, 0.7]]) {
        for (let k = 0; k < 4; k++) {
          const fan = [-13, -5, 5, 13][k] * (Math.PI / 180) * (k % 2 ? 1 : -1);
          const back = (1.5 - k) * 0.9 * size * scaleSet; // offset along the facing direction
          const a = yaw + turn + fan;
          const ox = Math.sin(yaw + turn) * back, oz = Math.cos(yaw + turn) * back;
          list.push({
            type: kind, x: x + ox, z: z + oz, y: getHeight(x, z) - 0.05, lx: lx + ox, lz: lz + oz, rot: a,
            scale: size * scaleSet * (1.15 - k * 0.12), tone: 0.84 + k * 0.06 + set * 0.02, lean: 0,
          });
        }
      }
      list.colliders = list.colliders || [];
      list.colliders.push({ x, z, r: 4.2 * size });
    }
  }
  // pond life, on its own seed so the rest of the chunk's layout never shifts: cattails along the banks,
  // lily pads (a few in bloom) in the shallows near shore
  {
    const prng = mulberry32(hash2(cx, cz, SEED + 29));
    let lodged = false;
    for (let gz = 0; gz < CHUNK; gz += 2.2) {
      for (let gx = 0; gx < CHUNK; gx += 2.2) {
        const lx = gx + prng() * 2.2, lz = gz + prng() * 2.2, roll = prng(), s = prng(), rot = prng() * Math.PI * 2;
        const x = cx * CHUNK + lx, z = cz * CHUNK + lz;
        if (blocked(x, z)) continue;
        // by height, to match the printed water (it reads as water a little above the walkable line)
        const h = getHeight(x, z);
        const shore = (d) => getHeight(x + d, z) > 0.32 || getHeight(x - d, z) > 0.32 || getHeight(x, z + d) > 0.32 || getHeight(x, z - d) > 0.32;
        if (!lodged && h < 0.1 && roll > 0.9 && shore(6) && [0, 1, 2, 3, 4, 5, 6, 7].every((k) => isWater(x + Math.cos(k * 0.785) * 2.8, z + Math.sin(k * 0.785) * 2.8))) { // open water all round, the bank a few strides off
          // a beaver lodge: one at most to a chunk, out in the shallows a few strides from the bank
          lodged = true;
          list.push({ type: 'lodge', x, z, y: -0.18, lx, lz, rot, scale: 0.95 + s * 0.3, lean: 0 });
          list.colliders = list.colliders || []; list.colliders.push({ x, z, r: 1.3 });
        } else if (h > 0.1 && h < 0.45 && roll < 0.16) {
          // a clump: two or three stalk cards
          const n = 2 + (roll < 0.06 ? 1 : 0);
          for (let k = 0; k < n; k++) {
            const ox = (prng() - 0.5) * 1.1, oz = (prng() - 0.5) * 1.1;
            list.push({ type: 'cattail', x: x + ox, z: z + oz, y: getHeight(x + ox, z + oz), lx: lx + ox, lz: lz + oz, rot: rot + k * 1.1, scale: 1.05 + prng() * 0.5, lean: 0 });
          }
        } else if (h < 0.1 && roll < 0.32 && shore(5.5)) {
          list.push({ type: roll < 0.08 ? 'lilybloom' : 'lilypad', x, z, y: h + 0.03, lx, lz, rot, scale: 0.75 + s * 0.55, lean: 0 });
        }
      }
    }
  }
  // the wild woods floor: now and then a fallen log, mossy, with shelf fungus and a fern (own seed)
  {
    const wrng = mulberry32(hash2(cx, cz, SEED + 53));
    for (let gz = 0; gz < CHUNK; gz += 8) {
      for (let gx = 0; gx < CHUNK; gx += 8) {
        const lx = gx + 1 + wrng() * 6, lz = gz + 1 + wrng() * 6, roll = wrng(), rot = wrng() * Math.PI * 2, s = wrng();
        const x = cx * CHUNK + lx, z = cz * CHUNK + lz;
        if (roll > 0.22 || regionAt(x, z) !== 'forest' || blocked(x, z, 1.6) || pathField(x, z) < 0.1 || isWater(x, z)) continue;
        list.push({ type: 'log', x, z, y: getHeight(x, z), lx, lz, rot, scale: 0.95 + s * 0.4, lean: 0 });
        list.colliders = list.colliders || [];
        for (const k of [-0.8, 0, 0.8]) list.colliders.push({ x: x + Math.cos(rot) * k * (0.95 + s * 0.4), z: z - Math.sin(rot) * k * (0.95 + s * 0.4), r: 0.45 });
      }
    }
  }
  // field dressing: round bales left where the hay was mown, wheat stooked in loose rows to dry (own seed)
  {
    const frng = mulberry32(hash2(cx, cz, SEED + 41));
    for (let gz = 0; gz < CHUNK; gz += 4.5) {
      for (let gx = 0; gx < CHUNK; gx += 4.5) {
        const lx = gx + frng() * 4.5, lz = gz + frng() * 4.5, roll = frng(), rot = frng() * Math.PI * 2, s = frng();
        const x = cx * CHUNK + lx, z = cz * CHUNK + lz;
        if (roll > 0.3 || regionAt(x, z) !== 'field' || fieldMask(x, z) < 0.62 || blocked(x, z, 1) || pathField(x, z) < 0.08) continue;
        const kind = fieldKindAt(x, z);
        if (kind === 'hay' && roll < 0.12) {
          list.push({ type: 'bale', x, z, y: getHeight(x, z), lx, lz, rot, scale: 1.25 + s * 0.3, lean: 0 });
          list.colliders = list.colliders || []; list.colliders.push({ x, z, r: 0.7 });
        } else if (kind === 'wheat') {
          // a short row of two or three stooks, a pace apart
          for (let k = 0; k < 2 + (roll < 0.15 ? 1 : 0); k++) {
            const sx = x + Math.cos(rot) * k * 1.3, sz = z + Math.sin(rot) * k * 1.3;
            if (Math.floor(sx / CHUNK) !== cx || Math.floor(sz / CHUNK) !== cz || fieldKindAt(sx, sz) !== 'wheat') continue;
            list.push({ type: 'stook', x: sx, z: sz, y: getHeight(sx, sz), lx: sx - cx * CHUNK, lz: sz - cz * CHUNK, rot: rot + k * 0.9, scale: 1.45 + s * 0.35, lean: (s - 0.5) * 0.1 });
          }
        }
      }
    }
  }
  // old orchards: now and then a meadow chunk holds a loose grid of apple trees, windfalls in the grass
  {
    const orng = mulberry32(hash2(cx, cz, SEED + 31));
    const ox = cx * CHUNK + 6 + orng() * 20, oz = cz * CHUNK + 6 + orng() * 20;
    if (orng() < 0.3 && regionAt(ox, oz) === 'meadow' && !blocked(ox, oz, 6)) {
      const yaw = orng() * Math.PI;
      for (let i = -1; i <= 1; i++) for (let j = -1; j <= 1; j++) {
        if (orng() < 0.25) continue; // gaps where old trees have fallen
        const gx = i * 5.5 + (orng() - 0.5) * 1.2, gz = j * 5.5 + (orng() - 0.5) * 1.2;
        const x = ox + gx * Math.cos(yaw) - gz * Math.sin(yaw), z = oz + gx * Math.sin(yaw) + gz * Math.cos(yaw);
        if (Math.floor(x / CHUNK) !== cx || Math.floor(z / CHUNK) !== cz || isWater(x, z) || blocked(x, z) || pathField(x, z) < 0.05) continue;
        for (let k = list.length - 1; k >= 0; k--) if ((list[k].x - x) ** 2 + (list[k].z - z) ** 2 < 6.5) list.splice(k, 1); // room for the crown
        list.push({ type: 'appletree', x, z, y: getHeight(x, z), lx: x - cx * CHUNK, lz: z - cz * CHUNK, rot: orng() * 6.28, scale: 0.85 + orng() * 0.3, lean: (orng() - 0.5) * 0.06 });
        const a = orng() * Math.PI * 2, hx = x + Math.cos(a) * 1.5, hz = z + Math.sin(a) * 1.5;
        if (Math.floor(hx / CHUNK) === cx && Math.floor(hz / CHUNK) === cz && !isWater(hx, hz)) {
          list.push({ type: 'apples', x: hx, z: hz, y: getHeight(hx, hz), lx: hx - cx * CHUNK, lz: hz - cz * CHUNK, rot: orng() * 6.28, scale: 1.3 + orng() * 0.3, lean: 0 });
        }
      }
    }
  }
  // a lost satchel, now and then, far out in the wilds (never regrows; found ones are remembered)
  {
    const srng = mulberry32(hash2(cx, cz, SEED + 37));
    const x = cx * CHUNK + 4 + srng() * 24, z = cz * CHUNK + 4 + srng() * 24;
    const far = !flat || Math.hypot(x - flat.x, z - flat.z) > 60;
    if (srng() < 0.07 && far && !isWater(x, z) && !blocked(x, z, 2) && regionAt(x, z) !== 'peak' && rangeAt(x, z) < 0.01) {
      for (let k = list.length - 1; k >= 0; k--) if ((list[k].x - x) ** 2 + (list[k].z - z) ** 2 < 4) list.splice(k, 1);
      list.push({ type: 'satchel', x, z, y: getHeight(x, z), lx: x - cx * CHUNK, lz: z - cz * CHUNK, rot: srng() * 6.28, scale: 1.2, lean: 0 });
    }
  }
  // the kitchen garden (planted by the homestead): corn and pumpkins in rows, gathered and regrown like the wild
  if (garden) {
    for (const row of garden.rows) {
      const step = row.type === 'corn' ? 1.0 : 1.5;
      for (let x = garden.x0; x <= garden.x1 + 0.01; x += step) {
        if (Math.floor(x / CHUNK) !== cx || Math.floor(row.z / CHUNK) !== cz) continue;
        const jx = x + (rng() - 0.5) * 0.25, jz = row.z + (rng() - 0.5) * 0.2;
        list.push({ type: row.type, x: jx, z: jz, y: getHeight(jx, jz) + 0.02, lx: jx - cx * CHUNK, lz: jz - cz * CHUNK,
          rot: 0.25 + rng() * 0.4, scale: row.type === 'corn' ? 1.15 + rng() * 0.2 : 0.75 + rng() * 0.25, lean: 0 });
      }
    }
  }
  // a landmark, if this chunk is where the world put one of its one-of-a-kind encounters (see uniqueEncounters)
  let lm = null;
  {
    const U = uniqueEncounters().find((u) => u.cx === cx && u.cz === cz);
    if (U) {
      const { x, z, rot, mark, land } = U;
      for (let i = list.length - 1; i >= 0; i--) if ((list[i].x - x) ** 2 + (list[i].z - z) ** 2 < 70) list.splice(i, 1); // room round it
      list.colliders = list.colliders || []; list.colliders.push(...landmarkColliders(mark, x, z, rot));
      lm = { key: `${cx},${cz},landmark`, kind: 'landmark', mark, land, x, y: Math.max(0, getHeight(x, z)), z, rot, guards: 0 };
    }
  }
  // Guarded sites: never near the farm, and the guards keep to them. An iron vein in the highlands, watched by a
  // coyote pack; a wild-hive grove in the woods, watched by an old bramble boar; a berry thicket out in the
  // meadow, watched by a pair of coyotes. About one chunk in three of the right country has one.
  list.sites = lm ? [lm] : [];
  const sx = cx * CHUNK + 8 + rng() * 16, sz = cz * CHUNK + 8 + rng() * 16;
  const sroll = rng();
  const farFromFarm = !flat || Math.hypot(sx - flat.x, sz - flat.z) > 55;
  const sreg = regionAt(sx, sz);
  const sland = landAt(sx, sz), LS = sland.id !== 'home' ? LAND_SITES[sland.id] : null, slandId = sland.id;
  const fenOk = !LS || LS.kind !== 'pearl' || [0, 1, 2, 3, 4, 5].some((k) => isWater(sx + Math.cos(k) * 4, sz + Math.sin(k) * 4)); // mussels want water
  const siteKind = !farFromFarm ? null
    : LS ? (sroll < 0.22 && sreg !== 'water' && fenOk ? LS.kind : (sreg === 'highland' || sreg === 'peak') && sroll < 0.32 ? 'vein' : null) // (iron veins in any high country, one high chunk in ten: the home lands alone have almost none)
    : (sreg === 'highland' || sreg === 'peak') && sroll < 0.4 ? 'vein'
      : sreg === 'forest' && sroll < 0.3 ? 'grove'
        : sreg === 'meadow' && sroll < 0.2 ? 'thicket' : null;
  if (siteKind && rangeAt(sx, sz) < 0.08 && !blocked(sx, sz, 6) && !(lm && Math.hypot(sx - lm.x, sz - lm.z) < 18)) {
    const sy = getHeight(sx, sz);
    // clear the site's own props so the treasure stands out
    for (let i = list.length - 1; i >= 0; i--) if ((list[i].x - sx) ** 2 + (list[i].z - sz) ** 2 < 36) list.splice(i, 1);
    const ring = (type, n, r0, r1, scale) => {
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + rng() * 0.6, d = r0 + rng() * (r1 - r0), rot = rng() * 6.28, sc = 0.9 + rng() * 0.3;
        const x = sx + Math.cos(a) * d, z = sz + Math.sin(a) * d;
        if (isWater(x, z) && type !== 'pearl') continue;
        if (type === 'pearl' && getHeight(x, z) > 0.6) continue; // mussel beds only right down at the water
        list.push({ type, x, z, y: Math.max(0.02, getHeight(x, z)), lx: x - cx * CHUNK, lz: z - cz * CHUNK, rot, scale: scale * sc, lean: 0, tint: PROP_TINT[slandId]?.[type] });
      }
    };
    if (LS && siteKind === LS.kind) { // no warning sign out here: you find out what keeps it when it finds you (an iron vein out here is built as at home, below)
      const n = { sang: 6, silver: 5, pearl: 7, geode: 5, amber: 5 }[siteKind];
      ring(siteKind, n, 1.4, 5, siteKind === 'sang' ? 1.45 : 1.0); // (ginseng a little bigger, so it reads among the toadstools)
      if (siteKind === 'amber') ring('pine', 4, 5, 7, 1.1);
      if (siteKind === 'silver') ring('rock', 4, 4, 6.5, 1.0);
      list.sites.push({ key: `${cx},${cz},site`, kind: siteKind, land: slandId, guard: LS.guard, x: sx, y: sy, z: sz, guards: LS.guards });
      return list;
    }
    if (siteKind === 'vein') { ring('ore', 7, 2.2, 5.5, 1.0); ring('rock', 3, 4, 6, 0.9); }
    else if (siteKind === 'grove') { ring('hive', 3, 1.2, 2.8, 1.0); ring('mushroom', 6, 3, 6, 0.9); }
    else { ring('bush', 8, 1.2, 5, 1.1); ring('mushroom', 3, 3, 5.5, 0.9); ring('apples', 2, 2, 4, 1.0); } // the thicket: berries, toadstools, windfalls
    // a hand-painted warning sign on the side facing home, so you know whose treasure it is
    const home = flat ? Math.atan2(flat.x - sx, flat.z - sz) : rng() * 6.28;
    for (const da of [0, 0.6, -0.6, 1.2, -1.2, Math.PI]) {
      const a = home + da, x = sx + Math.sin(a) * 7.5, z = sz + Math.cos(a) * 7.5;
      if (isWater(x, z) || blocked(x, z, 1)) continue;
      for (let i = list.length - 1; i >= 0; i--) if ((list[i].x - x) ** 2 + (list[i].z - z) ** 2 < 7 && list[i].type !== 'hive') list.splice(i, 1); // a clear spot to read it from
      list.push({ type: siteKind === 'vein' ? 'signvein' : siteKind === 'thicket' ? 'signthicket' : 'signgrove', x, z, y: getHeight(x, z), lx: x - cx * CHUNK, lz: z - cz * CHUNK, rot: a + (rng() - 0.5) * 0.3, scale: 1.45, lean: 0 });
      break;
    }
    list.sites.push({ key: `${cx},${cz},site`, kind: siteKind, x: sx, y: sy, z: sz, guards: siteKind === 'vein' ? 3 : siteKind === 'thicket' ? 2 : 1 });
  }
  return list;
}

// ---------------------------------------------------------------- hinge spring

/** Damped spring 0 → 1 with ~12 % overshoot and a small quiver, settled by ~1 s. */
function markDirty(pool, i) { pool.dirty = true; if (i < pool.lo) pool.lo = i; if (i > pool.hi) pool.hi = i; }
function markColor(pool, i) { pool.colorDirty = true; if (i < pool.clo) pool.clo = i; if (i > pool.chi) pool.chi = i; }

export function springRise(t) {
  if (t <= 0) return 0;
  const zeta = 0.56, wn = 9, wd = wn * Math.sqrt(1 - zeta * zeta);
  return 1 - Math.exp(-zeta * wn * t) * (Math.cos(wd * t) + ((zeta * wn) / wd) * Math.sin(wd * t));
}

// ---------------------------------------------------------------- world / chunk manager

const _m = new THREE.Matrix4(), _m2 = new THREE.Matrix4(), _q = new THREE.Quaternion(), _q2 = new THREE.Quaternion(), _q3 = new THREE.Quaternion();
const _p = new THREE.Vector3(), _s = new THREE.Vector3(), _axis = new THREE.Vector3(), _c = new THREE.Color();
const UP = new THREE.Vector3(0, 1, 0), RIGHT = new THREE.Vector3(1, 0, 0);
const _tint = [1, 1, 1];

export class World {
  constructor(scene) {
    this.scene = scene;
    this.chunks = new Map();
    this.destroyed = new Set();
    this.ducking = new Set(); // tall cards bowing out of the camera's way
    this.regrow = new Map(); // destroyed key → { at, res }
    this.regrowBlocked = null; // (res) => true if something (a built piece) now stands there
    this.animating = new Set();
    this.exclusions = []; // {x, z, r}: no props here (homestead etc.)
    this.colliders = []; // {x, z, r}: static circles the player can't walk into
    this.onResourceGone = null;
    this.time = 0;
    this.pools = {};

    // region map: R = region height, G = path, B = moisture, A = crop field
    this.mapData = new Uint8Array(MAP * MAP * 4);
    this.mapTex = new THREE.DataTexture(this.mapData, MAP, MAP, THREE.RGBAFormat);
    this.mapTex.wrapS = this.mapTex.wrapT = THREE.RepeatWrapping;
    this.mapTex.magFilter = THREE.LinearFilter;
    this.mapTex.minFilter = THREE.LinearFilter;
    this.mapTex.colorSpace = THREE.NoColorSpace;
    this.mapTex.needsUpdate = true;
    // the land tint map: each wild land dyes the page its own colour (stored at 0.8x so it can go above 1)
    this.landData = new Uint8Array(MAP * MAP * 4).fill(204);
    this.landTex = new THREE.DataTexture(this.landData, MAP, MAP, THREE.RGBAFormat);
    this.landTex.wrapS = this.landTex.wrapT = THREE.RepeatWrapping;
    this.landTex.magFilter = this.landTex.minFilter = THREE.LinearFilter;
    this.landTex.colorSpace = THREE.NoColorSpace; this.landTex.needsUpdate = true;

    // one printed paper page, far bigger than the frame, following the player
    this.groundMat = groundMaterial(this.mapTex, { landTex: this.landTex, waterT: (WATER_T + 10) / 60, highT: (HIGH_T + 10) / 60, peakT: (PEAK_T + 10) / 60 });
    const plane = new THREE.PlaneGeometry(360, 360, 1, 1).rotateX(-Math.PI / 2);
    plane.setAttribute('kind', new THREE.Float32BufferAttribute([3, 3, 3, 3], 1));
    this.ground = new THREE.Mesh(plane, groundMaterial(this.mapTex, { landTex: this.landTex, waterT: (WATER_T + 10) / 60, highT: (HIGH_T + 10) / 60, peakT: (PEAK_T + 10) / 60 }));
    this.ground.receiveShadow = true;
    scene.add(this.ground);
    // create every prop pool up front so all their shaders compile before the first frame
    for (const t of Object.keys(POOL_CAP)) this.pool(t);
  }

  key(cx, cz) { return `${cx},${cz}`; }

  paintRegionMap(cx, cz) {
    const d = this.mapData;
    for (let j = 0; j < CHUNK; j++) {
      for (let i = 0; i < CHUNK; i++) {
        const x = cx * CHUNK + i, z = cz * CHUNK + j;
        const tx = ((x % MAP) + MAP) % MAP, tz = ((z % MAP) + MAP) % MAP;
        const o = (tz * MAP + tx) * 4;
        d[o] = Math.max(0, Math.min(255, ((coarseRegion(cx, cz, i, j) + 10) / 60) * 255));
        d[o + 1] = Math.max(0, Math.min(255, (pathField(x, z) / 0.25) * 255));
        d[o + 2] = Math.max(0, Math.min(255, (moisture(x, z) * 0.5 + 0.5) * 255));
        d[o + 3] = Math.max(0, Math.min(255, fieldMask(x, z) * 255));
        if ((i & 1) === 0 && (j & 1) === 0) { // the tint changes slowly: sample every 2 m, fill the 2x2 block
          landTint(x, z, _tint);
          for (let dj = 0; dj < 2; dj++) for (let di = 0; di < 2; di++) {
            const q = ((((z + dj) % MAP) + MAP) % MAP * MAP + ((((x + di) % MAP) + MAP) % MAP)) * 4;
            this.landData[q] = Math.min(255, _tint[0] * 204); this.landData[q + 1] = Math.min(255, _tint[1] * 204); this.landData[q + 2] = Math.min(255, _tint[2] * 204);
          }
        }
      }
    }
    this.mapTex.needsUpdate = true; this.landTex.needsUpdate = true;
  }

  update(px, pz, dt) {
    this.time += dt;
    this.ground.position.set(Math.round(px), -0.05, Math.round(pz)); // backdrop under every sheet, beyond the loaded chunks
    const pcx = Math.floor(px / CHUNK), pcz = Math.floor(pz / CHUNK);
    const want = [];
    for (let dz = -VIEW_RADIUS; dz <= VIEW_RADIUS; dz++) {
      for (let dx = -VIEW_RADIUS; dx <= VIEW_RADIUS; dx++) {
        const d2 = dx * dx + dz * dz;
        if (d2 > VIEW_RADIUS * VIEW_RADIUS + 1) continue;
        if (!this.chunks.has(this.key(pcx + dx, pcz + dz))) want.push([d2, pcx + dx, pcz + dz]);
      }
    }
    want.sort((a, b) => a[0] - b[0]);
    if (want.length) this.createChunk(want[0][1], want[0][2]); // one chunk per frame keeps hitches small

    const far = (VIEW_RADIUS + 1.5) ** 2;
    for (const [k, ch] of this.chunks) {
      const dx = ch.cx - pcx, dz = ch.cz - pcz;
      if (dx * dx + dz * dz > far) this.disposeChunk(k, ch);
    }

    // regrowth: once a second, pop gathered props back up (not under the farmer's feet or a building)
    this.regrowClock = (this.regrowClock || 0) + dt;
    if (this.regrowClock > 1 && this.regrow.size) {
      const boost = this.regrowClock * (this.rain || 0); // rain doubles the pace
      this.regrowClock = 0;
      for (const [k, g] of this.regrow) {
        g.at -= boost;
        if (this.time < g.at) continue;
        let r = g.res;
        const loaded = this.chunks.get(this.key(Math.floor(r.x / CHUNK), Math.floor(r.z / CHUNK)));
        if (loaded && r.chunk !== loaded) r = loaded.resources.find((q) => q.key === k) || r; // chunk was rebuilt
        if (loaded && r.chunk === loaded) {
          if ((r.x - px) ** 2 + (r.z - pz) ** 2 < 6.25 || this.regrowBlocked?.(r)) { g.at = this.time + 20; continue; }
          r.alive = true; r.hp = RESOURCE_TYPES[r.type].hp || 1; r.rise = 0;
          r.anim = { kind: 'grow', t: 0, dur: 1.2 };
          this.animating.add(r);
        } else if (this.regrowBlocked?.(r)) { g.at = this.time + 20; continue; }
        this.destroyed.delete(k);
        this.regrow.delete(k);
      }
    }

    // pop-up: each card rotates up about its fold from lying flat, staggered, with overshoot
    for (const ch of this.chunks.values()) {
      if (ch.settled) continue;
      const t = this.time - ch.born;
      let done = true;
      for (const r of ch.resources) {
        const local = t - r.delay;
        r.rise = springRise(local);
        if (local < 1.3) done = false;
        this.writeMatrix(r);
      }
      if (done) { ch.settled = true; for (const r of ch.resources) { r.rise = 1; this.writeMatrix(r); } }
    }
    this.updateAnimations(dt);
    this.flushPools();
  }

  /**
   * One instanced mesh per prop type for the whole world (not one per chunk): chunks borrow slots
   * from it and hand them back when they unload. ~11 draw calls for all props instead of ~230.
   */
  pool(type) {
    let pool = this.pools[type];
    if (pool) return pool;
    const kind = propKinds()[type], base = type.split('~')[0]; // ('rock~1': a second cut of rock, pooled on its own)
    const cap = Math.ceil((POOL_CAP[base] || 600) / (CUTS[base] ? 2 : 1));
    let geo = kind.geometry, mat = kind.material;
    // rocks from the reference art, where they've been made: the model baked to one geometry, as wide as the card
    // outcrop it replaces and standing on 0, so the pool, the regrowth and the ghosting all work as before
    const src = ROCK_MODELS[type] && propModel(ROCK_MODELS[type][0]);
    if (src) {
      let g = null; src.scene.updateWorldMatrix(true, true);
      src.scene.traverse((o) => { if (o.isMesh && !g) { g = o.geometry.clone().applyMatrix4(o.matrixWorld); mat = o.material; } });
      kind.geometry.computeBoundingBox(); g.computeBoundingBox();
      const cb = kind.geometry.boundingBox, b = g.boundingBox, k = (cb.max.x - cb.min.x) * ROCK_MODELS[type][1] / (b.max.x - b.min.x);
      g.translate(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2).scale(k, k, k); g.computeBoundingSphere(); geo = g;
    }
    let ghost = null;
    if (OCCLUDERS[base]) {
      // cards that can stand between the camera and the farmer can dissolve to a faint ghost through a fine stipple
      // (no movement) and fill back in afterwards. Only the few that are fading move into this small ghost mesh,
      // so the thousands of ordinary trees keep a plain material with no per-pixel test (a big cost in Firefox).
      const GHOSTS = 24, ggeo = geo.clone(), fade = new THREE.InstancedBufferAttribute(new Float32Array(GHOSTS), 1);
      ggeo.setAttribute('fade', fade);
      const gmat = mat.clone();
      const p = screenCoordinate.xy; // interleaved-gradient noise: an even, fine-grained stipple
      const ign = fract(float(52.9829189).mul(fract(p.x.mul(0.06711056).add(p.y.mul(0.00583715)))));
      gmat.opacityNode = select(attribute('fade', 'float').greaterThan(ign), float(0), float(1));
      gmat.alphaTest = 0.5;
      const gm = new THREE.InstancedMesh(ggeo, gmat, GHOSTS);
      gm.castShadow = true; gm.receiveShadow = true; gm.frustumCulled = false; gm.count = 0;
      const white = new THREE.Color(1, 1, 1); for (let i = 0; i < GHOSTS; i++) gm.setColorAt(i, white);
      this.scene.add(gm);
      ghost = { mesh: gm, fade, owners: [], cap: GHOSTS };
    }
    const mesh = new THREE.InstancedMesh(geo, mat, cap);
    mesh.castShadow = base !== 'grass' && base !== 'flowers' && base !== 'lilypad' && base !== 'lilybloom';
    mesh.receiveShadow = true;
    mesh.frustumCulled = false; // instances span the whole view; per-instance culling isn't worth it
    const white = new THREE.Color(1, 1, 1);
    for (let i = 0; i < cap; i++) mesh.setColorAt(i, white);
    mesh.count = 0; // only live instances are drawn; the pool stays packed
    this.scene.add(mesh);
    pool = this.pools[type] = { mesh, ghost, cap, owners: [], dirty: true, colorDirty: true, lo: 0, hi: cap - 1, clo: 0, chi: cap - 1 };
    return pool;
  }

  /** Take the next slot at the end of the packed range. */
  allocSlot(pool, res) {
    if (pool.mesh.count >= pool.cap) return -1;
    const slot = pool.mesh.count++;
    pool.owners[slot] = res;
    return slot;
  }

  /** Free a slot by moving the last live instance into it (keeps the range packed). */
  releaseSlot(pool, slot) {
    const last = pool.mesh.count - 1;
    if (slot !== last) {
      pool.mesh.getMatrixAt(last, _m); pool.mesh.setMatrixAt(slot, _m);
      pool.mesh.getColorAt(last, _c); pool.mesh.setColorAt(slot, _c);
      const moved = pool.owners[last];
      pool.owners[slot] = moved;
      moved.index = slot;
    }
    pool.owners[last] = undefined;
    pool.mesh.count = last;
    markDirty(pool, slot); markColor(pool, slot);
  }

  createChunk(cx, cz) {
    const terrain = new THREE.Mesh(buildTerrain(cx, cz), this.groundMat);
    this.paintRegionMap(cx, cz);
    terrain.castShadow = true;
    terrain.receiveShadow = true;
    this.scene.add(terrain);
    const placed = placeProps(cx, cz, this.exclusions);
    const resources = [];
    const tint = new THREE.Color();
    const rng = mulberry32(hash2(cx, cz, SEED + 13));
    const born = this.time;
    const counters = {};
    for (const r of placed) {
      // rocks and bushes come in three cuts (see props.js); which one stands here is fixed by where it stands
      const cut = CUTS[r.type] ? Math.abs(Math.floor(r.x * 0.73 + r.z * 1.31)) % CUTS[r.type] : 0, pool = this.pool(cut ? r.type + '~' + cut : r.type);
      const i = counters[r.type] = (counters[r.type] || 0) + 1;
      const v = (r.tone ?? 1) * (0.95 + rng() * 0.1);
      const jitter = rng();
      const res = {
        ...r, index: -1, mesh: pool.mesh, pool, chunk: null, key: `${cx},${cz},${r.type},${i - 1}`,
        hp: RESOURCE_TYPES[r.type].hp || 1, alive: true, anim: null, rise: 0,
        // stagger: nearer the chunk centre first, plus a little per-card jitter
        delay: 0.02 * Math.hypot(r.lx - CHUNK / 2, r.lz - CHUNK / 2) + jitter * 0.15,
      };
      const slot = this.allocSlot(pool, res);
      if (slot < 0) continue; // pool full: skip this prop rather than stall
      res.index = slot;
      res.alive = !this.destroyed.has(res.key);
      this.writeMatrix(res);
      // per-sheet tone: ±4–6 % so "the same" colour differs card to card
      if (r.tint) tint.setRGB(v * r.tint[0], v * r.tint[1], v * r.tint[2]); else tint.setRGB(v, v, v);
      pool.mesh.setColorAt(slot, tint);
      markColor(pool, slot);
      resources.push(res);
    }
    const colliders = placed.colliders || [];
    this.colliders.push(...colliders);
    const ch = { cx, cz, terrain, resources, colliders, born, settled: false, sites: placed.sites || [] };
    for (const site of ch.sites) this.onSiteLoad?.(site);
    for (const r of resources) r.chunk = ch;
    this.chunks.set(this.key(cx, cz), ch);
    return ch;
  }

  /** The guarded sites of any chunk, loaded or not (memoised: generation is deterministic). */
  sitesFor(cx, cz) {
    const k = this.key(cx, cz);
    const ch = this.chunks.get(k);
    if (ch) return ch.sites;
    return this.layoutFor(cx, cz).sites;
  }

  /** Sites and lost satchels of an unloaded chunk, generated once and memoised. */
  layoutFor(cx, cz) {
    const k = this.key(cx, cz);
    this.siteMemo = this.siteMemo || new Map();
    let s = this.siteMemo.get(k);
    if (!s) {
      const placed = placeProps(cx, cz, this.exclusions);
      const trees = placed.filter((r) => r.type === 'appletree');
      const orchard = trees.length ? { x: trees.reduce((a, r) => a + r.x, 0) / trees.length, z: trees.reduce((a, r) => a + r.z, 0) / trees.length } : null;
      s = { orchard, sites: placed.sites || [], satchels: placed.filter((r) => r.type === 'satchel').map((r) => ({ x: r.x, z: r.z, key: `${cx},${cz},satchel,0` })) };
      this.siteMemo.set(k, s);
      if (!this.chunks.has(k)) { hCache.delete(k); rCache.delete(k); } // don't keep caches for chunks nobody sees
    }
    return s;
  }

  /** The middle of a chunk's apple orchard, if it has one (loaded or not). */
  orchardFor(cx, cz) {
    const ch = this.chunks.get(this.key(cx, cz));
    if (ch) {
      const t = ch.resources.filter((r) => r.type === 'appletree');
      return t.length ? { x: t.reduce((a, r) => a + r.x, 0) / t.length, z: t.reduce((a, r) => a + r.z, 0) / t.length } : null;
    }
    return this.layoutFor(cx, cz).orchard;
  }

  /** Unopened lost satchels in a chunk (loaded or not). */
  satchelsFor(cx, cz) {
    const ch = this.chunks.get(this.key(cx, cz));
    if (ch) return ch.resources.filter((r) => r.type === 'satchel' && r.alive).map((r) => ({ x: r.x, z: r.z, key: r.key }));
    return this.layoutFor(cx, cz).satchels.filter((q) => !this.destroyed.has(q.key));
  }

  disposeChunk(k, ch) {
    for (const site of ch.sites || []) this.onSiteUnload?.(site);
    hCache.delete(k); rCache.delete(k);
    this.scene.remove(ch.terrain);
    ch.terrain.geometry.dispose();
    for (const r of ch.resources) {
      this.animating.delete(r); this.ducking.delete(r);
      this.unghost(r);
      this.releaseSlot(r.pool, r.index);
    }
    this.colliders = this.colliders.filter((c) => !ch.colliders.includes(c));
    this.chunks.delete(k);
  }

  /** Upload only the changed range of instance data, once per frame. */
  flushPools() {
    for (const t in this.pools) {
      const p = this.pools[t];
      if (p.dirty) {
        // whole-buffer upload: ranged uploads left stale matrices on the GPU (trees stuck mid-rise)
        p.mesh.instanceMatrix.needsUpdate = true;
        p.dirty = false; p.lo = Infinity; p.hi = -1;
      }
      if (p.colorDirty) {
        p.mesh.instanceColor.needsUpdate = true;
        p.colorDirty = false; p.clo = Infinity; p.chi = -1;
      }
    }
  }

  writeMatrix(res) {
    if (!res.alive && !(res.anim && res.anim.kind === 'fall')) {
      this.unghost(res);
      _m.makeScale(0, 0, 0);
      res.mesh.setMatrixAt(res.index, _m);
      if (res.pool) markDirty(res.pool, res.index);
      return;
    }
    _q.setFromAxisAngle(UP, res.rot);
    // hinge: lying folded back (−90°) → upright, about the card's base line
    const fold = RESOURCE_TYPES[res.type].flat ? 0 : (1 - res.rise) * (-Math.PI / 2) + res.lean; // flat cards just lie on the water
    _q2.setFromAxisAngle(RIGHT, fold);
    _q.multiply(_q2);
    if (res.anim && res.anim.kind !== 'grow') {
      const a = res.anim;
      _axis.copy(a.axis);
      const angle = a.kind === 'wobble'
        ? Math.sin(a.t * 38) * 0.09 * (1 - a.t / a.dur)
        : Math.pow(Math.min(1, a.t / a.dur), 2.2) * (Math.PI / 2 - 0.05);
      _q3.setFromAxisAngle(_axis, angle);
      _q.premultiply(_q3);
    }
    _p.set(res.x, res.y, res.z);
    _s.setScalar(res.scale); if (TALL[res.type]) _s.y *= TALL[res.type]; // trees stand taller than they are wide
    _m.compose(_p, _q, _s);
    const G = res.pool?.ghost;
    if (G && (res.fade || 0) > 0 && (res.ghostSlot >= 0 || G.owners.length < G.cap)) {
      if (!(res.ghostSlot >= 0)) { res.ghostSlot = G.owners.length; G.owners.push(res); G.mesh.count = G.owners.length; }
      G.mesh.setMatrixAt(res.ghostSlot, _m); G.mesh.instanceMatrix.needsUpdate = true;
      G.fade.setX(res.ghostSlot, res.fade); G.fade.needsUpdate = true;
      if (G.mesh.instanceColor) { res.mesh.getColorAt(res.index, _c); G.mesh.setColorAt(res.ghostSlot, _c); G.mesh.instanceColor.needsUpdate = true; }
      _m.makeScale(0, 0, 0); // hidden in the main pool while its ghost stands in
    } else this.unghost(res);
    res.mesh.setMatrixAt(res.index, _m);
    if (res.pool) markDirty(res.pool, res.index);
  }

  /** Hand a card's ghost slot back (the last ghost moves into the gap). */
  unghost(res) {
    if (!(res.ghostSlot >= 0)) return;
    const G = res.pool.ghost, slot = res.ghostSlot, last = G.owners.length - 1;
    if (slot !== last) {
      const moved = G.owners[last];
      G.mesh.getMatrixAt(last, _m2); G.mesh.setMatrixAt(slot, _m2);
      G.fade.setX(slot, G.fade.getX(last));
      if (G.mesh.instanceColor) { G.mesh.getColorAt(last, _c); G.mesh.setColorAt(slot, _c); G.mesh.instanceColor.needsUpdate = true; }
      G.owners[slot] = moved; moved.ghostSlot = slot;
    }
    G.owners.pop(); G.mesh.count = G.owners.length;
    G.mesh.instanceMatrix.needsUpdate = true; G.fade.needsUpdate = true;
    res.ghostSlot = -1;
  }

  updateAnimations(dt) {
    for (const res of this.animating) {
      const a = res.anim;
      if (!a) { this.animating.delete(res); continue; } // its animation was cut short (e.g. gathered mid-wobble)
      a.t += dt;
      if (a.kind === 'grow') res.rise = a.t >= a.dur ? 1 : springRise(a.t);
      if (a.t >= a.dur) {
        res.anim = null;
        this.animating.delete(res);
        if (a.kind === 'fall' && this.onResourceGone) this.onResourceGone(res, true);
      }
      this.writeMatrix(res);
    }
  }

  resourcesNear(x, z, range) {
    const out = [];
    const cx = Math.floor(x / CHUNK), cz = Math.floor(z / CHUNK);
    for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) {
      const ch = this.chunks.get(this.key(cx + dx, cz + dz));
      if (!ch) continue;
      for (const r of ch.resources) {
        const def = RESOURCE_TYPES[r.type];
        if (!r.alive || def.decor) continue;
        const rr = range + def.radius * r.scale;
        const ddx = r.x - x, ddz = r.z - z;
        if (ddx * ddx + ddz * ddz < rr * rr) out.push(r);
      }
    }
    return out;
  }

  hit(res, fromX, fromZ, damage = 1) {
    const def = RESOURCE_TYPES[res.type];
    if (res.anim?.kind === 'grow') res.rise = 1;
    res.hp = Math.max(0, res.hp - damage);
    const dx = res.x - fromX, dz = res.z - fromZ;
    const len = Math.hypot(dx, dz) || 1;
    const axis = new THREE.Vector3(dz / len, 0, -dx / len);
    if (res.hp > 0) {
      res.anim = { kind: 'wobble', t: 0, dur: 0.35, axis };
      this.animating.add(res);
      return { destroyed: false };
    }
    res.alive = false;
    this.destroyed.add(res.key);
    if (REGROW[res.type]) this.regrow.set(res.key, { at: this.time + REGROW[res.type] * (0.85 + Math.random() * 0.3) * (CROPS.has(res.type) ? this.cropGrow ?? 1 : 1), res }); // (a rain barrel from the cooper: crops come on a quarter sooner)
    const amount = def.loot[0] + Math.floor(Math.random() * (def.loot[1] - def.loot[0] + 1));
    if (def.falls) {
      res.anim = { kind: 'fall', t: 0, dur: 0.9, axis };
      this.animating.add(res);
    } else {
      res.anim = null;
      this.animating.delete(res);
      this.writeMatrix(res);
      if (this.onResourceGone) this.onResourceGone(res, false);
    }
    return { destroyed: true, amount, item: def.item };
  }

  /**
   * Tall cards standing between the camera and the farmer (trees, rocks, hills) dissolve to a faint stipple
   * so you can see him, and fill back in once the view has moved on. Nothing moves or tips over.
   */
  updateOcclusion(cam, target, dt) {
    const tx = target.x, tz = target.z, ty = target.y + 1.0;
    const sx = cam.x - tx, sz = cam.z - tz;
    const len = Math.hypot(sx, sz);
    const seen = this._seenFrame = (this._seenFrame || 0) + 1;
    if (len > 0.5) {
      const dirX = sx / len, dirZ = sz / len;
      const minX = Math.min(tx, cam.x) - 3, maxX = Math.max(tx, cam.x) + 3;
      const minZ = Math.min(tz, cam.z) - 3, maxZ = Math.max(tz, cam.z) + 3;
      for (let cx = Math.floor(minX / CHUNK); cx <= Math.floor(maxX / CHUNK); cx++) {
        for (let cz = Math.floor(minZ / CHUNK); cz <= Math.floor(maxZ / CHUNK); cz++) {
          const ch = this.chunks.get(this.key(cx, cz));
          if (!ch) continue;
          for (const r of ch.resources) {
            const occ = OCCLUDERS[r.type];
            if (!occ || !r.alive || r.rise < 0.99 || r.x < minX || r.x > maxX || r.z < minZ || r.z > maxZ) continue;
            const along = (r.x - tx) * dirX + (r.z - tz) * dirZ; // metres from the farmer toward the camera
            if (along < 0.6 || along > len + 1) continue;
            const ox = tx + dirX * along - r.x, oz = tz + dirZ * along - r.z;
            const rad = occ[1] * r.scale + 0.5;
            if (ox * ox + oz * oz > rad * rad) continue;
            const lineY = ty + (cam.y - ty) * Math.min(1, along / len);
            if (r.y + occ[0] * r.scale < lineY) continue; // the sight line passes over it
            r.duckSeen = seen;
            this.ducking.add(r);
          }
        }
      }
    }
    for (const r of this.ducking) {
      // in the way: dissolve quickly to a faint ghost; out of the way: fill back in a little more gently
      const want = r.duckSeen === seen ? 0.82 : 0;
      r.fade = want > (r.fade || 0) ? Math.min(want, (r.fade || 0) + dt * 5) : Math.max(0, (r.fade || 0) - dt * 2.5);
      if (!want && r.fade <= 0) this.ducking.delete(r);
      if (r.alive) this.writeMatrix(r);
    }
  }

  /** A dry meadow spot near the origin with land all around (for the homestead + spawn). */
  findSpawn() {
    for (let r = 0; r < 260; r += 6) {
      for (let a = 0; a < Math.PI * 2; a += 0.35) {
        const x = Math.round(Math.cos(a) * r), z = Math.round(Math.sin(a) * r);
        const reg = regionAt(x, z);
        if (reg !== 'meadow' && reg !== 'forest' && reg !== 'field') continue;
        let ok = true;
        for (let k = 0; k < 12 && ok; k++) {
          const b = (k / 12) * Math.PI * 2;
          const rr = regionAt(x + Math.cos(b) * 24, z + Math.sin(b) * 24);
          if (rr === 'water' || rr === 'peak' || rr === 'highland') ok = false;
        }
        if (ok) return new THREE.Vector3(x, 0, z);
      }
    }
    return new THREE.Vector3(0, 0, 0);
  }
}
