// The great ranges, folded from paper. Their height lives on a coarse lattice (world.js, LAT) and runs flat between
// the nodes, so every slope is a big flat facet with a sharp crease, the way a folded paper mountain is. This one mesh
// of every range in the world, built once on that lattice, is the mountain near and far (the detailed terrain under
// it follows the same facets, for walking on): handmade paper dyed cold blue at the foot, paling up to white snow,
// each facet catching the light on its own, and taking a cold pale distance colour far off.
import * as THREE from 'three/webgpu';
import { rangeAt, farHeight, LAT } from './world.js';
import { mix, smoothstep, distance, positionWorld, cameraPosition, vec2, vec3, float, color, mx_noise_float } from 'three/tsl';

const C = (h) => color(h);

/** Builds the far ranges for this world and adds them to the scene. Call once the world's seed and centre are set. */
export function buildRanges(scene, sky) {
  const G = LAT, R = LAT * 166, // (R a whole number of lattice cells, so every vertex sits exactly on a lattice node)
  N = Math.round((2 * R) / G) + 1;
  const H = new Float32Array(N * N), M = new Float32Array(N * N);
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
    const x = -R + i * G, z = -R + j * G, m = rangeAt(x, z);
    M[j * N + i] = m;
    H[j * N + i] = m > 0.003 ? farHeight(x, z) + 0.12 : 0; // (on the same lattice as the near terrain's mountains, a hair above it: this mesh is the mountain, near and far)
  }
  const pos = [], idx = [], vid = new Int32Array(N * N).fill(-1);
  const v = (i, j) => { const k = j * N + i; if (vid[k] < 0) { vid[k] = pos.length / 3; pos.push(-R + i * G, H[k], -R + j * G); } return vid[k]; };
  for (let j = 0; j < N - 1; j++) for (let i = 0; i < N - 1; i++) {
    const k = j * N + i;
    if (Math.max(M[k], M[k + 1], M[k + N], M[k + N + 1]) < 0.004) continue; // (only the mountains, from their very feet: the same edge where the folded ground begins)
    const a = v(i, j), b = v(i + 1, j), c = v(i, j + 1), d = v(i + 1, j + 1);
    idx.push(a, c, b, b, c, d);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  geo.setIndex(idx); geo.computeVertexNormals(); geo.computeBoundingSphere();

  const mat = new THREE.MeshLambertNodeMaterial({ fog: false, flatShading: true }); // (every facet its own flat plane of light: folded paper)
  const p = positionWorld.xz, y = positionWorld.y;
  const nz = (q) => mx_noise_float(vec3(q.x, q.y, 0.0)).mul(0.5).add(0.5);
  // the same as the near slopes: handmade paper dyed cold blue, deep at the foot, paling upward, white snow on top
  const yW = y.add(nz(p.mul(0.045)).sub(0.5).mul(5)).add(nz(p.mul(0.16)).sub(0.5).mul(2.2));
  let col = mix(C(0x56689a), C(0x9caccc), smoothstep(4, 21, yW));
  col = mix(col, C(0xf4f6fa), smoothstep(22.5, 24, yW));
  col = col.mul(float(0.94).add(nz(p.mul(1.7)).mul(0.1)));
  // aerial perspective toward the sky's horizon colour, and a valley mist around their feet
  if (sky?.uHorizon) {
    const far = smoothstep(80, 520, distance(p, cameraPosition.xz)).mul(0.45);
    const mist = smoothstep(13, 3, y).mul(smoothstep(110, 170, distance(p, cameraPosition.xz))).mul(0.95); // (far off, their feet stand in the same haze as the valley floor)
    col = mix(col, mix(sky.uHorizon, C(0xb4c2dc), 0.65), far.max(mist)); // (a cold blue distance, so far ranges stay blue, not the warm haze)
  }
  mat.colorNode = col;
  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = false; mesh.castShadow = false; mesh.frustumCulled = false;
  scene.add(mesh);
  return mesh;
}
