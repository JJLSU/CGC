// Watercolour sky dome, die-cut paper clouds, sun/moon lights, day/night, and a "volumetric"
// fog node: distance + low-lying valley mist, brightened where you look toward the sun.
import * as THREE from 'three/webgpu';
import {
  uniform, normalize, positionLocal, positionWorld, cameraPosition, smoothstep, mix, dot, vec3, vec2, texture, float, max, pow,
  fog, rangeFogFactor, distance,
} from 'three/tsl';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { sharedTextures, cardMaterial, uKeyDir } from './materials.js';
import { cardGeometry } from './props.js';
import { paintCard } from './textures.js';
import { smoothstep as ss, mulberry32 } from './noise.js';

export const DAY_LENGTH = 720; // seconds per full day

const C = (h) => new THREE.Color(h);
const PAL = {
  zenithDay: C(0x8db4cc), horizonDay: C(0xf2dcb8),
  zenithNight: C(0x1a2340), horizonNight: C(0x3a3a5a),
  sunset: C(0xf09a5c), sunsetHigh: C(0xd98a8a),
  sunHigh: C(0xffe2b8), sunLow: C(0xff9a58), moon: C(0x8ea2e0),
  hemiDay: C(0xf3dcb8), hemiNight: C(0x3a56b0),
  duskSky: C(0xa898d0), duskGround: C(0x5a4a78),
  hazeDay: C(0xd8bf8e), hazeDusk: C(0xc98fa0), hazeNight: C(0x0e1a44),
  fillDay: C(0xf2dcc2), fillGolden: C(0xb9bcd8), fillDusk: C(0x6f63a8), fillNight: C(0x7890d0),
  groundDay: C(0x8a6d4a), groundNight: C(0x22243a),
};

export class Sky {
  constructor(scene) {
    this.scene = scene;
    this.time = 0.31;
    this.day = 1;
    this.night = 0; // 0 day … 1 night, for lamps & windows
    this.dusk = 0;

    this.uZenith = uniform(new THREE.Color());
    this.uHorizon = uniform(new THREE.Color());
    this.uSunDir = uniform(new THREE.Vector3(0, 1, 0));
    this.uSunCol = uniform(new THREE.Color(0xfff1d6));
    this.uSunVis = uniform(1);
    this.uMoonVis = uniform(0);
    this.uFogNear = uniform(70);
    this.uFogFar = uniform(155);
    this.uMist = uniform(0.35);

    const { wash, fiber } = sharedTextures();

    // ---- dome
    const mat = new THREE.MeshBasicNodeMaterial({ side: THREE.BackSide, depthWrite: false, fog: false });
    const dir = normalize(positionLocal);
    const skyUV = dir.xz.div(dir.y.add(0.35)).mul(0.35);
    const blooms = texture(wash, skyUV).r;
    let col = mix(this.uHorizon, this.uZenith, smoothstep(-0.02, 0.6, dir.y).pow(0.8));
    col = col.mul(mix(0.9, 1.03, blooms));
    const sd = dot(dir, this.uSunDir);
    const sunDisc = smoothstep(0.9968, 0.9975, sd).mul(this.uSunVis);
    const sunHalo = pow(max(sd, 0), 24).mul(0.35).add(pow(max(sd, 0), 4).mul(0.12)).mul(this.uSunVis);
    col = mix(col, this.uSunCol.mul(1.6), sunDisc).add(this.uSunCol.mul(sunHalo));
    // the moon is a paper crescent card now (nightsky.js); the dome keeps only a faint glow around it
    const md = dot(dir, this.uSunDir.negate());
    col = col.add(vec3(0.16, 0.15, 0.12).mul(pow(max(md, 0), 60)).mul(this.uMoonVis));
    // stars: sparse specks from the fibre texture at night
    const star = smoothstep(0.83, 0.9, texture(fiber, dir.xz.div(dir.y.add(0.05)).mul(0.6)).r).mul(this.uMoonVis).mul(smoothstep(0.1, 0.4, dir.y));
    mat.colorNode = col.add(vec3(star.mul(0.8)));
    this.dome = new THREE.Mesh(new THREE.SphereGeometry(450, 32, 16), mat);
    this.dome.frustumCulled = false;
    this.dome.renderOrder = -1;
    scene.add(this.dome);

    // ---- haze, not fog: subtle and only far away, measured on the ground from the focus (the hero)
    // so the ring travels with the subject and never eats the foreground. Mid-tone colours only.
    this.uFocus = uniform(new THREE.Vector3());
    this.uHaze = uniform(new THREE.Color(0xd8bf8e));
    this.uHazeAmt = uniform(0.3);
    const fromFocus = distance(positionWorld.xz, this.uFocus.xz);
    // near: a subtle mid-tone haze; far: the page fades fully into the sky's horizon colour, so a free
    // camera looking out sees a soft paper skyline instead of the edge of the world
    const near = smoothstep(34.0, 95.0, fromFocus).mul(this.uHazeAmt);
    const far = smoothstep(95.0, 150.0, fromFocus);
    // (the great mountains stand clear of the near haze: their heights take their own aerial perspective, see ranges.js)
    const high = float(1).sub(smoothstep(5.5, 11.0, positionWorld.y).mul(0.9)); // (from the foot of the slopes up, not just the heights)
    scene.fogNode = fog(mix(this.uHaze, this.uHorizon, far), near.add(far).min(1).mul(high));

    // ---- lights
    this.hemi = new THREE.HemisphereLight(0xf3dcb8, 0x8a6d4a, 1.0);
    scene.add(this.hemi);
    this.sun = new THREE.DirectionalLight(0xffffff, 2.5);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    const sc = this.sun.shadow.camera;
    sc.left = -30; sc.right = 30; sc.top = 30; sc.bottom = -30; sc.near = 1; sc.far = 320;
    this.sun.shadow.bias = -0.0005;
    this.sun.shadow.normalBias = 0.05;
    this.sun.shadow.radius = 3;
    scene.add(this.sun, this.sun.target);
    this.fill = new THREE.DirectionalLight(0xf2dcc2, 0.6); // no shadows: a soft frontal fill
    scene.add(this.fill, this.fill.target);

    this.sunDir = new THREE.Vector3();
    this.keyDir = new THREE.Vector3();
    this.buildClouds();
  }

