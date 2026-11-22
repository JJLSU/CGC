// The barn dance: on the evening of County Fair day (from 19:00 till about 23:30) the county comes to dance in
// front of the red barn. A string of paper lanterns glows between two poles and the barn's corner, a fiddler
// saws away on a hay bale, and three paper couples (die-cut, crossed so they read from any side) whirl round
// the floor, spinning as they go. Stand by the floor and press E to join in: the farmer swings round for a
// reel and comes away rested. The tune is a soft reel, heard only near the barn.
import * as THREE from 'three/webgpu';
import { Folk } from './folk.js';
import { ModelFigure, hasFolk } from './modelfolk.js';
import { uniform, vec3, texture, uv } from 'three/tsl';
import { cardMaterial, paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight, springRise } from './world.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
// twice a week: the night of the County Fair (every seventh day) and a midweek dance three days after it; from
// half past five in the evening till three in the morning (a night that runs past midnight still counts as its own)
export const isDanceNight = (day) => day % 7 === 0 || day % 7 === 3;
export const DANCE_FROM = 17.5 / 24, DANCE_TILL = 3 / 24;
/** The day number of the dance night under way at this hour (after midnight, it's still last night's). */
export const danceNightOf = (sky) => (sky.time < DANCE_TILL ? sky.day - 1 : sky.day);

const MAN = [[-0.12, 0], [-0.04, 0], [-0.03, 0.7], [0.03, 0.7], [0.04, 0], [0.12, 0], [0.13, 0.8], [0.19, 1.25], [0.1, 1.33], [0.07, 1.38], [0.1, 1.5], [0.15, 1.52], [0.15, 1.56], [0.0, 1.66], [-0.15, 1.56], [-0.15, 1.52], [-0.1, 1.5], [-0.07, 1.38], [-0.1, 1.33], [-0.19, 1.25], [-0.13, 0.8]];
const WOMAN = [[-0.32, 0], [0.32, 0], [0.13, 0.85], [0.18, 1.24], [0.1, 1.32], [0.07, 1.37], [0.11, 1.5], [0.06, 1.6], [0.0, 1.62], [-0.06, 1.6], [-0.13, 1.56], [-0.11, 1.5], [-0.07, 1.37], [-0.1, 1.32], [-0.18, 1.24], [-0.13, 0.85]];
// a lively reel in D (MIDI), one note per eighth
export const REEL = [62, 66, 69, 66, 62, 66, 69, 74, 73, 69, 71, 73, 74, 69, 66, 69, 67, 71, 74, 71, 67, 71, 74, 76, 74, 73, 71, 69, 66, 64, 62, 62];
export const hz = (m) => 440 * 2 ** ((m - 69) / 12);

function person(pts, paint, seed) {
  return paintCard(pts, { W: 128, H: 256, seed, base: paint.base, fills: [`rgba(${paint.rgb},A)`], edge: 'rgba(40,30,24,1)', details: paint.draw });
}
const crossedCard = (pts) => mergeGeometries([cardGeometry(pts, 0.025), cardGeometry(pts, 0.025).rotateY(Math.PI / 2)]);

