// Your own gold claim: filed for at the Redrock Breaks trading post, staked out a short walk back along the line from
// that whistle-stop. Four corner stakes with rag flags, the claim notice on a post, an adit timbered into the red rock
// with a windlass over the shaft beside it, an ore cart on a few yards of plank track and a rack of tools. Once a day
// the vein gives up a few pinches of gold (more with a better pick), and now and then a nugget of silver. Hidden, and
// costing nothing, until it's yours.
//
// A hired hand (hired at the same post) works the vein for you every day, turning a pick at the adit mouth by day
// and sleeping in his tent by night; his takings pile up in the ore cart (up to five days' worth) till you come for them.
// A stamp mill (bought at the post once he's taken on) goes up beside the adit: its stamps thump away by day, crushing
// the quartz so far more of the gold comes out of it.
import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { paperMaterial } from './materials.js';
import { card } from './town.js';
import { propModel, ModelFigure, hasFolk } from './modelfolk.js';
import { getHeight } from './world.js';

export class Claim {
  constructor(scene, railroad) {
    this.rr = railroad; this.scene = scene; this.group = null; this.dugDay = -1;
    this.mill = null; this.thumpT = 0; this.onThump = null; // (onThump(dist): a stamp falling, for the sound)
    this.hand = null; this.stock = { gold: 0, silver: 0 }; this.handDay = -1; // (the hired hand's takings, waiting in the cart, and the last day he's worked)
    this.stop = railroad.stops.find((s) => s.land === 'breaks') || null;
  }
  /** Where the claim lies (worked out with the line, so its ground is cleared before the county is built). */
  get at() { return this.stop?.geo.claim || null; }
  /** Stake it out (once it's filed, and the line is down). */
  build() {
    if (this.group || !this.at || !this.rr.built) return;
    const { side } = this.stop.geo, at = this.at, y = getHeight(at.x, at.z), face = Math.atan2(-side.x, -side.z);
    const g = new THREE.Group(); g.position.set(at.x, y, at.z); g.rotation.y = face;
    const wood = paperMaterial({ color: 0x6a4a30, flatShading: true });
    const put = (name, size, x, z, turn = 0, byHeight = false) => {
      const src = propModel(name); if (!src) return null;
      const m = src.scene.clone(), bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3()), c = bb.getCenter(new THREE.Vector3()), k = size / (byHeight ? sz.y : Math.max(sz.x, sz.z));
      const hold = new THREE.Group(); m.position.set(-c.x, -bb.min.y, -c.z); hold.add(m); hold.scale.setScalar(k); hold.position.set(x, 0, z); hold.rotation.y = turn; g.add(hold); return hold;
    };
    put('mine_entrance', 4.2, 0, -3.4);
    put('mine_windlass', 2.2, -3.6, -1.2, 0.3);
    put('mine_orecart', 1.7, 2.6, 0.2, Math.PI / 2);
    put('mine_toolrack', 1.5, -3.4, 2.2, 0.5, true);
    // a few yards of plank track from the adit to the cart's tip
    const bits = [];
    for (let k = 0; k < 7; k++) bits.push(new THREE.BoxGeometry(1.2, 0.06, 0.22).translate(2.6, 0.03, -2.2 + k * 0.62).toNonIndexed());
    for (const x of [2.15, 3.05]) bits.push(new THREE.BoxGeometry(0.06, 0.06, 4.2).translate(x, 0.08, -0.4).toNonIndexed());
    const track = new THREE.Mesh(mergeGeometries(bits), wood); track.receiveShadow = true; g.add(track);
    // the four corner stakes, each with a strip of red rag
    const stakes = [], rags = [];
    for (const [x, z] of [[-6.6, -6.2], [5.5, -5], [-5.5, 4.5], [5.5, 4.5]]) {
      stakes.push(new THREE.BoxGeometry(0.1, 1.2, 0.1).translate(x, 0.6, z).toNonIndexed());
      rags.push(new THREE.BoxGeometry(0.34, 0.16, 0.02).translate(x + 0.2, 1.08, z).toNonIndexed());
    }
    const sm = new THREE.Mesh(mergeGeometries(stakes), wood); sm.castShadow = true; g.add(sm);
    const rm = new THREE.Mesh(mergeGeometries(rags), paperMaterial({ color: 0xb5473a, flatShading: true })); rm.castShadow = true; g.add(rm);
    // the claim notice, nailed to a post by the front stake
    const notice = card([[-0.55, 0], [0.55, 0.02], [0.56, 0.72], [-0.54, 0.7]], '#efe6cc', (gg, px) => {
      gg.fillStyle = '#3a2a1c'; gg.textAlign = 'center'; gg.textBaseline = 'middle';
      let [x, yy] = px(0, 0.58); gg.font = 'bold 30px Georgia, serif'; gg.fillText('NOTICE', x, yy);
      [x, yy] = px(0, 0.42); gg.font = 'italic 17px Georgia, serif'; gg.fillText('This ground is claimed', x, yy);
      [x, yy] = px(0, 0.31); gg.fillText('for mining purposes.', x, yy);
      [x, yy] = px(0, 0.16); gg.font = 'bold 18px Georgia, serif'; gg.fillText('THE HOMESTEAD LODE', x, yy);
      gg.strokeStyle = '#6a4a30'; gg.lineWidth = 3; gg.beginPath(); const [a, b] = px(-0.4, 0.5), [c] = px(0.4, 0.5); gg.moveTo(a, b); gg.lineTo(c, b); gg.stroke();
    }, { W: 256, H: 168, seed: 1900, thick: 0.03 });
    notice.position.set(-1.6, 0.9, 4.6); g.add(notice);
    const np = new THREE.Mesh(new THREE.BoxGeometry(0.1, 1.5, 0.1), wood); np.position.set(-1.6, 0.75, 4.55); np.castShadow = true; g.add(np);
    this.scene.add(g); this.group = g;
    this.digAt = g.localToWorld(new THREE.Vector3(0, 0, -1.2)); // (at the mouth of the adit)
    this.put = put;
  }
  /** Take on a hand: his tent goes up by the cart and he starts in at the adit tomorrow. */
  hire(day) {
    if (this.hand || !this.group) return;
    this.put('prop_tent', 2.3, -0.2, 2.0, 0.3); // (between the adit and the notice, clear of the cart track)
    const name = hasFolk('prospectors_6') ? 'prospectors_6' : 'prospectors_1';
    const f = new ModelFigure(name, { hue: 0.8 }); f.root.position.set(-0.7, 0, -1.4); f.root.rotation.y = Math.PI - 0.3; this.group.add(f.root); // (at the adit, facing into the rock)
    this.hand = f; if (this.handDay < 0) this.handDay = day;
  }
  /** Each new day the hand works, his takings go in the cart (five days' worth at most). By day he swings his pick at
   *  the adit (animated only while you're near); after dark he's in his tent. */
  update(dt, day, isDay, player) {
    if (!this.hand) return;
    while (this.handDay < day) {
      this.handDay++;
      if (this.stock.gold < (this.mill ? 25 : 15)) { this.stock.gold += 2 + (this.mill ? 2 : 0) + (Math.random() < 0.4 ? 1 : 0); if (Math.random() < 0.25) this.stock.silver++; }
    }
    const near = Math.hypot(this.at.x - player.pos.x, this.at.z - player.pos.z) < 60;
    this.hand.root.visible = isDay && near;
    if (this.hand.root.visible) this.hand.update(dt, 0, 'work');
    // the stamps falling, by day: a thump, and the whole frame giving a little shudder
    if (this.mill) {
      if (isDay && near) { if ((this.thumpT -= dt) <= 0) { this.thumpT = 0.85; this.onThump?.(Math.hypot(this.at.x - player.pos.x, this.at.z - player.pos.z)); } }
      this.mill.position.y = isDay && near ? Math.max(0, 0.03 - (0.85 - this.thumpT) * 0.12) : 0;
    }
  }
  /** Put up the stamp mill beside the adit. */
  addMill() { if (!this.mill && this.group) this.mill = this.put('mine_stampmill', 3.4, -4.1, -4.2, 0.35); }
  /** Empty the cart: whatever the hand has dug since you were last out. */
  collect() { const s = this.stock; this.stock = { gold: 0, silver: 0 }; return s; }
  save() { return { dug: this.dugDay, stock: this.stock, handDay: this.handDay }; }
  /** Standing at the adit mouth? */
  near(x, z, r = 2.4) { return !!this.digAt && Math.hypot(this.digAt.x - x, this.digAt.z - z) < r; }
  /** Work the vein: a few pinches of gold (more with a better pick), sometimes silver. Once a day. */
  dig(day, tools) {
    if (this.dugDay === day) return null;
    this.dugDay = day;
    const gold = 2 + (this.mill ? 1 : 0) + (tools.has('ironpick') ? 1 : 0) + (tools.has('steelpick') ? 1 : 0) + (Math.random() < 0.3 ? 1 : 0);
    const silver = Math.random() < 0.35 ? 1 : 0;
    return { gold, silver };
  }
}
