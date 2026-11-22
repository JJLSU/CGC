// The farmer's journal, retired: it used to show a chain of goals under the clock. Now there are no chores, just
// things to do; it only keeps a tally of what you've done (for the almanac). The old goals stay below for saves.
// written like an old farmer's almanac: one small tall tale at a time
export const GOALS = [
  { id: 'wood', text: 'Fell five trees for the woodpile', event: 'chop', need: 5, reward: { stone: 4 } },
  { id: 'berries', text: 'Pick three berry bushes', event: 'pick', need: 3, reward: { wood: 6 } },
  { id: 'hammer', text: 'Whittle yourself a hammer (C)', event: 'craft:hammer', need: 1, reward: { wood: 5 } },
  { id: 'fiber', text: 'Pull six armfuls of tall grass', event: 'gather:fiber', need: 6, reward: { berries: 4 } },
  { id: 'rope', text: 'Twist a length of rope', event: 'craft:rope', need: 1, reward: { stone: 4 } },
  { id: 'pat', text: 'Give Old Blue a good scratch behind the ears (E)', event: 'pat', need: 1, reward: { berries: 2 } },
  { id: 'bench', text: 'Build a workbench (B)', event: 'build:workbench', need: 1, reward: { stone: 4 } },
  { id: 'fire', text: 'Light a campfire to sit by', event: 'build:campfire', need: 1, reward: { berries: 4 } },
  { id: 'deer', text: 'Spot three deer in the woods', event: 'deer', need: 3, reward: { berries: 5 } },
  { id: 'clay', text: 'Dig clay from the riverbank', event: 'gather:clay', need: 6, reward: { wood: 6 } },
  { id: 'eggs', text: 'Gather eggs from the nesting box', event: 'gather:egg', need: 4, reward: { corn: 3 } },
  { id: 'milk', text: 'Milk the cow and shear a sheep', event: 'livestock', need: 2, reward: { berries: 4 } },
  { id: 'shoo', text: 'Shoo the crows out of the corn', event: 'shoo', need: 1, reward: { corn: 3 } },
  { id: 'scarecrow', text: 'Stand a scarecrow by the garden', event: 'build:scarecrow', need: 1, reward: { pumpkin: 1 } },
  { id: 'wheat', text: 'Gather wheat from the stooks in a field', event: 'gather:wheat', need: 6, reward: { egg: 2 } },
  { id: 'apples', text: 'Gather windfall apples in an old orchard', event: 'gather:apples', need: 6, reward: { honey: 1 } },
  { id: 'fish', text: 'Catch three fish from the bank', event: 'gather:fish', need: 3, reward: { berries: 4 } },
  { id: 'pick', text: 'Make a pickaxe at the workbench', event: 'craft:pickaxe', need: 1, reward: { rope: 1 } },
  { id: 'forge', text: 'Raise a forge of stone and clay', event: 'build:forge', need: 1, reward: { wood: 8 } },
  { id: 'spear', text: 'Make an ash spear, just in case', event: 'craft:spear', need: 1, reward: { berries: 4 } },
  { id: 'slay', text: 'Drive off a treasure guardian', event: 'slay', need: 1, reward: { stone: 8 } },
  { id: 'ore', text: 'Dig iron from a guarded vein', event: 'gather:ore', need: 4, reward: { wood: 8 } },
  { id: 'iron', text: 'Smelt iron at your forge', event: 'craft:iron', need: 2, reward: { rope: 2 } },
  { id: 'honey', text: 'Win honey from a wild hive', event: 'gather:honey', need: 2, reward: { berries: 6 } },
  { id: 'cake', text: 'Bake a honey cake by the fire', event: 'craft:honeycake', need: 1, reward: { wood: 6 } },
  { id: 'walls', text: 'Raise four walls of a cabin', event: 'build:wall', need: 4, reward: { wood: 8 } },
  { id: 'roof', text: 'Put a roof over your head', event: 'build:roof', need: 2, reward: { stone: 6 } },
  { id: 'bed', text: 'Sew a quilt and build a bed', event: 'build:bed', need: 1, reward: { berries: 4 } },
  { id: 'sleep', text: 'Sleep the night through', event: 'sleep', need: 1, reward: { wood: 6 } },
  { id: 'tinker', text: 'Trade with the travelling tinker', event: 'tinker', need: 1, reward: { rope: 1 } },
  { id: 'tales', text: 'Hear three tall tales by the campfire', event: 'tale', need: 3, reward: { honey: 1 } },
  { id: 'satchel', text: 'Find a lost satchel out in the wilds', event: 'satchel', need: 1, reward: { berries: 4 } },
  { id: 'skep', text: 'Keep bees: build a skep and take its honey', event: 'skep', need: 1, reward: { berries: 4 } },
  { id: 'snowman', text: 'Build a snowman on a snow day', event: 'build:snowman', need: 1, reward: { honey: 1 } },
  { id: 'request', text: "Fill one of the tinker's special requests", event: 'request', need: 1, reward: { iron: 1 } },
  { id: 'growtree', text: 'Plant an apple sapling and see it grow', event: 'growtree', need: 1, reward: { honey: 1 } },
  { id: 'letter', text: 'Read a letter from the mailbox', event: 'letter', need: 1, reward: { rope: 1 } },
  { id: 'jar', text: 'Catch a jarful of lightning bugs (craft the jar at a workbench)', event: 'firefly', need: 6, reward: { honey: 2 } },
  { id: 'cat', text: 'Make friends with Marmalade, the barn cat', event: 'cat', need: 3, reward: { fish: 1 } },
  { id: 'star', text: 'Find a fallen star (watch the sky on a clear night)', event: 'star', need: 1, reward: { honey: 1 } },
  { id: 'ribbon', text: 'Win a ribbon at the County Fair (every seventh day)', event: 'ribbon', need: 1, reward: { honeycake: 1 } },
  { id: 'dance', text: 'Dance a reel at the barn dance (fair night and midweek, from 5:30 pm)', event: 'dance', need: 1, reward: { pie: 1 } },
  { id: 'peace', text: 'Make peace with a guardian (3 apples for a boar, 2 fish for coyotes)', event: 'peace', need: 1, reward: { honey: 2 } },
  { id: 'kite', text: 'Fly a paper kite (make one at a workbench, then G)', event: 'kite', need: 1, reward: { apples: 3 } },
  { id: 'leaves', text: 'Run through a pile of autumn leaves', event: 'leaves', need: 1, reward: { berries: 4 } },
  { id: 'dandelion', text: 'Set a dandelion clock a-flying (walk through them in a meadow)', event: 'dandelion', need: 3, reward: { honey: 1 } },
  { id: 'cider', text: 'Build a cider press and press a mug of cider', event: 'cider', need: 1, reward: { iron: 1 } },
  { id: 'fetch', text: 'Play fetch with Old Blue (scratch him, and he may bring a stick)', event: 'fetch', need: 3, reward: { pelt: 1 } },
  { id: 'johnny', text: 'Pass the time of day with Johnny Appleseed when he comes by', event: 'johnny', need: 1, reward: { honey: 1 } },
  { id: 'feeder', text: 'Build a bird feeder and fill it (corn or berries)', event: 'feeder', need: 1, reward: { rope: 1 } },
  { id: 'skate', text: 'Go skating on a frozen pond (after a good snow)', event: 'skate', need: 8, reward: { honeycake: 1 } },
  { id: 'calf', text: 'Find the lost calf and lead it home (when it wanders)', event: 'calf', need: 1, reward: { biscuits: 1 } },
  { id: 'woodpile', text: 'Build a woodpile and stack a dozen logs on it', event: 'stack', need: 12, reward: { honey: 1 } },
  { id: 'giant', text: 'Grow a giant pumpkin on a patch (tend it each day) and cut it', event: 'giant', need: 1, reward: { honeycake: 1 } },
  { id: 'grandma', text: 'Knock at the farmhouse door of an evening (Grandma is up till half past ten)', event: 'grandma', need: 1, reward: { wool: 2 } },
  { id: 'ring', text: 'Find a fairy ring of toadstools (the morning after a rainy night)', event: 'ring', need: 1, reward: { honey: 1 } },
  { id: 'wish', text: "Bring Grandma what she's wishing for (knock of an evening)", event: 'wish', need: 1, reward: { honey: 1 } },
  { id: 'night', text: 'Watch the fireflies come out', event: 'night', need: 1, reward: { berries: 4 } },
  { id: 'ironaxe', text: 'Forge an iron axe', event: 'craft:ironaxe', need: 1, reward: { stone: 10 } },
  { id: 'coat', text: 'Sew a sheepskin coat from pelts', event: 'craft:coat', need: 1, reward: { honey: 2 } },
  { id: 'whiskers', text: 'Land Old Whiskers, the night-time catfish of legend', event: 'legendfish', need: 1, reward: { honeycake: 2 } },
  { id: 'legend', text: 'Drive off five guardians — a tall tale!', event: 'slay', need: 5, reward: { iron: 4 } },
];

