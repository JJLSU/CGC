// Grandma Pell in the window: of an evening, once the lamps are lit (about 18:30 till 22:30), the lamplit
// front window of the farmhouse shows her shadow: a cut-paper silhouette in her rocking chair, hair in a bun,
// knitting, rocking slowly back and forth. At half past ten the lamp is turned down and she's gone up to bed.
// Knock at the front door (E) of an evening and she hands out a warm slice of pie, once a night, with a word.
import * as THREE from 'three/webgpu';

export const PIE_WORDS = [
  `"There you are! Take this before it goes cold, and wipe your boots."`,
  `"I made two, and your grandfather never could finish one. Go on."`,
  `"Pumpkin, with a little nutmeg. Don't tell the Grange ladies my secret."`,
  `"You work too hard. Sit on the porch a spell and eat that slowly."`,
];

// what Grandma's after today (one a day, picked by the calendar), and what she bakes you for it
export const WISHES = [
  { cost: { egg: 4 }, gives: { honeycake: 1, pie: 1 }, ask: 'four eggs for a custard', thanks: 'Four lovely brown eggs! Here, a honey cake and a pie for your trouble.' },
  { cost: { milk: 2 }, gives: { biscuits: 3 }, ask: 'two pails of milk to churn some butter', thanks: 'Fresh from Daisy! Take these biscuits, still warm, with the first of the butter.' },
  { cost: { wool: 3 }, gives: { pie: 2, rope: 1 }, ask: 'three fleeces of wool to knit you a muffler', thanks: 'Soft as a cloud. I will have it knitted by first frost. Two pies, and your grandfather’s old rope.' },
  { cost: { apples: 6 }, gives: { applecrisp: 2 }, ask: 'six good apples for apple butter', thanks: 'These will make a crock of apple butter fit for a fair. Two apple crisps, and mind you share.' },
  { cost: { honey: 2 }, gives: { pie: 2, egg: 2 }, ask: 'two jars of honey for her tea', thanks: 'Clover honey! My tea thanks you. Two pies and a couple of eggs.' },
  { cost: { wheat: 4 }, gives: { bread: 2, honeycake: 1 }, ask: 'four sheaves of wheat for the flour bin', thanks: 'I will grind it Saturday. Two loaves and a honey cake now, and more to come.' },
  { cost: { fish: 2 }, gives: { fishfry: 2, pie: 1 }, ask: 'two fish for a Friday supper', thanks: 'Trout! I will fry these up with cornmeal. Here is yours already, and a pie besides.' },
];
export const wishFor = (day) => WISHES[((day * 2654435761) >>> 0) % WISHES.length];

export class Grandma {
  constructor(scene, windowAnchor, doorAnchor) {
    this.win = windowAnchor; this.door = new THREE.Vector3();
    doorAnchor.updateWorldMatrix(true, false); this.door.setFromMatrixPosition(doorAnchor.matrixWorld);
    this.pivot = new THREE.Group();
    // her shadow, drawn with a brush on a sheet and cut out: the rocker, Grandma knitting, a ball of yarn
    const c = document.createElement('canvas'); c.width = 256; c.height = 256; const g = c.getContext('2d');
    g.fillStyle = g.strokeStyle = '#2e1c14'; g.lineCap = 'round'; g.lineJoin = 'round';
    g.lineWidth = 9; g.beginPath(); g.moveTo(28, 236); g.quadraticCurveTo(110, 252, 190, 228); g.stroke(); // the rocker's runner
    g.lineWidth = 10; g.beginPath(); g.moveTo(52, 236); g.lineTo(44, 40); g.stroke(); // the high chair back
    g.beginPath(); g.arc(44, 34, 8, 0, Math.PI * 2); g.fill(); // its finial
    g.lineWidth = 8; g.beginPath(); g.moveTo(150, 236); g.lineTo(140, 168); g.stroke(); // front leg of the chair
    // Grandma: shawled shoulders, lap and long skirt, feet on the runner
    g.beginPath(); g.moveTo(60, 160); g.quadraticCurveTo(58, 100, 92, 88); g.quadraticCurveTo(128, 84, 132, 118); g.lineTo(150, 150);
    g.lineTo(176, 160); g.quadraticCurveTo(190, 176, 182, 228); g.lineTo(196, 232); g.lineTo(196, 240); g.lineTo(158, 240); g.lineTo(160, 184);
    g.lineTo(80, 180); g.closePath(); g.fill();
    g.beginPath(); g.arc(104, 66, 24, 0, Math.PI * 2); g.fill(); // her head
    g.beginPath(); g.arc(84, 50, 13, 0, Math.PI * 2); g.fill(); // hair in a bun
    g.beginPath(); g.moveTo(126, 62); g.lineTo(134, 70); g.lineTo(124, 74); g.fill(); // a little nose
    g.lineWidth = 3.5; // the knitting needles, crossed, with a scrap of knitting hanging from them
    g.beginPath(); g.moveTo(130, 128); g.lineTo(196, 104); g.moveTo(134, 112); g.lineTo(198, 128); g.stroke();
    g.beginPath(); g.moveTo(160, 116); g.lineTo(178, 116); g.lineTo(174, 140); g.lineTo(162, 138); g.closePath(); g.fill();
    g.beginPath(); g.arc(222, 222, 15, 0, Math.PI * 2); g.fill(); // the ball of yarn on the floor
    g.lineWidth = 2.5; g.beginPath(); g.moveTo(170, 136); g.quadraticCurveTo(214, 170, 214, 208); g.stroke(); // the strand
    const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
    const m = new THREE.Mesh(new THREE.PlaneGeometry(0.82, 0.82).translate(0.0, 0.41, 0), new THREE.MeshBasicNodeMaterial({ map: tex, transparent: true, alphaTest: 0.5, depthWrite: false }));
    this.pivot.add(m);
    windowAnchor.add(this.pivot);
    this.pivot.visible = false;
    this.t = 0; this.pieDay = -1;
  }

  home(sky) { return sky.time > 0.77 && sky.time < 0.94; } // 18:30 to 22:30
  atDoor(pos, r = 1.3) { return Math.hypot(pos.x - this.door.x, pos.z - this.door.z) < r; }

  update(dt, sky) {
    this.t += dt;
    this.pivot.visible = this.home(sky);
    if (!this.pivot.visible) return;
    // rocking on the chair's runners, and a nod now and then over the knitting
    this.pivot.rotation.z = Math.sin(this.t * 1.4) * 0.06;
    this.pivot.position.y = Math.abs(Math.sin(this.t * 1.4)) * 0.01;
  }
}
