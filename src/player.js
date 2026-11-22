// Third-person traveller: movement, stamina, swimming, collisions and the orbit camera.
import * as THREE from 'three/webgpu';
import { Avatar } from './avatar.js';
import { alongPath } from './climb.js';
import { getHeight, isWater, wadeable, wadeDepth, impassable, WALK_THROUGH, WATER_LEVEL, RESOURCE_TYPES } from './world.js';
import { clamp } from './noise.js';

const WALK = 6.0, SPRINT = 11.5, SWIM = 2.6, JUMP = 7.4, GRAVITY = 22;
const SWIM_DEPTH = 1.15; // feet this far below the surface => swimming
export const REACH = 2.1;

export class Player {
  constructor(scene, camera, spawn) {
    this.camera = camera;
    this.avatar = new Avatar();
    scene.add(this.avatar.root);

    this.pos = spawn.clone();
    this.vel = new THREE.Vector3();
    this.velY = 0;
    this.onGround = true;
    this.swimming = false;
    this.facing = 0;

    this.maxStamina = 200;
    this.health = 100;
    this.maxHealth = 100;
    this.hurtTimer = 0; // seconds since last hurt gate natural healing
    this.dead = false;
    this.stamina = 100;
    this.staminaBoost = 0; // seconds of "well fed"
    this.fullness = 70;    // 0..100: food in your belly, emptying through the day (eat with F)
    this.staminaRest = 0;

    // the opening view: close in and low over the farmer's shoulder, looking across the yard to the woods
    // (the wheel still zooms from 2.5 out to 42 for the high diorama view)
    this.yaw = 0.35;
    this.pitch = 0.46;
    this.pitchOffset = 0; // the mouse nudges the zoom-derived pitch up or down a little
    this.dist = 15;
    this.camTarget = new THREE.Vector3();
    this.anchor = spawn.clone().setY(spawn.y + 0.9);
    this.focusOffset = new THREE.Vector3();
    this.occlusionLift = 0;
    this.build = null; // BuildSystem, for floors/stairs/walls
    this.events = []; // 'jump' | 'land' | 'splash', drained by the game loop for sound
  }

  /** Terrain height, or a built floor/stair surface the player can step onto. */
  groundAt(x, z) {
    let t = getHeight(x, z);
    if (this.iceOn && t < WATER_LEVEL + 0.04) t = WATER_LEVEL + 0.04; // the ice sheet lies at the water line
    if (this.climbs) t = Math.max(t, this.climbs.surfaceAt(x, z, this.pos.y)); // decks of climbable things (the fire lookout's catwalk...)
    return this.build ? Math.max(t, this.build.surfaceAt(x, z, this.pos.y)) : t;
  }

  /** Unit vector the camera looks along on the ground plane. */
  forward(out = new THREE.Vector3()) {
    return out.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
  }