  buildClouds() {
    const rng = mulberry32(42);
    const shapes = [];
    for (let v = 0; v < 3; v++) {
      const pts = [];
      const bumps = 3 + v, w = 10 + v * 3;
      pts.push([w / 2, 0]);
      for (let b = 0; b < bumps; b++) {
        const cx = w / 2 - (w / bumps) * (b + 0.5), r = (w / bumps) * (0.55 + rng() * 0.25);
        const lift = (1 - Math.abs(b - (bumps - 1) / 2) / bumps) * 2.2;
        for (let k = 0; k <= 8; k++) {
          const a = (k / 8) * Math.PI;
          pts.push([cx + Math.cos(a) * r, lift + Math.sin(a) * r * 0.9]);
        }
      }
      pts.push([-w / 2, 0]);
      const art = paintCard(pts, {
        W: 512, H: 256, seed: 70 + v, base: '#fbf3e3',
        fills: ['rgba(255,250,240,A)', 'rgba(236,226,214,A)', 'rgba(250,230,210,A)'],
        edge: 'rgba(170,160,170,1)',
        details(g, px, r) {
          // bluish shadow wash along the bottom
          const [, y0] = px(0, 0), [, y1] = px(0, 2.5);
          const gr = g.createLinearGradient(0, y0, 0, y1);
          gr.addColorStop(0, 'rgba(150,160,190,0.35)'); gr.addColorStop(1, 'rgba(150,160,190,0)');
          g.fillStyle = gr; g.fillRect(0, y1, 512, y0 - y1);
        },
      });
      shapes.push({ geo: cardGeometry(pts, 0.25), mat: cardMaterial(art, { fog: false }) });
    }
    this.cloudMats = shapes.map((s) => s.mat);
    this.clouds = [];
    for (let i = 0; i < 20; i++) {
      const s = shapes[i % shapes.length];
      const m = new THREE.Mesh(s.geo, s.mat);
      m.position.set((rng() - 0.5) * 440, 50 + rng() * 30, (rng() - 0.5) * 440);
      m.scale.setScalar(0.9 + rng() * 0.9);
      this.scene.add(m);
      this.clouds.push(m);
    }
  }

