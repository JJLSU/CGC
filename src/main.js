import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { Landmarks, LANDMARK_INFO } from './landmarks.js';
import { Shafts } from './shafts.js';
import { Wake } from './wake.js';
import { World, getHeight, isWater, wadeable, impassable, setRangeCenter, setFlatArea, RESOURCE_TYPES, CHUNK, WATER_LEVEL, landAt, LANDS, setWorldSeed, regionAt, uniqueEncounters } from './world.js';

// what the old folks say of the wild lands' treasures and keepers (shown the first time you meet each)
const TREASURE_LORE = {
  sang: 'Wild sang! The forked root of the ginseng, dug from the Hollows. The tinker pays well for three.',
  silver: 'Silver, bright as a new dime in the red rock. Two of these and the tinker will hand over steel.',
  pearl: 'A pearl from the fen mussels, pale as the moon on black water. The tinker will want a pair.',
  geode: 'A thunder egg, cracked open on a heart of violet crystal. The tinker collects them.',
  amber: 'Pine amber, gold and warm, with a gnat sealed in it. The tinker takes three.',
};
const KEEPER_LORE = {
  hodag: 'The HODAG! Up out of the reeds it comes, horns and spikes and a grin full of teeth. It keeps the pearls.',
  wampus: 'A WAMPUS CAT drops out of the pines, all smoke and lamp-yellow eyes! Mind its pounce.',
  gouger: 'A sidehill gouger! It lists along on its short uphill legs, and it doesn\'t like company near its silver.',
  hidebehind: 'Something was behind you all along: the HIDEBEHIND, tall and grey as birch shadow!',
  coyote: 'Coyotes! A whole pack, out of the long grass. They keep the thunder eggs.',
};
// what the town says as each building is put right
const MEND_TEXT = {
  store: 'Planks off the windows, a fresh coat of buff paint, a new sign: GENERAL MDSE. The storekeeper sweeps the boardwalk and sets out a barrel of crackers.',
  assay: 'The assay office gets new glass and a coat of oxblood red. The assayer polishes his brass scales and almost smiles.',
  boarding: 'The boarding house is patched and painted blue-grey, every window glazed. Somebody hangs a sign: ROOMS · MEALS.',
  saloon: 'THE GOLDEN GARTER is back in business: fresh red and gold paint, the batwing doors swinging free, a piano being tuned, and a hand-lettered card in the window: "Can-Can Revue Nightly".',
  livery: 'The livery barn gets new doors and a whitewashed cross-brace. A mule looks out, unimpressed.',
  smithy: 'The forge is relit and the anvil rings again: the blacksmith\'s is open for business.',
  church: 'The steeple is set straight and the church is whitewashed till it shines. Sunday, the bell will ring.',
};
import { Sky } from './sky.js';
import { Player } from './player.js';
import { Figure } from './figure.js';
import { Input } from './input.js';
import { Confetti } from './particles.js';
import { Hud, TOOLBAR } from './hud.js';
import { Dandelions } from './dandelions.js';
import { Homestead } from './homestead.js';
import { Town, PLAYBILL } from './town.js';
import { Climbs } from './climb.js';
import { makeSaddle, placeSaddle } from './saddle.js';
import { buildRanges } from './ranges.js';
import { NativeCamps, setLodgeGlow } from './natives.js';
import { Hunting, BOW, REVOLVER, RIFLE } from './hunting.js';
import { loadFolk, loadAnimals, loadProps, animalModel } from './modelfolk.js';
// the folk made from the reference art that the game uses (each about 5 MB; only these are loaded)
// the animals made from the reference art that the game uses (each about 4.5 MB): Old Blue, the barn cat and the horse
// the buildings and props made from the reference art that the game uses (each about 5 MB)
const PROP_MODELS = ['bldg_bank_ruined', 'bldg_bank_restored', 'bldg_barber_ruined', 'bldg_barber_restored', 'bldg_bakery_ruined', 'bldg_bakery_restored', 'bldg_jail_ruined', 'bldg_jail_restored', 'bldg_feed_ruined', 'bldg_feed_restored', 'bldg_opera_ruined', 'bldg_opera_restored', 'bldg_telegraph_ruined', 'bldg_telegraph_restored', 'bldg_hotel2_ruined', 'bldg_hotel2_restored', 'bldg_drygoods_ruined', 'bldg_drygoods_restored', 'bldg_cooper_ruined', 'bldg_cooper_restored', 'bldg_stable2_ruined', 'bldg_stable2_restored', 'bldg_dance_ruined', 'bldg_dance_restored', /* (Second and Third Street, as they're made) */ 'bldg_blacksmith_ruined', 'bldg_blacksmith_restored', 'bldg_church_ruined', 'bldg_church_restored', 'bldg_hotel_ruined', 'bldg_hotel_restored', 'bldg_saloon_ruined', 'bldg_saloon_restored', 'bldg_store_ruined', 'bldg_store_restored', 'mine_sluice', 'mine_entrance', 'prop_workbench', 'furn_bed', 'veh_freight_wagon', 'veh_broken_wagon', 'veh_handcart', 'prop_lamppost', 'prop_mailbox', 'prop_tipi', 'prop_tipi_painted', 'prop_travois', 'prop_drying_rack', 'prop_parfleche', 'prop_bedroll', 'prop_cookfire', 'prop_pouch', 'prop_drum', 'mine_scales', 'bldg_assay', 'bldg_livery', 'prop_scarecrow', 'bldg_leanto', 'bldg_farmhouse_starter', 'bldg_farmhouse_partly', 'bldg_farmhouse_mended', 'bldg_barn', 'bldg_coop', 'prop_haybale_round', 'prop_forge', 'prop_snowman', 'prop_tent', 'prop_beaverlodge', 'prop_haybales', 'prop_woodpile', 'animal_owl', 'animal_cardinal', 'animal_bluebird', 'animal_chickadee', 'animal_crow', 'animal_frog', 'animal_hidebehind', 'veh_stagecoach', 'prop_watertower', 'veh_covered_wagon', 'prop_barrel', 'prop_crates', 'bldg_cottage_restored', 'mine_windlass', 'mine_orecart', 'mine_toolrack', 'mine_stampmill'];
const ANIMAL_MODELS = ['animal_dog', 'animal_cat', 'animal_horse', 'animal_bison', 'animal_rabbit', 'animal_coyote', 'animal_cow', 'animal_calf', 'animal_ox', 'animal_donkey', 'animal_sheep', 'animal_deer', 'animal_hodag', 'animal_wampus', 'animal_boar']; // (+ the prairie bison herd and the rabbits)
// peace offerings, one per kind of keeper: what it takes, the prompt, what the tales say, and what happens
const PEACE = {
  coyote: { cost: { fish: 2 }, give: 'Toss the coyotes 2 fish (a peace offering)', hint: 'The coyotes might doze off for 2 fish',
    lore: 'Folks say the dust-devil coyotes will doze off for a couple of fish.', thanks: 'The coyotes gulp the fish, circle three times and curl up in the sun. What they keep is yours till morning.' },
  boar: { cost: { apples: 3 }, give: 'Toss the old boar 3 apples (a peace offering)', hint: 'The old boar might take kindly to 3 apples',
    lore: 'The old tales say a bramble boar can be bought off with three good apples.', thanks: "The old boar snuffles up the apples, grunts, and settles down for a nap. Mind you don't wake him." },
  gouger: { cost: { berries: 4 }, give: 'Toss the gougers 4 berries (a peace offering)', hint: 'The gougers might nod off for 4 berries',
    lore: 'They say a sidehill gouger will nod off for a handful of berries (4).', thanks: 'The gougers lap up the berries, lean into the hillside on their short legs and nod off. The silver is yours till morning.' },
  hodag: { cost: { fish: 3 }, give: 'Toss the Hodag 3 fish (a peace offering)', hint: 'The Hodag might be bought off with 3 fish',
    lore: 'Up north they say a Hodag will trade a night\'s peace for a mess of fish (3).', thanks: 'The Hodag crunches the fish bones and all, grins its awful grin, and sinks down in the reeds to sleep it off. The pearls are yours till morning.' },
  wampus: { cost: { milk: 2 }, give: 'Set out 2 pails of milk for the wampus cat (a peace offering)', hint: 'The wampus cat might settle for 2 pails of milk',
    lore: 'Old-timers set out milk for the wampus cat, the way you would for any cat, only more of it (2 pails).', thanks: 'The wampus cat laps the milk, washes its whiskers, and curls up on the ridge with its tail over its nose. The amber is yours till morning.' },
  hidebehind: { cost: { honey: 2 }, give: 'Leave 2 jars of honey behind you (a peace offering)', hint: 'The Hidebehind might leave you be for 2 jars of honey',
    lore: 'They say if you leave honey behind you (2 jars), the Hidebehind is too busy with it to follow.', thanks: 'You set the honey down and do not look back. Something behind you sighs, and sticky slurping follows. The sang is yours till morning.' },
};
const FOLK_MODELS = ['folk_jim', 'folk_native_warrior', 'folk_native_archer', 'folk_native_hunter', 'folk_native_woman', 'folk_native_maiden', 'folk_native_elder', 'folk_native_grandfather', 'folk_native_girl', 'folk_farmhand_01', 'folk_farmhand_02', 'folk_farmhand_03', 'folk_calico_01', 'folk_calico_02', 'folk_calico_03', 'folk_fiddler', 'folk_ezra', 'folk_otis', 'folk_silas', 'folk_player', 'folk_tinker', 'folk_johnny', 'folk_asa', 'folk_amos', 'folk_liveryman', 'folk_abel', 'folk_luther', 'folk_mose', 'saloon_1', 'townsfolk_3', 'prospectors_1', 'prospectors_2', 'prospectors_3', 'prospectors_4', 'prospectors_5', 'prospectors_6', 'saloon_2', 'saloon_3', 'saloon_4', 'townsfolk_1', 'townsfolk_2', 'townsfolk_4', 'trades_1', 'trades_5', 'trades_2', 'trades_4', 'trades_6', 'trades_7'];
import { RootCellar, CELLAR_COST } from './cellar.js';
import { Bunkhouse, BUNK_COST } from './bunkhouse.js';
import { Puppet } from './puppets.js';
import { Laundry } from './laundry.js';
import { Mail } from './mail.js';
import { Weathervane } from './weathervane.js';
import { Frogs } from './frogs.js';
import { Jar, JAR_MAX } from './jar.js';
import { NightSky } from './nightsky.js';
import { Cat } from './cat.js';
import { Fair, isFairDay } from './fair.js';
import { FireSmoke } from './firesmoke.js';
import { BarnDance, isDanceNight, danceNightOf, hz } from './barndance.js';
import { Tumbleweeds } from './tumbleweed.js';
import { HoofDust } from './dust.js';
import { Fireworks } from './fireworks.js';
import { NightHowl } from './howl.js';
import { Signpost } from './signpost.js';
import { Footprints } from './footprints.js';
import { Ducks } from './ducks.js';
import { Railroad } from './railroad.js';
import { Train } from './train.js';
import { Claim } from './claim.js';
import { Mist } from './mist.js';
import { Kite } from './kite.js';
import { LeafPiles } from './leafpiles.js';
import { Puddles } from './puddles.js';
import { Wanderer, SAYINGS } from './wanderer.js';
import { Songbirds } from './songbirds.js';
import { Calf } from './calf.js';
import { Woodpiles, PILE_MAX } from './woodpile.js';
import { GiantPumpkins, GIANT_STAGES } from './giantpumpkin.js';
import { Grandma, PIE_WORDS, wishFor } from './grandma.js';
import { Storm } from './storm.js';
import { FairyRing } from './fairyring.js';
import { FallingStars, STAR_GIFTS } from './fallingstar.js';
import { createPost } from './post.js';
import { BuildSystem, PIECES, PIECE_ORDER, PIECE_GROUPS, PIECE_HP, STONE_PIECES, costText, costHTML } from './building.js';
import { Sound } from './audio.js';
import { Ambient } from './ambient.js';
import { Critters } from './critters.js';
import { Journal } from './journal.js';
import { Rumours } from './rumour.js';
import { Fishing } from './fishing.js';
import { Weather } from './weather.js';
import { uSnow, uCloudShade } from './materials.js';
import { Tinker } from './tinker.js';
import { Coop } from './coop.js';
import { CountyMap } from './map.js';
import { Crows } from './crows.js';
import { Geese } from './geese.js';
import { Beaver } from './beaver.js';
import { Eagle } from './eagle.js';
import { Settlers, WORKS, WORK_NAME } from './settlers.js';
import { Tales } from './tales.js';
import { Owl } from './owl.js';
import { Wisp } from './wisp.js';
import { Porch, WARP } from './porch.js';
import { Rainbow } from './rainbow.js';
import { Dog } from './dog.js';
import { Butterflies } from './butterflies.js';
import { DAY_LENGTH } from './sky.js';
import { Enemies, GUARDS } from './enemies.js';
import { REACH } from './player.js';
import { uIce } from './materials.js';
import { CraftingPanel, damageFor, toolFor, SOFT, RECIPES, newRequest, requestState, newOrder, orderState, clearOrder } from './crafting.js';

