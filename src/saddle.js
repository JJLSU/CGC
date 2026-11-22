// Biscuit's tack, for the model horse (Meshy's mare comes bare-backed): a red Navajo-stripe saddle blanket with a
// cream border and a fringe, a tooled brown stock saddle with a high cantle, a pommel and a horn, and stirrup
// fenders with wooden stirrups. Every piece is a printed card bent to her back. It rides on her spine bones each
// frame, so it rocks with her walk; a handful of meshes, two small canvases.
import * as THREE from 'three/webgpu';
import { cardMaterial } from './materials.js';

function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; return t;
}

// the blanket: barn red, a band of cream and slate stepped diamonds down the middle, cream borders and a fringe
const blanketArt = () => canvasTex(256, 256, (g, w, h) => {
  g.fillStyle = '#9e3328'; g.fillRect(0, 0, w, h);
  g.fillStyle = '#efe2c4'; g.fillRect(0, 0, w, 22); g.fillRect(0, h - 22, w, 22);
  g.fillStyle = '#4f6680'; g.fillRect(0, 22, w, 8); g.fillRect(0, h - 30, w, 8);
  g.fillStyle = '#7a2620'; for (let x = 0; x < w; x += 16) { g.fillRect(x, 40, 8, 6); g.fillRect(x + 8, h - 46, 8, 6); }
  for (let i = 0; i < 4; i++) { // stepped diamonds along the band across her back
    const cx = w / 2, cy = 52 + i * 50;
    g.fillStyle = '#efe2c4'; g.beginPath(); g.moveTo(cx, cy - 20); g.lineTo(cx + 26, cy); g.lineTo(cx, cy + 20); g.lineTo(cx - 26, cy); g.fill();
    g.fillStyle = '#4f6680'; g.beginPath(); g.moveTo(cx, cy - 10); g.lineTo(cx + 13, cy); g.lineTo(cx, cy + 10); g.lineTo(cx - 13, cy); g.fill();
  }
  g.strokeStyle = '#d9c9a2'; g.lineWidth = 3; // the fringe
  for (let x = 2; x < w; x += 7) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x + 1, 12); g.moveTo(x, h); g.lineTo(x + 1, h - 12); g.stroke(); }
  g.strokeStyle = 'rgba(60,24,16,0.5)'; g.lineWidth = 4; g.strokeRect(2, 2, w - 4, h - 4);
});

// the leather: saddle brown, tooled with a scroll border and a darker cut edge
const leatherArt = () => canvasTex(256, 128, (g, w, h) => {
  g.fillStyle = '#8a5530'; g.fillRect(0, 0, w, h);
  g.fillStyle = '#9c6639'; g.fillRect(10, 10, w - 20, h - 20);
  g.strokeStyle = '#5e3518'; g.lineWidth = 3;
  for (let x = 20; x < w - 20; x += 22) { g.beginPath(); g.arc(x, 18, 6, 0, Math.PI * 1.5); g.stroke(); g.beginPath(); g.arc(x + 11, h - 18, 6, Math.PI, Math.PI * 2.5); g.stroke(); }
  g.strokeStyle = '#4a2a14'; g.lineWidth = 6; g.strokeRect(3, 3, w - 6, h - 6);
  g.setLineDash([5, 5]); g.strokeStyle = '#e6c890'; g.lineWidth = 1.5; g.strokeRect(9, 9, w - 18, h - 18);
});

let MATS = null;
const mats = () => MATS ||= {
  blanket: cardMaterial(blanketArt(), { side: THREE.DoubleSide }),
  leather: cardMaterial(leatherArt(), { side: THREE.DoubleSide }),
  wood: cardMaterial(canvasTex(32, 32, (g) => { g.fillStyle = '#b07a44'; g.fillRect(0, 0, 32, 32); g.fillStyle = '#7e5028'; g.fillRect(0, 12, 32, 4); }), { side: THREE.DoubleSide }),
};

// a curved card draped over a back: an open half-tube of radius r and length len (along x), spanning `arc` radians
function drape(r, len, arc, mat) {
  const geo = new THREE.CylinderGeometry(r, r, len, 20, 1, true, -arc / 2, arc);
  geo.rotateZ(Math.PI / 2); geo.rotateX(-Math.PI / 2); // the tube along x, its arc over the top
  return new THREE.Mesh(geo, mat);
}

/** Builds the tack (in metres, +x her forward) and returns its group. */
export function makeSaddle() {
  const M = mats(), g = new THREE.Group();
  const blanket = drape(0.46, 0.98, 2.2, M.blanket); blanket.position.y = 0.34 - 0.46; g.add(blanket); // (a wide curve, so it lies on her barrel, not in it)
  const seat = drape(0.48, 0.46, 1.1, M.leather); seat.position.y = 0.36 - 0.48; g.add(seat);
  // skirts: the saddle's square leather flaps down each side over the blanket
  for (const s of [1, -1]) {
    const skirt = drape(0.47, 0.56, 0.62, M.leather); skirt.position.y = 0.355 - 0.47; skirt.rotation.x = s * 0.62; g.add(skirt);
  }
  // the cantle behind the seat and the pommel in front: upright leather half-discs
  const cantle = new THREE.Mesh(new THREE.CircleGeometry(0.17, 12, 0, Math.PI), M.leather);
  cantle.rotation.y = Math.PI / 2; cantle.position.set(-0.24, 0.3, 0); cantle.rotation.z = -0.25; g.add(cantle);
  const pommel = new THREE.Mesh(new THREE.CircleGeometry(0.12, 12, 0, Math.PI), M.leather);
  pommel.rotation.y = Math.PI / 2; pommel.position.set(0.23, 0.31, 0); g.add(pommel);
  const horn = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.03, 0.12, 8), M.leather); horn.position.set(0.25, 0.47, 0); g.add(horn);
  const cap = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.02, 10), M.leather); cap.position.set(0.25, 0.53, 0); g.add(cap);
  // fenders and stirrups, hanging down her flanks
  g.stirrups = [];
  for (const s of [1, -1]) {
    const hang = new THREE.Group(); hang.position.set(0.02, 0.2, s * 0.36); g.add(hang);
    const fender = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.5), M.leather); fender.position.y = -0.25; hang.add(fender);
    const stirrup = new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.018, 6, 12, Math.PI * 1.3), M.wood);
    stirrup.rotation.z = Math.PI * 1.15; stirrup.position.y = -0.55; hang.add(stirrup);
    hang.side = s; g.stirrups.push(hang);
  }
  g.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  return g;
}

const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _f = new THREE.Vector3(), _u = new THREE.Vector3(), _s = new THREE.Vector3(), _m = new THREE.Matrix4();
/**
 * Sits the tack on the horse's back for this frame: centred between two spine bones, a little above them, pitched
 * along her spine. `lift` is how far her back's top stands above the bones (metres at her scale).
 */
export function placeSaddle(saddle, model, lift) {
  const bones = saddle.bones ||= ['spine2', 'spine_04'].map((n) => model.getObjectByName(n));
  if (!bones[0] || !bones[1]) { saddle.visible = false; return; }
  bones[0].getWorldPosition(_a); bones[1].getWorldPosition(_b);
  _f.subVectors(_b, _a).normalize(); // her forward along the spine
  _s.set(0, 1, 0).cross(_f).normalize(); _u.crossVectors(_f, _s);
  _m.makeBasis(_f, _u, _s.negate());
  saddle.quaternion.setFromRotationMatrix(_m);
  saddle.position.copy(_a).lerp(_b, 0.5).addScaledVector(_u, lift - 0.34 * saddle.scale.y);
  saddle.visible = true;
}
