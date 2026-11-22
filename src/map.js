// The county map (Tab): a hand-inked map on a torn sheet of handmade paper, washed in watercolour where
// you've been and left blank parchment where you haven't. It marks the homestead, the tinker's lane, the
// guarded sites you've come across (an iron vein or a hive grove) and where you stand. Exploration is
// remembered in 16 m cells and saved with the game. The map is painted once when opened (~16k samples).
import { regionAt, landAt, landTint, LANDS } from './world.js';

const CELL = 16, SEE = 3; // cells; you "see" about 48 m around you
const SPAN = 320;         // metres across the sheet
const W = 560;            // canvas pixels
const WASH = { water: '#8fb3ad', forest: '#93a35c', meadow: '#d6c47a', field: '#e2b65a', highland: '#b8a68a', peak: '#d9d2c4' };

export class CountyMap {
  constructor(el) {
    this.el = el;
    this.canvas = el.querySelector('canvas');
    this.canvas.width = this.canvas.height = W;
    this.explored = new Set();
    this.cell = '';
    this.open = false;
    this.small = document.createElement('canvas');
    this.small.width = this.small.height = 140;
  }

  load(list) { for (const k of list || []) this.explored.add(k); }
  save() { return [...this.explored]; }

  /** Mark the cells around the farmer as explored (only when he steps into a new cell). */
  update(pos) {
    const ci = Math.floor(pos.x / CELL), cj = Math.floor(pos.z / CELL), key = `${ci},${cj}`;
    if (key === this.cell) return;
    this.cell = key;
    for (let dj = -SEE; dj <= SEE; dj++) for (let di = -SEE; di <= SEE; di++) {
      if (di * di + dj * dj <= SEE * SEE + 1) this.explored.add(`${ci + di},${cj + dj}`);
    }
  }

  seen(x, z) { return this.explored.has(`${Math.floor(x / CELL)},${Math.floor(z / CELL)}`); }

  toggle(ctx) { this.setOpen(!this.open, ctx); }

  setOpen(v, ctx) {
    this.open = v;
    this.el.classList.toggle('show', v);
    if (v) this.paint(ctx);
  }

  /** ctx: { player, camera, home, sites, tinker } */
  paint({ player, camera, home, sites, tinker, orchards = [], pieces = [], fair = null, star = null, town = null }) {
    const g = this.canvas.getContext('2d');
    const cx = player.pos.x, cz = player.pos.z;
    const toPx = (x, z) => [((x - cx) / SPAN + 0.5) * W, ((z - cz) / SPAN + 0.5) * W];

    // 1. watercolour wash of the land, sampled coarse and scaled up soft; unexplored left as parchment
    const s = this.small.getContext('2d'), N = this.small.width;
    const img = s.createImageData(N, N);
    const named = {}, tint = [1, 1, 1]; // where each wild land you've seen lies on the sheet, to letter its name
    for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
      const x = cx + (i / N - 0.5) * SPAN, z = cz + (j / N - 0.5) * SPAN, o = (j * N + i) * 4;
      // a ragged, hand-washed edge to what you know: jitter the explored test by a little value noise
      const jx = (hash(i >> 1, j >> 1) - 0.5) * 14, jz = (hash(j >> 1, i >> 1) - 0.5) * 14;
      if (!this.seen(x + jx, z + jz)) { img.data[o + 3] = 0; continue; }
      const hex = WASH[regionAt(x, z)] || WASH.meadow;
      landTint(x, z, tint); // the wild lands wash in their own colours
      img.data[o] = Math.min(255, parseInt(hex.slice(1, 3), 16) * tint[0]); img.data[o + 1] = Math.min(255, parseInt(hex.slice(3, 5), 16) * tint[1]); img.data[o + 2] = Math.min(255, parseInt(hex.slice(5, 7), 16) * tint[2]);
      const L = landAt(x, z); if (L.wild > 0.7) { const n = (named[L.id] ||= [0, 0, 0]); n[0] += i; n[1] += j; n[2]++; }
      img.data[o + 3] = 215;
    }
    s.putImageData(img, 0, 0);
    g.clearRect(0, 0, W, W);
    g.fillStyle = '#efe3c4'; g.fillRect(0, 0, W, W);
    g.save();
    g.filter = 'blur(3px)';
    g.imageSmoothingEnabled = true;
    g.drawImage(this.small, 0, 0, W, W);
    g.restore();
    // a second, sharper pass gives the wash a pigment-pooled edge
    g.globalAlpha = 0.35; g.drawImage(this.small, 0, 0, W, W); g.globalAlpha = 1;