  update(dt, input, world, active) {
    // --- look
    if (active) {
      this.yaw -= input.dx * 0.0024;
      this.pitch = clamp(this.pitch + input.dy * 0.0022, -0.45, 1.53); // free look: from up at the sky to straight down
      this.dist = clamp(this.dist * (1 + input.wheel * 0.12), 2.5, 42); // free zoom; capped so the world's edge never shows
    } else {
      this.yaw += dt * 0.05; // idle orbit on the title screen
    }

    // --- climbing a ladder (or scrambling up rock): carried along the climb's path, nothing else to do meanwhile
    if (this.climbing) {
      const c = this.climbing; c.t += dt;
      alongPath(c.pts, c.len, Math.min(1, c.t / c.dur), this.pos);
      this.vel.set(0, 0, 0); this.velY = 0; this.onGround = true;
      let d = c.face - this.facing; d = Math.atan2(Math.sin(d), Math.cos(d)); this.facing += d * Math.min(1, dt * 12);
      if (c.t >= c.dur) this.climbing = null;
      const connected = this.avatar.update(dt, 1.6, false, false); // hand over hand: the walk cycle reads as climbing
      this.avatar.root.position.copy(this.pos); this.avatar.root.rotation.y = this.facing;
      return { connected, sprinting: false };
    }
    // up on a deck: the world's ground-level colliders don't reach up here; a railed deck keeps you on it
    const upOn = this.climbs ? this.climbs.standing(this.pos) : null;

    // --- move intent
    const f = this.forward(_f);
    const r = _r.set(-f.z, 0, f.x);
    const wish = _w.set(0, 0, 0);
    if (active) {
      if (input.down('KeyW')) wish.add(f);
      if (input.down('KeyS')) wish.sub(f);
      if (input.down('KeyD')) wish.add(r);
      if (input.down('KeyA')) wish.sub(r);
    }
    const moving = wish.lengthSq() > 0;
    if (moving) wish.normalize();

    const ground = this.groundAt(this.pos.x, this.pos.z);
    this.swimming = ground < WATER_LEVEL - SWIM_DEPTH && this.pos.y <= WATER_LEVEL - SWIM_DEPTH + 0.3;

    // --- health: heals slowly once you've been left alone a while (faster by a fire)
    this.hurtTimer -= dt;
    // (only with something in your belly: peckish, under 30, and wounds stop mending)
    if (!this.dead && this.hurtTimer <= 0 && this.fullness >= 30 && !this.chilled && this.health < this.maxHealth) this.health = Math.min(this.maxHealth, this.health + dt * (this.warm ? 5 : 1.5));

    // --- stamina / sprint
    this.staminaBoost = Math.max(0, this.staminaBoost - dt);
    this.maxStamina = this.staminaBoost > 0 ? 300 : 200;
    const wantsSprint = active && moving && input.down('ShiftLeft') && !this.swimming;
    const sprinting = wantsSprint && this.stamina > 1;
    if (sprinting) { this.stamina -= 11 * dt * (this.thrift || 1); this.staminaRest = 0.6; } // (leather boots: thrift 0.67)
    else if ((this.staminaRest -= dt) <= 0) this.stamina += 34 * dt * (this.warm ? 2 : 1) * (this.chilled ? 0.5 : 1); // chilled to the bone, you get your breath back slowly
    // --- hunger: the belly empties over about a day and a half, twice as fast while sprinting. Starving (under 10)
    // caps your stamina at half; quite empty, you slowly weaken (never below 20 health: the farm is kind)
    this.fullness = Math.max(0, this.fullness - dt * (sprinting ? 0.19 : 0.09) * (this.chilled ? 1.5 : 1)); // the cold burns through your supper
    if (this.fullness < 10) this.maxStamina = Math.min(this.maxStamina, 100);
    if (this.fullness <= 0 && !this.dead && this.health > 20) this.health = Math.max(20, this.health - dt * 0.3);
    this.stamina = clamp(this.stamina, 0, this.maxStamina);

    let speed = (this.swimming ? SWIM : sprinting ? SPRINT : WALK) * (this.riding && !this.swimming ? 1.7 * (this.oatsFed ? 1.25 : 1) : 1); // a horse under you: nearly twice the pace (and a quarter faster again on a bellyful of oats)
    if (this.wading) speed *= 0.6 - 0.2 * wadeDepth(this.pos.x, this.pos.z); // slow going, slower the deeper
    if (this.avatar.swing >= 0) speed *= 0.45;

    // steep uphill slows you down (terrace walls feel like climbing)
    if (moving && this.onGround) {
      const ahead = this.groundAt(this.pos.x + wish.x * 0.6, this.pos.z + wish.z * 0.6);
      const slope = (ahead - ground) / 0.6;
      speed *= clamp(1.35 - slope * 0.35, 0.3, 1);
    }

    // on ice your boots have no grip: you glide, and turning takes a long, lovely curve
    const k = 1 - Math.exp(-(this.onIce && this.onGround ? (moving ? 3.2 : 0.45) : this.onGround || this.swimming ? 12 : 3) * dt); // on ice: push off briskly, then glide a long way
    this.vel.x += (wish.x * speed - this.vel.x) * k;
    this.vel.z += (wish.z * speed - this.vel.z) * k;

    const prevX = this.pos.x, prevZ = this.pos.z;
    this.pos.x += this.vel.x * dt;
    this.pos.z += this.vel.z * dt;
    if (!upOn) this.collide(world); else this.climbs.keepOn(this.pos, prevX, prevZ, upOn);
    // printed water is the edge of the walkable page: slide along the bank instead of entering it
    // ...unless there's a dock or floor built over it: then the planks carry you
    const deck = (x, z) => (this.build && this.build.surfaceAt(x, z, this.pos.y) > -Infinity) || (this.climbs && this.climbs.surfaceAt(x, z, this.pos.y) > -Infinity);
    this.onDeck = isWater(this.pos.x, this.pos.z) && deck(this.pos.x, this.pos.z);
    // a frozen pond carries you like a floor (set by the game on snow days)
    this.onIce = !!this.iceOn && isWater(this.pos.x, this.pos.z) && !this.onDeck;
    // shallow water you wade through, shin-deep and slow; only the deep water turns you back at its edge
    const deep = (x, z) => (isWater(x, z) && !wadeable(x, z)) || impassable(x, z); // (deep water, or the mountains' steep sides)
    if (deep(this.pos.x, this.pos.z) && ((!this.onDeck && !this.iceOn) || impassable(this.pos.x, this.pos.z))) { // (ice and decks carry you over water, never up a mountain)
      if (!deep(this.pos.x, prevZ)) this.pos.z = prevZ;
      else if (!deep(prevX, this.pos.z)) this.pos.x = prevX;
      else { this.pos.x = prevX; this.pos.z = prevZ; }
      this.onDeck = isWater(this.pos.x, this.pos.z) && deck(this.pos.x, this.pos.z);
    }

    this.wading = isWater(this.pos.x, this.pos.z) && !this.onDeck && !this.onIce;
    // --- vertical (wading, his feet go down through the water sheet, so it laps at his shins)
    const g2 = this.groundAt(this.pos.x, this.pos.z) - (this.wading ? 0.3 + 0.5 * wadeDepth(this.pos.x, this.pos.z) : 0); // shin-deep at the edge, waist-deep further out
    if (this.swimming) {
      const target = WATER_LEVEL - SWIM_DEPTH;
      this.pos.y += (target + Math.sin(performance.now() * 0.003) * 0.05 - this.pos.y) * Math.min(1, dt * 6);
      this.velY = 0;
      if (g2 > target) { this.pos.y = g2; this.onGround = true; }
      else this.onGround = false;
    } else {
      if (active && this.onGround && input.hit('Space') && this.stamina > 5) {
        this.velY = JUMP; this.onGround = false; this.stamina -= 5; this.staminaRest = 0.4;
        this.events.push('jump');
      }
      this.velY -= GRAVITY * dt;
      this.pos.y += this.velY * dt;
      if (this.pos.y <= g2) {
        if (!this.onGround && this.velY < -6) this.events.push('land');
        this.pos.y = g2; this.velY = 0; this.onGround = true;
      }
      else if (this.onGround && this.velY <= 0 && this.pos.y - g2 < 0.45) { this.pos.y = g2; this.velY = 0; }
      else this.onGround = false;
      // entering deep water from a fall
      if (g2 < WATER_LEVEL - SWIM_DEPTH && this.pos.y < WATER_LEVEL - SWIM_DEPTH) { this.pos.y = WATER_LEVEL - SWIM_DEPTH; this.velY = 0; this.events.push('splash'); }
    }

    // --- facing
    const hs = Math.hypot(this.vel.x, this.vel.z);
    let targetFacing = this.facing;
    if (this.avatar.swing >= 0 || this.aiming) targetFacing = Math.atan2(f.x, f.z); // (drawing the bow, he faces his aim)
    else if (hs > 0.4) targetFacing = Math.atan2(this.vel.x, this.vel.z);
    let d = targetFacing - this.facing;
    d = Math.atan2(Math.sin(d), Math.cos(d));
    this.facing += d * Math.min(1, dt * 12);

    const connected = this.avatar.update(dt, hs, !this.onGround && !this.swimming, this.swimming);
    this.avatar.root.position.copy(this.pos);
    this.avatar.root.rotation.y = this.facing;

    return { connected, sprinting };
  }