export class BarnDance {
  constructor(scene, center, spot = null) {
    // in front of the barn doors (the barn stands at C + (-10, -7), turned -0.25)
    const fx = -Math.sin(0.25), fz = Math.cos(0.25);
    const bx = center.x - 10, bz = center.z - 7;
    // in Paydirt Hollow: out in the street before the livery barn's doors (spot)
    this.at = spot ? new THREE.Vector3(spot.x, 0, spot.z) : new THREE.Vector3(bx + fx * 6, 0, bz + fz * 6); this.at.y = getHeight(this.at.x, this.at.z);
    const g = (this.group = new THREE.Group()); g.position.copy(this.at); g.rotation.y = spot ? Math.atan2(spot.look.x - spot.x, spot.look.z - spot.z) : -0.25;
    this.hinge = new THREE.Group(); g.add(this.hinge);
    // the dancers
    const shirt = (col, trim) => ({ base: col, rgb: '120,60,50', draw(c, px) {
      c.fillStyle = '#3f5f8a'; { const [a, b] = px(-0.14, 0.78), [d, e] = px(0.14, 0); c.fillRect(a, b, d - a, e - b); } // denim
      c.fillStyle = trim; for (let k = 0; k < 4; k++) { const [a, b] = px(-0.2 + k * 0.1, 1.28), [, e] = px(0, 0.8); c.fillRect(a, b, 4, e - b); } // plaid lines
      c.fillStyle = '#f0d6b8'; { const [a, b] = px(0, 1.44); c.beginPath(); c.arc(a, b, 14, 0, Math.PI * 2); c.fill(); }
      c.fillStyle = '#6b4a30'; { const [a, b] = px(-0.15, 1.56), [d, e] = px(0.15, 1.5); c.fillRect(a, b, d - a, e - b); const [h1, h2] = px(-0.08, 1.66); c.fillRect(h1, h2, 20, 16); } // hat
    } });
    const dress = (col, dot) => ({ base: col, rgb: '150,70,60', draw(c, px, r) {
      c.fillStyle = dot; for (let k = 0; k < 40; k++) { const [a, b] = px(-0.25 + r() * 0.5, 0.05 + r() * 1.15); c.beginPath(); c.arc(a, b, 2.5, 0, Math.PI * 2); c.fill(); } // calico sprig
      c.fillStyle = '#efe3c4'; { const [a, b] = px(-0.12, 0.9), [d, e] = px(0.12, 0.2); c.fillRect(a, b, d - a, e - b); } // apron
      c.fillStyle = '#f0d6b8'; { const [a, b] = px(0, 1.45); c.beginPath(); c.arc(a, b, 13, 0, Math.PI * 2); c.fill(); }
      c.fillStyle = '#8a5a30'; { const [a, b] = px(0.05, 1.58); c.beginPath(); c.arc(a, b, 9, 0, Math.PI * 2); c.fill(); } // hair bun
    } });
    const looks = [[shirt('#b5473a', '#7a2a24'), dress('#c4574a', '#f3e6cc')], [shirt('#6f8a5a', '#3f5a34'), dress('#4f6f96', '#efe3c4')], [shirt('#d9a441', '#9a7030'), dress('#8a74a8', '#f3e6cc')]];
    void looks;
    const DOLLS = [[0xb5473a, 0xc4574a, 0xa86a3a], [0x6f8a5a, 0x4f6f96, 0x3a2a20], [0xd9a441, 0x8a74a8, 0x8a5a30]];
    this.couples = DOLLS.map(([shirtC, dressC, hairC], i) => {
      const pair = new THREE.Group();
      // the three farmhands and three calico women from the reference art (each drawn alone, so none came out fused)
      const mm = `folk_farmhand_0${i + 1}`, wm = `folk_calico_0${i + 1}`;
      const man = hasFolk(mm) ? new ModelFigure(mm) : new Folk({ coat: shirtC, coatPat: 1, sleeve: 0xefe3c4, pants: 0x3f5f8a, hat: i === 1 ? 'cap' : 'straw', hatColor: 0x5a3e2a, beard: i === 2 ? 0x8a5a30 : undefined, scale: 0.9 });
      const wom = hasFolk(wm) ? new ModelFigure(wm) : new Folk({ coat: dressC, dress: dressC, dressPat: 2, apron: 0xefe3c4, hair: hairC, bun: true, cheeks: true, scale: 0.85 });
      man.root.position.x = -0.3; wom.root.position.x = 0.3; man.root.rotation.y = Math.PI / 2; wom.root.rotation.y = -Math.PI / 2;
      pair.add(man.root, wom.root);
      this.hinge.add(pair);
      return { pair, man, wom, ph: (i / 3) * Math.PI * 2 };
    });
    // the fiddler on a hay bale, his bow arm sawing
    const bale = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.45, 0.8, 12).rotateZ(Math.PI / 2), paperMaterial({ color: 0xd2b064 }));
    bale.position.set(-2.8, 0.45, -1.2); bale.castShadow = true; this.hinge.add(bale);
    this.fiddlerDoll = hasFolk('folk_fiddler') ? new ModelFigure('folk_fiddler') : new Folk({ coat: 0x5a3e2a, vest: 0x2b2018, sleeve: 0xefe3c4, pants: 0x4a4038, beard: 0x6b4a30, hat: 'straw', band: 0x2b2018, hold: 'bow', scale: 0.85 });
    this.fiddlerDoll.root.position.set(-2.8, this.fiddlerDoll instanceof ModelFigure ? 0.42 : 0.1, -1.05); /* (the model sits with its own sitting clip, on the bale's top) */ // hips on the top of the bale this.fiddlerDoll.root.rotation.y = 0.5;
    for (const l of this.fiddlerDoll.legs) l.rotation.x = -1.4; // sitting on the bale
    this.hinge.add(this.fiddlerDoll.root);
    this.fiddler = this.fiddlerDoll.root;
    // poles and a string of glowing paper lanterns
    this.glow = uniform(0);
    const poles = mergeGeometries([new THREE.BoxGeometry(0.08, 3.0, 0.08).translate(-3.2, 1.5, 1.6), new THREE.BoxGeometry(0.08, 3.0, 0.08).translate(3.2, 1.5, 1.6)]);
    const pm = new THREE.Mesh(poles, paperMaterial({ color: 0x6b4a30 })); pm.castShadow = true; this.hinge.add(pm);
    const lanternGeo = new THREE.CylinderGeometry(0.13, 0.13, 0.24, 8);
    [0xe07a3a, 0xe8c050, 0xc4574a].forEach((col, k) => {
      const geos = [];
      for (let i = k; i < 15; i += 3) {
        const u = i / 14, x = -3.2 + u * 6.4, y = 2.8 - Math.sin(u * Math.PI) * 0.6, z = 1.6 - Math.sin(u * Math.PI) * 1.2;
        geos.push(lanternGeo.clone().translate(x, y, z));
      }
      const m = new THREE.MeshBasicNodeMaterial();
      const c = new THREE.Color(col);
      m.colorNode = vec3(c.r, c.g, c.b).mul(this.glow.mul(1.6).add(0.5));
      this.hinge.add(new THREE.Mesh(mergeGeometries(geos), m));
    });
    // the lanterns' warm light on the dancers (made at load, so it joins the night lighting set-up)
    this.light = new THREE.PointLight(0xffb070, 0, 10, 1); this.light.position.set(0, 2.4, 0.8); g.add(this.light);
    g.visible = false; scene.add(g);
    this.up = 0; this.t = 0; this.shown = false; this.beat = 0; this.note = 0;
    this.spinT = 0;
    this.onNote = null;
  }

  live(sky) { return isDanceNight(danceNightOf(sky)) && (sky.time >= DANCE_FROM || sky.time < DANCE_TILL); }
  near(pos, r = 3.6) { return this.shown && this.up > 0.9 && Math.hypot(pos.x - this.at.x, pos.z - this.at.z) < r; }

  update(dt, sky, player) {
    this.t += dt;
    const want = this.live(sky);
    if (want && !this.shown) { this.shown = true; this.up = 0; this.group.visible = true; }
    if (!this.shown) return;
    this.up = want ? Math.min(1.5, this.up + dt * 0.8) : this.up - dt * 1.2;
    const k = want ? springRise(this.up) : Math.max(0, this.up) ** 2;
    this.hinge.rotation.x = -(1 - k) * (Math.PI / 2);
    if (!want && this.up <= 0) { this.shown = false; this.group.visible = false; this.light.intensity = 0; return; }
    this.glow.value = Math.min(1, sky.night * 1.4);
    this.light.intensity = 4.5 * this.glow.value * k;
    // the couples whirl round the floor, each pair spinning on its own as it goes
    const t = this.t;
    for (const c of this.couples) {
      const a = t * 0.55 + c.ph;
      c.pair.position.set(Math.cos(a) * 1.4, Math.abs(Math.sin(t * 4.4 + c.ph)) * 0.06, Math.sin(a) * 1.0 + 0.2);
      c.pair.rotation.y = t * 2.2 + c.ph;
      c.man.update(dt, 1.2, 'dance'); c.wom.update(dt, 1.2, 'dance');
    }
    this.fiddlerDoll.update(dt, 0, this.fiddlerDoll instanceof ModelFigure ? 'sit' : 'fiddle');
    for (const l of this.fiddlerDoll.legs) l.rotation.x = -1.4 + Math.sin(t * 8.8) * 0.06; // tapping his foot
    // the reel, an eighth note every 0.17 s, heard only near the barn
    const d = Math.hypot(player.pos.x - this.at.x, player.pos.z - this.at.z);
    if (want && d < 28 && (this.beat -= dt) <= 0) {
      this.beat += 0.17;
      const m = REEL[this.note++ % REEL.length];
      this.onNote?.(hz(m), 0.2, Math.max(0, 1 - d / 28));
    }
  }
}
