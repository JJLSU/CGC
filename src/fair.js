// The County Fair: every seventh day (Day 7, 14, 21…) from 07:00 till 19:00, a judging table goes up just south
// of the farm lane. It's a trestle with a gingham cloth under strings of red, cream and blue bunting, a
// hand-lettered sign, and the judge herself, Mrs. Pruitt, a paper doll in her Sunday hat with a clipboard. It hinges up out
// of the grass that morning and folds away at dusk. Press E at the table to enter the classes (pies, bread,
// honey, fleece, pumpkins, and a fish story); each class takes one entry per fair and pays a prize and a
// ribbon. Every ribbon you've won is pinned as a little rosette along the farmhouse porch beam.
import * as THREE from 'three/webgpu';
import { Folk } from './folk.js';
import { ModelFigure, hasFolk } from './modelfolk.js';
import { cardMaterial, paperMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight, springRise } from './world.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

export const isFairDay = (day) => day % 7 === 0;

const JUDGE = [[-0.22, 0], [0.22, 0], [0.26, 0.5], [0.2, 0.9], [0.3, 1.2], [0.24, 1.3], [0.14, 1.32], [0.12, 1.5], [0.32, 1.56], [0.3, 1.62],
  [0.0, 1.72], [-0.3, 1.62], [-0.32, 1.56], [-0.12, 1.5], [-0.14, 1.32], [-0.22, 1.2], [-0.24, 0.9], [-0.28, 0.5]];
const ROSETTE = (() => {
  const pts = [[0.05, -0.32], [0.09, -0.12], [0.03, -0.1]];
  for (let k = 0; k <= 16; k++) { const a = -Math.PI / 2 + 0.35 + (k / 16) * (Math.PI * 2 - 0.7), r = 0.13 + (k % 2) * 0.025; pts.push([Math.cos(a) * r, Math.sin(a) * r]); }
  pts.push([-0.03, -0.1], [-0.09, -0.12], [-0.05, -0.32], [0, -0.26]);
  return pts.map(([x, y]) => [x, y + 0.32]);
})();

