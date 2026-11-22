// Settlers and works. Folk you meet out in the county can be won over to join the farm; each one runs a work
// (a woodcutter's lot, a stone quarry…) and what they make trickles, a little at a time, into your storehouse.
// It's only a trickle: enough to keep you going, never enough that you don't still go out and gather.
//
// Four folk camp at the edge of the farm once you've built a storehouse, each won over their own way:
//   Silas Crane (woodcutter) and Hattie Boone (quarrywoman) take a fair wage; Ada Hale (fisherwoman) joins if you
//   help mend her lean-to; Big Jim Tuttle (clay digger) joins whoever can beat him at arm-wrestling.
// A hired settler walks to the nearest work of their trade and works it by day (you can see them at it), and
// fills a crate on their back with what they make, and carries each crateful (three) to the storehouse. E at the storehouse takes it all into your pack.
import * as THREE from 'three/webgpu';
import { Folk } from './folk.js';
import { ModelFigure, hasFolk } from './modelfolk.js';
import { getHeight } from './world.js';
import { Steer } from './steer.js';
import { paperMaterial } from './materials.js';

// hauling: what a settler makes goes into a crate on their back; with a crateful (or at dusk) they carry it to
// the storehouse and tip it in, then go back to work. The crate's contents show what they're bringing.
const LOAD = 3;
const GOODS = { gold: 0xe8b830, wood: 0x8a5a34, stone: 0x9a968c, fish: 0x7a9ab0, clay: 0xa8603a, ore: 0x5a5450, honey: 0xe0a83a, flour: 0xf3ead6, syrup: 0xb8702a, leather: 0xb08048, charcoal: 0x2e2a28, bricks: 0xb5473a };
const _mats = {}; const pm = (c) => (_mats[c] ||= paperMaterial({ color: c, flatShading: true }));
const crateGeo = new THREE.BoxGeometry(0.46, 0.28, 0.3), slatGeo = new THREE.BoxGeometry(0.48, 0.05, 0.32), postGeo = new THREE.BoxGeometry(0.05, 0.3, 0.32);
const logGeo = new THREE.CylinderGeometry(0.065, 0.065, 0.4, 7).rotateZ(Math.PI / 2), lumpGeo = new THREE.DodecahedronGeometry(0.085, 0);
function crate(item) {
  const g = new THREE.Group();
  const box = new THREE.Mesh(crateGeo, pm(0xc99a5e)); g.add(box);
  for (const y of [-0.08, 0.08]) { const slat = new THREE.Mesh(slatGeo, pm(0x8a5a34)); slat.position.y = y; g.add(slat); } // the crate's slats
  for (const x of [-0.22, 0.22]) { const post = new THREE.Mesh(postGeo, pm(0x7a4e2c)); post.position.x = x; g.add(post); }
  // what's in it, heaped over the top: logs for wood, lumps for everything else
  const c = pm(GOODS[item] ?? 0x8a7a64);
  if (item === 'wood') [[0.01, 0.2, -0.07], [-0.02, 0.2, 0.07], [0.02, 0.31, 0]].forEach(([x, y, z]) => { const l = new THREE.Mesh(logGeo, c); l.position.set(x, y, z); g.add(l); });
  else [[-0.12, 0.17, 0.05], [0.1, 0.17, -0.05], [0.0, 0.2, 0.06], [0.03, 0.27, -0.02]].forEach(([x, y, z], i) => { const l = new THREE.Mesh(lumpGeo, c); l.position.set(x, y, z); l.rotation.set(i, i * 2, 0); g.add(l); });
  for (const m of g.children) { m.castShadow = true; m.receiveShadow = true; }
  g.position.set(0, 1.0, -0.4); g.visible = false;
  return g;
}

// what each work makes, and what it's called (the first time you gather a thing yourself, its work unlocks)
export const WORKS = { wood: ['woodlot', "woodcutter's lot"], stone: ['quarry', 'stone quarry'], fish: ['weir', 'fish weir'], clay: ['claypit', 'clay pit'], ore: ['diggings', 'ore diggings'], honey: ['beeyard', 'bee yard'], wheat: ['mill', 'grist mill'], sap: ['shack', 'sugar shack'], pelt: ['tannery', 'tannery'], iron: ['charpit', 'charcoal pit'], gold: ['sluice', 'sluice box'] }; // (the brick kiln unlocks along with the clay pit) // (the mill unlocks with wheat and grinds flour)
export const WORK_NAME = Object.fromEntries(Object.values(WORKS));

