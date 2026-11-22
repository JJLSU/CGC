// Post-processing (TSL RenderPipeline), following the papercraft lens:
//   scene → warm contact occlusion (GTAO) → thin silhouette depth line → tilt-shift macro lens
//   (one sharp band ~40 % of the frame on the hero, blur by depth + screen height) → bloom for lit panes
//   → tone map → mild vintage grade → light vignette and ~1 % grain.
// No screen-space paper overlay (fibre lives on the surfaces), no colour fog (sunbeams are tissue-paper cards: shafts.js).
import * as THREE from 'three/webgpu';
import {
  pass, uniform, float, vec2, vec3, vec4, mix, smoothstep, screenUV, screenSize, renderOutput, luminance,
  time, clamp, abs, min, length, Fn, perspectiveDepthToViewZ, cameraNear, cameraFar, fract, sin, dot, select,
  mrt, output, normalView, packNormalToRGB, unpackRGBToNormal, sample,
} from 'three/tsl';
import { ao } from 'three/addons/tsl/display/GTAONode.js';
import { bloom } from 'three/addons/tsl/display/BloomNode.js';
import { gaussianBlur } from 'three/addons/tsl/display/GaussianBlurNode.js';

/**
 * opts (quality levels): ao — warm contact occlusion; line — silhouette line; dof — tilt-shift blur;
 * dofLevels — 2 (half + quarter res blurs) or 1 (quarter only); bloom — glow on lit panes.
 */
