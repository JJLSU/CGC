// Johnny Appleseed comes by: on some mornings (about one day in four, from Day 3) the old wanderer of the
// folk tales walks across the county past the farm, barefoot, with his tin pot for a hat and a sack of apple
// seeds over his shoulder. He's a paper doll like the farmer, who walks with swinging arms and a staff. Walk up to him and he
// stops to talk; press E and he gives you some apples and, before he goes on his way, plants an apple
// sapling at the edge of your yard (it grows like one of your own). Then he wanders off east and is gone.
import * as THREE from 'three/webgpu';
import { Folk } from './folk.js';
import { ModelFigure, hasFolk } from './modelfolk.js';
import { cardMaterial } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { getHeight } from './world.js';
import { Steer } from './steer.js';

const FIGURE = [[-0.21, 0], [-0.04, 0], [-0.02, 0.48], [0.02, 0.48], [0.04, 0], [0.21, 0], [0.28, 0.6], [0.25, 1.08], [0.34, 1.1], [0.47, 1.28], [0.38, 1.47],
  [0.22, 1.42], [0.16, 1.42], [0.19, 1.6], [0.2, 1.77], [0.27, 1.79], [0.27, 1.9], [-0.23, 1.9], [-0.23, 1.79], [-0.19, 1.6], [-0.16, 1.42],
  [-0.27, 1.3], [-0.28, 0.6]];
export const SAYINGS = [
  `"Mornin', neighbor. Plant a seed today and somebody you'll never meet sits in its shade."`,
  `"I've walked from the Ohio to here with nothing but this pot and these seeds. Rich as a king."`,
  `"An apple tree's a promise you make to the folks who come after. I'll leave you one."`,
  `"Treat the critters kindly, even the cross old boars. Most of 'em only want an apple."`,
];

export class Wanderer {
  constructor(scene, center) {
    this.C = center;
    const art = paintCard(FIGURE, {
      W: 192, H: 384, seed: 261, base: '#a8865c', fills: ['rgba(168,134,92,A)', 'rgba(140,110,74,A)'], edge: 'rgba(50,36,24,1)',
      details(g, px) {
        // a coffee-sack tunic with a rope belt, patched; bare shins; a tin-pot hat with its handle; a seed sack
        g.fillStyle = '#c9a676'; { const [a, b] = px(-0.27, 1.4), [c, d] = px(0.27, 0.62); g.fillRect(a, b, c - a, d - b); } // lighter sacking
        g.strokeStyle = 'rgba(110,80,50,0.5)'; g.lineWidth = 2; for (let y = 0.7; y < 1.4; y += 0.08) { const [a, b] = px(-0.26, y), [c] = px(0.26, y); g.beginPath(); g.moveTo(a, b); g.lineTo(c, b); g.stroke(); } // the weave
        g.fillStyle = '#f0d6b8'; { const [a, b] = px(0, 1.6); g.beginPath(); g.arc(a, b, 26, 0, Math.PI * 2); g.fill(); } // face
        g.fillStyle = '#a8adb2'; { const [a, b] = px(-0.23, 1.9), [c, d] = px(0.27, 1.77); g.fillRect(a, b, c - a, d - b); } // the pot
        g.fillStyle = 'rgba(255,255,255,0.35)'; { const [a, b] = px(-0.18, 1.88), [c, d] = px(-0.1, 1.79); g.fillRect(a, b, c - a, d - b); }
        g.strokeStyle = '#6e7276'; g.lineWidth = 5; { const [a, b] = px(0.27, 1.84), [c, d] = px(0.38, 1.82); g.beginPath(); g.moveTo(a, b); g.lineTo(c, d); g.stroke(); }
        g.fillStyle = '#8a6a48'; { const [a, b] = px(0, 1.52); g.beginPath(); g.arc(a, b, 18, 0.15, Math.PI - 0.15); g.fill(); } // whiskers
        g.fillStyle = '#2b2018'; for (const ex of [-0.06, 0.06]) { const [a, b] = px(ex, 1.63); g.beginPath(); g.arc(a, b, 3.5, 0, Math.PI * 2); g.fill(); }
        g.fillStyle = 'rgba(214,130,110,0.5)'; for (const ex of [-0.1, 0.1]) { const [a, b] = px(ex, 1.57); g.beginPath(); g.arc(a, b, 5, 0, Math.PI * 2); g.fill(); } // rosy cheeks
        g.strokeStyle = '#d9c49a'; g.lineWidth = 6; { const [a, b] = px(-0.27, 0.9), [c] = px(0.27, 0.9); g.beginPath(); g.moveTo(a, b); g.lineTo(c, b); g.stroke(); } // rope belt
        g.fillStyle = '#8a6a48'; { const [a, b] = px(-0.16, 1.25), [c, d] = px(-0.05, 1.12); g.fillRect(a, b, c - a, d - b); } // a patch
        g.fillStyle = '#d2b48a'; { const [a, b] = px(0.37, 1.28); g.beginPath(); g.ellipse(a, b, 20, 26, 0.3, 0, Math.PI * 2); g.fill(); } // the seed sack
        g.fillStyle = '#c4362f'; for (const [x, y] of [[0.34, 1.42], [0.41, 1.4]]) { const [a, b] = px(x, y); g.beginPath(); g.arc(a, b, 6, 0, Math.PI * 2); g.fill(); } // apples peeking out
        g.fillStyle = '#e8c8a8'; for (const lx of [-0.13, 0.13]) { const [a, b] = px(lx - 0.06, 0.48), [c, d] = px(lx + 0.06, 0.04); g.fillRect(a, b, c - a, d - b); } // bare shins
      },
    });
    // a paper doll like the farmer: a patched sackcloth coat, rolled trousers, bare feet, a grey beard
    this.man = hasFolk('folk_johnny') ? new ModelFigure('folk_johnny') : new Folk({ coat: 0x9a7a52, coatPat: 3, pants: 0x6a5a48, barefoot: true, beard: 0x9a948a, hair: 0x9a948a, hat: 'pot', sack: true, hold: 'staff' });
    this.group = new THREE.Group(); this.group.add(this.man.root); this.group.visible = false;
    scene.add(this.group);
    this.pos = this.group.position;
    this.steer = new Steer(0.4); this.heading = new THREE.Vector3(1, 0, 0);
    this.visitDay = -1; this.state = 'away'; this.talked = false; this.walk = 0; this.dir = 1;
  }