async function main() {
  // ?gpu turns on GPU timestamp queries (renderer.info.render.timestamp) for profiling
  const renderer = new THREE.WebGPURenderer({ antialias: false, trackTimestamp: new URLSearchParams(location.search).has('gpu') });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); // the quality level sets this below
  renderer.setSize(Math.max(1, innerWidth), Math.max(1, innerHeight));
  renderer.toneMapping = THREE.NeutralToneMapping; // keeps chroma; AgX washed the autumn colours out
  renderer.toneMappingExposure = 1.4;
  renderer.shadowMap.enabled = true;
  document.getElementById('app').appendChild(renderer.domElement);
  await renderer.init();

  const scene = new THREE.Scene();
  // a long macro lens (28° vertical) looking 40–55° down into the paper model: the page runs past every edge
  const camera = new THREE.PerspectiveCamera(30, innerWidth / Math.max(1, innerHeight), 0.2, 900);

  const sky = new Sky(scene);
  // the world itself: each new game rolls a seed of its own (so every county is new, with wild lands starting
  // close by the homestead); a save from before this keeps the original world, wild lands and all, as it was
  let worldParams = null;
  try { const raw = JSON.parse(localStorage.getItem('paperfjord.builds.v1') || 'null'); if (raw) worldParams = raw.world || { seed: 20261120, ring: [130, 210] }; } catch { /* storage unavailable */ }
  if (!worldParams) worldParams = { seed: (Math.random() * 2 ** 31) >>> 0, ring: [60, 115] };
  setWorldSeed(worldParams.seed, worldParams.ring);
  await Promise.all([loadFolk(FOLK_MODELS), loadAnimals(ANIMAL_MODELS), loadProps(PROP_MODELS)]); // the folk made from the reference art (see assets/PIPELINE.md); missing ones fall back to paper dolls (before the world and the homestead: its rocks and its farmhouse are some)
  const world = new World(scene);
  const center = world.findSpawn();
  setFlatArea(center.x, center.z, 24, 38); // the farm sits on one level sheet
  setRangeCenter(center.x, center.z); // the home valley's mountain rim rings the farm (and the town 85 m off), wherever the farm lies
  buildRanges(scene, sky); // the great ranges on the horizon, walling in the valleys
  const home = new Homestead(scene, world, center); // registers exclusions before chunks exist
  const cellar = new RootCellar(scene, world, center); // the first thing gold buys for the homestead
  const bunkhouse = new Bunkhouse(scene, world, center); // the second: a bunkhouse for the hired hands
  const town = new Town(scene, world, center); // Paydirt Hollow, down the lane (lays its own level ground before chunks exist)
  const railroad = new Railroad(scene, world, town, center); // the line out of town (its right-of-way cleared before chunks exist; laid once the town earns it)
  const _ride = new THREE.Vector3();
  const train = new Train(scene, railroad); // the Overland & Western's little paper train, on its timetable
  const claim = new Claim(scene, railroad); // your own gold claim, once filed at the Redrock Breaks post
  claim.onThump = (d) => { if (sound.ready && !sound.muted && d < 45) sound.stamp(Math.max(0.1, 1 - d / 45)); };
  // the fingerpost at the farm end of the lane to town, a little to the side of it
  { const tx = town.at.x - center.x, tz = town.at.z - center.z, td = Math.hypot(tx, tz), ux = tx / td, uz = tz / td, sx = center.x + ux * 24 - uz * 2.6, sz = center.z + uz * 24 + ux * 2.6;
    new Signpost(scene, new THREE.Vector3(sx, 0, sz), town); world.colliders.push({ x: sx, z: sz, r: 0.3 }); }
  /** At the door of a building in town (mended ones only, unless `any`). */
  const atTownDoor = (id, pos, any = false) => (any || town.tiers[id]) && Math.hypot(pos.x - town.doors[id].x, pos.z - town.doors[id].z) < 2.3;
  let pianoT = 0, dollyDay = -1, blessedDay = -1, bellDay = -1, bellT = -1, meetingDay = -1, fwDay = -1, riderDay = -1, crowDay = -1, railCheckT = 2, hymnT = 0, hymnI = 0;
  // [melody midi note, beats, bass note on the bar's downbeat]: G major, three beats a bar; 0 = a rest
  const HYMN = [[67, 1, 43], [71, 1], [74, 1], [72, 2, 48], [71, 1], [69, 2, 50], [67, 1], [69, 3, 50],
    [71, 1, 43], [74, 1], [79, 1], [76, 2, 48], [74, 1], [72, 1, 45], [71, 1], [69, 1], [67, 3, 43], [0, 3]]; // (the parson's blessing; the dawn bell)
  // the saddle horse from the livery (once it's mended): bought once, ridden with X, left grazing where you get down
  let horse = null, riding = false; const horseSaved = { owned: false, x: 0, z: 0 };
  const tinker = new Tinker(scene, world, center, town.spot(-19, -3.4)); // at the head of Main Street
  const coop = new Coop(scene, world, center);
  const fair = new Fair(scene, world, center, home.roofs[0], town.spot(15, 0, 0, 0)); fair.pinTo(home.houseModel || home.house); home.onHouseModel = (m) => fair.pinTo(m); // up the street before the church, facing back down it
  const dance = new BarnDance(scene, center, town.spot(-1, 1.2, -1, -8)); // in the street before the livery barn // fair night: lanterns, a fiddler and dancing couples by the barn // the County Fair's judging table, every seventh day
  const vane = new Weathervane(scene, home.vaneAt); // the copper rooster on the barn ridge
  const frogs = new Frogs(scene); // on the lily pads
  frogs.onCroak = (v) => sound.croak(v); frogs.onPlop = () => sound.plop();
  const laundry = new Laundry(scene, world, center); // washing on the line in the yard
  const countyMap = new CountyMap(document.getElementById('map'));
  const landmarks = new Landmarks(scene); // the wild lands' landmarks (placed with their chunks; see below)
  const climbs = new Climbs(); landmarks.climbs = climbs; // what you can climb: the fire lookout, the arch, the wreck...
  // the farm windmill: up the ladder on its south face (stepping round the stock tank) to the railed plank platform
  // under the head, 8 m up; the first time each day, the whole home place is laid out below you and inked on the map
  climbs.add('windmill', home.millAt.x, home.millAt.y, home.millAt.z, 0, {
    decks: [{ x: 0, z: 0, hw: 0.75, hd: 0.75, y: 7.89, rail: true }],
    ladders: [{ foot: [1.4, 0, 0.45], via: [[0.3, 0.65, 0.78], [0, 1.0, 0.76]], top: [0, 7.89, 0.32], land: [0.42, -0.35], name: 'the windmill' }],
  });
  let millViewDay = -1, millPending = false;
  const shafts = new Shafts(scene); // tissue-paper sunbeams slanting through the trees
  const wadeRings = new Wake(scene); // rings on the water when you wade
  const tales = new Tales(document.getElementById('story'));
  const mail = new Mail(document.getElementById('letter'), home.mailFlag, home.mailbox); // RFD: a letter most mornings
  // postcards (K): the view as it is, printed onto a cream card with a deckled edge and a caption, saved as a PNG
  let snapWanted = false;
  const makePostcard = () => {
    const src = renderer.domElement, w = src.width, h = src.height;
    const pad = Math.round(Math.min(w, h) * 0.06), foot = Math.round(pad * 2.2);
    const c = document.createElement('canvas'); c.width = w + pad * 2; c.height = h + pad + foot;
    const g = c.getContext('2d');
    // the card: cream stock with a deckled edge and a scatter of fibres
    g.fillStyle = '#efe3c4';
    g.beginPath();
    const W = c.width, H = c.height, j = () => Math.random() * 5;
    g.moveTo(j(), j());
    for (let x = 0; x <= W; x += 14) g.lineTo(x, j());
    for (let y = 0; y <= H; y += 14) g.lineTo(W - j(), y);
    for (let x = W; x >= 0; x -= 14) g.lineTo(x, H - j());
    for (let y = H; y >= 0; y -= 14) g.lineTo(j(), y);
    g.fill();
    for (let i = 0; i < W * H / 900; i++) { g.fillStyle = `rgba(110,80,50,${Math.random() * 0.12})`; g.fillRect(Math.random() * W, Math.random() * H, 1 + Math.random() * 3, 1); }
    // the picture, with a thin warm shadow as if pasted on
    g.save(); g.shadowColor = 'rgba(74,38,14,0.35)'; g.shadowBlur = 8; g.shadowOffsetX = 3; g.shadowOffsetY = 4;
    g.drawImage(src, pad, pad); g.restore();
    g.strokeStyle = 'rgba(58,42,28,0.6)'; g.lineWidth = 2; g.strokeRect(pad, pad, w, h);
    // the caption, in a postcard hand
    g.fillStyle = '#3a2a1c'; g.textAlign = 'left'; g.textBaseline = 'middle';
    g.font = `italic ${Math.round(foot * 0.36)}px Georgia, 'Times New Roman', serif`;
    g.fillText('Greetings from Paydirt Hollow', pad, h + pad + foot * 0.45);
    g.font = `${Math.round(foot * 0.22)}px Georgia, serif`; g.fillStyle = '#6b5440';
    g.fillText(sky.clockText().replace(' · ', ', '), pad, h + pad + foot * 0.78);
    // a little red stamp in the corner
    const sx = W - pad - foot * 0.7, sy = h + pad + foot * 0.12, sw = foot * 0.62, sh = foot * 0.72;
    g.fillStyle = '#b5473a'; g.fillRect(sx, sy, sw, sh);
    g.strokeStyle = '#efe3c4'; g.setLineDash([3, 3]); g.lineWidth = 2; g.strokeRect(sx + 4, sy + 4, sw - 8, sh - 8); g.setLineDash([]);
    g.fillStyle = '#efe3c4'; g.font = `bold ${Math.round(sh * 0.35)}px Georgia, serif`; g.textAlign = 'center'; g.fillText('2¢', sx + sw / 2, sy + sh / 2);
    c.toBlob((blob) => {
      if (!blob) return;
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `paperfjord-day${sky.day}.png`;
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(a.href), 4000);
    }, 'image/png');
    window.paperfjord.lastPostcard = c; // handy for checking
    hud.toast('Snap! A postcard of the farm is on its way to your downloads.');
    sound.click();
  };
  // a barn owl keeps watch from the pen's corner post after dark
  const owl = new Owl(scene, new THREE.Vector3(center.x + 6, getHeight(center.x + 6, center.z + 10) + 1.02, center.z + 10));
  owl.onHoot = () => sound.hoot();
  // a will-o'-the-wisp that, some nights, leads the way to a lost satchel
  const wisp = new Wisp(scene);
  const porch = new Porch(scene, home.roofs[0]); // a rocking chair on the farmhouse porch
  let wispTold = false;
  wisp.onAppear = () => { if (!wispTold) { wispTold = true; hud.toast("A will-o'-the-wisp bobs at the edge of the dark. Folks say they lead to lost things."); } sound.lullaby(); };
  const player = new Player(scene, camera, home.spawn);
  player.climbs = climbs;
  const confetti = new Confetti(scene);
  const ambient = new Ambient(scene);
  const woodpiles = new Woodpiles(scene); // the logs stacked on your woodpiles
  const giants = new GiantPumpkins(scene); // prize pumpkins swelling on your patches
  const fairyRing = new FairyRing(scene); // toadstools in a ring, the morning after a wet night
  let ringRain = false;
  const storm = new Storm(scene); // summer thunderstorms: paper lightning far off, thunder rolling in after
  const grandma = new Grandma(scene, home.frontWindow, home.frontDoor); // Grandma Pell's shadow in the lamplit window
  const calf = new Calf(scene, new THREE.Vector3(center.x - 5, 0, center.z + 17)); // Daisy's calf, now and then lost
  calf.onMoo = (v) => sound.moo(v);
  const songbirds = new Songbirds(scene); // cardinals, bluebirds and chickadees at your feeders
  const johnny = new Wanderer(scene, center); // Johnny Appleseed, now and then, walking the lane
  const puddles = new Puddles(scene); // rain puddles in the lanes, rain rings on the ponds
  const dandelions = new Dandelions(scene); // seeded clocks in the meadows: brush through and they puff away
  const leafPiles = new LeafPiles(scene, center); // raked heaps of leaves round the yard: run through them
  let dandelionToldAt = -1e9, setT = 0, hungerWarned = 0, coldT = 0, coldLevel = 0, coldWarned = false, calmT = 0;
  try { if (localStorage.getItem('paperfjord.dev')) document.body.classList.add('dev'); } catch { /* ignore */ }
  const coldEl = document.getElementById('cold');
  const tapped = new Map(); // maple → the day it was last tapped
  let leafKicks = 0;
  const kite = new Kite(scene); // the paper kite (G), once you've made one
  const mist = new Mist(scene); // tissue-paper mist lying low over the fields at first light
  let nightRain = false;
  const ducks = new Ducks(scene); // a mallard and her ducklings on the nearest pond
  train.onDepart = () => { const n = railroad.takeFreight(); if (n && Math.hypot(player.pos.x - railroad.depot.x, player.pos.z - railroad.depot.z) < 80) hud.toast(`The freight hands swing your ${n} crate${n > 1 ? 's' : ''} into the boxcar, and the train pulls out for the East.`); };
  train.onWhistle = (p) => { const d = Math.hypot(p.x - player.pos.x, p.z - player.pos.z); if (sound.ready && !sound.muted && d < 220) sound.whistle(Math.max(0.15, 1 - d / 220)); };
  train.onChuff = (p) => { const d = Math.hypot(p.x - player.pos.x, p.z - player.pos.z); if (sound.ready && !sound.muted && d < 70) sound.chuff(Math.max(0.1, 1 - d / 70)); };
  ducks.onRing = (x, z, s) => wadeRings.ring(x, z, s); ducks.onQuack = (d) => { if (sound.ready && !sound.muted && d < 40) sound.quack(Math.max(0.15, 1 - d / 40)); };
  const footprints = new Footprints(scene); // a trail of prints across the snow
  const nightHowl = new NightHowl(scene); // a coyote howling on the rise, some dark nights
  const fireworks = new Fireworks(scene), fwAt = new THREE.Vector3(); // Saturday nights over a finished town
  const hoofDust = new HoofDust(scene); // dust kicked up behind a galloping horse
  const tumbleweeds = new Tumbleweeds(scene); // dry brush bowling down the wind in town and the Breaks
  const fireSmoke = new FireSmoke(scene); // smoke and sparks over your own campfires and forge
  const fallingStars = new FallingStars(scene); // now and then one comes down nearby
  const nightSky = new NightSky(scene); // paper stars and a crescent moon
  const jar = new Jar(player.avatar); // the lightning-bug jar in his left hand (shown once crafted)
  world.exclusions.push({ x: center.x - 5, z: center.z + 17, r: 6 }); // an open pasture south of the yard
  const critters = new Critters(scene, new THREE.Vector3(center.x - 7, 0, center.z - 1), new THREE.Vector3(center.x - 5, 0, center.z + 17)); // hens by the barn, cow & sheep in the pasture
  const hud = new Hud();
  const input = new Input(renderer.domElement);
  hud.backend.textContent = renderer.backend.isWebGPUBackend ? 'WebGPU' : 'WebGL 2';


  // ---- graphics quality: high / medium / low, or auto (starts high, steps down while fps stays low)
  const quality = { mode: 'auto', level: 'high', lowSeconds: 0, startedAt: performance.now() };
  try {
    const saved = JSON.parse(localStorage.getItem('paperfjord.quality') || 'null');
    if (saved && QUALITY[saved.level]) { quality.mode = saved.mode === 'manual' ? 'manual' : 'auto'; quality.level = saved.level; }
  } catch { /* storage unavailable */ }
  let post = null, shadowEvery = 1, shadowTick = 0;
  let lensZ = 20, lensAim = 20, lensTick = 0; // the lens's focus distance (eased) and where the centre ray lands
  const _ray = new THREE.Vector3();
  function centreDepth(heroZ) {
    const o = camera.position, d = camera.getWorldDirection(_ray);
    // (the camera always centres on the farmer, so the ray looks past him to what lies beyond)
    let best = Infinity;
    const near = heroZ * 0.9; // anything between the lens and the farmer fades out of the way, so it never takes the focus
    // trees and rocks near the ray (their collider circles, as posts a few metres tall)
    for (const c of world.colliders) {
      const cx = c.x - o.x, cz = c.z - o.z, flat = Math.hypot(d.x, d.z) || 1e-6, t = (cx * d.x + cz * d.z) / (flat * flat);
      if (t <= near || t >= best) continue;
      const px = d.x * t - cx, pz = d.z * t - cz, y = o.y + d.y * t;
      if (px * px + pz * pz < (c.r + 0.3) ** 2 && y < getHeight(c.x, c.z) + 4.5) best = t;
    }
    // the ground: march out in growing steps
    for (let t = near, step = 0.4; t < Math.min(best, 260); t += step, step = Math.min(6, step * 1.12)) {
      const x = o.x + d.x * t, y = o.y + d.y * t, z = o.z + d.z * t;
      if (y < Math.max(getHeight(x, z), WATER_LEVEL)) { best = t; break; }
    }
    return Math.max(2, Math.min(best === Infinity ? 240 : best, 240));
  }
  const lastCamPos = new THREE.Vector3(), lastCamQuat = new THREE.Quaternion();
  function applyQuality(level) {
    const q = QUALITY[level];
    quality.level = level;
    // on medium/low the sun's shadow map is redrawn every 2nd/3rd frame (it moves slowly; saves a whole pass)
    shadowEvery = q.shadowEvery || 1;
    sky.sun.shadow.radius = q.soft || 3;
    sky.sun.shadow.autoUpdate = shadowEvery === 1;
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, q.ratio));
    if (sky.sun.shadow.mapSize.x !== q.shadow) {
      sky.sun.shadow.mapSize.set(q.shadow, q.shadow);
      sky.sun.shadow.map?.dispose();
      sky.sun.shadow.map = null;
    }
    const dofOn = post ? post.u.dofEnabled.value : 1;
    if (post) post.dispose();
    post = createPost(renderer, scene, camera, q.post);
    post.u.dofEnabled.value = dofOn;
    if (window.paperfjord) window.paperfjord.post = post;
    try { localStorage.setItem('paperfjord.quality', JSON.stringify({ mode: quality.mode, level })); } catch { /* ignore */ }
  }
  applyQuality(quality.level);

  const overlay = document.getElementById('overlay');
  const sound = new Sound();
  // sound starts (or wakes, if the browser suspended it) on any real click or key; synthetic events from
  // test scripts don't count as a gesture, and a context made from one comes up suspended and stays silent
  const wake = (e) => { if (e.isTrusted) sound.start(); };
  addEventListener('pointerdown', wake, { capture: true });
  addEventListener('keydown', wake, { capture: true });
  document.addEventListener('pointerlockchange', () => sound.start());
  document.addEventListener('visibilitychange', () => { if (!document.hidden && sound.ctx) sound.start(); });
  const inventory = { wood: 0, stone: 0, berries: 0, apples: 0, applecrisp: 0, fiber: 0, rope: 0, clay: 0, mushrooms: 0, honey: 0, ore: 0, iron: 0, pelt: 0, whiskers: 0, milk: 0, wool: 0, biscuits: 0, egg: 0, flapjacks: 0, fish: 0, fishfry: 0, corn: 0, wheat: 0, bread: 0, ribbon: 0, giantpumpkin: 0, pumpkin: 0, stew: 0, cornbread: 0, pie: 0, honeycake: 0, flour: 0, applepie: 0, bricks: 0, sap: 0, syrup: 0, johnnycake: 0, leather: 0, charcoal: 0, steel: 0, gold: 0, dollars: 0, sang: 0, silver: 0, pearl: 0, geode: 0, amber: 0 };
  const tools = new Set();
  let eFree = true; // nothing but gathering wants E right now (from last frame's prompt)
  let savedFullness = null;
  let fortune = 0, panT = 0; // dollars the assayer has paid you, all told (saved); the pan's swirl timer
  const landsFound = new Set(); let landHere = 'home'; // the wild lands you've walked into (saved)
  const wear = { axe: 100, pick: 100, spear: 100 }; // how sharp each tool is (0 = dull: it hits at half strength)
  let held = 'axe'; // the tool in hand, picked from the tool bar with 1–5

  // building + saved progress (pieces, inventory, crafted tools)
  const build = new BuildSystem(scene, camera);
  player.build = build;
  const saved = build.load();
  let journal = null; // created below; its progress is saved alongside builds
  let bounty = null, operaDay = -1, hotelNight = false;
  // the stage line: from the stage stables, a coach to any landmark you've found out in the county (and you ride
  // the morning coach home from there: the driver drops you back at the stables if you take it again)
  const stageStops = () => {
    const out = [];
    for (const key of landmarks.found || []) {
      const [cx, cz] = key.split(',').map(Number); const st = world.sitesFor(cx, cz).find((s) => s.key === key);
      if (st && LANDMARK_INFO[st.mark]) out.push({ name: LANDMARK_INFO[st.mark].name, x: st.x, z: st.z });
    }
    return out.sort((a, b) => Math.hypot(a.x - town.at.x, a.z - town.at.z) - Math.hypot(b.x - town.at.x, b.z - town.at.z));
  };
  let stageIdx = 0, stageFrom = null;
  // the telegraph office's daily wire: a buyer back East wants one thing today, and pays well for it at the office
  const MARKET = [['pelt', 5, 'a furrier in St. Louis'], ['wool', 3, 'a woollen mill in Lowell'], ['honey', 5, 'a confectioner in Chicago'], ['venison', 3, 'a chophouse in Denver'],
    ['leather', 7, 'a saddler in Kansas City'], ['syrup', 6, 'a hotel in San Francisco'], ['charcoal', 2, 'the smelter at Leadville'], ['egg', 1, 'a bakery in Cheyenne']]; // (operaDay: the night you last saw a show) // the sheriff's posted bounty: { key, guards, x, z, name, pay }
  if (saved) {
    Object.assign(inventory, saved.inventory || {});
    for (const t of saved.tools || []) tools.add(t);
    if (saved.held) held = saved.held;
    if (typeof saved.fullness === 'number') savedFullness = saved.fullness;
    fortune = saved.fortune || 0;
    if (saved.horse) Object.assign(horseSaved, saved.horse);
    town.load(saved.town);
    if (saved.bounty) { bounty = saved.bounty; town.setPoster(bounty); }
    cellar.load(saved.cellar);
    bunkhouse.load(saved.bunkhouse);
    for (const k of saved.lands || []) landsFound.add(k);
    landmarks.load(saved.landmarks);
    if (saved.wear) Object.assign(wear, saved.wear);
    for (const k of saved.beaten || []) world.destroyed.add(k); // beaten guardians stay gone
    countyMap.load(saved.explored);
    tales.load(saved.tales);
    mail.load(saved.mail);
    if (saved.fair) { fair.enteredDay = saved.fair.day || 0; for (const id of saved.fair.entered || []) fair.entered.add(id); }
    const herd = critters.list.filter((c) => c.type === 'cow' || c.type === 'sheep');
    (saved.chores || []).forEach(([m, sh], i) => {
      const c = herd[i]; if (!c) return;
      if (m) c.milkedDay = m;
      if (sh) { c.shornDay = sh; critters.setShorn(c, true); }
    });
    const al = saved.almanac;
    if (al) {
      sky.day = al.day ?? 1; sky.time = al.time ?? sky.time;
      coop.eggs = al.eggs ?? coop.eggs; coop.laidDay = al.laidDay ?? sky.day; coop.refresh();
    }
    grandma.pieDay = saved.grandmaPie ?? -1; grandma.wishDay = saved.grandmaWish ?? -1;
    johnny.talkedDay = saved.johnnyTalked ?? -1;
    calf.load(saved.calf, sky.day);
  }
  let dogRef = null, enemiesRef = null; // set once Old Blue exists (saveAll can run before that)
  let settlersRef = null; // (set once the settlers exist; saves before then keep the saved state)
  // the way to town: trees you fell in a strip between the farmhouse and Paydirt Hollow stay felled, so the track you
  // clear down to town stays clear (the rest of the woods grows back as ever)
  const ROAD_TREES = new Set(['pine', 'maple', 'snag', 'birch', 'goldtree', 'sagetree', 'appletree']);
  const onRoad = (r) => {
    const ax = center.x, az = center.z, bx = town.at.x, bz = town.at.z, dx = bx - ax, dz = bz - az, L2 = dx * dx + dz * dz;
    const t = Math.max(0, Math.min(1, ((r.x - ax) * dx + (r.z - az) * dz) / L2)), qx = ax + dx * t - r.x, qz = az + dz * t - r.z;
    return qx * qx + qz * qz < 7 * 7;
  };
  const roadKept = new Set((saved?.beaten || []).filter((k) => !k.includes(':g') && !k.includes(',satchel,'))); // (felled on the road in an earlier session)
  const roadFelled = (k) => { if (roadKept.has(k)) return true; const g = world.regrow.get(k); return !!g && ROAD_TREES.has(g.res.type) && onRoad(g.res); }; // (saved, so they stay felled)
  const saveAll = () => {
    build.extraSave = {
      settlers: settlersRef ? settlersRef.save() : saved?.settlers,
      world: worldParams, opening: openingDone, fortune, horse: horse ? { owned: true, x: horse.group.position.x, z: horse.group.position.z } : horseSaved, town: town.save(), cellar: cellar.save(), bunkhouse: bunkhouse.save(),
      tools: [...tools], held, fullness: Math.round(player.fullness), lands: [...landsFound], landmarks: landmarks.save(), wear: { ...wear }, journal: journal?.save(), dayLog, beaten: [...world.destroyed].filter((k) => k.includes(':g') || k.includes(',satchel,') || roadFelled(k)), // guardians and found satchels stay gone
      explored: countyMap.save(), tales: tales.save(), mail: mail.save(), fair: { day: fair.enteredDay, entered: [...fair.entered] }, grandmaPie: grandma.pieDay, grandmaWish: grandma.wishDay ?? -1, johnnyTalked: johnny.talkedDay ?? -1, calf: calf.save(),
      campPeace: camp.save(), railroad: railroad.save(), wire: orderState(), claimDay: claim.dugDay, claim: claim.save(), bounty, calm: enemiesRef ? Object.fromEntries(Object.entries(enemiesRef.calmBySite).filter(([, u]) => u > sky.day + sky.time)) : (saved?.calm || {}), dogDay: dogRef?.foundDay || 0, request: requestState() || saved?.request || null,
      almanac: { day: sky.day, time: sky.time, eggs: coop.eggs, laidDay: coop.laidDay }, // the calendar and the hens
      // which cow was milked and which sheep shorn, and when (the herd spawns in a fixed order)
      chores: critters.list.filter((c) => c.type === 'cow' || c.type === 'sheep').map((c) => [c.milkedDay || 0, c.shornDay || 0]),
    };
    build.save(inventory);
  };
  journal = new Journal(document.getElementById('journal'), {
    inventory,
    onComplete(g) {
      const reward = Object.entries(g.reward).map(([k, v]) => `+${v} ${k}`).join(', ');
      hud.toast(`Journal: ${g.text} ✓  (${reward})`);
      sound.craft();
      if (!journal.quiet) saveAll(); // (not mid-load: the rest of the save isn't set up yet; it saves soon after)
    },
  });
  journal.load(saved?.journal);
  journal.quiet = true; journal.catchUp({ tools, pieces: build.pieces, inventory }); journal.quiet = false; // goals you met before they came up count too
  // the almanac: everything the journal hears about today is tallied, and read back when you sleep
  let dayLog = { ...(saved?.dayLog || {}) };
  {
    const rec = journal.record.bind(journal);
    journal.record = (ev, n = 1) => { dayLog[ev] = (dayLog[ev] || 0) + n; return rec(ev, n); };
  }
  const almanacEl = document.getElementById('almanac');
  let almanacT = 0;
  const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;
  const almanacLines = () => {
    const out = [];
    const L = dayLog;
    if (L.chop) out.push(`felled ${plural(L.chop, 'tree', 'trees')}`);
    if (L.mine) out.push(`broke ${plural(L.mine, 'rock', 'rocks')} with the pick`);
    if (L.pick) out.push(`picked ${plural(L.pick, 'berry bush', 'berry bushes')} clean`);
    for (const [k, n] of Object.entries(L)) {
      if (k === 'gather:fish') out.push(`caught ${plural(n, 'fish', 'fish')}`);
      else if (k.startsWith('gather:') && !['wood', 'stone', 'berries'].includes(k.slice(7))) out.push(`gathered ${n} ${k.slice(7)}`);
    }
    const made = Object.keys(L).filter((k) => k.startsWith('craft:') && !k.startsWith('craft:t-')).map((k) => (RECIPES.find((r) => r.id === k.slice(6))?.name || k.slice(6)).toLowerCase());
    if (made.length) out.push(`made ${made.slice(0, 4).join(', ')}${made.length > 4 ? ' and more' : ''}`);
    const built = Object.entries(L).filter(([k]) => k.startsWith('build:')).map(([k, n]) => { const nm = (PIECES[k.slice(6)]?.name || k.slice(6)).toLowerCase(); return n === 1 ? `a ${nm}` : `${n} ${nm}${nm.endsWith('s') ? 'es' : 's'}`; });
    if (built.length) out.push(`raised ${built.slice(0, 4).join(', ')}`);
    if (L.slay) out.push(`drove off ${plural(L.slay, 'treasure guardian', 'treasure guardians')}`);
    if (L.deer) out.push(`spotted ${plural(L.deer, 'deer', 'deer')} in the woods`);
    if (L.livestock) out.push('did the milking and the shearing');
    if (L.shoo) out.push('shooed the crows out of the corn');
    if (L.skep) out.push('took honey from the bees');
    if (L.letter) out.push('read a letter from the mailbox');
    if (L.star) out.push('found a fallen star in the grass');
    if (L.peace) out.push('made peace with a guardian, with a gift');
    if (L.johnny) out.push('talked with Johnny Appleseed, who planted you a tree');
    if (L.calf) out.push('found the lost calf and led it home');
    if (L.dance) out.push('danced a reel at the barn dance');
    if (L.ribbon) out.push(`won ${plural(L.ribbon, 'ribbon', 'ribbons')} at the County Fair`);
    if (L.tinker) out.push('traded with the tinker');
    if (L.request) out.push("filled the tinker's special request");
    if (L.dogfind) out.push('took whatever Old Blue dug up, with thanks');
    if (L.tale) out.push(`told ${plural(L.tale, 'tall tale', 'tall tales')} by the fire`);
    if (L.satchel) out.push('found a lost satchel out in the wilds');
    if (L.legendfish) out.push('landed OLD WHISKERS himself, and nobody will believe it');
    return out.slice(0, 9);
  };
  const showAlmanac = (day) => {
    const lines = almanacLines();
    almanacEl.innerHTML = `<h2>Day ${day}, as the almanac tells it</h2>`
      + (lines.length ? `<p>On this day the farmer…</p><ul>${lines.map((l) => `<li>${l}</li>`).join('')}</ul>` : '<p>A quiet day. Sometimes that\'s the best kind.</p>')
      + '<small>E to close</small>';
    almanacEl.classList.add('show');
    almanacT = 12;
    dayLog = {};
  };
  const rumours = new Rumours(world, document.getElementById('rumour'));
  // the way home: once you're well out (90 m), a chip by the clock with an arrow that turns with your view
  // one centre panel at a time: whichever opened last is shown; any others wait, hidden, till it's put away
  {
    const PANELS = ['craft', 'map', 'story', 'almanac', 'letter', 'calendar', 'settlers', 'pack'].map((id) => document.getElementById(id)).filter(Boolean);
    let order = [];
    const sync = (recs = []) => {
      const open = PANELS.filter((el) => getComputedStyle(el).display !== 'none');
      order = order.filter((el) => open.includes(el));
      for (const r of recs) if (open.includes(r.target) && !order.includes(r.target)) order.push(r.target); // in the order they opened
      for (const el of open) if (!order.includes(el)) order.push(el);
      order.forEach((el, i) => el.toggleAttribute('data-waiting', i < order.length - 1));
      document.body.classList.toggle('panel-open', order.length > 0);
    };
    const mo = new MutationObserver(sync);
    for (const el of PANELS) mo.observe(el, { attributes: true, attributeFilter: ['class', 'style'] });
  }
  // the gold pan, held out in front while you swirl it
  const panMesh = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.22, 0.08, 14, 1, true), new THREE.MeshLambertNodeMaterial({ color: 0x8a8e90, side: THREE.DoubleSide }));
  panMesh.position.set(0, -0.08, 0.32); panMesh.visible = false; player.avatar.fig.hands[1].add(panMesh);
  // the opening: a new game starts with a glint of gold in the gravel a few steps from the cabin, so the very first
  // thing you do is pick up a nugget and learn what this country is about
  let openingDone = !!saved?.opening || !!(saved && (saved.fortune || saved.inventory?.gold)), glint = null, glintT = 0, glintTold = false;
  if (!openingDone) {
    const gx = home.spawn.x + town.along.x * 3.2 + town.toward.x * 1.2, gz = home.spawn.z + town.along.z * 3.2 + town.toward.z * 1.2;
    glint = new THREE.Group(); glint.position.set(gx, getHeight(gx, gz), gz);
    const gold = new THREE.MeshLambertNodeMaterial({ color: 0xf0c840, emissive: 0x5a3c00 });
    for (const [x, z, r] of [[0, 0, 0.13], [0.16, 0.06, 0.07], [-0.1, 0.12, 0.06]]) { const m = new THREE.Mesh(new THREE.DodecahedronGeometry(r, 0), gold); m.position.set(x, r * 0.6, z); m.scale.y = 0.6; m.rotation.set(x * 5, z * 7, 0.3); m.castShadow = true; glint.add(m); }
    scene.add(glint);
  }
  const fortuneEl = document.getElementById('fortune');
  // on the model horse, the rider sits on its back: his hips over the middle of its spine (between the hips and chest
  // bones), raised to the top of the back; returns false for the paper horse or the paper farmer
  const _sa = new THREE.Vector3(), _sb = new THREE.Vector3(), _sr = new THREE.Vector3(), _sq = new THREE.Quaternion();
  function seatRider() {
    const A = player.avatar, hm = horse?.model, rm = A.fig?.model;
    if (!hm || !rm) return false;
    horse.seatBones ||= ['hips', 'chest'].map((n) => hm.getObjectByName(n));
    A.fig.root.updateWorldMatrix(true, false); A.fig.root.getWorldQuaternion(_sq);
    _sb.set(0, 0, 1).applyQuaternion(_sq); horse.heading = horse.flip.rotation.y = Math.atan2(_sb.x, _sb.z) - Math.PI / 2; // (the puppet heading is a quarter-turn off its travel)
    A.hipBone ||= rm.getObjectByName('Hips');
    if (!horse.seatBones[0] || !horse.seatBones[1] || !A.hipBone) return false;
    horse.group.updateWorldMatrix(true, true); A.root.updateWorldMatrix(true, true);
    if (horse.saddle?.visible) _sa.set(0, 0.5 * horse.saddle.scale.y, 0).applyQuaternion(horse.saddle.quaternion).add(horse.saddle.position); // (his hips a hand above the saddle's seat)
    else { horse.seatBones[0].getWorldPosition(_sa); horse.seatBones[1].getWorldPosition(_sb); _sa.lerp(_sb, 0.55); _sa.y += 0.32 * horse.rig.scale.x / 1.7; } // (from the spine up to the top of the back)
    A.hipBone.getWorldPosition(_sr);
    A.root.position.x += _sa.x - _sr.x; A.root.position.y += _sa.y - _sr.y; A.root.position.z += _sa.z - _sr.z;
    return true;
  }
  function makeHorse(x, z) { horse = new Puppet('horse', animalModel('animal_horse') ? 1.7 : 1.25); /* (the model horse stands taller: a horse for a big man) */ horse.group.position.set(x, getHeight(x, z), z); scene.add(horse.group);
    if (horse.model) { horse.saddle = makeSaddle(); horse.saddle.scale.setScalar(horse.rig.scale.x / 1.7); scene.add(horse.saddle); } }
  if (horseSaved.owned) makeHorse(horseSaved.x, horseSaved.z);
  const homewardEl = document.getElementById('homeward');
  const HOME_ICON = '<svg viewBox="0 0 24 24"><path d="M3 12 L12 4 L21 12 L18 12 L18 20 L6 20 L6 12 Z" fill="#a8352a" stroke="#4a3426" stroke-width="1.6" stroke-linejoin="round"/></svg>';
  const GOLD_ICON = '<svg viewBox="0 0 24 24"><path d="M3 18 C5 11 9 8 12 8 C15 8 19 11 21 18 Z" fill="#d8a830" stroke="#7a5a14" stroke-width="1.5"/><circle cx="9" cy="14" r="1.4" fill="#ffe08a"/><circle cx="14" cy="12" r="1.2" fill="#ffe08a"/></svg>';
  homewardEl.innerHTML = '<span class="ico"></span>'
    + '<svg class="arrow" viewBox="-12 -12 24 24"><path d="M0-10 L7 3 L2 1.5 L2 10 L-2 10 L-2 1.5 L-7 3 Z" fill="#b5523b" stroke="#4a3426" stroke-width="1.4" stroke-linejoin="round"/></svg><span></span>';
  const homewardArrow = homewardEl.children[1], homewardText = homewardEl.children[2];
  let homewardSig = '', homewardDeg = null, homewardIcon = '';
  const _ha = new THREE.Vector3(), _hb = new THREE.Vector3();
  // NEXT: one short line saying the most useful thing to do now, in a few words. Hunger first, then the gold road:
  // workbench -> pickaxe -> iron ore -> forge -> iron -> iron pickaxe -> gold quartz, with the assayer between
  const nextEl = document.getElementById('next'), nextText = nextEl.querySelector('span');
  const FOODS = ['johnnycake', 'applepie', 'honeycake', 'roast', 'pie', 'applecrisp', 'flapjacks', 'stew', 'biscuits', 'bread', 'fishfry', 'cornbread', 'apples', 'berries'];
  let nextT = 0, nextSig = '';
  function updateNext(dt) {
    if ((nextT -= dt) > 0) return; nextT = 0.5;
    const has = (t) => build.pieces.some((p) => p.type === t), I = inventory;
    const iron = tools.has('ironpick') || tools.has('steelpick');
    let say = '', urgent = false, mend = null;
    if (player.fullness < 25) { urgent = true; say = FOODS.some((k) => I[k] > 0) ? 'Hungry! Press F to eat' : cellar.stocked(sky.day) ? 'Hungry! Get food from the root cellar' : 'Hungry! Pick berries or apples'; }
    else if (glint) say = 'Pick up the gold glint by the cabin (E)';
    else if ((I.gold > 0 || I.silver > 0) && !town.nearAssay(player.pos, 20)) say = I.gold > 0 ? 'Sell your gold at the assay office' : 'Sell your silver at the assay office';
    else if (!cellar.built && I.dollars >= CELLAR_COST) say = `Buy a root cellar by the house ($${CELLAR_COST})`;
    else if (cellar.built && !bunkhouse.built && settlers.hired.size && I.dollars >= BUNK_COST) say = `Build a bunkhouse for your hands ($${BUNK_COST})`;
    else if ((mend =town.projects().filter((p) => !town.tiers[p.id] && I.dollars >= p.cost).sort((p, q) => p.cost - q.cost)[0])) say = `Mend the ${mend.name} in town ($${mend.cost})`; // (the cheapest run-down building you can afford, on any open street)
    else if (!owns('pick') && !has('workbench')) say = 'Build a workbench (B)';
    else if (!owns('pick')) say = 'Make a pickaxe at the workbench (C)';
    else if (!iron && (I.iron || 0) >= 3) say = has('forge') ? 'Make an iron pickaxe at the forge (C)' : 'Build a forge (B): 10 stone, 6 clay';
    else if (!iron && (I.ore || 0) >= 2) say = has('forge') ? 'Smelt iron at the forge (C)' : 'Build a forge (B): 10 stone, 6 clay';
    else if (!iron) say = 'Find iron ore (rusty grey rocks), for an iron pickaxe';
    // with the gold road travelled, today's doings: the meeting, the fair, a barn dance, the fireworks
    else if (sky.day % 7 === 0 && town.tiers.church && sky.time < 0.45) say = 'Sunday meeting at the church this morning';
    else if (isFairDay(sky.day) && sky.time < 0.8) say = 'County Fair today, by the farm lane: enter your best';
    else if (sky.day % 7 === 6 && town.streetDone(-1) && town.streetDone(0) && town.streetDone(1) && sky.time > 0.6 && sky.time < 0.9) say = 'Fireworks over Paydirt Hollow tonight, after supper';
    else if (isDanceNight(sky.day) && sky.time > 0.6 && sky.time < 0.95) say = 'Barn dance tonight: follow the fiddle';
    else say = 'Mine gold quartz in the Redrock Breaks or Bluepine Highlands';
    const sig = say + urgent;
    if (sig !== nextSig) { nextSig = sig; nextText.textContent = say; nextEl.classList.toggle('urgent', urgent); nextEl.classList.toggle('off', !say); }
  }
  function updateHomeward() {
    // carrying gold: the chip points the way to the assayer instead (once you're out of sight of his door)
    const ad = town.doors.assay, toAssay = inventory.gold > 0 && Math.hypot(ad.x - player.pos.x, ad.z - player.pos.z) > 20;
    const goal = toAssay ? ad : home.spawn;
    const hx = goal.x - player.pos.x, hz = goal.z - player.pos.z, d = Math.hypot(hx, hz);
    const show = (toAssay || d > 90) && !player.dead;
    const icon = toAssay ? GOLD_ICON : HOME_ICON; if (icon !== homewardIcon) { homewardIcon = icon; homewardEl.children[0].innerHTML = icon; }
    homewardEl.classList.toggle('show', show);
    if (!show) return;
    _ha.copy(player.pos).project(camera);
    _hb.set(player.pos.x + (hx / d) * 4, player.pos.y, player.pos.z + (hz / d) * 4).project(camera);
    const deg = Math.round((Math.atan2(_hb.x - _ha.x, (_hb.y - _ha.y) / camera.aspect) * 180) / Math.PI);
    if (homewardDeg === null || Math.abs(deg - homewardDeg) > 2) { homewardDeg = deg; homewardArrow.style.transform = `rotate(${deg}deg)`; }
    const sig = `${toAssay ? `Assay office (${inventory.gold} pinch${inventory.gold > 1 ? 'es' : ''})` : 'Home'}, ${Math.round((d * 1.3) / 10) * 10} paces`;
    if (sig !== homewardSig) { homewardSig = sig; homewardText.textContent = sig; }
  }
  journal.render();
  critters.onHerd = () => hud.toast('A herd of bison grazing the high prairie, shaggy as old haystacks! Folks say they once ran so thick the ground shook for a day. Best not crowd them.');
  critters.onSpotted = () => journal.record('deer');
  // hunting: the bow looses an arrow at the deer you face; walk up to one you've brought down to dress it
  const hunting = new Hunting(scene);
  const guns = { revolver: { size: 6, loaded: 6, reload: 0, time: 2.4 }, rifle: { size: 1, loaded: 1, reload: 0, time: 1.6 } }; // (rounds in the gun; reload seconds)
  let huntTold = false;
  hunting.onThunk = () => sound.knock();
  hunting.onHit = (c) => { sound.land(); if (!huntTold) { huntTold = true; hud.toast(`A clean shot. The ${c.type} folds down in the grass: walk up to it to dress it.`); } };
  hunting.onWound = (c) => { sound.knock(); if (c.type === 'bison') hud.toast('The bull bellows and lumbers off, hit but still on his feet. It takes more than one shot to bring down a buffalo.'); };
  // the turkey flock's gobble, now and then from the woods when you're near them
  critters.onGobble = (d) => { if (sound.ready && !sound.muted) sound.gobble(Math.max(0.15, 1 - d / 35)); };
  critters.onDressed = (c) => {
    // a deer: 2 venison and, more often than not, a hide; a rabbit: a little meat and maybe a skin; a buffalo: a
    // great deal of meat and a robe (two hides)
    const T = c?.type === 'bison' ? { meat: 5, pelt: 2, name: 'buffalo' } : c?.type === 'rabbit' ? { meat: 1, pelt: Math.random() < 0.4 ? 1 : 0, name: 'rabbit' } : c?.type === 'turkey' ? { meat: 2, pelt: 0, name: 'wild turkey' } : { meat: 2, pelt: Math.random() < 0.6 ? 1 : 0, name: 'deer' };
    inventory.venison = (inventory.venison || 0) + T.meat; inventory.pelt = (inventory.pelt || 0) + T.pelt;
    settlers.discover?.('pelt'); sound.pick(); dayLog.deerTaken = (dayLog.deerTaken || 0) + 1;
    hud.toast(`You dress the ${T.name}: ${T.meat} ${c?.type === 'turkey' ? 'cuts of turkey (kept with your venison)' : 'venison'}${T.pelt ? (T.pelt > 1 ? ' and a buffalo robe (2 pelts)' : ' and a hide (pelt)') : ''}. Roast the meat at a campfire.`); saveAll();
  };
  hud.setInventory(inventory);

  // crafting panel (frees the mouse while open)
  const panel = new CraftingPanel(document.getElementById('craft'), {
    inventory, tools,
    stationNear: (st) => (st.startsWith?.('post-') ? railroad.postAt(player.pos.x, player.pos.z, 4)?.land === st.slice(5) : st === 'depot' ? railroad.built && !!railroad.freightAt && Math.hypot(player.pos.x - railroad.freightAt.x, player.pos.z - railroad.freightAt.z) < 4 : st === 'camp' ? !!camp.fireAt(player.pos.x, player.pos.z, 6) : st === 'cooper' ? !!town.tiers.cooper && Math.hypot(player.pos.x - town.doors.cooper.x, player.pos.z - town.doors.cooper.z) < 3.2 : st === 'drygoods' ? !!town.tiers.drygoods && Math.hypot(player.pos.x - town.doors.drygoods.x, player.pos.z - town.doors.drygoods.z) < 3.2 : st === 'feed' ? !!town.tiers.feed && Math.hypot(player.pos.x - town.doors.feed.x, player.pos.z - town.doors.feed.z) < 3.2 : st === 'bank' ? !!town.tiers.bank && Math.hypot(player.pos.x - town.doors.bank.x, player.pos.z - town.doors.bank.z) < 3.2 : st === 'bakery' ? !!town.tiers.bakery && Math.hypot(player.pos.x - town.doors.bakery.x, player.pos.z - town.doors.bakery.z) < 3.2 : st === 'smithy' ? !!atTownDoor('smithy', player.pos) : st === 'store' ? !!town.tiers.store && Math.hypot(player.pos.x - town.doors.store.x, player.pos.z - town.doors.store.z) < 3.2 : st === 'tinker' ? tinker.near(player.pos) : st === 'fair' ? fair.near(player.pos, 3.2) : build.stationNear(st, player.pos)),
    onCraft(r) {
      if (r.station === 'depot') railroad.addFreight(); // (a crate on the platform for the next train)
      if (r.id === 'iron' && settlers.discover('iron')) hud.toast('Your first iron! Now you can build a charcoal pit (B, Works shelf), and with charcoal, smelt steel.');
      if (r.wire) { hud.toast(`The keeper reads the telegram twice, counts your goods and pays out $${r.pay}. "That's a load off. Much obliged, neighbor."`); saveAll(); return; }
      if (r.fair) { fair.showRibbons(inventory.ribbon); journal.record('ribbon'); sound.lullaby(); hud.toast(`Mrs. Pruitt tastes, pokes and peers, and pins a blue ribbon on your entry. (${r.name})`); saveAll(); return; }
      if (r.sharpen) { for (const k in wear) wear[k] = 100; dullWarned = false; }
      if (r.request) journal.record('request'); hud.toast(r.request ? 'The tinker beams and pays you well for it. "Much obliged, neighbor!"' : r.sharpen ? 'Skrrrr... the smith works every edge on his wheel. Sharp as new.' : r.station === 'smithy' ? `The smith hands over a ${r.name.toLowerCase()}, still warm from the quench.` : r.station === 'store' ? `Bought: ${r.name.toLowerCase()}` : r.gives ? `Traded with the tinker: ${r.name.toLowerCase()}` : `Crafted ${r.name.toLowerCase()}`); sound.craft(); journal.record(`craft:${r.id}`); saveAll(); },
  });
  panel.fairEntered = (id) => fair.entered.has(id);
  panel.onFairEntry = (id) => fair.entered.add(id);
  panel.fairToday = () => fair.open(sky);
  panel.storeOpen = () => !!town.tiers.store; // the general store sells once it's mended
  panel.campOpen = () => !!camp.fireAt(player.pos.x, player.pos.z, 6); // (trading at a camp fire, while at peace there)
  panel.depotOpen = () => railroad.built && !!railroad.freightAt && Math.hypot(player.pos.x - railroad.freightAt.x, player.pos.z - railroad.freightAt.z) < 4; // the depot's freight office, by its platform
  panel.postOpen = () => railroad.postAt(player.pos.x, player.pos.z, 4); // a whistle-stop's trading post, at its door
  panel.cooperOpen = () => !!town.tiers.cooper; // the cooperage, once it's mended
  panel.drygoodsOpen = () => !!town.tiers.drygoods; // the dry goods, once it's mended
  panel.feedOpen = () => !!town.tiers.feed; // the feed & grain, once it's mended
  panel.bankOpen = () => !!town.tiers.bank; // the Miners' bank, once it's mended
  panel.bakeryOpen = () => !!town.tiers.bakery; // the Second Street bakery, once it's mended
  panel.smithyOpen = () => !!town.tiers.smithy; // and the blacksmith forges once his shop is
  fair.showRibbons(inventory.ribbon || 0);
  let harvestToldDay = 0, fairToldDay = 0, danceT = 0, danceToldDay = 0, ciderT = 0;
  dance.onNote = (f, d, v) => sound.fiddle(f, d, v);
  // the daily stage coming in: the guard blows his horn, heard across town (and a word, if you're about)
  town.onStage = () => {
    const d = Math.hypot(player.pos.x - town.at.x, player.pos.z - town.at.z);
    if (d < 120) { if (sound.ready && !sound.muted) sound.horn(Math.max(0.2, 1 - d / 120)); if (d < 60) hud.toast('A horn sounds down the lane: the Overland stage is rattling into Paydirt Hollow, and will wait by the boarding house till afternoon.'); }
  };
  town.onNote = (f, d, v) => sound.fiddle(f, d, v); // (the dance hall's fiddler, of an evening)
  // the almanac card (H): this week at a glance, and what's ready around the farm today
  const calendar = document.getElementById('calendar');
  let calT = 0;
  const renderCalendar = () => {
    const d0 = sky.day;
    const week = Array.from({ length: 7 }, (_, i) => {
      const d = d0 + i, bits = [];
      if (d % 7 === 0) bits.push('<span class="fair">County Fair</span>');
      if (isDanceNight(d)) bits.push('<span class="dance">Barn dance</span>');
      if (d % 2 === 0) bits.push('<span class="tink">Tinker</span>');
      if (d % 7 === 0 && town.tiers.church) bits.push('<span class="town">Sunday meeting</span>'); // (the town's own doings, once there's a town for them)
      if (d % 7 === 6 && town.streetDone(-1) && town.streetDone(0) && town.streetDone(1)) bits.push('<span class="fw">Fireworks</span>');
      if (!bits.length) bits.push('<span>&nbsp;</span>');
      return `<div class="day ${i === 0 ? 'today' : ''}"><b>${i === 0 ? 'Today' : 'Day ' + d}</b>${bits.join('')}</div>`;
    }).join('');
    const herd = critters.list.filter((c) => c.type === 'cow' || c.type === 'sheep');
    const cows = herd.filter((c) => c.type === 'cow'), sheep = herd.filter((c) => c.type === 'sheep');
    const toMilk = cows.filter((c) => c.milkedDay !== d0).length, toShear = sheep.filter((c) => !(c.shornDay && d0 - c.shornDay < 2)).length;
    const honey = build.pieces.filter((p) => p.type === 'skep').reduce((s, p) => s + (p.stock || 0), 0);
    const apples = build.pieces.filter((p) => p.type === 'homeapple').reduce((s, p) => s + (p.stock || 0), 0);
    const req = requestState();
    const daysToFair = (7 - (d0 % 7)) % 7;
    let daysToDance = 0; while (!isDanceNight(d0 + daysToDance)) daysToDance++;
    const notes = [
      coop.eggs ? `${coop.eggs} egg${coop.eggs > 1 ? 's' : ''} waiting in the nesting box` : 'No eggs till the hens lay again tomorrow morning',
      cows.length ? (toMilk ? `${toMilk} cow${toMilk > 1 ? 's' : ''} to milk` : 'The cows are milked') + (sheep.length ? ` · ${toShear ? `${toShear} sheep ready to shear` : 'the sheep are shorn'}` : '') : null,
      mail.waiting ? 'The red flag is up: a letter in the mailbox' : d0 >= 1 ? 'The mail carrier comes by mid-morning' : null,
      honey ? `${honey} comb${honey > 1 ? 's' : ''} of honey in your skeps` : null,
      apples ? `${apples} ripe apple${apples > 1 ? 's' : ''} on your own trees` : null,
      orderState() && !orderState().done ? `Telegram at the depot: ${orderState().name.toLowerCase()} wanted at the ${orderState().where} trading post by day ${orderState().due} ($${orderState().pay})` : null,
      tinker.visiting(sky) ? `The tinker's wagon is on Main Street in Paydirt Hollow${req && !req.done ? ' (he has a special request)' : ''}` : null,
      grandma.wishDay !== d0 ? `Grandma could use ${wishFor(d0).ask} (knock of an evening)` : null,
      calf.state === 'lost' || calf.state === 'follow' ? 'Daisy’s calf is lost out in the meadows: listen for it bawling' : null,
      (d0 + 1) % 7 === 0 ? 'Tonight the harvest moon rises: whatever you gather after dark comes in one extra' : null,
      dance.live(sky) ? 'The barn dance is on in the street before the livery barn, till three in the morning' : daysToDance === 0 ? 'Barn dance tonight, from half past five till three, in the street before the livery barn' : `The next barn dance is ${daysToDance === 1 ? 'tomorrow night' : `in ${daysToDance} days`} (5:30 pm till 3 am)`,
      fair.open(sky) ? "It's County Fair day: Mrs. Pruitt is judging south of the lane" : `The County Fair is ${daysToFair === 1 ? 'tomorrow' : `in ${daysToFair} days`}`,
      weather.target === 0 && weather.next < 45 ? `The barn rooster has swung east: ${weather.nextKind === 'snow' ? 'snow' : 'rain'} on the way` : null,
      fallingStars.state === 'landed' ? 'A fallen star is glowing somewhere out in the grass' : null,
    ].filter(Boolean);
    calendar.innerHTML = `<h2>The Farmer's Almanac · ${sky.clockText()}</h2><div class="week">${week}</div><ul>${notes.map((n) => `<li>${n}</li>`).join('')}</ul><small>${inventory.ribbon || 0} ribbon${inventory.ribbon === 1 ? '' : 's'} won at the fair · H to fold it away</small>`;
  };
  const openCraft = () => { panel.setOpen(true); input.unlock(); };
  const closeCraft = () => {
    panel.setOpen(false);
    input.lock();
    // if the browser refused the lock (no user gesture), fall back to the pause card
    setTimeout(() => { if (!input.locked && !panel.open) overlay.classList.remove('hidden'); }, 300);
  };
  panel.onClose = closeCraft;

  // build bar
  const buildbar = document.getElementById('buildbar');
  const buildhint = document.getElementById('buildhint');
  let barSig = '';
  function renderBuildBar() {
    const sig = `${build.selected}|${JSON.stringify(inventory)}`;
    if (sig === barSig) return;
    barSig = sig;
    // only the current shelf's pieces, with the four shelves named above them
    const cur = PIECE_ORDER[build.selected];
    const gi = PIECE_GROUPS.findIndex(([, list]) => list.includes(cur));
    const tabs = PIECE_GROUPS.map(([name], i) => `<span class="shelf ${i === gi ? 'on' : ''}">${i + 1} ${name}</span>`).join('');
    buildbar.innerHTML = `<div class="shelves">${tabs}</div>` + PIECE_GROUPS[gi][1].map((t) => {
      const p = PIECES[t];
      const poor = Object.entries(p.cost).some(([k, v]) => (inventory[k] || 0) < v);
      return `<div class="piece ${t === cur ? 'sel' : ''} ${poor ? 'poor' : ''}">${p.name}<small>${costHTML(p.cost, inventory)}</small></div>`;
    }).join('');
  }
  // the tool bar: hands, axe, pickaxe, spear, fishing pole; the ones you haven't made yet are greyed
  const NO_TOOLS = new Set();
  const _hq = new THREE.Quaternion(), _hf = new THREE.Vector3(), _hp = new THREE.Vector3();
  const owns = (id) => id === 'hands' || id === 'axe' || (id === 'pick' ? tools.has('pickaxe') || tools.has('ironpick') || tools.has('steelpick') : tools.has(id));
  function pickTool(id) {
    if (!owns(id)) { hud.toast(id === 'pick' ? 'No pickaxe yet: make one at a workbench (C).' : id === 'spear' ? 'No spear yet: whittle an ash spear at a workbench (C).' : id === 'bow' ? 'No bow yet: make a hunting bow at a workbench (C).' : id === 'revolver' ? 'No six-shooter yet: the general store sells one, once it is mended.' : id === 'rifle' ? 'No rifle yet: the general store sells one, once it is mended.' : 'No fishing pole yet: make a willow pole at a workbench (C).'); sound.denied(); return; }
    if (held !== id) { held = id; sound.click(); }
  }
  // tool wear: each blow dulls the tool in hand a little (better metal holds its edge longer); a dull tool hits at
  // half strength until it's sharpened on the grindstone at a workbench or forge (E, 1 stone)
  const WEAR_PER_HIT = () => held === 'axe' ? (tools.has('steelaxe') ? 0.35 : tools.has('ironaxe') ? 0.6 : tools.has('stoneaxe') ? 1 : 1.25)
    : held === 'pick' ? (tools.has('steelpick') ? 0.35 : tools.has('ironpick') ? 0.6 : 1) : held === 'spear' ? 0.8 : 0;
  let dullWarned = false;
  function edge(type) {
    const d = damageFor(type, tools, held);
    return d > 0 && wear[held] !== undefined && wear[held] <= 0 ? Math.max(1, Math.floor(d / 2)) : d;
  }
  function blow() {
    if (wear[held] === undefined) return;
    const was = wear[held];
    wear[held] = Math.max(0, wear[held] - WEAR_PER_HIT());
    if (was > 0 && wear[held] <= 0 && !dullWarned) { dullWarned = true; hud.toast(`Your ${held === 'axe' ? 'axe' : held === 'pick' ? 'pickaxe' : 'spear'} has gone dull: it bites at half strength now. Sharpen it on the grindstone at a workbench or forge (E, 1 stone).`); }
  }
  function wrongTool(type) {
    const want = toolFor(type), name = RESOURCE_TYPES[type].name.toLowerCase();
    if (want === 'pick' && (type === 'quartz' || type === 'silver') && !tools.has('ironpick') && !tools.has('steelpick')) return 'Too hard! Needs an IRON pickaxe';
    if (want === 'pick') return owns('pick') ? `That ${name} wants the pickaxe: press 3` : `Your tools just bounce off the ${name}. Make a pickaxe at a workbench (C).`;
    return `You'll want the axe for the ${name}: press 2`;
  }
  document.getElementById('toolbar').addEventListener('click', (e) => { const b = e.target.closest('[data-t]'); if (b) { e.stopPropagation(); pickTool(b.dataset.t); } });

  function setBuilding(on) {
    build.active = on;
    document.body.classList.toggle('building', on);
    player.avatar.tool = on ? 'hammer' : 'axe';
  }

  world.regrowBlocked = (r) => build.pieces.some((p) => (p.x - r.x) ** 2 + (p.z - r.z) ** 2 < 6.25) || (ROAD_TREES.has(r.type) && onRoad(r));
  world.onResourceGone = (res, fell) => {
    const def = RESOURCE_TYPES[res.type];
    const p = fell ? _v.set(res.x, res.y + 0.5, res.z) : _v.set(res.x, res.y + 0.6 * res.scale, res.z);
    confetti.burst(p, def.chips, fell ? 46 : 32, 1.1);
    if (!fell && res.type === 'rock') sound.tear();
  };

  overlay.addEventListener('click', () => input.lock());
  // New game: wipe the save (builds, inventory, tools) and start over on a fresh page
  document.getElementById('newgame').addEventListener('click', (e) => {
    e.stopPropagation();
    if (!confirm('Start a new game? Your builds, items and tools will be lost.')) return;
    build.save = () => {}; // don't let the running game write the old state back
    try { localStorage.removeItem('paperfjord.builds.v1'); } catch { /* storage unavailable */ }
    location.reload();
  });
  renderer.domElement.addEventListener('click', () => { if (!input.locked && !panel.open) input.lock(); });
  let lockChangedAt = 0;
  const peek = document.getElementById('peek');
  input.onLockChange = (locked) => {
    lockChangedAt = performance.now();
    overlay.classList.toggle('hidden', locked || panel.open);
    peek.classList.remove('show');
    overlay.querySelector('.cta').textContent = 'Click to resume';
  };
  // Escape folds the controls card away (the browser won't hand the mouse back on a key press, so the farm
  // shows paused with a small note, and a click carries on); Escape again brings the card back
  addEventListener('keydown', (e) => {
    if (e.code !== 'Escape' || input.locked || panel.open || performance.now() - lockChangedAt < 400) return;
    const showing = !overlay.classList.contains('hidden');
    overlay.classList.toggle('hidden', showing);
    peek.classList.toggle('show', showing);
  });

  // Size is checked every frame: the page can start in a hidden/zero-sized view.
  const size = new THREE.Vector2();
  function fitToWindow() {
    if (innerWidth === 0 || innerHeight === 0) return false;
    renderer.getSize(size);
    if (size.x !== innerWidth || size.y !== innerHeight) {
      camera.aspect = innerWidth / innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(innerWidth, innerHeight);
    }
    return true;
  }

  // guardians spawn with their sites as chunks load, so they must exist before the first chunks do
  const enemies = new Enemies(scene, world);
  enemies.calmBySite = { ...(saved?.calm || {}) }; enemiesRef = enemies; // dozing guardians stay dozing across a reload
  let deathTimer = 0, sleepTimer = 0, autosaveT = 0;
  addEventListener('pagehide', () => saveAll());
  document.addEventListener('visibilitychange', () => { if (document.hidden) saveAll(); });
  const fishing = new Fishing(scene);
  let jumpTold = false;
  fishing.onJump = () => { sound.plop(); if (!jumpTold && tools.has('rod')) { jumpTold = true; hud.toast('A fish jumped! Cast near the rings and they bite sooner.'); } };
  fishing.camera = camera;
  // footprints: in lying snow the farmer leaves a trail of boot prints (a ring of 80 flat ovals), gone as it melts
  const PRINTS = 80;
  const bootGeo = mergeGeometries([
    new THREE.CircleGeometry(1, 12).scale(0.1, 0.15, 1).translate(0, 0.07, 0), // sole
    new THREE.CircleGeometry(1, 10).scale(0.075, 0.07, 1).translate(0, -0.15, 0), // heel
  ]).rotateX(-Math.PI / 2);
  // a cool lilac-blue hollow, the way shadows sit in snow
  const prints = new THREE.InstancedMesh(bootGeo, new THREE.MeshBasicNodeMaterial({ color: 0x8f97ad, transparent: true, opacity: 0.75, depthWrite: false }), PRINTS);
  prints.frustumCulled = false; prints.count = PRINTS; prints.visible = false; prints.renderOrder = 1;
  const _pm = new THREE.Matrix4(), _pq = new THREE.Quaternion(), _ps = new THREE.Vector3(), _pp = new THREE.Vector3(), _pUp = new THREE.Vector3(0, 1, 0);
  for (let i = 0; i < PRINTS; i++) { _pm.makeScale(0, 0, 0); prints.setMatrixAt(i, _pm); }
  scene.add(prints);
  // skate tracks: thin pale scratches the blades leave on pond ice, a ring of 160, gone when it thaws
  const TRACKS = 240;
  const tracks = new THREE.InstancedMesh(new THREE.PlaneGeometry(0.035, 0.55).rotateX(-Math.PI / 2), new THREE.MeshBasicNodeMaterial({ color: 0xf3f6f4, transparent: true, opacity: 0.7, depthWrite: false }), TRACKS);
  tracks.frustumCulled = false; tracks.renderOrder = 1; tracks.visible = false;
  for (let i = 0; i < TRACKS; i++) { _pm.makeScale(0, 0, 0); tracks.setMatrixAt(i, _pm); }
  scene.add(tracks);
  let trackNext = 0, trackDist = 0, skateT = 0;
  const lastTrack = new THREE.Vector3();
  let printNext = 0, printSide = 1;
  // bees: a few dark specks looping lazily around each nearby skep (one instanced mesh, by day only)
  const beeMesh = new THREE.InstancedMesh(new THREE.SphereGeometry(0.035, 6, 4).scale(1.4, 1, 1), new THREE.MeshBasicNodeMaterial({ color: 0x2b2018 }), 30);
  beeMesh.frustumCulled = false; beeMesh.count = 0; scene.add(beeMesh);
  const _bm = new THREE.Matrix4();
  // settlers and works: folk who join the farm and run a work, filling the storehouse a little at a time
  const settlers = new Settlers(scene, center);
  settlers.town = town; // the folk live in town now, not camped in your yard
  settlers.bunk = bunkhouse; // (till you build them a bunkhouse on the farm)
  // newcomers taking rooms at the mended boarding house: one note for them all
  let newcomers = [], newcomerNews = false; // (only announced when you mend it, not every time a save loads)
  settlers.onNewcomer = (s) => { if (newcomerNews) newcomers.push(s); };
  // once someone joins, say plainly where they'll go (or what they're waiting for), a beat after their own line
  settlers.onJoin = (s) => setTimeout(() => {
    const first = s.S.name.split(' ')[0], work = WORK_NAME[s.S.work];
    const built = build.pieces.some((p) => p.type === s.S.work), store = build.pieces.some((p) => p.type === 'storehouse');
    if (!built) hud.toast(`${first} will wait by the camp fire till you build a ${work} (B, then the Works shelf). The moment it stands, ${first} walks over and gets to work.`);
    else if (sky.night >= 0.45) hud.toast(`${first} will set off for your ${work} at first light.`);
    else hud.toast(`${first} sets off for your ${work}.${store ? '' : " (Build a storehouse too, or there's nowhere to bring what gets made.)"}`);
  }, 1800);
  settlers.load(saved?.settlers); settlersRef = settlers;
  if (savedFullness !== null) player.fullness = savedFullness;
  for (const k of ['wood', 'stone', 'fish', 'clay', 'ore', 'honey', 'wheat', 'sap', 'pelt', 'iron']) if ((inventory[k] || 0) > 0) settlers.discover(k); // you've plainly gathered these already
  build.discovered = settlers.discovered;
  // folk arriving: one at a time, a note introducing them; several at once (a new storehouse), a single note
  let arrivals = [];
  settlers.onArrive = (s) => arrivals.push(s);
  const announceArrivals = () => {
    if (!arrivals.length) return;
    if (arrivals.length === 1) { const s = arrivals[0]; hud.toast(`${s.S.name}, ${s.S.pitch}, has made camp at the edge of the farm. ${s.S.ask}`); }
    else hud.toast(`Word of your storehouse has got round: ${arrivals.length} folk looking for work have made camp at the edge of the farm. Go and meet them, or press J to see who's who.`);
    arrivals = [];
  };
  const settlersCard = document.getElementById('settlers');
  const renderSettlers = () => {
    const rows = settlers.rows(build.pieces).map((r) => `<li><b>${r.name}</b> <i>(${r.trade})</i><br>${r.status}</li>`).join('');
    const stock = settlers.stockText();
    const storeLine = build.pieces.some((p) => p.type === 'storehouse') ? (stock ? `In the storehouse: ${stock}` : 'The storehouse is empty for now.') : 'No storehouse yet: build one (B, Works shelf) and folk will come looking for work.';
    settlersCard.innerHTML = `<h2>Settlers &amp; works</h2><p class="sum">${storeLine}<br>${settlers.larderText()}. Each settler eats a ration every morning (R at the storehouse to stock it); without one they work at half pace.</p><ul>${rows}</ul><small>J to fold it away</small>`;
  };
  const eagle = new Eagle(scene); // a bald eagle soaring over the high country
  const beaver = new Beaver(scene); // swims round its lodge on the nearest pond
  beaver.onSlap = () => { sound.plop(); setTimeout(() => sound.plop(), 120); };
  const geese = new Geese(scene); // a skein of Canada geese going over in a V now and then by day
  geese.onHonk = () => sound.honk();
  geese.onFirst = () => hud.toast('Honk-honk! A skein of Canada geese goes over in a V, headed south. Folks say an early flight means an early frost.');
  const crows = new Crows(scene);
  let crowsWarned = false;
  crows.onCaw = () => sound.caw();
  crows.onLand = () => { sound.caw(); if (!crowsWarned) { crowsWarned = true; hud.toast('Crows in the corn! Shoo them off, or build a scarecrow (B).'); } };
  crows.onScatter = () => { sound.caw(); hud.toast('The crows scatter, cawing indignantly.'); journal.record('shoo'); };
  crows.onSteal = (r) => world.hit(r, r.x, r.z, 99);
  const weather = new Weather(scene);
  tinker.onArrive = () => { const q = newRequest(sky.day, saved?.request); if (q.done) return; hud.toast(`A tinker's wagon rattles into Paydirt Hollow and draws up at the head of Main Street. He has a request today: ${q.name.replace('Request: ', '').toLowerCase()}.`); };
  tinker.onLeave = () => hud.toast('The tinker tips his hat and rattles off out of Paydirt Hollow.');
  weather.onStart = () => hud.toast(weather.kind === 'snow' ? 'Snow! Fat paper flakes come drifting down over the county.' : weather.storm ? 'Thunder grumbles off to the east and the sky goes dark as a stovepipe. A summer storm! Best get under a roof.' : 'Clouds roll in and a soft rain begins. The garden and the fish love it.');
  storm.onThunder = (v) => sound.thunder(v);
  const rainbow = new Rainbow(scene);
  // Old Blue, the farm hound, trots along at the farmer's heels
  const butterflies = new Butterflies(scene);
  const dog = new Dog(scene, home.spawn);
  const cat = new Cat(scene, center, porch); // Marmalade, the barn cat
  cat.onPurr = () => sound.purr();
  let trackTold = -1;
  dog.onTrack = () => { if (trackTold !== sky.day) { trackTold = sky.day; hud.toast('Old Blue has the calf’s scent! He bounds off a way and barks back at you: follow where he points.'); } };
  let fetches = 0;
  dog.onFetched = () => { journal.record('fetch'); if (++fetches % 3 === 1) hud.toast(['Old Blue gallops back and drops the stick at your feet. Again! Again!', 'Back he comes, ears flying, stick held high like a prize.', 'He drops it, sits, and stares at the stick. Then at you. Then at the stick.'][Math.floor(Math.random() * 3)]); };
  dogRef = dog;
  dog.onBark = () => sound.woof();
  dog.foundDay = saved?.dogDay || 0; // he's already been digging today, if the save says so
  dog.onDig = (at) => confetti.burst(_v.set(at.x, at.y + 0.2, at.z), [0x8a6040, 0x6b4a30, 0xb08a5a], 22, 0.7);
  // what Old Blue digs up (once a day): mostly useful, sometimes just a treasure to him
  dog.onFind = () => {
    const FINDS = [
      [{ iron: 1 }, 'an old horseshoe, rusty but good iron'], [{ rope: 1 }, "a coil of somebody's lost rope"],
      [{ honey: 1 }, 'a jar of honey, lid still on. Nobody asks where from'], [{ mushrooms: 2 }, 'a mouthful of toadstools, a little chewed'],
      [{ pelt: 1 }, 'an old fur cap. It might make a pelt'], [{}, 'a very fine stick. He is extremely proud of it'],
    ];
    const [gift, text] = FINDS[Math.floor(Math.random() * FINDS.length)];
    for (const k in gift) inventory[k] = (inventory[k] || 0) + gift[k];
    journal.record('dogfind'); sound.woof();
    hud.toast(`Old Blue trots back and drops ${text} at your feet.`);
    saveAll();
  };
  weather.onEnd = () => {
    hud.toast(weather.kind === 'snow' ? 'The snow stops. The whole farm is tucked under a white quilt.' : 'The rain eases off; everything smells of wet pine and paper.');
    // after a daytime shower, a rainbow stands up out of the far fields
    if (weather.kind === 'rain' && sky.night < 0.25) { rainbow.show(player, sky.sunDir); setTimeout(() => hud.toast('Look: a rainbow, standing up out of the far fields like a page in a pop-up book.'), 2500); }
  };
  fishing.onCast = () => { player.avatar.startCast(); sound.splash(); };
  fishing.onBite = () => sound.bite();
  fishing.onMiss = () => hud.toast('It nibbled the bait and swam off…');
  fishing.onCatch = (name, legend) => {
    if (legend) {
      inventory.whiskers = (inventory.whiskers || 0) + 1; inventory.fish += 4;
      journal.record('legendfish');
      hud.toast('The line goes taut, the pole bends double… and up comes OLD WHISKERS, the catfish of the tallest tale! (+4 fish, and a trophy to mount: B)');
      sound.craft(); saveAll();
      return;
    }
    inventory.fish += 1;
    if (settlers.discover('fish')) hud.toast('Your first fish! Now you can build a fish weir (B, Works shelf) for a settler to run.');
    journal.record('gather:fish');
    hud.toast(`You land ${name}! (+1 fish)`);
    sound.pick();
    saveAll();
  };
  const sleepEl = document.getElementById('sleep');
  // the wild lands' landmarks come and go with their chunks (the guardians' sites carry them along)
  { const onLoad = world.onSiteLoad, onUnload = world.onSiteUnload;
    world.onSiteLoad = (s) => (s.kind === 'landmark' ? landmarks.spawn(s) : onLoad(s));
    world.onSiteUnload = (s) => (s.kind === 'landmark' ? landmarks.despawn(s) : onUnload(s)); }
  enemies.onWindup = () => sound.growl();
  // the wild lands' keepers spring out of hiding; the first time you meet each, a line from the old tales
  const metKeepers = new Set();
  enemies.onAmbush = (e) => {
    sound.growl(); sound.tear?.();
    if (!metKeepers.has(e.kind)) { metKeepers.add(e.kind); hud.toast(KEEPER_LORE[e.kind] || `The ${e.spec.name.toLowerCase()} springs up out of nowhere!`); }
  };
  enemies.onPlayerHit = (dmg, e) => {
    const knockedOut = player.hurt(dmg, tools.has('coat') ? 0.33 : 0);
    hud.hurt();
    sound.knock();
    if (knockedOut) {
      deathTimer = 3;
      hud.toast(`The ${e.spec.name.toLowerCase()} has the better of you…`);
    }
  };
  // the people of the valleys: a camp whose land is marked with painted poles; trespass and their warriors warn you
  // off, then fight you off, and let you go once you're back over the poles
  const camp = new NativeCamps(scene, center, world); // (three camps, each in a valley of its own, in a clearing)
  camp.load(saved?.campPeace); // (days of peace bought with gifts)
  if (saved?.railroad?.built) { railroad.build(); for (let i = 0; i < (saved.railroad.freight || 0); i++) railroad.addFreight(); if (saved.wire) newOrder(sky.day, saved.wire); } claim.dugDay = saved?.claimDay ?? -1; if (saved?.claim) { claim.stock = saved.claim.stock || claim.stock; claim.handDay = saved.claim.handDay ?? -1; } // (the line, if the town had earned it, and any telegraph order standing)
  const campHooks = {
    onWarn: () => hud.toast('A warrior blocks your way and signals you back. This is their land: the painted poles mark it. An arrow thuds into the ground at your feet.'),
    onFight: () => { hud.toast('You stayed. The warriors come for you, bows drawn: get back over the poles!'); sound.growl?.(); },
    onLeave: () => hud.toast("You're off their land. The warriors watch you go, then turn back to their camp."),
    onShoot: () => sound.tear?.(),
    onFall: () => { hud.toast('The warrior falls. The camp will not forget it.'); sound.knock(); },
    onHit: (dmg) => {
      const knockedOut = player.hurt(dmg, tools.has('coat') ? 0.33 : 0); hud.hurt(); sound.knock();
      if (knockedOut) { deathTimer = 3; hud.toast('The warriors drive you off their land, and you come to far from their camp.'); }
    },
  };
  // raids: now and then a war party rides down on the town and falls on a mended building
  const raidHooks = {
    onSack: (id) => { const p = town.projects().find((q) => q.id === id); if (town.unmend(id)) { hud.toast(`The raiders wrecked the ${p?.name || 'building'} and rode off. It wants mending again (half the cost: the frame's sound).`); saveAll(); } },
    onRepelled: () => { hud.toast('The war party breaks and wheels away into the hills. The town is safe, and folk come out to cheer you.'); inventory.dollars += 10; },
    onShoot: () => sound.tear?.(),
    onFall: () => { hud.toast('A raider tumbles from his horse.'); sound.knock(); },
    onHit: campHooks.onHit,
  };
  let raidDay = 3 + Math.floor(Math.random() * 3);
  const raidTick = () => {
    if (camp.raid.on || sky.day < raidDay || sky.time < 0.3 || sky.time > 0.7 || player.dead) return;
    if (Math.hypot(player.pos.x - town.at.x, player.pos.z - town.at.z) > 220) return; // (only while you're near enough to ride to the rescue)
    const list = town.raidable(); raidDay = sky.day + 3 + Math.floor(Math.random() * 4);
    if (!list.length) return;
    const target = list[Math.floor(Math.random() * list.length)];
    if (camp.startRaid(town.at, target)) { hud.toast(`Riders! A war party is coming down out of the hills on the town, making for the ${target.name}. Drive them off before they wreck it!`); sound.growl?.(); }
  };
  for (let i = 0; i < 13; i++) world.update(player.pos.x, player.pos.z, 0); // build the visible chunks before the first frame
  // the opening view: of the directions round the farmer, look from the one with the clearest line of sight, so
  // the game never opens on a tree trunk or a wildflower card filling the lens. Trees and buildings in the way
  // count heavily; low plants only right by the lens' line near his feet.
  {
    const TALLISH = new Set(['pine', 'maple', 'goldtree', 'sagetree', 'birch', 'appletree', 'snag', 'lodge']);
    let bestYaw = player.yaw, bestScore = Infinity;
    for (let k = 0; k < 24; k++) {
      const yaw = (k / 24) * Math.PI * 2;
      let score = Math.abs(Math.atan2(Math.sin(yaw - 0.35), Math.cos(yaw - 0.35))) * 0.5; // (all else equal, the usual angle)
      for (let i = 1; i <= 14; i++) {
        const d = i * 1.1, x = player.pos.x + Math.sin(yaw) * d * Math.cos(player.pitch), z = player.pos.z + Math.cos(yaw) * d * Math.cos(player.pitch);
        const h = 0.9 + d * Math.tan(player.pitch); // the sight line's height above the ground here
        for (const r of world.resourcesNear(x, z, 1.4)) if (r.alive) score += TALLISH.has(r.type) ? 4 : h < 1.8 ? 2 : 0;
        if (world.colliders.some((c) => (c.x - x) ** 2 + (c.z - z) ** 2 < (c.r + 0.4) ** 2)) score += 3;
      }
      if (score < bestScore) { bestScore = score; bestYaw = yaw; }
    }
    player.yaw = bestYaw;
  }

  const chips = [...document.querySelectorAll('#times button')];
  function setPreset(i) {
    sky.time = TIME_PRESETS[i].t;
    chips.forEach((c, k) => c.classList.toggle('on', k === i));
  }
  chips.forEach((c, i) => c.addEventListener('click', (e) => { e.stopPropagation(); setPreset(i); sound.click(); }));

  // Exposure follows the time of day. The lighting rig carries the mood: a moon at half the
  // sun's strength, ambient and frontal fill that rise at dusk and night. Exposure only lifts
  // gently after dark. Values were picked by viewing each preset (afternoon, golden, blue hour,
  // night). It eases over ~0.4 s, so switching presets adapts like an eye rather than snapping.
  const expo = { value: renderer.toneMappingExposure, target: renderer.toneMappingExposure, override: 0 };
  function autoExpose(dt) {
    expo.target = expo.override || EXPOSURE.base * (1 + EXPOSURE.nightLift * sky.night);
    if (weather.storm) expo.target *= 1 - 0.22 * weather.rain; // a storm's gloom, dark as a stovepipe
    if (storm.flash > 0) expo.value = Math.max(expo.value, expo.target * (1 + storm.flash * 0.35)); // the lightning's pale flash
    expo.value += (expo.target - expo.value) * (1 - Math.exp(-dt * 2.5));
    renderer.toneMappingExposure = expo.value;
  }

  let placeCD = 0, waterNear = 0, waterT = 0;

  // compile every pipeline now, so nothing hitches the first time it comes into view
  hud.backend.textContent = 'compiling…';
  // Lamps by night only: every point light (lanterns, windows, fires, the jar, a fallen star) costs a loop in
  // every lit pixel's shader even at zero brightness, so by day they're all hidden. That gives exactly two
  // lighting set-ups, day and night; both are compiled here so dusk never hitches.
  const pointLights = [];
  scene.traverse((o) => { if (o.isPointLight) pointLights.push(o); });
  let lampsOn = true;
  const setLamps = (on) => { lampsOn = on; for (const l of pointLights) l.visible = on; };
  setLamps(true);
  await renderer.compileAsync(scene, camera);
  setLamps(false);
  await renderer.compileAsync(scene, camera);
  post.render();
  const backendName = renderer.backend.isWebGPUBackend ? 'WebGPU' : 'WebGL 2';
  hud.backend.textContent = backendName;
  const fps = { frames: 0, since: performance.now() };

  window.paperfjord = { train, railroad, claim, ducks, footprints, nightHowl, fireworks, hoofDust, tumbleweeds, wadeRings, shafts, wear, settlers, eagle, beaver, geese, dandelions, fairyRing, storm, grandma, giants, woodpiles, hud, calf, songbirds, johnny, puddles, leafPiles, kite, mist, dance, fireSmoke, fair, fallingStars, cat, nightSky, jar, frogs, vane, laundry, mail, butterflies, dog, rainbow, porch, wisp, owl, tales, crows, countyMap, coop, tinker, weather, fishing, rumours, enemies, ambient, critters, journal, renderer, scene, camera, world, player, sky, input, inventory, post, home, build, tools, panel, sound, expo };
  // dev: $500 at a click (the button shows only with the dev panel open, F3; F4 does the same)
  const devCash = () => { inventory.dollars = (inventory.dollars || 0) + 500; hud.toast('Dev: +$500 in your poke.'); sound.pick(); saveAll(); };
  {
    const b = document.createElement('button'); b.id = 'devcash'; b.textContent = '+$500'; b.title = 'Dev: add $500 (F4)';
    b.addEventListener('click', (e) => { e.stopPropagation(); devCash(); });
    document.body.appendChild(b);
    const st = document.createElement('style');
    st.textContent = '#devcash{display:block;position:fixed;right:12px;bottom:84px;z-index:50;font:600 14px Georgia,serif;padding:6px 12px;background:#f2e8d0;color:#3a2a1c;border:1.5px solid #6a4a30;border-radius:6px;box-shadow:2px 3px 0 rgba(90,60,30,.35);cursor:pointer}';
    document.head.appendChild(st);
  }
  town.onStreet = (name) => { journal?.record('street'); hud.toast(`Word spreads that Paydirt Hollow is coming up in the world: folk are putting up ${name} beside the old street. Its buildings want mending too.`); };
  window.paperfjord.hunting = hunting; window.paperfjord.town = town; window.paperfjord.camp = camp; window.paperfjord.guns = guns; window.paperfjord.debugRaid = () => { raidDay = 0; camp.raid.on || raidTick(); return camp.raid; }; window.paperfjord.debugHold = (id) => { tools.add(id); held = id; };
  window.paperfjord.debugCall = (d = 25) => { if (!horse) makeHorse(player.pos.x + d, player.pos.z); riding = false; player.riding = player.avatar.riding = false; horse.group.position.set(player.pos.x + d, 0, player.pos.z + 3); horse.called = true; return horse; };
  // the warriors can be struck: by your arrows (any arrow that passes through one) and by your blows
  // ...and so can the guardians (coyotes, boars and the rest): shot, a guardian turns on you like a struck one
  const guardianHit = (e, amount) => {
    const r = enemies.damage(e, amount, player.pos);
    confetti.burst(_v.set(e.pos.x, e.pos.y + 0.6, e.pos.z), [0xa8865c, 0x7d6448, 0xefe5cc], r.killed ? 36 : 8, r.killed ? 1 : 0.6);
    sound.chop();
    if (r.killed) {
      inventory.pelt += r.loot;
      if (settlers.discover('pelt')) hud.toast('Your first pelt! Now you can build a tannery (B, Works shelf) for a settler to run.');
      journal.record('slay');
      hud.toast(`The ${e.spec.name.toLowerCase()} is beaten and slinks off for good (+${r.loot} pelt)`);
      sound.tear(); saveAll();
    }
  };
  hunting.targets = () => { const out = camp.targets(); for (const e of enemies.list) if (!e.dying) out.push({ pos: e.pos, r: 0.65 * (e.spec.scale || 1), h: (e.spec.top || 1.1) * (e.spec.scale || 1), enemy: e }); return out; };
  hunting.onTarget = (t, a) => { if (t.enemy) guardianHit(t.enemy, a?.dmg ?? 6); else { camp.damage(t.w, a?.dmg ?? 6, campHooks, raidHooks); sound.land(); } };
  window.paperfjord.debugRide = () => { if (!horse) makeHorse(player.pos.x + 1.5, player.pos.z); riding = true; player.riding = player.avatar.riding = true; return horse; };

  const timer = new THREE.Timer();
  timer.connect(document);



  const frameInner = (ts) => {
    timer.update(ts);
    const dt = Math.max(0, Math.min(timer.getDelta(), 1 / 20)); // never negative (out-of-order timestamps)
    const active = input.locked;

    // crafting panel
    if (input.hit('KeyC')) { if (panel.open) closeCraft(); else openCraft(); }
    if (panel.open && input.hit('Escape')) closeCraft();

    // build mode
    if (active && input.hit('KeyB')) {
      if (!tools.has('hammer')) hud.toast('Craft a hammer first (C)');
      else setBuilding(!build.active);
    }
    // sleeping: E by a bed at night, through to morning — fully rested, the day saved
    const bed = !build.active && active && !player.dead ? build.bedNear(player.pos) : null;
    const sleepy = sky.time > 0.8 || sky.time < 0.24;
    const atTinker = !build.active && active && !player.dead && tinker.near(player.pos, 4.2);
    // tall tales: sit by a campfire after dark; an hour slips by and the fire mends you
    const evening = sky.time > 0.78 || sky.time < 0.22;
    const atFire = !build.active && active && !player.dead && !bed && !atTinker && build.fireDistance(player.pos) < 3;
    if (almanacT > 0) { almanacT -= dt; if (almanacT <= 0 || input.hit('KeyE')) { almanacT = 0; almanacEl.classList.remove('show'); } }
    // lightning bugs: with the jar, after dark, catch the fireflies drifting about (E)
    const bugAt = tools.has('jar') && !build.active && active && !player.dead && jar.count < JAR_MAX ? ambient.fireflyNear(player.pos) : -1;
    if (bugAt >= 0 && input.hit('KeyE')) {
      ambient.catchFirefly(bugAt); jar.count++; sound.pick(); journal.record('firefly');
      if (jar.count === 1) hud.toast('Got one! It blinks away in the jar, warm as a coal.');
      else if (jar.count === JAR_MAX) hud.toast('A jar full of lightning bugs: a lantern that hums.');
    }
    if (jar.count && sky.night < 0.15) { jar.count = 0; hud.toast('First light: you unscrew the lid and the lightning bugs drift off home.'); }
    // the mailbox at the end of the lane
    const atMail = !build.active && active && !player.dead && mail.near(player.pos);
    if (mail.open && (input.hit('KeyE') || !mail.near(player.pos, 3.5))) mail.setOpen(false);
    else if (atMail && input.hit('KeyE')) {
      const L = mail.take();
      if (L) {
        for (const [k, n] of Object.entries(L.gift)) inventory[k] = (inventory[k] || 0) + n;
        sound.pick(); journal.record('letter'); saveAll();
      } else hud.toast('Nothing in the box. The carrier comes by mid-morning.');
    }
    if (tales.open && (input.hit('KeyE') || !atFire)) tales.setOpen(false);
    else if (atFire && input.hit('KeyE')) {
      if (!evening) hud.toast('Tall tales keep till after dark. Come back when the stars are out.');
      else {
        const isNew = tales.tell();
        sky.time = (sky.time + 1 / 24) % 1;
        player.health = Math.min(player.maxHealth, player.health + 20);
        sound.lullaby();
        if (isNew) journal.record('tale');
        saveAll();
      }
    }
    // milk a cow once a day; shear a sheep, and its fleece grows back in two days
    const beast = !build.active && active && !player.dead ? critters.livestockNear(player.pos) : null;
    const beastReady = beast && (beast.type === 'cow' ? beast.milkedDay !== sky.day : !(beast.shornDay && sky.day - beast.shornDay < 2));
    if (beast && input.hit('KeyE')) {
      critters.hold(beast);
      if (!beastReady) hud.toast(beast.type === 'cow' ? "She's been milked today; she'll have more tomorrow." : 'Her fleece is still growing back.');
      else if (beast.type === 'cow') {
        beast.milkedDay = sky.day; inventory.milk += 1;
        hud.toast('A pail of warm, frothy milk. (+1 milk)'); sound.pick(); journal.record('livestock'); saveAll();
      } else {
        beast.shornDay = sky.day; critters.setShorn(beast, true);
        const n = 2 + Math.floor(Math.random() * 2); inventory.wool += n;
        hud.toast(`Snip, snip: an armful of fleece. (+${n} wool)`); sound.tear(); journal.record('livestock'); saveAll();
      }
    }
    for (const c of critters.list) if (c.shornDay && sky.day - c.shornDay >= 2) { c.shornDay = 0; critters.setShorn(c, false); }
    // bee skeps: the bees fill a comb each morning; E by a skep takes the honey
    build.tendSkeps(sky.day, sky.time);
    build.tendFeeders(sky.day, sky.time);
    build.tendTrees(sky.day, sky.time, () => { hud.toast('Your apple sapling has grown into a fine young apple tree!'); journal.record('growtree'); saveAll(); });
    const myTree = !build.active && active && !player.dead ? build.appleTreeNear(player.pos) : null;
    if (myTree && input.hit('KeyE')) {
      if (myTree.stock > 0) {
        const n = myTree.stock; myTree.stock = 0; inventory.apples += n; sound.pick();
        confetti.burst(_v.set(myTree.x, myTree.y + 2.5, myTree.z), [0xc4362f, 0xe0a03a, 0x7d9a4e], 18, 0.8);
        hud.toast(`You give your apple tree a shake: ${n} apples come thumping down.`); saveAll();
      } else hud.toast('Not a ripe apple left. They come on again in the morning.');
    }
    {
      let n = 0;
      if (sky.night < 0.5) for (const sp of build.pieces) {
        if (sp.type !== 'skep' || n >= 30 || Math.hypot(sp.x - player.pos.x, sp.z - player.pos.z) > 30) continue;
        for (let k = 0; k < 6 && n < 30; k++, n++) {
          const ph = performance.now() * 0.001 * (0.9 + k * 0.17) + k * 1.7;
          _bm.makeTranslation(sp.x + Math.sin(ph) * (0.6 + k * 0.12), sp.y + 1.1 + Math.sin(ph * 2.3) * 0.25, sp.z + Math.cos(ph * 1.3) * (0.6 + k * 0.1));
          beeMesh.setMatrixAt(n, _bm);
        }
      }
      beeMesh.count = n; if (n) beeMesh.instanceMatrix.needsUpdate = true;
    }
    const skep = !build.active && active && !player.dead && !beast ? build.skepNear(player.pos) : null;
    if (skep && input.hit('KeyE')) {
      if (skep.stock > 0) {
        const n = skep.stock; skep.stock = 0; inventory.honey += n;
        hud.toast(`Smoke, lift, and ${n === 1 ? 'a comb' : n + ' combs'} of golden honey. (+${n} honey)`); sound.pick(); journal.record('skep'); saveAll();
      } else hud.toast('The bees are still at work. Come back in the morning.');
    }
    // a scratch behind the ears for Old Blue
    const atStar = !build.active && active && !player.dead && fallingStars.near(player.pos);
    if (atStar && input.hit('KeyE')) {
      const [gift, note] = STAR_GIFTS[Math.floor(Math.random() * STAR_GIFTS.length)];
      for (const [k, n] of Object.entries(gift)) inventory[k] = (inventory[k] || 0) + n;
      confetti.burst(_v.copy(fallingStars.at).setY(fallingStars.at.y + 1), [0xf6e8b0, 0xe8c870, 0xfffaf0], 22, 0.9);
      fallingStars.take(); sound.lullaby(); journal.record('star'); saveAll();
      hud.toast(`You pick up the fallen star. It's warm, and it leaves you ${note}.`);
    }
    const atCat = !atStar && !build.active && active && !player.dead && !porch.sitting && !atMail && !mail.open && bugAt < 0 && cat.near(player.pos);
    if (atCat && input.hit('KeyE')) { cat.pat(); journal.record('cat'); hud.toast(['Marmalade purrs like a little engine.', 'She butts her head against your hand and purrs.', 'A slow blink. From a cat, that means a great deal.'][Math.floor(Math.random() * 3)]); }
    // a peace offering for a guardian: every keeper has the thing the old tales say will settle it, and then it dozes
    // till morning. A keeper still lying in wait (flat in the grass, or not there at all) gives no prompt away.
    const gn = !build.active && active && !player.dead ? enemies.awakeNear(player.pos, sky.day + sky.time) : null;
    const guardNear = gn && gn.state !== 'lurk' ? gn : null;
    const peace = guardNear ? PEACE[guardNear.kind] || PEACE.coyote : null, offering = peace?.cost || null;
    const canOffer = offering && Object.entries(offering).every(([k, n]) => (inventory[k] || 0) >= n);
    if (guardNear && input.hit('KeyE')) {
      if (canOffer) {
        for (const [k, n] of Object.entries(offering)) inventory[k] -= n;
        enemies.calm(guardNear, sky.day + sky.time); journal.record('peace'); sound.lullaby(); saveAll();
        hud.toast(peace.thanks);
      } else hud.toast(peace.lore);
    }
    // the cider press: four apples make a mug of warm cider, and you could run all afternoon
    const press = !build.active && active && !player.dead ? build.pressNear(player.pos) : null;
    if (press && input.hit('KeyE')) {
      if (inventory.apples >= 4) {
        inventory.apples -= 4; ciderT = 120; player.stamina = player.maxStamina; sound.pick(); journal.record('cider');
        confetti.burst(_v.set(press.x, press.y + 1.2, press.z), [0xd9a441, 0xc4362f, 0xe8c070], 16, 0.7);
        hud.toast('You crank the screw down and sweet cider runs into the crock. A warm mugful, and your legs feel fresh as morning.');
        saveAll();
      } else hud.toast('The press wants 4 apples for a mugful of cider.');
    }
    if (ciderT > 0) { ciderT -= dt; player.stamina = Math.min(player.maxStamina, player.stamina + dt * 30); if (ciderT <= 0) hud.toast('The cider warmth wears off.'); }
    // fairy rings: rain in the night brings one up by morning
    if (weather.rain > 0.3 && weather.kind === 'rain' && (sky.time > 0.8 || sky.time < 0.25)) ringRain = true;
    if (ringRain && sky.time >= 0.25 && sky.time < 0.5 && fairyRing.day !== sky.day) {
      ringRain = false;
      const dir = fairyRing.sprout(sky.day, player.pos);
      if (dir) hud.toast(`After the wet night, a ring of toadstools has come up in a meadow off to the ${dir}. Old folks say it's lucky to find one.`);
    }
    fairyRing.update(dt, sky);
    const atRing = !build.active && active && !player.dead && fairyRing.near(player.pos);
    if (atRing && input.hit('KeyE')) {
      fairyRing.gather(); inventory.mushrooms += 6; journal.record('ring'); sound.pick();
      const lucky = Math.random() < 0.35;
      if (lucky) { inventory.honey += 1; inventory.iron += 1; }
      hud.toast(lucky ? 'You gather the whole ring (+6 toadstools), and tucked in the grass at its middle there is a little clay jar of honey and an old iron key. Lucky indeed!' : 'You gather the whole ring into your hat: six fine toadstools for a stew.');
      saveAll();
    }
    // Grandma at the door of an evening: a warm slice of pie, once a night
    grandma.update(dt, sky);
    const atDoor = !build.active && active && !player.dead && !porch.sitting && grandma.atDoor(player.pos);
    if (atDoor && input.hit('KeyE')) {
      if (!grandma.home(sky)) hud.toast(sky.time >= 0.94 || sky.time < 0.25 ? 'The house is dark. Grandma has gone up to bed; best not wake her.' : 'Grandma is out visiting till evening. The door is on the latch.');
      else {
        // her wish for today: bring it and she bakes you something in return (once a day)
        const wish = wishFor(sky.day), have = Object.entries(wish.cost).every(([k, n]) => (inventory[k] || 0) >= n);
        if (have && grandma.wishDay !== sky.day) {
          for (const [k, n] of Object.entries(wish.cost)) inventory[k] -= n;
          for (const [k, n] of Object.entries(wish.gives)) inventory[k] = (inventory[k] || 0) + n;
          grandma.wishDay = sky.day; journal.record('wish'); sound.lullaby(); hud.toast(`"${wish.thanks}"`); saveAll();
        } else if (grandma.pieDay === sky.day) hud.toast(grandma.wishDay === sky.day ? `"One slice is plenty, young man. There will be more tomorrow."` : `"One slice is plenty. But if you're passing, I could use ${wish.ask}."`);
        else { grandma.pieDay = sky.day; inventory.pie += 1; journal.record('grandma'); sound.lullaby(); hud.toast(`Grandma opens the door in a warm wash of lamplight. ${PIE_WORDS[Math.floor(Math.random() * PIE_WORDS.length)]} (+1 pumpkin pie)${grandma.wishDay === sky.day ? '' : ` "And if you've a moment tomorrow or tonight, I could use ${wish.ask}."`}`); saveAll(); }
      }
    }
    // the giant-pumpkin patch: tend it once a day (E) and the prize pumpkin swells; at full size, cut it for the fair
    giants.update(dt, build.pieces, player.pos);
    const gp = !build.active && active && !player.dead ? build.patchNear(player.pos) : null;
    if (gp && input.hit('KeyE')) {
      gp.stage ??= 0;
      if (gp.stage >= GIANT_STAGES) { gp.stage = 0; gp.tendDay = sky.day; inventory.giantpumpkin = (inventory.giantpumpkin || 0) + 1; journal.record('giant'); sound.chop(); hud.toast('You cut the stem and roll your prize pumpkin onto the cart. Mrs. Pruitt will want to see this at the fair.'); saveAll(); }
      else if (gp.tendDay === sky.day) hud.toast('Tended already today. It grows overnight, they say, while nobody is looking.');
      else { gp.tendDay = sky.day; gp.stage += 1; sound.pick(); journal.record('tend'); hud.toast(gp.stage >= GIANT_STAGES ? 'Water, a dollop of manure, a kind word: your pumpkin is a whopper now! Cut it for the fair.' : `You water it, pinch back the vine and say something encouraging. It swells a size bigger (${gp.stage}/${GIANT_STAGES}).`); saveAll(); }
    }
    // the woodpile: E stacks your firewood (four at a go); with empty arms, E takes four back
    woodpiles.update(build.pieces, player.pos);
    const pile = !build.active && active && !player.dead ? build.woodpileNear(player.pos) : null;
    if (pile && input.hit('KeyE')) {
      pile.stock ??= 0;
      if (inventory.wood > 0 && pile.stock < PILE_MAX) { const n = Math.min(4, inventory.wood, PILE_MAX - pile.stock); inventory.wood -= n; pile.stock += n; sound.chop(); journal.record('stack', n); if (pile.stock >= 12 && pile.stock - n < 12) hud.toast('A good stack of firewood. With that near the house, the stove will keep you warm all night.'); saveAll(); }
      else if (inventory.wood === 0 && pile.stock > 0) { const n = Math.min(4, pile.stock); pile.stock -= n; inventory.wood += n; sound.pick(); saveAll(); }
      else hud.toast('The woodpile is stacked to the top.');
    }
    const calfR = calf.update(dt, sky, player, camera, world.colliders);
    if (calfR?.lost) hud.toast(`Daisy's calf slipped through the pasture rails in the night! Folks saw it heading off to the ${calfR.lost}. Listen for it bawling.`);
    if (calfR?.home) { inventory.milk += 2; journal.record('calf'); sound.lullaby(); saveAll(); hud.toast('The calf scampers through the rails to Daisy, who lows and licks it all over. She gives you two pails of milk, she is that glad.'); }
    const atCalf = !build.active && active && !player.dead && calf.near(player.pos);
    if (atCalf && input.hit('KeyE') && calf.lead()) hud.toast('The calf gives a little bawl and trots after you. Lead it home to the pasture.');
    const atJohnny = !build.active && active && !player.dead && johnny.near(player.pos);
    if (atJohnny && input.hit('KeyE')) {
      if (!johnny.talked) {
        johnny.talked = true; johnny.talkedDay = sky.day; inventory.apples += 3; journal.record('johnny');
        // and he plants a sapling just off the lane, at the edge of the yard
        const sx = johnny.pos.x, sz = johnny.pos.z - 2.6, sy = getHeight(sx, sz);
        if (!isWater(sx, sz) && !build.pieces.some((q) => Math.hypot(q.x - sx, q.z - sz) < 2)) build.add({ type: 'sapling', x: sx, y: sy, z: sz, rot: Math.random() * 6, day: sky.day });
        hud.toast(`${SAYINGS[Math.floor(Math.random() * SAYINGS.length)]} He hands you 3 apples and plants a sapling by the lane.`);
        sound.pick(); saveAll();
      } else hud.toast(`"Mind that sapling now. Water it with patience." He tips his pot and wanders on.`);
    }
    // the bird feeder: a cob of corn or a couple of handfuls of berries keeps the songbirds coming for two days
    // settlers: hire one at their camp; take what the works have made from the storehouse
    // the opening find: E by the glint picks up the nugget
    const atGlint = !!glint && active && !player.dead && !build.active && Math.hypot(player.pos.x - glint.position.x, player.pos.z - glint.position.z) < 2.3;
    if (glint) {
      // never lost under something you've built (a workbench put down on top of it): it hops to clear ground nearby
      if (glintT <= 0 && build.nearby(glint.position.x, glint.position.z, 1.8).length) {
        const gp = glint.position;
        for (let r = 2.5, done = false; r < 12 && !done; r += 1.5) for (let a = 0; a < Math.PI * 2 && !done; a += 0.6) {
          const x = gp.x + Math.cos(a) * r, z = gp.z + Math.sin(a) * r;
          if (!isWater(x, z) && !build.nearby(x, z, 1.8).length) { gp.set(x, getHeight(x, z), z); done = true; }
        }
      }
      if ((glintT -= dt) <= 0) { glintT = 0.9 + Math.random() * 0.6; confetti.burst(_v.set(glint.position.x, glint.position.y + 0.25, glint.position.z), [0xfff2b0, 0xf0c840], 3, 0.25); } // a twinkle in the gravel
      if (!glintTold && active) { glintTold = true; hud.toast('You came west chasing a gold rumour. Something glints by the cabin...'); }
      if (atGlint && input.hit('KeyE')) {
        scene.remove(glint); glint = null; openingDone = true; inventory.gold += 2; settlers.discover('gold'); journal.record('gather:gold');
        confetti.burst(_v.set(player.pos.x, player.pos.y + 0.9, player.pos.z), [0xf0c840, 0xffe08a, 0xd8a830], 14, 0.6); sound.craft();
        hud.toast('GOLD! The rumour was true. Sell it at the assay office in town: $4 a pinch. Pan creeks (E in shallow water) for more.');
        saveAll();
      }
    }
    // climbing: E at the foot of a ladder (or a scramble up rock) takes you up; E at its head brings you down
    const ladder = !player.climbing && !riding && active && !player.dead && !build.active && !atGlint ? climbs.ladderAt(player.pos) : null;
    if (ladder && input.hit('KeyE')) { player.climbing = { ...climbs.path(ladder, player.pos), t: 0 }; sound.place(); if (ladder.up && ladder.ladder.name === 'the windmill') millPending = true; }
    if (millPending && !player.climbing) {
      millPending = false;
      if (millViewDay !== sky.day) {
        millViewDay = sky.day; const m = home.millAt;
        for (let a = 0; a < Math.PI * 2; a += 0.12) for (let r = 0; r <= 110; r += 12) countyMap.update({ x: m.x + Math.cos(a) * r, z: m.z + Math.sin(a) * r });
        hud.toast("Up on the windmill platform, with the fan clattering over your head, the whole home place is laid out below: the house, the barn, the fields, the lane to Paydirt Hollow and the creek beyond. You ink it all onto your map."); sound.craft();
      }
    }
    // the root cellar: buy it at the stake by the house; once dug, something's put by in it every morning
    const atCellar = !build.active && active && !player.dead && !atGlint && !ladder && cellar.near(player.pos) && (!cellar.built || cellar.stocked(sky.day));
    if (atCellar && input.hit('KeyE')) {
      if (!cellar.built) {
        if (inventory.dollars >= CELLAR_COST) { inventory.dollars -= CELLAR_COST; cellar.build(); confetti.burst(_v.copy(cellar.pos).setY(cellar.pos.y + 1), [0x8a9a5a, 0x8a5a34, 0xefe3c4], 14, 0.7); sound.craft(); hud.toast('Root cellar dug! Food every morning.'); saveAll(); }
        else hud.toast(`A root cellar costs $${CELLAR_COST}. You have $${inventory.dollars}.`);
      } else { cellar.day = sky.day; inventory.apples += 2; inventory.bread += 1; sound.pick(); hud.toast('+2 apples, +1 bread from the cellar'); saveAll(); }
    }
    // the bunkhouse: buy it at its stake in the old camp ground west of the yard
    const atBunk = !build.active && active && !player.dead && !atGlint && !ladder && !atCellar && !bunkhouse.built && bunkhouse.near(player.pos);
    if (atBunk && input.hit('KeyE')) {
      if (inventory.dollars >= BUNK_COST) {
        inventory.dollars -= BUNK_COST; bunkhouse.build(); confetti.burst(_v.copy(bunkhouse.pos).setY(bunkhouse.pos.y + 1.5), [0x8a6038, 0xd8c8a0, 0xefe3c4], 18, 0.8); sound.craft();
        for (const s of settlers.list) if (settlers.hired.has(s.S.id) && s.state !== 'away') s.pos.copy(settlers.campAt(s));
        hud.toast('Bunkhouse built! Your hands sleep on the farm now: a quarter more work from every one.'); saveAll();
      } else hud.toast(`A bunkhouse costs $${BUNK_COST}. You have $${inventory.dollars}.`);
    }
    const busyE = atTinker || bed || fair.near(player.pos, 3.2) || atGlint || !!ladder || !!player.climbing || atCellar || atBunk;
    const grind = !build.active && active && !player.dead && !busyE && !atFire && Object.values(wear).some((w) => w < 70) && (build.stationNear('workbench', player.pos) || build.stationNear('forge', player.pos));
    if (grind && input.hit('KeyE')) {
      if ((inventory.stone || 0) >= 1) { inventory.stone -= 1; for (const k in wear) wear[k] = 100; dullWarned = false; hud.toast('Skrrrr... you work every edge on the grindstone till it shines. Sharp as new.'); sound.mine(); saveAll(); }
      else hud.toast('The grindstone wants a stone to dress it with.');
    } // the tinker, a bed or the fair table come first
    // gold: pan the creek shallows for colour (E while wading); the assayer in town weighs it and pays out
    // mending the town: at a run-down building's door, E pays to have it put right (the assay office's own door
    // weighs your gold first, if you've any)
    const project = !build.active && active && !player.dead && !busyE ? town.projectAt(player.pos) : null;
    const mendE = !!project && !(project.id === 'assay' && (inventory.gold > 0 || inventory.silver > 0));
    if (mendE && input.hit('KeyE')) {
      if (inventory.dollars >= project.cost) {
        inventory.dollars -= project.cost; town.mend(project.id); if (project.id === 'boarding') newcomerNews = true;
        hud.toast(MEND_TEXT[project.id] || `The ${project.name} is mended.`);
        confetti.burst(_v.set(project.door.x, player.pos.y + 1.6, project.door.z), [0xefe3c4, 0xb5473a, 0xe8c84a], 30, 0.9); sound.craft(); journal.record('mend'); saveAll();
      } else hud.toast(`Putting the ${project.name} to rights takes $${project.cost}; you've $${inventory.dollars}. Pan some more colour.`);
    }
    const wanter = !build.active && active && !player.dead && !busyE && !mendE ? town.wantAt(player.pos) : null; // a tent-dweller on Squatters' Row who wants something
    if (wanter && input.hit('KeyE')) { const r = town.fill(wanter, inventory, sky.day, inventory.groomedDay === sky.day ? 1 : 0); hud.toast(r.text); if (r.ok) { sound.craft(); saveAll(); } else sound.click(); }
    const assayE = !build.active && active && !player.dead && !busyE && !mendE && !wanter && town.nearAssay(player.pos);
    if (assayE && input.hit('KeyE')) {
      if (inventory.gold > 0 || inventory.silver > 0) { // gold dust at $4 the pinch, silver ore at $5 the lump
        const groomed = inventory.groomedDay === sky.day, g = inventory.gold, sv = inventory.silver || 0, pay = Math.round((g * 4 + sv * 5) * (groomed ? 1.1 : 1)); inventory.dollars += pay; // (a fresh shave and a trim: he's a shade more generous with a well-groomed man) fortune += pay; inventory.gold = 0; inventory.silver = 0; journal.record('assay');
        hud.toast(`The assayer weighs it on his brass scales${sv ? ' and assays the silver with a drop of acid' : ''}. "$${pay}, and not a cent more." Fortune so far: $${fortune}.`);
        sound.craft(); saveAll();
      } else hud.toast('"Bring me colour, friend, and I\'ll weigh it," says the assayer, not looking up.');
    }
    const panE = !build.active && active && !player.dead && !busyE && player.wading && !assayE && panT <= 0;
    if (panE && input.hit('KeyE')) { panT = 2.6; sound.step('water'); }
    if (panT > 0) {
      panT -= dt; panMesh.visible = true; panMesh.rotation.y += dt * 9; panMesh.position.y = -0.08 + Math.sin(panT * 14) * 0.03;
      if (panT <= 0) {
        panMesh.visible = false;
        const W = landAt(player.pos.x, player.pos.z).w, rich = 0.22 + 0.4 * (W.breaks + W.pines) + 0.15 * W.hollows + (blessedDay === sky.day ? 0.15 : 0), r = Math.random(); // (blessed: richer pans all day)
        if (r < rich) {
          const n = r < rich * 0.25 ? 2 : 1; inventory.gold += n;
          if (settlers.discover('gold')) hud.toast('COLOUR! Bright flakes in the black sand at the bottom of the pan. Gold. Take it to the assay office in Paydirt Hollow. And now you can build a sluice box by the water (B, Works shelf) for a placer miner to run.');
          else hud.toast(`+${n} pinch${n > 1 ? 'es' : ''} of gold`);
          confetti.burst(_v.set(player.pos.x, player.pos.y + 0.9, player.pos.z), [0xf0c840, 0xffe08a, 0xd8a830], 8, 0.5); sound.pick(); saveAll();
        } else hud.toast(['Nothing but black sand.', 'Gravel and a crawdad. No colour.', 'Sand, sand and more sand.'][Math.floor(Math.random() * 3)]);
      }
    }
    const settlerNear = !build.active && active && !player.dead && !busyE ? settlers.near(player.pos) : null;
    const hireable = settlerNear && settlerNear.state === 'camp' ? settlerNear : null;
    if (hireable && hireable.S.how === 'deed') {
      // the collier: only for someone who's driven off a treasure guardian
      if (input.hit('KeyE')) {
        if ([...world.destroyed].some((k) => k.includes(':g'))) { settlers.join(hireable); hud.toast(hireable.S.hired); sound.craft(); saveAll(); }
        else hud.toast(hireable.S.lost);
      }
    } else if (hireable && hireable.S.how === 'court') {
      // courting: a reel at the barn dance, and a pumpkin pie brought to her camp
      if (input.hit('KeyE')) {
        if (settlers.danced && (inventory.pie || 0) >= 1) { inventory.pie -= 1; settlers.join(hireable); hud.toast(hireable.S.hired); sound.craft(); saveAll(); }
        else if (!settlers.danced) hud.toast('"You haven\'t so much as asked me to dance. There\'s a dance in front of the livery barn the night of every County Fair, you know."');
        else hud.toast('"That reel was lovely. A pumpkin pie wouldn\'t go amiss, either."');
      }
    } else if (hireable && hireable.S.how === 'tale') {
      // the tall-tale contest: by his fire after dark, and you need tales of your own to tell
      if (input.hit('KeyE')) {
        if (sky.night < 0.45) hud.toast('"Tales are for after dark, friend. Come by my fire this evening."');
        else if (tales.heard.size >= hireable.S.tales) { settlers.join(hireable); hud.toast(hireable.S.hired); sound.craft(); saveAll(); }
        else hud.toast(hireable.S.lost);
      }
    } else if (hireable && hireable.S.how === 'wrestle') {
      // the arm-wrestle: E starts it, then every E press pushes his arm down
      if (!settlers.match && (hireable.tired || 0) <= 0 && input.hit('KeyE')) { settlers.match = { k: 0.5, s: hireable }; hud.toast('You sit down across the crate and clasp hands. Press E as fast as you can!'); sound.knock(); }
      else if (settlers.match) {
        const r = settlers.wrestle(dt, hireable, input.hit('KeyE'));
        if (r === 'won') { hud.toast(hireable.S.hired); sound.craft(); saveAll(); }
        else if (r === 'lost') { hud.toast('Thump! Big Jim pins your arm to the crate. "Come back when you\'ve had your oats."'); sound.knock(); }
      }
    } else if (hireable && input.hit('KeyE')) {
      if (settlers.hire(inventory, hireable)) { hud.toast(hireable.S.hired); sound.craft(); saveAll(); }
      else hud.toast(hireable.S.how === 'help' ? `${hireable.S.name} needs ${Object.entries(hireable.S.wage).map(([k, n]) => `${n} ${k}`).join(' and ')} to ${hireable.S.chore || 'mend her lean-to'}.` : `${hireable.S.name} would join for ${Object.entries(hireable.S.wage).map(([k, n]) => `${n} ${k}`).join(' and ')}.`);
    }
    if (settlers.match && settlers.match.s !== hireable) settlers.match = null; // walked off mid-match
    const storeNear = !build.active && active && !player.dead && !busyE ? build.pieces.find((p) => p.type === 'storehouse' && Math.hypot(p.x - player.pos.x, p.z - player.pos.z) < 2.8) : null;
    if (storeNear && !hireable && active && input.hit('KeyR')) {
      const r = settlers.stockLarder(inventory);
      if (r) { hud.toast(`Into the larder: ${Object.entries(r.taken).map(([k, n]) => `${n} ${k}`).join(', ')} (+${r.rations} rations). ${settlers.larderText()}.`); sound.pick(); saveAll(); }
      else hud.toast('Nothing plain to put by: fish, corn, apples, eggs, bread or berries (two to a ration) feed your settlers.');
    }
    if (storeNear && !hireable && input.hit('KeyE')) {
      const got = settlers.collect(inventory), text = Object.entries(got).map(([k, n]) => `${n} ${k}`).join(', ');
      if (text) { hud.toast(`From the storehouse: ${text}.`); sound.pick(); saveAll(); } else hud.toast('The storehouse is empty for now. Your settlers bring what they make a little at a time.');
    }
    if (active && input.hit('KeyJ')) { settlersCard.classList.toggle('show'); if (settlersCard.classList.contains('show')) renderSettlers(); sound.tear(); }
    else if (settlersCard.classList.contains('show') && (setT += dt) > 1) { setT = 0; renderSettlers(); }
    const feeder = !build.active && active && !player.dead ? build.feederNear(player.pos) : null;
    if (feeder && input.hit('KeyE')) {
      const food = inventory.corn >= 1 ? ['corn', 1, 'a cob of corn'] : inventory.berries >= 2 ? ['berries', 2, 'two handfuls of berries'] : null;
      if (food && (feeder.stock || 0) < 3) {
        inventory[food[0]] -= food[1]; feeder.stock = Math.min(3, (feeder.stock || 0) + 2); feeder.day ??= sky.day;
        sound.pick(); journal.record('feeder'); hud.toast(`You fill the feeder with ${food[2]}. Step back and wait: the birds will come.`); saveAll();
      } else hud.toast(food ? 'The feeder is full to the brim.' : 'The feeder takes a cob of corn or two handfuls of berries.');
    }
    const atDance = !build.active && active && !player.dead && dance.near(player.pos) && danceT <= 0;
    const atStick = !build.active && active && !player.dead && !atCat && !atDance && !porch.sitting && dog.stickNear(player.pos);
    if (atStick && input.hit('KeyE')) { dog.throwStick(player); sound.tear(); }
    const atDog = !atStick && !build.active && active && !player.dead && !beast && !skep && !porch.sitting && !atMail && !mail.open && bugAt < 0 && !atCat && !atDance && !project && !town.nearAssay(player.pos) && !atTownDoor('store', player.pos) && !atTownDoor('saloon', player.pos) && !atTownDoor('smithy', player.pos) && !atTownDoor('church', player.pos) && dog.near(player.pos); // (town business before patting the dog)
    if (atDog && input.hit('KeyE')) {
      dog.pat(); journal.record('pat');
      if (Math.random() < 0.5 && dog.offerStick(player)) hud.toast('Old Blue drops a slobbery stick at your feet and looks up at you, hopeful.');
      else hud.toast(['Old Blue thumps his tail on the ground.', 'A good scratch behind the ears. Old Blue leans into it.', 'Old Blue licks your hand and grins his dog grin.'][Math.floor(Math.random() * 3)]);
    }
    const atCoop = !build.active && active && !player.dead && !beast && !skep && !atDog && !atCat && coop.near(player.pos);
    if (atCoop && input.hit('KeyE')) {
      const n = coop.collect();
      if (n) {
        inventory.egg += n;
        journal.record('gather:egg', n);
        hud.toast(n === 1 ? 'One warm egg from the straw.' : `${['', '', 'Two', 'Three', 'Four'][n]} warm eggs from the nesting box!`);
        sound.pick();
        saveAll();
      } else hud.toast("The hens haven't laid since this morning. Check back tomorrow.");
    }
    if (atDance && input.hit('KeyE')) {
      danceT = 5; journal.record('dance'); settlers.danced = true; // (Clementine hears of it)
      hud.toast(['You swing your partner round and round. The fiddler grins and plays faster.', 'A reel, a jig and a do-si-do. Your boots have never been so happy.', 'Round the floor you go, under the lanterns. The whole county is clapping.'][Math.floor(Math.random() * 3)]);
    }
    if (danceT > 0) {
      danceT -= dt; player.facing += dt * 7; // swinging round on the floor
      player.stamina = Math.min(player.maxStamina, player.stamina + dt * 30); player.health = Math.min(player.maxHealth, player.health + dt * 3);
    }
    const atFair = !build.active && active && !player.dead && fair.near(player.pos, 3.2);
    if (atFair && !bed && input.hit('KeyE')) {
      openCraft(); journal.record('fair');
      [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('County Fair'))?.scrollIntoView({ block: 'start' });
    }
    const atStore = !build.active && active && !player.dead && !!town.tiers.store && Math.hypot(player.pos.x - town.doors.store.x, player.pos.z - town.doors.store.z) < 2.3;
    if (atStore && input.hit('KeyE')) {
      openCraft(); journal.record('store');
      [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('General store'))?.scrollIntoView({ block: 'start' }); // open at the shelves
    }
    const atBakery = !build.active && active && !player.dead && !atStore && !!town.tiers.bakery && Math.hypot(player.pos.x - town.doors.bakery.x, player.pos.z - town.doors.bakery.z) < 2.3;
    // the sheriff's jail, once it's mended: he puts a price on one guarded den out in the county (pencilled onto your
    // map); beat every guardian there and come back to his door for the reward
    const atJail = !build.active && active && !player.dead && !atStore && !!town.tiers.jail && Math.hypot(player.pos.x - town.doors.jail.x, player.pos.z - town.doors.jail.z) < 2.3;
    if (atJail && input.hit('KeyE')) {
      const beaten = (b) => Array.from({ length: b.guards }, (_, i) => `${b.key}:g${i}`).every((k) => world.destroyed.has(k));
      const dirTo = (x, z) => ['east', 'south-east', 'south', 'south-west', 'west', 'north-west', 'north', 'north-east'][Math.round(Math.atan2(z - town.at.z, x - town.at.x) / (Math.PI / 4) + 8) % 8];
      if (bounty && beaten(bounty)) {
        inventory.dollars += bounty.pay; hud.toast(`The sheriff tears down the poster and counts out $${bounty.pay}. "Much obliged. The county's that much safer."`); sound.craft(); journal.record('bounty');
        bounty = null; town.setPoster(null); saveAll();
      } else if (bounty) hud.toast(`"That ${bounty.name.toLowerCase()} is still out there, about ${Math.round((Math.hypot(bounty.x - town.at.x, bounty.z - town.at.z) * 1.3) / 10) * 10} paces ${dirTo(bounty.x, bounty.z)} of town. It's on your map."`);
      else {
        const tcx = Math.floor(town.at.x / CHUNK), tcz = Math.floor(town.at.z / CHUNK); let best = null, bd = Infinity;
        for (let dz = -10; dz <= 10; dz++) for (let dx = -10; dx <= 10; dx++) for (const st of world.sitesFor(tcx + dx, tcz + dz)) {
          if (!st.guards || st.kind === 'landmark') continue;
          const d = Math.hypot(st.x - town.at.x, st.z - town.at.z); if (d < 60 || d > 320) continue;
          const b = { key: st.key, guards: st.guards }; if (beaten(b)) continue;
          if (d < bd) { bd = d; best = st; }
        }
        if (!best) hud.toast('"Quiet as a churchyard out there, thanks to you. Nothing on the board today."');
        else {
          const kind = best.guard || (best.kind === 'grove' ? 'boar' : 'coyote'), spec = GUARDS[kind];
          bounty = { key: best.key, guards: best.guards, x: best.x, z: best.z, name: spec.name, pay: Math.max(12, Math.round(spec.hp * best.guards * 1.4)) };
          for (let a = 0; a < Math.PI * 2; a += 0.8) for (const r of [0, 14]) countyMap.update({ x: best.x + Math.cos(a) * r, z: best.z + Math.sin(a) * r });
          town.setPoster(bounty); sound.place();
          hud.toast(`The sheriff tacks up a fresh poster: WANTED, ${best.guards > 1 ? `${best.guards} ${spec.name.toLowerCase()}s` : `the ${spec.name.toLowerCase()}`}, $${bounty.pay} reward. "Their den's about ${Math.round((bd * 1.3) / 10) * 10} paces ${dirTo(best.x, best.z)} of town. I've marked your map."`);
          saveAll();
        }
      }
    }
    // the barber shop, once it's mended: a shave and a haircut, two bits... well, two dollars. Spruced up till the next
    // morning: the assayer pays a tenth more and the folk on Squatters' Row a dollar more
    const atBarber = !build.active && active && !player.dead && !atStore && !!town.tiers.barber && Math.hypot(player.pos.x - town.doors.barber.x, player.pos.z - town.doors.barber.z) < 2.3;
    if (atBarber && input.hit('KeyE')) {
      if (inventory.groomedDay === sky.day) hud.toast('"Any shorter and you\'ll catch cold, friend." You\'re as dapper as you\'ll get today.');
      else if ((inventory.dollars || 0) < 2) hud.toast('"Shave and a haircut: two dollars." You\'re short.');
      else { inventory.dollars -= 2; inventory.groomedDay = sky.day; sound.craft(); hud.toast('Snip, snip, a hot towel and a close shave with bay rum. You step out spruced up: till tomorrow the assayer pays a tenth more, and the folk on the Row a dollar more.'); saveAll(); }
    }
    const atFeed = !build.active && active && !player.dead && !atStore && !!town.tiers.feed && Math.hypot(player.pos.x - town.doors.feed.x, player.pos.z - town.doors.feed.z) < 2.3;
    if (atFeed && input.hit('KeyE')) { openCraft(); [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('Feed & grain'))?.scrollIntoView({ block: 'start' }); }
    // the opera house, once it's mended: from sundown to near midnight a touring company plays a tall tale. A ticket
    // is $3: you sit through the show (an hour or so passes) and come out rested and in good heart
    const atOpera = !build.active && active && !player.dead && !atStore && !!town.tiers.opera && Math.hypot(player.pos.x - town.doors.opera.x, player.pos.z - town.doors.opera.z) < 2.3;
    const curtain = sky.time > 0.74 || sky.time < 0.02;
    if (atOpera && input.hit('KeyE')) {
      const [title, sub, tale] = PLAYBILL[sky.day % PLAYBILL.length];
      if (!curtain) hud.toast(`The doors are shut till sundown. Tonight: ${title[0] + title.slice(1).toLowerCase().replace(/ (\w)/g, (m) => m.toUpperCase())} ${sub}.`);
      else if (operaDay === sky.day) hud.toast('You\'ve seen tonight\'s bill. The company plays something new tomorrow.');
      else if ((inventory.dollars || 0) < 3) hud.toast('"Three dollars a seat, friend." You\'re short.');
      else {
        inventory.dollars -= 3; operaDay = sky.day; sky.time = (sky.time + 0.045) % 1; // (an hour in the dark, the footlights hissing)
        player.health = player.maxHealth; player.stamina = player.maxStamina; player.fullness = Math.max(player.fullness, 60);
        sound.craft(); journal.record('opera'); saveAll();
        hud.toast(`The gaslights dim and the curtain rises on ${title[0] + title.slice(1).toLowerCase().replace(/ (\w)/g, (m) => m.toUpperCase())} ${sub}. ${tale} You come out into the night rested and smiling.`);
      }
    }
    // the Grand Hotel, once it's mended: a room for the night ($4), a feather bed, and ham and eggs at breakfast
    const atHotel = !build.active && active && !player.dead && !atStore && !!town.tiers.hotel2 && Math.hypot(player.pos.x - town.doors.hotel2.x, player.pos.z - town.doors.hotel2.z) < 2.3;
    if (atHotel && input.hit('KeyE') && !sleepTimer) {
      if (!sleepy) hud.toast('"Rooms are let from sundown, sir. The dining room serves supper at six."');
      else if ((inventory.dollars || 0) < 4) hud.toast('"A room is four dollars the night, sir, breakfast included." You\'re short.');
      else { inventory.dollars -= 4; hotelNight = true; sleepTimer = 2.6; sleepEl.classList.add('show'); sound.lullaby(); }
    }
    // the telegraph office, once it's mended: the morning wire names a buyer back East and what they want; sell all
    // you have of it here, at a good price, once a day
    const atWire = !build.active && active && !player.dead && !atStore && !!town.tiers.telegraph && Math.hypot(player.pos.x - town.doors.telegraph.x, player.pos.z - town.doors.telegraph.z) < 2.3;
    const wire = MARKET[(sky.day * 5 + 3) % MARKET.length];
    if (atWire && input.hit('KeyE')) {
      const [item, price, who] = wire, n = inventory[item] || 0;
      if (inventory.wireDay === sky.day) hud.toast(`"The order's filled for today. Tomorrow's wire comes in at seven."`);
      else if (!n) hud.toast(`The telegrapher taps the morning's wire: "${who.toUpperCase()} WANTS ${item.toUpperCase()} STOP $${price} EACH STOP". Bring some today.`);
      else { inventory[item] = 0; inventory.dollars += n * price; inventory.wireDay = sky.day; sound.craft(); journal.record('wire'); saveAll(); hud.toast(`Click-clack: ${n} ${item} crated and billed to ${who}. The telegrapher counts out $${n * price}.`); }
    }
    const atDry = !build.active && active && !player.dead && !atStore && !!town.tiers.drygoods && Math.hypot(player.pos.x - town.doors.drygoods.x, player.pos.z - town.doors.drygoods.z) < 2.3;
    if (atDry && input.hit('KeyE')) { openCraft(); [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('Dry goods'))?.scrollIntoView({ block: 'start' }); }
    // the dance hall, once it's mended: of an evening, step in and dance a reel (once a night). You come out light on your
    // feet: a long spring in your step, and a little hungrier for it
    const atHall = !build.active && active && !player.dead && !atStore && !!town.tiers.dance && Math.hypot(player.pos.x - town.doors.dance.x, player.pos.z - town.doors.dance.z) < 2.3;
    const hallOpen = sky.time > 0.76 || sky.time < 0.04;
    if (atHall && input.hit('KeyE')) {
      if (!hallOpen) hud.toast('"Doors open at dusk, friend. Bring your dancing boots."');
      else if (inventory.hallDay === sky.day) hud.toast('Your feet have had all the reels they can take tonight.');
      else { inventory.hallDay = sky.day; player.staminaBoost = Math.max(player.staminaBoost || 0, 360); player.stamina = Math.max(player.stamina, player.maxStamina); player.fullness = Math.max(0, player.fullness - 8); sky.time = (sky.time + 0.02) % 1; sound.craft(); journal.record('dance'); saveAll();
        hud.toast(['You swing through a Virginia reel with the calico girls, the fiddle sawing away. You come out light as a feather.', 'A stomping schottische, then a waltz. You step out into the night with a spring in your step.', 'The caller hollers "Promenade!" and you do. Breathless and grinning, you come out ready to run all night.'][sky.day % 3]); }
    }
    const atDepot = !build.active && active && !player.dead && !riding && !train.passenger && railroad.built && !!railroad.freightAt && Math.hypot(player.pos.x - railroad.freightAt.x, player.pos.z - railroad.freightAt.z) < 2.6;
    const atClaim = !build.active && active && !player.dead && !riding && !train.passenger && !!claim.group && claim.near(player.pos.x, player.pos.z);
    if (atClaim && input.hit('KeyE')) {
      const pick = tools.has('pickaxe') || tools.has('ironpick') || tools.has('steelpick');
      const cart = claim.collect(); if (cart.gold || cart.silver) { inventory.gold = (inventory.gold || 0) + cart.gold; inventory.silver = (inventory.silver || 0) + cart.silver; hud.toast(`Your hand tips out the ore cart for you: ${cart.gold} pinches of gold${cart.silver ? ` and ${cart.silver} nugget${cart.silver > 1 ? 's' : ''} of silver` : ''}. "She's a fair vein, boss."`); saveAll(); }
      else if (!pick) hud.toast('You need a pickaxe to work the vein.');
      else { const got = claim.dig(sky.day, tools); if (!got) hud.toast(claim.hand ? 'You have worked the vein today, and the cart is empty. Your hand will have more for you tomorrow.' : 'You have worked the vein today. Come back tomorrow: it gives up a little each day.'); else { sound.mine?.(); inventory.gold = (inventory.gold || 0) + got.gold; if (got.silver) inventory.silver = (inventory.silver || 0) + got.silver; hud.toast(`You work the vein by lantern light and come out with ${got.gold} pinches of gold${got.silver ? ' and a nugget of silver' : ''}. (The assayer in town buys it.)`); saveAll(); } }
    }
    const atPost = !build.active && active && !player.dead && !riding && !train.passenger && railroad.postAt(player.pos.x, player.pos.z, 2.6);
    if (atPost && input.hit('KeyE')) { openCraft(); [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('Trading post'))?.scrollIntoView({ block: 'start' }); }
    if (atDepot && input.hit('KeyE')) { openCraft(); [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('Freight office'))?.scrollIntoView({ block: 'start' }); }
    const atCooper = !build.active && active && !player.dead && !atStore && !!town.tiers.cooper && Math.hypot(player.pos.x - town.doors.cooper.x, player.pos.z - town.doors.cooper.z) < 2.3;
    if (atCooper && input.hit('KeyE')) { openCraft(); [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('Cooperage'))?.scrollIntoView({ block: 'start' }); }
    settlers.cap = tools.has('casks') ? 45 : 30; world.cropGrow = tools.has('rainbarrel') ? 0.75 : 1; // (the cooper's casks and rain barrel)
    const atStage = !build.active && active && !player.dead && !atStore && !riding && !!town.tiers.stable2 && Math.hypot(player.pos.x - town.doors.stable2.x, player.pos.z - town.doors.stable2.z) < 2.3;
    const stops = atStage ? stageStops() : null, stop = stops?.length ? stops[stageIdx % stops.length] : null;
    if (atStage && input.hit('KeyQ') && stops?.length) { stageIdx = (stageIdx + 1) % stops.length; sound.click(); }
    if (atStage && input.hit('KeyE')) {
      if (!stop) hud.toast('"The stage runs to any landmark you\'ve found out in the county, friend. Go find some, and I\'ll take you back any time."');
      else if ((inventory.dollars || 0) < 3) hud.toast('"Three dollars the fare." You\'re short.');
      else {
        inventory.dollars -= 3; const a = Math.atan2(town.at.z - stop.z, town.at.x - stop.x), x = stop.x + Math.cos(a) * 9, z = stop.z + Math.sin(a) * 9;
        player.pos.set(x, getHeight(x, z), z); player.anchor.copy(player.pos); stageFrom = { x, z }; journal.record('stage');
        sky.time = (sky.time + 0.03) % 1; sound.craft(); saveAll();
        hud.toast(`The coach rattles out of Paydirt Hollow and over the passes, and sets you down by ${stop.name}. The driver tips his hat: "Wait here when you're done and I'll carry you home." (E at this spot rides the coach back, $3.)`);
      }
    }
    // the coach home: back at the spot it set you down, wave it down (E) and ride back to the stables
    const atDrop = !!stageFrom && !atStage && !build.active && active && !player.dead && !riding && Math.hypot(player.pos.x - stageFrom.x, player.pos.z - stageFrom.z) < 4;
    if (atDrop && input.hit('KeyE')) {
      if ((inventory.dollars || 0) < 3) hud.toast(`"Three dollars the fare home." You're short; it's a long walk.`);
      else { inventory.dollars -= 3; const d = town.doors.stable2, x = d.x + town.toward.x * 2.5, z = d.z + town.toward.z * 2.5; player.pos.set(x, getHeight(x, z), z); player.anchor.copy(player.pos); stageFrom = null; sky.time = (sky.time + 0.03) % 1; sound.craft(); saveAll(); hud.toast('The coach comes rattling up the trail. You ride home over the passes and step down at the stage stables in Paydirt Hollow.'); }
    }
    // a gift at a camp's poles: two venison, a jar of honey or a hide left by the painted poles buys peace on their land
    // for three days (and the girl brings you a little something back). Striking one of them ends it.
    const poles = !build.active && active && !player.dead && !riding ? camp.atPoles(player.pos.x, player.pos.z) : null;
    const giftOf = poles && (inventory.venison >= 2 ? ['venison', 2, 'two cuts of venison'] : inventory.honey >= 1 ? ['honey', 1, 'a jar of honey'] : inventory.pelt >= 1 ? ['pelt', 1, 'a good hide'] : null);
    const atPeace = poles && (poles.peaceUntil || 0) > sky.day;
    if (poles && input.hit('KeyE') && poles.alarm !== 'fight') {
      if (atPeace) hud.toast(`You are welcome on their land for ${poles.peaceUntil - sky.day} more day${poles.peaceUntil - sky.day > 1 ? 's' : ''}.`);
      else if (!giftOf) hud.toast('A gift left at the poles would be welcome: two cuts of venison, a jar of honey or a good hide.');
      else {
        inventory[giftOf[0]] -= giftOf[1]; poles.gift(3); journal.record('peace'); inventory.rope = (inventory.rope || 0) + 2; sound.craft(); saveAll();
        hud.toast(`You leave ${giftOf[2]} at the foot of a painted pole and step back. Before long the elder comes out, looks at it a long while, and raises a hand. You are welcome on their land for three days. The girl runs out with a coil of braided rawhide (+2 rope).`);
      }
    }
    // the stage's passenger: once a day, a word with the lady off the coach marks a landmark you haven't seen on
    // your county map (the nearest one the county talk has heard of)
    const atRider = !build.active && active && !player.dead && !riding && town.rider && Math.hypot(player.pos.x - town.rider.x, player.pos.z - town.rider.z) < 2.4;
    if (atRider && input.hit('KeyE')) {
      if (riderDay === sky.day) hud.toast('"That’s all the news I carry, friend. Ask me again when the stage comes through tomorrow."');
      else {
        let best = null, bd = Infinity;
        for (const st of rumours.found.values()) { if (st.kind !== 'landmark' || landmarks.found.has(st.key) || !LANDMARK_INFO[st.mark]) continue; const d = Math.hypot(st.x - player.pos.x, st.z - player.pos.z); if (d < bd) { bd = d; best = st; } }
        riderDay = sky.day;
        if (!best) hud.toast('The lady laughs. "You’ve seen more of this county than I have, friend. Nothing I can tell you."');
        else {
          for (let i = -2; i <= 2; i++) for (let j = -2; j <= 2; j++) countyMap.explored.add(`${Math.floor(best.x / 16) + i},${Math.floor(best.z / 16) + j}`);
          hud.toast(`A lady in a feathered hat steps down off the stage, glad of someone to talk to. "We came by ${LANDMARK_INFO[best.mark].name} on the way in. Quite a sight." She sketches the way for you on the back of a handbill. (It’s marked on your county map, Tab.)`);
          sound.craft(); saveAll();
        }
      }
    }
    // feeding the ducks: a cob of corn tossed on the water near you, and the family paddles over for it
    const duckSpot = !build.active && active && !player.dead && !riding && inventory.corn >= 1 ? ducks.tossSpot(player.pos.x, player.pos.z) : null;
    if (duckSpot && input.hit('KeyE') && !ducks.fam.come) { inventory.corn--; ducks.feed(duckSpot); wadeRings.ring(duckSpot.x, duckSpot.z, 0.8); hud.toast('You shuck a cob and toss the kernels out on the water. The duck turns, quacks to her brood, and they come paddling over in a line.'); saveAll(); }
    // riding the Overland & Western: board her where she stands (a dollar's fare; from the depot she leaves at once),
    // ride on the coach's back platform, and step off at any stop she draws up at
    const trainStop = train.stoppedAt(), coachNear = trainStop && !riding && !train.passenger && Math.hypot(player.pos.x - train.cars[3].position.x, player.pos.z - train.cars[3].position.z) < 5;
    if (input.hit('KeyE') && active && !player.dead) {
      if (train.passenger && trainStop) { train.passenger = false; player.pos.copy(trainStop.platform); player.pos.y = getHeight(trainStop.platform.x, trainStop.platform.z) + 0.3; hud.toast(`You step down onto the platform at ${trainStop.name}. The conductor tips his cap.`); }
      else if (coachNear && !train.passenger) {
        if ((inventory.dollars || 0) < 1) hud.toast('The fare is a dollar, and your poke is empty.');
        else { inventory.dollars--; train.passenger = true; if (trainStop.depot) train.depart(); hud.toast(`You pay the conductor a dollar and climb up onto the coach's back platform. All aboard for ${train.nextStopName()}!`); saveAll(); }
      }
    }
    const atFire2 = !build.active && active && !player.dead && !riding && camp.fireAt(player.pos.x, player.pos.z);
    if (atFire2 && input.hit('KeyE')) { openCraft(); [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('Trading at the camp'))?.scrollIntoView({ block: 'start' }); }
    const atBank = !build.active && active && !player.dead && !atStore && !atBakery && !!town.tiers.bank && Math.hypot(player.pos.x - town.doors.bank.x, player.pos.z - town.doors.bank.z) < 2.3;
    if (atBank && input.hit('KeyE')) { openCraft(); [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith("Miners' bank"))?.scrollIntoView({ block: 'start' }); }
    if (atBakery && input.hit('KeyE')) { openCraft(); [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('Bakery'))?.scrollIntoView({ block: 'start' }); }
    // the saloon, once it's mended: a hot supper, and an old-timer at the bar with a tip for your map
    // the mended church: once a day the parson has a few kind words at the door. You go away mended, and your pans
    // run richer till sundown
    const atChurch = !build.active && active && !player.dead && atTownDoor('church', player.pos) && blessedDay !== sky.day;
    if (atChurch && input.hit('KeyE')) {
      blessedDay = sky.day; player.health = player.maxHealth; player.stamina = player.maxStamina;
      confetti.burst(_v.set(player.pos.x, player.pos.y + 1.6, player.pos.z), [0xf6efe0, 0xf0c840, 0xfff2b0], 10, 0.5); sound.lullaby?.();
      hud.toast(['"Bless you, prospector. The Lord keeps the gold where the honest can find it."', '"Go gently today, friend. Luck favours the patient pan."', '"May your riffles fill and your back hold out."'][sky.day % 3] + ' Mended, and blessed: richer pans today.');
      journal.record('church'); saveAll();
    }
    // the dawn bell: three slow tolls when the sun comes up, heard across the county
    if (town.tiers.church && sound.ready && !sound.muted && sky.time > 0.25 && sky.time < 0.3 && bellDay !== sky.day) { bellDay = sky.day; bellT = 0; }
    if (town.tiers.church && town.sunday && meetingDay !== sky.day) { meetingDay = sky.day; if (!town.far) hud.toast('Sunday morning. The bell has rung, and the families from Squatters’ Row walk up Main Street in their Sunday best for meeting at the church.'); }
    // the meeting's hymn: once the families stand in the churchyard, a slow plain tune in three (made up for the game,
    // a verse of 24 beats and a rest) on the pump organ, heard within about 40 m of the church door
    const gathered = town.sunday && town.tiers.church && (town.civilians || []).some((c) => c.atMeeting && c.goal && c.fig.root.position.distanceTo(c.goal) < 0.6);
    if (gathered) {
      const dd = Math.hypot(player.pos.x - town.doors.church.x, player.pos.z - town.doors.church.z), vol = Math.max(0, 1 - dd / 40);
      if ((hymnT -= dt) <= 0) {
        const [m, beats, b] = HYMN[hymnI % HYMN.length]; hymnI++;
        if (m) sound.hymn(hz(m), beats * 0.62, vol, b ? hz(b) : 0);
        hymnT = beats * 0.62;
      }
    } else { hymnI = 0; hymnT = 0; }
    // the rooster crows at sunup (heard near the farm): he draws himself up in the yard and lets fly
    if (sky.time > 0.245 && sky.time < 0.3 && crowDay !== sky.day && critters.rooster) {
      crowDay = sky.day; critters.rooster.crowT = 1.8;
      const d = Math.hypot(player.pos.x - critters.rooster.pos.x, player.pos.z - critters.rooster.pos.z); if (sound.ready && !sound.muted && d < 90) sound.crow(Math.max(0.1, 1 - d / 90));
    }
    if (bellT >= 0) {
      const before = bellT; bellT += dt;
      for (const k of [0, 2.2, 4.4]) if (before < k && bellT >= k) { const d = Math.hypot(player.pos.x - town.churchAt.x, player.pos.z - town.churchAt.z), vol = 0.12 * Math.max(0.25, 1 - d / 200), w = sound.ctx.currentTime; sound.pluck(147, w, vol, 4.5); sound.pluck(294, w, vol * 0.45, 3.5); sound.pluck(441, w, vol * 0.2, 2.5); }
      if (bellT > 5) bellT = -1;
    }
    const atSaloon = !build.active && active && !player.dead && atTownDoor('saloon', player.pos);
    // Miss Dolly out front of the mended Golden Garter has a word for you, once a day
    if (town.tiers.saloon && dollyDay !== sky.day && Math.hypot(player.pos.x - town.doors.saloon.x, player.pos.z - town.doors.saloon.z) < 6) { dollyDay = sky.day; hud.toast(['"Buy a girl a drink, sugar?" Miss Dolly winks.', "\"Lookin' lucky tonight, prospector.\"", "\"Come on in, the piano's warm.\""][sky.day % 3]); }
    if (atSaloon && input.hit('KeyE')) {
      if (inventory.dollars >= 3) {
        inventory.dollars -= 3; player.fullness = 100; player.health = Math.min(player.maxHealth, player.health + 20);
        // the nearest guarded treasure you haven't seen yet, pencilled onto your map
        const pcx = Math.floor(player.pos.x / CHUNK), pcz = Math.floor(player.pos.z / CHUNK); let tip = null, td = Infinity;
        for (let dz = -8; dz <= 8; dz++) for (let dx = -8; dx <= 8; dx++) for (const st of world.sitesFor(pcx + dx, pcz + dz)) {
          if (st.kind === 'landmark' || countyMap.seen(st.x, st.z)) continue;
          const d = Math.hypot(st.x - player.pos.x, st.z - player.pos.z); if (d < td) { td = d; tip = st; }
        }
        let said = 'The stew is hot and the bread is fresh. An old-timer at the bar has nothing new to tell you tonight.';
        if (tip) {
          for (let a = 0; a < Math.PI * 2; a += 0.8) for (const r of [0, 14]) countyMap.update({ x: tip.x + Math.cos(a) * r, z: tip.z + Math.sin(a) * r });
          const dir = ['east', 'south-east', 'south', 'south-west', 'west', 'north-west', 'north', 'north-east'][Math.round(Math.atan2(tip.z - player.pos.z, tip.x - player.pos.x) / (Math.PI / 4) + 8) % 8];
          const what = { vein: 'an iron vein the coyotes keep', grove: 'a wild-hive grove an old boar watches', thicket: 'a berry thicket full of coyotes', sang: 'wild sang in the Hollows (and something that walks behind you)', silver: 'silver in the red rock, where the gougers graze', pearl: 'pearls in the fen, if the Hodag lets you', geode: 'thunder eggs on the prairie, coyote country', amber: 'amber on the old pines, wampus cat country' }[tip.kind] || 'something worth the walk';
          said = `A hot supper of stew and bread. An old-timer at the bar leans over: "${what[0].toUpperCase() + what.slice(1)}, ${Math.round((td * 1.3) / 10) * 10} paces ${dir} of town." He pencils it onto your map.`;
        }
        hud.toast(said); sound.craft(); journal.record('saloon'); saveAll();
      } else hud.toast('"Supper\'s three dollars, friend." The barkeep goes back to polishing a glass.');
    }
    // the livery: buy a saddle horse
    const atLivery = !build.active && active && !player.dead && !horse && atTownDoor('livery', player.pos);
    if (atLivery && input.hit('KeyE')) {
      if (inventory.dollars >= 35) {
        inventory.dollars -= 35; const d = town.doors.livery; makeHorse(d.x + town.toward.x * 2.5, d.z + town.toward.z * 2.5);
        hud.toast('The liveryman leads out a chestnut mare with a white blaze and a red saddle blanket. "Her name\'s Biscuit. She\'s steady." Press X beside her to get up, and X again to get down. From anywhere else, X whistles her over.');
        sound.craft(); journal.record('horse'); saveAll();
      } else hud.toast(`"A good saddle horse is thirty-five dollars, and she's worth every cent." You've $${inventory.dollars}.`);
    }
    // getting up and down: X beside her; riding, she carries you at nearly twice the pace
    if (horse && active && !player.dead && !build.active && input.hit('KeyX')) {
      if (riding) { riding = false; player.riding = player.avatar.riding = false; horse.group.position.set(player.pos.x + Math.cos(player.facing) * 1.2, player.pos.y, player.pos.z - Math.sin(player.facing) * 1.2); sound.place(); saveAll(); }
      else if (Math.hypot(player.pos.x - horse.group.position.x, player.pos.z - horse.group.position.z) < 2.6) { riding = true; player.riding = player.avatar.riding = true; horse.called = false; player.pos.x = horse.group.position.x; player.pos.z = horse.group.position.z; sound.place(); }
      else { // too far to get up: a two-note whistle, and she lifts her head and comes to you
        horse.called = true; sound.tone({ freq: 1500, to: 1900, dur: 0.18, vol: 0.12 }); sound.tone({ freq: 1900, to: 1300, dur: 0.28, vol: 0.12, when: 0.24 });
        const far = Math.hypot(player.pos.x - horse.group.position.x, player.pos.z - horse.group.position.z);
        if (far > 140) { for (let k = 0; k < 12; k++) { const a = Math.random() * Math.PI * 2, x = player.pos.x + Math.cos(a) * 30, z = player.pos.z + Math.sin(a) * 30; if (!impassable(x, z) && !isWater(x, z)) { horse.group.position.set(x, 0, z); break; } } } // (from out of earshot she comes up over the rise)
        hud.toast(far > 40 ? 'You whistle for Biscuit. Away off, she lifts her head and comes at a gallop.' : 'You whistle, and Biscuit comes trotting over.');
      }
    }
    const atSmithy = !build.active && active && !player.dead && atTownDoor('smithy', player.pos);
    if (atSmithy && input.hit('KeyE')) {
      openCraft(); journal.record('smithy');
      [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith('Blacksmith'))?.scrollIntoView({ block: 'start' });
    }
    if (atTinker && !bed && input.hit('KeyE')) {
      openCraft(); journal.record('tinker');
      [...panel.el.querySelectorAll('h3')].find((h) => h.textContent.startsWith("Tinker"))?.scrollIntoView({ block: 'start' }); // open at his wares
    }
    if (bed && input.hit('KeyE')) {
      if (!sleepy) hud.toast('Not sleepy yet; the bed will keep till nightfall.');
      else if (!sleepTimer) {
        sleepTimer = 2.6;
        sleepEl.classList.add('show');
        sound.lullaby();
      }
    }
    if (sleepTimer > 0) {
      sleepTimer -= dt;
      if (sleepTimer < 1.3 && sleepEl.classList.contains('show')) {
        const endedDay = sky.day;
        if (sky.time > 0.5) sky.day += 1;
        sky.time = 0.27;
        player.health = player.maxHealth; player.stamina = player.maxStamina;
        sleepEl.classList.remove('show');
        journal.record('sleep');
        player.fullness = Math.max(0, player.fullness - 15); // you wake up hungry
        showAlmanac(endedDay);
        const inn = hotelNight; hotelNight = false;
        if (inn) { // a feather bed at the Grand Hotel: you wake fed and warm, a spring in your step
          player.fullness = Math.max(player.fullness, 80); player.staminaBoost = Math.max(player.staminaBoost || 0, 200);
          hud.toast(`Day ${sky.day}: you wake in a feather bed at the Grand Hotel, sun through lace curtains. Ham, eggs and hot coffee in the dining room, and out into the street fed and rested.`);
        }
        // a good woodpile near the bed keeps the stove going all night: you wake warm, with a well-rested spring in your step
        const stove = !inn && build.pieces.find((q) => q.type === 'woodpile' && (q.stock || 0) >= 2 && Math.hypot(q.x - player.pos.x, q.z - player.pos.z) < 30);
        if (stove) { stove.stock -= 2; player.staminaBoost = Math.max(player.staminaBoost, 300); player.stamina = 300; journal.record('warmnight'); hud.toast(`Day ${sky.day}: the stove burned two logs from the woodpile all night. You wake warm as toast, ready for anything.`); }
        else if (!inn) hud.toast(`Day ${sky.day}: the rooster crows and you wake well rested.`);
        saveAll();
      }
      if (sleepTimer <= 0) sleepTimer = 0;
    }
    if (build.active && active) {
      if (input.hit('KeyQ')) { build.selected = (build.selected + PIECE_ORDER.length - 1) % PIECE_ORDER.length; build.roofManual = false; }
      if (input.hit('KeyE')) { build.selected = (build.selected + 1) % PIECE_ORDER.length; build.roofManual = false; }
      if (input.hit('KeyR')) {
        // rotating a roof by hand starts from the auto-picked direction and switches auto off
        if (build.type === 'roof' && build.preview) build.rot = build.preview.rot;
        build.rot = (build.rot + 1) % 4;
        if (build.type === 'roof') build.roofManual = true;
      }
      // holding a button repeats: place / remove every 0.3 s
      placeCD -= dt;
      if (input.clicked || (input.mouseDown && placeCD <= 0)) {
        placeCD = 0.3;
        const ok = !!build.preview?.valid;
        const placedType = build.preview?.type;
        const msg = build.place(inventory);
        if (ok) journal.record(`build:${placedType}`);
        if (msg && (input.clicked || ok)) hud.toast(msg);
        if (ok) { player.avatar.startSwing(); sound.place(); saveAll(); } else if (msg && input.clicked) sound.denied();
      }
      if (input.rightClicked || (input.rightDown && placeCD <= 0)) {
        placeCD = 0.3;
        const msg = build.remove(inventory);
        if (msg) { hud.toast(msg); sound.tear(); }
      }
    }
    // fishing takes the click when there's water ahead and a pole in the pack
    const canAct = active && !build.active && !player.dead;
    const fishR = fishing.update(dt, player, input, canAct, canAct && !player.iceOn ? fishing.spot(player, held === 'rod' ? tools : NO_TOOLS) : null); // no fishing through the ice
    // the bow: hold the button to draw (a reticle rides out along your aim and tightens), let go to loose
    // the guns work the same way: hold to raise and steady (the reticle), let go to fire. The six-shooter holds six;
    // the buffalo rifle one. Empty, it reloads from your cartridges (bought by the box at the general store).
    const W = held === 'revolver' ? REVOLVER : held === 'rifle' ? RIFLE : BOW, gun = W !== BOW;
    if (gun) {
      const g = guns[held];
      if (g.reload > 0) { g.reload -= dt; if (g.reload <= 0) { const n = Math.min(g.size - g.loaded, inventory.cartridges || 0); g.loaded += n; inventory.cartridges -= n; sound.knock(); } }
      if (active && input.hit('KeyR') && g.loaded < g.size && g.reload <= 0 && (inventory.cartridges || 0) > 0) g.reload = g.time;
    }
    const gunReady = !gun || (guns[held].loaded > 0 && guns[held].reload <= 0);
    const bowUp = !build.active && active && !fishR.engaged && (held === 'bow' || gun) && !player.dead; // (from the saddle too)
    if (bowUp && gun && !gunReady && input.clicked) { if (guns[held].reload <= 0 && !(inventory.cartridges > 0)) { hud.toast('Click. Out of cartridges: buy a box at the general store.'); sound.denied(); } }
    if (bowUp && gunReady && input.mouseDown) {
      camera.getWorldDirection(_hf); _hf.y = 0; _hf.normalize(); player.aiming = true;
      hunting.aim(dt, camera, _hp.set(player.pos.x + _hf.x * 0.5, player.pos.y + (riding ? 2.7 : 1.45), player.pos.z + _hf.z * 0.5), critters, renderer.domElement, world, W);
    } else if (hunting.charge > 0) {
      const ad = hunting.aimDir || _hf; player.aiming = false;
      if (bowUp && gunReady && hunting.loose(_hp.set(player.pos.x + ad.x * 0.5, player.pos.y + (riding ? 2.7 : 1.45), player.pos.z + ad.z * 0.5), W)) {
        player.avatar.startCast();
        if (gun) { const g = guns[held]; g.loaded--; sound.bang(held === 'rifle'); if (!g.loaded) { if (inventory.cartridges > 0) g.reload = g.time; else hud.toast(held === 'rifle' ? 'That was your last cartridge: buy a box at the general store.' : 'The cylinder\'s empty and so is your cartridge box: buy more at the general store.'); } }
        else sound.tear();
      }
      else hunting.ease();
    } else player.aiming = false;
    if (bowUp) { /* (the bow never swings like an axe) */ } else if (!build.active && active && !fishR.engaged && held !== 'rod' && held !== 'bow' && held !== 'revolver' && held !== 'rifle' && (input.clicked || input.mouseDown)) player.avatar.startSwing(); // hold to keep swinging (never with the fishing pole)
    else if (!build.active && active && !fishR.engaged && held === 'rod' && input.clicked && !player.dead) hud.toast('Stand on the bank facing open water to cast (or pick up another tool with the number keys).');
    if (active && input.hit('KeyF')) {
      const food = [['johnnycake', 40, 120, 'Maple johnnycakes, dripping with syrup'], ['applepie', 55, 110, 'A slice of apple pie, the crust just so'], ['honeycake', 60, 120, 'Honey cake — sweet as a summer fair'], ['roast', 50, 110, 'Venison roast with pan gravy, a hunter\'s supper'], ['pie', 50, 100, 'Pumpkin pie, like Grandma made'], ['applecrisp', 45, 90, 'Warm apple crisp with a drizzle of honey'], ['flapjacks', 40, 90, 'A stack of flapjacks, hot off the skillet'], ['stew', 40, 60, 'Toadstool stew warms you through'], ['biscuits', 35, 60, 'Buttermilk biscuits, light as a feather'], ['bread', 35, 60, 'A thick slice of farmhouse bread and butter'], ['fishfry', 35, 60, 'Pan-fried fish, crisp at the edges'], ['cornbread', 30, 45, 'Skillet cornbread, warm and crumbly'], ['apples', 6, 40, 'A crisp, tart apple'], ['berries', 8, 90, 'A handful of berries']]
        .find(([k]) => inventory[k] > 0);
      if (food) {
        const [k, heal, boost, text] = food;
        inventory[k] -= 1;
        player.health = Math.min(player.maxHealth, player.health + heal);
        player.staminaBoost = Math.max(player.staminaBoost, boost);
        player.stamina = 300; // (clamped to whatever the belly allows)
        const fill = Math.round(heal * 0.8); // a hearty dish fills you a good deal more than a handful of berries
        player.fullness = Math.min(100, player.fullness + fill);
        hungerWarned = player.fullness >= 30 ? 0 : hungerWarned;
        hud.toast(`${text} (+${heal} health, +${fill} fullness)`);
        sound.eat();
      } else hud.toast('Nothing to eat');
    }

    // number keys: in build mode they pick a shelf of the build menu; otherwise a tool from the tool bar
    for (let i = 0; i < Math.max(PIECE_GROUPS.length, TOOLBAR.length); i++) {
      if (!input.hit(`Digit${i + 1}`)) continue;
      if (build.active) { if (PIECE_GROUPS[i]) { build.selected = PIECE_ORDER.indexOf(PIECE_GROUPS[i][1][0]); build.roofManual = false; } }
      else if (TOOLBAR[i]) pickTool(TOOLBAR[i].id);
    }
    if (active && input.hit('KeyI')) { document.getElementById('pack').classList.toggle('show'); sound.tear(); }
    if (active && (input.hit('Tab') || input.hit('KeyM'))) { // M (or Tab): the county map
      // the guarded sites in explored country (site layout is deterministic, so they can be looked up)
      const sites = [], orchards = [];
      if (!countyMap.open) {
        const r = 9, pcx = Math.floor(player.pos.x / CHUNK), pcz = Math.floor(player.pos.z / CHUNK); // (out past the sheet's edge too, for the nearest iron)
        for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) {
          const x0 = (pcx + dx) * CHUNK + CHUNK / 2, z0 = (pcz + dz) * CHUNK + CHUNK / 2;
          if (!countyMap.seen(x0, z0)) { for (const s of world.sitesFor(pcx + dx, pcz + dz)) if (s.kind === 'vein') sites.push({ ...s, rumour: true }); } // (the iron veins the assayer has heard of, inked faint till you've seen them)
          else { sites.push(...world.sitesFor(pcx + dx, pcz + dz).map((s) => (s.kind === 'landmark' ? { ...s, foundName: landmarks.found.has(s.key) ? LANDMARK_INFO[s.mark].name.replace(/^the /, '').replace(/^./, (c) => c.toUpperCase()) : null } : s))); const o = world.orchardFor(pcx + dx, pcz + dz); if (o && !orchards.some((q) => Math.hypot(q.x - o.x, q.z - o.z) < 25)) orchards.push(o); } // one mark per orchard
        }
      }
      for (const c of camp.list) sites.push({ kind: 'camp', x: c.at.x, z: c.at.z, rumour: true, r: 46, peace: Math.max(0, (c.peaceUntil || 0) - sky.day) }); // (their lands: folks in town know where they lie)
      countyMap.toggle({ player, camera, home: home.spawn, sites, tinker, orchards, pieces: build.pieces, fair: fair.open(sky) ? fair.at : null, star: fallingStars.state === 'landed' ? fallingStars.at : null, town: { at: town.at, along: town.along, toward: town.toward, offs: [0, ...(town.opened || []).map((k) => town.streetOffs[k])], mended: Object.values(town.tiers).filter(Boolean).length } });
      sound.tear();
    }
    if (active && input.hit('KeyG')) {
      if (!tools.has('kite')) hud.toast('Make a paper kite at a workbench first (C).');
      else if (!kite.flying && weather.rain > 0.3) hud.toast('Too wet for kite-flying. Wait for the shower to pass.');
      else { kite.toggle(); sound.tear(); if (kite.flying) { journal.record('kite'); hud.toast('Up she goes! The kite climbs away on the west wind.'); } }
    }
    if (active && input.hit('KeyH')) { calendar.classList.toggle('show'); if (calendar.classList.contains('show')) renderCalendar(); sound.tear(); }
    else if (calendar.classList.contains('show') && (calT += dt) > 1) { calT = 0; renderCalendar(); } // keep it current while open
    if (active && input.hit('KeyK')) snapWanted = true;
    if (input.hit('KeyN')) hud.toast(sound.toggleMute() ? 'Sound off' : 'Sound on'); // N: sound on/off
    if (input.hit('F4')) devCash();
    if (input.hit('F3')) { document.body.classList.toggle('dev'); try { localStorage.setItem('paperfjord.dev', document.body.classList.contains('dev') ? '1' : ''); } catch { /* ignore */ } }
    if (input.hit('KeyO')) {
      // cycle: auto → high → medium → low → auto
      const order = ['auto', 'high', 'medium', 'low'];
      const cur = quality.mode === 'auto' ? 'auto' : quality.level;
      const next = order[(order.indexOf(cur) + 1) % order.length];
      if (next === 'auto') { quality.mode = 'auto'; quality.lowSeconds = 0; applyQuality('high'); }
      else { quality.mode = 'manual'; applyQuality(next); }
      hud.toast(`Graphics: ${next}`);
    }
    if (input.hit('KeyP')) {
      post.u.dofEnabled.value = post.u.dofEnabled.value > 0.5 ? 0 : 1;
      hud.toast(post.u.dofEnabled.value ? 'Depth of field on' : 'Depth of field off');
    }

    // knocked out: a few seconds of quiet, then you wake by the farmhouse
    if (deathTimer > 0) {
      deathTimer -= dt;
      if (deathTimer <= 0) {
        player.pos.copy(home.spawn);
        player.anchor.copy(player.pos);
        player.health = 60; player.dead = false; player.hurtTimer = 0;
        hud.toast('You wake by the farmhouse, a little worse for wear.');
      }
    }
    // the porch rocker: E to sit and let time drift by (about 24× faster); E again, or a step, to get up
    const moveKeys = ['KeyW', 'KeyA', 'KeyS', 'KeyD'].some((k) => input.down(k));
    if (porch.sitting && (input.hit('KeyE') || moveKeys || !active)) { porch.sitting = false; hud.toast('You stretch, and get up from the rocker.'); }
    else if (!porch.sitting && active && !build.active && !player.dead && porch.near(player.pos) && input.hit('KeyE')) {
      porch.sitting = true; hud.toast('You settle into the rocker and watch the day drift by.');
    }
    if (porch.sitting) sky.time += (dt * (WARP - 1)) / DAY_LENGTH;
    player.thrift = tools.has('boots') ? 0.67 : 1;
    player.avatar.seated = porch.sitting; // (the model sits in the rocker with its sit clip)
    let { connected } = player.update(dt, input, world, active && !player.dead && !porch.sitting && !train.passenger); // (aboard the train you ride, not walk)
    porch.update(dt, player);

    // what's in front of us: a resource or a built piece, whichever is closer
    let target = null, pieceT = null, enemyT = null;
    if (active && !build.active && !player.dead) {
      enemyT = enemies.findTarget(player, REACH + (held === 'spear' ? 0.9 : 0));
      target = enemyT ? null : player.findTarget(world);
      const f = player.forward(_f);
      pieceT = enemyT ? null : build.findTarget(player.pos, f.x, f.z, REACH);
      if (pieceT && target) {
        const tDist = Math.hypot(target.x - player.pos.x, target.z - player.pos.z) - RESOURCE_TYPES[target.type].radius * target.scale;
        if (pieceT.dist < tDist) target = null; else pieceT = null;
      }
    }
    const stoneTarget = ['rock', 'ore', 'quartz'].includes(target?.type) || (pieceT && STONE_PIECES.has(pieceT.piece.type));
    if (!build.active) player.avatar.tool = held === 'hands' ? 'none' : held;
    player.avatar.hasBow = tools.has('bow'); // (his quiver)
    player.avatar.aiming = !!player.aiming; // (a gun comes up level while he aims)
    // E picks soft things whole (berries, toadstools, grass, apples, corn, wheat, a hive's honey), whatever's in
    // your hand; but only when nothing else around wants E (last frame's prompt says so)
    // tapping a maple for sap: E at a maple, once a tree a day
    if (!enemyT && target?.type === 'maple' && eFree && !build.active && input.hit('KeyE')) {
      const key = `${Math.round(target.x)},${Math.round(target.z)}`;
      if (tapped.get(key) === sky.day) hud.toast('This maple has given its sap today. Try another, or come back tomorrow.');
      else {
        tapped.set(key, sky.day); inventory.sap = (inventory.sap || 0) + 1; sound.plop();
        hud.toast(settlers.discover('sap') ? 'You knock in a spile and hang a bucket: drip, drip... your first sap! Now you can build a sugar shack (B, Works shelf) for a settler to run.' : 'Drip, drip: a bucket of maple sap (+1 sap).');
      }
    }
    const ePick = !enemyT && !!target && SOFT.has(target.type) && eFree && !build.active && input.hit('KeyE');
    if (ePick) connected = true;
    if (connected && enemyT) {
      const e = enemyT.enemy;
      guardianHit(e, edge('enemy')); blow();
    } else if (connected && !enemyT && camp.findTarget(player, REACH + (held === 'spear' ? 0.9 : 0))) {
      const w = camp.findTarget(player, REACH + (held === 'spear' ? 0.9 : 0)); blow(); sound.chop();
      camp.damage(w, Math.max(2, edge('enemy')), campHooks, raidHooks);
      confetti.burst(_v.set(w.pos.x, w.pos.y + 1.1, w.pos.z), [0xa8352a, 0xefe2c4], 8, 0.6);
    } else if (connected && target && damageFor(target.type, tools, held) === 0) {
      hud.toast(wrongTool(target.type));
      sound.denied();
    } else if (connected && target) {
      const def = RESOURCE_TYPES[target.type];
      const r = world.hit(target, player.pos.x, player.pos.z, ePick ? target.hp : edge(target.type));
      if (!ePick && !SOFT.has(target.type)) blow();
      confetti.burst(_v.set(target.x, target.y + 1.0, target.z).lerp(player.pos, 0.35).setY(player.pos.y + 1.1), def.chips, 7, 0.6);
      if (['rock', 'ore', 'quartz'].includes(target.type)) sound.mine(); else if (['bush', 'grass', 'mushroom', 'hive', 'clay', 'corn', 'pumpkin', 'apples', 'stook'].includes(target.type)) sound.pick(); else sound.chop();
      if (r.destroyed) {
        if (def.falls) sound.treeFall();
        const ev = ['rock', 'ore', 'quartz'].includes(target.type) ? 'mine' : target.type === 'bush' ? 'pick' : def.item === 'wood' ? 'chop' : null;
        if (ev) journal.record(ev);
        if (def.item === 'satchel') {
          // what somebody left behind, with a word from them
          const SATCHELS = [
            [{ iron: 2 }, 'two bars of iron wrapped in a note: "For the next fellow. —Amos"'],
            [{ honey: 2, berries: 4 }, 'a jar of honey, a twist of berries and a pressed clover'],
            [{ pelt: 2 }, 'two good pelts and a tally of coyotes, crossed out'],
            [{ rope: 3 }, 'three coils of rope and a map of the creek, mostly wrong'],
            [{ ore: 3 }, 'a sack of ore and a pick-handle with no pick'],
            [{ honeycake: 1, egg: 2 }, 'a honey cake in a handkerchief and two eggs, still whole'],
          ];
          const [gift, text] = SATCHELS[Math.floor(Math.random() * SATCHELS.length)];
          for (const k in gift) inventory[k] = (inventory[k] || 0) + gift[k];
          journal.record('satchel');
          hud.toast(`Inside the old satchel: ${text}.`);
          sound.craft();
          saveAll();
        } else {
        journal.record(`gather:${def.item}`);
        const amount = r.amount + (r.item === 'wood' && landmarks.blessed ? 1 : 0) /* Babe's blessing */ + (r.item === 'berries' && tools.has('basket') ? 1 : 0) + ((sky.day + 1) % 7 === 0 && sky.night > 0.5 ? 1 : 0); // the harvest moon's bounty
        inventory[r.item] += amount;
        const firstFind = settlers.discover(r.item);
        if (firstFind && WORKS[r.item]) hud.toast(`Your first ${r.item}! Now you can build a ${WORKS[r.item][1]} (B, Works shelf) for a settler to run.`);
        if (firstFind && TREASURE_LORE[r.item]) { hud.toast(TREASURE_LORE[r.item]); sound.craft(); }
        hud.toast(`+${amount} ${r.item}`);
        saveAll();
        }
      }
    } else if (connected && pieceT) {
      const p = pieceT.piece, stone = STONE_PIECES.has(p.type);
      const r = build.damage(p, Math.max(1, edge(stone ? 'stonepiece' : 'tree')), inventory);
      const at = _v.set(p.x, p.y + 1.0, p.z).lerp(player.pos, 0.4).setY(player.pos.y + 1.1);
      confetti.burst(at, build.chipsFor(p.type), r.destroyed ? 40 : 7, r.destroyed ? 1.1 : 0.6);
      if (stone) sound.mine(); else sound.knock();
      if (r.destroyed) {
        sound.tear();
        hud.toast(`Broke ${PIECES[p.type].name.toLowerCase()} (+${costText(r.refund)})`);
        saveAll();
      }
    }
    // two lines of hints: what E does here (sleep, milk, gather, trade, tell a tale…) above what the mouse does
    let ePrompt = '';
    const pieceType = pieceT?.piece.type;
    if (mail.open) ePrompt = '[E] Fold the letter away';
    else if (atRing) ePrompt = '[E] Gather the fairy ring of toadstools';
    else if (atDoor && grandma.home(sky)) { const w = wishFor(sky.day), have = Object.entries(w.cost).every(([k, n]) => (inventory[k] || 0) >= n); ePrompt = have && grandma.wishDay !== sky.day ? `[E] Knock and give Grandma ${w.ask.split(' for ')[0]}` : grandma.pieDay !== sky.day ? '[E] Knock at the door (Grandma is up)' : ''; }
    else if (gp) ePrompt = (gp.stage || 0) >= GIANT_STAGES ? '[E] Cut your prize giant pumpkin' : gp.tendDay === sky.day ? `Your giant pumpkin (${gp.stage || 0}/${GIANT_STAGES}): tended today` : `[E] Tend the giant pumpkin (${gp.stage || 0}/${GIANT_STAGES})`;
    else if (pile) ePrompt = inventory.wood > 0 && (pile.stock || 0) < PILE_MAX ? `[E] Stack firewood on the woodpile (${pile.stock || 0}/${PILE_MAX})` : (pile.stock || 0) > 0 && inventory.wood === 0 ? `[E] Take 4 logs from the woodpile (${pile.stock} stacked)` : `The woodpile (${pile.stock || 0}/${PILE_MAX})`;
    else if (atCalf) ePrompt = '[E] Lead the lost calf home';
    else if (feeder) ePrompt = feeder.stock ? `[E] Top up the bird feeder (${feeder.stock} day${feeder.stock > 1 ? 's' : ''} of seed left)` : '[E] Fill the bird feeder (a cob of corn or 2 handfuls of berries)';
    else if (atJohnny) ePrompt = johnny.talked ? '[E] Say so long to Johnny Appleseed' : '[E] Pass the time of day with Johnny Appleseed';
    else if (press) ePrompt = inventory.apples >= 4 ? '[E] Press 4 apples into a mug of warm cider' : 'The cider press: bring 4 apples';
    else if (guardNear) ePrompt = canOffer ? `[E] ${peace.give}` : `[E] ${peace.hint}`;
    else if (atStar) ePrompt = '[E] Pick up the fallen star';
    else if (atCat) ePrompt = '[E] Give Marmalade a scratch under the chin';
    else if (bugAt >= 0) ePrompt = `[E] Catch the lightning bug in your jar (${jar.count}/${JAR_MAX})`;
    else if (atMail) ePrompt = mail.waiting ? '[E] The flag is up: take the letter from the mailbox' : 'The mailbox: the carrier comes by mid-morning';
    else if (myTree) ePrompt = myTree.stock ? `[E] Shake your apple tree (${myTree.stock} ripe)` : 'Your apple tree: fresh apples by morning';
    else if (porch.sitting) ePrompt = '[E] Get up from the rocker (time is drifting by)';
    else if (atDance) ePrompt = '[E] Join the barn dance';
    else if (atStick) ePrompt = '[E] Throw the stick for Old Blue';
    else if (atDog) ePrompt = '[E] Give Old Blue a scratch behind the ears';
    else if (porch.near(player.pos)) ePrompt = '[E] Sit in the rocking chair and watch the day go by';
    else if (bed || pieceType === 'bed') ePrompt = sleepy ? '[E] Sleep till morning' : 'A quilted bed: sleep here once night falls';
    else if ((atFire || pieceType === 'campfire') && !tales.open) ePrompt = evening ? '[E] Sit by the fire and tell a tall tale' : 'A good fire. Tall tales are for after dark.';
    else if (beast) ePrompt = beastReady ? (beast.type === 'cow' ? '[E] Milk the cow' : '[E] Shear the sheep') : beast.type === 'cow' ? 'Already milked today' : 'Fleece still growing back';
    else if (skep) ePrompt = skep.stock ? `[E] Take ${skep.stock} honey from the bee skep` : 'The bees are busy filling the comb';
    else if (atCoop) ePrompt = coop.eggs ? `[E] Gather ${coop.eggs} egg${coop.eggs > 1 ? 's' : ''} from the nesting box` : 'The nesting box is empty till morning';
    else if (atTinker) ePrompt = '[E] Trade with the tinker';
    else if (atLivery) ePrompt = `[E] Buy a saddle horse at the livery: $35 (you have $${inventory.dollars})`;
    else if (horse && !riding && Math.hypot(player.pos.x - horse.group.position.x, player.pos.z - horse.group.position.z) < 2.6) ePrompt = '[X] Get up on Biscuit';
    else if (atSmithy) ePrompt = `[E] The blacksmith's: tools, and every edge ground sharp ($${inventory.dollars} in your poke)`;
    else if (atChurch) ePrompt = '[E] A word with the parson (mends you; richer pans today)';
    else if (atSaloon) ePrompt = `[E] Hot supper at the saloon, and the old-timers' talk ($3; you have $${inventory.dollars})`;
    else if (atJail) ePrompt = bounty ? `[E] See the sheriff about the $${bounty.pay} bounty` : '[E] Ask the sheriff if there\'s a bounty posted';
    else if (atHall) ePrompt = hallOpen ? (inventory.hallDay === sky.day ? '[E] The dance hall (you\'ve danced tonight)' : '[E] Step in and dance a reel') : '[E] The dance hall (opens at dusk)';
    else if (atClaim) ePrompt = claim.stock.gold || claim.stock.silver ? `[E] Empty the ore cart (${claim.stock.gold} gold${claim.stock.silver ? `, ${claim.stock.silver} silver` : ''})` : claim.dugDay === sky.day ? 'Your claim: worked today' : '[E] Work your claim';
    else if (atPost) ePrompt = `[E] Trade at the ${atPost.name} trading post`;
    else if (atDepot) ePrompt = railroad.freight ? `[E] The freight office (${railroad.freight} crate${railroad.freight > 1 ? 's' : ''} waiting for the train)` : '[E] The freight office: ship your goods East';
    else if (atCooper) ePrompt = `[E] Step into the cooperage ($${inventory.dollars} in your poke)`;
    else if (atStage) ePrompt = stop ? `[E] Take the stage to ${stop.name}: $3${stops.length > 1 ? ' · [Q] next stop' : ''}` : '[E] The stage line (runs to landmarks you\'ve found)';
    else if (atDrop) ePrompt = '[E] Wave down the coach home to Paydirt Hollow: $3';
    else if (train.passenger) ePrompt = trainStop ? `[E] Get off at ${trainStop.name}` : `Riding the Overland & Western · next stop ${train.nextStopName()}`;
    else if (coachNear) ePrompt = trainStop.depot ? '[E] Board the train ($1): she leaves at once' : `[E] Board the train at ${trainStop.name} ($1)`;
    else if (duckSpot && !ducks.fam.come) ePrompt = '[E] Toss the ducks some corn';
    else if (atRider) ePrompt = riderDay === sky.day ? 'The lady off the stage, stretching her legs' : '[E] Ask the stage passenger for news';
    else if (atFire2) ePrompt = '[E] Sit at their fire and trade';
    else if (poles && poles.alarm !== 'fight') ePrompt = atPeace ? `Their land: welcome for ${poles.peaceUntil - sky.day} more day${poles.peaceUntil - sky.day > 1 ? 's' : ''}` : giftOf ? `[E] Leave a gift at the poles (${giftOf[2]}): three days' peace` : 'A gift left at the poles would be welcome (venison, honey or a hide)';
    else if (atDry) ePrompt = `[E] Step into the dry goods ($${inventory.dollars} in your poke)`;
    else if (atWire) ePrompt = inventory.wireDay === sky.day ? '[E] The telegraph office (today\'s order is filled)' : `[E] Today's wire: ${wire[2]} wants ${wire[0]}, $${wire[1]} each (you have ${inventory[wire[0]] || 0})`;
    else if (atHotel) ePrompt = sleepy ? '[E] Take a room for the night at the Grand Hotel: $4, breakfast included' : '[E] The Grand Hotel (rooms from sundown)';
    else if (atOpera) ePrompt = curtain ? (operaDay === sky.day ? '[E] The opera house (seen tonight\'s show)' : '[E] A seat for tonight\'s show: $3') : '[E] Read the playbill (curtain at sundown)';
    else if (atFeed) ePrompt = `[E] Step into the feed & grain ($${inventory.dollars} in your poke)`;
    else if (atBarber) ePrompt = inventory.groomedDay === sky.day ? '[E] The barber (you\'re spruced up for today)' : '[E] A shave and a haircut: $2';
    else if (atBank) ePrompt = `[E] Step up to the teller's window ($${inventory.dollars} in your poke, $${inventory.savings || 0} in the bank)`;
    else if (atBakery) ePrompt = `[E] Step into the bakery ($${inventory.dollars} in your poke)`;
    else if (atStore) ePrompt = `[E] Shop at the general store ($${inventory.dollars} in your poke)`;
    else if (atFair) ePrompt = '[E] Enter your goods at the County Fair';
    else if (mendE) ePrompt = `[E] Mend the ${project.name}: $${project.cost} (you have $${inventory.dollars})`;
    else if (wanter) ePrompt = `[E] ${wanter.name} wants ${wanter.want[1]} ${wanter.want[0]} ($${wanter.want[2]}): you have ${inventory[wanter.want[0]] || 0}`;
    else if (atGlint) ePrompt = '[E] Pick up the glint in the gravel';
    else if (atBunk) ePrompt = `[E] Build a bunkhouse for your hands: $${BUNK_COST} (you have $${inventory.dollars})`;
    else if (atCellar) ePrompt = cellar.built ? '[E] Take food from the root cellar' : `[E] Dig a root cellar: $${CELLAR_COST} (you have $${inventory.dollars})`;
    else if (player.climbing) ePrompt = 'Climbing...';
    else if (ladder) ePrompt = ladder.up ? `[E] Climb ${ladder.ladder.name}` : '[E] Climb down';
    else if (assayE) ePrompt = inventory.gold > 0 || inventory.silver > 0 ? `[E] Sell to the assayer: ${[inventory.gold ? `${inventory.gold} gold` : '', inventory.silver ? `${inventory.silver} silver` : ''].filter(Boolean).join(', ')} (about $${inventory.gold * 4 + (inventory.silver || 0) * 5})` : 'The assay office: bring gold here to be weighed';
    else if (panT > 0) ePrompt = 'Swirling the pan, washing the gravel out over the lip...';
    else if (panE) ePrompt = '[E] Pan the shallows for colour';
    else if (grind) ePrompt = `[E] Sharpen your tools on the grindstone (1 stone)`;
    else if (hireable && hireable.S.how === 'deed') ePrompt = [...world.destroyed].some((k) => k.includes(':g')) ? `[E] Tell ${hireable.S.name} how you drove off the guardian` : `${hireable.S.name} won't work for anyone who hasn't driven off a treasure guardian`;
    else if (hireable && hireable.S.how === 'court') ePrompt = `[E] Court ${hireable.S.name}: ${settlers.danced ? 'a reel danced ✓' : 'dance a reel at the barn dance'} · ${(inventory.pie || 0) >= 1 ? 'give her a pumpkin pie' : 'bring a pumpkin pie'}`;
    else if (hireable && hireable.S.how === 'tale') ePrompt = sky.night < 0.45 ? `${hireable.S.name} trades tall tales by his fire after dark` : `[E] Sit by ${hireable.S.name}'s fire and out-tell him (${tales.heard.size}/${hireable.S.tales} tales of your own)`;
    else if (hireable && hireable.S.how === 'wrestle') ePrompt = settlers.match ? `[E E E!] Arm-wrestling Big Jim  ${settlers.matchBar()}` : (hireable.tired || 0) > 0 ? 'Big Jim is still flexing his arm. Give it a little while.' : `[E] Arm-wrestle ${hireable.S.name} (win, and he'll dig your clay)`;
    else if (hireable && hireable.S.how === 'help') ePrompt = `[E] Help ${hireable.S.name} ${hireable.S.chore || 'mend her lean-to'} (${Object.entries(hireable.S.wage).map(([k, n]) => `${n} ${k}`).join(' + ')})`;
    else if (hireable) ePrompt = `[E] Hire ${hireable.S.name}, ${hireable.S.trade} (${Object.entries(hireable.S.wage).map(([k, n]) => `${n} ${k}`).join(' + ')})`;
    else if (storeNear) ePrompt = `${settlers.stockText() ? `[E] Take from the storehouse: ${settlers.stockText()}` : 'The storehouse: your settlers fill it a little at a time'}   [R] Stock the larder (${settlers.larder} rations)`;
    eFree = !ePrompt.startsWith('[E]');
    if (eFree && target?.type === 'maple' && !enemyT) ePrompt = '[E] Tap the maple for sap';
    if (eFree && target && SOFT.has(target.type) && !enemyT) ePrompt = `[E] ${E_PICK[target.type] || `Pick up the ${RESOURCE_TYPES[target.type].name.toLowerCase()}`}`;
    let lmb = '';
    if (fishR.engaged) lmb = fishR.hint;
    else if (enemyT) {
      const e = enemyT.enemy, hp = Math.max(0, Math.ceil(e.hp));
      lmb = `[LMB] Fight the ${e.spec.name.toLowerCase()}  ${'■'.repeat(hp)}${'□'.repeat(Math.max(0, e.spec.hp - hp))}`;
    } else if (target) {
      const def = RESOURCE_TYPES[target.type];
      const verb = target.type === 'satchel' ? 'Open the' : target.type === 'stook' ? 'Gather the' : ['bush', 'mushroom', 'grass', 'corn', 'pumpkin', 'apples'].includes(target.type) ? 'Pick' : target.type === 'hive' ? 'Take honey from' : target.type === 'clay' ? 'Dig' : ['rock', 'ore', 'quartz'].includes(target.type) ? 'Mine' : 'Chop';
      const needs = damageFor(target.type, tools, held) === 0 ? `  (${toolFor(target.type) === 'pick' ? 'needs the pickaxe: 3' : 'needs the axe: 2'})` : '';
      lmb = `[LMB] ${verb} ${def.name.toLowerCase()}  ${'■'.repeat(target.hp)}${'□'.repeat(def.hp - target.hp)}${needs}`;
    } else if (pieceT) {
      const p = pieceT.piece, max = PIECE_HP[p.type], hp = Math.max(0, p.hp ?? max);
      lmb = `[LMB] Break ${PIECES[p.type].name.toLowerCase()}  ${'■'.repeat(hp)}${'□'.repeat(max - hp)}`;
    }
    hud.setHint([ePrompt, lmb].filter(Boolean).join(String.fromCharCode(10)));

    // camera: aim at what the farmer is working on (zoomed in), or just ahead of him
    let focus = null;
    if (enemyT) focus = _focus.set(enemyT.enemy.pos.x, enemyT.enemy.pos.y + 0.6, enemyT.enemy.pos.z);
    else if (target) {
      const h = ['rock', 'ore', 'quartz'].includes(target.type) ? 0.6 : ['bush', 'grass', 'mushroom', 'clay', 'hive', 'pumpkin', 'apples', 'satchel'].includes(target.type) ? 0.45 : 1.5;
      focus = _focus.set(target.x, target.y + h * target.scale, target.z);
    } else if (pieceT) {
      focus = _focus.set(pieceT.piece.x, pieceT.piece.y + 1, pieceT.piece.z);
    }
    player.updateCamera(dt, focus, world);
    world.updateOcclusion(camera.position, player.pos, dt);

    // footsteps & body sounds
    if (player.avatar.stepped) {
      player.avatar.stepped = false;
      const onWood = build.surfaceAt(player.pos.x, player.pos.z, player.pos.y) >= getHeight(player.pos.x, player.pos.z) - 0.01;
      sound.step(onWood ? 'wood' : player.wading ? 'water' : weather.snow > 0.5 ? 'snow' : 'grass'); // (a muffled crunch once the snow lies)
      if (player.wading) { // a ring spreading from the shins, and a flick of paper spray
        wadeRings.ring(player.pos.x, player.pos.z);
        confetti.burst(_v.set(player.pos.x, 0.1, player.pos.z), [0xd6e6e8, 0xf3ead6, 0x9cc4d0], 4, 0.35);
      }
      if (!onWood && weather.snow > 0.3 && !player.swimming && !player.onIce) {
        const yaw = Math.atan2(player.vel.x, player.vel.z);
        printSide = -printSide;
        _pp.set(player.pos.x + Math.cos(yaw) * 0.13 * printSide, 0, player.pos.z - Math.sin(yaw) * 0.13 * printSide);
        _pp.y = getHeight(_pp.x, _pp.z) + 0.03;
        _pm.compose(_pp, _pq.setFromAxisAngle(_pUp, yaw), _ps.set(1, 1, 1));
        prints.setMatrixAt(printNext, _pm); printNext = (printNext + 1) % PRINTS;
        prints.instanceMatrix.needsUpdate = true;
      }
    }
    prints.visible = weather.snow > 0.3;
    if (weather.snow <= 0.3 && printNext !== -1 && prints.userData.dirty !== false) { // the thaw wipes the trail
      for (let i = 0; i < PRINTS; i++) { _pm.makeScale(0, 0, 0); prints.setMatrixAt(i, _pm); }
      prints.instanceMatrix.needsUpdate = true; prints.userData.dirty = false;
    }
    if (weather.snow > 0.3) prints.userData.dirty = true;
    for (const e of player.events.splice(0)) sound[e]?.();

    world.update(player.pos.x, player.pos.z, dt);
    build.update(dt, { inventory, player, night: sky.night });
    build.animate(dt);
    // a dry roof in the rain rests you like a fire
    player.warm = build.nearFire(player.pos) || (weather.rain > 0.2 && (home.covers(player.pos.x, player.pos.z) || build.roofAt(player.pos.x, player.pos.z)));
    // cold nights: after dark, out in the open, away from a fire, you're chilled (the sheepskin coat keeps it off,
    // except on a snowy night). Chilled, you get your breath back slowly and go hungry faster; out too long on a
    // snowy or wet night, the bitter cold starts to cost you health (never below 20). A fire, a roof or bed fixes it.
    {
      const underRoof = home.covers(player.pos.x, player.pos.z) || build.roofAt(player.pos.x, player.pos.z);
      const bitter = (weather.kind === 'snow' && weather.rain > 0.2) || weather.snow > 0.4 || (weather.kind === 'rain' && weather.rain > 0.4);
      player.chilled = sky.night > 0.55 && !player.dead && !player.warm && !underRoof && !porch.sitting && (!tools.has('coat') || (weather.kind === 'snow' && weather.rain > 0.2) || weather.snow > 0.4);
      coldT = player.chilled ? coldT + dt : Math.max(0, coldT - dt * 3);
      coldLevel += ((player.chilled ? Math.min(1, 0.35 + coldT / 60) : 0) - coldLevel) * Math.min(1, dt * 0.8);
      // (no screen effect: the clock says "chilly"; a frosted vignette read as a fault in the camera)
      if (player.chilled && bitter && coldT > 45 && player.health > 20) player.health = Math.max(20, player.health - dt * 0.4);
      if (player.chilled && coldT > 2 && !coldWarned) { coldWarned = true; hud.toast(tools.has('coat') ? 'Even your sheepskin can\'t keep out a night like this. Find a fire or a roof.' : 'A cold night: your breath smokes and your fingers ache. A fire, a roof or a sheepskin coat would help.'); }
      if (!player.chilled && coldT === 0) coldWarned = false;
    }

    // ambience: how much water is around, how close a fire is
    if ((waterT -= dt) <= 0) {
      waterT = 0.5;
      let wet = 0;
      for (let k = 0; k < 8; k++) {
        const a = (k / 8) * Math.PI * 2;
        if (isWater(player.pos.x + Math.cos(a) * 12, player.pos.z + Math.sin(a) * 12)) wet++;
      }
      waterNear = wet / 8;
    }
    const fireD = build.fireDistance(player.pos);
    const covered = (x, z) => home.covers(x, z) || build.roofAt(x, z);
    weather.update(dt, player.pos, covered);
    storm.update(dt, camera, player.pos, weather.storm && weather.rain > 0.6);
    puddles.update(dt, player.pos, weather.kind === 'rain' ? weather.rain : 0, weather.kind === 'snow');
    const sheltered = weather.rain > 0.2 && covered(player.pos.x, player.pos.z);
    tinker.update(dt, sky);
    owl.update(dt, { night: sky.night, player, camera });
    rainbow.update(dt);
    dog.day = sky.day;
    cat.update(dt, player, camera, dog, sky.night, world);
    dog.update(dt, player, camera, { rocker: porch.sitting ? porch : null, prey: tumbleweeds.list[0]?.mesh || ducks.fam?.ducks[0]?.p.group || null, // (a tumbleweed, or the ducks on the pond: off he goes to the bank, barking)
       colliders: world.colliders, track: calf.state === 'lost' ? calf.pos : null, danger: enemies.list.some((e) => !e.dying && !enemies.isCalm(e, sky.day + sky.time) && Math.hypot(e.pos.x - player.pos.x, e.pos.z - player.pos.z) < 14) || crows.state === 'pecking' && Math.hypot(crows.birds[0].to.x - player.pos.x, crows.birds[0].to.z - player.pos.z) < 25 });
    wisp.update(dt, { world, player, camera, night: sky.night });
    geese.update(dt, player.pos, sky);
    Figure.watch = player.dead ? null : player.pos; // folk look round at the farmer when he's near
    Figure.cam = camera.position; // and turn to face the lens, like stage puppets
    settlers.wet = weather.kind === 'rain' && weather.rain > 0.5; // (a downpour sends the hands in, as it does the town)
    settlers.update(dt, { pieces: build.pieces, sky, camera });
    announceArrivals();
    if (newcomers.length) {
      hud.toast(`Word has got round that the boarding house has rooms again. New folk have come to Paydirt Hollow looking for work: ${newcomers.map((s) => `${s.S.name}, ${s.S.pitch}`).join('; and ')}.`);
      newcomers = [];
    }
    beaver.update(dt, world, player.pos);
    eagle.update(dt, player.pos, sky);
    crows.update(dt, { world, player, camera, sky, guarded: (r) => build.pieces.some((p) => p.type === 'scarecrow' && Math.hypot(p.x - r.x, p.z - r.z) < 16), kite: kite.flying ? kite.pos : null });
    if (kite.update(dt, player, camera, weather.rain) === 'rain') hud.toast('The rain brings your kite fluttering down. You reel it in.');
    countyMap.update(player.pos);
    if ((autosaveT += dt) > 30) { autosaveT = 0; saveAll(); } // the clock moves on, so the almanac is saved now and then
    coop.update(sky, inventory);
    laundry.update(dt, player, weather.rain);
    dance.update(dt, sky, player);
    if (sky.night < 0.4) {
      const spots = build.pieces.filter((q) => q.type === 'feeder' && q.stock > 0 && (q.x - player.pos.x) ** 2 + (q.z - player.pos.z) ** 2 < 45 * 45);
      // the mended bakery's doorstep: birds come for the crumbs on the boardwalk (not in a downpour, nor with the town asleep)
      const bk = town.tiers.bakery && town.doors.bakery; if (bk && !town.raining && !town.far && (bk.x - player.pos.x) ** 2 + (bk.z - player.pos.z) ** 2 < 45 * 45) spots.push({ x: bk.x, y: town.y0, z: bk.z, ground: true });
      spots.sort((a, b) => ((a.x - player.pos.x) ** 2 + (a.z - player.pos.z) ** 2) - ((b.x - player.pos.x) ** 2 + (b.z - player.pos.z) ** 2));
      songbirds.update(dt, spots, player, camera);
    }
    else songbirds.update(dt, [], player, camera); // they roost at night
    if (johnny.update(dt, sky, player, camera, world.colliders) === 'arrived') hud.toast('A barefoot old fellow with a tin pot for a hat is coming along the lane. Johnny Appleseed, by the look of him!');
    const puffs = dandelions.update(dt, sky.day, player.pos, [{ pos: player.pos, speed: Math.hypot(player.vel.x, player.vel.z) }, { pos: dog.pos, speed: dog.speed }]);
    if (puffs) {
      sound.rustle(); journal.record('dandelion');
      if (performance.now() - dandelionToldAt > 90000) {
        dandelionToldAt = performance.now();
        const n = 1 + Math.floor(Math.random() * 12), hr = Math.floor(sky.time * 24) % 12 || 12;
        hud.toast(n === hr ? `Away go the dandelion seeds! Folks say count the puffs to tell the hour: ${n} o'clock, and right on the dot. Make a wish!` : `Away go the dandelion seeds! Folks say count the puffs to tell the hour: ${n} o'clock, says the dandelion. (The sun says otherwise.)`);
      }
    }
    if (leafPiles.update(dt, [{ pos: player.pos, speed: Math.hypot(player.vel.x, player.vel.z) }, { pos: dog.pos, speed: dog.speed }]) >= 0) {
      sound.rustle(); journal.record('leaves');
      if (++leafKicks === 1) hud.toast('Whoosh! Leaves everywhere. The breeze will sweep them back into a heap by and by.');
    }
    if (weather.rain > 0.3 && (sky.time > 0.75 || sky.time < 0.2)) nightRain = true;
    mist.update(dt, player.pos, sky, nightRain, landAt(player.pos.x, player.pos.z).w.fen);
    if (sky.time > 0.45) nightRain = false;
    if (dance.live(sky) && danceToldDay !== danceNightOf(sky)) { danceToldDay = danceNightOf(sky); hud.toast('Fiddle music drifts up the lane from Paydirt Hollow: a barn dance has started in the street before the livery barn! It runs till three in the morning.'); }
    if (fair.update(dt, sky) && fairToldDay !== sky.day) { fairToldDay = sky.day; hud.toast("It's County Fair day! Mrs. Pruitt's judging table is up just south of the farm lane, past the fence."); }
    frogs.update(dt, { world, player, camera, night: sky.night, snow: weather.snow });
    const omen = vane.update(dt, weather);
    if (omen && Math.hypot(player.pos.x - vane.group.position.x, player.pos.z - vane.group.position.z) < 60)
      hud.toast(omen === 'snow' ? "The rooster on the barn has swung round to the east, and the air's gone sharp. Snow's coming." : weather.nextStorm ? "The rooster on the barn has swung hard to the east and the air's gone close and heavy. A thunderstorm's brewing." : "The rooster on the barn has swung round to the east. Wind from the east: rain's on the way.");
    if (mail.update(dt, sky) && Math.hypot(player.pos.x - mail.at.x, player.pos.z - mail.at.z) < 45) hud.toast("The mail carrier's been by: the red flag is up on the mailbox.");
    const wet = weather.kind === 'rain' ? weather.rain : 0;
    sky.rain = weather.kind === 'snow' ? weather.rain * 0.45 : weather.rain; // snow light is soft but brighter
    world.rain = fishing.rain = wet;
    fishing.night = sky.night; // only rain hurries the crops and the fish
    uSnow.value = weather.snow;
    train.update(dt, sky.time, camera, player);
    if (!claim.group && railroad.built && tools.has('claim')) claim.build(); // (staked out once it's filed)
    if (claim.group && !claim.hand && tools.has('claimhand')) claim.hire(sky.day); // (and the hired hand, once he's taken on)
    if (claim.group && !claim.mill && tools.has('stampmill')) claim.addMill(); // (and the stamp mill)
    claim.update(dt, sky.day, sky.time > 0.24 && sky.time < 0.86, player);
    railroad.update(dt, player, sky.time > 0.24 && sky.time < 0.86); // (the trading-post keepers: out front by day)
    if (train.passenger) { train.ridePoint(_ride); player.pos.copy(_ride); player.vel.set(0, 0, 0); } // (standing on the coach's back platform)
    ducks.update(dt, player, camera, sky.night < 0.4 && weather.rain < 0.5, dog.pos);
    footprints.dogTrack(weather.snow, dog.pos); footprints.update(dt, weather.snow, player.pos, riding);
    // ponds freeze while snow lies thick (over half a minute) and thaw slowly after; never melts under your boots
    const onPond = isWater(player.pos.x, player.pos.z);
    uIce.value += ((weather.snow > 0.6 || (player.iceOn && onPond) ? 1 : 0) - uIce.value) * Math.min(1, dt * (weather.snow > 0.6 ? 0.06 : 0.02));
    const wasIce = player.iceOn;
    player.iceOn = uIce.value > 0.8 || (wasIce && onPond);
    if (player.iceOn && !wasIce) hud.toast('The ponds have frozen over! Step out onto the ice and glide.');
    if (player.onIce && Math.hypot(player.vel.x, player.vel.z) > 2.2 && (skateT += dt) > 1) { skateT = 0; journal.record('skate'); }
    // the blades score the ice: a pair of scratches every half metre you glide
    if (player.onIce && player.onGround) {
      trackDist += Math.hypot(player.pos.x - lastTrack.x, player.pos.z - lastTrack.z);
      if (trackDist > 0.42) {
        trackDist = 0; tracks.visible = true;
        const yaw = Math.atan2(player.vel.x, player.vel.z);
        for (const side of [-0.11, 0.11]) { // both blades, overlapping a little so the scratch runs on unbroken
          _pp.set(player.pos.x + Math.cos(yaw) * side, player.pos.y + 0.012, player.pos.z - Math.sin(yaw) * side);
          _pm.compose(_pp, _pq.setFromAxisAngle(_pUp, yaw), _ps.set(1, 1, 1));
          tracks.setMatrixAt(trackNext, _pm); trackNext = (trackNext + 1) % TRACKS;
        }
        tracks.instanceMatrix.needsUpdate = true;
      }
    }
    lastTrack.copy(player.pos);
    if (tracks.visible && uIce.value < 0.3) { tracks.visible = false; for (let i = 0; i < TRACKS; i++) { _pm.makeScale(0, 0, 0); tracks.setMatrixAt(i, _pm); } tracks.instanceMatrix.needsUpdate = true; }
    uCloudShade.value = (1 - sky.night) * (1 - Math.min(1, weather.rain * 1.5)); // fair days only: under rain clouds it's all shade
    build.snow = weather.snow;
    if (weather.snow < 0.15 && build.pieces.some((q) => q.type === 'snowman')) { build.meltSnowmen(); hud.toast('The thaw comes, and your snowman slumps quietly into the grass.'); saveAll(); }
    sound.update(dt, { night: sky.night, nearFire: Math.max(0, 1 - fireD / 10), water: waterNear, rain: wet, sheltered, time: sky.time, land: landHere });
    ambient.update(dt, player.pos, sky.night);
    jar.update(dt, tools.has('jar'), sky.night);
    butterflies.update(dt, player.pos, { night: sky.night, rain: weather.rain });
    if (!critters.barn && home.barn) { home.barn.updateMatrixWorld(true); critters.barn = new THREE.Vector3(1, 0, 0).transformDirection(home.barn.matrixWorld).multiplyScalar(5.4).add(home.barn.getWorldPosition(new THREE.Vector3())); } // (just out before the barn's big doors)
    critters.roost = coop.roostAt || null; critters.abed = sky.time > 0.86 || sky.time < 0.23 || (weather.kind === "rain" && weather.rain > 0.5); // (the hens go in to roost at nightfall, and out of a downpour)
    critters.update(dt, player, camera); hunting.update(dt, critters, world);
    rumours.update(player, camera, journal.active(), (k) => landmarks.found.has(k));
    enemies.update(dt, player, camera, sky.day + sky.time);
    setLodgeGlow(sky.night, performance.now() / 1000, sky.time > 0.9 || sky.time < 0.22 || (weather.kind === 'rain' && weather.rain > 0.5), sky.day); camp.update(dt, player, camera, campHooks, raidHooks); raidTick(); // (camp folk abed late at night, and in their lodges out of a downpour)
    landmarks.update(dt, camera);
    if (horse) { // she walks under you when you ride; left alone, she grazes
      const hp = horse.group.position;
      if (riding) hp.set(player.pos.x, player.pos.y, player.pos.z);
      else hp.y = getHeight(hp.x, hp.z);
      // whistled for: she comes to you, galloping from afar, walking the last stretch, and stops beside you
      let callSpd = 0;
      if (horse.called && !riding) {
        const dx = player.pos.x - hp.x, dz = player.pos.z - hp.z, d = Math.hypot(dx, dz);
        if (d < 2.2) horse.called = false;
        else {
          callSpd = d > 12 ? 8 : d > 5 ? 3.2 : 1.6;
          const nx = hp.x + (dx / d) * callSpd * dt, nz = hp.z + (dz / d) * callSpd * dt;
          if ((isWater(nx, nz) && !wadeable(nx, nz)) || impassable(nx, nz)) horse.called = false; else { hp.x = nx; hp.z = nz; hp.y = getHeight(nx, nz); }
        }
      }
      // her stall: as dusk comes on, if she's been left near the farm she walks herself in through the barn's big doors
      // to the stall and stands there the night; come morning she walks back out to the yard. Whistling or riding her
      // breaks it off.
      const BB = home.barnBox;
      if (BB && !riding && !horse.called) {
        const toW = (lx, lz) => { lx += BB.ox; lz += BB.oz; return new THREE.Vector3(BB.x + BB.c * lx + BB.s * lz, 0, BB.z - BB.s * lx + BB.c * lz); };
        const night = sky.time >= 0.83 || sky.time < 0.22, near = Math.hypot(hp.x - BB.x, hp.z - BB.z) < 70;
        if (night && near && !horse.stabled && !horse.route) { horse.route = [toW(0, BB.hd + 2.2), toW(0, BB.hd - 0.8), toW(-0.35, -0.05)]; horse.stabled = true; }
        else if (!night && horse.stabled && !horse.route) { horse.route = [toW(0, BB.hd - 0.8), toW(0, BB.hd + 2.2), toW(-1.5, BB.hd + 6)]; horse.stabled = false; }
      }
      if (riding || horse.called) { horse.route = null; if (riding || horse.called) horse.stabled = false; }
      if (horse.route && !riding) {
        const wp = horse.route[0], dx = wp.x - hp.x, dz = wp.z - hp.z, d = Math.hypot(dx, dz);
        if (d < 0.25) { horse.route.shift(); if (!horse.route.length) horse.route = null; }
        else { callSpd = Math.min(d / dt, 1.3); hp.x += (dx / d) * callSpd * dt; hp.z += (dz / d) * callSpd * dt; hp.y = getHeight(hp.x, hp.z); }
      }
      const spd = riding ? Math.hypot(player.vel.x, player.vel.z) : callSpd / 0.8;
      const yawToCam = Math.atan2(camera.position.x - hp.x, camera.position.z - hp.z), camRight = _v.set(Math.cos(yawToCam), 0, -Math.sin(yawToCam));
      const left = riding ? (Math.sin(player.facing) * camRight.x + Math.cos(player.facing) * camRight.z) < 0 : false;
      horse.update(dt, spd * 0.8, spd > 0.2 ? 'walk' : 'idle', left, yawToCam, 0); // (whistled for, the run blends in past a trot)
      if (horse.saddle) { placeSaddle(horse.saddle, horse.model, 0.44 * horse.saddle.scale.y); horse.saddle.visible &&= horse.group.visible; } // (her tack rides her back)
      if (riding && !seatRider()) player.avatar.root.position.y += 1.05; // (after her step, so he sits on this frame's back)
    }
    bunkhouse.supper(sky.time > 0.76 && sky.time < 0.88);
    // oats from the feed & grain: the first time you ride each day she gets a feed, and runs a quarter faster all day
    if (riding && inventory.oatsDay !== sky.day && (inventory.oats || 0) > 0) { inventory.oats--; inventory.oatsDay = sky.day; hud.toast('Biscuit noses the feed bag and eats her oats. She tosses her head and is raring to go: a quarter faster all day.'); }
    player.oatsFed = inventory.oatsDay === sky.day;
    // the railroad comes: the day every street in town stands mended, the Overland & Western lays its line
    // the telegraph: a rush order wired down the line each morning there isn't one standing (the day after one's filled)
    if (railroad.built && sky.time > 0.3 && sky.time < 0.8) {
      const o = orderState();
      if (!o || (o.day !== sky.day && (o.done || sky.day > o.due))) {
        if (o && !o.done) hud.toast(`The rush order for the ${o.where} trading post has lapsed: they found it elsewhere.`);
        clearOrder(); const q = newOrder(sky.day);
        if (Math.hypot(player.pos.x - railroad.depot.x, player.pos.z - railroad.depot.z) < 150 || train.passenger) hud.toast(`The telegraph at the depot clatters: a rush order from ${q.where}, ${q.name.replace('Telegram: ', '').toLowerCase()}, by day ${q.due}, $${q.pay} on delivery. (Almanac, H)`);
        saveAll();
      }
    }
    if (!railroad.built && (railCheckT -= dt) <= 0) {
      railCheckT = 3;
      if (town.streetDone(-1) && town.streetDone(0) && town.streetDone(1)) { railroad.build(); saveAll(); hud.toast('Paydirt Hollow has come up in the world: the Overland & Western has laid a rail line out past the church, with a depot at its head and a whistle-stop in each of the wild lands.'); }
    }
    town.day = sky.day; town.bedtime = sky.time > 0.9 || sky.time < 0.22; town.camPos = camera.position; town.playerPos = player.pos; town.clock = sky.time; town.raining = weather.kind === 'rain' && weather.rain > 0.5; town.snowCover = weather.snow; town.sunday = sky.day % 7 === 0 && sky.time > 0.27 && sky.time < 0.45; town.inv = inventory; town.update(sky.night, dt); town.setPlaybill(sky.day); town.danceHall(sky.time > 0.76 || sky.time < 0.04, dt); town.operaQueue(sky.time > 0.74 && sky.time < 0.86, dt);
    if (town.tiers.bank && sky.time > 0.25 && inventory.bankDay !== sky.day) { // the morning's interest, three cents on the dollar
      const due = inventory.bankDay !== undefined && inventory.savings >= 10 ? Math.max(1, Math.floor(inventory.savings * 0.03)) : 0;
      inventory.bankDay = sky.day;
      if (due) { inventory.savings += due; hud.toast(`The Miners' bank has written $${due} interest into your account. $${inventory.savings} in the safe.`); }
    } cellar.update(sky.day); bunkhouse.update(sky.night);
    // a honky-tonk piano drifting out of the mended saloon after dark, louder as you come up the street
    if (town.tiers.saloon && sky.night > 0.45 && sound.ready && !sound.muted) {
      const sd = Math.hypot(player.pos.x - town.doors.saloon.x, player.pos.z - town.doors.saloon.z);
      if (sd < 30 && (pianoT -= dt) <= 0) {
        pianoT = 0.18 + Math.random() * 0.22;
        const SCALE = [60, 62, 64, 67, 69, 72, 74, 76], m = SCALE[Math.floor(Math.random() * SCALE.length)], vol = 0.07 * (1 - sd / 30);
        const w = sound.ctx.currentTime; sound.pluck(440 * Math.pow(2, (m - 69) / 12), w, vol, 0.7);
        if (Math.random() < 0.3) sound.pluck(440 * Math.pow(2, (m - 81) / 12), w, vol * 0.8, 0.9); // the left hand, an octave down
      }
    }
    updateHomeward(); updateNext(dt);
    home.setFortune(fortune); home.barnCutaway(player.pos); // (the farmhouse mends as your fortune grows; cheap when nothing's changed)
    { const txt = fortune || inventory.dollars ? `$${inventory.dollars} in your poke` : ''; if (fortuneEl.textContent !== txt) { fortuneEl.textContent = txt; fortuneEl.style.display = txt ? '' : 'none'; } }
    wadeRings.update(dt, player.pos, player.wading, Math.hypot(player.vel.x, player.vel.z));
    shafts.update(dt, { camera, pos: player.pos, sky, rain: weather.rain, world, getHeight, wooded: regionAt(player.pos.x, player.pos.z) === 'forest' ? 1 : 0.4 });
    // reaching a landmark for the first time: what you find there
    {
      const hit = landmarks.reached(player.pos, inventory), site = hit?.site;
      if (hit?.hint) hud.toast(LANDMARK_INFO[site.mark].found);
      else if (site) {
        const info = LANDMARK_INFO[site.mark];
        for (const k in info.needs || {}) inventory[k] -= info.needs[k];
        if (info.blessing) landmarks.blessed = true;
        for (const k in info.gift) inventory[k] = (inventory[k] || 0) + info.gift[k];
        if (info.reveal) for (let a = 0; a < Math.PI * 2; a += 0.1) for (let r = 0; r <= info.reveal; r += 12) countyMap.update({ x: site.x + Math.cos(a) * r, z: site.z + Math.sin(a) * r });
        if (info.mend) { player.health = player.maxHealth; player.stamina = player.maxStamina; }
        if (info.mapAll) for (const u of uniqueEncounters()) for (let a = 0; a < Math.PI * 2; a += 0.6) for (const r of [0, 14]) countyMap.update({ x: u.x + Math.cos(a) * r, z: u.z + Math.sin(a) * r }); // he inks them all onto your map
        hud.toast(info.thanks || `${info.found} ${Object.entries(info.gift).map(([k, n]) => `${n} ${k}`).join(', ')}.`);
        journal.record('landmark'); sound.craft(); saveAll();
      }
    }
    // crossing into a land: its name, and the first time, what the old folks say of it
    {
      const L = landAt(player.pos.x, player.pos.z), id = L.wild > 0.6 ? L.id : L.wild < 0.35 ? 'home' : landHere;
      if (id !== landHere) {
        landHere = id;
        if (id === 'home') hud.toast('Back in the home county. The fields and fences look like old friends.');
        else if (!landsFound.has(id)) { landsFound.add(id); journal.record('land'); hud.toast(`You've come into ${LANDS[id].name}. ${LANDS[id].lore}`); sound.craft(); saveAll(); }
        else hud.toast(`Into ${LANDS[id].name} again.`);
      }
    }
    if (sky.night > 0.85) journal.record('night');
    if (build.active) {
      renderBuildBar();
      const pv = build.preview;
      buildhint.textContent = pv
        ? (pv.valid ? `LMB place ${PIECES[pv.type].name.toLowerCase()} · R rotate${pv.type === 'roof' ? (build.roofManual ? ' (manual)' : ' (auto)') : ''} · Q/E change` : pv.reason)
          + (build.hover ? ' · RMB remove' : '')
        : 'Aim at the ground';
    }
    sky.update(dt, player.pos, camera);
    // the harvest moon: the night before the County Fair, everything you gather yields one more
    const harvestMoon = (sky.day + 1) % 7 === 0 && sky.night > 0.5;
    nightSky.update(dt, camera, sky.sunDir, sky.night, harvestMoon);
    if (harvestMoon && harvestToldDay !== sky.day) { harvestToldDay = sky.day; hud.toast('A harvest moon is rising, big and gold as a pumpkin. Folks say whatever you gather tonight comes in double-handed.'); }
    const fell = fallingStars.update(dt, { player, camera, night: sky.night, rain: weather.rain });
    if (fell) hud.toast(`A falling star! It came down off to the ${fell}, not far. Folk say a fallen star brings luck.`);
    home.update(dt, sky.night, camera);
    {
      const fires = [];
      for (const p of build.pieces) {
        if (p.type !== 'campfire' && p.type !== 'forge') continue;
        const d = (p.x - player.pos.x) ** 2 + (p.z - player.pos.z) ** 2;
        if (d > 55 * 55) continue;
        if (p.type === 'campfire') fires.push({ x: p.x, y: p.y, z: p.z, top: 0.9, sparks: true, d });
        else { const ra = ((p.rot || 0) * Math.PI) / 2, c = Math.cos(ra), s = Math.sin(ra); /* build rotations are quarter turns */ fires.push({ x: p.x + 0.45 * c - 0.25 * s, y: p.y, z: p.z - 0.45 * s - 0.25 * c, top: 2.35, sparks: false, d }); }
      }
      // the valley people's cookfires, and the bunkhouse supper fire while it's lit
      for (const c of camp.list) { const d = (c.at.x - player.pos.x) ** 2 + (c.at.z - player.pos.z) ** 2; if (d < 55 * 55) fires.push({ x: c.at.x, y: c.at.y, z: c.at.z, top: 0.8, sparks: true, d }); }
      if (bunkhouse.built && bunkhouse.flame?.visible) { const f = bunkhouse.fireAt, d = (f.x - player.pos.x) ** 2 + (f.z - player.pos.z) ** 2; if (d < 55 * 55) fires.push({ x: f.x, y: getHeight(f.x, f.z), z: f.z, top: 0.7, sparks: true, d }); }
      // the town's stovepipes: the trades' fires all day, the cookstoves at breakfast and supper
      const tm = sky.time, dayFire = tm > 0.24 && tm < 0.8, meals = (tm > 0.24 && tm < 0.36) || (tm > 0.7 && tm < 0.84);
      if (!town.far) for (const c of town.chimneys || []) { if (!(c.when === 'day' ? dayFire : meals)) continue; const d = (c.x - player.pos.x) ** 2 + (c.z - player.pos.z) ** 2; if (d < 55 * 55) fires.push({ x: c.x, y: c.y, z: c.z, top: c.top, sparks: false, d }); }
      fires.sort((a, b) => a.d - b.d);
      fireSmoke.update(dt, fires, camera, sky.night, weather.rain);
      // Saturday-night fireworks: every street mended, a Saturday evening, near enough to see them
      {
        const show = !town.far && sky.day % 7 === 6 && sky.time > 0.79 && sky.time < 0.9 && town.streetDone(-1) && town.streetDone(0) && town.streetDone(1);
        town.fireworksOn = sky.day % 7 === 6 && sky.time > 0.7 && sky.time < 0.9 && town.streetDone(-1) && town.streetDone(0) && town.streetDone(1); // (the Row walks over after supper to find a place before the first rocket)
        if (show && fwDay !== sky.day) { fwDay = sky.day; hud.toast('Saturday night, and the whole town is mended. From the field behind the church the first rocket goes up: fireworks!'); }
        if (show || fireworks.mesh.count) fireworks.update(dt, show, fwAt.set(town.churchAt.x + town.along.x * 14, town.y0, town.churchAt.z + town.along.z * 14), camera, (x, y, z) => { const d = Math.hypot(x - player.pos.x, z - player.pos.z); if (sound.ready && !sound.muted && d < 140) sound.pop(Math.max(0.05, 1 - d / 140)); });
      }
      nightHowl.update(dt, player, camera, sky.night > 0.7 && weather.rain < 0.1 && Math.hypot(player.pos.x - town.at.x, player.pos.z - town.at.z) > 90 && Math.hypot(player.pos.x, player.pos.z) > 45, (v, ans) => sound.howl(v, ans));
      hoofDust.update(dt, player.pos, player.vel, riding && !player.swimming && weather.rain < 0.2 && landAt(player.pos.x, player.pos.z).w.fen < 0.5, camera);
      tumbleweeds.update(dt, player, weather.rain < 0.1 && sky.night < 0.4 && (Math.hypot(player.pos.x - town.at.x, player.pos.z - town.at.z) < 75 || Tumbleweeds.dryAt(player.pos.x, player.pos.z)), world.colliders);
    }
    if (lampsOn ? sky.night < 0.12 : sky.night > 0.18) setLamps(!lampsOn); // a little hysteresis at dusk and dawn
    confetti.update(dt, getHeight);

    // post uniforms follow the camera & the time of day
    // lens: focus on the hero; kD converts relative depth to frame heights = 1 / (fovY · cot(pitch))
    // the lens focuses on whatever the middle of the screen lands on, as if you were looking at it: a ray from the
    // camera through the centre is walked out (every third frame) until it meets a building, rock or tree, or the ground
    const heroZ = camera.position.distanceTo(player.camTarget);
    if ((lensTick++ % 3) === 0) lensAim = centreDepth(heroZ);
    lensZ += (lensAim - lensZ) * Math.min(1, dt * 4);
    const lensFar = THREE.MathUtils.smoothstep(lensZ / heroZ, 1.3, 3);
    post.u.focusZ.value = lensZ;
    post.u.depthWeight.value = THREE.MathUtils.lerp(0.8, 1, lensFar);
    post.u.nearGain.value = THREE.MathUtils.lerp(1.55, 1.1, lensFar);
    post.u.kD.value = Math.max(0.25, Math.tan(Math.max(0.05, player.pitch))) / THREE.MathUtils.degToRad(camera.fov);
    post.u.night.value = sky.night;
    post.u.shadowWarmth.value = 0.7 * (1 - 0.75 * sky.night);
    post.u.aoStrength.value = 1.0 - 0.45 * sky.night; // AO adds to night murk

    hud.setInventory(inventory);
    hud.setTools(tools, held, owns, wear);
    hud.setStamina(player.stamina, player.maxStamina, player.staminaBoost > 0);
    hud.setFullness(player.fullness);
    // a quiet HUD: the bars fade out after a few seconds of all being well, and are back at once when they matter
    const allWell = player.health >= player.maxHealth * 0.98 && player.stamina >= player.maxStamina * 0.97 && player.fullness >= 50 && !player.chilled && !player.dead;
    calmT = allWell ? calmT + dt : 0;
    document.body.classList.toggle('calm', calmT > 3);
    // a word when the belly starts to rumble, and again when it's empty
    if (player.fullness < 30 && hungerWarned < 1) { hungerWarned = 1; hud.toast('Hungry! Eat something (F).'); }
    if (player.fullness < 10 && hungerWarned < 2) { hungerWarned = 2; hud.toast('STARVING! Eat now (F).'); }
    hud.setHealth(player.health, player.maxHealth);
    hud.setClock(sky.clockText() + (landHere !== 'home' ? ` · ${LANDS[landHere].name.replace(/^the /, '')}` : '') + (player.chilled ? (coldT > 45 ? ' · bitter cold' : ' · chilly') : porch.sitting ? ' · rocking on the porch' : sheltered ? ' · snug and dry' : player.warm ? ' · warm by the fire' : ciderT > 0 ? ' · warm with cider' : ''));

    // On medium/low the sun's shadow map is redrawn only every 2nd/3rd frame, but only while the view holds still:
    // the key light follows the camera, so skipping frames while it moves made every shadow hop in steps
    // (it read as a jerky camera). Moving, it's redrawn every frame.
    if (shadowEvery > 1) {
      const moving = camera.position.distanceToSquared(lastCamPos) > 1e-6 || Math.abs(camera.quaternion.dot(lastCamQuat)) < 0.999999;
      lastCamPos.copy(camera.position); lastCamQuat.copy(camera.quaternion);
      sky.sun.shadow.needsUpdate = (shadowTick++ % (moving ? Math.max(1, shadowEvery - 1) : shadowEvery)) === 0; // moving: low every 2nd frame, medium every frame
    }
    if (fitToWindow()) { autoExpose(dt); post.render(); }
    if (snapWanted) { snapWanted = false; makePostcard(); } // right after the render, while the frame is still on the canvas
    // real frames per second (wall clock), shown next to the backend name
    fps.frames++;
    const nowMs = performance.now();
    if (nowMs - fps.since >= 1000) {
      const rate = Math.round((fps.frames * 1000) / (nowMs - fps.since));
      hud.backend.textContent = `${backendName} · ${rate} fps · ${quality.mode === 'auto' ? 'auto ' : ''}${quality.level}`;
      // auto quality: after a warm-up, three seconds in a row under 50 fps steps down one level (never up)
      if (quality.mode === 'auto' && !document.hidden && nowMs - quality.startedAt > 6000) {
        quality.lowSeconds = rate < 50 ? quality.lowSeconds + 1 : 0;
        if (quality.lowSeconds >= 3 && quality.level !== 'low') {
          applyQuality(quality.level === 'high' ? 'medium' : 'low');
          quality.lowSeconds = 0;
          hud.toast(`Graphics lowered to ${quality.level} for smoother play (O to change)`);
        }
      }
      fps.frames = 0; fps.since = nowMs;
    }
    input.endFrame();
  };
  // a stray error in one frame must never freeze the farm: log it (a few times), tell the player once, carry on
  let tears = 0;
  const frame = (ts) => {
    try { frameInner(ts); } catch (err) {
      input.endFrame(); // don't let a click or key press repeat forever
      if (tears < 3) console.error('Paydirt Hollow: a frame tore, carrying on:', err);
      if (tears === 0) hud.toast('A little tear in the paper: something went wrong, but the game carries on.');
      tears++;
    }
  };
  renderer.setAnimationLoop((ts) => { if (!window.paperfjord?.hold) frame(ts); }); // hold: a test hook that pauses the live loop while frames are stepped by hand
  window.paperfjord.frame = frame; // lets tests step the game when the tab is throttled
}

