// Paper-model props. Trees and bushes are two crossed die-cut cards with real thickness
// (extruded silhouettes) — printed faces from painted canvas art, cream cut edges on the sides.
// Rocks are faceted papier-mâché. Every geometry has its origin at the base.
import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { mulberry32 } from './noise.js';
import { cardMaterial, paperMaterial } from './materials.js';
import {
  EDGE_UV, BLOOMS_SUSAN, BLOOMS_CONE, pineSilhouette, roundTreeSilhouette, bushSilhouette, pineArt, roundTreeArt, bushArt,
  grassSilhouette, grassArt, hillSilhouette, hillArt, peakArt, rockSilhouette, rockArt,
  sangSilhouette, sangArt, silverArt, geodeSilhouette, geodeArt, musselSilhouette, musselArt, amberSilhouette, amberArt,
  clayArt, toadstoolSilhouette, toadstoolArt, oreArt, quartzArt, hiveSilhouette, hiveArt, signSilhouette, signArt, cornSilhouette, cornArt, cattailSilhouette, cattailArt, snagSilhouette, snagArt, lodgeSilhouette, lodgeArt, birchSilhouette, birchArt, wildflowerSilhouette, wildflowerArt, appleHeapSilhouette, appleHeapArt, satchelSilhouette, satchelArt, lilypadSilhouette, lilypadArt, pumpkinSilhouette, pumpkinArt, baleSilhouette, baleArt, stookSilhouette, stookArt,
} from './textures.js';

const THICK = 0.06;