  /** Does he come by today? About one day in four, never on fair day, from Day 3. */
  visits(day) { return day >= 3 && day % 7 !== 0 && ((day * 2654435761) >>> 0) % 4 === 1; }
  near(pos, r = 2.6) { return this.state === 'walking' && this.group.visible && Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z) < r; }

  update(dt, sky, player, camera, colliders = []) {
    const C = this.C;
    if (this.state === 'away') {
      if (sky.day !== this.visitDay && this.visits(sky.day) && sky.time > 0.34 && sky.time < 0.55) {
        this.visitDay = sky.day; this.state = 'walking'; this.talked = this.talkedDay === sky.day; // a reload doesn't get you a second sapling
        this.pos.set(C.x - 46, 0, C.z + 13.5); this.pos.y = getHeight(this.pos.x, this.pos.z);
        this.group.visible = true;
        return 'arrived';
      }
      return null;
    }
    // he walks the lane across the bottom of the farm, west to east, and stops while you're near
    const d = Math.hypot(player.pos.x - this.pos.x, player.pos.z - this.pos.z);
    const stopped = d < 4.5;
    const speed = stopped ? 0 : 1.0;
    // follow the lane (a gentle wave across the bottom of the farm), stepping round wagons, rails and bales
    const lane = (x) => C.z + 13.5 + Math.sin(x * 0.15) * 1.2;
    if (speed) {
      const ax = this.pos.x + 3, az = lane(ax), dx = ax - this.pos.x, dz = az - this.pos.z, dl = Math.hypot(dx, dz) || 1;
      this.heading.lerp(this.steer.heading(_w.set(dx / dl, 0, dz / dl), this.pos, null, colliders, dt), Math.min(1, dt * 5)).normalize();
      this.pos.x += this.heading.x * speed * dt; this.pos.z += this.heading.z * speed * dt;
      this.steer.pushOut(this.pos);
    }
    this.pos.y = getHeight(this.pos.x, this.pos.z);
    this.walk += speed * dt;
    // he faces the way he walks, or turns to you when he stops to talk
    const want = stopped ? Math.atan2(player.pos.x - this.pos.x, player.pos.z - this.pos.z) : Math.atan2(this.heading.x, this.heading.z);
    let dy = want - this.group.rotation.y; dy = Math.atan2(Math.sin(dy), Math.cos(dy));
    this.group.rotation.y += dy * Math.min(1, dt * 6);
    this.man.update(dt, speed);
    if (this.pos.x > C.x + 46 || (sky.time > 0.7 && !stopped)) { this.state = 'away'; this.group.visible = false; }
    return null;
  }
}

const _w = new THREE.Vector3();
