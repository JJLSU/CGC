// Paydirt Hollow, the town down the lane: a crooked main street of false-front buildings, gone to seed since the
// first strike played out. A general store with its windows boarded, the assay office (still open, just), a
// shuttered saloon, a two-storey boarding house, a livery barn, a leaning white church at the end of the street,
// a few canvas tents, a trough and a hitching rail. The folk who might work for you live here.
// Built the papercraft way: each building is a printed false-front card standing proud of a plain box body, with
// a plank boardwalk at its feet; the street is a long torn sheet of ochre dirt laid over the ground. The town is
// laid out once, on its own level sheet, about 85 m from the homestead. Facades are painted per "tier" so the town
// can be mended later (0 = run-down).
import * as THREE from 'three/webgpu';
import { mix, vec3, dot, uniform } from 'three/tsl';
import { cardMaterial, paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight, isWater, regionAt, landAt, addFlatArea, rangeAt, STEP } from './world.js';
import { mulberry32 } from './noise.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { makeMesh } from './building.js';
import { bakeByMaterial } from './bake.js';
import { REEL, hz } from './barndance.js';
import { Figure } from './figure.js';
import { ModelFigure, hasFolk, propModel, animalModel } from './modelfolk.js';
import { Puppet } from './puppets.js';

const rgbA = (hex) => { const c = new THREE.Color(hex); return `rgba(${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)},A)`; };
const tone = (hex, k) => { const c = new THREE.Color(hex); c.multiplyScalar(k); return `#${c.getHexString()}`; };
export function card(pts, base, draw, { W = 512, H = 512, seed = 1, thick = 0.08, snow = true } = {}) {
  const tex = paintCard(pts, { W, H, seed, base, fills: [rgbA(base), rgbA(tone(base, 0.88)), rgbA(tone(base, 1.08))], edge: rgbA(tone(base, 0.45)).replace(',A)', ',1)'), details: draw });
  // a plain back: a swatch of weathered board painted in the canvas corner (outside the cut), which the back
  // face samples, so a sign never shows through mirrored from behind
  let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
  for (const [x, y] of pts) { minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
  const c = tex.image, g = c.getContext('2d'); g.fillStyle = tone(base, 0.62); g.fillRect(0, 0, 12, 12); tex.needsUpdate = true;
  const w0 = maxX - minX, h0 = maxY - minY, back = [minX - w0 * 0.04 + (6 / c.width) * w0 * 1.08, maxY + h0 * 0.04 - (6 / c.height) * h0 * 1.08];
  const m = new THREE.Mesh(cardGeometry(pts, thick, back), cardMaterial(tex, { snow })); m.castShadow = true; m.receiveShadow = true;
  return m;
}
const box = (w, h, d, color) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), paperMaterial({ color, flatShading: true })); m.castShadow = true; m.receiveShadow = true; return m; };

// the buildings, left side then right side, from the end nearest the homestead; s = position along the street
const BUILDINGS = [
  { id: 'store', name: 'general store', cost: 25, sign: 'GENERAL MDSE.', worn: 'GEN RAL MDSE', w: 7, h: 3.6, d: 7, paint: 0xb8a07a, side: -1, s: -12 },
  { id: 'assay', name: 'assay office', cost: 15, sign: 'ASSAY OFFICE', worn: 'ASSAY OFFICE', w: 4.6, h: 3.2, d: 5, paint: 0x9a5a48, side: -1, s: -3 },
  { id: 'boarding', name: 'boarding house', cost: 35, sign: 'BOARDING', worn: 'BOARD NG', w: 6.4, h: 5.6, d: 6.5, paint: 0x7a8690, side: -1, s: 6.5 },
  { id: 'saloon', name: 'Golden Garter saloon', cost: 30, sign: 'GOLDEN GARTER', worn: 'GOLD N GART R', w: 6.6, h: 4, d: 7, paint: 0xb89a52, side: 1, s: -11 },
  { id: 'livery', name: 'livery barn', cost: 20, sign: 'LIVERY', worn: 'LIV RY', w: 7.4, h: 4.4, d: 8, paint: 0x8a5a3e, side: 1, s: -1, barn: true },
  { id: 'smithy', name: "blacksmith's", cost: 20, sign: 'BLACKSMITH', worn: 'BLACKSM TH', w: 5, h: 3.4, d: 5.5, paint: 0x6e6660, side: 1, s: 8 },
];
const SMOKERS = { smithy: 'day', bakery: 'day', cooper: 'day', boarding: 'meals', hotel2: 'meals' }; // (whose stovepipes smoke, and when)
// lamplight on the ground: a warm amber round, brightest under the lamp and fading out to a ragged edge (drawn once,
// shared by every street lamp; added over the dirt, so it warms what's there rather than painting over it)
const POOL_MAT = (() => {
  const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  const grd = g.createRadialGradient(64, 64, 4, 64, 64, 60); grd.addColorStop(0, 'rgba(255,190,110,0.55)'); grd.addColorStop(0.45, 'rgba(240,160,80,0.28)'); grd.addColorStop(1, 'rgba(220,130,60,0)');
  g.fillStyle = grd; g.beginPath();
  for (let i = 0; i <= 40; i++) { const a = (i / 40) * Math.PI * 2, r = 54 + Math.sin(i * 2.7) * 4 + Math.sin(i * 1.3) * 3; g.lineTo(64 + Math.cos(a) * r, 64 + Math.sin(a) * r); }
  g.fill();
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  return new THREE.MeshBasicNodeMaterial({ map: t, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });
})();
// the flower barrels' paper, shared by every barrel in town so each bakes down to a handful of meshes
const BARREL_MATS = { keg: paperMaterial({ color: 0x8a6038, flatShading: true }), fl: [0xc4362f, 0xe8b84a, 0xf6efe0].map((c) => paperMaterial({ color: c, flatShading: true })), leaf: paperMaterial({ color: 0x6a8a4a, flatShading: true }) };
const HALF = 6.2; // half the street's width, to the building fronts
// The town grows: once every building on Main Street is mended, folk put up Second Street alongside it, a row of
// tumbledown buildings that want mending in turn; mend those and Third Street goes up on the other side. Each new
// building wears one of the town's models (`model`) in a new trade, with its own name and sign.
const STREETS = [
  { id: 'second', name: 'Second Street', buildings: [
    { id: 'bank', name: 'Miners\' bank', model: 'hotel', cost: 40, sign: 'MINERS BANK', worn: 'MIN RS BA K', w: 6.4, h: 5.2, d: 6.5, paint: 0x8a7a6a, side: -1, s: -12 },
    { id: 'barber', name: 'barber shop', model: 'assay', cost: 15, sign: 'BARBER', worn: 'BAR ER', w: 4.6, h: 3.2, d: 5, paint: 0x7a9aa0, side: -1, s: -3 },
    { id: 'bakery', name: 'bakery', model: 'store', cost: 25, sign: 'BAKERY', worn: 'BAK RY', w: 7, h: 3.6, d: 7, paint: 0xc8a878, side: -1, s: 7 },
    { id: 'jail', name: 'sheriff\'s jail', model: 'blacksmith', cost: 25, sign: 'JAIL', worn: 'JA L', w: 5, h: 3.4, d: 5.5, paint: 0x8a8278, side: 1, s: -11 },
    { id: 'feed', name: 'feed & grain', model: 'livery', cost: 25, sign: 'FEED & GRAIN', worn: 'FEE  GRAIN', w: 7.4, h: 4.4, d: 8, paint: 0x9a6a3e, side: 1, s: -1, barn: true },
    { id: 'opera', name: 'opera house', model: 'saloon', cost: 45, sign: 'OPERA HOUSE', worn: 'OPER  HOUS', w: 6.6, h: 4, d: 7, paint: 0xa85a5a, side: 1, s: 9 },
  ] },
  { id: 'third', name: 'Third Street', buildings: [
    { id: 'telegraph', name: 'telegraph office', model: 'assay', cost: 30, sign: 'TELEGRAPH', worn: 'TELE RAPH', w: 4.6, h: 3.2, d: 5, paint: 0x6a7a8a, side: -1, s: -12 },
    { id: 'hotel2', name: 'Grand Hotel', model: 'hotel', cost: 50, sign: 'GRAND HOTEL', worn: 'GR ND HOT L', w: 6.4, h: 5.6, d: 6.5, paint: 0x9a8a6a, side: -1, s: -2 },
    { id: 'drygoods', name: 'dry goods', model: 'store', cost: 30, sign: 'DRY GOODS', worn: 'DRY GO DS', w: 7, h: 3.6, d: 7, paint: 0xa8b08a, side: -1, s: 8 },
    { id: 'cooper', name: 'cooperage', model: 'blacksmith', cost: 25, sign: 'COOPER', worn: 'COO ER', w: 5, h: 3.4, d: 5.5, paint: 0x7a6650, side: 1, s: -11 },
    { id: 'stable2', name: 'stage stables', model: 'livery', cost: 30, sign: 'STAGE LINE', worn: 'STA E LINE', w: 7.4, h: 4.4, d: 8, paint: 0x7a4a3a, side: 1, s: -1, barn: true },
    { id: 'dance', name: 'dance hall', model: 'saloon', cost: 45, sign: 'DANCE HALL', worn: 'DAN E HALL', w: 6.6, h: 4, d: 7, paint: 0xb88a52, side: 1, s: 9 },
  ] },
];
// the opera house's bill: a different tall tale on the boards each night, played by a touring company
export const PLAYBILL = [
  ['PAUL BUNYAN', 'and Babe the Blue Ox', 'A lumberjack ten axe-handles high clears the whole of Dakota in a week, and Babe drinks a river dry.'],
  ['PECOS BILL', 'Rides the Cyclone', 'Raised by coyotes, Bill lassoes a twister and rides it bareback clear across Texas, whooping.'],
  ['JOHN HENRY', 'the Steel-Driving Man', 'Hammer in hand, John Henry races the steam drill through the mountain, and the whole house stands to sing.'],
  ['DAVY CROCKETT', 'and the Frozen Dawn', 'Davy thaws the sun loose with bear grease when the world freezes on its axle. The gallery stamps its boots.'],
  ['MIKE FINK', 'King of the Keelboats', 'The roaring river man brags, brawls and poles his keelboat up the Mississippi against a flood.'],
  ['FEBOLD FEBOLDSON', 'and the Year of Two Summers', 'It got so hot the corn popped in the fields and the cows froze, thinking it was snow.'],
  ['SALLY ANN THUNDER', 'Whirlwind Crockett', 'She wears a hornet\'s nest for a bonnet and skins a grizzly with her own two hands. The ladies cheer loudest.'],
];
const LAMP_GLASS = new THREE.MeshBasicNodeMaterial({ color: 0x5a5248 }); // (shared by every door lantern: one colour flip lights them all)
const NIGHT_OWLS = new Set(['saloon', 'hotel2']); // (whose doors stay kept all night)
const STREET_OFF = 32; // how far a new street lies off Main Street
// As the town grows, more folk pitch tents on Squatters' Row: a second rank of tents goes up behind the first with
// each new street, and the family in each one wants something they can't get in town. Bring it and they pay for it;
// the next morning they want something else. [item, how many, dollars, what they say]
const WANTS = [
  ['apples', 3, 4, 'a sack of apples for the young ones'], ['fish', 2, 5, 'a couple of fish for supper'], ['bread', 1, 4, 'a loaf of bread'],
  ['wood', 6, 3, 'firewood: the nights are cold under canvas'], ['venison', 2, 7, 'venison, if you hunt'], ['honey', 1, 5, 'a jar of honey for a cough'],
  ['pelt', 1, 6, 'a hide to patch the tent'], ['egg', 4, 3, 'a few eggs'], ['rope', 2, 4, 'rope to guy the tent down'], ['berries', 4, 3, 'berries for a pie'],
];
const ROW_FOLK = [['folk_calico_01', 'Widow Pruitt'], ['folk_farmhand_01', 'Jeb Calloway'], ['folk_calico_02', 'Mrs. Dunaway'], ['prospectors_3', 'Old Hiram'],
  ['folk_farmhand_02', 'Tom Kessler'], ['folk_calico_03', 'Ada Lark'], ['prospectors_4', 'Rufus Pike'], ['folk_farmhand_03', 'Silas Fry']];

/** A false front: the tall printed face with a stepped parapet, painted for its tier. */
function facade(b, tier, seed) {
  const W = b.w + 0.4, H = b.h, top = H + (b.barn ? 1.8 : 1.5);
  const pts = b.barn
    ? [[-W / 2, 0], [W / 2, 0], [W / 2, H], [0, top], [-W / 2, H]]
    : [[-W / 2, 0], [W / 2, 0], [W / 2, H + 0.9], [W / 2 - 0.3, H + 0.9], [W / 2 - 0.3, H + 1.25], [0.7, H + 1.25], [0.45, top], [-0.45, top], [-0.7, H + 1.25], [-W / 2 + 0.3, H + 1.25], [-W / 2 + 0.3, H + 0.9], [-W / 2, H + 0.9]];
  const paint = tier ? b.paint : tone(b.paint, 0.82);
  return card(pts, paint, (g, px, rng) => {
    // clapboards, the paint peeling off in pale patches (run-down), nail heads
    g.strokeStyle = 'rgba(40,28,20,0.35)'; g.lineWidth = 2;
    for (let y = 0.25; y < top; y += 0.25) { const [a, c] = px(-W / 2, y), [d] = px(W / 2, y); g.beginPath(); g.moveTo(a, c); g.lineTo(d, c); g.stroke(); }
    if (!tier) for (let i = 0; i < 16; i++) { const [x, y] = px(-W / 2 + rng() * W, rng() * top); g.fillStyle = 'rgba(214,200,172,0.55)'; g.beginPath(); g.ellipse(x, y, 8 + rng() * 22, 5 + rng() * 10, rng() * 3, 0, Math.PI * 2); g.fill(); }
    // the sign board under the parapet, its letters gone patchy
    const [s0x, s0y] = px(-W / 2 + 0.5, H + 0.75), [s1x, s1y] = px(W / 2 - 0.5, H + 0.05);
    g.fillStyle = tier ? '#efe3c4' : '#c9b896'; g.fillRect(s0x, s0y, s1x - s0x, s1y - s0y);
    g.strokeStyle = 'rgba(40,28,20,0.6)'; g.lineWidth = 3; g.strokeRect(s0x, s0y, s1x - s0x, s1y - s0y);
    g.fillStyle = tier ? '#3a2a1c' : 'rgba(58,42,28,0.8)'; g.font = `bold ${Math.round((s1y - s0y) * 0.62)}px Georgia, serif`; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(tier ? b.sign : b.worn, (s0x + s1x) / 2, (s0y + s1y) / 2 + 2);
    // door and windows; boarded over while the town is down on its luck
    const door = (x0, w, h) => { const [a, c] = px(x0, h), [d, e] = px(x0 + w, 0); g.fillStyle = '#3a2a20'; g.fillRect(a, c, d - a, e - c); g.strokeStyle = 'rgba(200,180,140,0.5)'; g.lineWidth = 2; g.strokeRect(a + 3, c + 3, d - a - 6, e - c - 6); };
    const win = (x0, y0, w, h) => {
      const [a, c] = px(x0, y0 + h), [d, e] = px(x0 + w, y0); g.fillStyle = '#2e3a40'; g.fillRect(a, c, d - a, e - c);
      if (!tier) { g.fillStyle = '#a88a5e'; g.save(); g.translate((a + d) / 2, (c + e) / 2); for (const r of [0.5, -0.45]) { g.save(); g.rotate(r); g.fillRect(-(d - a) * 0.62, -6, (d - a) * 1.24, 12); g.restore(); } g.restore(); }
      else { g.strokeStyle = '#efe3c4'; g.lineWidth = 4; g.strokeRect(a, c, d - a, e - c); g.beginPath(); g.moveTo((a + d) / 2, c); g.lineTo((a + d) / 2, e); g.stroke(); }
    };
    if (b.barn) { door(-1.4, 2.8, 3.2); g.strokeStyle = '#efe3c4'; g.lineWidth = 3; const [a, c] = px(-1.4, 3.2), [d, e] = px(1.4, 0); g.beginPath(); g.moveTo(a, c); g.lineTo(d, e); g.moveTo(d, c); g.lineTo(a, e); g.stroke(); win(-0.6, 3.6, 1.2, 0.8); }
    else {
      door(-0.55, 1.1, 2.2);
      win(-W / 2 + 0.5, 0.9, 1.4, 1.4); win(W / 2 - 1.9, 0.9, 1.4, 1.4);
      if (H > 4.5) for (const x of [-W / 2 + 0.6, -0.6, W / 2 - 1.8]) win(x, 3.3, 1.2, 1.3); // the boarding house's upper rooms
    }
    if (b.id === 'saloon' && !tier) { g.fillStyle = '#7a5a38'; const [a, c] = px(-0.7, 1.6), [d, e] = px(0.7, 0.4); g.fillRect(a, c, d - a, e - c); } // batwings nailed shut
  }, { W: Math.round(W * 70), H: Math.round(top * 70), seed });
}

