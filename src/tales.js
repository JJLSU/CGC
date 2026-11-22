// Tall tales by the fire: sit at a campfire after dark (E) and the farmer tells himself one of the old
// county stories, printed on a paper card. An hour slips by, the fire mends you, and the journal counts
// the tales you've heard. All stories here are original tellings written for this game.
export const TALES = [
  {
    title: 'The Summer the Corn Grew Too Tall',
    text: 'Old Mabry planted his corn the week of the big thunder, and by July the stalks were brushing the clouds. '
      + 'He sent his boy up one to fetch an ear for supper, and the boy came down in October with a beard, '
      + 'a sack of ears, and a story about the moon being mostly cheese rind after all.',
  },
  {
    title: 'The Crow Who Kept Accounts',
    text: 'There was a crow down by the mill who could count to a hundred and never forgot a debt. '
      + 'Every kernel you took from his field he wrote on a birch leaf, and every autumn he came to collect. '
      + 'Folks say that is why we leave the last row standing: it squares the ledger.',
  },
  {
    title: 'How the River Learned to Bend',
    text: 'Back when the river ran straight as a fence rail, it was in such a hurry that the fish got dizzy. '
      + 'A heron stood in the middle of it one whole summer and would not budge, so the water had to go around. '
      + 'It liked the scenery so much it has been taking the long way ever since.',
  },
  {
    title: 'The Tinker and the Thunderhead',
    text: 'One spring a thunderhead parked over the county and would not move along. '
      + 'The tinker sold it a tin bucket, a length of rope and a jar of honey, and talked so long about the '
      + 'roads to the west that the storm packed up and followed him, raining polite little showers the whole way.',
  },
  {
    title: 'The Boar Who Guarded Nothing',
    text: 'Deep in the woods an old bramble boar guarded a hollow log for forty years. '
      + 'When a farmer finally peeked inside, there was only a note in a careful hand: "Keep watching." '
      + 'Nobody knows who wrote it, but the boars out there still take the job seriously.',
  },
  {
    title: 'The Quilt That Kept the Frost Away',
    text: 'Grandmother Pell stitched a quilt from every patch of every shirt the family ever wore out. '
      + 'The first cold night she spread it over the garden instead of the bed, and Jack Frost took one look, '
      + 'recognised his own old mittens in the corner square, and went home ashamed.',
  },
];

export class Tales {
  constructor(el) {
    this.el = el;
    this.heard = new Set();
    this.open = false;
  }

  load(list) { for (const i of list || []) this.heard.add(i); }
  save() { return [...this.heard]; }

  /** The next tale: one not heard yet if any remain, else any. Returns its index. */
  next() {
    const fresh = TALES.map((_, i) => i).filter((i) => !this.heard.has(i));
    const pool = fresh.length ? fresh : TALES.map((_, i) => i);
    return pool[Math.floor(Math.random() * pool.length)];
  }

  tell() {
    const i = this.next();
    const isNew = !this.heard.has(i);
    this.heard.add(i);
    const t = TALES[i];
    this.el.innerHTML = `<h2>${t.title}</h2><p>${t.text}</p><small>${this.heard.size} of ${TALES.length} tall tales heard · E to stir the fire and close</small>`;
    this.setOpen(true);
    return isNew;
  }

  setOpen(v) { this.open = v; this.el.classList.toggle('show', v); }
}