  /** Take damage (armour softens it). Returns true if this blow knocked the farmer out. */
  hurt(amount, armour = 0) {
    if (this.dead) return false;
    this.health -= amount * (1 - armour);
    this.hurtTimer = 6;
    if (this.health <= 0) { this.health = 0; this.dead = true; return true; }
    return false;
  }

  collide(world) {
    const near = world.resourcesNear(this.pos.x, this.pos.z, 1.5)
      .filter((r) => !WALK_THROUGH.has(r.type)) // grass, bushes and the like: you just push through
      .map((r) => ({ x: r.x, z: r.z, r: RESOURCE_TYPES[r.type].radius * r.scale }))
      .concat(world.colliders);
    for (const res of near) {
      const rad = res.r + 0.3;
      const dx = this.pos.x - res.x, dz = this.pos.z - res.z;
      const d = Math.hypot(dx, dz);
      if (d < rad && d > 1e-4) {
        this.pos.x = res.x + (dx / d) * rad;
        this.pos.z = res.z + (dz / d) * rad;
      }
    }
    if (this.build) this.build.collide(this.pos);
  }

  /** The resource the player would hit: nearest alive one in front, within reach. */
  findTarget(world) {
    const f = this.forward(_f);
    let best = null, bestD = Infinity;
    for (const res of world.resourcesNear(this.pos.x, this.pos.z, REACH)) {
      const dx = res.x - this.pos.x, dz = res.z - this.pos.z;
      const d = Math.hypot(dx, dz);
      const edge = d - RESOURCE_TYPES[res.type].radius * res.scale;
      if (edge > REACH) continue;
      const dot = d > 0.01 ? (dx * f.x + dz * f.z) / d : 1;
      if (dot < 0.25) continue;
      const score = edge + (RESOURCE_TYPES[res.type].minor ? 1.2 : 0); // grass only when nothing better is in reach
      if (score < bestD) { bestD = score; best = res; }
    }
    return best;
  }