// the buildings made from the reference art (Meshy, from the town sheets), by the town's names for them: a
// building wears its model when one has been made, ruined until it's mended, restored after
const MODEL_OF = { smithy: 'blacksmith', saloon: 'saloon', store: 'store', boarding: 'hotel', church: 'church', assay: 'assay', livery: 'livery' };
// a building drawn in one state only (the assay office, the livery barn) stands faded, greyed and a touch askew till mended
const _faded = new WeakMap();
function faded(mat) {
  if (!_faded.has(mat)) {
    const m = mat.clone(), c = mat.colorNode; m.colorNode = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.55).mul(0.8);
    if (mat.emissiveNode) m.emissiveNode = mat.emissiveNode.mul(0.6);
    _faded.set(mat, m);
  }
  return _faded.get(mat);
}
const _bb = new THREE.Box3(), _bs = new THREE.Vector3(), _bc = new THREE.Vector3();
function modelBuilding(id, tier, width, height, model = MODEL_OF[id]) {
  const two = model && propModel(`bldg_${model}_${tier ? 'restored' : 'ruined'}`), one = !two && model && propModel(`bldg_${model}`);
  const src = two || one;
  if (!src) return null;
  const g = new THREE.Group(), m = src.scene.clone();
  if (one && !tier) { m.traverse((o) => { if (o.isMesh && o.material.colorNode) o.material = faded(o.material); }); m.rotation.z = 0.015; }
  _bb.setFromObject(m); _bb.getSize(_bs); _bb.getCenter(_bc);
  // its body (not the debris round it) about as wide as the false front it stands in for, and no taller than that front
  // with its parapet, so a ruin and its mended self stand the same size; its front (glTF +Z) to the street
  const s = Math.min(width * 1.15 / (src.info?.body?.x || _bs.x), height / _bs.y);
  m.scale.setScalar(s); m.position.set(-(src.info?.body?.cx ?? _bc.x) * s, -_bb.min.y * s, -_bb.max.z * s + 0.5);
  g.add(m); g.userData.model = true; return g;
}

function building(b, tier, rng) {
  const own = b.model && (propModel(`bldg_${b.id}_ruined`) || propModel(`bldg_${b.id}`)); // (a new street's building wears its own model once it's made, else a Main Street one in a new trade)
  const mg = modelBuilding(b.id, tier, b.w + 0.4, b.h + (b.barn ? 1.8 : 1.5), own ? b.id : b.model);
  if (mg) { // the model, on the town's boardwalk planks
    const walk = box(b.w + 0.6, 0.14, 1.8, tier ? 0xa8845a : 0x8a7458); walk.position.set(0, 0.07, 0.95); mg.add(walk);
    return mg;
  }
  const g = new THREE.Group();
  const body = box(b.w, b.h, b.d, tone(b.paint, tier ? 0.85 : 0.68)); body.position.set(0, b.h / 2, -b.d / 2); g.add(body);
  // a pitched roof of weathered shakes behind the false front, a bit sway-backed on the run-down ones
  const pitch = b.barn ? 0.62 : 0.32, half = b.w / 2 / Math.cos(pitch) + 0.15;
  for (const sx of [-1, 1]) {
    const r = box(half, 0.14, b.d + 0.3, tier ? 0x6a4a34 : 0x5a4a3e);
    r.position.set(sx * b.w / 4, b.h + Math.tan(pitch) * b.w / 4, -b.d / 2); r.rotation.z = -sx * pitch + (tier ? 0 : (rng() - 0.5) * 0.06); g.add(r);
  }
  const front = facade(b, tier, 701 + Math.round(rng() * 99)); front.position.z = 0.06; front.rotation.z = tier ? 0 : (rng() - 0.5) * 0.025; g.add(front);
  // the boardwalk: planks at its feet, with a hitching rail before the store and the saloon
  const walk = box(b.w + 0.6, 0.14, 1.8, tier ? 0xa8845a : 0x8a7458); walk.position.set(0, 0.07, 0.95); g.add(walk);
  if (b.id === 'store' || b.id === 'saloon') { const rail = box(3, 0.1, 0.1, 0x6a4a30); rail.position.set(0, 0.95, 2.3); g.add(rail); for (const x of [-1.4, 1.4]) { const p = box(0.12, 1, 0.12, 0x6a4a30); p.position.set(x, 0.5, 2.3); g.add(p); } }
  // once mended, lamplight in the windows after dark (warm panes over the painted glass; shown by Town.update)
  if (tier) {
    const W = b.w + 0.4, panes = b.barn ? [[-0.6, 3.6, 1.2, 0.8]] : [[-W / 2 + 0.5, 0.9, 1.4, 1.4], [W / 2 - 1.9, 0.9, 1.4, 1.4], ...(b.h > 4.5 ? [-W / 2 + 0.6, -0.6, W / 2 - 1.8].map((x) => [x, 3.3, 1.2, 1.3]) : []), ...(b.id === 'saloon' ? [[-0.55, 0.3, 1.1, 1.6]] : [])];
    const glow = new THREE.Group(); glow.visible = false;
    for (const [x, y, w, h] of panes) { const m = new THREE.Mesh(new THREE.PlaneGeometry(w - 0.16, h - 0.16), lampMat()); m.position.set(x + w / 2, y + h / 2, 0.112); glow.add(m); }
    g.add(glow); g.userData.glow = glow;
  }
  return g;
}
let _lamp = null;
const lampMat = () => (_lamp ||= new THREE.MeshBasicNodeMaterial({ color: 0xffc46a }));

function church(tier) {
  const mg = modelBuilding('church', tier, 5.6, 10); if (mg) return mg;
  const g = new THREE.Group(), white = tier ? 0xefe9dc : 0xc8c0b0;
  const body = box(5.4, 4.2, 8.5, white); body.position.set(0, 2.1, -4.25); g.add(body);
  for (const sx of [-1, 1]) { const r = box(3.6, 0.14, 8.9, 0x5a4a3e); r.position.set(sx * 1.35, 5.0, -4.25); r.rotation.z = -sx * 0.62; g.add(r); }
  const gable = card([[-2.75, 0], [2.75, 0], [0, 2.1]], tier ? '#efe9dc' : '#c8c0b0', (gg, px) => { gg.fillStyle = '#3e5662'; const [x, y] = px(0, 0.9); gg.beginPath(); gg.arc(x, y, 18, 0, Math.PI * 2); gg.fill(); }, { W: 256, H: 128, seed: 741 });
  gable.position.set(0, 4.2, 0.02); g.add(gable);
  const door = card([[-0.7, 0], [0.7, 0], [0.7, 2.0], [0, 2.5], [-0.7, 2.0]], '#5a3a2a', null, { W: 96, H: 128, seed: 743 }); door.position.set(0, 0, 0.03); g.add(door);
  // the steeple, leaning a little till the town can mend it
  const tower = new THREE.Group(); tower.position.set(0, 4.2, -1.2); tower.rotation.z = tier ? 0 : 0.07; g.add(tower);
  const t1 = box(1.6, 2.6, 1.6, white); t1.position.y = 1.3; tower.add(t1);
  const spire = new THREE.Mesh(new THREE.ConeGeometry(1.25, 3.0, 4).rotateY(Math.PI / 4), paperMaterial({ color: 0x5a4a3e, flatShading: true })); spire.position.y = 4.1; spire.castShadow = true; tower.add(spire);
  const walk = box(2.6, 0.3, 1.4, 0x8a7458); walk.position.set(0, 0.15, 0.7); g.add(walk);
  return g;
}

/** A canvas A-frame tent: two printed canvas sheets leaning together on a ridge pole, triangular end walls (a
 *  dark doorway at the front, the flap tied back), patches and seams, a weather stain at the hem, guy-ropes. */
// a lantern lit inside every tent after dark: the canvas glows warm from within (one shared uniform, no lights)
const uTentGlow = uniform(0), TENT_MATS = new Map();
function lampLit(g) {
  g.traverse((o) => {
    if (!o.isMesh) return;
    let m = TENT_MATS.get(o.material);
    if (!m) { m = o.material.clone(); const e = o.material.emissiveNode; m.emissiveNode = e ? e.mul(uTentGlow.mul(5).add(1)).add(vec3(1.0, 0.55, 0.25).mul(uTentGlow.mul(0.12))) : vec3(1.0, 0.6, 0.28).mul(uTentGlow.mul(0.5)); TENT_MATS.set(o.material, m); TENT_MATS.set(m, m); } // (the print itself glows, so patches and seams still show)
    o.material = m;
  });
  return g;
}
function tent(rng) { return lampLit(tentShape(rng)); }
function tentShape(rng) {
  const tsrc = propModel('prop_tent');
  if (tsrc) { // the patched wall tent from the reference art: flap tied back, guy ropes pegged out (each a little bigger or smaller)
    const g = new THREE.Group(), m = tsrc.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3());
    const k = (2.6 + rng()) * 1.5 / sz.x; m.scale.setScalar(k); m.position.set(-c.x * k, -bb.min.y * k, -c.z * k); g.add(m); return g;
  }
  const g = new THREE.Group(), w = 2.6 + rng(), d = 3 + rng() * 1.2, H = 1.9, L = Math.hypot(w / 2, H), slope = Math.atan2(w / 2, H);
  const canvas = (gg, px, r, len) => {
    gg.strokeStyle = 'rgba(120,100,70,0.45)'; gg.lineWidth = 2; gg.setLineDash([5, 4]);
    for (const y of [len * 0.33, len * 0.66]) { const [a, b] = px(-d / 2, y), [c] = px(d / 2, y); gg.beginPath(); gg.moveTo(a, b); gg.lineTo(c, b); gg.stroke(); } // sewn seams
    gg.setLineDash([]);
    for (let i = 0; i < 2; i++) { const [a, b] = px(-d / 2 + 0.3 + r() * (d - 1), 0.3 + r() * (len - 0.9)); gg.fillStyle = i ? '#b8a07a' : '#9aa8a0'; gg.fillRect(a, b, 30 + r() * 20, 22 + r() * 14); gg.strokeStyle = 'rgba(90,70,50,0.6)'; gg.setLineDash([3, 3]); gg.strokeRect(a, b, 30, 22); gg.setLineDash([]); } // patches, stitched on
    const [h0, h1] = px(-d / 2, 0.35), [h2, h3] = px(d / 2, 0); gg.fillStyle = 'rgba(110,90,60,0.25)'; gg.fillRect(h0, h1, h2 - h0, h3 - h1); // mud splashed up the hem
  };
  for (const sx of [-1, 1]) {
    const sheet = card([[-d / 2, 0], [d / 2, 0], [d / 2, L], [-d / 2, L]], '#d8ccae', (gg, px, r) => canvas(gg, px, r, L), { W: Math.round(d * 64), H: Math.round(L * 64), seed: 861 + Math.round(rng() * 50), thick: 0.04 });
    const hold = new THREE.Group(); sheet.rotation.y = sx * Math.PI / 2; hold.add(sheet); // printed side outward
    hold.position.set(sx * w / 2, 0, 0); hold.rotation.z = sx * slope; g.add(hold);
  }
  // the end walls: the front with its doorway and the flap tied back, the back plain
  const front = card([[-w / 2, 0], [w / 2, 0], [0, H]], '#d0c4a4', (gg, px) => {
    gg.fillStyle = '#2a201a'; gg.beginPath(); const [a, b] = px(-0.45, 0), [c] = px(0.45, 0), [e, f] = px(0, 1.35); gg.moveTo(a, b); gg.lineTo(c, b); gg.lineTo(e, f); gg.closePath(); gg.fill();
    gg.fillStyle = '#e2d6b8'; gg.beginPath(); const [k, l] = px(0.45, 0), [m, n] = px(0.95, 0.15), [o, q] = px(0.2, 1.1); gg.moveTo(k, l); gg.lineTo(m, n); gg.lineTo(o, q); gg.closePath(); gg.fill(); // the flap, tied back
  }, { W: Math.round(w * 64), H: Math.round(H * 64), seed: 871, thick: 0.04 });
  front.position.z = d / 2; g.add(front);
  const back = card([[-w / 2, 0], [w / 2, 0], [0, H]], '#c8bc9c', null, { W: 96, H: 64, seed: 873, thick: 0.04 }); back.position.z = -d / 2; back.rotation.y = Math.PI; g.add(back);
  const pole = box(0.07, 0.07, d + 0.5, 0x6a4a30); pole.position.set(0, H + 0.03, 0); g.add(pole);
  for (const z of [d / 2 + 0.2, -d / 2 - 0.2]) { const p = box(0.07, H + 0.25, 0.07, 0x6a4a30); p.position.set(0, (H + 0.25) / 2, z); g.add(p); }
  for (const z of [d / 2, -d / 2]) { const rope = box(0.02, 0.02, 1.6, 0xb8a888); rope.position.set(0, H * 0.55, z + Math.sign(z) * 0.7); rope.rotation.x = Math.sign(z) * 0.95; g.add(rope); } // guy-ropes to pegs
  for (const c of g.children) c.position.z -= d / 2 + 0.9; // the doorway (and its guy-rope) at the front of the plot, so the folk stand outside it
  return g;
}