export class Journal {
  constructor(el, { inventory, onComplete }) {
    this.el = el;
    this.inventory = inventory;
    this.onComplete = onComplete;
    this.progress = {}; // goal id → count
    this.done = new Set();
    this.sig = '';
  }

  load(data) {
    if (!data) return;
    this.progress = { ...(data.progress || {}) };
    this.done = new Set(data.done || []);
  }

  save() { return { progress: this.progress, done: [...this.done] }; }

  /**
   * No chores: the farm has no task list any more, only things you can do, so no goal is ever "active", nothing
   * is shown and no reward pops. What you do is still tallied (the almanac reads the day back when you sleep).
   */
  active() { return []; }

  /**
   * Record something that happened. It counts toward every goal still to do, shown or not, so what you did
   * before a goal came up isn't lost: when a goal reaches the list already met, it ticks off straight away.
   */
  record(event, n = 1) {
    let changed = false;
    for (const g of GOALS) {
      if (g.event !== event || this.done.has(g.id)) continue;
      const before = this.progress[g.id] || 0;
      this.progress[g.id] = Math.min(g.need, before + n);
      changed ||= this.progress[g.id] !== before;
    }
    if (this.settle() || changed) this.render();
    return changed;
  }

  /** Raise progress to at least `count` (for things the save can vouch for). */
  atLeast(id, count) {
    const g = GOALS.find((q) => q.id === id);
    if (g && !this.done.has(id)) this.progress[id] = Math.max(this.progress[id] || 0, Math.min(g.need, count));
  }

