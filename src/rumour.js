// Word around the county: when a journal goal needs a guarded site (iron, honey, a guardian to drive off),
// or, with nothing pressing, of the nearest wild-land landmark you haven't seen yet,
// a small torn note under the journal says what folks tell of it, how many paces off, and an inked arrow
// points the way on screen. Sites are found by quietly generating the
// layout of nearby chunks, one chunk per frame, so it costs next to nothing.
import * as THREE from 'three/webgpu';
import { CHUNK } from './world.js';

const _a = new THREE.Vector3(), _b = new THREE.Vector3();

const WANTS = {
  ore: 'vein', iron: 'vein', ironaxe: 'vein',
  honey: 'grove', cake: 'grove',
  slay: 'guarded', legend: 'guarded', coat: 'guarded',
};
const TALES = {
  vein: 'Folks say dust-devil coyotes keep an iron vein',
  grove: 'They tell of an old boar watching a wild-hive grove',
  thicket: 'They tell of coyotes lying up in a berry thicket out in the meadow',
  // with nothing pressing, the talk turns to the landmarks of the wild lands you haven't seen yet
  arch: 'Prospectors tell of a great stone arch out in the red rock',
  steamboat: 'Old-timers tell of a riverboat sunk to her rails in the fen',
  lookout: "They say there's a fire lookout in the high pines, with a view for miles",
  schooner: 'A drover tells of a lost wagon somewhere out on the prairie',
  birch: 'Grandmothers tell of a birch older than the county, deep in the Hollows',
  babe: 'Lumberjacks swear Babe the Blue Ox still grazes up in the high pines, partial to apples',
  hermit: 'They say an old hermit lives deep in the Hollows, and knows every strange corner of the county',
};
const RADIUS = 10; // chunks (~320 m)

export class Rumours {
  constructor(world, el) {
    this.world = world;
    this.el = el;
    this.found = new Map(); // site key → site
    this.order = [];
    for (let r = 0; r <= RADIUS; r++) for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) {
      if (Math.max(Math.abs(dx), Math.abs(dz)) === r) this.order.push([dx, dz]);
    }
    this.cursor = 0;
    this.center = null;
    this.sig = '';
    this.angle = null;
  }

  guarded(site) {
    for (let i = 0; i < site.guards; i++) if (!this.world.destroyed.has(`${site.key}:g${i}`)) return true;
    return false;
  }

  /** visited(key): whether you've already reached a landmark (then nobody bothers telling you of it). */
  update(player, camera, goals, visited = () => true) {
    const goal = goals.find((g) => WANTS[g.id]);
    const want = goal ? WANTS[goal.id] : 'landmark';

    // scan outward from the player's chunk, one chunk a frame
    const pcx = Math.floor(player.pos.x / CHUNK), pcz = Math.floor(player.pos.z / CHUNK);
    const c = `${pcx},${pcz}`;
    if (c !== this.center) { this.center = c; this.cursor = 0; }
    if (this.cursor < this.order.length) {
      const [dx, dz] = this.order[this.cursor++];
      for (const s of this.world.sitesFor(pcx + dx, pcz + dz)) this.found.set(s.key, s);
    }

    let best = null, bd = Infinity;
    for (const s of this.found.values()) {
      if (want === 'guarded' ? !this.guarded(s) : s.kind !== want) continue;
      if (want === 'landmark' && visited(s.key)) continue;
      const d = Math.hypot(s.x - player.pos.x, s.z - player.pos.z);
      if (d < bd) { bd = d; best = s; }
    }
    if (!best || bd < 14) return this.hide();

    // arrow: the on-screen direction of a point a few steps toward the site
    const ux = (best.x - player.pos.x) / bd, uz = (best.z - player.pos.z) / bd;
    _a.copy(player.pos).project(camera);
    _b.set(player.pos.x + ux * 4, player.pos.y, player.pos.z + uz * 4).project(camera);
    const deg = Math.round((Math.atan2(_b.x - _a.x, (_b.y - _a.y) * camera.aspect ** -1) * 180) / Math.PI);
    const paces = Math.max(10, Math.round((bd * 1.3) / 10) * 10);
    const sig = `${best.key}|${paces}`;
    if (sig !== this.sig) {
      this.sig = sig;
      this.el.classList.add('show');
      this.el.innerHTML = `<svg class="arrow" viewBox="-14 -14 28 28"><path d="M0-11 L8 3 L2.5 1.5 L2 11 L-2 11 L-2.5 1.5 L-8 3 Z" fill="#b5523b" stroke="#4a3426" stroke-width="1.6" stroke-linejoin="round"/></svg>`
        + `<span>${TALES[best.kind === 'landmark' ? best.mark : best.kind]}<small>about ${paces} paces that way</small></span>`;
      this.angle = null;
    }
    if (this.angle === null || Math.abs(deg - this.angle) > 2) {
      this.angle = deg;
      this.el.firstChild.style.transform = `rotate(${deg}deg)`;
    }
  }

  hide() {
    if (this.sig !== '') { this.sig = ''; this.el.classList.remove('show'); }
  }
}