/** A squatter's shanty: a crooked box of grey scrap boards under a rusted tin roof, a rag at the window, a stovepipe. */
function shanty(rng) {
  const g = new THREE.Group(), w = 2.2 + rng() * 0.8, h = 1.9 + rng() * 0.3, d = 2.2 + rng() * 0.5;
  const body = box(w, h, d, 0x7a7068); body.position.set(0, h / 2, -d / 2); body.rotation.z = (rng() - 0.5) * 0.06; g.add(body);
  const front = card([[-w / 2, 0], [w / 2, 0], [w / 2 - 0.05, h], [-w / 2 + 0.08, h + 0.1]], '#8a8076', (gg, px, r) => {
    gg.strokeStyle = 'rgba(40,32,26,0.5)'; gg.lineWidth = 2; for (let x = -w / 2 + 0.25; x < w / 2; x += 0.28) { const [a, b] = px(x, 0), [, c] = px(x + (r() - 0.5) * 0.05, h); gg.beginPath(); gg.moveTo(a, b); gg.lineTo(a, c); gg.stroke(); }
    for (let i = 0; i < 3; i++) { const [a, b] = px(-w / 2 + r() * w * 0.8, 0.3 + r() * (h - 0.6)); gg.fillStyle = ['#a88a5e', '#6e8a9a', '#9a6a4a'][i]; gg.fillRect(a, b, 26 + r() * 20, 18 + r() * 12); } // patches of scavenged board
    const [d0, d1] = px(-0.4, 1.6), [d2, d3] = px(0.4, 0); gg.fillStyle = '#2a201a'; gg.fillRect(d0, d1, d2 - d0, d3 - d1); // the doorway, a sack hung across it
    gg.fillStyle = '#b8a07a'; gg.fillRect(d0 + 4, d1 + 4, (d2 - d0) * 0.6, (d3 - d1) * 0.7);
    const [w0, w1] = px(w / 2 - 0.75, 1.5), [w2, w3] = px(w / 2 - 0.25, 1.05); gg.fillStyle = '#2e3a40'; gg.fillRect(w0, w1, w2 - w0, w3 - w1); gg.fillStyle = '#c4362f'; gg.fillRect(w0, w1, (w2 - w0) * 0.5, w3 - w1); // a rag for a curtain
  }, { W: Math.round(w * 70), H: Math.round((h + 0.1) * 70), seed: 801 + Math.round(rng() * 99) });
  front.position.z = 0.05; g.add(front);
  const roof = box(w + 0.5, 0.08, d + 0.6, 0x8a5e48); roof.position.set(0, h + 0.18, -d / 2); roof.rotation.x = -0.18; roof.rotation.z = (rng() - 0.5) * 0.1; g.add(roof); // rusted tin, pitched to the back
  const pipe = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 1.0, 6), paperMaterial({ color: 0x2b2622 })); pipe.position.set(w / 2 - 0.4, h + 0.6, -d + 0.4); pipe.rotation.z = 0.1; g.add(pipe);
  return g;
}

// who stands out front of each building once it's mended (at: metres along the boardwalk from the door)
const TOWNSFOLK = {
  store: { model: 'townsfolk_3', with: [{ model: 'townsfolk_4', at: -2.5, out: 0.7, turn: 0.35 }], look: { coat: 0xefe3c4, sleeve: 0xefe3c4, vest: 0x5a6a4a, apron: 0xf6efe0, pants: 0x4a4440, hair: 0x6a4a30, beard: 0x6a4a30, hat: 'none', collar: 0xffffff }, pose: null }, // Mr. Dobbs the storekeeper, in his long white apron
  boarding: { model: 'trades_5', look: { coat: 0x7a8690, dress: 0x7a8690, dressPat: 2, apron: 0xf6efe0, hair: 0x9a8a7a, bun: true, cheeks: true, curvy: true, hat: 'none', scale: 1.05 } }, // the Widow Mae, the landlady
  saloon: { at: 2.9, pose: 'beckon', model: 'saloon_1', with: [{ model: 'prospectors_4', at: -1.7, out: 0.5, turn: 0.6 }], look: { coat: 0xc4302c, dress: 0xc4302c, dressPat: 0, sleeve: 0xf2dcc4, hair: 0xe8c070, long: true, glam: true, curvy: true, neckline: true, corset: 0x1e1612, short: true, stockings: 0x1e1a1c, garter: 0xe8c070, mole: true, lips: 0xc4302c, lids: 0x6a7aa8, flower: 0xc4302c, cheeks: true, hat: 'none' } }, // Miss Dolly Valentine
  livery: { model: 'folk_liveryman', with: [{ model: 'trades_4', at: -2.7, out: 0.6, turn: 0.35 }], look: { coat: 0x8a6a48, coatPat: 1, sleeve: 0x8a6a48, pants: 0x3f5f8a, beard: 0x8a6a48, burly: true, rolled: true, hat: 'straw', band: 0x6a4428, hold: 'shovel', scale: 1.1 } }, // the liveryman
  smithy: { pose: 'work', model: 'folk_amos', modelScale: 1.1, look: { coat: 0x5a4a3e, sleeve: 0x5a4a3e, apron: 0x3a2a20, pants: 0x3a3634, beard: 0x2b2018, hair: 0x2b2018, burly: true, rolled: true, hat: 'none', hold: 'axe', scale: 1.15 } }, // Big Amos the smith, at his work
  stable2: { model: 'folk_silas', hue: -1.3, look: { coat: 0x6a4a3a, pants: 0x3a3634, beard: 0x3a2a20, hat: 'cap', hatColor: 0x3a2e26 } }, // the stage-line driver, whip in hand
  cooper: { model: 'folk_ezra', hue: 1.9, pose: 'work', look: { coat: 0x7a6650, pants: 0x4a4038, apron: 0x6a4a30, beard: 0x8a7a68, hat: 'none' } }, // the cooper, at his work in a leather apron
  drygoods: { model: 'townsfolk_1', hue: -2.2, look: { coat: 0x6a8a6a, dress: 0x6a8a6a, hair: 0x8a5a3a, bun: true, cheeks: true, hat: 'none' } }, // the dry goods lady, Mrs. Abernathy's sister, in a re-dyed bustle dress
  telegraph: { model: 'trades_7', hue: 2.3, look: { coat: 0xefe3c4, sleeve: 0xefe3c4, vest: 0x3a4a5a, pants: 0x3a3634, hair: 0x6a4a30, collar: 0xffffff, hat: 'cap', hatColor: 0x2e3a4a } }, // the telegrapher in his green eyeshade and sleeve garters
  hotel2: { model: 'prospectors_4', hue: -0.35, look: { coat: 0x5a3a5a, longcoat: true, vest: 0xd8b860, pants: 0x2b2622, collar: 0xffffff, hair: 0x3a2a20, beard: 0x3a2a20, hat: 'none' } }, // the Grand Hotel's clerk in his plum frock coat and gold waistcoat
  feed: { model: 'prospectors_1', hue: 0.7, look: { coat: 0x8a6a48, coatPat: 1, sleeve: 0x8a6a48, pants: 0x3f5f8a, beard: 0x8a7a68, burly: true, rolled: true, hat: 'straw', band: 0x6a4428, scale: 1.05 } }, // the feed man in his straw hat, flour dust on his overalls
  barber: { model: 'townsfolk_3', hue: 2.8, look: { coat: 0xf6efe0, sleeve: 0xf6efe0, vest: 0x8a2a2a, pants: 0x3a3634, hair: 0x2b2018, beard: 0x2b2018, collar: 0xffffff, hat: 'none' } }, // the barber in shirtsleeves and a red waistcoat, comb in his pocket
  jail: { model: 'trades_1', hue: 1.6, look: { coat: 0x5a4a3e, vest: 0x2b2622, pants: 0x3a3634, beard: 0x6a4a30, hat: 'cap', hatColor: 0x3a2e26, hold: null } }, // the sheriff, thumbs in his belt by the jail door
  bank: { model: 'townsfolk_2', look: { coat: 0x6a8a6a, dress: 0x6a8a6a, hair: 0x3a2418, bun: true, cheeks: true, hat: 'none' } }, // Mrs. Vance, who keeps the bank's ledger, in her green walking dress
  bakery: { model: 'trades_6', look: { coat: 0xefe3c4, sleeve: 0xefe3c4, apron: 0xf6efe0, pants: 0x6a5a48, hair: 0x8a5a3a, cheeks: true, hat: 'none' } }, // the baker on Second Street, flour to the elbows
  church: { at: 2.2, pose: 'clipboard', model: 'trades_1', with: [{ model: 'trades_2', at: -3.3, out: 0.6, turn: -0.3 }], look: { coat: 0x2b2622, longcoat: true, pants: 0x2b2622, collar: 0xffffff, hair: 0xd8d0c0, hat: 'stovepipe', hatColor: 0x2b2622, band: 0x2b2622, hold: 'clipboard' } }, // the parson with his book
};