// how: 'hire' (a fair wage), 'help' (bring what they need for a chore), 'wrestle' (beat them at arm-wrestling),
//      'tale' (out-tell them at their fire after dark: you need three tall tales of your own),
//      'court' (dance a reel at the barn dance, then bring a gift: both, in either order),
//      'deed' (they only join someone who's done a brave thing: driven off a treasure guardian)
export const SETTLERS = [
  {
    id: 'silas', model: 'folk_silas', how: 'hire', name: 'Silas Crane', trade: 'woodcutter', work: 'woodlot', item: 'wood', every: 45, camp: [-16, 14],
    wage: { apples: 4, berries: 6 }, pitch: 'a lanky woodcutter with a two-bit axe, down on his luck',
    ask: '"A sack of apples and a few handfuls of berries, and I\'ll cut your cordwood as long as you\'ll have me."',
    hired: 'Silas shoulders his axe. "Point me at your woodlot, boss."',
    look: { coat: 0xb5473a, coatPat: 1, sleeve: 0xb5473a, pants: 0x3f5f8a, beard: 0x6b4a30, burly: true, rolled: true, hat: 'cap', hatColor: 0x3a3028, hold: 'axe', scale: 1.08 },
  },
  {
    id: 'hattie', model: 'trades_6', how: 'hire', name: 'Hattie Boone', trade: 'quarrywoman', work: 'quarry', item: 'stone', every: 60, camp: [-19, 10],
    wage: { wood: 8, berries: 6 }, pitch: 'a broad-shouldered quarrywoman who can split granite with a look',
    ask: '"Eight sticks of wood for my lean-to and something sweet. Then I\'ll cut your stone."',
    hired: 'Hattie spits on her palms. "Where\'s this quarry, then?"',
    look: { coat: 0x6f8a5a, dress: 0x6a5a48, dressPat: 2, apron: 0x8a7a64, hair: 0xa8482a, long: true, cheeks: true, glam: true, curvy: true, rolled: true, lids: 0x7a9a6a, lips: 0xb8302a, hat: 'none', hold: 'pick' },
  },
  {
    id: 'ada', model: 'townsfolk_2', how: 'help', name: 'Ada Hale', trade: 'fisherwoman', work: 'weir', item: 'fish', every: 70, camp: [-13, 18],
    wage: { wood: 10, rope: 1 }, pitch: 'a widow from down the creek whose lean-to blew in with the last storm',
    ask: '"If you could spare ten sticks and a coil of rope to mend my lean-to, I\'d keep you in fish till the creek runs dry."',
    hired: 'Ada ties off the last knot. "There. Now, where\'s a good bend in the creek for a weir?"',
    look: { coat: 0x4f6f96, dress: 0x4f6f96, dressPat: 2, apron: 0xefe3c4, hair: 0x9a948a, bun: true, cheeks: true, hat: 'bonnet', hatColor: 0x8a74a8, hold: 'rod' },
  },
  {
    id: 'jim', model: 'folk_player', how: 'wrestle', /* (the weathered homesteader from the reference art; you're the big man in red) */ name: 'Big Jim Tuttle', trade: 'clay digger', work: 'claypit', item: 'clay', every: 60, camp: [-22, 15],
    pitch: 'a mountain of a teamster with arms like stovepipes, sitting on an upturned crate',
    ask: '"Work for a farmer? I\'ll work for any man who can put my arm down. Care to try?"',
    hired: 'Big Jim rubs his elbow and laughs till he coughs. "Fair\'s fair. Show me your clay bank."',
    look: { coat: 0xd9a441, coatPat: 1, sleeve: 0xefe3c4, pants: 0x4a4038, vest: 0x6b4a30, beard: 0x3a2a20, burly: true, rolled: true, hat: 'straw', band: 0x2b2018, hold: 'pick', scale: 1.16 },
  },
  {
    id: 'cyrus', model: 'prospectors_6', how: 'tale', name: 'Old Cyrus Pike', trade: 'prospector', work: 'diggings', item: 'ore', every: 120, camp: [-10, 21], tales: 3,
    pitch: 'a grizzled prospector with a burro\'s patience and a beard you could lose a pickaxe in',
    ask: '"I\'ve told tales from here to Sutter\'s Mill. Out-tell me by my fire some evening and I\'ll dig your ore."',
    hired: 'Cyrus slaps his knee. "Blamed if that ain\'t the tallest one I ever heard! All right, I\'m your man."',
    lost: 'Cyrus yawns. "Heard that one. Go listen by your own fire a while; come back with three tales worth the telling."',
    look: { coat: 0x8a7a5a, coatPat: 3, pants: 0x5a4a38, beard: 0xe8e2d6, hair: 0xe8e2d6, hat: 'stovepipe', hatColor: 0x5a4a38, band: 0x8a3a2a, hold: 'pick' },
  },
  {
    id: 'clem', model: 'prospectors_3', how: 'court', name: 'Clementine Rowe', trade: 'beekeeper', work: 'beeyard', item: 'honey', every: 150, camp: [-25, 11],
    gift: { pie: 1 }, pitch: 'a merry beekeeper\'s daughter with a laugh like a dinner bell and a straw hat full of daisies',
    ask: '"A body likes to be courted proper: a reel at the barn dance, and a pie, if you can bake one. Then we\'ll see."',
    hired: 'Clementine blushes to her ears and takes the pie. "Well! I suppose a farm like this could use some bees."',
    look: { coat: 0xe8b84a, dress: 0xe8b84a, dressPat: 2, apron: 0xefe3c4, hair: 0xd89048, long: true, cheeks: true, glam: true, curvy: true, neckline: true, lips: 0xd8506a, hat: 'sunday', hatColor: 0xe2c27a, band: 0xc4362f, hold: 'smoker' },
  },
  {
    id: 'ezra', model: 'folk_ezra', how: 'help', chore: 'cut him a new millstone', name: 'Ezra Fenn', trade: 'miller', work: 'mill', item: 'flour', every: 80, camp: [-28, 18],
    wage: { stone: 12, wood: 4 }, pitch: 'a dusty miller whose old millstone cracked clean in two last spring',
    ask: '"Twelve good stones and a bit of timber, and I\'ll dress you a new millstone. Then put me by a stream and you\'ll never want for flour."',
    hired: 'Ezra runs a floury thumb round the new stone. "She\'ll grind. Now find me running water."',
    look: { coat: 0xefe5cc, coatPat: 0, sleeve: 0xefe5cc, pants: 0x8a7a64, vest: 0x8a6a48, beard: 0xcfc6b4, hat: 'cap', hatColor: 0xd8cfb8, hold: 'flour' },
  },
  {
    id: 'luther', model: 'folk_luther', how: 'hire', name: 'Luther Odom', trade: 'brickmaker', work: 'kiln', item: 'bricks', every: 90, camp: [-31, 13],
    wage: { fishfry: 2, rope: 2 }, pitch: 'a soft-spoken brickmaker with kiln-scorched forearms and a mason\'s pencil behind his ear',
    ask: '"Two hot suppers of fried fish and a couple coils of rope, and I\'ll fire you bricks enough for a proper chimney."',
    hired: 'Luther tucks his pencil away. "Clay and a good draught. Show me where to build the kiln."',
    look: { coat: 0x8a4a34, coatPat: 1, sleeve: 0xefe3c4, pants: 0x4a4038, vest: 0x5a3e2a, beard: 0x2b2018, burly: true, rolled: true, hat: 'cap', hatColor: 0x3a2e26, hold: 'shovel', scale: 1.08 },
  },
  {
    id: 'abel', model: 'folk_abel', how: 'help', chore: 'patch his leaky sap buckets', name: 'Abel Whitcomb', trade: 'sugar-maker', work: 'shack', item: 'syrup', every: 110, camp: [-34, 17],
    wage: { iron: 1, wood: 6 }, pitch: 'an old sugar-maker from up north, with a sweet tooth and a cough from forty springs of woodsmoke',
    ask: '"My sap buckets leak like a sieve, son. A bar of iron for new hoops and a bit of wood for staves, and I\'ll boil you syrup fit for a parson."',
    hired: 'Abel sniffs the air. "Maples a-plenty hereabouts. Build me a shack with a good draught and I\'ll get boiling."',
    look: { coat: 0x5a6a4a, coatPat: 1, sleeve: 0x5a6a4a, pants: 0x6a5a48, beard: 0xd8d0c0, hair: 0xd8d0c0, hat: 'straw', band: 0x6a4428, hold: 'bucket' },
  },
  {
    id: 'mose', model: 'folk_mose', how: 'hire', name: 'Mose Hartwell', trade: 'tanner', work: 'tannery', item: 'leather', every: 130, camp: [-37, 12],
    wage: { pelt: 2, honeycake: 1 }, pitch: 'a leathery old tanner with oak-bark stains to the elbow and a nose that gave up complaining years ago',
    ask: '"Two good pelts to start me off and a honey cake for my trouble. Then I\'ll tan you leather supple as a glove."',
    hired: 'Mose pats the pelts like old friends. "Oak bark, a couple of vats and a good stretch of time. Downwind of the house, mind."',
    look: { coat: 0x7a5a3a, coatPat: 3, sleeve: 0x7a5a3a, pants: 0x4a4038, apron: 0x5a3e2a, beard: 0x8a8278, hat: 'cap', hatColor: 0x4a3a2a, hold: 'hide' },
  },
  {
    id: 'patience', model: 'prospectors_2', how: 'deed', name: 'Patience Ewing', trade: 'collier', work: 'charpit', item: 'charcoal', every: 120, camp: [-40, 16],
    pitch: 'a soot-smudged collier who has burned charcoal alone in the hills for twenty years and fears nothing on four legs',
    ask: '"I don\'t work for folk who hide from coyotes. Drive off one of those treasure-guardians, and then we\'ll talk."',
    hired: 'Patience looks you up and down and nods once. "Word is you saw off a guardian. That\'ll do. Where do you want your charcoal?"',
    lost: '"Still hiding from the coyotes, are we? Come back when you\'ve driven one off."',
    look: { coat: 0x3a3634, coatPat: 1, sleeve: 0x3a3634, dress: 0x4a4038, dressPat: 0, apron: 0x2b2622, hair: 0x1e1612, long: true, glam: true, curvy: true, corset: 0x2b2622, lids: 0x5a4a5a, lips: 0x8a1a2a, hat: 'none', hold: 'staff' },
  },
  {
    id: 'gus', model: 'prospectors_1', how: 'hire', name: 'Gus Tolliver', trade: 'placer miner', work: 'sluice', item: 'gold', every: 150, camp: [-43, 12],
    wage: { fish: 3, apples: 4 }, pitch: 'a stooped old placer miner who swears the creeks were never played out, just the men',
    ask: '"Three fish and a sack of apples a week, and I\'ll rock your sluice from sunup to sundown. Gold\'s in them creeks yet, mark me."',
    hired: 'Gus spits, grins and shoulders his shovel. "Build me a sluice box down by the water and I\'ll make it pay."',
    look: { coat: 0x7a6a50, coatPat: 3, sleeve: 0x7a6a50, pants: 0x4a6385, pantsPat: 8, beard: 0xd8d0c0, hair: 0xd8d0c0, hat: 'straw', band: 0x5a3a24, hold: 'shovel' },
  },
  // newcomers: they only come to Paydirt Hollow once the boarding house has rooms to let (see `needs`)
  {
    id: 'nell', model: 'prospectors_5', how: 'hire', needs: 'boarding', name: 'Nell Harper', trade: 'placer miner', work: 'sluice', item: 'gold', every: 150, camp: [-46, 16],
    wage: { bread: 2, honey: 1 }, pitch: 'a hard-bitten freighter who drove mule wagons up the canyon road for ten years and has decided to get rich instead',
    ask: '"Two loaves and a jar of honey, and I\'ll work any sluice you build like it owes me money."',
    hired: 'Nell rolls up her sleeves. "Show me the water. I\'ve washed more gravel than you\'ve walked on."',
    look: { coat: 0x8a4a34, coatPat: 7, sleeve: 0x8a4a34, dress: 0x5a4a3e, dressPat: 1, apron: 0x6a5a48, hair: 0x4a2c1a, long: true, glam: true, curvy: true, corset: 0x6a2a2a, mole: true, lids: 0x7a5a6a, lips: 0xa82a2a, hat: 'sunday', hatColor: 0x5a4a3e, band: 0x8a3a2a, hold: 'shovel' },
  },
  {
    id: 'otis', model: 'folk_otis', how: 'hire', needs: 'boarding', name: 'Otis Bell', trade: 'woodcutter', work: 'woodlot', item: 'wood', every: 45, camp: [-49, 12],
    wage: { apples: 4, fish: 2 }, pitch: 'a big, quiet woodcutter down from the north woods, who says about three words a day',
    ask: '"Apples. Fish." He holds up four fingers, then two.',
    hired: 'Otis nods once and picks up his axe. That\'s all.',
    look: { coat: 0x3e5a6a, coatPat: 7, sleeve: 0x3e5a6a, pants: 0x4a4038, beard: 0x3a2a20, hair: 0x3a2a20, burly: true, hat: 'cap', hatColor: 0x8a3a2a, hold: 'axe', scale: 1.18 },
  },
];
const CAP = 30; // the storehouse holds at most this much of any one thing from the works
// the larder: plain food you stock at the storehouse (R) becomes rations; every settler eats one each morning,
// and a settler with no breakfast works at half pace. [item, how many make one ration]
export const RATIONS = [['fish', 1], ['corn', 1], ['apples', 1], ['berries', 2], ['egg', 1], ['bread', 1]];
const LARDER_CAP = 60;

