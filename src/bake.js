// Merge a group's static child meshes that share a material into one mesh each (draw calls matter on
// Firefox's WebGPU). `keep` lists meshes that must stay separate (they animate or toggle visibility).
import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

export function bakeByMaterial(group, keep = new Set()) {
  const byMat = new Map();
  for (const m of [...group.children]) {
    if (!m.isMesh || keep.has(m)) continue;
    m.updateMatrix();
    const g = (m.geometry.index ? m.geometry.toNonIndexed() : m.geometry.clone()).applyMatrix4(m.matrix);
    for (const name of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(name)) g.deleteAttribute(name);
    if (!g.attributes.uv) g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
    g.clearGroups();
    if (!byMat.has(m.material)) byMat.set(m.material, { geos: [], cast: false });
    const e = byMat.get(m.material);
    e.geos.push(g); e.cast ||= m.castShadow;
    group.remove(m);
  }
  for (const [mat, e] of byMat) {
    const merged = new THREE.Mesh(mergeGeometries(e.geos, false), mat);
    merged.castShadow = e.cast; merged.receiveShadow = true;
    group.add(merged);
  }
}
