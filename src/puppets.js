// Paper puppets: animals built from several printed die-cut cards (body, head, legs, tail, ears),
// layered a hair apart like a real pop-up figure: the far legs sit behind the body and print a shade darker,
// the near legs and head in front. Legs swing on pivots, heads nod and graze, tails flick.
// The whole puppet turns to face the camera and flips to its mirrored back when walking screen-left.
import * as THREE from 'three/webgpu';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { animalModel, propModel } from './modelfolk.js';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';

const INKS = { dark: '#2b2018', cream: '#f3ead6' };

// small helpers for outlines
const ellipse = (cx, cy, rx, ry, n = 16, a0 = 0, a1 = Math.PI * 2) => {
  const out = [];
  for (let i = 0; i <= n; i++) { const a = a0 + ((a1 - a0) * i) / n; out.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]); }
  return out;
};
const leg = (w, len, hoof = 0) => [[w / 2, 0], [w / 2, -len + hoof], [w * 0.6, -len], [-w * 0.6, -len], [-w / 2, -len + hoof], [-w / 2, 0]];

/**
 * Species: every part is [outline, art options]; legs/head/tail hang from pivots (x, y) on the body.
 * Coordinates in metres, side profile facing +x, feet at y = 0.
 */
const SPECIES = {
  rabbit: {
    body: { pts: ellipse(0, 0.2, 0.2, 0.13, 18), base: '#a4886c', belly: '#efe3cc', spots: 0 },
    head: { pivot: [0.16, 0.27], pts: [...ellipse(0.06, 0.04, 0.09, 0.07, 12)], base: '#a4886c', eye: [0.1, 0.06], nose: [0.15, 0.03] },
    ears: [{ pivot: [0.13, 0.36], pts: ellipse(0, 0.1, 0.03, 0.11, 10), base: '#9a7e62', inner: '#d98f8a' }],
    legs: [{ x: -0.1, y: 0.12, w: 0.08, len: 0.12, near: true }, { x: 0.1, y: 0.1, w: 0.05, len: 0.1, near: true }, { x: -0.06, y: 0.12, w: 0.08, len: 0.12 }, { x: 0.13, y: 0.1, w: 0.05, len: 0.1 }],
    tail: { pivot: [-0.2, 0.24], pts: ellipse(-0.03, 0, 0.05, 0.05, 10), base: '#f6efe0' },
    gait: 'hop',
  },
  deer: {
    body: { pts: [[-0.5, 0.68], [0.4, 0.68], [0.52, 0.8], [0.5, 0.98], [0.32, 1.06], [-0.36, 1.06], [-0.52, 0.98], [-0.56, 0.84]], base: '#b8834e', belly: '#efe0c4', spots: 9 },
    head: { pivot: [0.42, 0.98], pts: [[0, -0.05], [0.12, 0.25], [0.2, 0.42], [0.34, 0.4], [0.4, 0.34], [0.26, 0.3], [0.14, 0.18], [0.08, -0.06]], base: '#b8834e', eye: [0.22, 0.36], nose: [0.39, 0.34] },
    ears: [{ pivot: [0.58, 1.38], pts: [[0, 0], [-0.05, 0.12], [-0.12, 0.14], [-0.07, 0.03]], base: '#a87545', inner: '#e8c8a8' }],
    legs: [{ x: 0.32, y: 0.74, w: 0.08, len: 0.74, near: true, hoof: 0.05 }, { x: -0.38, y: 0.74, w: 0.09, len: 0.74, near: true, hoof: 0.05 }, { x: 0.24, y: 0.74, w: 0.07, len: 0.74, hoof: 0.05 }, { x: -0.46, y: 0.74, w: 0.08, len: 0.74, hoof: 0.05 }],
    tail: { pivot: [-0.52, 1.0], pts: [[0, 0], [-0.08, 0.04], [-0.1, -0.06], [-0.02, -0.08]], base: '#f6efe0' },
    gait: 'walk',
  },
  hen: {
    body: { pts: [...ellipse(0, 0.24, 0.17, 0.13, 16, -0.4, Math.PI + 0.3), [-0.24, 0.42], [-0.2, 0.26]], base: '#f1e6d0', belly: '#e0d2b8', spots: 0, wing: '#d8c8aa' },
    head: { pivot: [0.12, 0.32], pts: [...ellipse(0.04, 0.1, 0.07, 0.07, 12)], base: '#f1e6d0', eye: [0.06, 0.12], comb: '#c4363a', beak: '#e0a03a' },
    legs: [{ x: 0.0, y: 0.12, w: 0.025, len: 0.12, near: true, color: '#e0a03a' }, { x: 0.04, y: 0.12, w: 0.025, len: 0.12, color: '#e0a03a' }],
    gait: 'peck',
  },
  // a mallard hen and her ducklings, paddling: a low boat of a body (no legs showing above the water), a rounded
  // head and a flat orange bill; the ducklings are the same cut in downy yellow
  duck: {
    body: { pts: [...ellipse(0, 0.1, 0.17, 0.08, 16, -0.2, Math.PI + 0.2), [-0.22, 0.17], [-0.16, 0.08]], base: '#8a6a48', belly: '#a88a64', spots: 0, wing: '#5e4a36' },
    head: { pivot: [0.12, 0.14], pts: [...ellipse(0.02, 0.07, 0.055, 0.05, 12)], base: '#7a5c3c', eye: [0.04, 0.09], beak: '#e0902a' },
    legs: [{ x: 0.0, y: 0.03, w: 0.02, len: 0.03, near: true, color: '#e0902a' }],
    gait: 'peck',
  },
  duckling: {
    body: { pts: [...ellipse(0, 0.1, 0.17, 0.09, 16, -0.2, Math.PI + 0.2), [-0.2, 0.15], [-0.15, 0.08]], base: '#e8c860', belly: '#f2dc8a', spots: 0, wing: '#d4b04a' },
    head: { pivot: [0.12, 0.15], pts: [...ellipse(0.02, 0.07, 0.065, 0.06, 12)], base: '#e8c860', eye: [0.04, 0.09], beak: '#e0902a' },
    legs: [{ x: 0.0, y: 0.03, w: 0.02, len: 0.03, near: true, color: '#e0902a' }],
    gait: 'peck',
  },
  // a wild turkey of the oak woods: a big bronze body barred with buff, a bare red head and wattle, and a tail fanned up
  // behind like a hand of cards
  turkey: {
    body: { pts: [...ellipse(0, 0.27, 0.2, 0.15, 16, -0.4, Math.PI + 0.3), [-0.26, 0.45], [-0.22, 0.28]], base: '#5e4a34', belly: '#3a2e22', spots: 0, wing: '#9a7a4e' },
    head: { pivot: [0.16, 0.33], pts: [...ellipse(0.04, 0.1, 0.06, 0.065, 12), [0.0, 0.0], [-0.05, -0.04]], base: '#c4544a', eye: [0.06, 0.14], comb: '#d0303a', beak: '#d8b070' },
    legs: [{ x: 0.0, y: 0.14, w: 0.03, len: 0.15, near: true, color: '#b89282' }, { x: 0.05, y: 0.14, w: 0.03, len: 0.15, color: '#b89282' }],
    tail: { pivot: [-0.2, 0.36], pts: [[0, 0], ...Array.from({ length: 9 }, (_, i) => { const a = Math.PI * (0.35 + i * 0.1); return [Math.cos(a) * 0.26, Math.sin(a) * 0.3]; })], base: '#4a3a2a' },
    gait: 'peck',
  },
  // the farmyard rooster: a hen's build in rust and gold, a big red comb and wattle, a tall dark sickle tail
  rooster: {
    body: { pts: [...ellipse(0, 0.25, 0.18, 0.14, 16, -0.4, Math.PI + 0.3), [-0.24, 0.44], [-0.2, 0.27]], base: '#b8562e', belly: '#3e4a36', spots: 0, wing: '#d9a040' },
    head: { pivot: [0.12, 0.34], pts: [...ellipse(0.04, 0.11, 0.075, 0.075, 12)], base: '#d98a2e', eye: [0.06, 0.13], comb: '#d0303a', beak: '#e0a03a' },
    legs: [{ x: 0.0, y: 0.13, w: 0.028, len: 0.13, near: true, color: '#e0a03a' }, { x: 0.04, y: 0.13, w: 0.028, len: 0.13, color: '#e0a03a' }],
    tail: { pivot: [-0.18, 0.34], pts: [[0, 0], [-0.08, 0.16], [-0.16, 0.24], [-0.24, 0.2], [-0.2, 0.08], [-0.12, -0.02], [-0.04, -0.06]], base: '#2e4a3a' },
    gait: 'peck',
  },
  cow: {
    // a Guernsey: honey-brown with cream patches, a pale muzzle and a brass bell
    body: { pts: [[-0.75, 0.6], [-0.2, 0.6], [-0.17, 0.5], [0.02, 0.5], [0.05, 0.6], [0.6, 0.6], [0.74, 0.76], [0.74, 1.14], [0.55, 1.28], [-0.6, 1.28], [-0.8, 1.14], [-0.82, 0.86]],
      base: '#d4a066', belly: '#f0e2c8', spots: 0, patches: 5, bell: [0.6, 0.98] },
    head: { pivot: [0.66, 1.16], pts: [[0, -0.08], [0.06, 0.14], [0.22, 0.2], [0.38, 0.02], [0.46, -0.2], [0.34, -0.31], [0.18, -0.24], [0.04, -0.14]], base: '#d4a066', eye: [0.17, 0.06], nose: [0.41, -0.22], muzzle: '#f1e4ca' },
    ears: [{ pivot: [0.7, 1.3], pts: [[0, 0], [0.12, 0.08], [0.18, 0.0], [0.07, -0.05]], base: '#b88448', inner: '#e8c8a8' }],
    legs: [{ x: 0.5, y: 0.64, w: 0.13, len: 0.64, near: true, hoof: 0.07 }, { x: -0.55, y: 0.64, w: 0.14, len: 0.64, near: true, hoof: 0.07 }, { x: 0.42, y: 0.64, w: 0.12, len: 0.64, hoof: 0.07 }, { x: -0.62, y: 0.64, w: 0.13, len: 0.64, hoof: 0.07 }],
    tail: { pivot: [-0.8, 1.18], pts: [[0.02, 0], [-0.03, -0.5], [-0.09, -0.58], [-0.05, -0.68], [0.02, -0.6], [0.03, -0.02]], base: '#8a5a30' },
    gait: 'walk',
  },
  // Babe the Blue Ox: a cow's build, but blue as a winter sky, with a pale muzzle and a broad pair of cream horns
  ox: {
    body: { pts: [[-0.75, 0.6], [-0.2, 0.6], [-0.17, 0.5], [0.02, 0.5], [0.05, 0.6], [0.6, 0.6], [0.74, 0.76], [0.74, 1.14], [0.55, 1.32], [-0.6, 1.3], [-0.8, 1.14], [-0.82, 0.86]],
      base: '#6e9ed0', belly: '#a4c2e2', spots: 0, back: '#5080b4', bell: [0.6, 0.98] },
    head: { pivot: [0.66, 1.16], pts: [[0, -0.08], [0.06, 0.14], [0.22, 0.2], [0.38, 0.02], [0.46, -0.2], [0.34, -0.31], [0.18, -0.24], [0.04, -0.14]], base: '#6e9ed0', eye: [0.17, 0.06], nose: [0.41, -0.22], muzzle: '#c8d8e8' },
    ears: [{ pivot: [0.7, 1.32], pts: [[0, 0], [0.1, 0.04], [0.26, 0.16], [0.36, 0.3], [0.32, 0.32], [0.2, 0.2], [0.06, 0.08], [-0.02, 0.05]], base: '#efe3c4', inner: '#d8c8a0' }],
    legs: [{ x: 0.5, y: 0.64, w: 0.14, len: 0.64, near: true, hoof: 0.07, color: '#4e78a8' }, { x: -0.55, y: 0.64, w: 0.15, len: 0.64, near: true, hoof: 0.07, color: '#4e78a8' }, { x: 0.42, y: 0.64, w: 0.13, len: 0.64, hoof: 0.07, color: '#3e6290' }, { x: -0.62, y: 0.64, w: 0.14, len: 0.64, hoof: 0.07, color: '#3e6290' }],
    tail: { pivot: [-0.8, 1.18], pts: [[0.02, 0], [-0.03, -0.5], [-0.09, -0.58], [-0.05, -0.68], [0.02, -0.6], [0.03, -0.02]], base: '#3e6290' },
    gait: 'walk',
  },
  // a chestnut saddle horse from the livery: a white blaze, a dark mane and tail, a red saddle blanket
  horse: {
    body: { pts: [[-0.62, 0.86], [0.42, 0.86], [0.56, 0.98], [0.58, 1.24], [0.46, 1.38], [0.08, 1.36], [-0.04, 1.42], [-0.3, 1.42], [-0.42, 1.36], [-0.62, 1.32], [-0.72, 1.12]],
      base: '#a8643a', belly: '#c88a58', spots: 0, back: '#7a4428', saddle: '#b5473a' },
    head: { pivot: [0.5, 1.28], pts: [[-0.02, -0.04], [0.04, 0.3], [0.12, 0.48], [0.22, 0.5], [0.42, 0.22], [0.5, 0.06], [0.44, -0.02], [0.3, 0.04], [0.14, -0.04]], base: '#a8643a', eye: [0.2, 0.32], nose: [0.47, 0.06], blaze: '#f3ead6', mane: '#3a2418' },
    ears: [{ pivot: [0.64, 1.8], pts: [[0, 0], [0.03, 0.13], [0.07, 0.0]], base: '#8a4e2c', inner: '#e0b090' }],
    legs: [{ x: 0.36, y: 0.9, w: 0.1, len: 0.9, near: true, hoof: 0.08, color: '#9a5a34' }, { x: -0.5, y: 0.9, w: 0.11, len: 0.9, near: true, hoof: 0.08, color: '#9a5a34' }, { x: 0.28, y: 0.9, w: 0.09, len: 0.9, hoof: 0.08, color: '#7a4428' }, { x: -0.58, y: 0.9, w: 0.1, len: 0.9, hoof: 0.08, color: '#7a4428' }],
    tail: { pivot: [-0.7, 1.3], pts: [[0.02, 0], [-0.1, -0.2], [-0.16, -0.6], [-0.08, -0.72], [-0.02, -0.5], [0.04, -0.06]], base: '#3a2418' },
    gait: 'walk',
  },
  sheep: {
    // a woolly cloud of a ewe with a black face and stockings
    body: { pts: ellipse(0, 0.6, 0.42, 0.25, 30).map(([x, y]) => { const a = Math.atan2(y - 0.6, x); const k = 1 + 0.09 * Math.abs(Math.sin(a * 7)); return [x * k, 0.6 + (y - 0.6) * k]; }),
      base: '#f6efe0', belly: '#ece2cc', spots: 0, wool: true },
    head: { pivot: [0.36, 0.7], pts: [[0, 0.04], [0.1, 0.13], [0.22, 0.07], [0.27, -0.08], [0.19, -0.15], [0.04, -0.08]], base: '#3a3028', eye: [0.13, 0.04] },
    ears: [{ pivot: [0.42, 0.78], pts: [[0, 0], [0.07, 0.04], [0.12, -0.01], [0.05, -0.04]], base: '#3a3028', inner: '#8a6a5a' }],
    legs: [{ x: 0.24, y: 0.4, w: 0.05, len: 0.4, near: true, color: '#3a3028' }, { x: -0.26, y: 0.4, w: 0.055, len: 0.4, near: true, color: '#3a3028' }, { x: 0.18, y: 0.4, w: 0.05, len: 0.4, color: '#2e261f' }, { x: -0.32, y: 0.4, w: 0.05, len: 0.4, color: '#2e261f' }],
    tail: { pivot: [-0.44, 0.64], pts: ellipse(-0.03, -0.04, 0.06, 0.08, 10), base: '#e6dcc6' },
    gait: 'walk',
  },
  bison: {
    // an American bison: a towering shoulder hump in a shaggy dark-brown cape, a lighter tan rump, a low heavy
    // head with a beard and short cream horns, short stout legs and a tufted tail
    body: { pts: [[-0.82, 0.62], [0.32, 0.6], [0.58, 0.56], [0.78, 0.72], [0.84, 1.02], [0.7, 1.42], [0.42, 1.74], [0.14, 1.72], [-0.12, 1.5], [-0.52, 1.32], [-0.84, 1.22], [-0.92, 0.92]],
      base: '#8a6440', belly: '#6e4e32', spots: 0, cape: '#4a3020' },
    head: { pivot: [0.74, 1.08], pts: [[-0.04, 0.16], [0.14, 0.2], [0.3, 0.02], [0.36, -0.26], [0.3, -0.42], [0.16, -0.46], [0.04, -0.36], [-0.04, -0.12]], base: '#3e281a', eye: [0.2, -0.04], nose: [0.32, -0.34], beard: '#2e1e14' },
    ears: [{ pivot: [0.8, 1.22], pts: [[0, 0], [0.07, 0.03], [0.12, 0.12], [0.09, 0.2], [0.06, 0.12], [-0.02, 0.06]], base: '#e8dcc0', inner: '#cbbf9f' }],
    legs: [{ x: 0.5, y: 0.66, w: 0.15, len: 0.66, near: true, hoof: 0.07, color: '#4a3020' }, { x: -0.62, y: 0.66, w: 0.15, len: 0.66, near: true, hoof: 0.07 }, { x: 0.4, y: 0.66, w: 0.14, len: 0.66, hoof: 0.07, color: '#3a2618' }, { x: -0.7, y: 0.66, w: 0.14, len: 0.66, hoof: 0.07 }],
    tail: { pivot: [-0.9, 1.14], pts: [[0.02, 0], [-0.03, -0.36], [-0.1, -0.44], [-0.06, -0.56], [0.03, -0.46], [0.03, -0.02]], base: '#4a3020' },
    gait: 'walk',
  },
  dog: {
    // an old farm hound: tan with a dark saddle, long floppy ears and a waving tail
    body: { pts: [[-0.36, 0.32], [0.26, 0.32], [0.36, 0.4], [0.36, 0.56], [0.2, 0.62], [-0.28, 0.6], [-0.4, 0.5]], base: '#c69a62', belly: '#efe0c4', spots: 0, back: '#6b4a30' },
    head: { pivot: [0.3, 0.58], pts: [[0, -0.04], [0.04, 0.12], [0.16, 0.16], [0.3, 0.06], [0.34, -0.02], [0.18, -0.06], [0.06, -0.1]], base: '#c69a62', eye: [0.15, 0.08], nose: [0.33, 0.02] },
    ears: [{ pivot: [0.38, 0.72], pts: [[0, 0], [0.04, -0.02], [0.02, -0.2], [-0.05, -0.22], [-0.06, -0.04]], base: '#6b4a30', inner: '#8a6040' }],
    legs: [{ x: 0.2, y: 0.34, w: 0.06, len: 0.34, near: true }, { x: -0.28, y: 0.34, w: 0.07, len: 0.34, near: true }, { x: 0.14, y: 0.34, w: 0.055, len: 0.34 }, { x: -0.34, y: 0.34, w: 0.06, len: 0.34 }],
    tail: { pivot: [-0.38, 0.54], pts: [[0, 0.02], [-0.12, 0.1], [-0.22, 0.2], [-0.2, 0.24], [-0.1, 0.14], [0, 0.06]], base: '#c69a62' },
    gait: 'walk',
  },
  cat: {
    // a marmalade barn cat: ginger tabby bars, a cream bib and paws, a long tail held up in a question mark
    body: { pts: [[-0.2, 0.17], [0.14, 0.17], [0.2, 0.22], [0.2, 0.3], [0.1, 0.34], [-0.14, 0.33], [-0.22, 0.26]], base: '#e6a25a', belly: '#f3e6cc', spots: 0, stripes: '#b26a32' },
    head: { pivot: [0.17, 0.3], pts: [[-0.02, -0.04], [0.0, 0.08], [0.04, 0.1], [0.12, 0.09], [0.15, 0.03], [0.13, -0.04], [0.04, -0.07]], base: '#e6a25a', eye: [0.08, 0.04], nose: [0.145, 0.01], cat: true },
    ears: [{ pivot: [0.19, 0.39], pts: [[0, 0], [0.025, 0.07], [0.055, 0.0]], base: '#d6904c', inner: '#eeb4a8' }],
    legs: [{ x: 0.11, y: 0.19, w: 0.04, len: 0.19, near: true }, { x: -0.15, y: 0.19, w: 0.05, len: 0.19, near: true }, { x: 0.07, y: 0.19, w: 0.035, len: 0.19 }, { x: -0.19, y: 0.19, w: 0.045, len: 0.19 }],
    tail: { pivot: [-0.2, 0.28], pts: [[0, 0.02], [-0.08, 0.06], [-0.13, 0.16], [-0.12, 0.27], [-0.07, 0.31], [-0.05, 0.28], [-0.09, 0.24], [-0.09, 0.15], [-0.05, 0.08], [0, 0.0]], base: '#d6904c' },
    gait: 'walk',
  },
  coyote: {
    body: { pts: [[-0.42, 0.42], [0.3, 0.42], [0.42, 0.52], [0.4, 0.66], [0.22, 0.72], [-0.3, 0.7], [-0.44, 0.6]], base: '#dab47c', belly: '#f3e6c8', spots: 0, back: '#9a7048', swirls: '#f6ecd0' },
    head: { pivot: [0.34, 0.66], pts: [[0, -0.06], [0.08, 0.1], [0.14, 0.14], [0.36, 0.06], [0.38, 0.02], [0.14, -0.02], [0.06, -0.1]], base: '#dab47c', eye: [0.15, 0.07], nose: [0.37, 0.04], fierce: true, muzzle: '#f3e6c8' },
    ears: [{ pivot: [0.46, 0.78], pts: [[0, 0], [0.02, 0.14], [-0.06, 0.02]], base: '#9a7048', inner: '#e8c8a0' }],
    legs: [{ x: 0.24, y: 0.46, w: 0.06, len: 0.46, near: true }, { x: -0.32, y: 0.46, w: 0.07, len: 0.46, near: true }, { x: 0.16, y: 0.46, w: 0.055, len: 0.46 }, { x: -0.38, y: 0.46, w: 0.06, len: 0.46 }],
    tail: { pivot: [-0.42, 0.62], pts: [[0, 0.03], [-0.18, -0.02], [-0.34, -0.14], [-0.3, -0.2], [-0.14, -0.1], [0, -0.04]], base: '#b8895a', tip: '#3a2a20' },
    gait: 'walk',
  },
  // the Hodag of the north woods: a squat, scaled brute with a row of spikes down its back, horns, and a
  // grin full of white teeth, keeping the pearl beds of the fen
  hodag: {
    body: { pts: [[-0.6, 0.34], [0.42, 0.34], [0.58, 0.46], [0.58, 0.72], [0.46, 0.82], [0.4, 0.98], [0.3, 0.86], [0.22, 1.02], [0.1, 0.88], [0.0, 1.06], [-0.12, 0.9], [-0.22, 1.04], [-0.32, 0.88], [-0.44, 0.98], [-0.5, 0.8], [-0.66, 0.6]],
      base: '#6e8048', belly: '#a8b46e', spots: 7, back: '#4a5a34' },
    head: { pivot: [0.52, 0.7], pts: [[-0.02, 0.18], [0.06, 0.24], [0.02, 0.4], [0.12, 0.26], [0.2, 0.22], [0.26, 0.38], [0.28, 0.2], [0.44, 0.1], [0.48, -0.06], [0.38, -0.18], [0.08, -0.16], [-0.04, 0.0]],
      base: '#6e8048', eye: [0.2, 0.1], nose: [0.45, 0.02], fierce: true, grin: true },
    ears: [],
    legs: [{ x: 0.34, y: 0.38, w: 0.13, len: 0.38, near: true, hoof: 0.06, color: '#3e4c30' }, { x: -0.44, y: 0.38, w: 0.14, len: 0.38, near: true, hoof: 0.06, color: '#3e4c30' }, { x: 0.26, y: 0.38, w: 0.12, len: 0.38, hoof: 0.06, color: '#2e3a26' }, { x: -0.52, y: 0.38, w: 0.13, len: 0.38, hoof: 0.06, color: '#2e3a26' }],
    tail: { pivot: [-0.64, 0.6], pts: [[0, 0.04], [-0.3, 0.0], [-0.42, 0.08], [-0.56, 0.0], [-0.42, -0.08], [-0.3, -0.04], [0, -0.04]], base: '#3e4c30' },
    gait: 'walk',
  },
  // the wampus cat of the high timber: a long, low panther, smoke-black with tawny bars and lamp-yellow eyes
  wampus: {
    body: { pts: [[-0.62, 0.42], [0.36, 0.42], [0.5, 0.52], [0.5, 0.7], [0.3, 0.78], [-0.4, 0.74], [-0.62, 0.62]], base: '#3a3634', belly: '#5a524a', spots: 0, stripes: '#c8964a' },
    head: { pivot: [0.44, 0.7], pts: [[-0.02, -0.06], [0.0, 0.1], [0.06, 0.14], [0.22, 0.12], [0.3, 0.04], [0.28, -0.06], [0.08, -0.1]], base: '#3a3634', eye: [0.14, 0.05], nose: [0.28, 0.0], cat: true, glow: true },
    ears: [{ pivot: [0.48, 0.86], pts: [[0, 0], [0.03, 0.12], [0.07, 0.17], [0.08, 0.0]], base: '#2a2624', inner: '#8a6a5a' }],
    legs: [{ x: 0.28, y: 0.46, w: 0.08, len: 0.46, near: true }, { x: -0.48, y: 0.46, w: 0.1, len: 0.46, near: true }, { x: 0.2, y: 0.46, w: 0.075, len: 0.46 }, { x: -0.54, y: 0.46, w: 0.09, len: 0.46 }],
    tail: { pivot: [-0.6, 0.62], pts: [[0, 0.03], [-0.2, 0.02], [-0.42, 0.12], [-0.56, 0.3], [-0.52, 0.34], [-0.4, 0.18], [-0.2, 0.08], [0, -0.03]], base: '#2a2624' },
    gait: 'walk',
  },
  // the sidehill gouger: a shaggy rust-red beast built for hillsides, its uphill legs short and its downhill legs
  // long, so on level ground it lists like a barn in a gale; curled horns, a ragged mane
  gouger: {
    body: { pts: [[-0.5, 0.5], [0.34, 0.44], [0.48, 0.58], [0.46, 0.78], [0.3, 0.9], [-0.3, 0.92], [-0.52, 0.76]], base: '#9a5034', belly: '#d8b484', spots: 0, back: '#6a3420', bristles: true },
    head: { pivot: [0.42, 0.8], pts: [[-0.02, 0.12], [0.06, 0.24], [0.0, 0.32], [0.1, 0.36], [0.16, 0.24], [0.22, 0.2], [0.36, 0.04], [0.36, -0.08], [0.2, -0.12], [0.04, -0.08]], base: '#8a4630', eye: [0.16, 0.1], nose: [0.34, -0.02], fierce: true, beard: '#5a2a18' },
    ears: [{ pivot: [0.46, 1.0], pts: [[0, 0], [-0.06, 0.06], [-0.12, 0.02], [-0.06, -0.03]], base: '#e8d8b8', inner: '#c8b898' }],
    legs: [{ x: 0.24, y: 0.5, w: 0.08, len: 0.28, near: true, hoof: 0.05, color: '#5a2a18' }, { x: -0.34, y: 0.52, w: 0.09, len: 0.3, near: true, hoof: 0.05, color: '#5a2a18' }, { x: 0.18, y: 0.5, w: 0.08, len: 0.5, hoof: 0.05 }, { x: -0.4, y: 0.52, w: 0.09, len: 0.52, hoof: 0.05 }],
    tail: { pivot: [-0.5, 0.78], pts: [[0, 0], [-0.1, -0.06], [-0.14, -0.2], [-0.08, -0.18], [-0.04, -0.06]], base: '#6a3420' },
    gait: 'walk',
  },
  // the Hidebehind of the birch hollows: nobody has ever seen one, because it is always behind you. Tall, gaunt,
  // shaggy and grey as birch shadow, with long arms and two pale lamp eyes
  hidebehind: {
    body: { pts: [[-0.16, 0.8], [0.2, 0.8], [0.26, 1.2], [0.42, 1.0], [0.48, 0.74], [0.54, 0.76], [0.48, 1.12], [0.3, 1.6], [0.2, 1.86], [-0.14, 1.88], [-0.28, 1.5], [-0.46, 1.04], [-0.42, 0.74], [-0.36, 0.76], [-0.3, 1.1], [-0.22, 0.98]],
      base: '#6e6a66', belly: '#8e8a84', spots: 0, back: '#4a4644', wool: true },
    head: { pivot: [0.06, 1.84], pts: [[-0.16, -0.04], [-0.14, 0.24], [-0.04, 0.4], [0.12, 0.38], [0.2, 0.2], [0.18, -0.04], [0.04, -0.12]], base: '#5a5652', eye: [0.08, 0.16], nose: [0.17, 0.06], glow: true },
    ears: [],
    legs: [{ x: 0.06, y: 0.82, w: 0.1, len: 0.82, near: true, color: '#4a4644' }, { x: -0.06, y: 0.82, w: 0.1, len: 0.82, color: '#3a3634' }],
    gait: 'walk',
  },
  boar: {
    body: { pts: [[-0.5, 0.3], [0.36, 0.3], [0.5, 0.42], [0.5, 0.66], [0.28, 0.82], [-0.1, 0.86], [-0.42, 0.78], [-0.56, 0.56]], base: '#7a5e4a', belly: '#9a8068', spots: 0, back: '#4a3a30', bristles: true, brambles: true },
    head: { pivot: [0.44, 0.6], pts: [[0, 0.16], [0.12, 0.14], [0.32, 0.0], [0.36, -0.12], [0.24, -0.16], [0.02, -0.12], [-0.04, 0.0]], base: '#6e5544', eye: [0.12, 0.06], nose: [0.33, -0.08], tusk: true, fierce: true },
    ears: [{ pivot: [0.5, 0.74], pts: [[0, 0], [-0.04, 0.12], [-0.1, 0.02]], base: '#5a4436', inner: '#b8907a' }],
    legs: [{ x: 0.28, y: 0.34, w: 0.09, len: 0.34, near: true, hoof: 0.05 }, { x: -0.36, y: 0.34, w: 0.1, len: 0.34, near: true, hoof: 0.05 }, { x: 0.2, y: 0.34, w: 0.085, len: 0.34, hoof: 0.05 }, { x: -0.44, y: 0.34, w: 0.09, len: 0.34, hoof: 0.05 }],
    tail: { pivot: [-0.54, 0.66], pts: [[0, 0], [-0.08, -0.02], [-0.1, -0.12], [-0.06, -0.12], [-0.05, -0.04]], base: '#4a3a30' },
    gait: 'walk',
  },
};

