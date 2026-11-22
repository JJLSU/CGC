// Paper materials in TSL. Everything is dead-matte card: a Lambert (diffuse-only) model, no specular,
// no reflections, with paper fibre fixed to the surface at two non-integer scales so the repeat never lines up.
//  - paperMaterial: solid-colour paper (box folds, posts, the hero)
//  - cardMaterial: printed die-cut cards (art painted on canvases in textures.js)
//  - groundMaterial: the printed page. Region washes with torn edges, paths, fields, water, grass marks.
import * as THREE from 'three/webgpu';
import {
  Fn, float, vec2, vec3, materialColor, positionWorld, normalWorld, uv, texture, fract, smoothstep, clamp,
  mix, sin, cos, time, bumpMap, abs, floor, length, dot, mx_noise_float, mx_cell_noise_float, color, uniform, luminance,
  positionLocal, instanceIndex, attribute, cross, max, step,
} from 'three/tsl';
import { paperFiberTexture, washTexture, handmadePaperTexture, noiseTexture } from './textures.js';

let _tex = null;
export function sharedTextures() {
  return (_tex ||= { fiber: paperFiberTexture(), wash: washTexture(), handmade: handmadePaperTexture(), noise: noiseTexture() });
}

/** 0.5-centred paper fibre at a uv. */
const fiberAt = (uvNode) => texture(sharedTextures().fiber, uvNode).r;
/** Two-scale fibre (×1 and ×3.73 with an offset), so tiling never lines up. */
const fiber2 = (uvNode) => fiberAt(uvNode).mul(0.6).add(fiberAt(uvNode.mul(3.73).add(vec2(0.37, 0.61))).mul(0.4));
/** Watercolour bloom value (1 = clean, lower = pigment). */
const washAt = (uvNode) => texture(sharedTextures().wash, uvNode).r;

/** World-space planar projection picked by the facet normal (cheap triplanar). */
function worldPlanar(fn, scale) {
  const p = positionWorld.mul(scale);
  const n = abs(normalWorld);
  const top = fn(p.xz), side = mix(fn(p.zy), fn(p.xy), smoothstep(0.3, 0.7, n.z));
  return mix(side, top, smoothstep(0.45, 0.75, n.y));
}

/** Handmade-paper luminance around 1.0 (pulp clouds, fibres, inclusions). */
const handLum = (u) => luminance(texture(sharedTextures().handmade, u).rgb).div(0.79);

/** Multiplicative paper tone for solid-colour paper: handmade sheet + a little fine fibre. */
export const paperTone = Fn(() => worldPlanar(handLum, 0.55).mul(0.75).add(0.25).add(worldPlanar(fiber2, 0.9).sub(0.5).mul(0.12)));

/** Solid-colour paper (uses material.color and vertex/instance colours). Diffuse only. */
export function paperMaterial(params = {}) {
  const { roughness, metalness, ...rest } = params;
  const m = new THREE.MeshLambertNodeMaterial(rest);
  m.colorNode = mix(vec3(materialColor).mul(paperTone()), color(0xf3f0e8).mul(paperTone()), uSnow.mul(smoothstep(0.5, 0.85, normalWorld.y)));
  m.normalNode = bumpMap(worldPlanar(fiberAt, 0.9), 0.1);
  return m;
}

/** Printed card: painted canvas `map` × two-scale fibre. Side walls sample the darkened edge chip.
 *  `sway` (instanced props only): wind bend at the top in metres per metre² of height. */
/**
 * Turn a print's hue by `a` radians (about the grey axis), but not on skin, nor on browns (hair, leather, boots,
 * wood): those keep their own colour, so a re-dyed coat never comes with green hair or a blue face.
 */