export class Settlers {
  constructor(scene, home) {
    this.scene = scene; this.home = home;
    this.discovered = new Set(); // resources you've gathered at least once (works unlock from these)
    this.hired = new Set();
    this.stock = {};             // what's waiting in the storehouse
    this.larder = 0;             // rations for the settlers
    this.fedDay = -1;            // the last morning breakfast was handed out
    this.hungry = new Set();     // settlers who went without this morning
    this.list = SETTLERS.map((S) => {
      const folk = S.model && hasFolk(S.model) ? new ModelFigure(S.model) : new Folk(S.look); // (the model from the reference art, once it's made)
      folk.root.visible = false; scene.add(folk.root);
      const fire = new THREE.Group(); // their camp: a little ring of stones and a tiny flame card
      const stones = new THREE.Mesh(new THREE.TorusGeometry(0.35, 0.09, 5, 9).rotateX(Math.PI / 2), new THREE.MeshLambertNodeMaterial({ color: 0x8a8278 }));
      const flame = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.45, 5).translate(0, 0.22, 0), new THREE.MeshBasicNodeMaterial({ color: 0xff9a48 }));
      fire.add(stones, flame); fire.visible = false; scene.add(fire);
      const load = crate(S.item); folk.body.add(load);
      return { S, folk, fire, pos: folk.root.position, state: 'away', made: 0, steer: new Steer(0.4), dir: new THREE.Vector3(1, 0, 0), work: null, load: 0, crate: load, hauling: false };
    });
    this.onArrive = null; // (settler) when they first make camp
  }

  /** Where they live: in town (before a door on the boardwalk, or by a tent), or, with no town, at a camp by the farm. */
  campAt(s) {
    if (this.bunk?.built && this.hired.has(s.S.id)) { const p = this.bunk.homeFor([...this.hired].indexOf(s.S.id)); return new THREE.Vector3(p.x, getHeight(p.x, p.z), p.z); } // hired hands bed down in your bunkhouse
    if (this.town) { const p = this.town.homeFor(this.list.indexOf(s), s.S.needs); return new THREE.Vector3(p.x, getHeight(p.x, p.z), p.z); }
    const x = this.home.x + s.S.camp[0], z = this.home.z + s.S.camp[1]; return new THREE.Vector3(x, getHeight(x, z), z);
  }

  /** Remember a resource the farmer has gathered (the first time, its work unlocks). */
  discover(item) { const fresh = !this.discovered.has(item); this.discovered.add(item); return fresh; }

  near(pos, r = 2.2) { return this.list.find((s) => s.state !== 'away' && !s.asleep && Math.hypot(pos.x - s.pos.x, pos.z - s.pos.z) < r) || null; }

  canAfford(inv, s) { return Object.entries(s.S.wage || {}).every(([k, n]) => (inv[k] || 0) >= n); }

  /**
   * Arm-wrestling: press E as fast as you can; every press pushes his arm a little way down, and he pushes back
   * steadily. Put his knuckles on the crate (1) and he joins you; get pinned (0) and you can try again in a bit.
   * Returns 'won' | 'lost' | null.
   */
  wrestle(dt, s, pressed) {
    const W = (this.match ||= { k: 0.5, s });
    if (pressed) W.k += 0.09; // about five presses a second to gain on him
    W.k -= dt * 0.33;
    if (W.k >= 1) { this.match = null; this.join(s); return 'won'; }
    if (W.k <= 0) { this.match = null; s.tired = 20; return 'lost'; }
    return null;
  }
  matchBar() { const k = this.match?.k ?? 0.5, n = Math.round(k * 12); return `${'█'.repeat(n)}${'░'.repeat(12 - n)}`; }

  join(s) { this.hired.add(s.S.id); s.state = 'hired'; s.fire.visible = false; this.onJoin?.(s); }

  hire(inv, s) {
    if (!this.canAfford(inv, s)) return false;
    for (const [k, n] of Object.entries(s.S.wage)) inv[k] -= n;
    this.join(s);
    return true;
  }

  /** Take everything waiting in the storehouse into the pack. Returns what was taken. */
  collect(inv) {
    const got = {};
    for (const [k, n] of Object.entries(this.stock)) if (n > 0) { inv[k] = (inv[k] || 0) + n; got[k] = n; }
    this.stock = {};
    return got;
  }

  stockText() { return Object.entries(this.stock).filter(([, n]) => n > 0).map(([k, n]) => `${n} ${k}`).join(', '); }

  /** Stock the larder from the pack with plain food. Returns { taken, rations } or null if there was nothing to give. */
  stockLarder(inv) {
    const taken = {}; let added = 0;
    for (const [k, per] of RATIONS) {
      while ((inv[k] || 0) >= per && this.larder + added < LARDER_CAP) { inv[k] -= per; taken[k] = (taken[k] || 0) + per; added++; }
    }
    if (!added) return null;
    this.larder += added;
    for (const s of this.list) this.hungry.delete(s.S.id); // a full larder: anyone who went without gets a bite now
    return { taken, rations: added };
  }

  /** Each morning every settler with you eats one ration; anyone who can't, works at half pace that day. */
  breakfast(day) {
    if (day === this.fedDay) return;
    this.fedDay = day; this.hungry.clear();
    for (const s of this.list) {
      if (s.state !== 'hired') continue;
      if (this.larder > 0) this.larder--; else this.hungry.add(s.S.id);
    }
  }

  larderText() {
    const n = this.list.filter((s) => s.state === 'hired').length;
    return n ? `Larder: ${this.larder} ration${this.larder === 1 ? '' : 's'} (${n} to feed: ${Math.floor(this.larder / n)} day${Math.floor(this.larder / n) === 1 ? '' : 's'})` : `Larder: ${this.larder} rations`;
  }

  save() { return { discovered: [...this.discovered], hired: [...this.hired], stock: this.stock, danced: !!this.danced, larder: this.larder, fedDay: this.fedDay, hungry: [...this.hungry], loads: Object.fromEntries(this.list.filter((s) => s.load).map((s) => [s.S.id, s.load])) }; }
  load(d) {
    if (!d) return;
    for (const k of d.discovered || []) this.discovered.add(k);
    for (const id of d.hired || []) this.hired.add(id);
    this.stock = { ...(d.stock || {}) };
    this.danced = !!d.danced;
    this.larder = d.larder || 0; this.fedDay = d.fedDay ?? -1; for (const id of d.hungry || []) this.hungry.add(id);
    for (const s of this.list) if (this.hired.has(s.S.id)) { s.state = 'hired'; const c = this.campAt(s); s.pos.copy(c); s.load = d.loads?.[s.S.id] || 0; }
  }

  update(dt, { pieces, sky, camera }) {
    const storehouse = pieces.find((p) => p.type === 'storehouse' && p.risen !== false);
    if (sky.time > 0.25 && sky.time < 0.5) this.breakfast(sky.day); // breakfast is handed out each morning
    for (const s of this.list) {
      const S = s.S;
      // not met yet: they turn up and make camp at the edge of the farm once there's a storehouse to work for
      if (s.state === 'away') {
        if (S.needs && !this.town?.tiers[S.needs] && !this.hired.has(S.id)) { s.folk.root.visible = false; continue; } // not in town yet: no rooms to be had
        if (this.town) { // in Paydirt Hollow they're already living in town, scraping by, from the first day
          if (this.hired.has(S.id)) continue;
          if (S.needs) this.onNewcomer?.(s);
          s.state = 'camp'; s.pos.copy(this.campAt(s)); s.folk.root.visible = true; s.fire.visible = false;
        } else {
          if (!storehouse || this.hired.has(S.id)) continue;
          s.state = 'camp'; s.pos.copy(this.campAt(s)); s.fire.position.copy(s.pos).add(new THREE.Vector3(0.9, 0, 0.4));
          s.folk.root.visible = true; s.fire.visible = true; this.onArrive?.(s);
        }
      }
      s.folk.root.visible = true;
      const bedtime = sky.time > 0.88 || sky.time < 0.22 || !!this.wet; // (from late evening till before first light, folk are abed; and in a downpour they go in out of the wet)
      let speed = 0, goal = null, pose = null;
      if (s.tired > 0) s.tired -= dt;
      if (s.state === 'camp') {
        if (bedtime) { s.folk.root.visible = false; s.asleep = true; continue; } // turned in for the night, in their tent
        s.asleep = false;
        s.fire.children[1].scale.y = 0.85 + Math.sin(performance.now() * 0.012 + S.camp[0]) * 0.15; // the little flame flickers
      } else {
        // hired: by day to the nearest work of their trade; by night (or with no work built yet) back to camp
        s.work = pieces.filter((p) => p.type === S.work && p.risen !== false).sort((a, b) => Math.hypot(a.x - s.pos.x, a.z - s.pos.z) - Math.hypot(b.x - s.pos.x, b.z - s.pos.z))[0] || null;
        const day = sky.night < 0.45 && !this.wet; // (no work in a downpour: home to shelter till it passes)
        // a full crate (or any at all, come dusk) goes to the storehouse before anything else
        if (s.load && storehouse && (s.load >= LOAD || !day)) s.hauling = true;
        if (!storehouse) s.hauling = false;
        // supper at dusk: hired hands with a bunkhouse sit round its fire a while before they turn in
        const supper = !this.wet && this.bunk?.built && sky.time > 0.76 && sky.time < 0.88 && this.hired.has(S.id);
        if (s.hauling) { const away = _h.set(s.pos.x - storehouse.x, 0, s.pos.z - storehouse.z); away.multiplyScalar(1.9 / Math.max(0.01, away.length())); goal = _g.set(storehouse.x + away.x, 0, storehouse.z + away.z); }
        else if (supper) goal = this.bunk.fireSpot([...this.hired].indexOf(S.id));
        else goal = s.work && day ? _g.set(s.work.x + 1.3, 0, s.work.z + 0.9) : this.campAt(s);
        const to = _v.set(goal.x - s.pos.x, 0, goal.z - s.pos.z), d = to.length();
        if (s.hauling && d <= 0.8) { // tip the crate into the storehouse (what won't fit stays in the crate)
          const room = Math.max(0, (this.cap || CAP) - (this.stock[S.item] || 0)), put = Math.min(room, s.load); // (casks from the cooperage raise the cap)
          if (put) this.stock[S.item] = (this.stock[S.item] || 0) + put;
          s.load -= put; s.hauling = false; this.onDeliver?.(s, put);
        }
        s.asleep = bedtime && !s.hauling && d <= 0.8; // home and abed: in the bunkhouse (or their tent) till morning
        if (s.asleep) { s.folk.root.visible = false; s.crate.visible = false; continue; }
        if (d > 0.8) { s.dir.copy(to.normalize()); speed = d > 6 ? 1.6 : 1.1; s.pos.x += s.dir.x * speed * dt; s.pos.z += s.dir.z * speed * dt; }
        else if (supper) { pose = 'sit'; const k = Math.min(1, dt * 4); s.pos.x += (goal.x - s.pos.x) * k; s.pos.z += (goal.z - s.pos.z) * k; s.dir.set(this.bunk.fireAt.x - s.pos.x, 0, this.bunk.fireAt.z - s.pos.z).normalize(); } // (on a log by the fire, facing it)
        else if (s.work && day) {
          pose = 'work'; s.dir.set(s.work.x - s.pos.x, 0, s.work.z - s.pos.z).normalize();
          // the trickle: one unit every so often, into the storehouse (if there is one, and it has room)
          if (storehouse && s.load < LOAD && (s.made += dt * (this.hungry.has(S.id) ? 0.5 : 1) * (this.bunk?.built ? 1.25 : 1)) >= S.every) { s.made = 0; s.load++; this.discovered.add(S.item); }
        }
        s.pos.y = getHeight(s.pos.x, s.pos.z);
      }
      // face the way they're going (or the camera, idling at camp)
      const yaw = speed || pose ? Math.atan2(s.dir.x, s.dir.z) : Math.atan2(camera.position.x - s.pos.x, camera.position.z - s.pos.z);
      let dy = yaw - s.folk.root.rotation.y; dy = Math.atan2(Math.sin(dy), Math.cos(dy)); s.folk.root.rotation.y += dy * Math.min(1, dt * 6);
      s.crate.visible = s.load > 0;
      // far off (130 m or more from the lens) a settler is a speck: hidden, not animated, though still at their work
      if (camera && Math.hypot(camera.position.x - s.pos.x, camera.position.z - s.pos.z) > 130) s.folk.root.visible = false;
      else s.folk.update(dt, speed, pose);
    }
    // nobody stands inside anybody else: folk closer than an arm's length ease apart
    const up = this.list.filter((s) => s.folk.root.visible && s.state !== 'away');
    for (let i = 0; i < up.length; i++) for (let j = i + 1; j < up.length; j++) {
      const a = up[i].pos, b = up[j].pos, dx = b.x - a.x, dz = b.z - a.z, d = Math.hypot(dx, dz);
      if (d >= 0.95) continue;
      const k = Math.min(0.5, (0.95 - d) * 0.5) * Math.min(1, dt * 8), nx = d > 1e-4 ? dx / d : 1, nz = d > 1e-4 ? dz / d : 0;
      a.x -= nx * k; a.z -= nz * k; b.x += nx * k; b.z += nz * k;
    }
  }

  /** One line per settler for the settlers card. */
  rows(pieces) {
    return this.list.map((s) => {
      const S = s.S;
      const terms = S.how === 'deed' ? 'would join once you\'ve driven off a treasure guardian'
        : S.how === 'court' ? `would join if courted: ${this.danced ? 'you\'ve danced a reel (✓)' : 'dance a reel at the barn dance'}, and bring a pumpkin pie`
        : S.how === 'tale' ? `would join if you out-tell him by his fire after dark (you need ${S.tales} tall tales of your own)`
        : S.how === 'wrestle' ? 'would join if you beat him at arm-wrestling'
        : S.how === 'help' ? `would join if you bring ${Object.entries(S.wage).map(([k, n]) => `${n} ${k}`).join(' and ')} to ${S.chore || 'mend her lean-to'}`
          : `would join for ${Object.entries(S.wage).map(([k, n]) => `${n} ${k}`).join(' + ')}`;
      const status = s.state === 'away' ? (S.needs === 'boarding' && this.town ? 'not in town yet: will come once the boarding house has rooms to let (mend it)' : 'not met yet (build a storehouse)')
        : s.state === 'camp' ? `${this.town ? (S.needs ? 'rooms at the boarding house' : "lives on Squatters' Row") : 'camped at the edge of the farm'}; ${terms}`
          : !pieces.some((p) => p.type === S.work) ? `with you; waiting for you to build a ${WORK_NAME[S.work]}`
            : s.hauling ? `carrying ${s.load} ${S.item} to the storehouse`
            : `working the ${WORK_NAME[S.work]} (${s.load}/${LOAD} in the crate): about 1 ${S.item} every ${this.hungry.has(S.id) ? S.every * 2 : S.every} s by day${this.hungry.has(S.id) ? ' (hungry: no breakfast, so half pace; stock the larder)' : ''}`;
      return { name: S.name, trade: S.trade, status };
    });
  }
}

const _v = new THREE.Vector3(), _g = new THREE.Vector3(), _h = new THREE.Vector3();