const _v = new THREE.Vector3();
// graphics quality levels (O cycles auto → high → medium → low)
const QUALITY = {
  // soft: the sun's shadow penumbra (PCF radius: wider spread, same number of taps); bounce: the one-bounce light pass's resolution
  high: { ratio: 2, shadow: 2048, shadowEvery: 1, soft: 5, post: { bounce: 0.25 } },
  medium: { ratio: 1.5, shadow: 1024, shadowEvery: 2, soft: 4, post: { bloom: false, dofLevels: 1, bounce: 0.25 } },
  low: { ratio: 1, shadow: 1024, shadowEvery: 3, soft: 3, post: { ao: false, bloom: false, dof: false, line: false, bounce: 0.125 } },
};

// exposure: 1.4 is the approved afternoon/golden look; night lifts to ~1.75
const EXPOSURE = { base: 1.4, nightLift: 0.25 };
const _f = new THREE.Vector3(), _focus = new THREE.Vector3();
const E_PICK = { bush: 'Pick the berries', mushroom: 'Pick the toadstools', grass: 'Pull an armful of tall grass', apples: 'Pick up the windfall apples', stook: 'Gather the wheat sheaves', corn: 'Pick the sweet corn', pumpkin: 'Pick the pumpkin', hive: 'Take honey from the wild hive', satchel: 'Open the lost satchel' };
const TIME_PRESETS = [
  { name: 'Afternoon', t: 0.58 },
  { name: 'Golden', t: 0.715 },
  { name: 'Blue hour', t: 0.775 },
  { name: 'Night', t: 0.9 },
];

main().catch((err) => {
  console.error(err);
  const el = document.getElementById('error');
  el.textContent = `Could not start: ${err.message}`;
  el.style.display = 'block';
});