  /** Advance the day and place sun/lights/clouds around the player. */
  update(dt, center, camera) {
    // deep night runs three times as fast (about 2 minutes instead of 6); dusk and dawn keep their own pace
    this.time += (dt * (this.night > 0.8 ? 3 : 1)) / DAY_LENGTH;
    if (this.time >= 1) { this.time -= 1; this.day += 1; }

    const a = (this.time - 0.25) * Math.PI * 2;
    const sunDir = this.sunDir.set(Math.cos(a), Math.sin(a) * 0.85, 0.45).normalize();
    const e = sunDir.y;
    const dayAmt = ss(-0.16, 0.2, e);
    const dusk = (1 - ss(0.0, 0.32, Math.abs(e))) * ss(-0.25, 0.0, e);
    this.night = 1 - dayAmt;
    this.dusk = dusk;

    const zen = this.uZenith.value.copy(PAL.zenithNight).lerp(PAL.zenithDay, dayAmt).lerp(PAL.sunsetHigh, dusk * 0.25);
    const hor = this.uHorizon.value.copy(PAL.horizonNight).lerp(PAL.horizonDay, dayAmt).lerp(PAL.sunset, dusk * 0.7);
    this.uSunDir.value.copy(sunDir);
    this.uSunCol.value.copy(PAL.sunLow).lerp(PAL.sunHigh, ss(0.0, 0.45, e));
    this.uSunVis.value = ss(-0.08, 0.02, e);
    this.uMoonVis.value = ss(0.0, -0.12, e);
    this.uMist.value = 0.1 + 0.25 * (1 - ss(0.0, 0.5, e)); // mistier at dawn/dusk/night

    this.dome.position.copy(camera.position);

    const isDay = e > -0.02;
    // Key light is placed relative to the camera (papercraft lens rule): 55° off the camera axis toward
    // screen-left, a little toward the camera; ~50° up by day, lower toward golden hour, ~45° for the moon.
    const fwd = _tmp.subVectors(center, camera.position).setY(0).normalize();
    const leftX = fwd.z, leftZ = -fwd.x; // screen-left on the ground
    const az = THREE.MathUtils.degToRad(55);
    const hx = -fwd.x * Math.cos(az) + leftX * Math.sin(az), hz = -fwd.z * Math.cos(az) + leftZ * Math.sin(az);
    const elev = THREE.MathUtils.degToRad(isDay ? 26 + 24 * ss(0.05, 0.45, e) : 45);
    const lightDir = this.keyDir.set(hx * Math.cos(elev), Math.sin(elev), hz * Math.cos(elev)).normalize();
    this.sun.color.copy(isDay ? this.uSunCol.value : PAL.moon);
    // Key light. Like a paper diorama under a lamp, it never fades far: the moon is about half the
    // day sun, so cards stay readable and coloured at night.
    // a strong, directional sun against a softer sky, so every card throws a shadow you can read
    this.sun.intensity = isDay ? 3.8 * ss(-0.02, 0.22, e) : 1.6 * ss(0.02, 0.2, -e);
    this.sun.position.copy(center).addScaledVector(lightDir, 150);
    uKeyDir.value.copy(lightDir); // torn ground sheets cast their little shadows away from this
    this.sun.target.position.copy(center);

    // Ambient rises (not falls) toward dusk and night: violet at dusk, saturated blue at night.
    const nightAmt = 1 - dayAmt;
    this.hemi.intensity = 0.88 + 0.55 * nightAmt + 0.3 * dusk; // (by day the sky fills less, so the shade reads deeper)
    this.hemi.color.copy(PAL.hemiNight).lerp(PAL.hemiDay, dayAmt).lerp(PAL.duskSky, dusk * 0.6);
    this.hemi.groundColor.copy(PAL.groundNight).lerp(PAL.groundDay, dayAmt).lerp(PAL.duskGround, dusk * 0.5);

    // Frontal fill from behind the camera: warm by day, cool at golden hour, violet at dusk, blue at night.
    const golden = ss(0.32, 0.08, e) * ss(-0.02, 0.06, e);
    this.fill.color.copy(PAL.fillDay).lerp(PAL.fillGolden, golden).lerp(PAL.fillDusk, dusk).lerp(PAL.fillNight, ss(0.3, 0.8, nightAmt));
    this.fill.intensity = 0.38 + 0.35 * golden + 0.8 * dusk + 0.45 * ss(0.3, 0.8, nightAmt);
    _tmp.subVectors(camera.position, center).setY(0).normalize();
    this.fill.position.copy(center).addScaledVector(_tmp, 60).setY(center.y + 40);
    this.fill.target.position.copy(center);

    // paper clouds drift and wrap around the player, always turned to face the camera
    for (const c of this.clouds) {
      c.position.x += dt * 1.2;
      const ddx = c.position.x - center.x, ddz = c.position.z - center.z;
      if (ddx > 220) c.position.x -= 440; else if (ddx < -220) c.position.x += 440;
      if (ddz > 220) c.position.z -= 440; else if (ddz < -220) c.position.z += 440;
      c.rotation.y = Math.atan2(camera.position.x - c.position.x, camera.position.z - c.position.z);
    }

    // haze follows the hero; mid-tone colours per mood
    this.uFocus.value.copy(center);
    this.uHaze.value.copy(PAL.hazeDay).lerp(PAL.hazeDusk, dusk).lerp(PAL.hazeNight, ss(0.3, 0.85, nightAmt));
    this.uHazeAmt.value = 0.3 + 0.35 * dusk + 0.5 * ss(0.3, 0.85, nightAmt);

    // a passing shower: the key light softens and greys, the haze thickens to a pale rainy blue-grey
    const r = this.rain || 0;
    if (r > 0.001) {
      this.sun.intensity *= 1 - 0.55 * r;
      this.hemi.intensity *= 1 - 0.1 * r;
      this.sun.color.lerp(_rainKey, 0.5 * r);
      this.uHaze.value.lerp(_rainHaze, 0.55 * r);
      this.uHazeAmt.value += 0.35 * r;
      this.uMist.value += 0.2 * r;
    }
  }

  clockText() {
    const mins = Math.floor(this.time * 24 * 60);
    const hh = String(Math.floor(mins / 60)).padStart(2, '0');
    const mm = String(Math.floor((mins % 60) / 10) * 10).padStart(2, '0');
    return `Day ${this.day} · ${hh}:${mm}`;
  }
}

const _rainKey = new THREE.Color(0xc9d2d8), _rainHaze = new THREE.Color(0xa9b2b4);
const _tmp = new THREE.Vector3();
const _col = new THREE.Color();