    // 2. paper fibre specks
    for (let k = 0; k < 700; k++) { g.fillStyle = `rgba(90,60,30,${Math.random() * 0.08})`; g.fillRect(Math.random() * W, Math.random() * W, 1.5, 1.5); }

    // 3. inked marks
    g.lineCap = g.lineJoin = 'round';
    const ink = '#3a2a1c';
    const label = (text, x, y) => { g.font = "italic 17px Georgia, 'Times New Roman', serif"; g.fillStyle = ink; g.textAlign = 'center'; g.fillText(text, x, y); };
    // the wild lands you've seen, lettered big across their country like an old surveyor's map
    for (const [id, n] of Object.entries(named)) {
      if (n[2] < 40) continue;
      const x = (n[0] / n[2] / N) * W, y = (n[1] / n[2] / N) * W;
      g.save(); g.font = "italic 22px Georgia, 'Times New Roman', serif"; g.fillStyle = 'rgba(58,42,28,0.75)'; g.textAlign = 'center';
      const name = LANDS[id].name.replace(/^the /, '').toUpperCase(); g.letterSpacing = '3px'; g.fillText(name, x, y); g.restore();
    }
    // Paydirt Hollow: each of its streets an inked ochre band with a little row of false fronts down either side, and
    // the town's name lettered by it (once you've been near enough to see it)
    if (town?.at && this.seen(town.at.x, town.at.z)) {
      g.save();
      for (const off of town.offs) {
        const a = town.at.clone().addScaledVector(town.toward, off), e0 = a.clone().addScaledVector(town.along, -24), e1 = a.clone().addScaledVector(town.along, 24);
        const [x0, y0] = toPx(e0.x, e0.z), [x1, y1] = toPx(e1.x, e1.z);
        g.strokeStyle = '#c9a46a'; g.lineWidth = 7; g.lineCap = 'round'; g.beginPath(); g.moveTo(x0, y0); g.lineTo(x1, y1); g.stroke();
        g.strokeStyle = ink; g.lineWidth = 1; g.stroke();
        for (let s = -20; s <= 20; s += 8) for (const side of [-1, 1]) { // (the false fronts: little inked squares with a stepped top)
          const p = a.clone().addScaledVector(town.along, s).addScaledVector(town.toward, side * 9.5), [x, y] = toPx(p.x, p.z);
          g.fillStyle = side > 0 ? '#b8875a' : '#a87a52'; g.strokeStyle = ink; g.lineWidth = 1; g.beginPath(); g.rect(x - 3, y - 3, 6, 6); g.fill(); g.stroke();
        }
      }
      const [tx, ty] = toPx(town.at.x, town.at.z);
      g.font = "bold italic 17px Georgia, 'Times New Roman', serif"; g.fillStyle = ink; g.textAlign = 'center';
      // lettered on a little torn cream chit pinned above the streets, so it reads clear of anything drawn round it
      const pop = town.mended ? `pop. ${11 + town.mended * 4}` : 'pop. 11 (and falling)', cy = ty - 34, cw = Math.max(g.measureText('Paydirt Hollow').width, 90) + 16;
      g.fillStyle = 'rgba(0,0,0,0.18)'; g.fillRect(tx - cw / 2 + 2, cy - 15, cw, 34);
      g.fillStyle = '#f3ead6'; g.beginPath(); g.moveTo(tx - cw / 2, cy - 17); for (let i = 0; i <= 8; i++) g.lineTo(tx - cw / 2 + (cw * i) / 8, cy - 17 + (i % 2 ? 1.5 : -1)); g.lineTo(tx + cw / 2, cy + 15); for (let i = 8; i >= 0; i--) g.lineTo(tx - cw / 2 + (cw * i) / 8, cy + 15 + (i % 2 ? -1 : 1.5)); g.closePath(); g.fill();
      g.strokeStyle = ink; g.lineWidth = 1; g.stroke();
      g.fillStyle = ink; g.fillText('Paydirt Hollow', tx, cy); g.font = "italic 12px Georgia, 'Times New Roman', serif"; g.fillText(pop, tx, cy + 12);
      g.beginPath(); g.moveTo(tx, cy + 16); g.lineTo(tx, ty - 6); g.stroke(); // (a pin-line down to the town)
      g.restore();
    }
    if (tinker?.here && this.seen(tinker.pos.x, tinker.pos.z)) {
      const [x, y] = toPx(tinker.pos.x, tinker.pos.z);
      g.fillStyle = '#d9a441'; g.strokeStyle = ink; g.lineWidth = 2; g.beginPath(); g.arc(x, y, 6, 0, Math.PI * 2); g.fill(); g.stroke();
      label('Tinker', x + 30, y + 5);
    }
    // old orchards: a little round apple tree with red dots
    for (const o of orchards) {
      if (!this.seen(o.x, o.z)) continue;
      const [x, y] = toPx(o.x, o.z);
      if (x < 0 || y < 0 || x > W || y > W) continue;
      g.fillStyle = '#7d9a4e'; g.strokeStyle = ink; g.lineWidth = 1.5;
      g.beginPath(); g.arc(x, y - 4, 8, 0, Math.PI * 2); g.fill(); g.stroke();
      g.fillStyle = '#6b4a30'; g.fillRect(x - 1.5, y + 3, 3, 6);
      g.fillStyle = '#c4362f'; for (const [ax, ay] of [[-3, -6], [3, -3], [0, -1]]) { g.beginPath(); g.arc(x + ax, y - 4 + ay + 2, 1.8, 0, Math.PI * 2); g.fill(); }
      label('Apples', x, y + 22);
    }
    // your own camps: a little flame for each campfire, a quilt square for each bed, a dot of planks for docks,
    // and a little glyph for the rest of your yard: woodpiles, feeders, cider presses, pumpkin patches, apple trees
    const marks = { campfire: '#e07a2e', bed: '#b5473a', dock: '#c99a5e', skep: '#d9a948', woodpile: '#7a5636', feeder: '#4f6f96', press: '#c4362f', patch: '#de7a32', homeapple: '#7d9a4e', forge: '#8a8580' };
    for (const pc of pieces) {
      const col = marks[pc.type]; if (!col) continue;
      const [x, y] = toPx(pc.x, pc.z);
      if (x < 0 || y < 0 || x > W || y > W) continue;
      g.fillStyle = col; g.strokeStyle = ink; g.lineWidth = 1;
      if (pc.type === 'campfire') { g.beginPath(); g.moveTo(x, y - 7); g.quadraticCurveTo(x + 6, y, x, y + 4); g.quadraticCurveTo(x - 6, y, x, y - 7); g.fill(); g.stroke(); }
      else if (pc.type === 'woodpile') { for (const [ox, oy] of [[-3, 2], [3, 2], [0, -3]]) { g.beginPath(); g.arc(x + ox, y + oy, 3, 0, Math.PI * 2); g.fill(); g.stroke(); } } // three log ends
      else if (pc.type === 'patch' || pc.type === 'homeapple') { g.beginPath(); g.arc(x, y, 5, 0, Math.PI * 2); g.fill(); g.stroke(); }
      else if (pc.type === 'feeder') { g.beginPath(); g.moveTo(x - 6, y); g.lineTo(x, y - 6); g.lineTo(x + 6, y); g.closePath(); g.fill(); g.stroke(); g.fillRect(x - 1, y, 2, 6); } // a little roof on a post
      else { g.fillRect(x - 3, y - 3, 6, 6); g.strokeRect(x - 3, y - 3, 6, 6); }
    }
    // the County Fair's judging table, on fair days: a blue rosette
    if (fair && this.seen(fair.x, fair.z)) {
      const [x, y] = toPx(fair.x, fair.z);
      g.fillStyle = '#4a7ab8'; g.strokeStyle = ink; g.lineWidth = 1.5;
      g.beginPath(); for (let k = 0; k <= 16; k++) { const a = (k / 16) * Math.PI * 2, r = k % 2 ? 6 : 9; g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r); } g.closePath(); g.fill(); g.stroke();
      g.fillStyle = '#d9a441'; g.beginPath(); g.arc(x, y, 3.5, 0, Math.PI * 2); g.fill();
      label('Fair', x - 26, y + 8);
    }
    // a fallen star, glowing somewhere out in the grass
    if (star) {
      const [x, y] = toPx(star.x, star.z);
      if (x > 0 && y > 0 && x < W && y < W) {
        g.fillStyle = '#e8c870'; g.strokeStyle = ink; g.lineWidth = 1.5;
        g.beginPath(); for (let k = 0; k < 10; k++) { const a = -Math.PI / 2 + (k * Math.PI) / 5, r = k % 2 ? 4 : 9; g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r); } g.closePath(); g.fill(); g.stroke();
        label('Star', x + 24, y + 4);
      }
    }
    let ironOn = false;
    for (const site of sites) {
      const known = this.seen(site.x, site.z);
      if (!known && !site.rumour) continue;
      const [x, y] = toPx(site.x, site.z);
      if (x < 0 || y < 0 || x > W || y > W) continue;
      g.strokeStyle = ink; g.lineWidth = 2.5;
      if (site.kind === 'camp') { // their land: a ring of red dashes where the painted poles stand, and a little lodge
        const [ex] = toPx(site.x + site.r, site.z), rr = Math.abs(ex - x);
        g.save(); g.setLineDash([5, 5]); g.strokeStyle = '#a8352a'; g.lineWidth = 2; g.beginPath(); g.arc(x, y, rr, 0, Math.PI * 2); g.stroke(); g.restore();
        g.fillStyle = '#e6d3ae'; g.strokeStyle = ink; g.lineWidth = 1.5; g.beginPath(); g.moveTo(x - 8, y + 7); g.lineTo(x, y - 9); g.lineTo(x + 8, y + 7); g.closePath(); g.fill(); g.stroke();
        g.beginPath(); g.moveTo(x - 2, y - 13); g.lineTo(x, y - 9); g.lineTo(x + 2, y - 13); g.stroke();
        label(site.peace > 0 ? `Friends: welcome ${site.peace} day${site.peace > 1 ? 's' : ''}` : 'Their land', x, y + rr + 16); // (a gift at the poles shows here)
        continue;
      }
      if (site.kind === 'vein') { // crossed picks; an iron vein you haven't seen yet is inked faint, from the assayer's say-so
        ironOn = true; g.globalAlpha = known ? 1 : 0.55;
        g.beginPath(); g.moveTo(x - 8, y - 8); g.lineTo(x + 8, y + 8); g.moveTo(x + 8, y - 8); g.lineTo(x - 8, y + 8); g.stroke();
        label(known ? 'Iron' : 'Iron?', x, y + 24); g.globalAlpha = 1;
      } else if (site.kind === 'thicket') { // a sprig of three berries
        g.fillStyle = '#c4363a'; for (const [bx, by] of [[-5, 2], [5, 2], [0, -5]]) { g.beginPath(); g.arc(x + bx, y + by, 4.5, 0, Math.PI * 2); g.fill(); g.stroke(); }
        label('Berries', x, y + 24);
      } else if (site.kind === 'landmark') { // a landmark: an inked compass star, named once you've been there
        g.fillStyle = '#d9a441'; g.beginPath(); for (let k = 0; k < 8; k++) { const a = -Math.PI / 2 + (k * Math.PI) / 4, r = k % 2 ? 4 : 11; g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r); } g.closePath(); g.fill(); g.stroke();
        label(site.foundName || '?', x, y + 26);
      } else if (site.land) { // a wild land's treasure: a question mark, till you know what keeps it
        g.fillStyle = '#efe3c4'; g.beginPath(); g.arc(x, y, 9, 0, Math.PI * 2); g.fill(); g.stroke();
        g.font = "bold 14px Georgia, serif"; g.fillStyle = ink; g.textAlign = 'center'; g.fillText('?', x, y + 5);
        label({ sang: 'Sang', silver: 'Silver', pearl: 'Pearls', geode: 'Thunder eggs', amber: 'Amber' }[site.kind] || '?', x, y + 26);
      } else { // a skep hive
        g.fillStyle = '#d9a948'; g.beginPath(); g.ellipse(x, y, 8, 9, 0, Math.PI, 0); g.lineTo(x + 8, y + 5); g.lineTo(x - 8, y + 5); g.closePath(); g.fill(); g.stroke();
        label('Honey', x, y + 24);
      }
    }
    // the farmer: an inked arrow pointing the way he faces
    {
      const [x, y] = toPx(cx, cz);
      const f = player.forward(_f);
      const a = Math.atan2(f.x, -f.z);
      g.save(); g.translate(x, y); g.rotate(a);
      g.fillStyle = '#b5523b'; g.strokeStyle = ink; g.lineWidth = 2;
      g.beginPath(); g.moveTo(0, -13); g.lineTo(8, 9); g.lineTo(0, 4); g.lineTo(-8, 9); g.closePath(); g.fill(); g.stroke();
      g.restore();
    }
    // an inset of the home place, drawn bigger in the lower-left corner: around here the county map is too small
    // to tell your woodpile from your bird feeder, so the yard gets its own little pinned-on sheet
    const homeOn = home && (() => { const [x, y] = toPx(home.x, home.z); return x >= 0 && y >= 0 && x <= W && y <= W; })();
    if (homeOn) { // (only while home is on the sheet; further off, an arrow on the margin points the way instead)
      const IW = 150, ix = 14, iy = W - IW - 62, S = IW / 56; // 56 m across
      const ip = (x, z) => [ix + IW / 2 + (x - home.x) * S, iy + IW / 2 + (z - home.z) * S];
      g.save();
      g.fillStyle = '#efe3c4'; g.strokeStyle = ink; g.lineWidth = 1.5; g.translate(ix + IW / 2, iy + IW / 2); g.rotate(-0.02); g.translate(-(ix + IW / 2), -(iy + IW / 2));
      g.fillRect(ix, iy, IW, IW); g.strokeRect(ix, iy, IW, IW);
      g.beginPath(); g.rect(ix, iy, IW, IW); g.clip();
      g.font = "italic 13px Georgia, 'Times New Roman', serif"; g.fillStyle = ink; g.textAlign = 'left'; g.fillText('The home place', ix + 6, iy + 15);
      { const [x, y] = ip(home.x, home.z); g.fillStyle = '#b5473a'; g.beginPath(); g.moveTo(x - 9, y + 6); g.lineTo(x - 9, y - 2); g.lineTo(x, y - 10); g.lineTo(x + 9, y - 2); g.lineTo(x + 9, y + 6); g.closePath(); g.fill(); g.stroke(); }
      const glyph = (type, x, y) => {
        const col = marks[type]; if (!col) return;
        g.fillStyle = col; g.strokeStyle = ink; g.lineWidth = 1;
        if (type === 'campfire') { g.beginPath(); g.moveTo(x, y - 6); g.quadraticCurveTo(x + 5, y, x, y + 4); g.quadraticCurveTo(x - 5, y, x, y - 6); g.fill(); g.stroke(); }
        else if (type === 'woodpile') { for (const [ox, oy] of [[-3, 2], [3, 2], [0, -3]]) { g.beginPath(); g.arc(x + ox, y + oy, 2.6, 0, Math.PI * 2); g.fill(); g.stroke(); } }
        else if (type === 'patch' || type === 'homeapple') { g.beginPath(); g.arc(x, y, 4.5, 0, Math.PI * 2); g.fill(); g.stroke(); }
        else if (type === 'feeder') { g.beginPath(); g.moveTo(x - 5, y); g.lineTo(x, y - 5); g.lineTo(x + 5, y); g.closePath(); g.fill(); g.stroke(); g.fillRect(x - 1, y, 2, 5); }
        else { g.fillRect(x - 3, y - 3, 6, 6); g.strokeRect(x - 3, y - 3, 6, 6); }
      };
      for (const pc of pieces) { const [x, y] = ip(pc.x, pc.z); if (x > ix && y > iy && x < ix + IW && y < iy + IW) glyph(pc.type, x, y); }
      if (fair) { const [x, y] = ip(fair.x, fair.z); g.fillStyle = '#4a7ab8'; g.beginPath(); g.arc(x, y, 5, 0, Math.PI * 2); g.fill(); g.stroke(); }
      if (tinker?.here) { const [x, y] = ip(tinker.pos.x, tinker.pos.z); g.fillStyle = '#d9a441'; g.beginPath(); g.arc(x, y, 4.5, 0, Math.PI * 2); g.fill(); g.stroke(); }
      { const [x, y] = ip(player.pos.x, player.pos.z); g.fillStyle = '#b5523b'; g.beginPath(); g.arc(x, y, 3.5, 0, Math.PI * 2); g.fill(); g.stroke(); } // you
      g.restore();
    }
    // compass rose (north = −z) and a scale bar
    {
      const x = W - 50, y = 54;
      g.strokeStyle = ink; g.lineWidth = 1.5; g.fillStyle = ink;
      g.beginPath(); g.arc(x, y, 22, 0, Math.PI * 2); g.stroke();
      g.beginPath(); g.moveTo(x, y - 30); g.lineTo(x + 6, y); g.lineTo(x, y + 30); g.lineTo(x - 6, y); g.closePath(); g.fill();
      g.font = "bold 16px Georgia, serif"; g.textAlign = 'center'; g.fillText('N', x, y - 34);
      const px50 = (50 / SPAN) * W;
      g.lineWidth = 2; g.beginPath(); g.moveTo(24, W - 28); g.lineTo(24 + px50, W - 28); g.moveTo(24, W - 33); g.lineTo(24, W - 23); g.moveTo(24 + px50, W - 33); g.lineTo(24 + px50, W - 23); g.stroke();
      g.font = "italic 14px Georgia, serif"; g.textAlign = 'left'; g.fillText('50 yards, more or less', 24, W - 38);
    }
    // no iron on the sheet: a grey inked arrow on the margin toward the nearest vein the assayer knows of, with the distance
    const vein = !ironOn && sites.filter((s) => s.kind === 'vein').sort((a, b) => Math.hypot(a.x - cx, a.z - cz) - Math.hypot(b.x - cx, b.z - cz))[0];
    if (vein) {
      const [x, y] = toPx(vein.x, vein.z), dx = x - W / 2, dy = y - W / 2, M = W / 2 - 44, k = M / Math.max(Math.abs(dx), Math.abs(dy));
      const ax = W / 2 + dx * k, ay = W / 2 + dy * k, ang = Math.atan2(dy, dx);
      g.save(); g.translate(ax, ay); g.rotate(ang); g.fillStyle = '#7a7470'; g.strokeStyle = ink; g.lineWidth = 2;
      g.beginPath(); g.moveTo(20, 0); g.lineTo(2, -11); g.lineTo(6, -4); g.lineTo(-14, -4); g.lineTo(-14, 4); g.lineTo(6, 4); g.lineTo(2, 11); g.closePath(); g.fill(); g.stroke(); g.restore();
      const paces = Math.round((Math.hypot(vein.x - cx, vein.z - cz) * 1.3) / 10) * 10;
      label(`Iron, ${paces} paces`, Math.min(W - 70, Math.max(70, ax - Math.cos(ang) * 50)), Math.min(W - 16, Math.max(24, ay - Math.sin(ang) * 32)));
    }
    // their land off the sheet: a red inked arrow on the margin toward the camp, with the distance
    const off = (q) => { const [x, y] = toPx(q.x, q.z); return x < 0 || y < 0 || x > W || y > W; };
    const camps = sites.filter((q) => q.kind === 'camp');
    const campSite = !camps.some((q) => !off(q)) && camps.sort((a, b) => Math.hypot(a.x - cx, a.z - cz) - Math.hypot(b.x - cx, b.z - cz))[0]; // (the nearest, when none is on the sheet)
    if (campSite) {
      const [x, y] = toPx(campSite.x, campSite.z);
      {
        const dx = x - W / 2, dy = y - W / 2, M = W / 2 - 44, k = M / Math.max(Math.abs(dx), Math.abs(dy)), ax = W / 2 + dx * k, ay = W / 2 + dy * k, ang = Math.atan2(dy, dx);
        g.save(); g.translate(ax, ay); g.rotate(ang); g.fillStyle = '#a8352a'; g.strokeStyle = ink; g.lineWidth = 2;
        g.beginPath(); g.moveTo(20, 0); g.lineTo(2, -11); g.lineTo(6, -4); g.lineTo(-14, -4); g.lineTo(-14, 4); g.lineTo(6, 4); g.lineTo(2, 11); g.closePath(); g.fill(); g.stroke(); g.restore();
        const paces = Math.round((Math.hypot(campSite.x - cx, campSite.z - cz) * 1.3) / 10) * 10;
        label(`${campSite.peace > 0 ? 'Friends' : 'Their land'}, ${paces} paces`, Math.min(W - 90, Math.max(90, ax - Math.cos(ang) * 60)), Math.min(W - 16, Math.max(24, ay - Math.sin(ang) * 32)));
      }
    }
      // (drawn last, over the inset) out past the edge of the sheet: an inked arrow on the margin pointing the way home, with the distance
    if (home) {
      const [x, y] = toPx(home.x, home.z);
      if (x < 0 || y < 0 || x > W || y > W) {
        const dx = x - W / 2, dy = y - W / 2, M = W / 2 - 38, k = M / Math.max(Math.abs(dx), Math.abs(dy));
        const ax = W / 2 + dx * k, ay = W / 2 + dy * k, ang = Math.atan2(dy, dx);
        g.save(); g.translate(ax, ay); g.rotate(ang);
        g.fillStyle = '#a8352a'; g.strokeStyle = ink; g.lineWidth = 2;
        g.beginPath(); g.moveTo(22, 0); g.lineTo(2, -12); g.lineTo(6, -4); g.lineTo(-16, -4); g.lineTo(-16, 4); g.lineTo(6, 4); g.lineTo(2, 12); g.closePath(); g.fill(); g.stroke();
        g.restore();
        const paces = Math.max(10, Math.round((Math.hypot(home.x - cx, home.z - cz) * 1.3) / 10) * 10);
        const lx = Math.min(W - 70, Math.max(70, ax - Math.cos(ang) * 46)), ly = Math.min(W - 16, Math.max(24, ay - Math.sin(ang) * 30));
        label(`Home, ${paces} paces`, lx, ly);
      } else {
        // on the sheet: a big red house on a cream badge, drawn over everything else so it never hides
        g.fillStyle = '#f6efe0'; g.strokeStyle = ink; g.lineWidth = 2; g.beginPath(); g.arc(x, y - 2, 19, 0, Math.PI * 2); g.fill(); g.stroke();
        g.fillStyle = '#a8352a'; g.lineWidth = 2;
        g.beginPath(); g.moveTo(x - 12, y + 9); g.lineTo(x - 12, y - 3); g.lineTo(x, y - 15); g.lineTo(x + 12, y - 3); g.lineTo(x + 12, y + 9); g.closePath(); g.fill(); g.stroke();
        g.fillStyle = '#f6efe0'; g.fillRect(x - 3, y + 1, 6, 8);
        const d = Math.hypot(home.x - cx, home.z - cz), paces = Math.round((d * 1.3) / 10) * 10;
        const ly = y + 36 > W - 8 ? y - 28 : y + 36;
        g.font = "bold italic 17px Georgia, 'Times New Roman', serif"; g.textAlign = 'center';
        const text = d > 25 ? `Home, ${paces} paces` : 'Home';
        g.lineWidth = 4; g.strokeStyle = 'rgba(246,239,224,0.9)'; g.strokeText(text, x, ly); g.fillStyle = ink; g.fillText(text, x, ly);
      }
    }
  }
}

function hash(a, b) { const h = Math.sin(a * 127.1 + b * 311.7) * 43758.5453; return h - Math.floor(h); }

const _f = { x: 0, y: 0, z: 0, set(x, y, z) { this.x = x; this.y = y; this.z = z; return this; } };