function tintClothes(c, a) {
  const k = vec3(0.57735, 0.57735, 0.57735), ca = Math.cos(a), sa = Math.sin(a);
  const spun = c.mul(ca).add(cross(k, c).mul(sa)).add(k.mul(dot(k, c)).mul(1 - ca));
  const turned = mix(spun, vec3(dot(spun, vec3(0.299, 0.587, 0.114))), 0.32); // (a little greyed, so a re-dyed dress stays a muted, papery colour)
  const r = c.x, g = c.y, b = c.z, chroma = r.sub(b), gpos = g.sub(b).div(max(chroma, 0.001));
  const warm = step(g, r).mul(step(b, g)); // (red >= green >= blue: skin and the browns)
  // (skin, hair, leather and tan cloth are all warm orange-to-tan: red above green above blue, green partway between)
  const keep = warm.mul(smoothstep(0.06, 0.16, gpos)).mul(float(1).sub(smoothstep(0.85, 0.95, gpos))).mul(smoothstep(0.02, 0.06, chroma)); // (every warm skin-like tone keeps its colour, lit or shaded: skin is never re-dyed)
  return mix(turned, c, clamp(keep, 0, 1));
}

export function cardMaterial(map, params = {}) {
  const { roughness, metalness, sway = 0, paperScale = 1, pulp = 0.55, hue = 0, snow = true, snowCap = 0, ...rest } = params; // snow: false for folk and beasts (no snowdrift on a man's shoulders or a cow's back) // hue: radians to turn the print's colours (a figure's clothes), sparing skin, hair and leather // paperScale: finer grain for packed (atlas) textures; pulp: how much the sheet's pulp clouds show through
  const m = new THREE.MeshLambertNodeMaterial(rest);
  if (sway) {
    // idle wind: each card bends about its own base (~0.5–2.5°, 0.4–0.8 Hz), phase per instance
    const ph = fract(sin(float(instanceIndex).mul(12.9898)).mul(43758.5453));
    const w = time.mul(ph.mul(1.6).add(2.6)).add(ph.mul(6.283));
    const gust = sin(time.mul(0.23).add(ph.mul(3.0))).mul(0.35).add(0.75);
    const y2 = positionLocal.y.mul(positionLocal.y).mul(sway).mul(gust);
    m.positionNode = positionLocal.add(vec3(sin(w).mul(y2), 0, cos(w.mul(0.83)).mul(y2).mul(0.6)));
  }
  const fib = fiber2(uv().mul(2.4 * paperScale));
  // printed art on handmade stock: the sheet's pulp and fibres show through the ink
  const hand = texture(sharedTextures().handmade, uv().mul(1.3 * paperScale)).rgb.div(vec3(0.84, 0.78, 0.65));
  let base = texture(map, uv()).rgb;
  if (hue) base = tintClothes(base, hue);
  const ink = base.mul(mix(vec3(1), hand, pulp)).mul(float(1).add(fib.sub(0.5).mul(0.14)));
  m.inkNode = ink; // (for a model's soft self-fill, so it follows the tint)
  // snow settles on whatever faces the sky (roofs, ledges, the tops of rocks)
  const snowK = snow === true ? 1 : snow === false ? 0 : snow; // (a number for part cover: a trodden street keeps its ruts through the snow)
  m.colorNode = snowK ? mix(ink, color(0xf3f0e8).mul(mix(vec3(1), hand, 0.3)), uSnow.mul(snowK).mul(smoothstep(0.5, 0.85, normalWorld.y))) : ink;
  // a tree's crown takes a cap of snow: the top of the card (above snowCap of its height, along a ragged line from the
  // paper's own fibres) goes white as the snow comes, so the woods look snowed on and not just the ground
  if (snowCap) m.colorNode = mix(m.colorNode, color(0xf3f0e8).mul(mix(vec3(1), hand, 0.3)), uSnow.mul(smoothstep(snowCap, snowCap + 0.06, uv().y.add(fib.sub(0.5).mul(0.12)))));
  m.normalNode = bumpMap(luminance(hand).mul(0.6).add(fib.mul(0.4)), 0.12 * Math.min(1, pulp / 0.55));
  return m;
}

// TSL color() constants (vec3(new Color()) constants turned black when mixed together on WebGPU)
const C = (h) => color(h);

