// Climbable structures: things in the world register decks you can stand and walk on (flat, or following a curve
// like the top of the stone arch) and ladders (or scrambles) that carry you between the ground and a deck. E at the
// foot of a ladder climbs it; E at its head on the deck climbs down. Railed decks keep you on them; open ones (the
// arch) you can simply walk off and drop to the ground below.
import * as THREE from 'three/webgpu';

const _a = new THREE.Vector3();

export class Climbs {
  constructor() { this.sets = new Map(); }

  /**
   * Register a structure placed at (x, y, z), turned `rot` about y. `spec`:
   *   decks:   [{ x, z, hw, hd, y, yAt?(lx), rail? }]  local box (half width along x, half depth along z), height y
   *            above the placement (or yAt(local x) for a curved top)
   *   ladders: [{ foot: [x, y, z], via?: [[x, y, z]...], top: [x, y, z], land: [x, z], name }]  local points (y above
 *            the placement); `via` are points on the way up between the foot and the top (round a stock tank...)
   */
  add(key, x, y, z, rot, spec) {
    const c = Math.cos(rot), s = Math.sin(rot);
    const w = (lx, ly, lz) => new THREE.Vector3(x + lx * c + lz * s, y + ly, z - lx * s + lz * c);
    const set = { x, z, c, s, y, decks: spec.decks || [], ladders: [] };
    for (const L of spec.ladders || []) {
      const foot = w(...L.foot), top = w(...L.top), land = w(L.land[0], L.top[1], L.land[1]);
      const via = (L.via || []).map((p) => w(...p)), first = via[0] || top;
      set.ladders.push({ foot, via, top, land, name: L.name, face: Math.atan2(top.x - first.x, top.z - first.z) });
    }
    this.sets.set(key, set);
  }
  remove(key) { this.sets.delete(key); }

  /** Each deck that covers (x, z), with its surface height there: fn(deck, set, lx, lz, top). */
  each(x, z, fn) {
    for (const set of this.sets.values()) {
      const dx = x - set.x, dz = z - set.z;
      if (dx * dx + dz * dz > 400) continue;
      const lx = dx * set.c - dz * set.s, lz = dx * set.s + dz * set.c; // world -> local (inverse of the turn)
      for (const d of set.decks) {
        const ux = lx - d.x, uz = lz - d.z;
        if (Math.abs(ux) > d.hw || Math.abs(uz) > d.hd) continue;
        fn(d, set, ux, uz, set.y + (d.yAt ? d.yAt(lx) : d.y));
      }
    }
  }

  /** The highest deck surface under (x, z) that you could step up onto from height y (or -Infinity). */
  surfaceAt(x, z, y) {
    let best = -Infinity;
    this.each(x, z, (d, set, ux, uz, top) => { if (top <= y + 0.65 && top > best) best = top; });
    return best;
  }

  /** The deck you're standing on at pos, if any: { deck, set, top }. */
  standing(pos) {
    let out = null;
    this.each(pos.x, pos.z, (deck, set, ux, uz, top) => { if (Math.abs(pos.y - top) < 0.3 && (!out || top > out.top)) out = { deck, set, top }; });
    return out;
  }

  /** Keep you on a railed deck you were standing on: step back to where you were if this step leaves it. */
  keepOn(pos, prevX, prevZ, was) {
    if (!was?.deck.rail) return;
    let still = false;
    this.each(pos.x, pos.z, (d) => { if (d === was.deck) still = true; });
    if (!still) { pos.x = prevX; pos.z = prevZ; }
  }

  /** A ladder you can use from pos: { ladder, up } (at its foot on the ground, or at its head on the deck). */
  ladderAt(pos) {
    for (const set of this.sets.values()) for (const L of set.ladders) {
      if (Math.hypot(pos.x - L.foot.x, pos.z - L.foot.z) < 1.4 && Math.abs(pos.y - L.foot.y) < 1.6) return { ladder: L, up: true };
      if (Math.hypot(pos.x - L.land.x, pos.z - L.land.z) < 1.2 && Math.abs(pos.y - L.top.y) < 0.4) return { ladder: L, up: false };
    }
    return null;
  }

  /** The path for a climb: three points (and how long it takes). */
  path({ ladder: L, up }, pos) {
    const from = _a.copy(pos);
    const via = L.via.map((p) => p.clone());
    const pts = up ? [from.clone(), L.foot.clone(), ...via, L.top.clone(), L.land.clone()] : [from.clone(), L.top.clone(), ...via.reverse(), L.foot.clone()];
    let len = 0; for (let i = 1; i < pts.length; i++) len += pts[i].distanceTo(pts[i - 1]);
    return { pts, len, dur: Math.max(1.2, len / (up ? 2.4 : 3.2)), face: L.face };
  }
}

/** Where a point is along a path of segments, k in 0..1 of its length. */
export function alongPath(pts, len, k, out) {
  let d = k * len;
  for (let i = 1; i < pts.length; i++) {
    const seg = pts[i].distanceTo(pts[i - 1]);
    if (d <= seg || i === pts.length - 1) return out.lerpVectors(pts[i - 1], pts[i], seg > 0 ? Math.min(1, d / seg) : 1);
    d -= seg;
  }
  return out.copy(pts[pts.length - 1]);
}
