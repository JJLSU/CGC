// The fingerpost at the end of the farm lane: a weathered post with hand-lettered arrow boards, one pointing the
// true way to Paydirt Hollow and one to each of the wild lands (the nearest stretch of each, found once by walking
// out over the map), each with its distance in paces. Stacked up the post at a slant, like a crossroads sign.
import * as THREE from 'three/webgpu';
import { card } from './town.js';
import { paperMaterial } from './materials.js';
import { getHeight, isWater, landAt, LANDS } from './world.js';

const BOARD_COLORS = ['#d8c49a', '#c9b088', '#d2bd92', '#c4a882', '#dcc9a0', '#cdb48c'];

/** Where the nearest stretch of each wild land lies from (x, z): sampled outward on rings. */
function landDirections(x, z) {
  const found = {};
  for (let r = 60; r < 700 && Object.keys(found).length < 5; r += 30) {
    for (let a = 0; a < Math.PI * 2; a += 0.12) {
      const px = x + Math.cos(a) * r, pz = z + Math.sin(a) * r;
      const L = landAt(px, pz);
      for (const k of ['hollows', 'breaks', 'fen', 'prairie', 'pines']) if (!found[k] && L.w[k] > 0.85 && !isWater(px, pz)) found[k] = { x: px, z: pz };
    }
  }
  return found;
}

export class Signpost {
  constructor(scene, at, town) {
    const g = (this.group = new THREE.Group());
    g.position.set(at.x, getHeight(at.x, at.z), at.z);
    const post = new THREE.Mesh(new THREE.BoxGeometry(0.16, 3.1, 0.16), paperMaterial({ color: 0x6a4a30, flatShading: true }));
    post.position.y = 1.55; post.castShadow = true; g.add(post);
    const cap = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.22, 4).rotateY(Math.PI / 4), paperMaterial({ color: 0x4a3424, flatShading: true }));
    cap.position.y = 3.21; g.add(cap);
    const dests = [];
    if (town?.at) dests.push({ name: 'Paydirt Hollow', x: town.at.x, z: town.at.z, town: true });
    const lands = landDirections(at.x, at.z);
    for (const [k, p] of Object.entries(lands)) dests.push({ name: LANDS[k].name.replace(/^the /, ''), x: p.x, z: p.z });
    dests.forEach((d, i) => {
      const dx = d.x - at.x, dz = d.z - at.z, paces = Math.round((Math.hypot(dx, dz) * 1.3) / 10) * 10;
      const len = 1.25, h = 0.3;
      // an arrow-ended board: square at the post, pointed at the far end
      const pts = [[0, -h / 2], [len - 0.2, -h / 2], [len, 0], [len - 0.2, h / 2], [0, h / 2]];
      const letter = (cx) => (gg, px) => {
        const [x, y] = px(cx, 0.0);
        gg.fillStyle = d.town ? '#7a2a1e' : '#2e2218'; gg.textAlign = 'center'; gg.textBaseline = 'middle';
        gg.font = `bold ${d.name.length > 14 ? 40 : 46}px Georgia, serif`; gg.fillText(d.name, x, y - 14);
        gg.font = 'italic 30px Georgia, serif'; gg.fillText(`${paces} paces`, x, y + 26);
      };
      const col = BOARD_COLORS[i % BOARD_COLORS.length];
      const board = card(pts, col, letter(len * 0.44), { W: 512, H: 160, seed: 300 + i, thick: 0.05 });
      // the back is lettered too: the same board cut mirror-wise, turned about to face the other way, so the
      // name reads true from either side of the post
      const back = card(pts.map(([x, y]) => [-x, y]), col, letter(-len * 0.44), { W: 512, H: 160, seed: 340 + i, thick: 0.05 });
      const arm = new THREE.Group(); arm.position.y = 2.75 - i * 0.36; arm.rotation.y = Math.atan2(-dz, dx); // (its length along local +x, turned to point the way)
      board.position.set(0.08, 0, 0.02); back.position.set(0.08, 0, -0.02); back.rotation.y = Math.PI;
      const tilt = new THREE.Group(); tilt.rotation.z = (i % 2 ? 1 : -1) * 0.03; tilt.add(board, back); arm.add(tilt); g.add(arm);
    });
    scene.add(g);
  }
}
