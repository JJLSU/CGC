// The farmer: a papercraft figure (figure.js) in buffalo-plaid flannel and denim overalls with brass buttons,
// stout boots, a red-brown beard, a woven straw hat with a red band and a pack with a bedroll. His tools (felling
// axe, pickaxe, hammer, ash spear, willow pole) ride in his right hand, one at a time. Forward is +Z.
import * as THREE from 'three/webgpu';
import { paperMaterial } from './materials.js';
import { Figure } from './figure.js';
import { ModelFigure, hasFolk } from './modelfolk.js';

const mats = {};
function aimBone(b, child, dir) {
  b.updateWorldMatrix(true, true);
  b.getWorldPosition(_aa); child.getWorldPosition(_ab); _ab.sub(_aa).normalize();
  _ad.setFromUnitVectors(_ab, dir.normalize());
  b.getWorldQuaternion(_aq); b.parent.getWorldQuaternion(_ap);
  b.quaternion.copy(_ap.invert().multiply(_ad).multiply(_aq));
  b.updateWorldMatrix(false, true);
}
const _aa = new THREE.Vector3(), _ab = new THREE.Vector3(), _ad = new THREE.Quaternion(), _aq = new THREE.Quaternion(), _ap = new THREE.Quaternion();
const _pq = new THREE.Quaternion(), _sq = new THREE.Quaternion(), _dq = new THREE.Quaternion(), _pn = new THREE.Vector3(), _p = new THREE.Vector3(), _x = new THREE.Vector3(), _y = new THREE.Vector3(), _yy = new THREE.Vector3(), _z = new THREE.Vector3(), _q = new THREE.Quaternion(), _rq = new THREE.Quaternion(), _m = new THREE.Matrix4(), _inv = new THREE.Matrix4();
const mat = (hex) => (mats[hex] ||= paperMaterial({ color: hex, flatShading: true }));
function piece(geo, hex) { const m = new THREE.Mesh(geo, mat(hex)); m.castShadow = true; m.receiveShadow = true; return m; }
const handle = (len, r = 0.03) => new THREE.CylinderGeometry(r, r * 1.15, len, 6).rotateX(Math.PI / 2).translate(0, 0, len / 2 - 0.12);