export function createPost(renderer, scene, camera, opts = {}) {
  const { ao: useAO = true, line: useLine = true, dof: useDof = true, dofLevels = 2, bloom: useBloom = true, bounce: bounceScale = 0.25 } = opts;
  const pipeline = new THREE.RenderPipeline(renderer);
  pipeline.outputColorTransform = false;

  const u = {
    focusZ: uniform(30),      // view depth of the hero (the focus point)
    focusY: uniform(0.5),     // screen height of the focus line (the camera looks at the hero)
    kD: uniform(1.2),         // relative depth → frame heights: 1 / (fovY · cot(pitch))
    band: uniform(0.3),       // tilt-shift band parameter (measured sharp band ≈ 36–45 % of the frame)
    ramp: uniform(0.3),
    depthWeight: uniform(0.8),
    nearGain: uniform(1.55),
    bloomStrength: uniform(0.22),
    night: uniform(0),
    aoStrength: uniform(1.0),
    saturation: uniform(0.98),
    shadowWarmth: uniform(0.7),
    contrast: uniform(0.32),
    dofEnabled: uniform(1),
    bounce: uniform(0.5),     // one-bounce light strength (the ray-traced look)
  };

  const scenePass = pass(scene, camera);
  if (useAO) {
    scenePass.setMRT(mrt({ output, normal: packNormalToRGB(normalView) }));
    scenePass.getTexture('normal').type = THREE.UnsignedByteType;
  }
  const sceneColor = scenePass.getTextureNode('output');
  const sceneDepth = scenePass.getTextureNode('depth');
  const viewZ = scenePass.getViewZNode();


  // ---- tilt-shift amount (0 sharp … 1 full blur), per the skill: mix screen height and relative depth
  const z = viewZ.negate();
  const sY = screenUV.y.sub(u.focusY);
  const sD = z.sub(u.focusZ).div(u.focusZ).mul(u.kD);
  const cc = mix(sY, sD, u.depthWeight);
  const a0 = clamp(abs(cc).sub(u.band.mul(0.5)).div(u.ramp), 0, 1);
  const a1 = a0.mul(a0).mul(float(3).sub(a0.mul(2))).mul(0.35).add(a0.mul(0.65));
  const blurAmt = min(a1.mul(select(sD.lessThan(0), u.nearGain, float(1))), 1).mul(u.dofEnabled);

  // ---- warm contact occlusion (grey AO reads as dirt), faded out inside the blur
  let base = sceneColor.rgb;
  if (useAO) {
    const sceneNormal = sample((suv) => unpackRGBToNormal(scenePass.getTextureNode('normal').sample(suv)));
    const aoPass = ao(sceneDepth, sceneNormal, camera);
    aoPass.resolutionScale = 0.5;
    aoPass.radius.value = 0.7;
    aoPass.samples.value = 8;
    const aoV = aoPass.getTextureNode().sample(screenUV).r;
    const aoTint = mix(vec3(0.62, 0.42, 0.26), vec3(1), aoV);
    base = base.mul(mix(vec3(1), aoTint, u.aoStrength.mul(float(1).sub(blurAmt))));
  }

  // ---- one bounce of light, the look of ray-traced global illumination on a budget: the lit image, blurred wide
  // at low resolution, is the light arriving from the surroundings; each pixel takes it back tinted by its own
  // colour, mostly in the shade. So the ground beside the red barn glows faintly red, a tree's shaded side picks
  // up the warm meadow, and a lantern's pool of light spills colour onto the boards around it.
  if (bounceScale) {
    const around = gaussianBlur(vec4(base, 1), null, 7, { resolutionScale: bounceScale }).rgb;
    const L = luminance(base);
    const albedo = clamp(base.div(L.max(0.12)).mul(0.55), 0, 1.4); // the surface's own hue, at a mid value
    const shade = float(1).sub(smoothstep(0.18, 0.7, L));
    base = base.add(around.mul(albedo).mul(u.bounce).mul(shade.mul(0.75).add(0.25)));
  }

  // ---- thin silhouette line where a card stands in front of something farther away (~1 px, warm)
  const px = vec2(1).div(screenSize);
  const zAt = (o) => perspectiveDepthToViewZ(sceneDepth.sample(screenUV.add(o.mul(px))).r, cameraNear, cameraFar).negate();
  const zc = zAt(vec2(0, 0));
  const farther = zAt(vec2(1, 0)).max(zAt(vec2(-1, 0))).max(zAt(vec2(0, 1))).max(zAt(vec2(0, -1)));
  const line = smoothstep(0.04, 0.12, farther.sub(zc).div(zc)).mul(float(1).sub(blurAmt));
  const lined = useLine ? mix(base, base.mul(vec3(0.76, 0.67, 0.58)), line.mul(0.7)) : base;

  // ---- the lens: two blur levels, gathered progressively
  const lit = vec4(lined, 1);
  // blurred copies at half and quarter resolution: same blur radius on screen, a fraction of the cost
  let dofed = lined;
  if (useDof && dofLevels >= 2) {
    const blurA = gaussianBlur(lit, null, 1.6, { resolutionScale: 0.5 });
    const blurB = gaussianBlur(lit, null, 2.2, { resolutionScale: 0.25 });
    dofed = mix(mix(lined, blurA.rgb, smoothstep(0.0, 0.45, blurAmt)), blurB.rgb, smoothstep(0.45, 1.0, blurAmt));
  } else if (useDof) {
    const blurB = gaussianBlur(lit, null, 2.0, { resolutionScale: 0.25 });
    dofed = mix(lined, blurB.rgb, smoothstep(0.0, 1.0, blurAmt));
  }

  // ---- bloom only for lit panes / lamps
  const hdr = useBloom ? dofed.add(bloom(vec4(dofed, 1), 1, 0.5, 0.85).rgb.mul(u.bloomStrength)) : dofed;

  const display = renderOutput(vec4(hdr, 1));

  const graded = Fn(() => {
    let c = display.rgb.toVar();
    const l = luminance(c);
    c = mix(vec3(l), c, mix(u.saturation, u.saturation.mul(0.9), u.night));
    // warm the shadows (never grey), white balance (1.03, 0.985, 0.95)
    const shadowW = float(1).sub(smoothstep(0.0, 0.5, l));
    c = mix(c, c.mul(vec3(1.16, 0.9, 0.78)), shadowW.mul(u.shadowWarmth));
    c = c.mul(vec3(1.03, 0.985, 0.95));
    // warm shadow lift so the darkest tones never crush to black
    c = c.add(vec3(0.227, 0.125, 0.047).mul(0.03).mul(float(1).sub(smoothstep(0.0, 0.45, l))));
    c = mix(c, c.mul(c).mul(float(3).sub(c.mul(2))), u.contrast);
    // night: navy shadows, warm lights stay warm
    c = mix(c, c.mul(vec3(0.82, 0.9, 1.1)), u.night.mul(float(1).sub(smoothstep(0.3, 0.75, l))).mul(0.5));
    // light warm vignette (stronger at night), ~1 % grain
    const asp = screenSize.x.div(screenSize.y);
    const d = length(screenUV.sub(0.5).mul(vec2(asp, 1)));
    c = c.mul(float(1).sub(smoothstep(0.45, 1.1, d).mul(mix(0.12, 0.26, u.night))));
    const grain = fract(sin(dot(screenUV.mul(screenSize).add(fract(time.mul(13.7)).mul(97)), vec2(12.9898, 78.233))).mul(43758.5453));
    c = c.add(grain.sub(0.5).mul(0.012));
    return vec4(clamp(c, 0, 1), 1);
  })();

  pipeline.outputNode = graded;

  return {
    pipeline, u,
    render() { pipeline.render(); },
    dispose() { pipeline.dispose(); },
  };
}