/** Extrude a silhouette into a thin card; faces get uv from the silhouette's bounding box. */
export function cardGeometry(points, thickness = THICK, backAt = null) {
  const shape = new THREE.Shape(points.map(([x, y]) => new THREE.Vector2(x, y)));
  const g = new THREE.ExtrudeGeometry(shape, { depth: thickness, bevelEnabled: false, curveSegments: 1 });
  g.translate(0, 0, -thickness / 2);
  let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
  for (const [x, y] of points) { minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
  // same padding as textures.js frame()
  const w0 = maxX - minX, h0 = maxY - minY;
  minX -= w0 * 0.04; maxX += w0 * 0.04; minY -= h0 * 0.04; maxY += h0 * 0.04;
  const w = maxX - minX, h = maxY - minY;
  const pos = g.attributes.position, uvA = g.attributes.uv;
  for (const grp of g.groups) {
    for (let i = grp.start; i < grp.start + grp.count; i++) {
      if (grp.materialIndex === 0 && backAt && pos.getZ(i) < 0) uvA.setXY(i, (backAt[0] - minX) / w, (backAt[1] - minY) / h); // plain back (no mirrored print)
      else if (grp.materialIndex === 0) uvA.setXY(i, (pos.getX(i) - minX) / w, (pos.getY(i) - minY) / h);
      else uvA.setXY(i, EDGE_UV[0], EDGE_UV[1]);
    }
  }
  g.clearGroups();
  g.computeVertexNormals();
  return g;
}

/** Two cards crossed at right angles (slot construction). */
function crossed(points, thickness = THICK) {
  const a = cardGeometry(points, thickness);
  const b = cardGeometry(points, thickness).rotateY(Math.PI / 2);
  const g = mergeGeometries([a, b]);
  g.computeBoundingSphere();
  return g;
}

/** Shared prop kinds: { geometry, material } per resource / decoration type. */
let _kinds = null;
export function propKinds() {
  if (_kinds) return _kinds;
  const pine = pineSilhouette();
  const round = roundTreeSilhouette(4);
  const bush = bushSilhouette(2);
  const roundGeo = crossed(round);
  _kinds = {
    pine: { geometry: crossed(pine), material: cardMaterial(pineArt(pine), { sway: 0.006, snowCap: 0.8 }) },
    'pine~1': (() => { const p = pineSilhouette(1); return { geometry: crossed(p), material: cardMaterial(pineArt(p, 33), { sway: 0.007, snowCap: 0.8 }) }; })(), // (a tall slim pine and a stout old one)
    'pine~2': (() => { const p = pineSilhouette(2); return { geometry: crossed(p), material: cardMaterial(pineArt(p, 47), { sway: 0.005, snowCap: 0.8 }) }; })(),
    maple: { geometry: roundGeo, material: cardMaterial(roundTreeArt(round, 'maple', 3), { sway: 0.007, snowCap: 0.8 }) },
    goldtree: { geometry: roundGeo, material: cardMaterial(roundTreeArt(round, 'gold', 8), { sway: 0.008, snowCap: 0.8 }) },
    appletree: { geometry: roundGeo, material: cardMaterial(roundTreeArt(round, 'apple', 17), { sway: 0.006, snowCap: 0.8 }) },
    satchel: { geometry: crossed(satchelSilhouette(), 0.04), material: cardMaterial(satchelArt(satchelSilhouette()), { sway: 0.01 }) },
    apples: { geometry: crossed(appleHeapSilhouette(), 0.03), material: cardMaterial(appleHeapArt(appleHeapSilhouette())) },
    lodge: { geometry: crossed(lodgeSilhouette(), 0.08), material: cardMaterial(lodgeArt(lodgeSilhouette())) },
    snag: { geometry: crossed(snagSilhouette(), 0.07), material: cardMaterial(snagArt(snagSilhouette())) },
    birch: { geometry: crossed(birchSilhouette(31)), material: cardMaterial(birchArt(birchSilhouette(31)), { sway: 0.009, snowCap: 0.8 }) },
    sagetree: { geometry: roundGeo, material: cardMaterial(roundTreeArt(round, 'sage', 13), { sway: 0.006, snowCap: 0.8 }) },
    bush: { geometry: crossed(bush), material: cardMaterial(bushArt(bush, true, 5), { sway: 0.03 }) },
    'bush~1': (() => { const b = bushSilhouette(9, 4, 0.9); return { geometry: crossed(b), material: cardMaterial(bushArt(b, true, 19), { sway: 0.03 }) }; })(), // (two more cuts of berry bush)
    'bush~2': (() => { const b = bushSilhouette(14, 2, 0.6); return { geometry: crossed(b).scale(1.15, 0.8, 1.15), material: cardMaterial(bushArt(b, true, 27), { sway: 0.03 }) }; })(),
    flowers: { geometry: crossed(wildflowerSilhouette()), material: cardMaterial(wildflowerArt(wildflowerSilhouette()), { sway: 0.05 }) },
    'flowers~1': (() => { const p = wildflowerSilhouette(BLOOMS_SUSAN); return { geometry: crossed(p), material: cardMaterial(wildflowerArt(p, 14, BLOOMS_SUSAN), { sway: 0.05 }) }; })(), // (a patch of Susans, and a tall clump of coneflowers)
    'flowers~2': (() => { const p = wildflowerSilhouette(BLOOMS_CONE); return { geometry: crossed(p), material: cardMaterial(wildflowerArt(p, 22, BLOOMS_CONE), { sway: 0.05 }) }; })(), // coneflowers, black-eyed Susans and asters on their own stems
    rock: rockOutcrop(),
    'rock~1': rockOutcrop(rockArt, 1), // (two more cuts of rock, so a field of them isn't one stamp repeated)
    'rock~2': rockOutcrop(rockArt, 2),
    log: fallenLog(),
    ore: rockOutcrop(oreArt),
    quartz: rockOutcrop(quartzArt), // gold-bearing quartz
    // the wild lands' treasures
    silver: rockOutcrop(silverArt),
    sang: { geometry: crossed(sangSilhouette(), 0.03), material: cardMaterial(sangArt(sangSilhouette()), { sway: 0.04 }) },
    geode: { geometry: crossed(geodeSilhouette(), 0.06), material: cardMaterial(geodeArt(geodeSilhouette())) },
    pearl: { geometry: crossed(musselSilhouette(), 0.04), material: cardMaterial(musselArt(musselSilhouette())) },
    amber: { geometry: crossed(amberSilhouette(), 0.06), material: cardMaterial(amberArt(amberSilhouette())) },
    clay: { geometry: crossed(bush.map(([x, y]) => [x * 0.9, y * 0.55])), material: cardMaterial(clayArt(bush.map(([x, y]) => [x * 0.9, y * 0.55]))) },
    mushroom: { geometry: crossed(toadstoolSilhouette(), 0.04), material: cardMaterial(toadstoolArt(toadstoolSilhouette())) },
    hive: { geometry: crossed(hiveSilhouette(), 0.05), material: cardMaterial(hiveArt(hiveSilhouette())) },
    bale: { geometry: crossed(baleSilhouette(), 0.05), material: cardMaterial(baleArt(baleSilhouette())) },
    stook: { geometry: crossed(stookSilhouette(), 0.03), material: cardMaterial(stookArt(stookSilhouette()), { sway: 0.02 }) },
    cattail: { geometry: crossed(cattailSilhouette(), 0.03), material: cardMaterial(cattailArt(cattailSilhouette()), { sway: 0.05 }) },
    lilypad: { geometry: cardGeometry(lilypadSilhouette(), 0.02).rotateX(-Math.PI / 2), material: cardMaterial(lilypadArt(lilypadSilhouette(), false)) },
    lilybloom: { geometry: cardGeometry(lilypadSilhouette(), 0.02).rotateX(-Math.PI / 2), material: cardMaterial(lilypadArt(lilypadSilhouette(), true, 107)) },
    corn: { geometry: crossed(cornSilhouette(), 0.04), material: cardMaterial(cornArt(cornSilhouette()), { sway: 0.03 }) },
    pumpkin: { geometry: crossed(pumpkinSilhouette(), 0.04), material: cardMaterial(pumpkinArt(pumpkinSilhouette())) },
    signvein: { geometry: cardGeometry(signSilhouette(), 0.07, [0, 0.4]), material: cardMaterial(signArt(signSilhouette(), 'vein')) },
    signthicket: { geometry: cardGeometry(signSilhouette(), 0.07, [0, 0.4]), material: cardMaterial(signArt(signSilhouette(), 'thicket', 97)) },
    signgrove: { geometry: cardGeometry(signSilhouette(), 0.07, [0, 0.4]), material: cardMaterial(signArt(signSilhouette(), 'grove', 93)) },
    grass: { geometry: crossed(grassSilhouette(3), 0.03), material: cardMaterial(grassArt(grassSilhouette(3)), { sway: 0.09 }) },
    hill: { geometry: sail(hillSilhouette(7)), material: cardMaterial(hillArt(hillSilhouette(7))) },
    peak: { geometry: sail(hillSilhouette(9, 11, 6.5)), material: cardMaterial(peakArt(hillSilhouette(9, 11, 6.5))) },
  };
  return _kinds;
}

/**
 * A fallen log, wilderness-floor dressing: a rolled bark tube with its two end-grain faces, a torn sheet of
 * moss laid over its back, tiers of tan shelf fungus on one flank and a crossed fern card at its foot.
 * One geometry and one material: every part samples its own corner of a single painted atlas.
 */
function fallenLog() {
  const W = 512, c = document.createElement('canvas'); c.width = c.height = W;
  const g = c.getContext('2d'), rng = mulberry32(613);
  // bark (left half): deep brown, long split furrows, lichen flecks
  g.fillStyle = '#6a4a32'; g.fillRect(0, 0, W / 2, W);
  for (let i = 0; i < 26; i++) { g.strokeStyle = i % 3 ? 'rgba(40,26,18,0.55)' : 'rgba(150,118,84,0.45)'; g.lineWidth = 3 + rng() * 3; const x0 = rng() * W / 2; g.beginPath(); g.moveTo(x0, 0); for (let y = 0; y <= W; y += 32) g.lineTo(x0 + (rng() - 0.5) * 8, y); g.stroke(); } // furrows run the length of the log
  for (let i = 0; i < 40; i++) { g.fillStyle = rng() < 0.5 ? 'rgba(180,196,150,0.7)' : 'rgba(214,206,170,0.6)'; g.beginPath(); g.arc(rng() * W / 2, rng() * W, 3 + rng() * 5, 0, Math.PI * 2); g.fill(); }
  // end grain (top right quarter): pale rings, a rot-dark heart, bark rim
  { const cx = W * 0.625, cy = W * 0.125, R = W * 0.12;
    g.fillStyle = '#d8b884'; g.beginPath(); g.arc(cx, cy, R, 0, Math.PI * 2); g.fill();
    g.strokeStyle = 'rgba(140,96,52,0.6)'; g.lineWidth = 2.5; for (let r = 8; r < R - 6; r += 9) { g.beginPath(); g.arc(cx + 2, cy, r, 0, Math.PI * 2); g.stroke(); }
    g.fillStyle = '#7a5434'; g.beginPath(); g.arc(cx + 3, cy + 2, R * 0.2, 0, Math.PI * 2); g.fill();
    g.strokeStyle = '#5a3c26'; g.lineWidth = 9; g.beginPath(); g.arc(cx, cy, R - 4, 0, Math.PI * 2); g.stroke(); }
  // moss (right half, middle band): mottled greens with paler tufts
  g.fillStyle = '#5f7d3c'; g.fillRect(W / 2, W * 0.25, W / 2, W * 0.25);
  for (let i = 0; i < 70; i++) { g.fillStyle = ['#7e9c4c', '#4d6a30', '#9bb062'][i % 3]; g.beginPath(); g.arc(W / 2 + rng() * W / 2, W * 0.25 + rng() * W * 0.25, 4 + rng() * 7, 0, Math.PI * 2); g.fill(); }
  // shelf fungus (bottom right quarter, left part): tan with cream growth bands
  g.fillStyle = '#c99a5c'; g.fillRect(W / 2, W / 2, W / 4, W / 2);
  g.strokeStyle = 'rgba(244,228,190,0.8)'; g.lineWidth = 6; for (let k = 1; k < 5; k++) { g.beginPath(); g.ellipse(W * 0.625, W, W * 0.11 * k / 4 + 8, W * 0.4 * k / 4 + 8, 0, Math.PI, Math.PI * 2); g.stroke(); }
  // fern (bottom right quarter, right part): a sage frond on green
  g.fillStyle = '#5c8040'; g.fillRect(W * 0.75, W / 2, W / 4, W / 2);
  g.strokeStyle = '#3e5a2a'; g.lineWidth = 4; g.beginPath(); g.moveTo(W * 0.875, W); g.lineTo(W * 0.875, W * 0.52); g.stroke();
  for (let y = W * 0.56; y < W * 0.98; y += 18) { g.strokeStyle = '#8fb060'; g.lineWidth = 5; g.beginPath(); g.moveTo(W * 0.875, y); g.lineTo(W * 0.8, y - 10); g.moveTo(W * 0.875, y); g.lineTo(W * 0.95, y - 10); g.stroke(); }
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;

  const into = (geo, u0, v0, u1, v1) => { // squeeze a part's 0..1 uvs into its corner of the atlas (v up)
    const uv = geo.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, u0 + uv.getX(i) * (u1 - u0), v0 + uv.getY(i) * (v1 - v0));
    return geo.index ? geo.toNonIndexed() : geo;
  };
  const L = 2.6, R = 0.3;
  const bark = into(new THREE.CylinderGeometry(R, R * 1.08, L, 9, 1, true).rotateZ(Math.PI / 2).translate(0, R * 0.85, 0), 0, 0, 0.5, 1);
  const ends = [-1, 1].map((sx) => into(new THREE.CircleGeometry(sx > 0 ? R : R * 1.08, 9).rotateY(sx * Math.PI / 2).translate(sx * L / 2, R * 0.85, 0), 0.5, 0.75, 0.75, 1));
  // the moss: a torn sheet draped over the top of the log
  const mossPts = []; for (let i = 0; i <= 10; i++) mossPts.push([-L * 0.42 + (i / 10) * L * 0.8, 0.02 * Math.sin(i * 2.1)]);
  for (let i = 10; i >= 0; i--) mossPts.push([-L * 0.42 + (i / 10) * L * 0.8, 0.5 + (i % 2) * 0.08]);
  const moss = into(cardGeometry(mossPts, 0.02).rotateX(-Math.PI / 2).translate(0, 0, -0.25), 0.5, 0.5, 1, 0.75);
  { const pos = moss.attributes.position; for (let i = 0; i < pos.count; i++) { const zz = pos.getZ(i); pos.setY(i, pos.getY(i) + R * 0.85 + Math.sqrt(Math.max(0, R * R - zz * zz)) * 1.02 + 0.01); } }
  // shelf fungus: three half-moon brackets stepping along the south flank
  const shelf = (w) => { const pts = []; for (let i = 0; i <= 8; i++) { const a = Math.PI * (i / 8); pts.push([Math.cos(a) * w, Math.sin(a) * w * 0.55]); } return pts; };
  const fungi = [[0.6, 0.62, 0.2], [0.85, 0.42, 0.15], [-0.4, 0.55, 0.13]].map(([x, y, w]) => into(cardGeometry(shelf(w), 0.03).rotateX(-Math.PI / 2).translate(x, y, R + 0.02), 0.5, 0, 0.75, 0.5));
  // a fern at its foot: two crossed fronds
  const frond = [[-0.03, 0], [0.03, 0], [0.22, 0.25], [0.18, 0.5], [0.06, 0.72], [0, 0.78], [-0.06, 0.72], [-0.18, 0.5], [-0.22, 0.25]];
  const ferns = [0, Math.PI / 2].map((r) => into(cardGeometry(frond, 0.02).rotateY(r).rotateZ(-0.3).translate(-L / 2 - 0.15, 0, 0.25), 0.75, 0, 1, 0.5));
  const parts = [bark, ...ends, moss, ...fungi, ...ferns].map((q) => { for (const k of Object.keys(q.attributes)) if (!['position', 'normal', 'uv'].includes(k)) q.deleteAttribute(k); return q; });
  const geo = mergeGeometries(parts);
  geo.computeVertexNormals(); geo.computeBoundingSphere();
  return { geometry: geo, material: cardMaterial(tex, { side: THREE.DoubleSide }) };
}

