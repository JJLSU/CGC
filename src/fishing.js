// Fishing from the bank: with a willow pole, face the water and click to cast. A red-and-cream paper bobber
// rides the water on a sagging line; when it ducks under (a bite), click quickly to reel in a fish.
// Cheap: one tiny bobber, one thin pole and a 12-point line, all hidden unless you're fishing.
import * as THREE from 'three/webgpu';
import { isWater, getHeight } from './world.js';
import { paperMaterial, cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';

const FISH = ['a whiskered catfish', 'a speckled brook trout', 'a pumpkinseed sunfish', 'a bigmouth bass', 'a fat yellow perch', 'a bluegill no bigger than your hand'];
const N = 12;

export class Fishing {
  constructor(scene) {
    this.state = 'idle'; // idle · cast · wait · bite
    this.t = 0;
    this.timer = 0;
    this.onCatch = null; this.onBite = null; this.onCast = null; this.onMiss = null;
    this.target = new THREE.Vector3();
    this.from = new THREE.Vector3();
    this.castAt = new THREE.Vector3();

    const red = paperMaterial({ color: 0xc4402f }), cream = paperMaterial({ color: 0xf1e6cc }), dark = paperMaterial({ color: 0x5a3e2a });
    this.bobber = new THREE.Group();
    const top = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.11, 0.1, 10).translate(0, 0.08, 0), red);
    const bottom = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.07, 0.08, 10).translate(0, -0.01, 0), cream);
    const stick = new THREE.Mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.14, 5).translate(0, 0.19, 0), dark);
    for (const m of [top, bottom, stick]) { m.castShadow = true; this.bobber.add(m); }
    this.bobber.visible = false;
    scene.add(this.bobber);

    this.pole = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.03, 1, 5).translate(0, 0.5, 0), dark);
    this.pole.castShadow = true;
    this.pole.visible = false;
    scene.add(this.pole);

    // the line: a thin twine ribbon (a 1-pixel line vanishes at game zoom), turned to face the camera
    this.linePts = Array.from({ length: N }, () => new THREE.Vector3());
    this.linePos = new Float32Array(N * 2 * 3);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.linePos, 3));
    const idx = []; for (let i = 0; i < N - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    g.setIndex(idx);
    this.line = new THREE.Mesh(g, new THREE.MeshBasicNodeMaterial({ color: 0x4a3828, side: THREE.DoubleSide }));
    this.line.frustumCulled = false;
    this.line.visible = false;
    scene.add(this.line);
    this.camera = null; // set by the game, to turn the twine toward the lens

    // ripples: flat cream rings spreading on the water where the bobber lands or a fish tugs
    this.ripples = [0, 1, 2].map(() => {
      const m = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 28).rotateX(-Math.PI / 2), new THREE.MeshBasicNodeMaterial({ color: 0xf3ead6, transparent: true, depthWrite: false }));
      m.visible = false; scene.add(m); return { m, t: 9 };
    });
    // the catch: a printed fish card that leaps from the water to the farmer
    const fishPts = [[0.3, 0], [0.18, 0.08], [0, 0.1], [-0.18, 0.06], [-0.26, 0.1], [-0.3, 0.1], [-0.25, 0], [-0.3, -0.1], [-0.26, -0.1], [-0.18, -0.06], [0, -0.1], [0.18, -0.08]];
    const fishArt = paintCard(fishPts, {
      W: 192, H: 96, seed: 131, base: '#8fa3a0', fills: ['rgba(143,163,160,A)', 'rgba(120,140,136,A)', 'rgba(170,184,176,A)'], edge: 'rgba(50,66,64,1)',
      details(c, px) {
        const [x0, y0] = px(-0.2, 0.0), [x1] = px(0.22, 0); c.fillStyle = 'rgba(70,96,80,0.6)'; c.fillRect(x0, y0 - 22, x1 - x0, 14); // a darker back
        c.fillStyle = 'rgba(230,180,90,0.7)'; for (let k = 0; k < 6; k++) { const [sx, sy] = px(-0.12 + k * 0.05, -0.02 + (k % 2) * 0.03); c.beginPath(); c.arc(sx, sy, 3, 0, Math.PI * 2); c.fill(); }
        const [ex, ey] = px(0.2, 0.02); c.fillStyle = '#2b2018'; c.beginPath(); c.arc(ex, ey, 4, 0, Math.PI * 2); c.fill();
      },
    });
    this.fish = new THREE.Mesh(cardGeometry(fishPts, 0.02), cardMaterial(fishArt));
    this.fish.scale.setScalar(1.4); this.fish.visible = false; this.fish.castShadow = true;
    scene.add(this.fish);
    this.leap = { t: 9, from: new THREE.Vector3(), to: new THREE.Vector3() };
    // fish jumping in the ponds: a printed fish flips up out of the water and back, leaving rings, and for half
    // a minute the fish bite sooner there (cast near the rings)
    this.jumper = new THREE.Mesh(this.fish.geometry, this.fish.material);
    this.jumper.scale.setScalar(1.2); this.jumper.visible = false; this.jumper.castShadow = true;
    scene.add(this.jumper);
    this.jump = { t: 9, next: 6 + Math.random() * 8, from: new THREE.Vector3(), to: new THREE.Vector3() };
    this.hot = []; // { x, z, until }
    this.clock = 0;
    this.onJump = null;
  }

  /** Now and then a fish jumps in the water near the farmer. */
  updateJumps(dt, player) {
    this.clock += dt;
    const J = this.jump;
    if (J.t < 0.8) {
      J.t += dt;
      const k = Math.min(1, J.t / 0.8);
      this.jumper.position.lerpVectors(J.from, J.to, k); this.jumper.position.y += Math.sin(k * Math.PI) * 0.9;
      this.jumper.rotation.set(0, Math.atan2(J.to.x - J.from.x, J.to.z - J.from.z) - Math.PI / 2, Math.cos(k * Math.PI) * 1.2);
      if (k >= 1) { this.jumper.visible = false; this.ripple(J.to); }
      return;
    }
    if ((J.next -= dt) > 0) return;
    J.next = 9 + Math.random() * 16;
    for (let tries = 0; tries < 10; tries++) {
      const a = Math.random() * Math.PI * 2, d = 6 + Math.random() * 16;
      const x = player.pos.x + Math.cos(a) * d, z = player.pos.z + Math.sin(a) * d;
      const b = a + (Math.random() - 0.5), x2 = x + Math.cos(b) * 1.3, z2 = z + Math.sin(b) * 1.3;
      if (!isWater(x, z) || !isWater(x2, z2)) continue;
      J.from.set(x, getHeight(x, z) + 0.02, z); J.to.set(x2, getHeight(x2, z2) + 0.02, z2);
      J.t = 0; this.jumper.visible = true; this.ripple(J.from);
      this.hot = this.hot.filter((h) => h.until > this.clock); this.hot.push({ x: x2, z: z2, until: this.clock + 30 });
      this.onJump?.();
      return;
    }
  }

  /** Is this spot near where a fish jumped lately? */
  hotAt(p) { return this.hot.some((h) => h.until > this.clock && Math.hypot(h.x - p.x, h.z - p.z) < 3.5); }

  ripple(at) {
    const r = this.ripples.reduce((a, b) => (b.t > a.t ? b : a));
    r.t = 0; r.m.position.set(at.x, at.y + 0.03, at.z); r.m.visible = true;
  }

  /** ripples spread and fade; a caught fish arcs up and into the farmer's hands */
  updateFx(dt, player) {
    for (const r of this.ripples) {
      if (r.t > 1.4) { r.m.visible = false; continue; }
      r.t += dt;
      const k = r.t / 1.4;
      r.m.scale.setScalar(0.15 + k * 0.9);
      r.m.material.opacity = 0.7 * (1 - k);
    }
    const L = this.leap;
    if (L.t < 0.8) {
      L.t += dt;
      const k = Math.min(1, L.t / 0.8);
      L.to.set(player.pos.x, player.pos.y + 1.2, player.pos.z);
      this.fish.position.lerpVectors(L.from, L.to, k); this.fish.position.y += Math.sin(k * Math.PI) * 2.2;
      this.fish.rotation.set(0, Math.atan2(L.to.x - L.from.x, L.to.z - L.from.z) - Math.PI / 2, Math.cos(k * Math.PI) * 1.1);
      this.fish.visible = k < 1;
    }
  }

  /** Where a cast from here would land (water a few metres ahead, standing on dry land), or null. */
  spot(player, tools) {
    if (!tools.has('rod') || (isWater(player.pos.x, player.pos.z) && !player.onDeck)) return null; // the bank, or a dock
    const f = player.forward(_f);
    for (const d of [3.5, 5, 6.5]) {
      const x = player.pos.x + f.x * d, z = player.pos.z + f.z * d;
      if (isWater(x, z) && isWater(x + f.x, z + f.z)) return _spot.set(x, 0, z);
    }
    return null;
  }

  stop() {
    this.state = 'idle';
    this.bobber.visible = this.pole.visible = this.line.visible = false;
  }

  /** Returns { engaged, hint }: engaged means the click belongs to fishing (no axe swing). */
  update(dt, player, input, allowed, spot) {
    this.updateFx(dt, player);
    this.updateJumps(dt, player);
    if (!allowed) { if (this.state !== 'idle') this.stop(); return NONE; }
    if (this.state !== 'idle' && player.pos.distanceTo(this.castAt) > 1.2) { this.stop(); return NONE; }
    this.t += dt;
    const click = input.clicked;

    if (this.state === 'idle') {
      if (!spot) return NONE;
      if (click) {
        this.state = 'cast'; this.timer = 0.55;
        this.target.copy(spot); this.target.y = getHeight(spot.x, spot.z) + 0.02;
        this.castAt.copy(player.pos);
        this.bobber.visible = this.pole.visible = this.line.visible = true;
        this.onCast?.();
      } else return { engaged: true, hint: '[LMB] Cast your line' };
    } else if (click && this.state === 'bite') {
      // after dark there's a small chance the bite belongs to Old Whiskers, the catfish of the county's tallest tale
      const legend = (this.night || 0) > 0.6 && Math.random() < (this.legendChance ?? 0.07);
      this.onCatch?.(legend ? 'OLD WHISKERS' : FISH[Math.floor(Math.random() * FISH.length)], legend);
      this.fish.scale.setScalar(legend ? 4.2 : 1.4);
      this.leap.t = 0; this.leap.from.copy(this.bobber.position); this.ripple(this.target);
      this.stop();
      return { engaged: true, hint: '' };
    } else if (click) {
      this.stop(); // reeled in too early
      return { engaged: true, hint: '' };
    }

    // rod tip: up and out in front of the farmer
    const f = player.forward(_f);
    const hand = _h.set(player.pos.x + f.x * 0.35, player.pos.y + 1.15, player.pos.z + f.z * 0.35);
    const tip = _tip.set(hand.x + f.x * 1.5, hand.y + 1.0, hand.z + f.z * 1.5);
    this.pole.position.copy(hand);
    this.pole.scale.set(1, hand.distanceTo(tip), 1);
    this.pole.quaternion.setFromUnitVectors(UP, _d.subVectors(tip, hand).normalize());

    // bobber (fish bite sooner in the rain)
    this.timer -= this.state === 'wait' ? dt * (1 + (this.rain || 0)) * (this.hotAt(this.target) ? 2.5 : 1) : dt;
    const b = this.bobber.position;
    let hint = 'Waiting for a nibble… (LMB reels in)', sag = 0.45;
    if (this.state === 'cast') {
      const k = 1 - Math.max(0, this.timer) / 0.55;
      b.lerpVectors(tip, this.target, k); b.y += Math.sin(k * Math.PI) * 1.2;
      if (this.timer <= 0) { this.state = 'wait'; this.timer = 2.5 + Math.random() * 4.5; this.ripple(this.target); }
      hint = '';
      sag = 0.1;
    } else if (this.state === 'wait') {
      b.copy(this.target); b.y += Math.sin(this.t * 2.6) * 0.025;
      if (this.timer <= 0) { this.state = 'bite'; this.timer = 1.1; this.onBite?.(); this.ripple(this.target); }
    } else if (this.state === 'bite') {
      b.copy(this.target); b.y -= 0.1 + Math.abs(Math.sin(this.t * 22)) * 0.05;
      hint = '[LMB] A bite! Reel in!';
      sag = 0.08;
      if (this.timer <= 0) { this.state = 'wait'; this.timer = 2 + Math.random() * 4; this.onMiss?.(); }
    }

    // a sagging line from the tip to the bobber
    const P = this.linePts;
    for (let i = 0; i < N; i++) {
      const s = i / (N - 1);
      P[i].set(tip.x + (b.x - tip.x) * s, tip.y + (b.y + 0.25 - tip.y) * s - Math.sin(s * Math.PI) * sag, tip.z + (b.z - tip.z) * s);
    }
    const cam = this.camera?.position || _up;
    for (let i = 0; i < N; i++) {
      const a = P[Math.max(0, i - 1)], c = P[Math.min(N - 1, i + 1)];
      _d.subVectors(c, a).normalize();
      _w.subVectors(cam, P[i]).cross(_d).normalize().multiplyScalar(0.014); // half-width, sideways to the view
      this.linePos.set([P[i].x + _w.x, P[i].y + _w.y, P[i].z + _w.z, P[i].x - _w.x, P[i].y - _w.y, P[i].z - _w.z], i * 6);
    }
    this.line.geometry.attributes.position.needsUpdate = true;
    return { engaged: true, hint };
  }
}

const NONE = { engaged: false, hint: '' };
const UP = new THREE.Vector3(0, 1, 0);
const _w = new THREE.Vector3(), _up = new THREE.Vector3(0, 50, 0);
const _f = new THREE.Vector3(), _spot = new THREE.Vector3(), _h = new THREE.Vector3(), _tip = new THREE.Vector3(), _d = new THREE.Vector3();