export class Fair {
  constructor(scene, world, center, house, spot = null) {
    // in Paydirt Hollow the judging table stands up the street before the church (spot)
    const x = spot ? spot.x : center.x + 3, z = spot ? spot.z : center.z + 21; const look = spot ? spot.look : center;
    this.at = new THREE.Vector3(x, getHeight(x, z), z);
    world.exclusions.push({ x, z, r: 5 });
    const g = (this.group = new THREE.Group());
    g.position.copy(this.at);
    g.rotation.y = Math.atan2(look.x - x, look.z - z); // the front of the table toward the farm
    this.hinge = new THREE.Group(); g.add(this.hinge);
    const wood = paperMaterial({ color: 0x8a6038 }), dark = paperMaterial({ color: 0x5a3e2a });
    const parts = (list, mat) => { const m = new THREE.Mesh(mergeGeometries(list), mat); m.castShadow = m.receiveShadow = true; this.hinge.add(m); };
    // the trestle: two X legs and a plank top
    const leg = (sx, rot) => new THREE.BoxGeometry(0.07, 1.0, 0.07).rotateX(rot).translate(sx, 0.42, 0);
    parts([leg(-0.9, 0.45), leg(-0.9, -0.45), leg(0.9, 0.45), leg(0.9, -0.45), new THREE.BoxGeometry(0.06, 0.06, 0.7).translate(-0.9, 0.3, 0), new THREE.BoxGeometry(0.06, 0.06, 0.7).translate(0.9, 0.3, 0)], dark);
    // a red-and-cream gingham cloth hanging over the top
    const c = document.createElement('canvas'); c.width = c.height = 128; const gc = c.getContext('2d');
    gc.fillStyle = '#efe3c4'; gc.fillRect(0, 0, 128, 128);
    gc.fillStyle = 'rgba(181,71,58,0.55)'; for (let i = 0; i < 8; i++) { gc.fillRect(i * 16, 0, 8, 128); gc.fillRect(0, i * 16, 128, 8); }
    const ging = new THREE.CanvasTexture(c); ging.colorSpace = THREE.SRGBColorSpace; ging.wrapS = ging.wrapT = THREE.RepeatWrapping; ging.repeat.set(3, 1.5);
    const cloth = new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(2.3, 0.04, 1.0).translate(0, 0.86, 0), new THREE.BoxGeometry(2.3, 0.36, 0.02).translate(0, 0.7, 0.5)]), cardMaterial(ging));
    cloth.castShadow = cloth.receiveShadow = true; this.hinge.add(cloth);
    // entries on the table: a pie, a honey jar, a fleece, a pumpkin (simple folded shapes)
    const pie = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.14, 0.07, 12).translate(-0.7, 0.92, 0.1), paperMaterial({ color: 0xc9915a }));
    const jar = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 0.2, 10).translate(-0.25, 0.98, 0.15), paperMaterial({ color: 0xd9a441 }));
    const fleece = new THREE.Mesh(new THREE.SphereGeometry(0.2, 8, 6).scale(1.3, 0.6, 1).translate(0.25, 0.96, 0.05), paperMaterial({ color: 0xf3ecdc }));
    const pk = new THREE.Mesh(new THREE.SphereGeometry(0.2, 10, 8).scale(1.2, 0.85, 1).translate(0.75, 1.02, 0.05), paperMaterial({ color: 0xde7a32 }));
    for (const m of [pie, jar, fleece, pk]) { m.castShadow = true; this.hinge.add(m); }
    // bunting: two poles and three drooping strings of pennants
    parts([new THREE.BoxGeometry(0.08, 2.6, 0.08).translate(-1.6, 1.3, -0.5), new THREE.BoxGeometry(0.08, 2.6, 0.08).translate(1.6, 1.3, -0.5)], wood);
    const flags = { 0: [], 1: [], 2: [] };
    for (let i = 0; i < 13; i++) {
      const u = i / 12, fx = -1.55 + u * 3.1, fy = 2.5 - Math.sin(u * Math.PI) * 0.35;
      flags[i % 3].push(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(fx - 0.11, fy, -0.5), new THREE.Vector3(fx + 0.11, fy, -0.5), new THREE.Vector3(fx, fy - 0.26, -0.5)]));
    }
    [0xb5473a, 0xefe3c4, 0x4f6f96].forEach((col, k) => {
      const geo = mergeGeometries(flags[k]); geo.computeVertexNormals();
      const m = new THREE.Mesh(geo, paperMaterial({ color: col, side: THREE.DoubleSide })); m.castShadow = true; this.hinge.add(m);
    });
    // the sign, hand-lettered on a cream board
    const sc = document.createElement('canvas'); sc.width = 512; sc.height = 160; const sg = sc.getContext('2d');
    sg.fillStyle = '#efe3c4'; sg.fillRect(0, 0, 512, 160); sg.strokeStyle = '#5a3e2a'; sg.lineWidth = 10; sg.strokeRect(5, 5, 502, 150);
    sg.fillStyle = '#b5473a'; sg.font = 'bold 54px Georgia, serif'; sg.textAlign = 'center'; sg.fillText('COUNTY FAIR', 256, 70);
    sg.fillStyle = '#4f6f96'; sg.font = 'italic 34px Georgia, serif'; sg.fillText('Judging Today · All Welcome', 256, 122);
    const st = new THREE.CanvasTexture(sc); st.colorSpace = THREE.SRGBColorSpace;
    const sign = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.53, 0.04), cardMaterial(st)); sign.position.set(0, 2.0, -0.48); sign.castShadow = true; this.hinge.add(sign);
    // Mrs. Pruitt, the judge: a die-cut card in a Sunday hat with a clipboard
    const judgeArt = paintCard(JUDGE, {
      W: 192, H: 384, seed: 191, base: '#6f8aa8', fills: ['rgba(111,138,168,A)', 'rgba(90,114,142,A)'], edge: 'rgba(40,40,50,1)',
      details(dg, px) {
        dg.fillStyle = '#f0d6b8'; { const [a, b] = px(0, 1.38); dg.beginPath(); dg.arc(a, b, 26, 0, Math.PI * 2); dg.fill(); } // face
        dg.fillStyle = '#b5473a'; { const [a, b] = px(-0.32, 1.62), [c2, d] = px(0.32, 1.55); dg.fillRect(a, b, c2 - a, d - b); } // hat brim
        dg.fillStyle = '#7a3a5a'; { const [a, b] = px(-0.13, 1.72), [c2, d] = px(0.13, 1.6); dg.fillRect(a, b, c2 - a, d - b); }
        dg.fillStyle = '#efe3c4'; { const [a, b] = px(-0.1, 1.18), [c2, d] = px(0.1, 1.02); dg.fillRect(a, b, c2 - a, d - b); } // lace collar
        dg.fillStyle = '#2b2018'; for (const ex of [-0.05, 0.05]) { const [a, b] = px(ex, 1.4); dg.beginPath(); dg.arc(a, b, 3, 0, Math.PI * 2); dg.fill(); }
        dg.strokeStyle = '#8a4a3a'; dg.lineWidth = 2.5; { const [a, b] = px(0, 1.33); dg.beginPath(); dg.arc(a, b, 8, 0.2, Math.PI - 0.2); dg.stroke(); }
        dg.fillStyle = '#c9a26a'; { const [a, b] = px(0.04, 0.95), [c2, d] = px(0.24, 0.62); dg.fillRect(a, b, c2 - a, d - b); } // clipboard
        dg.fillStyle = '#f6efe0'; { const [a, b] = px(0.07, 0.9), [c2, d] = px(0.21, 0.66); dg.fillRect(a, b, c2 - a, d - b); }
      },
    });
    void judgeArt;
    this.judgeDoll = hasFolk('townsfolk_1') ? new ModelFigure('townsfolk_1') : new Folk({ coat: 0x6f8aa8, dress: 0x6f8aa8, dressPat: 2, apron: 0xefe3c4, hair: 0x8a8278, bun: true, cheeks: true, hat: 'sunday', hatColor: 0xb5473a, band: 0x7a3a5a, hold: 'clipboard' });
    this.judgeDoll.root.position.set(1.35, 0, -0.25); this.judgeDoll.root.rotation.y = -0.25; // facing out over the table toward the visitors
    this.hinge.add(this.judgeDoll.root);
    this.judge = this.judgeDoll.root;
    g.visible = false;
    scene.add(g);
    this.up = 0; this.t = 0; this.shown = false;
    // rosettes for the ribbons you've won, pinned along the porch beam (shown as you win them)
    const rosArt = paintCard(ROSETTE, {
      W: 128, H: 192, seed: 193, base: '#4a7ab8', fills: ['rgba(74,122,184,A)', 'rgba(60,102,160,A)'], edge: 'rgba(30,40,60,1)',
      details(rg, px) { const [a, b] = px(0, 0.32); rg.fillStyle = '#d9a441'; rg.beginPath(); rg.arc(a, b, 16, 0, Math.PI * 2); rg.fill(); rg.fillStyle = '#efe3c4'; rg.font = 'bold 18px Georgia'; rg.textAlign = 'center'; rg.fillText('1', a, b + 6); },
    });
    const rosGeo = cardGeometry(ROSETTE, 0.02), rosMat = cardMaterial(rosArt);
    const cs = Math.cos(house.rot), sn = Math.sin(house.rot), hy = getHeight(house.x, house.z);
    this.rosettes = Array.from({ length: 10 }, (_, i) => {
      const m = new THREE.Mesh(rosGeo, rosMat);
      const lx = -2.4 + i * 0.4, lz = 4.0; // hung in a row under the front edge of the porch awning, facing the yard
      m.position.set(house.x + cs * lx + sn * lz, hy + 2.05, house.z - sn * lx + cs * lz);
      m.rotation.y = house.rot;
      m.visible = false; scene.add(m);
      return m;
    });
    this.entered = new Set(); this.enteredDay = 0;
  }

  /** Pin the rosettes onto the house as it actually stands (the model house's porch, not the old paper one's): a ray
   * from the yard toward the house at each rosette's spot finds the porch beam, post or wall it hangs on. */
  pinTo(house) {
    if (!house) return;
    house.updateWorldMatrix(true, true);
    const fwd = new THREE.Vector3(0, 0, 1).transformDirection(house.matrixWorld).setY(0).normalize(), ray = new THREE.Raycaster(), o = new THREE.Vector3();
    for (const m of this.rosettes) {
      m.userData.home ||= m.position.clone(); m.position.copy(m.userData.home); // (always from the old porch spot, so a re-pin after the house changes lands right)
      for (const dy of [-0.7, -0.95, -1.2]) { // (under the awning: the beam, a post, or the wall behind the porch)
        o.copy(m.position).addScaledVector(fwd, 4); o.y += dy;
        ray.set(o, fwd.clone().negate()); ray.far = 9;
        const hit = ray.intersectObject(house, true)[0];
        if (hit) { m.position.copy(hit.point).addScaledVector(fwd, 0.04); m.rotation.y = Math.atan2(fwd.x, fwd.z); break; }
      }
    }
  }

  near(pos, r = 2.6) { return this.shown && this.up > 0.9 && Math.hypot(pos.x - this.at.x, pos.z - this.at.z) < r; }
  open(sky) { return isFairDay(sky.day) && sky.time >= 0.29 && sky.time < 0.8; }

  /** Pin up a rosette for each ribbon won (up to ten along the beam). */
  showRibbons(n) { this.rosettes.forEach((m, i) => { m.visible = i < n; }); }

  update(dt, sky) {
    this.t += dt;
    const want = this.open(sky);
    if (want && this.enteredDay !== sky.day) { this.entered.clear(); this.enteredDay = sky.day; }
    if (want && !this.shown) { this.shown = true; this.up = 0; this.group.visible = true; }
    if (this.shown) {
      this.up = want ? Math.min(1.5, this.up + dt * 0.8) : this.up - dt * 1.2;
      const k = want ? springRise(this.up) : Math.max(0, this.up) ** 2;
      this.hinge.rotation.x = -(1 - k) * (Math.PI / 2);
      if (!want && this.up <= 0) { this.shown = false; this.group.visible = false; }
      this.judgeDoll.update(dt, 0, 'clipboard'); // she sways on her heels, considering, clipboard held out
    }
    return want;
  }
}