  /**
   * Zoomed out, the lens looks steeply down at the scene around the farmer (the diorama view, ~48–52°).
   * The view is centred on the farmer (no look-ahead, no pull toward what he's working on: both made it scoot).
   */
  updateCamera(dt, focus = null, world = null) {
    // The camera is entirely yours: the mouse sets yaw and pitch, the wheel sets distance.
    const zoom = THREE.MathUtils.smoothstep(this.dist, 11, 40); // 0 = close, 1 = far (only shapes the aim)
    const f = this.forward(_f);

    // The camera rides on the farmer (tight, so it never trails) plus a smoothed offset toward what he's
    // working on (gentle, and capped, so switching targets glides instead of swinging).
    const anchor = _t2.set(this.pos.x, this.pos.y + 0.9, this.pos.z);
    const aim = _t;
    // Centred on the farmer himself, at chest height: no look-ahead in the direction he faces (that swung the
    // view round whenever he turned, and near trees and walls, where collisions keep nudging his heading, it
    // made the camera scoot about).
    aim.set(0, THREE.MathUtils.lerp(0.35, 0.1, zoom), 0);
    this.focusOffset.lerp(aim, 1 - Math.exp(-dt * 3));
    this.anchor.lerp(anchor, 1 - Math.exp(-dt * 18));
    const t = this.camTarget.copy(this.anchor).add(this.focusOffset);

    const cp = Math.cos(this.pitch);
    const cam = this.camera.position.set(
      t.x + Math.sin(this.yaw) * cp * this.dist,
      t.y + Math.sin(this.pitch) * this.dist,
      t.z + Math.cos(this.yaw) * cp * this.dist,
    );
    // keep above the ground, but ease the lift in and out instead of snapping up when the lens meets a hill
    const floor = Math.max(getHeight(cam.x, cam.z), WATER_LEVEL - 0.2) + 0.5;
    const want = Math.max(0, floor - cam.y);
    this.camLift = (this.camLift || 0) + (want - (this.camLift || 0)) * (1 - Math.exp(-dt * (want > (this.camLift || 0) ? 10 : 4)));
    cam.y += this.camLift;
    this.camera.lookAt(t);

  }
}

const _f = new THREE.Vector3(), _r = new THREE.Vector3(), _w = new THREE.Vector3(), _t = new THREE.Vector3(), _t2 = new THREE.Vector3(), _t3 = new THREE.Vector3();