export class Avatar {
  constructor() {
    // you, from the reference art: the big man in the brick-red shirt and braces (Big Jim's sheet), or the weathered
    // homesteader till he's made; the folded-paper farmer before either
    const me = ['folk_jim', 'folk_player'].find(hasFolk);
    const fig = (this.fig = me ? new ModelFigure(me) : new Figure({
      coat: 0xb5473a, coatPat: 7, pants: 0x4a6385, pantsPat: 8, overalls: true, boots: 0x5a3a24,
      beard: 0xa86a3a, hair: 0x8a5432, eyes: '#3f5a74', hat: 'straw', band: 0xa63c2e, pack: true,
    }));
    this.root = fig.root; this.body = fig.body; this.head = fig.head; this.legs = fig.legs; this.arms = fig.arms;
    const hand = fig.hands[1];
    const tool = (...parts) => { const g = new THREE.Group(); for (const p of parts) g.add(p); g.visible = false; g.rotation.x = 0.6; hand.add(g); return g; }; // carried pointing forward and down
    // a felling axe, a pickaxe, a claw hammer, the ash spear and the willow fishing pole
    this.axe = tool(piece(handle(0.85), 0x8a6038), piece(new THREE.BoxGeometry(0.035, 0.26, 0.17).translate(0, 0.08, 0.66), 0xb9bec4), piece(new THREE.BoxGeometry(0.04, 0.05, 0.08).translate(0, -0.06, 0.66), 0x8e9294));
    this.pick = tool(piece(handle(0.85), 0x8a6038), piece(new THREE.CylinderGeometry(0.032, 0.032, 0.56, 5).rotateZ(Math.PI / 2).rotateY(Math.PI / 2).translate(0, 0.05, 0.66), 0x9a9da2));
    this.hammer = tool(piece(handle(0.62), 0x8a6038), piece(new THREE.BoxGeometry(0.1, 0.2, 0.1).translate(0, 0.02, 0.46), 0x6e5a48));
    this.spear = tool(piece(handle(1.5, 0.028), 0x9a7448), piece(new THREE.BoxGeometry(0.06, 0.05, 0.12).translate(0, 0, 1.1), 0x5a3a20), piece(new THREE.ConeGeometry(0.07, 0.28, 4).rotateX(Math.PI / 2).translate(0, 0, 1.3), 0x8e8a80));
    this.rod = tool(piece(new THREE.CylinderGeometry(0.014, 0.03, 1.9, 5).rotateX(Math.PI / 2 - 0.5).translate(0, 0.42, 0.75), 0xa88a50), piece(new THREE.BoxGeometry(0.07, 0.07, 0.07).translate(0, 0.02, 0.08), 0xb5473a));
    // the hunting bow: a hickory stave curved like a drawn brow, through the fist, with a cream string tip to tip
    const R = 0.9, half = 0.62;
    const stave = new THREE.TorusGeometry(R, 0.022, 5, 14, half * 2).rotateZ(Math.PI / 2 - half).translate(0, -R, 0).rotateY(Math.PI / 2).rotateX(-Math.PI / 2); // (upright, belly forward)
    const string = new THREE.CylinderGeometry(0.005, 0.005, 2 * R * Math.sin(half), 3).rotateX(Math.PI / 2).translate(0, R * Math.cos(half) - R, 0).rotateX(-Math.PI / 2);
    this.bow = tool(piece(stave, 0x9a6a3c), piece(string, 0xefe2c4), piece(new THREE.BoxGeometry(0.05, 0.06, 0.1), 0x5a3a20));
    // the six-shooter: a walnut grip in the fist, the cylinder above it and the barrel out ahead; the buffalo rifle:
    // a long walnut stock and forend with the octagon barrel running out past them
    // (the guns don't hang off the hand bone, whose frame is posed for an axe on the shoulder: they ride in the body's
    // own frame at the hand, barrel along the way he faces, so they point where he points; see aimGuns)
    this.handBone = hand;
    this.revolver = tool(piece(new THREE.BoxGeometry(0.045, 0.13, 0.06).rotateX(0.3).translate(0, -0.06, -0.01), 0x6a4428), piece(new THREE.CylinderGeometry(0.042, 0.042, 0.08, 8).rotateX(Math.PI / 2).translate(0, 0.025, 0.04), 0x5a5a60), piece(new THREE.CylinderGeometry(0.017, 0.017, 0.24, 6).rotateX(Math.PI / 2).translate(0, 0.035, 0.19), 0x3e3e44));
    this.rifle = tool(piece(new THREE.BoxGeometry(0.06, 0.11, 0.42).translate(0, -0.03, -0.24), 0x7a4a26), piece(new THREE.BoxGeometry(0.05, 0.05, 0.42).translate(0, 0.0, 0.18), 0x8a5a30), piece(new THREE.CylinderGeometry(0.02, 0.022, 1.0, 8).rotateX(Math.PI / 2).translate(0, 0.035, 0.45), 0x3e3e44));
    for (const gun of [this.revolver, this.rifle]) { gun.rotation.set(0, 0, 0); gun.scale.setScalar(1); this.root.add(gun); }
    // once he has a bow, a quiver rides across his back: a stitched leather tube, top over his right shoulder, with
    // the paper fletchings of three arrows peeping out (barn red and cream, like the arrows he looses)
    this.quiver = new THREE.Group(); this.quiver.visible = false;
    {
      const tube = piece(new THREE.CylinderGeometry(0.08, 0.068, 0.62, 10, 1, true), 0x7a4a26); tube.material = mats.quiv ||= paperMaterial({ color: 0x7a4a26, flatShading: true, side: THREE.DoubleSide });
      this.quiver.add(tube);
      for (const y of [-0.31, 0.2, 0.29]) this.quiver.add(piece(new THREE.CylinderGeometry(0.085, 0.085, 0.035, 10).translate(0, y, 0), y < 0 ? 0x5a3418 : 0xc89a5a)); // the base cap and two tooled bands
      const fl = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0.05, 0.03, 0), new THREE.Vector3(0.045, 0.15, 0), new THREE.Vector3(0, 0.13, 0)]);
      fl.setIndex([0, 1, 2, 0, 2, 3]); fl.computeVertexNormals();
      [[0.025, 0.02, 0.38], [-0.03, 0.015, 0.42], [0.005, -0.03, 0.35]].forEach(([x, z, h], i) => {
        const arrow = new THREE.Group(); arrow.position.set(x, 0.31, z); arrow.rotation.set(z * 4, i * 1.9, -x * 4);
        arrow.add(piece(new THREE.CylinderGeometry(0.009, 0.009, h, 4).translate(0, h / 2 - 0.15, 0), 0xc8a46e));
        for (let k = 0; k < 2; k++) { const v = new THREE.Mesh(fl, mats['fl' + ((i + k) % 2)] ||= paperMaterial({ color: (i + k) % 2 ? 0xefe2c4 : 0xa8352a, flatShading: true, side: THREE.DoubleSide })); v.position.y = h - 0.3; v.rotation.y = k * Math.PI / 2; v.castShadow = true; arrow.add(v); }
        this.quiver.add(arrow);
      });
    }
    fig.root.add(this.quiver);
    if (!(fig instanceof ModelFigure)) { this.quiver.removeFromParent(); this.quiver.position.set(0.12, 0.05, -0.32); this.quiver.rotation.z = -0.5; fig.body.add(this.quiver); } // (the paper farmer: on his pack)
    this.tool = 'axe';
    // on the model the tools are held in the closed fist, placed each frame from the hand itself (see grip below)
    if (fig instanceof ModelFigure) {
      this.grip = new THREE.Group(); fig.root.add(this.grip);
      for (const t of [this.axe, this.pick, this.hammer, this.spear, this.rod, this.bow]) { t.parent.remove(t); t.rotation.set(0, 0, 0); this.grip.add(t); }
      // his curled fingers round the haft: Meshy's hands are open and the rig has no finger bones, so the hand is
      // drawn in short and a fold of paper fingers, in his skin tone, wraps the handle where he grips it
      const knuckles = new THREE.CylinderGeometry(0.042, 0.04, 0.095, 7, 1, true, -Math.PI * 0.15, Math.PI * 1.3).rotateX(Math.PI / 2);
      this.fist = new THREE.Mesh(knuckles, paperMaterial({ color: 0xd49a76, side: THREE.DoubleSide, flatShading: true })); this.fist.castShadow = true; this.grip.add(this.fist);
    }
    this.swing = -1; // <0 idle, else 0..1 progress
  }

  /**
   * Astride the horse: the sit clip is a chair sit, knees together and thighs level, so after it each thigh is swung
   * outward round his forward axis and dropped round his side axis, to straddle the horse's back.
   */
  astride() {
    const rm = this.fig.model;
    this.legBones ||= [['LeftUpLeg', 'LeftLeg', 'LeftFoot'], ['RightUpLeg', 'RightLeg', 'RightFoot']].map((c) => c.map((n) => rm.getObjectByName(n)));
    this.fig.root.updateWorldMatrix(true, true); this.fig.root.getWorldQuaternion(_rq);
    const fwd = _z.set(0, 0, 1).applyQuaternion(_rq), side = _x.set(1, 0, 0).applyQuaternion(_rq);
    this.legBones.forEach(([up, knee, foot], i) => {
      if (!up || !knee || !foot) return;
      const sgn = i === 0 ? 1 : -1; // (his left is +x on the model)
      // the thigh forward and out over the horse's barrel, the shin hanging down her flank, the heel a touch back
      aimBone(up, knee, _y.copy(fwd).multiplyScalar(0.55).addScaledVector(side, sgn * 0.62).add(_yy.set(0, -0.56, 0)));
      aimBone(knee, foot, _y.copy(fwd).multiplyScalar(-0.22).addScaledVector(side, sgn * 0.16).add(_yy.set(0, -0.96, 0)));
    });
  }


  /**
   * The grip, on the model: the hand bone runs wrist to fingertips along its +y; the middle of the closed fist is
   * 8.5 cm down it, and a handle held there runs square across the fingers, pointing as near his forward as it can.
   * Done from the posed hand every frame, so it holds through any idle, the walk and the swing.
   */
  holdTools() {
    const hb = this.fig.hands[1].parent, root = this.fig.root;
    root.updateWorldMatrix(true, true);
    hb.getWorldPosition(_p); hb.getWorldQuaternion(_q); root.getWorldQuaternion(_rq);
    _y.set(0, 1, 0).applyQuaternion(_q); // the fingers
    _z.set(0, 0, 1).applyQuaternion(_rq); _z.addScaledVector(_y, -_z.dot(_y)); // his forward, squared across the fingers
    if (_z.lengthSq() < 1e-4) _z.set(0, 1, 0).applyQuaternion(_rq); _z.normalize();
    _x.crossVectors(_y, _z).normalize(); _yy.crossVectors(_z, _x);
    hb.scale.y = this.fist.visible ? 0.55 : 1; // (the fingers drawn in to a fist while he holds something)
    _p.addScaledVector(_y, 0.06).addScaledVector(_pn.set(0, 0, -1).applyQuaternion(_q), 0.025); // in the palm
    _m.makeBasis(_x, _yy, _z).setPosition(_p);
    _m.premultiply(_inv.copy(root.matrixWorld).invert()).decompose(this.grip.position, this.grip.quaternion, this.grip.scale);
  }

  /**
   * The quiver on the model: it rides the upper spine (so it leans and sways with him), set back from the bone by
   * the depth of his back and slung on the slant, its mouth over his right shoulder.
   */
  wearQuiver() {
    const sb = this.spineBone ||= this.fig.model.getObjectByName('Spine02') || this.fig.model.getObjectByName('Spine01');
    if (!sb) return;
    const root = this.fig.root;
    sb.getWorldPosition(_p); sb.getWorldQuaternion(_q); root.getWorldQuaternion(_rq);
    _z.set(0, 0, 1).applyQuaternion(_rq); // his forward
    _p.addScaledVector(_z, -0.2).add(_pn.set(0, 0.06, 0)); // behind his shoulder blades
    _q.copy(_rq).multiply(_sq.setFromAxisAngle(_x.set(0, 0, 1), 0.55)).multiply(_dq.setFromAxisAngle(_x.set(1, 0, 0), -0.18)); // slung on the slant, the mouth leaning back off him
    _m.compose(_p, _q, _yy.set(1, 1, 1));
    _m.premultiply(_inv.copy(root.matrixWorld).invert()).decompose(this.quiver.position, this.quiver.quaternion, this.quiver.scale);
  }

  /** The gun in hand rides at the hand in the body's own frame: carried pointing ahead and down, raised level while aiming. */
  aimGuns() {
    const gun = this.revolver.visible ? this.revolver : this.rifle.visible ? this.rifle : null;
    if (!gun || !this.handBone) return;
    this.root.updateWorldMatrix(true, true); this.handBone.getWorldPosition(_gp);
    // (the hand bone sits at the wrist: carry on past it, along the forearm's line, into the palm)
    const wrist = this.handBone.parent, fore = wrist?.parent;
    if (fore?.isBone) { fore.getWorldPosition(_gf); _gf.subVectors(_gp, _gf).normalize(); _gp.addScaledVector(_gf, this.aiming ? 0.065 : 0.075); }
    this.root.worldToLocal(_gp);
    gun.position.copy(_gp); gun.rotation.set(this.aiming ? -0.05 : 0.55, 0, 0);
  }

  /** speed: horizontal speed (m/s); air: in the air; swim: swimming. Returns true on the frame a swing "connects". */
  update(dt, speed, air, swim) {
    const fig = this.fig;
    const prevStep = Math.floor(fig.phase / Math.PI);
    const model = fig instanceof ModelFigure; // (the model swings with its own hammer-swing clip, from the top each swing)
    if (model && this.swing >= 0 && !this.swinging) fig.actions.work?.reset();
    this.swinging = this.swing >= 0;
    this.casting = Math.max(0, (this.casting || 0) - dt);
    fig.update(dt, this.riding || this.seated ? 0 : speed, this.riding || this.seated ? 'sit' : model && this.casting > 0 ? 'cast' : model && this.swing >= 0 ? 'swing' : null, { air: air && !this.riding, swim }); // in the saddle: legs astride, arms easy
    if (this.riding && model) this.astride();
    if (this.grip) this.holdTools();
    this.aimGuns();
    this.quiver.visible = !!this.hasBow && !swim;
    if (this.grip && this.quiver.visible) this.wearQuiver();
    // a footfall each half stride (read & cleared by the game loop for sound)
    if (Math.floor(fig.phase / Math.PI) !== prevStep && speed > 0.8 && !air && !swim) this.stepped = true;

    let connected = false;
    if (this.swing >= 0) {
      // the swing: wind up over the shoulder with the elbow cocked, then drive down and through
      const prev = this.swing;
      this.swing += dt / 0.5;
      const t = this.swing, arm = this.arms[1];
      let a, el;
      if (t < 0.35) { const k = easeOut(t / 0.35); a = -2.9 * k; el = -0.9 * k; }
      else if (t < 0.55) { const k = easeIn((t - 0.35) / 0.2); a = -2.9 + 2.3 * k; el = -0.9 + 0.8 * k; }
      else { const k = easeOut((t - 0.55) / 0.45); a = -0.6 * (1 - k); el = -0.1 - 0.15 * k; }
      arm.rotation.x = a; arm.elbow.rotation.x = el;
      this.arms[0].rotation.x = a * 0.45; // the off hand follows the haft
      this.body.rotation.y = t < 0.35 ? -0.3 * (t / 0.35) : -0.3 + 0.5 * Math.min(1, (t - 0.35) / 0.2);
      this.body.rotation.x = 0.06 + (t > 0.35 && t < 0.7 ? 0.12 : 0);
      if (prev < 0.52 && t >= 0.52) connected = true;
      if (t >= 1) { this.swing = -1; this.body.rotation.y = 0; }
    }
    this.axe.visible = !swim && this.tool === 'axe';
    this.pick.visible = !swim && this.tool === 'pick';
    this.hammer.visible = !swim && this.tool === 'hammer';
    this.spear.visible = !swim && this.tool === 'spear';
    this.rod.visible = !swim && this.tool === 'rod';
    this.bow.visible = !swim && this.tool === 'bow';
    this.revolver.visible = !swim && this.tool === 'revolver'; this.rifle.visible = !swim && this.tool === 'rifle';
    if (this.seated) this.axe.visible = this.pick.visible = this.hammer.visible = this.spear.visible = this.rod.visible = this.bow.visible = this.revolver.visible = this.rifle.visible = false; // (his tool set down while he rocks)
    if (this.fist) this.fist.visible = this.axe.visible || this.pick.visible || this.hammer.visible || this.spear.visible || this.rod.visible || this.bow.visible || this.revolver.visible || this.rifle.visible;
    if (this.castSwing) { if (this.swing < 0) this.castSwing = false; connected = false; } // (a cast is no blow)
    return connected;
  }

  /** A cast of the fishing line: an arm-out flick on the model, the swing's wind-up on the paper farmer; never a blow. */
  startCast() {
    if (this.fig instanceof ModelFigure) { this.casting = 0.7; this.fig.actions.wave?.reset(); }
    else { this.startSwing(); this.castSwing = true; }
  }

  startSwing() {
    if (this.swing >= 0) return false;
    this.swing = 0;
    return true;
  }
}

const easeOut = (t) => 1 - (1 - t) * (1 - t);
const easeIn = (t) => t * t;
const _gp = new THREE.Vector3(), _gf = new THREE.Vector3();