export class Town {
  /** Lay the town out once, down the lane from the homestead (before any chunk is built). */
  constructor(scene, world, home) {
    this._world = world;
    this.scene = scene;
    this.tiers = {}; // building id → 0 (run-down) or 1 (mended), saved with the game
    const rng = mulberry32(919);
    // the site: about 85 m off, dry and in the home county, the street running across the way from the farm
    let best = null;
    for (let k = 0; k < 36; k++) {
      const a = (k / 36) * Math.PI * 2, x = home.x + Math.cos(a) * 85, z = home.z + Math.sin(a) * 85;
      let ok = landAt(x, z).wild < 0.3 && regionAt(x, z) !== 'highland' && regionAt(x, z) !== 'peak';
      for (let j = 0; j < 16 && ok; j++) { const b = (j / 16) * Math.PI * 2; for (const r of [8, 16, 26]) if (isWater(x + Math.cos(b) * r, z + Math.sin(b) * r) || regionAt(x + Math.cos(b) * r, z + Math.sin(b) * r) === 'water') ok = false; }
      if (ok) { best = { x, z, a }; break; }
    }
    if (!best) { const a = 0.8; best = { x: home.x + Math.cos(a) * 85, z: home.z + Math.sin(a) * 85, a }; }
    this.at = new THREE.Vector3(best.x, 0, best.z);
    addFlatArea(best.x, best.z, 30, 42); // the town stands on its own level sheet
    world.exclusions.push({ x: best.x, z: best.z, r: 31 });
    // the new streets' lots, levelled and kept clear from the start, on whichever side of Main Street has room
    {
      const al = new THREE.Vector3(best.x - home.x, 0, best.z - home.z).normalize(), tw = new THREE.Vector3(-al.z, 0, al.x);
      const ok = (side) => [-20, -10, 0, 10, 20].every((sv) => [-10, 0, 10].every((cv) => { const x = best.x + al.x * sv + tw.x * (side * STREET_OFF + cv), z = best.z + al.z * sv + tw.z * (side * STREET_OFF + cv); return !isWater(x, z) && rangeAt(x, z) < 0.002; }));
      const sides = [1, -1].filter(ok);
      this.streetOffs = STREETS.map((_, i) => (sides[i] ?? (sides[0] ? -sides[0] : (i ? -1 : 1))) * STREET_OFF);
      for (const off of this.streetOffs) for (const sv of [-16, 0, 16]) {
        const x = best.x + al.x * sv + tw.x * off, z = best.z + al.z * sv + tw.z * off;
        addFlatArea(x, z, 16, 24); world.exclusions.push({ x, z, r: 17 });
      }
    }
    // the street runs straight out from the farm, so from home you look right down Main Street to the church;
    // "along" points up the street (away from the farm), "toward" across it (the buildings' side axis)
    const along = new THREE.Vector3(best.x - home.x, 0, best.z - home.z).normalize();
    const toward = new THREE.Vector3(-along.z, 0, along.x);
    this.along = along; this.toward = toward;
    const y0 = STEP * 1.5;
    this.group = new THREE.Group(); scene.add(this.group);
    this.y0 = y0;
    const place = (this.place = (obj, s, side, offset = 0, street = 0) => { // s along the street, side ±1, facing the street's centre line (`street`: its offset across from Main Street)
      const p = this.at.clone().addScaledVector(along, s).addScaledVector(toward, street + side * (HALF + offset));
      obj.position.set(p.x, y0, p.z);
      obj.rotation.y = Math.atan2(-side * toward.x, -side * toward.z);
      this.group.add(obj); return p;
    });
    this.doors = {}; this.parts = {};
    for (const b of BUILDINGS) {
      const g = building(b, 0, mulberry32(hashId(b.id))); const p = place(g, b.s, b.side); this.parts[b.id] = g;
      this.doors[b.id] = p.clone().addScaledVector(toward, -b.side * 1.6); // on the boardwalk before the door
      // colliders: a row of circles across the body
      const n = Math.ceil(b.w / 2.4);
      for (let i = 0; i < n; i++) {
        const t = (i + 0.5) / n - 0.5, c = this.at.clone().addScaledVector(along, b.s + t * b.w).addScaledVector(toward, b.side * (HALF + b.d / 2));
        world.colliders.push({ x: c.x, z: c.z, r: Math.min(b.d, 2.6) / 2 + 0.3 }, { x: c.x + toward.x * b.side * b.d * 0.3, z: c.z + toward.z * b.side * b.d * 0.3, r: Math.min(b.d, 2.6) / 2 + 0.3 });
      }
    }
    { // the assayer: out on his boardwalk beside the door in his green eyeshade and black vest, brass scales on a
      // little table at his elbow, and a placard on a post so nobody need ask who buys the gold
      const d = this.doors.assay, face = Math.atan2(toward.x, toward.z); // (the assay office stands on side -1: the street is +toward)
      const at = d.clone().addScaledVector(along, 1.6).addScaledVector(toward, -0.35);
      this.assayer = hasFolk('trades_7') ? new ModelFigure('trades_7') : new Figure({ coat: 0xf0e8d8, sleeve: 0xf0e8d8, vest: 0x2e2a28, pants: 0x4a4440, hair: 0xa8a098, beard: 0xa8a098, hat: 'cap', hatColor: 0x3e7a5a, hold: 'clipboard' });
      this.assayer.root.position.set(at.x, y0 + 0.14, at.z); this.assayer.root.rotation.y = face; this.group.add(this.assayer.root);
      const tbl = new THREE.Group(), brass = 0xd8a830, bench = propModel('mine_scales');
      if (bench) { // the assay bench from the reference art (the mining sheet): brass scales, weights and gold pokes on a plank bench
        const m = bench.scene.clone(), bb = new THREE.Box3().setFromObject(m), bs = bb.getSize(new THREE.Vector3()), bc = bb.getCenter(new THREE.Vector3());
        const k = 1.35 / bs.x, hold = new THREE.Group(); m.position.set(-bc.x, -bb.min.y, -bc.z); hold.add(m); hold.scale.setScalar(k); hold.rotation.y = Math.PI; tbl.add(hold); // (its front, glTF +Z, to the assayer)
      } else {
      const top = box(0.8, 0.06, 0.5, 0x8a6038); top.position.y = 0.78; tbl.add(top);
      for (const [lx, lz] of [[-0.34, -0.2], [0.34, -0.2], [0.34, 0.2], [-0.34, 0.2]]) { const l = box(0.06, 0.78, 0.06, 0x5a3e2a); l.position.set(lx, 0.39, lz); tbl.add(l); }
      const post = box(0.05, 0.5, 0.05, brass); post.position.y = 1.06; tbl.add(post);
      const beam = box(0.62, 0.035, 0.035, brass); beam.position.y = 1.3; beam.rotation.z = 0.06; tbl.add(beam); // tipped a hair toward the dust
      for (const sx of [-1, 1]) {
        const pan = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.08, 0.04, 12), paperMaterial({ color: brass })); pan.position.set(sx * 0.3, 1.0 + sx * 0.02, 0); pan.castShadow = true; tbl.add(pan);
        const str = box(0.01, 0.3, 0.01, 0x6a5a40); str.position.set(sx * 0.3, 1.15 + sx * 0.01, 0); tbl.add(str);
      }
      const dust = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.04, 8), paperMaterial({ color: 0xf0c840 })); dust.position.set(-0.3, 1.04, 0); tbl.add(dust); // a little heap of gold dust in the near pan
      }
      const tp = d.clone().addScaledVector(along, 1.6).addScaledVector(toward, 0.45);
      tbl.position.set(tp.x, y0 + 0.14, tp.z); tbl.rotation.y = face; this.group.add(tbl);
      // the placard on its post, at the street edge before the door
      const pp = d.clone().addScaledVector(along, -1.7).addScaledVector(toward, 1.0);
      const plac = card([[-0.62, 0], [0.64, 0.03], [0.6, 0.62], [-0.64, 0.6]], '#efe3c4', (gg, px) => {
        gg.textAlign = 'center'; gg.textBaseline = 'middle';
        gg.fillStyle = '#9a5a48'; gg.font = 'bold 40px Georgia, serif'; { const [x, y] = px(0, 0.42); gg.fillText('GOLD BOUGHT', x, y); }
        gg.fillStyle = '#2a201a'; gg.font = 'italic 30px Georgia, serif'; { const [x, y] = px(0, 0.18); gg.fillText('$4 the pinch · honest scales', x, y); }
      }, { W: 320, H: 160, seed: 823 });
      const pg = new THREE.Group(); plac.position.y = 1.15; plac.rotation.z = 0.04; pg.add(plac); pg.add(beams2([[0, 0]]));
      pg.position.set(pp.x, y0, pp.z); pg.rotation.y = face; this.group.add(pg);
    }
    // the church closes the far end of the street, facing back down it
    const ch = church(0), cp = this.at.clone().addScaledVector(along, 22); this.churchAt = cp;
    ch.position.set(cp.x, y0, cp.z); ch.rotation.y = Math.atan2(-along.x, -along.z); this.group.add(ch); this.parts.church = ch;
    for (const t of [-0.2, 0.2]) world.colliders.push({ x: cp.x + along.x * 4 + toward.x * t * 10, z: cp.z + along.z * 4 + toward.z * t * 10, r: 3 });
    this.doors.church = cp.clone().addScaledVector(along, -1.5);
    // tents pitched behind the buildings, where the poorer folk live
    this.tents = [];
    for (const [s, side] of [[-6, -1], [2, 1], [12, -1], [14, 1]]) {
      const t = tent(rng); const p = place(t, s, side, 9.5); t.rotation.y += (rng() - 0.5) * 0.5; this.tents.push(p);
      world.colliders.push({ x: p.x + toward.x * side * 2.6, z: p.z + toward.z * side * 2.6, r: 1.6 });
    }
    // Squatters' Row: a ragged lane of shanties and patched tents just outside town on the farm side, where the
    // down-and-out live, and where you find most of the folk who'll work for you
    const rowC = this.at.clone().addScaledVector(along, -43);
    addFlatArea(rowC.x, rowC.z, 11, 17); world.exclusions.push({ x: rowC.x, z: rowC.z, r: 13 });
    for (const side of [-1, 1]) { const q = rowC.clone().addScaledVector(toward, side * 12); addFlatArea(q.x, q.z, 10, 15); world.exclusions.push({ x: q.x, z: q.z, r: 11 }); } // (room for the row to grow)
    this.rowRng = mulberry32(4242); this.civilians = [];
    this.squat = [];
    let k = 0;
    for (const s of [-34, -38.5, -43, -47.5, -52]) for (const side of [-1, 1]) {
      const p0 = this.at.clone().addScaledVector(along, s).addScaledVector(toward, side * 5.4);
      if (isWater(p0.x, p0.z)) continue;
      const hut = tent(rng); k++; // (all canvas tents now: the plank shanties read as junk)
      const p = place(hut, s, side, -0.8); hut.rotation.y += (rng() - 0.5) * 0.35;
      this.squat.push(p.clone().addScaledVector(toward, -side * 1.5)); // a spot out front, by the cookfire
      world.colliders.push({ x: p.x + toward.x * side * 1.2, z: p.z + toward.z * side * 1.2, r: 1.5 });
    }
    { // the hand-painted sign at the head of the row
      const sp = this.at.clone().addScaledVector(along, -31).addScaledVector(toward, -3.6);
      const sign = card([[-1.0, 0], [1.05, 0.05], [1.0, 0.5], [-1.05, 0.48]], '#9a8a6a', (gg, px) => { gg.fillStyle = '#2a201a'; gg.font = 'italic bold 26px Georgia, serif'; gg.textAlign = 'center'; gg.textBaseline = 'middle'; const [x, y] = px(0, 0.25); gg.fillText("Squatters' Row", x, y); }, { W: 256, H: 72, seed: 811 });
      const sg = new THREE.Group(); sign.position.y = 1.1; sign.rotation.z = -0.06; sg.add(sign); sg.add(beams2([[0, 0]]));
      sg.position.set(sp.x, y0, sp.z); sg.rotation.y = Math.atan2(-along.x, -along.z); this.group.add(sg);
    }
    // the dirt street: a long torn sheet of ochre with wheel ruts, and the town sign by the lane
    const street = card([[-4.6, -27], [4.6, -27], [5.2, -10], [4.4, 8], [5.0, 27], [-4.8, 27], [-4.2, 10], [-5.0, -9]], '#b89a6a', (gg, px) => {
      gg.strokeStyle = 'rgba(110,80,50,0.45)'; gg.lineWidth = 5; for (const x of [-1.2, 1.2]) { gg.beginPath(); for (let y = -27; y <= 27; y += 3) { const [a, b] = px(x + Math.sin(y * 0.3) * 0.15, y); y === -27 ? gg.moveTo(a, b) : gg.lineTo(a, b); } gg.stroke(); }
      for (let i = 0; i < 40; i++) { const [a, b] = px(-4 + Math.random() * 8, -26 + Math.random() * 52); gg.fillStyle = 'rgba(140,110,70,0.4)'; gg.beginPath(); gg.arc(a, b, 3 + Math.random() * 5, 0, Math.PI * 2); gg.fill(); }
    }, { W: 256, H: 1024, seed: 751, thick: 0.03, snow: 0.45 }); // (the snow lies thin on a street the wagons keep churning: the ruts show through)
    street.castShadow = false; street.rotation.set(-Math.PI / 2, 0, 0); // laid flat: its long axis runs along -z, so the holder turns it to the street
    const holder = new THREE.Group(); holder.add(street);
    holder.position.set(this.at.x, y0 + 0.03, this.at.z); holder.rotation.y = Math.atan2(along.x, along.z); this.group.add(holder);
    this.signAt = this.at.clone().addScaledVector(along, -27).addScaledVector(toward, 4.5);
    this.makeSign();
    this.dressStreet();
  }

  /** The town sign by the lane, facing the farm; its population rises as the town is mended. */
  makeSign() {
    if (this.sign) this.group.remove(this.sign);
    const mended = Object.values(this.tiers).filter(Boolean).length, pop = 11 + mended * 4;
    const line = mended === 0 ? 'Pop. 11 (and falling)' : mended >= 7 ? `Pop. ${pop} · Welcome, stranger!` : `Pop. ${pop} (and rising)`;
    const sign = card([[-1.6, 0], [1.6, 0], [1.7, 0.9], [-1.7, 0.95]], mended ? '#e8dcc0' : '#c9b896', (gg, px) => {
      gg.fillStyle = '#3a2a1c'; gg.textAlign = 'center'; gg.textBaseline = 'middle';
      const [x, y] = px(0, 0.62); gg.font = 'bold 30px Georgia, serif'; gg.fillText('PAYDIRT HOLLOW', x, y);
      const [x2, y2] = px(0, 0.25); gg.font = 'italic 22px Georgia, serif'; gg.fillText(line, x2, y2);
    }, { W: 384, H: 112, seed: 757 + mended });
    const sg = new THREE.Group(); sign.position.y = 1.2; sg.add(sign); sg.add(beams2([[-1.3, 0], [1.3, 0]]));
    const a = this.signAt; sg.position.set(a.x, getHeight(a.x, a.z), a.z); sg.rotation.y = Math.atan2(-this.along.x, -this.along.z); sg.rotation.z = mended ? 0 : 0.04; // facing the lane from the farm
    this.group.add(sg); this.sign = sg;
  }

  /** The height to stand at (x, z) by building id: its boardwalk or step if there's one underfoot, else the street. */
  surfaceAt(x, z, id) {
    const g = this.parts[id]; if (!g) return this.y0;
    g.updateMatrixWorld(true); (this._ray ||= new THREE.Raycaster()).set(new THREE.Vector3(x, this.y0 + 3, z), new THREE.Vector3(0, -1, 0));
    const hit = this._ray.intersectObject(g, true).find((h) => h.point.y < this.y0 + 0.8 && h.face && Math.abs(h.face.normal.clone().transformDirection(h.object.matrixWorld).y) > 0.7); // (a floor or a step, not a rail's top)
    return hit ? Math.max(this.y0, hit.point.y) : this.y0;
  }
  /** Pop a greeting card up over a keeper's head (one at a time: a new one replaces the last). */
  sayHello(root) {
    if (!this.hello) {
      const words = ['Mornin’!', 'Howdy!', 'Fine day!', 'Evenin’!', 'Well, hello!'];
      this.helloMats = words.map((w) => {
        const c = document.createElement('canvas'); c.width = 256; c.height = 112; const g = c.getContext('2d');
        g.fillStyle = '#f3ead6'; g.strokeStyle = '#5a4030'; g.lineWidth = 6; g.beginPath(); g.moveTo(16, 10); g.lineTo(240, 8); g.lineTo(246, 78); g.lineTo(120, 80); g.lineTo(96, 104); g.lineTo(98, 80); g.lineTo(12, 82); g.closePath(); g.fill(); g.stroke();
        g.fillStyle = '#3a2a1c'; g.font = 'bold 40px Georgia, serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(w, 128, 46);
        const tx = new THREE.CanvasTexture(c); tx.colorSpace = THREE.SRGBColorSpace;
        return new THREE.MeshBasicNodeMaterial({ map: tx, transparent: true, alphaTest: 0.5, side: THREE.DoubleSide, depthTest: false }); // (drawn over a porch roof, as a speech card should be)
      });
      this.hello = new THREE.Mesh(new THREE.PlaneGeometry(0.95, 0.42).translate(0, 0.21, 0), this.helloMats[0]); this.hello.rotation.order = 'YXZ'; this.hello.renderOrder = 10; this.hello.visible = false; this.group.add(this.hello); // (hinged at its foot)
    }
    const evening = (this.clock ?? 0.5) > 0.66, i = evening ? 3 : [0, 1, 2, 4][Math.floor(Math.random() * 4)];
    this.hello.material = this.helloMats[(this.clock ?? 0.5) < 0.42 && Math.random() < 0.6 ? 0 : i];
    this.helloT = 2.6; this.helloAt = root;
  }
  helloTick(dt) {
    if (!this.hello) return;
    this.helloT = (this.helloT || 0) - dt; const on = this.helloT > 0 && !this.far; this.hello.visible = on; if (!on) return;
    const r = this.helloAt.position, k = Math.min(1, (2.6 - this.helloT) / 0.18), out = Math.min(1, this.helloT / 0.25);
    const up = Math.min(k, out), over = k < 1 ? 0 : Math.sin(Math.min(1, (2.6 - this.helloT - 0.18) / 0.5) * Math.PI * 2) * 0.12 * (1 - Math.min(1, (2.6 - this.helloT - 0.18) / 0.5));
    this.hello.position.set(r.x, r.y + 2.05, r.z); this.hello.rotation.x = -(1 - up) * Math.PI / 2 + over; // (it springs up on its hinge with a little quiver, and folds away flat)
    if (this.camPos) this.hello.rotation.y = Math.atan2(this.camPos.x - r.x, this.camPos.z - r.z);
  }
  /** The town's mending projects, one per building: { id, name, cost, door }. */
  projects() {
    const c = (id, cost) => (this.raided?.[id] ? Math.ceil(cost / 2) : cost); // (a building the raiders wrecked mends at half the cost: the frame's still sound)
    const main = [...BUILDINGS.map((b) => ({ id: b.id, name: b.name, cost: c(b.id, b.cost), door: this.doors[b.id] })), { id: 'church', name: 'church', cost: 40, door: this.doors.church }];
    return main.concat(...(this.opened || []).map((k) => STREETS[k].buildings.map((b) => ({ id: b.id, name: b.name, cost: c(b.id, b.cost), door: this.doors[b.id] }))));
  }
  /** Is every building on Main Street (k = -1) or on the k-th new street mended? */
  streetDone(k) { return (k < 0 ? [...BUILDINGS.map((b) => b.id), 'church'] : STREETS[k].buildings.map((b) => b.id)).every((id) => this.tiers[id]); }
  /** Put up the k-th new street: its dirt street, and its buildings run-down and wanting mending. */
  openStreet(k) {
    this.opened ||= [];
    if (this.opened.includes(k)) return;
    this.opened.push(k);
    const st = STREETS[k], off = this.streetOffs[k], along = this.along, toward = this.toward, y0 = this.y0;
    for (const b of st.buildings) {
      const g = building(b, 0, mulberry32(hashId(b.id))); const p = this.place(g, b.s, b.side, 0, off); this.parts[b.id] = g;
      this.doors[b.id] = p.clone().addScaledVector(toward, -b.side * 1.6);
      const n = Math.ceil(b.w / 2.4);
      for (let i = 0; i < n; i++) {
        const t = (i + 0.5) / n - 0.5, c = this.at.clone().addScaledVector(along, b.s + t * b.w).addScaledVector(toward, off + b.side * (HALF + b.d / 2));
        this._world.colliders.push({ x: c.x, z: c.z, r: Math.min(b.d, 2.6) / 2 + 0.3 });
      }
    }
    const sheet = this.streetSheet(); sheet.position.copy(this.at).addScaledVector(toward, off); sheet.position.y = y0 + 0.03; this.group.add(sheet);
    // its name on a post at the corner
    const sp = this.at.clone().addScaledVector(along, -18).addScaledVector(toward, off - Math.sign(off) * 5.2);
    const sign = card([[-1.1, 0], [1.1, 0.03], [1.05, 0.42], [-1.1, 0.4]], '#e8dcc0', (gg, px) => { gg.fillStyle = '#3a2a1c'; gg.font = 'bold 26px Georgia, serif'; gg.textAlign = 'center'; gg.textBaseline = 'middle'; const [x, y] = px(0, 0.21); gg.fillText(st.name.toUpperCase(), x, y); }, { W: 256, H: 64, seed: 900 + k });
    const sg = new THREE.Group(); sign.position.y = 1.6; sg.add(sign); sg.add(beams2([[0, 0]]));
    sg.position.set(sp.x, y0, sp.z); sg.rotation.y = Math.atan2(-along.x, -along.z); this.group.add(sg);
    this.growRow(k);
    this.onStreet?.(st.name);
  }
  /** Four more tents behind the first rank on Squatters' Row, each with a family in it who wants something. */
  growRow(k) {
    const spots = [[-37, -1], [-37, 1], [-44, -1], [-44, 1], [-51, -1], [-51, 1], [-40.5, -1], [-47.5, 1]].slice(k * 4, k * 4 + 4);
    for (const [s, side] of spots) {
      const p0 = this.at.clone().addScaledVector(this.along, s).addScaledVector(this.toward, side * 12);
      if (isWater(p0.x, p0.z)) continue;
      // (the back rank turns its back on the front one and opens onto the field, so its folk stand out in the open)
      const hut = tent(this.rowRng), p = this.place(hut, s, side, 12 - HALF); hut.rotation.y += Math.PI + (this.rowRng() - 0.5) * 0.35;
      this._world.colliders.push({ x: p.x - this.toward.x * side * 1.2, z: p.z - this.toward.z * side * 1.2, r: 1.5 });
      const i = this.civilians.length, [model, name] = ROW_FOLK[i % ROW_FOLK.length];
      const at = p.clone().addScaledVector(this.toward, side * 1.8);
      const fig = hasFolk(model) ? new ModelFigure(model) : new Figure({ coat: 0x7a6a50, sleeve: 0x7a6a50, pants: 0x4a4038, hat: 'straw', hold: null });
      fig.root.position.set(at.x, this.y0 + 0.02, at.z); fig.root.rotation.y = Math.atan2(side * this.toward.x, side * this.toward.z); this.group.add(fig.root);
      // a little paper card over their head while they want something: a cream note with a red "!"
      const twoFaced = (m, make) => { const back = make(); back.rotation.y = Math.PI; back.position.z = -0.03; m.add(back); return m; }; // (a spinning note shows its print from both sides)
      const noteCard = () => card([[-0.22, 0], [0.22, 0.02], [0.2, 0.42], [-0.21, 0.4]], '#f2e8d0', (gg, px) => { gg.fillStyle = '#b5473a'; gg.font = 'bold 120px Georgia, serif'; gg.textAlign = 'center'; gg.textBaseline = 'middle'; const [x, y] = px(0, 0.2); gg.fillText('!', x, y); }, { W: 128, H: 128, seed: 600 + i, thick: 0.02 });
      const note = twoFaced(noteCard(), noteCard);
      note.position.set(at.x, this.y0 + 2.35, at.z); this.group.add(note);
      // and when you've what they want in your pack, the note turns: a pale sage card with a green tick, come and see me
      const readyCard = () => card([[-0.22, 0], [0.22, 0.02], [0.2, 0.42], [-0.21, 0.4]], '#d4e2b4', (gg, px) => { gg.strokeStyle = '#3e6a2e'; gg.lineWidth = 16; gg.lineCap = 'round'; gg.lineJoin = 'round'; gg.beginPath(); const [a, b] = px(-0.11, 0.2), [c, d] = px(-0.03, 0.1), [e, f] = px(0.12, 0.31); gg.moveTo(a, b); gg.lineTo(c, d); gg.lineTo(e, f); gg.stroke(); }, { W: 128, H: 128, seed: 640 + i, thick: 0.02 });
      const ready = twoFaced(readyCard(), readyCard);
      ready.visible = false; this.group.add(ready);
      this.civilians.push({ name, fig, at, door: p.clone().addScaledVector(this.toward, side * 0.9), note, ready, want: WANTS[(i * 3 + 1) % WANTS.length], day: -1 });
    }
  }
  /**
   * The sheriff's WANTED poster, tacked to a board on a post by the jail door: the guardian he's put a price on and
   * the reward, printed on yellowed paper with a torn edge (null takes it down).
   */
  /** The opera house's playbill, on a post by its door: tonight's tall tale (day picks it). */
  setPlaybill(day) {
    if (!this.doors.opera || !this.tiers.opera) { if (this.bill) { this.group.remove(this.bill); this.bill = null; } return; }
    if (this.bill && this.billDay === day) return;
    if (this.bill) this.group.remove(this.bill);
    this.billDay = day;
    const [title, sub] = PLAYBILL[day % PLAYBILL.length];
    const st = STREETS.find((q) => q.buildings.some((x) => x.id === 'opera')), ob = st.buildings.find((x) => x.id === 'opera'), off = this.streetOffs[STREETS.indexOf(st)];
    const p = this.at.clone().addScaledVector(this.along, ob.s - 3.2).addScaledVector(this.toward, off + ob.side * (HALF - 1.2));
    const sheet = card([[-0.42, 0], [0.42, 0.02], [0.4, 0.86], [-0.43, 0.84]], '#f0dcb0', (gg, px) => {
      gg.textAlign = 'center'; gg.textBaseline = 'middle';
      gg.fillStyle = '#8a2a1e'; let [x, y] = px(0, 0.76); gg.font = 'bold 22px Georgia, serif'; gg.fillText('TONIGHT', x, y);
      gg.fillStyle = '#2a201a'; [x, y] = px(0, 0.58); gg.font = 'bold 30px Georgia, serif'; gg.fillText(title, x, y);
      [x, y] = px(0, 0.44); gg.font = 'italic 20px Georgia, serif'; gg.fillText(sub, x, y);
      [x, y] = px(0, 0.26); gg.font = '18px Georgia, serif'; gg.fillText('Curtain at sundown', x, y);
      gg.fillStyle = '#8a2a1e'; [x, y] = px(0, 0.1); gg.font = 'bold 24px Georgia, serif'; gg.fillText('ADMISSION $3', x, y);
    }, { W: 256, H: 256, seed: 990 + (day % 7), thick: 0.02 });
    const g = new THREE.Group(); sheet.position.set(0, 1.0, -0.15); sheet.rotation.z = -0.03; g.add(sheet); g.add(beams2([[0, 0]])); // (the sheet tacked to the face of its post, not behind it)
    g.position.set(p.x, this.y0, p.z); g.rotation.y = Math.atan2(ob.side * this.toward.x, ob.side * this.toward.z) + Math.PI; this.group.add(g); this.bill = g;
  }
  setPoster(b) {
    if (this.poster) { this.group.remove(this.poster); this.poster = null; }
    if (!b || !this.doors.jail) return;
    const st = STREETS.find((q) => q.buildings.some((x) => x.id === 'jail')), jb = st.buildings.find((x) => x.id === 'jail'), off = this.streetOffs[STREETS.indexOf(st)];
    const p = this.at.clone().addScaledVector(this.along, jb.s + 2.6).addScaledVector(this.toward, off + jb.side * (HALF - 1.2));
    const sheet = card([[-0.42, 0], [0.4, 0.03], [0.43, 0.62], [0.02, 0.6], [-0.41, 0.63]], '#e8d8a8', (gg, px) => {
      gg.fillStyle = '#2a201a'; gg.textAlign = 'center'; gg.textBaseline = 'middle';
      let [x, y] = px(0, 0.53); gg.font = 'bold 40px Georgia, serif'; gg.fillText('WANTED', x, y);
      [x, y] = px(0, 0.36); gg.font = 'italic 21px Georgia, serif'; gg.fillText(b.name, x, y);
      [x, y] = px(0, 0.2); gg.font = 'bold 22px Georgia, serif'; gg.fillText('DEAD OR DRIVEN OFF', x, y);
      [x, y] = px(0, 0.08); gg.fillStyle = '#8a2a1e'; gg.font = 'bold 30px Georgia, serif'; gg.fillText(`$${b.pay} REWARD`, x, y);
    }, { W: 256, H: 192, seed: 977, thick: 0.02 });
    const g = new THREE.Group(); sheet.position.set(0, 1.15, -0.15); sheet.rotation.z = 0.03; g.add(sheet); g.add(beams2([[0, 0]])); // (the sheet tacked to the face of its post, not behind it)
    g.position.set(p.x, this.y0, p.z); g.rotation.y = Math.atan2(jb.side * this.toward.x, jb.side * this.toward.z) + Math.PI; this.group.add(g); this.poster = g;
  }
  /**
   * The dance hall's evening: once it's mended, from dusk till late, two couples (civilian models in their own re-dyed
   * Sunday best) swing round in the street before its doors, each pair turning as it goes. Hidden by day.
   */
  danceHall(evening, dt) {
    if (this.far) return; // (hidden with the rest of the town's folk)
    if (!this.tiers.dance || !this.doors.dance) { if (this.hallDancers) for (const d of this.hallDancers) d.fig.root.visible = false; return; }
    if (!this.hallDancers) {
      const pairs = [['folk_farmhand_02', -1.0, 'folk_calico_02', 1.3], ['folk_farmhand_03', 2.4, 'folk_calico_03', -2.0]];
      this.hallDancers = [];
      pairs.forEach(([m, hm, w, hw], i) => {
        for (const [name, hue, sgn] of [[m, hm, -1], [w, hw, 1]]) {
          if (!hasFolk(name)) continue;
          const fig = new ModelFigure(name, { hue }); this.group.add(fig.root); fig.root.visible = false;
          this.hallDancers.push({ fig, pair: i, sgn });
        }
      });
      const st = STREETS.find((q) => q.buildings.some((x) => x.id === 'dance')), b = st.buildings.find((x) => x.id === 'dance');
      this.hallFloor = this.doors.dance.clone().addScaledVector(this.toward, -b.side * 3.4); // (out in the street before the doors)
    }
    this.hallT = (this.hallT || 0) + dt;
    // the fiddler on the dance hall's boardwalk, sawing away, and the tune heard down the street (a fourth above
    // the barn dance's reel, and a shade quicker)
    if (!this.hallFiddler && hasFolk('folk_fiddler')) {
      const st = STREETS.find((q) => q.buildings.some((x) => x.id === 'dance')), b = st.buildings.find((x) => x.id === 'dance');
      const f = new ModelFigure('folk_fiddler', { hue: 0.9 }), p = this.doors.dance.clone().addScaledVector(this.along, -2.2);
      f.root.position.set(p.x, this.y0 + 0.14, p.z); f.root.rotation.y = Math.atan2(-b.side * this.toward.x, -b.side * this.toward.z); this.group.add(f.root); this.hallFiddler = f;
    }
    if (this.hallFiddler) { this.hallFiddler.root.visible = evening; if (evening) this.hallFiddler.update(dt, 0, null); }
    const cp = this.camPos, hd = cp ? Math.hypot(cp.x - this.hallFloor.x, cp.z - this.hallFloor.z) : 99;
    if (evening && hd < 30 && (this.hallBeat = (this.hallBeat ?? 0) - dt) <= 0) {
      this.hallBeat += 0.15; this.hallNote = (this.hallNote || 0) + 1;
      this.onNote?.(hz(REEL[this.hallNote % REEL.length] + 5), 0.18, Math.max(0, 1 - hd / 30) * 0.8);
    }
    for (const d of this.hallDancers) {
      d.fig.root.visible = evening;
      if (!evening) continue;
      const a = this.hallT * 0.5 + d.pair * Math.PI, c = this.hallFloor, spin = this.hallT * 2.0 + d.pair;
      const px = c.x + Math.cos(a) * 2.2 * (d.pair ? 1 : 0.8), pz = c.z + Math.sin(a) * 1.6;
      d.fig.root.position.set(px + Math.cos(spin) * 0.32 * d.sgn, this.y0 + 0.03, pz + Math.sin(spin) * 0.32 * d.sgn);
      d.fig.root.rotation.y = -spin + (d.sgn > 0 ? Math.PI / 2 : -Math.PI / 2);
      d.fig.update(dt, 0, 'dance');
    }
  }
  /**
   * Curtain time at the opera house: once it's mended, from sundown till the show's done, a few theatre-goers in
   * their best (civilian models, re-dyed) wait in a line along the boardwalk by its doors, chatting, a pace apart.
   */
  operaQueue(curtain, dt) {
    if (this.far) return;
    if (!this.tiers.opera || !this.doors.opera) { if (this.queue) for (const q of this.queue) q.root.visible = false; return; }
    if (!this.queue) {
      const st = STREETS.find((x) => x.buildings.some((b) => b.id === 'opera')), ob = st.buildings.find((b) => b.id === 'opera');
      this.queue = [['townsfolk_2', 1.1], ['folk_farmhand_01', -1.8], ['prospectors_2', 2.4], ['folk_calico_01', -0.7]].filter(([m]) => hasFolk(m)).map(([m, hue], i) => {
        const f = new ModelFigure(m, { hue }), p = this.doors.opera.clone().addScaledVector(this.along, 1.4 + i * 0.95).addScaledVector(this.toward, -ob.side * 0.4);
        f.root.position.set(p.x, this.surfaceAt(p.x, p.z, 'opera'), p.z); f.root.rotation.y = Math.atan2(-this.along.x, -this.along.z) + (i % 2 ? 0.5 : -0.3); // (facing up the line toward the doors, turned a little to talk)
        f.root.visible = false; this.group.add(f.root); return f;
      });
    }
    for (const f of this.queue) { f.root.visible = curtain; if (curtain) f.update(dt, 0, null); }
  }
  /** A tent-dweller close enough to talk to (within reach of E), wanting something. */
  wantAt(pos, r = 2.2) { return (this.civilians || []).find((c) => { const q = c.fig.root.position; return c.want && c.fig.root.visible && Math.hypot(pos.x - q.x, pos.z - q.z) < r; }) || null; }
  /** Hand over what they want, if you have it: they pay, and want something else tomorrow. */
  fill(c, inventory, day, bonus = 0) {
    const [item, n, pay0, say] = c.want, pay = pay0 + bonus; // (a well-groomed neighbour gets a dollar more: folk are kinder to a clean shave)
    if ((inventory[item] || 0) < n) return { ok: false, text: `${c.name} could use ${say} (${n} ${item}). They'll pay $${pay}.` };
    inventory[item] -= n; inventory.dollars = (inventory.dollars || 0) + pay;
    c.want = null; c.day = day + 1; c.note.visible = false;
    return { ok: true, text: `${c.name} takes the ${item} gratefully and presses $${pay} into your hand. "God bless you, neighbor."` };
  }
  /** A dirt street's torn ochre sheet with wheel ruts, laid along the town's axis. */
  streetSheet() {
    const street = card([[-4.6, -27], [4.6, -27], [5.2, -10], [4.4, 8], [5.0, 27], [-4.8, 27], [-4.2, 10], [-5.0, -9]], '#b89a6a', (gg, px) => {
      gg.strokeStyle = 'rgba(110,80,50,0.45)'; gg.lineWidth = 5; for (const x of [-1.2, 1.2]) { gg.beginPath(); for (let y = -27; y <= 27; y += 3) { const [a, b] = px(x + Math.sin(y * 0.3) * 0.15, y); y === -27 ? gg.moveTo(a, b) : gg.lineTo(a, b); } gg.stroke(); }
    }, { W: 256, H: 1024, seed: 761, thick: 0.03, snow: 0.45 }); // (snow lies thin on a street the wagons keep churning: the ruts show through)
    street.castShadow = false; street.rotation.set(-Math.PI / 2, 0, 0);
    const holder = new THREE.Group(); holder.add(street); holder.rotation.y = Math.atan2(this.along.x, this.along.z); return holder;
  }
  /** The unmended project whose door you're standing at, if any. */
  projectAt(pos, r = 2.3) { return this.projects().find((p) => !this.tiers[p.id] && Math.hypot(pos.x - p.door.x, pos.z - p.door.z) < r) || null; }
  /** Rebuild one building mended: fresh paint, its sign whole, glass in the windows, the roof straight. */
  /**
   * The folk who come back with a mended building, out on its boardwalk by the door, and a barrel of flowers there.
   * The saloon gets Miss Dolly Valentine, the Golden Garter's hostess, beckoning in passers-by.
   */
  dressUp(id) {
    if (this.folk?.[id] || !TOWNSFOLK[id]) return;
    this.folk ||= {};
    const T = TOWNSFOLK[id], church = id === 'church';
    const b = BUILDINGS.find((q) => q.id === id) || STREETS.flatMap((st) => st.buildings).find((q) => q.id === id), side = b?.side ?? 1, door = this.doors[id];
    const out = church ? this.along.clone().negate() : this.toward.clone().multiplyScalar(-side); // the way to the street
    const face = Math.atan2(out.x, out.z), y = this.y0 + 0.14;
    const p = door.clone().addScaledVector(church ? this.toward : this.along, T.at ?? 1.5).addScaledVector(out, -0.3);
    const f = T.model && hasFolk(T.model) ? new ModelFigure(T.model, { scale: T.modelScale, hue: T.hue }) : new Figure(T.look); /* (the model from the reference art, when it's been made) */ f.root.position.set(p.x, church ? this.y0 : y, p.z); f.root.rotation.y = face; this.group.add(f.root);
    // a barrel of red and yellow flowers on the other side of the door
    const q = door.clone().addScaledVector(church ? this.toward : this.along, -(T.at ?? 1.5)).addScaledVector(out, -0.2);
    const bar = new THREE.Group(); bar.position.set(q.x, church ? this.y0 : y, q.z);
    const keg = new THREE.Mesh(new THREE.CylinderGeometry(0.28, 0.24, 0.5, 10), BARREL_MATS.keg); keg.position.y = 0.25; keg.castShadow = true; bar.add(keg);
    for (let k = 0; k < 7; k++) { const fl = new THREE.Mesh(new THREE.IcosahedronGeometry(0.08, 0), BARREL_MATS.fl[k % 3]); const a = k * 0.9; fl.position.set(Math.cos(a) * 0.16 * (k % 2 + 0.5), 0.55 + (k % 3) * 0.05, Math.sin(a) * 0.16 * (k % 2 + 0.5)); bar.add(fl); }
    const leaf = new THREE.Mesh(new THREE.SphereGeometry(0.25, 7, 4), BARREL_MATS.leaf); leaf.position.y = 0.5; leaf.scale.y = 0.45; bar.add(leaf); bakeByMaterial(bar); // (shared materials, baked: 9 meshes down to 5 a barrel)
    this.group.add(bar);
    this.folk[id] = { fig: f, pose: T.pose || null, bar };
    // company: anyone else who hangs about this door (the gambler by the Golden Garter)
    (T.with || []).forEach((E, k) => {
      if (!E.model || !hasFolk(E.model)) return;
      const e = new ModelFigure(E.model), pe = door.clone().addScaledVector(church ? this.toward : this.along, E.at ?? -1.6).addScaledVector(out, E.out ?? 0.3); /* (along the front, as the keeper stands) */
      e.root.position.set(pe.x, church ? this.y0 : this.surfaceAt(pe.x, pe.z, id), pe.z); /* (on the boardwalk if they stand on it, else down in the street) */ e.root.rotation.y = face + (E.turn ?? 0); this.group.add(e.root);
      this.folk[id + '_' + k] = { fig: e, pose: E.pose || null };
    });
  }
  mend(id) {
    const k = STREETS.findIndex((st) => st.buildings.some((b) => b.id === id));
    if (k >= 0 && !this.opened?.includes(k)) this.openStreet(k); // (a saved game: put the street up first)
    this.tiers[id] = 1; if (this.raided) delete this.raided[id]; this.dressUp(id);
    this.rebuild(id, 1, k);
    // the town grows: Main Street all mended puts up Second Street; that all mended puts up Third Street
    for (let n = 0; n < STREETS.length; n++) if (!this.opened?.includes(n) && this.streetDone(n - 1)) { this.openStreet(n); break; }
  }
  /** Raiders wrecked it: it stands run-down again, its folk gone, until it's mended once more. */
  unmend(id) {
    if (!this.tiers[id] || id === 'church') return false;
    this.tiers[id] = 0; (this.raided ||= {})[id] = true;
    for (const key of Object.keys(this.folk || {})) if (key === id || key.startsWith(id + '_')) { const F = this.folk[key]; this.group.remove(F.fig.root); if (F.bar) this.group.remove(F.bar); delete this.folk[key]; }
    this.rebuild(id, 0, STREETS.findIndex((st) => st.buildings.some((b) => b.id === id)));
    return true;
  }
  /** The mended buildings a war party could fall on (never the church). */
  raidable() { return this.projects().filter((p) => p.id !== 'church' && this.tiers[p.id]); }
  rebuild(id, tier, k) {
    const old = this.parts[id]; this.group.remove(old);
    let g;
    if (id === 'saloon') this.revue = null; // (the dancers come back with the new building)
    if (id === 'church') { g = church(tier); g.position.copy(old.position); g.rotation.copy(old.rotation); this.group.add(g); }
    else if (k >= 0) { const b = STREETS[k].buildings.find((q) => q.id === id); g = building(b, tier, mulberry32(hashId(b.id))); this.place(g, b.s, b.side, 0, this.streetOffs[k]); }
    else { const b = BUILDINGS.find((q) => q.id === id); g = building(b, tier, mulberry32(hashId(b.id))); this.place(g, b.s, b.side); }
    this.parts[id] = g; this.lit = null; // (re-light on the next update)
    if (id !== 'church') {
      // keeper, company and flower barrel seated on the mended building's boardwalk, or the street; one left down in the
      // street with the boardwalk just behind them steps back up onto it (a model's porch may stop short of the old spot)
      const bb = BUILDINGS.find((q) => q.id === id) || STREETS.flatMap((st) => st.buildings).find((q) => q.id === id), back = this.toward.clone().multiplyScalar(bb?.side ?? 1);
      const seat = (o, step) => {
        const p = o.position; let y = this.surfaceAt(p.x, p.z, id);
        if (step && y < this.y0 + 0.05) for (let d = 0.2; d <= 1.2; d += 0.2) { const yy = this.surfaceAt(p.x + back.x * d, p.z + back.z * d, id); if (yy > this.y0 + 0.05) { p.x += back.x * (d + 0.25); p.z += back.z * (d + 0.25); y = this.surfaceAt(p.x, p.z, id); break; } }
        p.y = y;
      };
      for (const key of Object.keys(this.folk || {})) if (key === id || key.startsWith(id + '_')) { const F = this.folk[key]; seat(F.fig.root, key === id); if (F.bar) seat(F.bar, true); }
    } // (keeper, company and flower barrel re-seated on the mended building's boardwalk, or the street)
    // a lantern on a post by the door of a mended building on the new streets, lit after dark
    if (this.lamps?.[id]) { this.group.remove(this.lamps[id]); delete this.lamps[id]; }
    if (k >= 0 && tier) {
      const b = STREETS[k].buildings.find((q) => q.id === id), d = this.doors[id], lamp = new THREE.Group();
      const p = d.clone().addScaledVector(this.along, (b.w / 2) * 0.55).addScaledVector(this.toward, -b.side * 0.9);
      const post = box(0.09, 2.1, 0.09, 0x4a3424); post.position.y = 1.05; lamp.add(post);
      const arm = box(0.42, 0.06, 0.06, 0x3a2a1c); arm.position.set(0.18, 2.0, 0); lamp.add(arm);
      const cage = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.28, 0.2), LAMP_GLASS); cage.position.set(0.36, 1.78, 0); lamp.add(cage);
      const cap = box(0.26, 0.06, 0.26, 0x2e2a28); cap.position.set(0.36, 1.95, 0); lamp.add(cap);
      lamp.position.set(p.x, this.y0, p.z); lamp.rotation.y = Math.atan2(this.along.x, this.along.z) - Math.PI / 2; this.group.add(lamp);
      (this.lamps ||= {})[id] = lamp;
    }
    // a hitching rail before the feed barn and the stage stables once they're mended, a horse tied at each, swishing
    // its tail and shifting its weight
    if (this.hitch?.[id]) { this.group.remove(this.hitch[id].g, this.hitch[id].horse.group); delete this.hitch[id]; }
    if (tier && ((k >= 0 && (id === 'feed' || id === 'stable2')) || (k < 0 && id === 'saloon'))) { // (and a late customer's horse at the Golden Garter's rail)
      const b = k >= 0 ? STREETS[k].buildings.find((q) => q.id === id) : BUILDINGS.find((q) => q.id === id), g = new THREE.Group();
      const p = this.doors[id].clone().addScaledVector(this.along, (id === 'saloon' ? 1.05 : -0.6) * (b.w / 2)).addScaledVector(this.toward, -b.side * (id === 'saloon' ? 1.2 : 2.2)); // (the saloon's at the far end of its front, clear of the dancers, and close in to the boardwalk, clear of the stage)
      for (const dx of [-1.3, 1.3]) { const post = box(0.12, 1.1, 0.12, 0x5a3e28); post.position.set(dx, 0.55, 0); g.add(post); }
      const rail = box(2.9, 0.09, 0.09, 0x6a4a30); rail.position.y = 1.0; g.add(rail);
      g.position.set(p.x, this.y0, p.z); g.rotation.y = Math.atan2(this.along.x, this.along.z) - Math.PI / 2; this.group.add(g);
      const horse = new Puppet('horse', animalModel('animal_horse') ? 1.7 : 1.25), hp = p.clone().addScaledVector(this.toward, -b.side * 1.1);
      horse.group.position.set(hp.x, this.y0, hp.z); horse.heading = Math.atan2(this.toward.x * b.side, this.toward.z * b.side) - Math.PI / 2; this.group.add(horse.group); // (nose to the rail)
      (this.hitch ||= {})[id] = { g, horse };
    }
    this.dressStreet();
    this.makeSign();
  }
  /** The daily stage: once the boarding house is mended, the Overland stage drives in from the farm end of Main Street
   *  behind its pair of horses about mid-morning, draws up before the boarding house and waits there into the afternoon,
   *  then swings round and rattles off the way it came. */
  stage_(dt) {
    const t = this.clock ?? 0.5, src = propModel('veh_stagecoach');
    if (!this.tiers.boarding || !src) { if (this.coach) this.coach.g.visible = false; this.rider = null; return; }
    if (!this.coach) {
      const m = src.scene.clone(), b = new THREE.Box3().setFromObject(m), sz = b.getSize(new THREE.Vector3()), c = b.getCenter(new THREE.Vector3());
      const k = 5.6 / sz.x; m.position.set(-c.x, -b.min.y, -c.z);
      const body = new THREE.Group(); body.add(m); body.scale.setScalar(k); // (its length along x)
      const g = new THREE.Group(); g.add(body);
      const horses = [-0.75, 0.75].map((dz) => { const h = new Puppet('horse', animalModel('animal_horse') ? 1.7 : 1.25); this.group.add(h.group); return { h, dz }; });
      g.visible = false; this.group.add(g);
      this.coach = { g, body, horses, s: -70, face: 1, phase: 'away', turn: 0 };
    }
    const C = this.coach, STOP = 13.5, OUT = -70, ACROSS = -0.3; // (down the crown of the street, clear of the carts drawn up by the store and the horse at the saloon rail)
    // when it should be where: away, coming in (from 0.4), waiting, going (from 0.58)
    if (C.phase === 'away' && t > 0.4 && t < 0.55) { C.phase = 'in'; C.s = OUT; C.face = 1; C.turn = 0; C.horn = false; }
    if (C.phase === 'in' && !C.horn && C.s > -40) { C.horn = true; this.onStage?.(); } // (the guard's horn as she comes in sight of town)
    if (C.phase === 'wait' && (t > 0.58 || t < 0.4)) C.phase = 'turn';
    let speed = 0;
    if (C.phase === 'in') { speed = 4.5 * Math.min(1, (STOP - C.s) / 6 + 0.25); C.s += speed * dt; if (C.s >= STOP) { C.s = STOP; C.phase = 'wait'; } }
    else if (C.phase === 'turn') { C.turn = Math.min(1, C.turn + dt / 2.5); speed = 1; if (C.turn >= 1) { C.phase = 'out'; C.face = -1; } }
    else if (C.phase === 'out') { speed = 4.5; C.s -= speed * dt; if (C.s <= OUT) { C.phase = 'away'; } }
    const shown = C.phase !== 'away' && !this.far;
    C.g.visible = shown; for (const H of C.horses) H.h.group.visible = shown;
    // while it waits, a passenger stretches her legs beside it: a lady traveller from back East with news of the county
    if (!C.rider && hasFolk('townsfolk_2')) { C.rider = new ModelFigure('townsfolk_2', { hue: 1.9 }); C.rider.root.visible = false; this.group.add(C.rider.root); }
    if (C.rider) {
      const out = C.phase === 'wait' && !this.far; C.rider.root.visible = out; this.rider = out ? C.rider.root.position : null;
      if (out) { const q = this.at.clone().addScaledVector(this.along, C.s - 1.2).addScaledVector(this.toward, 1.2 - 2.1); C.rider.root.position.set(q.x, this.y0 + 0.02, q.z); C.rider.root.rotation.y = Math.atan2(-this.toward.x, -this.toward.z); C.rider.update(dt, 0, null); }
    }
    if (!shown) return;
    const yaw = Math.atan2(-this.along.z, this.along.x) + (C.phase === 'turn' ? C.turn * Math.PI : C.face < 0 ? Math.PI : 0); // (its length along the street, nose the way it's going)
    const p = this.at.clone().addScaledVector(this.along, C.s).addScaledVector(this.toward, ACROSS);
    C.g.position.set(p.x, this.y0, p.z); C.g.rotation.y = yaw;
    // the pair in the traces, ahead of the coach, side by side
    const fwd = new THREE.Vector3(Math.cos(yaw), 0, -Math.sin(yaw)), side = new THREE.Vector3(Math.sin(yaw), 0, Math.cos(yaw));
    for (const H of C.horses) {
      const q = p.clone().addScaledVector(fwd, 4.6).addScaledVector(side, H.dz);
      H.h.group.position.set(q.x, this.y0, q.z); H.h.update(dt, speed, speed > 0.2 ? 'walk' : 'idle', false, 0);
    }
  }
  /** Main Street's street lamps, and the lamplighter: at dusk old Amos Teague comes out at the head of the street with
   *  his ladder-pole and walks down it lamp by lamp, stopping at each to light it, then goes in by the church. They're
   *  put out at sunup. (Arriving after he's done, or far off when he made his round, you find them all lit.) */
  lamplighter_(dt) {
    const t = this.clock ?? 0.5, dusk = t > 0.745 || t < 0.235;
    if (!this.streetLamps) {
      this.streetLamps = []; const ironParts = [];
      [[-15, 1], [-6, -1], [2.5, 1], [9, -1], [15.5, 1], [-1.5, -1]].sort((a, b) => a[0] - b[0]).forEach(([s, side]) => {
        const lamp = new THREE.Group(), p = this.at.clone().addScaledVector(this.along, s).addScaledVector(this.toward, side * (HALF - 0.5));
        // (the post, its crossbar for the ladder and the iron cap are merged across all six lamps into one mesh below)
        ironParts.push(new THREE.BoxGeometry(0.12, 3.0, 0.12).translate(p.x, this.y0 + 1.5, p.z), new THREE.BoxGeometry(0.5, 0.05, 0.05).translate(p.x, this.y0 + 2.55, p.z), new THREE.ConeGeometry(0.26, 0.2, 6).translate(p.x, this.y0 + 3.48, p.z));
        const glass = new THREE.MeshBasicNodeMaterial({ color: 0x5a5248 });
        const cage = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.12, 0.38, 6), glass); cage.position.y = 3.2; lamp.add(cage);
        lamp.position.set(p.x, this.y0, p.z); this.group.add(lamp);
        // the pool of lamplight on the street beneath it: a soft warm round with a ragged rim, laid on the dirt
        const pool = new THREE.Mesh(new THREE.PlaneGeometry(6.5, 6.5).rotateX(-Math.PI / 2), POOL_MAT); pool.position.set(p.x, this.y0 + 0.05, p.z); pool.rotation.y = s; pool.visible = false; pool.renderOrder = 2; this.group.add(pool);
        this._world.colliders.push({ x: p.x, z: p.z, r: 0.25 });
        this.streetLamps.push({ glass, pool, at: p, side, lit: false });
      });
      const iron = new THREE.Mesh(mergeGeometries(ironParts.map((g) => (g.index ? g.toNonIndexed() : g))), paperMaterial({ color: 0x342b25, flatShading: true }));
      iron.castShadow = true; iron.receiveShadow = true; this.group.add(iron); // (one draw call for all the posts and caps)
    }
    const light = (L, on) => { if (L.lit !== on) { L.lit = on; L.glass.color.setHex(on ? 0xffc060 : 0x5a5248); L.pool.visible = on; } };
    const L = this.lighter;
    if (!dusk) { for (const S of this.streetLamps) light(S, false); this.lit_round = false; if (L) L.fig.root.visible = false; return; }
    if (this.lit_round) return;
    // just turned dusk, close enough to see: he comes out and makes his round. Otherwise (late, or far off) they're lit
    if (!L && (this.far || !(t > 0.745 && t < 0.8))) { for (const S of this.streetLamps) light(S, true); this.lit_round = true; return; }
    if (!L) {
      const fig = hasFolk('prospectors_3') ? new ModelFigure('prospectors_3', { hue: 2.6 }) : new Figure({ coat: 0x4a5a6a, sleeve: 0x4a5a6a, pants: 0x3a3430, hat: 'bowler', hold: null });
      const p0 = this.at.clone().addScaledVector(this.along, -21);
      fig.root.position.set(p0.x, this.y0 + 0.02, p0.z); this.group.add(fig.root);
      this.lighter = { fig, i: 0, wait: 0 };
      return;
    }
    L.fig.root.visible = !this.far;
    const S = this.streetLamps[L.i], q = L.fig.root.position;
    const goal = S ? S.at.clone().addScaledVector(this.toward, -S.side * 0.7) : this.doors.church.clone().addScaledVector(this.along, -0.6);
    const gx = goal.x - q.x, gz = goal.z - q.z, gd = Math.hypot(gx, gz); let spd = 0;
    if (gd > 0.25) { spd = 1.6; q.x += (gx / gd) * spd * dt; q.z += (gz / gd) * spd * dt; let d = Math.atan2(gx, gz) - L.fig.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d)); L.fig.root.rotation.y += d * Math.min(1, dt * 6); }
    else if (S) { // at the lamp: he reaches up a moment, and it catches
      let d = Math.atan2(S.at.x - q.x, S.at.z - q.z) - L.fig.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d)); L.fig.root.rotation.y += d * Math.min(1, dt * 6);
      L.wait += dt; if (L.wait > 1.1) { light(S, true); L.wait = 0; L.i++; }
    } else { this.group.remove(L.fig.root); this.lighter = null; this.lit_round = true; return; } // (in at the church door: home for the night)
    L.fig.update(dt, spd, null);
  }
  /** After dark, the mended buildings light their windows. */
  update(night, dt = 0) {
    const on = night > 0.45;
    // far from town (130 m or more) its folk are specks: hide them and skip their animation. Skinned figures can't be
    // frustum-culled, so otherwise every one of them is drawn every frame wherever you are
    const cp = this.camPos, far = !!cp && Math.hypot(cp.x - this.at.x, cp.z - this.at.z) > 130;
    this.far = far;
    if (far) {
      const figs = [...Object.values(this.folk || {}).map((F) => F.fig), ...(this.civilians || []).map((c) => c.fig), ...(this.queue || []), ...(this.hallDancers || []).map((d) => d.fig), ...(this.revue || [])];
      if (this.assayer) figs.push(this.assayer); if (this.hallFiddler) figs.push(this.hallFiddler);
      for (const f of figs) f.root.visible = false;
      for (const h of Object.values(this.hitch || {})) h.horse.group.visible = false;
      for (const B of this.beasts || []) B.p.group.visible = false;
      for (const c of this.civilians || []) { c.note.visible = false; if (c.ready) c.ready.visible = false; }
      if (on !== this.lit) { this.lit = on; for (const g of Object.values(this.parts)) if (g.userData.glow) g.userData.glow.visible = on; LAMP_GLASS.color.setHex(on ? 0xffc060 : 0x5a5248); }
      return;
    }
    this._tg = (this._tg || 0) + dt; uTentGlow.value = Math.max(0, night - 0.35) * 0.4 * (0.94 + Math.sin(this._tg * 7.3) * 0.03 + Math.sin(this._tg * 2.1) * 0.03); // (lanterns in the tents: a soft flicker)
    this._t = (this._t || 0) + dt;
    // late at night folk go indoors: the Row turns in to its tents and the shopkeepers shut up shop; only the night
    // trades (the Golden Garter, the Grand Hotel's clerk) keep their doors
    const abed = !!this.bedtime || !!this.raining; // (and in a downpour everyone runs in out of the wet, the night trades excepted)
    for (const [i, c] of (this.civilians || []).entries()) {
      // turning in (bedtime, or a downpour): they walk to the tent flap and duck inside, rather than vanishing where
      // they stand; and come out of it again after
      if (abed) {
        c.note.visible = false; if (c.ready) c.ready.visible = false;
        const q = c.fig.root.position, dx = c.door.x - q.x, dz = c.door.z - q.z, d = Math.hypot(dx, dz);
        if (c.fig.root.visible && d > 0.35 && !this.far) { const sp = 1.6; q.x += (dx / d) * sp * dt; q.z += (dz / d) * sp * dt; let r = Math.atan2(dx, dz) - c.fig.root.rotation.y; r = Math.atan2(Math.sin(r), Math.cos(r)); c.fig.root.rotation.y += r * Math.min(1, dt * 6); c.fig.update(dt, sp, null); }
        else { c.fig.root.visible = false; q.set(c.door.x, q.y, c.door.z); c.goal?.copy(c.at); c.atMeeting = false; }
        continue;
      }
      c.fig.root.visible = true;
      c.note.visible = !!c.want;
      // by day they don't just stand there: now and then one strolls over to a neighbour's tent for a word, stands a
      // while, and wanders home again
      const q = c.fig.root.position; c.goal ||= c.at.clone(); c.wait = (c.wait ?? 4 + this.rowRng() * 10) - dt;
      if (c.wait <= 0) {
        const side = (v) => Math.sign((v.x - this.at.x) * this.toward.x + (v.z - this.at.z) * this.toward.z), home = c.goal.distanceTo(c.at) < 0.5, others = this.civilians.filter((o) => o !== c && side(o.at) === side(c.at)); // (neighbours on their own side of the Row: never through the tents)
        if (home && others.length && this.rowRng() < 0.5) { const o = others[Math.floor(this.rowRng() * others.length)]; c.goal.copy(o.at).addScaledVector(this.along, this.rowRng() < 0.5 ? 1.1 : -1.1); }
        else c.goal.copy(c.at);
        c.wait = 6 + this.rowRng() * 12;
      }
      // Sunday meeting: on a Sunday morning, once the church is mended, the Row's families walk up Main Street to the
      // churchyard and stand in loose rows before its doors, facing in, until the meeting lets out
      if (this.sunday && this.tiers.church && this.doors.church) {
        const out = this.along.clone().negate(), row = Math.floor(i / 5), col = (i % 5) - 2 + (row % 2) * 0.5;
        c.goal.copy(this.doors.church).addScaledVector(out, 3 + row * 1.25).addScaledVector(this.toward, col * 1.15); c.wait = 2; c.atMeeting = true;
      } else if (this.fireworksOn) { // Saturday's fireworks: out into Main Street in a loose crowd, all looking up the street to the sky over the church
        const j = i * 2.399, s = 1 + (i % 4) * 2.7 + Math.sin(j) * 0.5, across = (Math.floor(i / 4) - 1) * 2.3 + Math.cos(j) * 0.5;
        c.goal.copy(this.at).addScaledVector(this.along, s).addScaledVector(this.toward, across); c.wait = 2; c.atMeeting = true;
      } else if (c.atMeeting) { c.atMeeting = false; c.goal.copy(c.at); c.wait = 4 + this.rowRng() * 6; } // (and home again after)
      const gx = c.goal.x - q.x, gz = c.goal.z - q.z, gd = Math.hypot(gx, gz); let spd = 0;
      if (gd < 0.3 && c.atMeeting) { let d = Math.atan2(this.along.x, this.along.z) - c.fig.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d)); c.fig.root.rotation.y += d * Math.min(1, dt * 3); } // (facing the church door)
      if (gd > 0.3) { spd = c.atMeeting && gd > 6 ? 1.5 : 0.9; q.x += (gx / gd) * spd * dt; q.z += (gz / gd) * spd * dt; let d = Math.atan2(gx, gz) - c.fig.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d)); c.fig.root.rotation.y += d * Math.min(1, dt * 6); }
      for (const o of this.civilians) { if (o === c || !o.fig.root.visible) continue; const p2 = o.fig.root.position, dx = q.x - p2.x, dz = q.z - p2.z, dd = Math.hypot(dx, dz); if (dd < 0.85 && dd > 1e-4) { q.x += (dx / dd) * (0.85 - dd) * 0.5; q.z += (dz / dd) * (0.85 - dd) * 0.5; } } // (never inside one another)
      c.note.position.x = q.x; c.note.position.z = q.z;
      const can = !!c.want && (this.inv?.[c.want[0]] || 0) >= c.want[1]; // (you're carrying what they want)
      if (c.ready) { c.ready.visible = can && c.note.visible; if (c.ready.visible) { c.note.visible = false; c.ready.position.copy(c.note.position); c.ready.rotation.copy(c.note.rotation); } }
      if (c.atMeeting) { c.note.visible = false; if (c.ready) c.ready.visible = false; } // (no errands at meeting)
      c.fig.update(dt, spd, null);
      if (!c.want && this.day >= c.day && c.day >= 0) { c.want = WANTS[Math.floor(this.rowRng() * WANTS.length)]; c.note.visible = true; }
      if (c.want) { c.note.position.y = this.y0 + 2.35 + Math.sin(this._t * 2 + i) * 0.06; c.note.rotation.y += dt * 0.8; if (c.ready?.visible) { c.ready.position.copy(c.note.position); c.ready.rotation.copy(c.note.rotation); } }
    }
    for (const [id, h] of Object.entries(this.hitch || {})) { h.horse.group.visible = !this.bedtime || NIGHT_OWLS.has(id); if (h.horse.group.visible) h.horse.update(dt, 0, 'idle', false, 0); } // (ridden home at bedtime, but for the saloon's late customers)
    for (const B of this.beasts || []) { B.p.group.visible = !this.bedtime; if (!this.bedtime) B.p.update(dt, 0, 'idle', false, 0); } // (in the stable for the night)
    this.lamplighter_(dt);
    this.stage_(dt);
    // snowmen: once the snow lies thick, the Row's children have been out, and two paper snowmen stand up from the
    // page (one at the head of Main Street, one down the Row); when the snow goes they fold back down flat
    if (!this.snowmen && (this.snowCover || 0) > 0.05) {
      this.snowmen = [[-16, -4.4, 0.4], [-44, 4, -0.6]].map(([s, across, turn]) => {
        const hinge = new THREE.Group(), p = this.at.clone().addScaledVector(this.along, s).addScaledVector(this.toward, across);
        hinge.position.set(p.x, this.y0, p.z); hinge.rotation.y = Math.atan2(this.along.x, this.along.z) + turn; hinge.add(makeMesh('snowman')); this.group.add(hinge);
        return hinge;
      });
    }
    if (this.snowmen) { const up = Math.min(1, Math.max(0, ((this.snowCover || 0) - 0.55) * 4)); for (const h of this.snowmen) { h.visible = up > 0.01; h.rotation.x = -(1 - up) * Math.PI / 2; } } // (rising on its hinge as the snow deepens)
    if (this.assayer) { this.assayer.root.visible = !abed; if (!abed) this.assayer.update(dt, 0, 'clipboard'); }
    for (const k in this.folk || {}) {
      const F = this.folk[k], owl = NIGHT_OWLS.has(k.split('_')[0]);
      F.fig.root.visible = owl || !abed; if (F.bar) F.bar.visible = true;
      if (!F.fig.root.visible) continue;
      // they look up as you pass: within a few paces a shopkeeper turns to watch you by (never more than a quarter
      // turn from the street, so no one faces the wall), and eases back when you've gone on
      const r = F.fig.root; F.face ??= r.rotation.y;
      const pp = this.playerPos; let want = F.face;
      if (pp) { const dx = pp.x - r.position.x, dz = pp.z - r.position.z, d = Math.hypot(dx, dz); if (d < 5 && d > 0.4) { let off = Math.atan2(dx, dz) - F.face; off = Math.atan2(Math.sin(off), Math.cos(off)); want = F.face + Math.max(-1.3, Math.min(1.3, off)); } }
      let dr = want - r.rotation.y; dr = Math.atan2(Math.sin(dr), Math.cos(dr)); r.rotation.y += dr * Math.min(1, dt * 3);
      F.fig.update(dt, 0, F.pose);
      // a word of greeting the first time you pass each day: a little hand-lettered paper card over their head
      if (pp && !k.includes('_') && (this.greeted ||= {})[k] !== this.day && Math.hypot(pp.x - r.position.x, pp.z - r.position.z) < 3.2) { this.greeted[k] = this.day; this.sayHello(r); }
    }
    this.helloTick(dt);
    // the Golden Garter's can-can revue: once the saloon is mended, after dark, three dancers high-kick on its
    // boardwalk to the honky-tonk piano, skirts flying
    if (this.tiers.saloon && on) {
      if (!this.revue) {
        this.revue = [0xc4362f, 0xe8b84a, 0x3e7a5a].map((c, i) => {
          const m = ['saloon_2', 'saloon_3', 'saloon_4'][i]; /* the three girls from the saloon sheet, when they've been made */
          const f = hasFolk(m) ? new ModelFigure(m) : new Figure({ coat: c, dress: c, dressPat: 0, sleeve: 0xf6efe0, hair: [0x3a2418, 0xe8c070, 0x2b2018][i], long: i !== 1, bun: i === 1, cheeks: true, glam: true, curvy: true, neckline: true, corset: 0x2b2018, short: true, stockings: 0x2a2224, garter: c, mole: i === 2, lips: 0xc4302c, hat: 'sunday', hatColor: c, band: 0xf6efe0, scale: 0.92 });
          f.t = i * 0.35; this.parts.saloon.add(f.root); f.root.position.set(-2 + i * 2, 0.14, 1.1); return f;
        });
      }
      for (const f of this.revue) { f.root.visible = true; f.update(dt, 0, 'cancan'); }
    } else if (this.revue) for (const f of this.revue) f.root.visible = false;
    if (on === this.lit) return; this.lit = on; for (const g of Object.values(this.parts)) if (g.userData.glow) g.userData.glow.visible = on;
    LAMP_GLASS.color.setHex(on ? 0xffc060 : 0x5a5248); // (the new streets' door lanterns)
  }
  save() { return { ...this.tiers, opened: this.opened || [], raided: Object.keys(this.raided || {}) }; }
  load(d) {
    const order = [...BUILDINGS.map((b) => b.id), 'church', ...STREETS.flatMap((st) => st.buildings.map((b) => b.id))]; // (Main Street first, so the new streets open in turn)
    for (const k of d?.opened || []) if (STREETS[k]) this.openStreet(k);
    for (const id of order) if (d?.[id] === 1) this.mend(id);
    for (const id of d?.raided || []) if (!this.tiers[id]) (this.raided ||= {})[id] = true;
  }

  /**
   * Main Street's wagons and its water tower, from the reference art (the wagon and mining sheets): a broken-down
   * prairie schooner lies in the street before the ruined store, a loaded freight wagon stands there once the store is
   * mended, the stagecoach waits up the street once the boarding house has rooms, and a water tower stands behind
   * the saloon's side. Wagons are solid (two circles each). Re-dressed whenever a building is mended.
   */
  dressStreet() {
    this.world ||= this._world;
    for (const o of this.street || []) this.group.remove(o);
    if (this.streetCols) { const C = this.world.colliders; for (const c of this.streetCols) { const i = C.indexOf(c); if (i >= 0) C.splice(i, 1); } }
    this.street = []; this.streetCols = [];
    const yaw = Math.atan2(-this.along.z, this.along.x); // a model's length (its x) along the street
    const put = (name, size, axis, s, across, turn = 0, solid = false) => {
      const src = propModel(name); if (!src) return;
      const m = src.scene.clone(), b = new THREE.Box3().setFromObject(m), sz = b.getSize(new THREE.Vector3()), c = b.getCenter(new THREE.Vector3());
      const k = size / sz[axis]; m.position.set(-c.x, -b.min.y, -c.z);
      const g = new THREE.Group(); g.add(m); g.scale.setScalar(k);
      const p = this.at.clone().addScaledVector(this.along, s).addScaledVector(this.toward, across);
      g.position.set(p.x, this.y0, p.z); g.rotation.y = yaw + turn; this.group.add(g); this.street.push(g);
      if (solid) for (const t of [-0.28, 0.28]) {
        const q = p.clone().addScaledVector(this.along, Math.cos(turn) * t * size).addScaledVector(this.toward, -Math.sin(turn) * t * size);
        const col = { x: q.x, z: q.z, r: sz.z * k * 0.55 }; this._world.colliders.push(col); this.streetCols.push(col);
      }
    };
    if (this.tiers.store) put('veh_freight_wagon', 5.4, 'x', -8.5, -2.9, 0, true); /* (clear of the tinker's pitch at the head of the street) */
    else put('veh_handcart', 3.2, 'x', -8.5, -3.2, 0.5, true); // an abandoned ore cart, its load still in it
    // (the boarding house's own stage now comes and goes: see stage_)
    put('prop_watertower', 7.5, 'y', -6, HALF + 11);
    // the new streets' traffic: a freight wagon drawn up before the mended feed & grain, and the stage line's coach
    // waiting in the street before its stables
    const at = (id) => { const k = STREETS.findIndex((q) => q.buildings.some((x) => x.id === id)); if (k < 0 || !this.opened?.includes(k)) return null; return { b: STREETS[k].buildings.find((x) => x.id === id), off: this.streetOffs[k] }; };
    const fd = this.tiers.feed && at('feed'); if (fd) put('veh_freight_wagon', 5.4, 'x', fd.b.s + 4.6, fd.off + fd.b.side * (HALF - 3.4), 0, true);
    // working beasts: an ox in the traces of each freight wagon, standing patient; a donkey tethered by the mended livery
    for (const B of this.beasts || []) this.group.remove(B.p.group);
    this.beasts = [];
    const beast = (name, scale, s, across, face, kit = name) => { // (kit: the paper puppet it falls back on; the model is animal_<name>)
      if (!animalModel('animal_' + name)) return;
      const p = new Puppet(kit, scale, 'animal_' + name), q = this.at.clone().addScaledVector(this.along, s).addScaledVector(this.toward, across);
      p.group.position.set(q.x, this.y0, q.z); p.heading = face; this.group.add(p.group); this.beasts.push({ p });
      const col = { x: q.x, z: q.z, r: 0.8 }; this._world.colliders.push(col); this.streetCols.push(col);
    };
    const along0 = Math.atan2(this.along.x, this.along.z) - Math.PI / 2; // (a puppet's heading to face up the street)
    if (this.tiers.store) beast('ox', 1.5, -8.5 + 4.4, -2.9, along0);
    if (fd) beast('ox', 1.5, fd.b.s + 4.6 + 4.4, fd.off + fd.b.side * (HALF - 3.4), along0);
    if (this.tiers.livery) { const lv = BUILDINGS.find((q) => q.id === 'livery'); beast('donkey', 1.1, lv.s + lv.w / 2 + 1.4, lv.side * (HALF - 1.2), along0 + Math.PI / 2 * lv.side, 'horse'); }
    const sg = this.tiers.stable2 && at('stable2'); if (sg) put('veh_stagecoach', 5.6, 'x', sg.b.s + 4.2, sg.off + sg.b.side * (HALF - 3.4), Math.PI, true);
    // back lots: behind each mended building, the clutter of a working yard, by trade: a woodpile and a rain barrel
    // behind the smithy, hay behind the stables, crates and barrels behind the saloon and the stores. (Seeded by building, so a yard keeps its things where they were.)
    const YARD = { smithy: ['prop_woodpile', 'prop_barrel'], cooper: ['prop_barrel', 'prop_barrel', 'prop_woodpile'], bakery: ['prop_woodpile', 'prop_crates'], livery: ['prop_haybales', 'veh_handcart'], stable2: ['prop_haybale_round', 'prop_haybales'], feed: ['prop_haybales', 'prop_crates'], saloon: ['prop_barrel', 'prop_crates'], hotel2: ['prop_crates', 'prop_barrel'], boarding: ['prop_woodpile'], store: ['prop_crates', 'prop_barrel'], drygoods: ['prop_crates'] };
    const SIZE = { prop_woodpile: [1.9, 'x'], prop_barrel: [0.95, 'y'], prop_crates: [1.2, 'y'], prop_haybales: [2.2, 'x'], prop_haybale_round: [1.3, 'y'], veh_handcart: [2.6, 'x'] };
    const lots = [...BUILDINGS.map((b) => [b, 0]), ...(this.opened || []).flatMap((k) => STREETS[k].buildings.map((b) => [b, this.streetOffs[k]]))];
    for (const [b, off] of lots) {
      if (!this.tiers[b.id]) continue;
      const rnd = mulberry32(hashId('yard' + b.id)), back = off + b.side * (HALF + b.d + 1.6);
      const items = YARD[b.id] || ['prop_barrel', 'prop_crates'];
      items.forEach((name, j) => {
        const [size, axis] = SIZE[name], s = b.s + (j - (items.length - 1) / 2) * (b.w / items.length) + (rnd() - 0.5) * 0.6;
        put(name, size * (0.9 + rnd() * 0.2), axis, s, back + b.side * rnd() * 1.2, rnd() * 6.28, true);
      });
    }
    // stovepipes: the mended smithy, bakery and cooperage keep a fire all day, the boarding house and the Grand Hotel
    // light their cookstoves morning and evening. A black tin pipe stands on the back of the roof (found by dropping a
    // ray onto the building), and main.js sends the smoke up it while it's lit.
    this.chimneys = [];
    const pipeMat = paperMaterial({ color: 0x2e2a28, flatShading: true }), ray = new THREE.Raycaster();
    for (const [id, when] of Object.entries(SMOKERS)) {
      const g = this.parts[id]; if (!this.tiers[id] || !g) continue;
      const b = BUILDINGS.find((q) => q.id === id) || STREETS.flatMap((st) => st.buildings).find((q) => q.id === id); if (!b) continue;
      const cached = (this._chim ||= new WeakMap()).get(g); // (the raycasts run once per building model, not on every rebuild)
      if (cached) { this.chimneys.push({ ...cached.spot, when }); if (cached.pipe) { this.group.add(...cached.pipe); this.street.push(...cached.pipe); } continue; }
      g.updateMatrixWorld(true);
      const box = new THREE.Box3().setFromObject(g), c = box.getCenter(new THREE.Vector3()).addScaledVector(this.toward, b.side * b.d * 0.22).addScaledVector(this.along, b.w * 0.2);
      const drop = (x, z) => { ray.set(new THREE.Vector3(x, box.max.y + 2, z), new THREE.Vector3(0, -1, 0)); return ray.intersectObject(g, true).find((h) => h.object.isMesh && h.point.y > this.y0 + 1.5)?.point.y ?? -1; };
      // a model with its own chimney (the smithy's brick stack): a narrow peak standing up out of the roof. Sample a
      // grid over the building and look for a point well above its neighbours on every side; smoke from that instead
      const N = 12, sx = box.max.x - box.min.x, sz = box.max.z - box.min.z, H = [];
      for (let i = 0; i <= N; i++) { H[i] = []; for (let j = 0; j <= N; j++) H[i][j] = drop(box.min.x + (i / N) * sx, box.min.z + (j / N) * sz); }
      let stack = null;
      for (let i = 1; i < N; i++) for (let j = 1; j < N; j++) {
        const h = H[i][j]; if (h < 0) continue;
        if ([H[i - 1][j], H[i + 1][j], H[i][j - 1], H[i][j + 1]].filter((v) => v < h - 0.35).length >= 3 && (!stack || h > stack.y)) stack = { x: box.min.x + (i / N) * sx, y: h, z: box.min.z + (j / N) * sz };
      }
      if (stack) { const spot = { x: stack.x, y: stack.y, z: stack.z, top: 0.15 }; this._chim.set(g, { spot }); this.chimneys.push({ ...spot, when }); continue; }
      const hy = drop(c.x, c.z); if (hy < 0) continue; const hit = { point: { y: hy } };
      const pipe = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.13, 1.1, 8), pipeMat), cap = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.17, 0.12, 8), pipeMat);
      pipe.position.set(c.x, hit.point.y + 0.45, c.z); cap.position.set(c.x, hit.point.y + 1.04, c.z); pipe.castShadow = cap.castShadow = true;
      this.group.add(pipe, cap); this.street.push(pipe, cap);
      const spot = { x: c.x, y: hit.point.y, z: c.z, top: 1.1 }; this._chim.set(g, { spot, pipe: [pipe, cap] }); this.chimneys.push({ ...spot, when });
    }
    // bunting: a street with every building on it mended is strung across with three drooping cords of paper pennants
    // (red, cream and blue, cut with pinking shears), eave to eave. All the streets' pennants share three meshes.
    const flags = [[], [], []], cords = [];
    const done = [-1, ...(this.opened || [])].filter((k) => this.streetDone(k));
    for (const k of done) {
      const off = k < 0 ? 0 : this.streetOffs[k];
      [-9, 2.5, 13].forEach((s, j) => {
        const rnd = mulberry32(hashId('bunt' + k + j)), N = 15, y0 = 3.5 + rnd() * 0.3, sag = 0.7 + rnd() * 0.25;
        const P = (u) => this.at.clone().addScaledVector(this.along, s + (rnd() - 0.5) * 0.4).addScaledVector(this.toward, off - HALF + 0.3 + u * (2 * HALF - 0.6)).setY(this.y0 + y0 - Math.sin(u * Math.PI) * sag);
        let prev = P(0);
        for (let i = 1; i <= N; i++) {
          const q = P(i / N), mid = prev.clone().add(q).multiplyScalar(0.5), len = prev.distanceTo(q);
          const cord = new THREE.BoxGeometry(0.03, 0.03, len); cord.lookAt(q.clone().sub(prev)); cord.translate(mid.x, mid.y, mid.z); cords.push(cord);
          if (i < N) { // a pennant hung from this joint, flat across the street so it shows from up and down it
            const w = 0.2, h = 0.34 + rnd() * 0.06, a = q.clone().addScaledVector(this.toward, -w), b = q.clone().addScaledVector(this.toward, w), tip = q.clone().setY(q.y - h);
            tip.addScaledVector(this.along, (rnd() - 0.5) * 0.08); // (each hangs a touch askew)
            flags[(i + j) % 3].push(new THREE.BufferGeometry().setFromPoints([a, b, tip]));
          }
          prev = q;
        }
      });
    }
    if (cords.length) {
      const add = (geo, color) => { geo.computeVertexNormals(); const m = new THREE.Mesh(geo, paperMaterial({ color, side: THREE.DoubleSide })); m.castShadow = true; this.group.add(m); this.street.push(m); };
      add(mergeGeometries(cords.map((g) => g.toNonIndexed())), 0x5a4030);
      [0xb5473a, 0xefe3c4, 0x4f6f96].forEach((col, n) => flags[n].length && add(mergeGeometries(flags[n]), col));
    }
  }

  /** Where settler i lives: before a door on the boardwalk, or by one of the tents. */
  homeFor(i, needs = null) {
    // most folk scrape by on Squatters' Row; newcomers who came for the boarding house's rooms live in town
    if (!needs && this.squat?.length) { const p = this.squat[i % this.squat.length].clone(); return p.addScaledVector(this.along, Math.floor(i / this.squat.length) * 1.2); }
    if (needs && this.doors[needs]) { /* lodgers loaf in the street before the house they lodge at, clear of whoever keeps its door */
      const side = BUILDINGS.find((q) => q.id === needs)?.side ?? 1;
      return this.doors[needs].clone().addScaledVector(this.toward, -side * 2.6).addScaledVector(this.along, (i % 2 ? 1.3 : -1.3));
    }
    const spots = [...Object.values(this.doors), ...this.tents];
    const p = spots[i % spots.length].clone(), k = Math.floor(i / spots.length);
    return p.addScaledVector(this.along, (k ? 1.4 : 0) * (i % 2 ? 1 : -1));
  }
  /** Is (x, z) at the assay office's door? */
  /** A spot in the street: s along it, `across` metres from the centre line toward side +1; `look` is where it faces. */
  spot(s, across, lookS = s, lookAcross = 0) {
    const at = (a, b) => this.at.clone().addScaledVector(this.along, a).addScaledVector(this.toward, b);
    const p = at(s, across); return { x: p.x, z: p.z, look: at(lookS, lookAcross) };
  }
  nearAssay(pos, r = 3) { const d = this.doors.assay; return Math.hypot(pos.x - d.x, pos.z - d.z) < r; }
  near(pos, r = 34) { return Math.hypot(pos.x - this.at.x, pos.z - this.at.z) < r; }
}

function hashId(id) { let h = 7; for (const c of id) h = (h * 31 + c.charCodeAt(0)) >>> 0; return h; }
function beams2(xs) { const g = new THREE.Group(); for (const [x] of xs) { const p = box(0.16, 1.4, 0.16, 0x6a4a30); p.position.set(x, 0.7, -0.06); g.add(p); } return g; }