/** A hill sail: one stiff card, a little thicker than a prop card. */
function sail(points) {
  const g = cardGeometry(points, 0.1);
  g.computeBoundingSphere();
  return g;
}

/**
 * Rock outcrop, folded-paper style: 3 chunky slab cards leaning into each other at different angles,
 * each printed with a lit face and a darker folded facet (no low-poly boulder).
 */
function rockOutcrop(artFn = rockArt, cut = 0) {
  if (cut === 1) { // a tall split crag: two narrow slabs shouldering up together, a chip leaning at their foot
    const pts = rockSilhouette(17);
    const g = mergeGeometries([
      cardGeometry(pts, 0.07).scale(0.75, 1.35, 1).rotateZ(0.08).rotateY(0.5).translate(-0.15, 0, 0),
      cardGeometry(rockSilhouette(23), 0.07).scale(0.6, 1.1, 1).rotateZ(-0.14).rotateY(2.0).translate(0.25, 0, -0.15),
      cardGeometry(rockSilhouette(29), 0.07).scale(0.55, 0.45, 1).rotateZ(0.35).rotateY(3.6).translate(0.15, 0, 0.35),
    ]);
    g.computeBoundingSphere();
    return { geometry: g, material: cardMaterial(artFn(pts, 67)) };
  }
  if (cut === 2) { // a low ledge: four flat slabs stepped along the ground like a broken loaf
    const pts = rockSilhouette(37);
    const g = mergeGeometries([
      cardGeometry(pts, 0.07).scale(1.25, 0.55, 1).rotateZ(-0.05).rotateY(0.1).translate(-0.2, 0, 0.1),
      cardGeometry(rockSilhouette(41), 0.07).scale(1.0, 0.7, 1).rotateZ(0.1).rotateY(1.75).translate(0.45, 0, -0.1),
      cardGeometry(rockSilhouette(43), 0.07).scale(0.9, 0.42, 1).rotateZ(-0.12).rotateY(3.3).translate(-0.55, 0, -0.25),
      cardGeometry(rockSilhouette(47), 0.07).scale(0.5, 0.35, 1).rotateZ(0.25).rotateY(0.9).translate(0.6, 0, 0.35),
    ]);
    g.computeBoundingSphere();
    return { geometry: g, material: cardMaterial(artFn(pts, 73)) };
  }
  const pts = rockSilhouette(5);
  const parts = [
    cardGeometry(pts, 0.07).rotateZ(-0.12).rotateY(0.2).translate(-0.1, 0, 0.15),
    cardGeometry(rockSilhouette(8), 0.07).scale(0.8, 0.75, 1).rotateZ(0.18).rotateY(2.2).translate(0.35, 0, -0.1),
    cardGeometry(rockSilhouette(11), 0.07).scale(0.7, 0.6, 1).rotateZ(-0.2).rotateY(4.1).translate(-0.3, 0, -0.3),
  ];
  const g = mergeGeometries(parts);
  g.computeBoundingSphere();
  return { geometry: g, material: cardMaterial(artFn(pts)) };
}