  /**
   * Catch up on what's plain to see in an older save: tools you own, pieces you've built, what's in your pack.
   * Called on load, before the first render; met goals then tick off as they reach the list.
   */
  catchUp({ tools, pieces, inventory }) {
    for (const g of GOALS) {
      if (this.done.has(g.id)) continue;
      const [kind, what] = g.event.split(':');
      if (kind === 'craft') this.atLeast(g.id, tools.has(what) ? g.need : inventory[what] || 0);
      else if (kind === 'build') this.atLeast(g.id, pieces.filter((p) => p.type === what).length);
      else if (kind === 'gather') this.atLeast(g.id, inventory[what] || 0);
    }
    if (this.settle()) this.render();
  }

  /** Tick off every shown goal that's already met (which can bring up more that are). */
  settle() {
    let any = false;
    for (let again = true; again;) {
      again = false;
      for (const g of this.active()) {
        if ((this.progress[g.id] || 0) < g.need) continue;
        this.done.add(g.id);
        for (const k in g.reward) this.inventory[k] = (this.inventory[k] || 0) + g.reward[k];
        this.onComplete?.(g);
        again = any = true;
      }
    }
    return any;
  }

  render() {
    this.el.style.display = 'none'; return; // (the goal card is retired)
    const goals = this.active();
    const sig = goals.map((g) => `${g.id}:${this.progress[g.id] || 0}`).join('|');
    if (sig === this.sig) return;
    this.sig = sig;
    if (!goals.length) { this.el.innerHTML = '<h4>Journal</h4><p class="all">Every page filled. What a season!</p>'; return; }
    this.el.innerHTML = '<h4>Journal</h4>' + goals.map((g) => {
      const p = this.progress[g.id] || 0;
      const reward = Object.entries(g.reward).map(([k, v]) => `+${v} ${k}`).join(', ');
      return `<div class="goal"><span class="box">${p > 0 ? '◩' : '▢'}</span><span>${g.text}${g.need > 1 ? ` <em>${p}/${g.need}</em>` : ''}<small>${reward}</small></span></div>`;
    }).join('');
  }
}