// ---------------------------------------------------------------- printing the parts

function tone(hex, k) { const c = new THREE.Color(hex); c.multiplyScalar(k); return `#${c.getHexString()}`; }

function partArt(pts, base, draw, seed) {
  return paintCard(pts, {
    W: 192, H: 192, seed, base,
    fills: [`rgba(${hexToRgb(base)},A)`, `rgba(${hexToRgb(tone(base, 0.88))},A)`, `rgba(${hexToRgb(tone(base, 1.1))},A)`],
    edge: `rgba(${hexToRgb(tone(base, 0.55))},1)`,
    details: draw,
  });
}
function hexToRgb(h) { const c = new THREE.Color(h); return `${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)}`; }

/**
 * A solid paper form: the printed silhouette on both faces, joined by a chamfered wall of card all round (the wall
 * takes one colour from the print, the coat's), and swelled or slimmed through its depth by zScale(x, y), so a body
 * is barrel-chested and narrow at the belly and rump, and a head narrows to its snout. One piece, like a scored and
 * folded paper model, never a flat card.
 */
function solidGeometry(pts, depth, zScale, wall) {
  const bev = Math.min(0.05, depth * 0.18);
  const g = new THREE.ExtrudeGeometry(new THREE.Shape(pts.map(([x, y]) => new THREE.Vector2(x, y))), { depth: Math.max(0.01, depth - 2 * bev), bevelEnabled: true, bevelThickness: bev, bevelSize: bev * 0.7, bevelSegments: 2, curveSegments: 1 });
  g.translate(0, 0, -Math.max(0.01, depth - 2 * bev) / 2);
  let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
  for (const [x, y] of pts) { minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
  const bx = { minX, maxX, minY, maxY };
  const w0 = maxX - minX, h0 = maxY - minY, pX = minX - w0 * 0.04, pY = minY - h0 * 0.04, W = w0 * 1.08, H = h0 * 1.08;
  const pos = g.attributes.position, uv = g.attributes.uv;
  for (const grp of g.groups) for (let i = grp.start; i < grp.start + grp.count; i++) {
    if (grp.materialIndex === 0) uv.setXY(i, (pos.getX(i) - pX) / W, (pos.getY(i) - pY) / H);
    else uv.setXY(i, (wall[0] - pX) / W, (wall[1] - pY) / H);
  }
  for (let i = 0; i < pos.count; i++) pos.setZ(i, pos.getZ(i) * zScale(pos.getX(i), pos.getY(i), bx));
  g.clearGroups(); g.computeVertexNormals(); g.computeBoundingSphere();
  return g;
}
const unit = (v, a, b) => Math.min(1, Math.max(0, (v - a) / Math.max(1e-4, b - a)));

const CACHE = {};
/** Build (once per species) the printed card geometry + material for every part. */
function kit(name) {
  if (CACHE[name]) return CACHE[name];
  const sp = SPECIES[name];
  let seed = name.length * 13;
  const card = (pts, base, draw, thick = 0.025, solid = null) => ({ geometry: solid ? solidGeometry(pts, solid.depth, solid.z, solid.wall) : cardGeometry(pts, thick), material: cardMaterial(partArt(pts, base, draw, seed++)) });
  const out = {};
  const bys = sp.body.pts.map((p) => p[1]), bxs = sp.body.pts.map((p) => p[0]);
  const bLo = Math.min(...bys), bHi = Math.max(...bys), bXl = Math.min(...bxs), bXr = Math.max(...bxs);
  out.bodyDepth = Math.max(0.24, (bHi - bLo) * 0.85);
  const barrel = (x, y, b) => (0.5 + 0.5 * Math.sin(Math.PI * (0.15 + 0.7 * unit(y, b.minY, b.maxY)))) * (0.72 + 0.28 * Math.sin(Math.PI * (0.1 + 0.8 * unit(x, b.minX, b.maxX))));
  const hys = sp.head.pts.map((p) => p[1]), hxs = sp.head.pts.map((p) => p[0]);
  out.headDepth = Math.max(0.14, (Math.max(...hys) - Math.min(...hys)) * 0.75);
  const snout = (x, y, b) => (1 - 0.5 * unit(x, b.minX, b.maxX)) * (0.7 + 0.3 * Math.sin(Math.PI * (0.1 + 0.8 * unit(y, b.minY, b.maxY))));
  const B = sp.body;
  out.body = card(B.pts, B.base, (g, px, r) => {
    // belly wash, darker back stripe, spots, bristles, a wing for hens
    const ys = B.pts.map((p) => p[1]), lo = Math.min(...ys), hi = Math.max(...ys);
    const xs = B.pts.map((p) => p[0]), xl = Math.min(...xs), xr = Math.max(...xs), wd = xr - xl, ht = hi - lo;
    // the haunch and the shoulder: two cut layers of a deeper tone, each with a pale lip where the light catches its
    // top edge and a short soft shadow under it, so the flank reads as layered card, not a flat fill
    const deep = [tone(B.base, 0.78), tone(B.base, 0.86)];
    for (const [fx, fy, rx, ry, k] of [[0.22, 0.5, 0.17, 0.28, 0], [0.74, 0.56, 0.11, 0.2, 1]]) {
      const [cx, cy] = px(xl + wd * fx, lo + ht * fy), [ex] = px(xl + wd * (fx + rx), 0), [, ey] = px(0, lo + ht * (fy + ry)), RX = Math.abs(ex - cx), RY = Math.abs(ey - cy);
      g.fillStyle = 'rgba(40,24,14,0.16)'; g.beginPath(); g.ellipse(cx + 2, cy + 4, RX, RY, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = deep[k]; g.beginPath(); g.ellipse(cx, cy, RX, RY, -0.25, 0, Math.PI * 2); g.fill();
      g.strokeStyle = 'rgba(255,248,232,0.35)'; g.lineWidth = 2; g.beginPath(); g.ellipse(cx, cy, RX - 1, RY - 1, -0.25, Math.PI * 1.15, Math.PI * 1.75); g.stroke();
    }
    if (!B.wool && !B.cape) { // the nap of the coat: short strokes laid back along the body, darker on the back
      g.lineCap = 'round';
      for (let i = 0; i < 70; i++) {
        const u = r(), v = r(), [hx, hy] = px(xl + wd * (0.08 + u * 0.84), lo + ht * (0.25 + v * 0.7));
        g.strokeStyle = v > 0.55 ? `rgba(${hexToRgb(tone(B.base, 0.6))},0.6)` : `rgba(${hexToRgb(tone(B.base, 1.3))},0.5)`; g.lineWidth = 3;
        g.beginPath(); g.moveTo(hx, hy); g.lineTo(hx - 7, hy + 3); g.stroke();
      }
    }
    const [bx0, by0] = px(-0.6, lo), [bx1, by1] = px(0.6, lo + (hi - lo) * 0.3);
    g.fillStyle = B.belly; g.globalAlpha = 0.8; g.fillRect(bx0, by1, bx1 - bx0, by0 - by1); g.globalAlpha = 1;
    if (B.back) { const [cx0, cy0] = px(-0.6, hi - (hi - lo) * 0.25), [cx1, cy1] = px(0.6, hi + 0.1); g.fillStyle = B.back; g.globalAlpha = 0.6; g.fillRect(cx0, cy1, cx1 - cx0, cy0 - cy1); g.globalAlpha = 1; }
    for (let i = 0; i < B.spots; i++) { const [sx, sy] = px(-0.35 + r() * 0.7, lo + (hi - lo) * (0.45 + r() * 0.45)); g.fillStyle = 'rgba(246,236,214,0.9)'; g.beginPath(); g.arc(sx, sy, 4 + r() * 3, 0, Math.PI * 2); g.fill(); }
    if (B.stripes) { g.fillStyle = B.stripes; g.globalAlpha = 0.75; for (let i = 0; i < 6; i++) { const [sx, sy] = px(-0.17 + i * 0.06, hi); g.beginPath(); g.moveTo(sx - 5, sy); g.lineTo(sx + 5, sy); g.lineTo(sx + 2, sy + 26); g.lineTo(sx - 3, sy + 22); g.fill(); } g.globalAlpha = 1; }
    if (B.swirls) { // the dust devils it's named for: little rust whirlwinds printed down its flank
      g.strokeStyle = B.swirls; g.lineWidth = 5; g.lineCap = 'round';
      for (const [sx, sy] of [[-0.2, 0.58], [0.0, 0.6], [0.18, 0.56]]) {
        const [cx, cy] = px(sx, sy); g.beginPath();
        for (let k = 0; k <= 34; k++) { const a = k * 0.42, r = 2 + k * 0.62; g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r * 0.8); }
        g.stroke();
      }
    }
    if (B.brambles) { // briar caught in its bristles: thorny green sprigs with leaves and a few red berries
      for (const [bx0, by0, ang] of [[-0.3, 0.8, -0.3], [0.05, 0.84, 0.2], [0.25, 0.76, 0.5]]) {
        const [x0, y0] = px(bx0, by0); g.save(); g.translate(x0, y0); g.rotate(ang); g.scale(1.6, 1.6);
        g.strokeStyle = '#4a6a34'; g.lineWidth = 3; g.beginPath(); g.moveTo(-22, 4); g.quadraticCurveTo(0, -10, 24, 2); g.stroke();
        g.fillStyle = '#5e7e40'; for (const lx of [-14, 2, 16]) { g.beginPath(); g.ellipse(lx, -6, 6, 3.5, -0.5, 0, Math.PI * 2); g.fill(); }
        g.fillStyle = '#c4362f'; for (const lx of [-6, 10]) { g.beginPath(); g.arc(lx, 2, 3.5, 0, Math.PI * 2); g.fill(); }
        g.strokeStyle = '#2b3a20'; g.lineWidth = 1.5; for (const lx of [-18, -2, 12, 20]) { g.beginPath(); g.moveTo(lx, -2); g.lineTo(lx + 3, -8); g.stroke(); }
        g.restore();
      }
    }
    if (B.cape) {
      g.fillStyle = B.cape; g.beginPath();
      const [c0x, c0y] = px(-0.06, hi + 0.1); g.moveTo(c0x, c0y);
      for (let k = 0; k <= 14; k++) { const yy = hi + 0.1 - (k / 14) * (hi - lo + 0.2), [ex, ey] = px(-0.12 + (k % 2) * 0.09 + (r() - 0.5) * 0.04, yy); g.lineTo(ex, ey); }
      const [c1x, c1y] = px(1.0, lo - 0.1), [c2x, c2y] = px(1.0, hi + 0.1); g.lineTo(c1x, c1y); g.lineTo(c2x, c2y); g.closePath(); g.fill();
      g.strokeStyle = 'rgba(150,110,72,0.55)'; g.lineWidth = 3; g.lineCap = 'round';
      for (let i = 0; i < 30; i++) { const [hx, hy] = px(0.0 + r() * 0.75, lo + (hi - lo) * (0.2 + r() * 0.75)); g.beginPath(); g.moveTo(hx, hy); g.quadraticCurveTo(hx + 4, hy + 7, hx - 1, hy + 14); g.stroke(); } // curls of shag
    }
    if (B.bristles) { g.strokeStyle = 'rgba(40,30,24,0.8)'; g.lineWidth = 3; for (let i = 0; i < 14; i++) { const [sx, sy] = px(-0.35 + i * 0.05, hi - 0.02); g.beginPath(); g.moveTo(sx, sy + 6); g.lineTo(sx + 3, sy - 8); g.stroke(); } }
    if (B.patches) { // cream patches, each a cut layer of its own
      for (let i = 0; i < B.patches; i++) {
        const [px0, py0] = px(-0.6 + (i / (B.patches - 1)) * 1.1 + (r() - 0.5) * 0.15, lo + (hi - lo) * (0.4 + r() * 0.45));
        g.fillStyle = '#f3e8d2'; g.beginPath();
        for (let k = 0; k <= 9; k++) { const a = (k / 9) * Math.PI * 2, rr = 16 + r() * 12; g.lineTo(px0 + Math.cos(a) * rr * 1.3, py0 + Math.sin(a) * rr); }
        g.fill();
      }
    }
    if (B.saddle) { const [a, b] = px(-0.3, 1.43), [c, d] = px(0.12, 1.1); g.fillStyle = B.saddle; g.fillRect(a, b, c - a, d - b); g.fillStyle = '#e8c84a'; g.fillRect(a, d - 6, c - a, 5); g.fillStyle = '#5a3a24'; const [e, f] = px(-0.22, 1.5), [h, k] = px(0.06, 1.38); g.fillRect(e, f, h - e, k - f); }
    if (B.bell) { const [bx, by] = px(B.bell[0], B.bell[1]); g.strokeStyle = '#7a3a24'; g.lineWidth = 6; g.beginPath(); g.moveTo(bx - 6, by - 26); g.lineTo(bx, by - 4); g.stroke(); g.fillStyle = '#d9a441'; g.beginPath(); g.arc(bx, by + 4, 9, 0, Math.PI * 2); g.fill(); }
    if (B.wool) { g.strokeStyle = 'rgba(214,202,176,0.55)'; g.lineWidth = 2.5; for (let i = 0; i < 40; i++) { const [wx, wy] = px(-0.38 + r() * 0.76, lo + (hi - lo) * (0.12 + r() * 0.8)); g.beginPath(); g.arc(wx, wy, 5 + r() * 4, r() * 6, r() * 6 + 3.6); g.stroke(); } }
    if (B.wing) { const [wx, wy] = px(-0.04, 0.24); g.fillStyle = B.wing; g.beginPath(); g.ellipse(wx, wy, 34, 20, -0.3, 0, Math.PI * 2); g.fill(); g.strokeStyle = 'rgba(150,120,90,0.6)'; g.lineWidth = 2; for (let k = 0; k < 3; k++) { g.beginPath(); g.arc(wx + 10 - k * 10, wy, 14, 0.2, 2.2); g.stroke(); } }
  }, 0.025, { depth: out.bodyDepth, z: barrel, wall: [(bXl + bXr) / 2, bHi - (bHi - bLo) * 0.12] });
  const H = sp.head;
  out.head = card(H.pts, H.base, (g, px) => {
    const [ex, ey] = px(H.eye[0], H.eye[1]);
    if (H.glow) { // lamp eyes: a yellow glow ring and a slit
      g.fillStyle = 'rgba(240,208,80,0.35)'; g.beginPath(); g.arc(ex, ey, 14, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#f2d050'; g.beginPath(); g.ellipse(ex, ey, 8, 6, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = INKS.dark; g.fillRect(ex - 1.5, ey - 5, 3, 10);
    }
    if (H.grin) { // a long grin with a row of white teeth
      const [m0x, m0y] = px(H.nose[0] - 0.02, H.nose[1] - 0.1), [m1x, m1y] = px(0.08, -0.06);
      g.fillStyle = '#2a1a14'; g.beginPath(); g.moveTo(m1x, m1y); g.quadraticCurveTo((m0x + m1x) / 2, m0y + 16, m0x, m0y); g.lineTo(m0x, m0y - 6); g.quadraticCurveTo((m0x + m1x) / 2, m0y + 6, m1x, m1y - 6); g.fill();
      g.fillStyle = INKS.cream; for (let k = 0; k < 6; k++) { const t = k / 5, tx = m1x + (m0x - m1x) * t, ty = m1y - 6 + (m0y - m1y) * t + Math.sin(t * Math.PI) * 6; g.beginPath(); g.moveTo(tx - 4, ty); g.lineTo(tx + 4, ty); g.lineTo(tx, ty + 9); g.fill(); }
    }
    if (H.glow) { /* the lamp eyes stand in for the usual ink eye */ } else {
    g.fillStyle = INKS.cream; g.beginPath(); g.arc(ex, ey, H.fierce ? 7 : 6, 0, Math.PI * 2); g.fill();
    g.fillStyle = H.fierce ? '#8a2a1a' : INKS.dark; g.beginPath(); g.arc(ex + 1, ey, H.fierce ? 4 : 4.5, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#ffffff'; g.beginPath(); g.arc(ex - 0.5, ey - 2, 1.8, 0, Math.PI * 2); g.fill(); // a catch-light: the eye is wet and alive
    if (!H.fierce) {
      g.strokeStyle = INKS.dark; g.lineWidth = 2; g.lineCap = 'round'; g.beginPath(); g.arc(ex, ey, 7.5, Math.PI * 1.1, Math.PI * 1.9); g.stroke(); // the lid
      for (const a of [1.15, 1.3]) { g.beginPath(); g.moveTo(ex + Math.cos(Math.PI * a) * 7.5, ey + Math.sin(Math.PI * a) * 7.5); g.lineTo(ex + Math.cos(Math.PI * a) * 11, ey + Math.sin(Math.PI * a) * 11); g.stroke(); } // two lashes
      const [bx, by] = px(H.eye[0] + 0.06, H.eye[1] - 0.12); g.fillStyle = 'rgba(226,116,96,0.35)'; g.beginPath(); g.ellipse(bx, by, 9, 5, 0, 0, Math.PI * 2); g.fill(); // a little blush
    }
    if (H.fierce) { g.strokeStyle = INKS.dark; g.lineWidth = 3; g.beginPath(); g.moveTo(ex - 9, ey - 9); g.lineTo(ex + 8, ey - 5); g.stroke(); }
    }
    if (H.muzzle) { const [mx, my] = px(H.nose[0] - 0.02, H.nose[1] + 0.02); g.fillStyle = H.muzzle; g.beginPath(); g.ellipse(mx, my, 20, 16, 0.3, 0, Math.PI * 2); g.fill(); }
    if (H.cat) { const [mx, my] = px(H.nose[0] - 0.02, H.nose[1] - 0.02); g.strokeStyle = 'rgba(60,40,28,0.7)'; g.lineWidth = 1.5; for (const d of [-4, 0, 4]) { g.beginPath(); g.moveTo(mx, my + d * 0.5); g.lineTo(mx + 22, my + d * 1.6); g.stroke(); } g.fillStyle = '#9a5a2a'; for (const k of [0, 1]) { const [sx, sy] = px(0.02 + k * 0.03, 0.09); g.fillRect(sx - 3, sy, 5, 12); } }
    if (H.nose && H.cat) { const [nx, ny] = px(H.nose[0], H.nose[1]); g.fillStyle = '#c8706a'; g.beginPath(); g.arc(nx, ny, 3.5, 0, Math.PI * 2); g.fill(); }
    else if (H.nose) { const [nx, ny] = px(H.nose[0], H.nose[1]); g.fillStyle = INKS.dark; g.beginPath(); g.arc(nx, ny, 5, 0, Math.PI * 2); g.fill(); }
    if (H.blaze) { g.fillStyle = H.blaze; g.beginPath(); const [a, b] = px(0.16, 0.46), [c, d] = px(0.44, 0.1), [e, f] = px(0.38, 0.06); g.moveTo(a, b); g.lineTo(a + 8, b); g.lineTo(c, d); g.lineTo(e, f); g.closePath(); g.fill(); }
    if (H.mane) { g.fillStyle = H.mane; g.beginPath(); const pts = [[-0.04, -0.02], [0.02, 0.3], [0.1, 0.5], [0.16, 0.5], [0.06, 0.28], [0.04, -0.02]]; pts.forEach(([x, y], i) => { const [a, b] = px(x, y); i ? g.lineTo(a, b) : g.moveTo(a, b); }); g.fill(); }
    if (H.beard) { g.fillStyle = H.beard; g.beginPath(); const [b0x, b0y] = px(0.06, -0.3), [b1x, b1y] = px(0.24, -0.42); g.moveTo(b0x, b0y); g.lineTo(b1x, b1y); for (let k = 0; k <= 5; k++) { const [tx, ty] = px(0.22 - k * 0.035, -0.46 - (k % 2 ? 0.0 : 0.05)); g.lineTo(tx, ty); } g.closePath(); g.fill(); }
    if (H.tusk) { const [tx, ty] = px(H.nose[0] - 0.08, H.nose[1] - 0.02); g.fillStyle = INKS.cream; g.beginPath(); g.moveTo(tx, ty); g.lineTo(tx + 6, ty - 20); g.lineTo(tx + 10, ty); g.fill(); }
    if (H.comb) { const [cx, cy] = px(H.eye[0] - 0.02, H.eye[1] + 0.07); g.fillStyle = H.comb; for (let k = 0; k < 3; k++) { g.beginPath(); g.arc(cx - 8 + k * 8, cy, 6, 0, Math.PI * 2); g.fill(); } const [wx, wy] = px(H.eye[0] + 0.02, H.eye[1] - 0.08); g.beginPath(); g.ellipse(wx, wy, 5, 8, 0, 0, Math.PI * 2); g.fill(); }
    if (H.beak) { const [kx, ky] = px(0.1, 0.09); g.fillStyle = H.beak; g.beginPath(); g.moveTo(kx, ky - 6); g.lineTo(kx + 16, ky); g.lineTo(kx, ky + 6); g.fill(); }
  }, 0.025, { depth: out.headDepth, z: snout, wall: [(Math.min(...hxs) + Math.max(...hxs)) / 2, Math.max(...hys) - 0.06] });
  out.ears = (sp.ears || []).map((e) => card(e.pts, e.base, (g, px) => { const c = e.pts.reduce((a, p) => [a[0] + p[0] / e.pts.length, a[1] + p[1] / e.pts.length], [0, 0]); const [x, y] = px(c[0], c[1]); g.fillStyle = e.inner; g.beginPath(); g.ellipse(x, y, 6, 14, 0.2, 0, Math.PI * 2); g.fill(); }, 0.02));
  out.legs = sp.legs.map((l) => card(leg(l.w, l.len, l.hoof || 0), l.color || tone(H.base, l.near ? 0.95 : 0.78), (g, px) => {
    if (l.hoof) { const [a, b] = px(-l.w, -l.len), [c2, d] = px(l.w, -l.len + l.hoof); g.fillStyle = INKS.dark; g.fillRect(a, d, c2 - a, b - d); }
  }, 0.02, { depth: l.w * 0.95, z: () => 1, wall: [0, -l.len * 0.4] }));
  if (sp.tail) out.tail = card(sp.tail.pts, sp.tail.base, sp.tail.tip ? (g, px) => { const [x, y] = px(-0.31, -0.17); g.fillStyle = sp.tail.tip; g.beginPath(); g.ellipse(x, y, 16, 12, 0.6, 0, Math.PI * 2); g.fill(); } : null, 0.02);
  return (CACHE[name] = out);
}

// ---------------------------------------------------------------- the puppet

export class Puppet {
  constructor(name, scale = 1, modelName = null) {
    this.name = name;
    this.sp = SPECIES[name];
    const k = kit(name);
    const g = (this.group = new THREE.Group());
    // A paper model animal: one solid, rounded body shell (barrel-chested, slimmer at belly and rump), one solid head
    // narrowing to the snout, four square-ish legs at its corners, an ear each side, printed all over. It reads from
    // every side, and it turns to face the way it goes (`flip` is the heading; the name stays for older code).
    this.flip = new THREE.Group();
    this.rig = new THREE.Group();  // bobs, leans, lunges
    g.add(this.flip); this.flip.add(this.rig);
    this.rig.scale.setScalar(scale);
    const mesh = (part, shadow = false) => { const m = new THREE.Mesh(part.geometry, part.material); m.castShadow = shadow; m.receiveShadow = true; return m; };
    const sp = this.sp, BD = k.bodyDepth, HD = k.headDepth;
    this.body = new THREE.Group(); this.rig.add(this.body);
    this.body.add(mesh(k.body, true));
    // legs on pivots at the body's sides: near legs on the near side, far legs on the far side
    this.legs = sp.legs.map((l, i) => {
      const p = new THREE.Group(); p.position.set(l.x, l.y, (l.near ? 1 : -1) * BD * 0.3);
      p.add(mesh(k.legs[i], true)); this.rig.add(p); p.userData.near = !!l.near; p.userData.idx = i;
      return p;
    });
    const H = sp.head;
    this.head = new THREE.Group(); this.head.position.set(H.pivot[0], H.pivot[1], 0); this.rig.add(this.head);
    this.head.add(mesh(k.head, true));
    // one ear on each side of the head (a single ear in the species data is the pair)
    this.ears = [];
    const earList = sp.ears || [];
    const sides = earList.length >= 2 ? earList.map((e, i) => [e, i, i === 0 ? 1 : -1]) : earList.flatMap((e, i) => [[e, i, 1], [e, i, -1]]);
    for (const [e, i, sd] of sides) {
      const p = new THREE.Group(); p.position.set(e.pivot[0] - H.pivot[0], e.pivot[1] - H.pivot[1], sd * HD * 0.38); p.rotation.x = -sd * 0.3;
      p.add(mesh(k.ears[i], true)); this.head.add(p); this.ears.push(p);
    }
    if (k.tail) { this.tail = new THREE.Group(); this.tail.position.set(sp.tail.pivot[0], sp.tail.pivot[1], 0); this.tail.add(mesh(k.tail, true)); this.rig.add(this.tail); }
    this.heading = null; this._last = new THREE.Vector3(); this._has = false;
    this.phase = Math.random() * 6;
    this.t = Math.random() * 10;
    this.graze = 0;
    const src = animalModel(modelName || 'animal_' + name) || propModel(modelName || 'animal_' + name); // (a still model too: it turns, rises and lunges with the puppet, without walk clips) // (a calf is a small cow puppet wearing the calf)
    if (src) this.wear(src);
  }

  /**
   * Wear the animal made from the reference art (Meshy, rigged with a walk and a run) in place of the paper shell:
   * sized to the shell, turned so its nose leads the way the puppet goes, its clips played by speed. The pivots
   * (head, legs, tail) stay for the code that pokes them; only their paper is hidden.
   */
  wear(src) {
    this.rig.updateWorldMatrix(true, true);
    const size = new THREE.Box3().setFromObject(this.rig).getSize(new THREE.Vector3()).divideScalar(this.rig.scale.x);
    for (const g of [this.body, this.head, ...this.legs, this.tail]) g?.traverse((o) => { if (o.isMesh) o.visible = false; });
    const m = SkeletonUtils.clone(src.scene), turn = new THREE.Group();
    turn.rotation.y = Math.PI / 2; // the model's front (+Z) to the puppet's (+X)
    turn.scale.setScalar((Math.max(size.x, size.y) * 1.05) / 2); // (Meshy's animals come fitted in a 2 m box)
    // Meshy's rig stands on its hips: lift it until its lowest toe (plus the paw under it) meets the ground
    m.updateWorldMatrix(true, true); let low = 0; const w = new THREE.Vector3();
    m.traverse((o) => { if (o.isBone) { o.getWorldPosition(w); low = Math.min(low, m.worldToLocal(w).y); } });
    if (low === 0) { m.updateWorldMatrix(true, true); low = new THREE.Box3().setFromObject(m).min.y - 0.05; } // (no bones: stand it on its lowest point)
    m.position.y = -low + 0.05;
    turn.add(m); this.rig.add(turn); this.model = m;
    this.mixer = new THREE.AnimationMixer(m); this.acts = {};
    for (const c of src.clips) { const a = this.mixer.clipAction(c); a.play(); a.setEffectiveWeight(0); this.acts[c.name] = a; }
    this.mw = 0; this.rw = 0;
  }

  /**
   * speed: m/s along the ground; state: 'idle' | 'walk' | 'flee' | 'chase' | 'attack';
   * left: walking toward screen-left (show the mirrored back); yawToCam: card yaw facing the camera.
   */
  update(dt, speed, state, left, yawToCam, lunge = 0) {
    this.t += dt;
    if (this.mixer) { // the model: walk and run blended by speed, easing back to its standing pose when still
      const A = this.acts, fast = speed > (this.sp?.gait === 'hop' ? 1.2 : 3.2) || state === 'flee' || state === 'chase';
      this.mw += ((speed > 0.15 ? 1 : 0) - this.mw) * Math.min(1, dt * 6); this.rw += ((fast ? 1 : 0) - this.rw) * Math.min(1, dt * 4);
      A.walk?.setEffectiveWeight(this.mw * (A.run ? 1 - this.rw : 1)); A.run?.setEffectiveWeight(this.mw * this.rw);
      if (A.walk) A.walk.timeScale = Math.min(1.8, Math.max(0.5, speed / 1.4)); if (A.run) A.run.timeScale = Math.min(1.6, Math.max(0.6, speed / 4));
      this.mixer.update(dt);
      if (this.lop) this.lop.bones.forEach((b, i) => b.scale.copy(this.lop.rest[i]).multiplyScalar(this.lop.k)); // (a lopsided beast: one side's legs drawn short, after the clip)
    }
    const moving = speed > 0.15;
    this.phase += dt * (this.sp.gait === 'hop' ? 8 : 6 + speed * 1.3) * (moving ? 1 : 0.2);
    const s = Math.sin(this.phase);
    let bob = 0, lean = 0;
    if (this.sp.gait === 'hop') {
      bob = moving ? Math.max(0, Math.sin(this.phase)) * (state === 'flee' ? 0.32 : 0.14) : 0;
      lean = moving ? -Math.cos(this.phase) * 0.12 : 0;
      for (const l of this.legs) l.rotation.z = moving ? (l.position.x < 0 ? -1 : 0.5) * Math.max(0, Math.cos(this.phase)) * 0.9 : 0;
    } else {
      const amp = moving ? Math.min(0.75, 0.25 + speed * 0.07) : 0;
      this.legs.forEach((l, i) => { const diag = (i === 0 || i === 3) ? 0 : Math.PI; l.rotation.z = Math.sin(this.phase + diag) * amp; });
      bob = moving ? Math.abs(Math.cos(this.phase)) * 0.03 * Math.min(2, speed / 2) : 0;
    }
    // head: nods while walking; grazes / pecks when idle; lowers to lunge
    if (!moving && state === 'idle') this.graze = Math.min(1, this.graze + dt * 0.8); else this.graze = Math.max(0, this.graze - dt * 3);
    const peck = this.sp.gait === 'peck' ? Math.max(0, Math.sin(this.t * 5)) * 0.6 : 0;
    this.head.rotation.z = -this.graze * (this.sp.gait === 'peck' ? peck : 0.7) + (moving ? s * 0.05 : Math.sin(this.t * 0.7) * 0.04) - lunge * 0.5;
    for (const e of this.ears) e.rotation.z = Math.sin(this.t * 1.7 + this.phase) * 0.12 + (state === 'flee' ? -0.4 : 0);
    if (this.tail) this.tail.rotation.z = state === 'chase' || state === 'attack' ? Math.sin(this.t * 9) * 0.25 : Math.sin(this.t * 2.3) * 0.15 + (state === 'flee' ? 0.6 : 0);
    this.rig.position.set(lunge * 0.3, bob, 0);
    this.rig.rotation.z = lean - lunge * 0.15;
    if (this.lop) { this.rig.rotation.x = this.lop.roll; this.rig.position.y -= this.lop.drop; } // (listing toward its short legs, paws on the ground)
    // face the way it's going: the heading follows how the puppet actually moved (smoothly, a quarter-turn a beat);
    // until it first moves it stands broadside to the camera, as the cards used to
    const pos = this.group.position;
    if (this._has) {
      const dx = pos.x - this._last.x, dz = pos.z - this._last.z, d2 = dx * dx + dz * dz;
      if (d2 > 1e-6 && d2 < 4) {
        const want = Math.atan2(dx, dz) - Math.PI / 2;
        if (this.heading === null) this.heading = want;
        let dh = want - this.heading; dh = Math.atan2(Math.sin(dh), Math.cos(dh));
        this.heading += dh * Math.min(1, dt * 6);
      }
    }
    this._last.copy(pos); this._has = true;
    this.flip.rotation.y = this.heading ?? yawToCam + (left ? Math.PI : 0);
  }

  /**
   * How far the model stands up: 1 standing, 0 pressed flat and spread on the page like a squashed paper model,
   * above 1 for a springy overshoot.
   */
  setFold(f) { this.flip.scale.y = 0.06 + 0.94 * Math.max(0, f); this.flip.scale.z = 1 + 0.6 * (1 - Math.min(1, Math.max(0, f))); } // flat: pressed down and spread

  /** Turn shadow casting on (near the camera) or off (further away) for the parts that cast one. */
  setShadows(on) {
    this._casters ||= []; if (!this._casters.length) this.group.traverse((o) => { if (o.isMesh && o.castShadow) this._casters.push(o); });
    for (const m of this._casters) m.castShadow = on;
  }

  dispose(scene) { scene.remove(this.group); }
}