/** Direction toward the key light (kept up to date by sky.js): torn sheet edges cast shadows away from it. */
export const uKeyDir = uniform(new THREE.Vector3(-0.5, 0.7, 0.5));
/** 0 … 1: how much snow lies on the land and on anything facing up (set by the weather). */
export const uSnow = uniform(0);
/** 0..1: how frozen the ponds are (they ice over while snow lies thick, and thaw after). */
export const uIce = uniform(0);
/** 0 … 1: how strongly drifting cloud shadows show on the land (fair days by day; set by the sky). */
export const uCloudShade = uniform(0);

/**
 * The page, built as layered torn handmade paper. Each region is its own dyed sheet laid over the one
 * below (water → land → meadow → forest → crop fields → highland → footpaths). Every sheet's edge is
 * torn: a ragged line from three scales of noise, a pale fibrous core along the tear, loose fibres poking
 * past it, and a short soft shadow cast away from the key light onto the sheet underneath. Fallen
 * leaves drift under the woods; the paper itself shows pulp clouds, fibres and inclusions.
 */
export function groundMaterial(mapTex, { waterT, highT, peakT, landTex }) {
  const m = new THREE.MeshLambertNodeMaterial();
  const MAPN = float(mapTex.image.width);
  const { handmade, noise } = sharedTextures();
  const nz = (u) => texture(noise, u);
  m.colorNode = Fn(() => {
    const p = positionWorld.xz;
    // shadow vector: away from the light, ~14 cm
    const sv = uKeyDir.xz.normalize().negate().mul(0.14);
    const ps = p.sub(sv);
    const sA = texture(mapTex, p.add(0.5).div(MAPN));
    const sB = texture(mapTex, ps.add(0.5).div(MAPN));
    const tearAt = (q) => {
      const a = nz(q.mul(0.011)), b = nz(q.mul(0.047)), c = nz(q.mul(0.33));
      return a.r.sub(0.5).mul(0.9).add(b.g.sub(0.5).mul(0.45)).add(c.b.sub(0.5).mul(0.22));
    };
    const tA = tearAt(p), tB = tearAt(ps);
    const fine = nz(p.mul(1.7)).b;

    /** One torn sheet: inside mask, fibrous rim, loose fibres, and the shadow it casts at p. */
    const sheet = (vA, vB, thr, amp, width) => {
      const dA = vA.add(tA.mul(amp)).sub(thr), dB = vB.add(tB.mul(amp)).sub(thr);
      const inside = smoothstep(width.mul(-0.08), width.mul(0.08), dA);
      const rimW = width.mul(fine.mul(0.9).add(0.5));
      const rim = inside.mul(float(1).sub(smoothstep(rimW.mul(0.35), rimW, dA)));
      const hairs = float(1).sub(inside).mul(smoothstep(0.66, 0.74, fine)).mul(float(1).sub(smoothstep(0, rimW.mul(0.7), dA.negate())));
      const shadow = smoothstep(width.mul(-0.4), width.mul(0.4), dB).mul(float(1).sub(inside));
      return { inside, rim: rim.max(hairs), shadow };
    };

    const hA = sA.r, hB = sB.r;
    // water is the bottom sheet (y = 0) of the stacked terrain; the backdrop plane (kind 3) is always land
    const kindA = attribute('kind', 'float');
    const landMask = kindA.greaterThan(2.5).select(float(1), smoothstep(0.2, 0.35, positionWorld.y));
    // the bank's torn edge: a ragged band of pale paper core just where the land sheet meets the water
    const bankY = positionWorld.y.add(fine.sub(0.5).mul(0.06));
    const bankRim = kindA.greaterThan(2.5).select(float(0), smoothstep(0.17, 0.21, bankY).mul(float(1).sub(smoothstep(0.23, 0.28, bankY))));
    const water = { inside: landMask, rim: bankRim, shadow: float(0) };
    const onLand = (sh) => ({ inside: sh.inside.mul(landMask), rim: sh.rim.mul(landMask), shadow: sh.shadow.mul(landMask) }); // nothing is printed over the water
    const forest = onLand(sheet(sA.b, sB.b, 0.515, 0.09, float(0.02)));     // forest sheet over meadow
    const field = onLand(sheet(sA.a, sB.a, 0.5, 0.35, float(0.06)));        // crop-field sheets
    const highl = onLand(sheet(hA, hB, highT, 0.03, float(0.006)));
    const peak = onLand(sheet(hA, hB, peakT, 0.03, float(0.006)));
    const path = sheet(sA.g.mul(-1), sB.g.mul(-1), -0.14, 0.06, float(0.012)); // inside where path value is small

    // --- sheets, bottom to top
    const ripple = fract(nz(p.mul(0.055).add(time.mul(0.004))).r.mul(7)).sub(0.5).abs();
    const strokes = smoothstep(0.56, 0.66, nz(p.mul(0.21).add(vec2(0.37, 0.11))).g); // broken into short painted strokes
    // water, authored a step bluer than it should read: the warm grade turns pale teal into khaki
    const depth = smoothstep(waterT, waterT - 0.05, hA);
    let col = mix(C(0x78a8bc), C(0x3d7896), depth);
    // painted ripple lines: pale wavy strokes on the open water
    col = mix(col, C(0xd6e6e8), float(1).sub(smoothstep(0.01, 0.03, ripple)).mul(strokes).mul(0.34).mul(depth.mul(0.5).add(0.5)));
    // the bank is a sheet lying on the water: it casts a soft shadow just off its edge
    // ice: on a snow day the ponds freeze to a pale blue-white sheet, scored with skate tracks and a few cracks
    const skate = float(1).sub(smoothstep(0.004, 0.012, fract(nz(p.mul(0.09).add(vec2(0.2, 0.6))).r.mul(5)).sub(0.5).abs()));
    const crack = float(1).sub(smoothstep(0.003, 0.01, fract(nz(p.mul(0.03).add(vec2(0.7, 0.1))).g.mul(4)).sub(0.5).abs())).mul(smoothstep(0.55, 0.7, nz(p.mul(0.05)).b));
    const iceCol = mix(C(0x8fb8d0), C(0xb8d6e4), fine.mul(0.6).add(nz(p.mul(0.012)).r.mul(0.4))).mul(float(1).sub(crack.mul(0.35))).add(vec3(skate.mul(0.18)));
    col = mix(col, iceCol, uIce.mul(float(1).sub(landMask)));
    const bankShade = smoothstep(waterT - 0.035, waterT + 0.005, hB).mul(float(1).sub(landMask));
    col = col.mul(float(1).sub(bankShade.mul(0.32)));
    col = mix(col, C(0xc8c6a6), water.inside);                                  // meadow sheet
    const leafy = mix(col, C(0xaeb28e), forest.inside);
    col = mix(leafy.mul(float(1).sub(forest.shadow.mul(0.22))), leafy, forest.inside); // forest sheet + its shadow
    // crop field: stubble rows printed on its own sheet
    // a patchwork of fields: each patch (a ~40 m cell of low noise) is golden wheat, fresh-ploughed earth or mown
    // hay, with its rows run its own way, the way a county looks from the hill road
    const fpick = nz(p.mul(0.0045).add(vec2(0.13, 0.71))).g.add(tA.mul(0.025)); // torn borders between patches
    const fang = nz(p.mul(0.0045).add(vec2(0.53, 0.29))).r.mul(6.283);
    const fdir = vec2(cos(fang), sin(fang));
    const along = dot(p, fdir);
    const wobble = nz(p.mul(0.08)).b.sub(0.5).mul(0.6);                      // rows drawn by hand, not ruled
    const rowWave = sin(along.add(wobble).mul(3.4));
    const isWheat = smoothstep(0.446, 0.454, fpick).mul(float(1).sub(smoothstep(0.621, 0.629, fpick)));
    const isPlough = smoothstep(0.621, 0.629, fpick);
    const patchRim = float(1).sub(smoothstep(0.003, 0.009, abs(fpick.sub(0.45)))).max(float(1).sub(smoothstep(0.003, 0.009, abs(fpick.sub(0.625)))));
    const isHay = float(1).sub(isWheat).sub(isPlough).max(0);
    // wheat: gold with darker drill rows and pale glints of the heads
    const wheat = mix(C(0xbfa86e), C(0x9a8150), smoothstep(0.55, 0.95, rowWave)).mul(float(1).add(smoothstep(0.8, 0.95, fine).mul(0.12)));
    // ploughed: brown furrows, each with a lit ridge and a shadowed trough
    const plough = mix(mix(C(0x8a6448), C(0x5e4130), smoothstep(-0.2, 0.7, rowWave)), C(0xa8805c), smoothstep(0.7, 0.95, rowWave.negate()).mul(0.6));
    // hay: mown sage swathes, alternating light and dark where the mower turned
    const swath = sin(along.add(wobble).mul(0.55));
    const hay = mix(C(0x9aa070), C(0x7e8a5a), smoothstep(-0.15, 0.15, swath)).mul(float(1).sub(smoothstep(0.6, 0.95, rowWave).mul(0.06)));
    const fieldCol = mix(wheat.mul(isWheat).add(plough.mul(isPlough)).add(hay.mul(isHay)), C(0xf3ead6), patchRim.mul(0.75));
    col = col.mul(float(1).sub(field.shadow.mul(0.22)));
    col = mix(col, fieldCol, field.inside);
    col = col.mul(float(1).sub(highl.shadow.mul(0.2)));
    col = mix(col, C(0xc4bdaa), highl.inside);
    col = mix(col, C(0xd9d6cf), peak.inside);
    // the great ranges: plain handmade paper dyed a cold blue, deep at the foot and paling up the slope, then white
    // snow above a torn, ragged snow line (no lines or strata: the paper's own fibre and wash do the texture)
    const yW = positionWorld.y.add(nz(p.mul(0.045)).r.sub(0.5).mul(5)).add(nz(p.mul(0.16)).g.sub(0.5).mul(2.2));
    let mcol = mix(C(0x56689a), C(0x9caccc), smoothstep(4, 21, yW));
    mcol = mix(mcol, C(0xf4f6fa), smoothstep(22.5, 24, yW));
    mcol = mcol.mul(float(0.94).add(fine.mul(0.1)));
    col = mix(col, mcol, peak.inside.mul(smoothstep(2.5, 6, positionWorld.y))); // (from the very foot of the slopes)

    // grass marks + fallen leaves in drifts (on meadow / forest only)
    const cellP = p.mul(0.9);
    const cell = floor(cellP);
    const jx = mx_cell_noise_float(vec3(cell, 1.0)), jy = mx_cell_noise_float(vec3(cell, 2.0));
    const local = fract(cellP).sub(vec2(jx, jy).mul(0.6).add(0.2));
    const pick = mx_cell_noise_float(vec3(cell, 3.0));
    const ang = pick.mul(6.283);
    const rl = vec2(local.x.mul(cos(ang)).sub(local.y.mul(sin(ang))), local.x.mul(sin(ang)).add(local.y.mul(cos(ang))));
    const leaf = float(1).sub(smoothstep(0.85, 1.0, length(rl.mul(vec2(4.2, 8.5)))));
    const grass = float(1).sub(smoothstep(0.05, 0.08, length(local.mul(vec2(1.0, 0.45)))));
    const drift = smoothstep(0.5, 0.66, nz(p.mul(0.04)).r).mul(smoothstep(0.3, 0.6, pick.add(nz(p.mul(0.2)).g.sub(0.5))));
    const onGreen = water.inside.mul(float(1).sub(field.inside)).mul(float(1).sub(highl.inside));
    const leafCol = mix(mix(C(0xc8642f), C(0xb3402c), smoothstep(0.3, 0.6, pick)), C(0xd9a441), smoothstep(0.6, 0.9, pick));
    const leafOn = leaf.mul(drift).mul(onGreen).mul(smoothstep(0.35, 0.55, sA.b));
    col = mix(col, C(0x8e9862), grass.mul(float(1).sub(drift)).mul(onGreen).mul(0.55));
    col = mix(col.mul(float(1).sub(leafOn.mul(0.15))), leafCol, leafOn.mul(0.9));

    // footpath: a torn cream strip on top of everything, with its shadow
    // paths only on land: never printed across water you can't walk on
    col = col.mul(float(1).sub(path.shadow.mul(0.25).mul(landMask)));
    col = mix(col, C(0xefe3c4), path.inside.mul(landMask));

    // torn fibrous cores along every tear (the pale inside of the paper shows)
    const core = C(0xf8f2e2);
    const rims = water.rim.max(forest.rim.mul(0.85)).max(field.rim).max(highl.rim).max(path.rim.mul(landMask));
    col = mix(col, core, rims.mul(0.9));

    // handmade paper: pulp, fibres, inclusions (two scales so the tile never lines up)
    const hp1 = texture(handmade, p.mul(0.21)).rgb, hp2 = texture(handmade, p.mul(0.067).add(vec2(0.31, 0.57))).rgb;
    const cream = vec3(0.84, 0.78, 0.65); // linear mean of the handmade sheet
    const tint = hp1.div(cream).mul(0.6).add(hp2.div(cream).mul(0.4));
    col = col.mul(mix(vec3(1), tint, 0.85));
    // broad watercolour unevenness in the dye
    col = col.mul(mix(0.9, 1.04, washAt(p.mul(0.017))));
    // Printed contour layers: every 0.6 m of height reads as the torn edge of another sheet of paper,
    // with a white fibrous lip just above the line and a soft shadow just below the next one.
    const ny = normalWorld.y.max(0.25);
    const slope = ny.mul(ny).oneMinus().max(0).sqrt().div(ny);           // rise per metre
    // on the great ranges the sheets turn into rock strata: tilted (each mountain its own way), gently folded and
    // wider apart, so a mountainside reads as upturned layers of rock rather than a stack of level stripes
    const mtnK = peak.inside.mul(smoothstep(4, 8, positionWorld.y));
    const tiltA = nz(p.mul(0.0045).add(vec2(0.31, 0.77))).r.mul(9.4);
    const tiltD = vec2(cos(tiltA), sin(tiltA));
    const strata = dot(p, tiltD).mul(0.55).add(sin(dot(p, vec2(tiltD.y.negate(), tiltD.x)).mul(0.07)).mul(3.5));
    const band = mix(float(0.6), float(2.2), mtnK);                      // (sheet spacing: 0.6 m in the valleys)
    const yT = positionWorld.y.add(strata.mul(mtnK)).add(nz(p.mul(0.35)).b.sub(0.5).mul(mix(0.16, 0.9, mtnK))).add(nz(p.mul(1.9)).b.sub(0.5).mul(0.05));
    const fL = fract(yT.div(band)).mul(band);                             // height above the last line
    const onHill = landMask.mul(smoothstep(0.25, 0.4, positionWorld.y)).mul(smoothstep(0.02, 0.08, slope)).mul(float(1).sub(mtnK)); // (no sheet lines up the mountains)
    const lipH = slope.mul(0.07).add(0.004);
    const lipC = float(1).sub(smoothstep(lipH.mul(0.45), lipH, fL)).mul(onHill);
    const shadeH = slope.mul(0.4).add(0.01);
    const shadeC = smoothstep(band.sub(shadeH), band, fL).mul(onHill);
    col = col.mul(float(1).sub(shadeC.mul(0.2)));
    col = mix(col, C(0xfbf6ea).mul(mix(vec3(1), tint, 0.4)), lipC.mul(0.9));

    // the terrain sheets' own paper: cream walls (darker toward the foot, fibrous) and a white torn lip
    const isWall = kindA.greaterThan(0.5).and(kindA.lessThan(1.5));
    const isLip = kindA.greaterThan(1.5).and(kindA.lessThan(2.5));
    const f = fract(positionWorld.y.div(0.6).sub(0.002));
    const wallTex = texture(handmade, vec2(positionWorld.x.add(positionWorld.z).mul(0.3), positionWorld.y.mul(0.3))).rgb.div(cream);
    const wallCol = mix(C(0xc9b996), C(0xf1e7d0), smoothstep(0.0, 0.9, f)).mul(wallTex);
    const lipCol = C(0xfbf6ea).mul(mix(vec3(1), tint, 0.4)).mul(float(0.94).add(fine.mul(0.08)));
    // snow: a patchy white blanket over the land (never the water), thinnest where the paper fibres show through
    // cloud shadows: big soft blots of shade drifting slowly across the fields with the wind
    const cp = positionWorld.xz.mul(0.02).add(vec2(time.mul(0.016), time.mul(0.006))); // ~0.8 m/s drift
    const cn = mx_noise_float(vec3(cp.x, cp.y, 0.0)).mul(0.7).add(mx_noise_float(vec3(cp.x.mul(2.1), cp.y.mul(2.1), 3.7)).mul(0.3));
    const blot = smoothstep(0.08, 0.32, cn);
    col = col.mul(float(1).sub(blot.mul(uCloudShade).mul(0.18)));
    const snowAmt = smoothstep(0.0, 0.3, uSnow.mul(1.3).sub(fine.mul(0.35)).sub(0.08)).mul(landMask);
    col = mix(col, C(0xf3f0e8).mul(mix(vec3(1), tint, 0.25)), snowAmt);
    // the footpaths stay trodden through it: a churned tan of slush and boot-prints along each lane, so the ways
    // across the county still read when all the fields are white
    col = mix(col, C(0xc2ab84).mul(float(0.92).add(fine.mul(0.12))), path.inside.mul(landMask).mul(snowAmt).mul(0.75));
    // the wild lands: each dyes its land its own colour (rust in the breaks, gold on the prairie, blue in the
    // high pines...), soft across the borders; the water and the snow keep their own
    const landDye = landTex ? texture(landTex, p.add(0.5).div(MAPN)).rgb.mul(1.25) : vec3(1);
    col = col.mul(mix(vec3(1), landDye, landMask.mul(float(1).sub(snowAmt.mul(0.7)))));
    col = col.mul(mix(vec3(1), landDye.min(vec3(1)), float(1).sub(landMask).mul(0.85))); // the fen's water runs dark as tea
    return isWall.select(wallCol.mul(mix(vec3(1), landDye, 0.6)), isLip.select(lipCol, col));
  })();
  const hpLum = (u) => luminance(texture(sharedTextures().handmade, u).rgb);
  m.normalNode = bumpMap(hpLum(positionWorld.xz.mul(0.21)), 0.35);
  return m;
}

