// A lightning-bug jar: an old honey jar, scraped clean, with a twine handle and holes punched in the lid.
// After dark, stand by a firefly and press E to catch it; each one you catch makes the jar in the farmer's
// left hand glow a little brighter and throw a little more warm light about, up to six. At first light he
// unscrews the lid and lets them all go home.
import * as THREE from 'three/webgpu';
import { uniform, vec3 } from 'three/tsl';
import { paperMaterial } from './materials.js';

export const JAR_MAX = 6;

export class Jar {
  constructor(avatar) {
    this.count = 0;
    this.glowU = uniform(0);
    const g = (this.group = new THREE.Group());
    g.position.set(0, -0.64, 0.04); // hanging by its twine from the left hand
    const glass = paperMaterial({ color: 0xcfe0d4, transparent: true, opacity: 0.55 });
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.09, 0.22, 10), glass);
    body.position.y = -0.12; g.add(body);
    const lid = new THREE.Mesh(new THREE.CylinderGeometry(0.085, 0.085, 0.04, 10), paperMaterial({ color: 0xb08a4a }));
    lid.position.y = 0.01; g.add(lid);
    const twine = new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.008, 4, 10, Math.PI), paperMaterial({ color: 0xd9c49a }));
    twine.position.y = 0.02; g.add(twine);
    // the bugs inside: a soft warm core whose brightness follows how many you've caught
    const coreMat = new THREE.MeshBasicNodeMaterial();
    coreMat.colorNode = vec3(1.5, 1.05, 0.28).mul(this.glowU);
    const core = new THREE.Mesh(new THREE.SphereGeometry(0.065, 8, 6), coreMat);
    core.position.y = -0.12; g.add(core);
    // the light it throws (always present, so adding it never recompiles the scene's shaders)
    this.light = new THREE.PointLight(0xffd27a, 0, 7, 1.4);
    this.light.position.y = -0.12; g.add(this.light);
    for (const m of [body, lid, twine]) m.castShadow = false;
    avatar.arms[0].add(g);
    g.visible = false;
    this.t = 0;
  }

  /** Show the jar once you own it; glow with the catch, flickering softly as the bugs blink. */
  update(dt, owned, night) {
    this.t += dt;
    this.group.visible = owned;
    const k = this.count / JAR_MAX;
    const flicker = 0.85 + 0.15 * Math.sin(this.t * 7.3) * Math.sin(this.t * 3.1 + 1.2);
    this.glowU.value = this.count ? (0.25 + k * 0.75) * flicker : 0;
    this.light.intensity = owned ? k * 2.6 * flicker * Math.max(0.3, night) : 0;
  }
}
