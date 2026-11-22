// Shafts of sunlight slanting down through the trees, cut from tissue paper: long soft strips laid along the
// sun's direction, each streaked with a few paler threads, glowing faintly where the light comes in. A dozen of
// them drift around the farmer in wooded country, fading in and out on their own slow clock; brightest in the
// low gold of morning and evening, gone by night and in the rain. One instanced mesh, one draw call; each strip
// turns about its own long axis to face the camera, and fades by narrowing (so no per-strip material).
import * as THREE from 'three/webgpu';
import { uniform, uv, abs, sin, float, smoothstep, vec4, positionView } from 'three/tsl';

const N = 12;
const _m = new THREE.Matrix4(), _c = new THREE.Vector3(), _w = new THREE.Vector3(), _n = new THREE.Vector3(), _to = new THREE.Vector3();
const WHITE = new THREE.Color(1, 1, 1);
const TREES = new Set(['pine', 'maple', 'goldtree', 'sagetree', 'birch', 'appletree', 'snag']);

export class Shafts {
  constructor(scene) {
    this.uCol = uniform(new THREE.Color(1, 0.86, 0.6));
    this.uStrength = uniform(0);
    const mat = new THREE.MeshBasicNodeMaterial({ transparent: true, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, fog: false });
    const u = uv();
    const across = float(1).sub(smoothstep(0.18, 0.5, abs(u.x.sub(0.5))));                // soft torn sides
    const along = smoothstep(0.0, 0.35, u.y).mul(float(1).sub(smoothstep(0.75, 1.0, u.y))); // fades at the ground and up high
    const threads = sin(u.x.mul(23.0).add(u.y.mul(2.0))).mul(0.25).add(sin(u.x.mul(57.0)).mul(0.12)).add(0.75); // paler fibres in the tissue
    const nearCam = smoothstep(5.0, 14.0, positionView.z.negate()); // a beam right by the lens fades out rather than washing the frame
    mat.colorNode = vec4(this.uCol.mul(across.mul(along).mul(threads).mul(nearCam).mul(this.uStrength)), 1);
    this.mesh = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1).translate(0, 0.5, 0), mat, N);
    this.mesh.frustumCulled = false; this.mesh.renderOrder = 5;
    scene.add(this.mesh);
    this.list = Array.from({ length: N }, (_, i) => ({ x: 0, z: 0, y: 0, w: 0, len: 12, age: 99, life: 1 + i, wide: 1 }));
    this.t = 0;
  }

  /** Put a strip somewhere near the farmer, beside a tree if there's one to be found. */
  place(s, world, p, getHeight) {
    for (let k = 0; k < 6; k++) {
      const a = Math.random() * Math.PI * 2, d = 6 + Math.random() * 22, x = p.x + Math.cos(a) * d, z = p.z + Math.sin(a) * d;
      const near = world.resourcesNear(x, z, 4).some((r) => TREES.has(r.type) && r.alive);
      if (near || k === 5) { s.x = x; s.z = z; s.y = getHeight(x, z); break; }
    }
    s.age = 0; s.life = 7 + Math.random() * 9; s.len = 10 + Math.random() * 8; s.wide = 0.8 + Math.random() * 1.8;
  }

  update(dt, { camera, pos, sky, rain, world, getHeight, wooded }) {
    this.t += dt;
    // strongest in the low gold light, softer at noon, nothing at night or under rain
    const e = sky.keyDir.y, day = 1 - sky.night;
    const strength = day * (1 - Math.min(1, rain * 1.6)) * (0.18 + 0.22 * (1 - Math.min(1, Math.max(0, (e - 0.45) / 0.35)))) * (0.45 + 0.55 * wooded);
    this.uStrength.value += (strength - this.uStrength.value) * Math.min(1, dt * 0.8);
    this.uCol.value.copy(sky.uSunCol.value).lerp(WHITE, 0.15);
    this.mesh.visible = this.uStrength.value > 0.004;
    if (!this.mesh.visible) return;
    const a = sky.keyDir; // up toward the sun
    for (let i = 0; i < N; i++) {
      const s = this.list[i];
      s.age += dt;
      if (s.age > s.life || Math.hypot(s.x - pos.x, s.z - pos.z) > 34) this.place(s, world, pos, getHeight);
      const k = Math.sin(Math.PI * Math.min(1, s.age / s.life)); // breathes in and out
      // axial billboard: the strip runs from the ground up toward the sun and turns to face the camera
      _c.set(s.x, s.y, s.z);
      _to.subVectors(camera.position, _c);
      _w.crossVectors(a, _to).normalize().multiplyScalar(s.wide * k + 1e-4);
      _n.crossVectors(_w, a).normalize();
      _m.makeBasis(_w, _c.copy(a).multiplyScalar(s.len), _n).setPosition(s.x, s.y, s.z);
      this.mesh.setMatrixAt(i, _m);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
  }
}