// ---------------------------------------------------------------- the field patchwork, read on the CPU
// The ground shader picks each crop patch's kind (wheat, plough, hay) from the shared noise texture; the world
// reads the same texels here to dress the patches (stooks on wheat, bales on hay) to match.
let _noisePx = null;
function noiseG(u, v) {
  if (!_noisePx) {
    const img = sharedTextures().noise.image;
    _noisePx = img.getContext('2d').getImageData(0, 0, img.width, img.height);
  }
  const S = _noisePx.width, d = _noisePx.data;
  // linear filtering with repeat wrap; the canvas is uploaded flipped (uv 0,0 = its bottom-left)
  const x = u * S - 0.5, y = (1 - v) * S - 0.5;
  const x0 = Math.floor(x), y0 = Math.floor(y), tx = x - x0, ty = y - y0;
  const at = (i, j) => d[((((j % S) + S) % S) * S + (((i % S) + S) % S)) * 4 + 1] / 255;
  const a = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * tx, b = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * tx;
  return a + (b - a) * ty;
}
/** 'hay' | 'wheat' | 'plough' | null (too near a patch border) for a crop field at world (x, z). */
export function fieldKindAt(x, z) {
  const f = noiseG(x * 0.0045 + 0.13, z * 0.0045 + 0.71);
  if (f < 0.43) return 'hay';
  if (f > 0.462 && f < 0.613) return 'wheat';
  if (f > 0.645) return 'plough';
  return null;
}
